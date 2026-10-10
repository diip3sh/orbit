//
//  MotionPlan+Layers.swift
//  Reco
//

import CoreGraphics

extension MotionPlan {

    /// Each scene's layers, parents first, with their sizes and moves; images come later. A `ui`
    /// layer whose asset was never lifted has no size yet and isn't drawn.
    nonisolated static func flattened(_ layers: [MotionLayer], parent: Int?, sizes: [String: CGSize], context: MoveContext, into list: [Layer] = []) -> [Layer] {
        var list = list
        for layer in layers {
            var isGroup = false
            if case .group = layer.content {
                isGroup = true
            }
            var context = context
            context.position = CGPoint(x: layer.transform.position.x, y: layer.transform.position.y)
            var parts: [CGRect] = []
            let size: CGSize
            if case .text(let text) = layer.content {
                let measured = TextImage(text, scale: 0)
                size = measured.size
                context.measure(measured)
                parts = layer.moves.contains { $0.kind == .lineMask } ? measured.lines
                    : layer.moves.contains { $0.kind == .wordByWord || $0.kind == .reply } ? measured.words : measured.characters
            } else {
                size = Self.size(of: layer.content, sizes: sizes)
            }
            var planned = Layer(
                parent: parent, base: Dictionary(uniqueKeysWithValues: MotionProperty.allCases.map { ($0, layer.base($0)) }),
                anchor: layer.transform.anchor, tracks: tracks(layer.keyframes), isDrawn: !isGroup && size.width > 0 && size.height > 0,
                size: size, shadow: layer.shadow
            )
            planned.parts = parts
            planned.isSharp = BurstExpansion.isParticles(layer.id) || parent.map { list[$0].isSharp } ?? false
            for move in layer.moves {
                let effect = MoveExpansion.effect(of: move, in: context)
                planned.moves.merge(effect.tracks) { $0 + $1 }
                planned.reveal = effect.reveal ?? planned.reveal
                planned.region = effect.region.map { CGRect(x: $0.minX * size.width, y: $0.minY * size.height, width: $0.width * size.width, height: $0.height * size.height) }
                    ?? planned.region
            }
            planned.moves.merge(MoveExpansion.placeTracks(of: layer.moves, from: context.position, in: context)) { $0 + $1 }
            dress(&planned, as: layer, parent: parent, in: &list, context: context)
            if case .shape(let shape) = layer.content {
                planned.morph = ShapeMorph(shape, moves: layer.moves, context: context)
            }
            planned.accent = layer.moves.first { $0.kind == .kinetic }?.color
            press(&planned, as: layer, context: context)
            list.append(planned)
            if case .group(let children) = layer.content {
                list = flattened(children, parent: list.count - 1, sizes: sizes, context: context, into: list)
            }
        }
        return list
    }

    /// How long the pointer stays at a selection's end once it's done.
    nonisolated static let selectionHold = 0.5

    /// When a pointer presses `planned`: its clicks, and a selection dragged across its text (spec 0016), pressed where it
    /// starts and let go ``selectionHold`` after it ends.
    nonisolated private static func press(_ planned: inout Layer, as layer: MotionLayer, context: MoveContext) {
        planned.clicks = layer.moves.filter { $0.kind == .click }.map { move in
            let timing = MoveExpansion.timing(of: move, in: context)
            return Click(press: timing.start, leaves: timing.start + timing.duration)
        }
        guard let move = layer.moves.first(where: { $0.kind == .select }), !planned.parts.isEmpty else { return }
        let timing = MoveExpansion.timing(of: move, in: context)
        let selection = TextSelection(
            parts: planned.parts, size: planned.size, start: timing.start, duration: timing.duration, color: move.color ?? TextSelection.defaultColor
        )
        planned.clicks.append(Click(press: timing.start, leaves: timing.start + timing.duration + selectionHold, sweep: selection))
    }

    /// A story film's parts of a layer (spec 0015): a voice line's follow, on its group if it's in one, so a logo beside it
    /// moves with it; its tints, its own and its groups' washes; a card's glass.
    nonisolated private static func dress(_ planned: inout Layer, as layer: MotionLayer, parent: Int?, in list: inout [Layer], context: MoveContext) {
        if case .shape(let shape) = layer.content, shape.glass == true, !shape.isGlyph, (shape.stroke ?? 0) == 0 {
            planned.glass = GlassRenderer.Shape(radius: shape.cornerRadius, rim: GlassRenderer.shapeRim)
        }
        if let reveal = planned.reveal, reveal.style == .voice {
            let scale = layer.transform.scale
            let origin = parent.map { list[$0].base[.positionX] ?? 0 } ?? 0
            let line = VoiceLine(
                left: origin + layer.transform.position.x - layer.transform.anchor.x * planned.size.width * scale, scale: scale,
                centre: abs(layer.transform.anchor.x - 0.5) < 1e-6 && parent == nil ? layer.transform.position.x : nil
            )
            let follow = followTrack(of: reveal, parts: planned.parts, line: line, canvas: context.canvas)
            if let parent {
                list[parent].moves[.positionX, default: []].append(contentsOf: follow)
            } else {
                planned.moves[.positionX, default: []].append(contentsOf: follow)
            }
            // Lovable's line slides along crisp: blurred by its follow, its letters doubled
            planned.isSharp = true
        }
        planned.tints = (parent.map { list[$0].tints.filter { $0.kind == .wash } } ?? []) + layer.moves.compactMap { move in
            guard move.kind == .shimmer || move.kind == .wash else { return nil }
            let timing = MoveExpansion.timing(of: move, in: context)
            return LayerTint(kind: move.kind == .shimmer ? .shimmer : .wash, start: timing.start, duration: timing.duration, over: list.count)
        }
    }

    /// Where a voice line sits across the canvas: its left edge, its scale, and the anchor it's centred on while it grows
    /// (`nil` for a line anchored elsewhere or in a group).
    nonisolated private struct VoiceLine {
        let left: Double
        let scale: Double
        let centre: Double?
    }

    /// A voice line centred on its anchor while it grows, then held with its caret at ``voiceFollow`` of the frame's
    /// width while the rest runs off to the left, as Lovable's dictation was: added to its place, its typed width eased
    /// from letter to letter, sampled at 30 Hz.
    nonisolated private static func followTrack(of reveal: TextReveal, parts: [CGRect], line: VoiceLine, canvas: CGSize) -> [PropertyTrack] {
        guard let first = parts.first else { return [] }
        let typed = { (time: Double) -> Double in
            // The right edge of what's typed, gliding from each letter's to the next
            guard let shown = parts.indices.last(where: { reveal.start(ofPart: $0) <= time }) else { return first.minX }
            let next = shown + 1
            guard next < parts.count, reveal.stagger > 0 else { return parts[shown].maxX }
            let share = min(max((time - reveal.start(ofPart: shown)) / reveal.stagger, 0), 1)
            return parts[shown].maxX + (parts[next].maxX - parts[shown].maxX) * share
        }
        let shift = { (time: Double) -> Double in
            let right = typed(time) * line.scale
            let centring = line.centre.map { $0 - (line.left + (first.minX * line.scale + right) / 2) } ?? 0
            return min(centring, voiceFollow * canvas.width - (line.left + right))
        }
        let end = reveal.end(parts: parts.count) + reveal.stagger
        let count = max(Int(((end - reveal.start) * 30).rounded(.up)), 1)
        let keyframes = (0...count).map { index in
            let time = reveal.start + (end - reveal.start) * Double(index) / Double(count)
            return Keyframe(time: time, value: shift(time))
        }
        return PropertyTrack(.positionX, keyframes: keyframes).map { [$0] } ?? []
    }

    /// Where a voice line's caret is held once the line reaches it, as a share of the frame's width.
    nonisolated static let voiceFollow = 0.7

    /// `layers` with the brand's gradient, which their new words, shimmers and washes are drawn in.
    nonisolated static func painted(_ layers: [Layer], with gradient: [RGBAColor]) -> [Layer] {
        layers.map { layer in
            var layer = layer
            layer.gradient = gradient
            return layer
        }
    }

    nonisolated static func tracks(_ keyframes: [MotionProperty: [Keyframe]]) -> [MotionProperty: PropertyTrack] {
        keyframes.reduce(into: [:]) { tracks, entry in
            tracks[entry.key] = PropertyTrack(entry.key, keyframes: entry.value)
        }
    }

    nonisolated static func size(of content: LayerContent, sizes: [String: CGSize]) -> CGSize {
        switch content {
        // Text is measured with its parts, in `flattened`
        case .text, .group: .zero
        case .image(let image): image.size
        case .lifted(let lifted):
            sizes[lifted.asset].map { size in
                let width = lifted.width ?? size.width
                return CGSize(width: width, height: width * size.height / size.width)
            } ?? .zero
        case .shape(let shape): shape.size
        }
    }

    nonisolated static func contents(of layers: [MotionLayer]) -> [LayerContent] {
        layers.flatMap { layer -> [LayerContent] in
            if case .group(let children) = layer.content {
                return [layer.content] + contents(of: children)
            }
            return [layer.content]
        }
    }
}
