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
                    : layer.moves.contains { $0.kind == .wordByWord } ? measured.words : measured.characters
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
            if case .shape(let shape) = layer.content {
                planned.morph = ShapeMorph(shape, moves: layer.moves, context: context)
            }
            planned.accent = layer.moves.first { $0.kind == .kinetic }?.color
            planned.clicks = layer.moves.filter { $0.kind == .click }.map { move in
                let timing = MoveExpansion.timing(of: move, in: context)
                return Click(press: timing.start, leaves: timing.start + timing.duration)
            }
            list.append(planned)
            if case .group(let children) = layer.content {
                list = flattened(children, parent: list.count - 1, sizes: sizes, context: context, into: list)
            }
        }
        return list
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
