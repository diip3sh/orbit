//
//  MotionLint.swift
//  Reco
//

import CoreGraphics
import Foundation

/// What the grammar's rules find wrong with a document, before anything is rendered (spec 0011,
/// *Rules*). Checks on pixels (an accent's share, contrast over UI) belong to the design check.
nonisolated enum MotionLint {

    nonisolated enum Rule: String, Sendable {
        case readingTime, textSize, safeArea, contrast, firstMove, simultaneousMoves, exitLength
        case sceneLengths, typingRate, stillness, hookLength, endingLength, rollLength, busyField, material, look, beats
    }

    nonisolated struct Finding: Equatable, Sendable {
        let rule: Rule
        let scene: String
        var layer: String?
        let message: String
    }

    /// Nothing moving and nothing to read for longer than this is a frozen stretch; in motion design, where something
    /// changes every beat, a beat and a half at the reference's 125 BPM (spec 0014).
    static let longestStillness = 1.5
    static let designStillness = 0.72

    /// The moves that make a scene motion design.
    private static let designMoves: Set<MotionMove.Kind> = [
        .letters, .kinetic, .pop, .press, .click, .burst, .ripple, .scroll, .morph, .spin, .flood, .voice, .reply, .shimmer, .wash, .scatter, .show, .hide
    ]

    /// Typing faster than the fastest reference (25 characters a second) reads as a paste.
    static let fastestTyping = 25.0

    /// A busy field at this strength or less is a glow behind the UI, not a picture competing with it.
    static let busyStrength = 0.5

    /// Moves that act on a layer already shown: they don't delay when it can be read. A burst and a ripple start
    /// their own layers, which count for them.
    /// Reveals read along as they're typed.
    private static let typedReveals: Set<MotionMove.Kind> = [.type, .kinetic, .voice]

    private static let actions: Set<MotionMove.Kind> = [.exit, .click, .press, .spin, .morph, .flood, .scroll, .burst, .ripple, .shimmer, .wash, .hide]

    static func findings(in document: MotionDocument, sizes: [String: CGSize] = [:]) -> [Finding] {
        let expanded = DocumentExpansion.expanded(document, sizes: sizes)
        var findings: [Finding] = []
        // Live takes and how long they play, as record_page times them
        let live = document.assets.reduce(into: [String: Double]()) { live, asset in
            if let plan = try? asset.takePlan() {
                live[asset.id] = plan.duration
            }
        }
        findings += beatFindings(document)
        for (scene, source) in zip(expanded.scenes, document.scenes) {
            let context = MoveContext(sceneDuration: scene.duration, canvas: document.canvas.size)
            let layers = timed(scene.layers, in: context, group: nil)
            findings += textFindings(layers, scene: scene, canvas: document.canvas, context: context)
            // The last scene may hold: a logo on its own as the light goes out
            let isEndCard = source.shot?.kind.isEnding == true || (document.scenes.count > 1 && source.id == document.scenes.last?.id)
            findings += timingFindings(layers, scene: scene, isEndCard: isEndCard, onBeat: SoundRules.beat(document.sound.style) != nil, live: live)
            if source.shot?.kind == .hook, let text = source.shot?.text, ReadingTime.words(in: text) > 6 {
                findings.append(Finding(rule: .hookLength, scene: scene.id, message: "A hook is six words at most; this one has \(ReadingTime.words(in: text))."))
            }
            if let shot = source.shot, shot.kind == .closing {
                let words = (shot.items ?? []).compactMap(\.text).filter { !$0.isEmpty }.count
                let needed = ShotLayout.closingLength(words: words, hasLogo: shot.asset != nil)
                if scene.duration < needed - 1e-6 {
                    let message = "A closing with \(words) words needs \(seconds(needed)) s to come together; this one has \(scene.duration.formatted()) s."
                    findings.append(Finding(rule: .endingLength, scene: scene.id, message: message))
                }
            }
            findings += rollFindings(scene.layers, scene: scene)
            let field = source.field ?? document.canvas.field
            if let shot = source.shot, shot.kind == .macro, field != .plain {
                findings += materialFindings(shot, over: field, scene: scene.id, assets: document.assets)
            }
            // A closing is drawn on black whatever the field; a field toned down to half is a glow behind the UI
            if field.isBusy, source.shot?.kind != .macro, source.shot?.kind != .closing, document.canvas.fieldStrength > busyStrength {
                findings.append(Finding(
                    rule: .busyField, scene: scene.id,
                    message: "The \(field.rawValue) field competes with what's over it: put it under a macro's glass, tone it down (fieldStrength 0.45), or use plain."
                ))
            }
        }
        findings += lookFindings(document)
        let lengths = document.scenes.map(\.duration)
        if lengths.count >= 4, let longest = lengths.max(), let shortest = lengths.min(), longest < 3 * shortest {
            findings.append(Finding(
                rule: .sceneLengths, scene: document.scenes[0].id,
                message: "The longest scene should be at least 3× the shortest (\(longest.formatted()) s against \(shortest.formatted()) s): vary the pace."
            ))
        }
        return findings
    }

    /// UI in macro over a field is glass or bare: as the page paints it, its fill reads as a flat box cut
    /// out of another picture (the L1 shot the user found "really bad" next to Raycast's). Bare only over
    /// satin: Supabase's docs text, bare over swirl, didn't read.
    private static func materialFindings(_ shot: MotionShot, over field: MotionField, scene: String, assets: [MotionAsset]) -> [Finding] {
        let shown = Set(shot.stops.compactMap(\.asset))
        let onGround = { (asset: MotionAsset) in asset.bare == true && asset.glass != true }
        return assets.filter { shown.contains($0.id) && $0.steps == nil && (onGround($0) ? field.isBusy : !$0.isBare) }.map { asset in
            let message = onGround(asset)
                ? "\"\(asset.id)\" is bare over \(field.rawValue), whose light competes with its text: set glass instead."
                : "\"\(asset.id)\" shows over \(field.rawValue) as the page paints it: set glass (a control, card or code) or bare (page text, over satin)."
            return Finding(rule: .material, scene: scene, message: message)
        }
    }

    /// One look a film: its scenes' fields from one family (satin, light, dither or aurora; plain and the halo go
    /// with any), and a seam in a field's language only into a scene of that language. A new technique a
    /// shot is a generated video's tell (`docs/references/style-guide.md`). A cut keeps the ground: bolt.new's
    /// cut in closer on its prompt jumped from a blob of light to two corners of it.
    private static func lookFindings(_ document: MotionDocument) -> [Finding] {
        var findings: [Finding] = []
        let looks: Set<MotionField.Family> = [.satin, .light, .dither, .aurora]
        var first: (family: MotionField.Family, scene: String)?
        var before: MotionField?
        for scene in document.scenes where scene.shot?.kind != .closing {
            let field = scene.field ?? document.canvas.field
            defer { before = field }
            if scene.seam == .cut, let before, before != field, looks.contains(field.family) {
                findings.append(Finding(
                    rule: .look, scene: scene.id,
                    message: "A cut keeps the ground: this scene is over \(field.rawValue), the one before over \(before.rawValue). "
                        + "Give it the same field, or change the ground with a whip or the look's seam."
                ))
            }
            if let family = scene.seam.family, family != .smoke, looks.contains(field.family), field.family != family {
                findings.append(Finding(
                    rule: .look, scene: scene.id, message: "A \(scene.seam.rawValue) seam is drawn in the \(family.rawValue) looks' language; this scene is over \(field.rawValue)."
                ))
            }
            guard looks.contains(field.family) else { continue }
            if let first, first.family != field.family {
                findings.append(Finding(
                    rule: .look, scene: scene.id,
                    message: "One look a film: \(first.scene) is over a \(first.family.rawValue) field, this scene over \(field.rawValue) (\(field.family.rawValue))."
                ))
            } else if first == nil {
                first = (field.family, scene.id)
            }
        }
        return findings
    }

    // MARK: - Timing

    /// A roll's last word must come in early enough to be read before its scene ends: the swaps start
    /// only once the headline is revealed (``DocumentExpansion/rollReading``).
    private static func rollFindings(_ layers: [MotionLayer], scene: MotionScene) -> [Finding] {
        layers.flatMap { layer -> [Finding] in
            guard case .group(let children) = layer.content else { return [] }
            let words = children.filter { $0.id.hasPrefix(layer.id + ".roll") }
            guard let last = words.last, words.count > 1, let entering = last.keyframes[.opacity]?.first?.time else {
                return rollFindings(children, scene: scene)
            }
            let needed = entering + DocumentExpansion.rollTransition + 0.5
            guard needed > scene.duration + 1e-6 else { return [] }
            return [Finding(
                rule: .rollLength, scene: scene.id, layer: layer.id,
                message: "The roll's last word comes in at \(seconds(entering)) s, too late to read: make the scene \(seconds(needed)) s or give the roll fewer words."
            )]
        }
    }

    /// Seconds to a tenth, as findings give them.
    private static func seconds(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    /// A layer's moves at the times they resolve to.
    nonisolated private struct TimedMove {
        let kind: MotionMove.Kind
        let start: Double
        let end: Double
    }

    nonisolated private struct TimedLayer {
        let layer: MotionLayer

        /// The group it's in: its layers start as one staggered move.
        let group: String?

        /// The group it's placed in, the innermost: its position is from that group's.
        var parent: String?

        let moves: [TimedMove]

        /// When a text layer is fully shown, and its character count.
        var shown = 0.0
        var characters = 0
    }

    private static func timed(_ layers: [MotionLayer], in context: MoveContext, group: String?, parent: String? = nil) -> [TimedLayer] {
        layers.flatMap { layer -> [TimedLayer] in
            var context = context
            if case .text(let text) = layer.content {
                context.measure(TextImage(text, scale: 0))
            }
            let moves = layer.moves.map { move in
                let timing = MoveExpansion.timing(of: move, in: context)
                return TimedMove(kind: move.kind, start: timing.start, end: timing.start + timing.duration)
            }
            var timed = TimedLayer(layer: layer, group: group, moves: moves)
            timed.parent = parent
            timed.characters = context.characters
            // Typed text is read as it's typed: Lovable cut away from its voice line 0.1 s after the last letter
            timed.shown = moves.filter { !actions.contains($0.kind) }.map { typedReveals.contains($0.kind) ? $0.start : $0.end }.max() ?? 0
            // A group's layers (a cascade's rows, a roll's words) move as one staggered whole
            if case .group(let children) = layer.content {
                return [timed] + self.timed(children, in: context, group: group ?? layer.id, parent: layer.id)
            }
            return [timed]
        }
    }

    /// `onBeat`: the film is cut to a beat, where a scene's first move lands on its cut (Lovable's tiles and words, the
    /// Spotify Jam's pill): waiting 0.1 s left the ground alone on screen at every cut of an Orca film.
    private static func timingFindings(_ layers: [TimedLayer], scene: MotionScene, isEndCard: Bool, onBeat: Bool, live: [String: Double]) -> [Finding] {
        var findings: [Finding] = []
        let cameraMoves = scene.camera.moves.map { MoveExpansion.timing(of: $0, in: MoveContext(sceneDuration: scene.duration, canvas: .zero)) }
        let cameraMovesAtCut = cameraMoves.contains { $0.start < 0.3 } || scene.seam == .cutOnMotion
        // A burst's and a ripple's own layers carry their start; a group and its layers are one thing
        let starts = layers.flatMap { layer in
            let isGroup = if case .group = layer.layer.content { true } else { false }
            // A shimmer, a wash and a swap aren't entrances: Lovable's end words shimmer from the cut they land on
            return layer.moves.filter { ![.burst, .ripple, .shimmer, .wash, .show, .hide].contains($0.kind) }.map { move in
                (start: move.start, key: layer.group ?? (isGroup ? layer.layer.id : layer.layer.id + "\(move.start)"))
            }
        }.sorted { $0.start < $1.start }

        if let first = starts.first?.start {
            if first < 0.1, !onBeat {
                findings.append(Finding(rule: .firstMove, scene: scene.id, message: "Motion starts at the cut (\(first.formatted()) s): start 0.1–0.3 s after it."))
            } else if first > 0.3, !cameraMovesAtCut {
                findings.append(Finding(rule: .firstMove, scene: scene.id, message: "Nothing moves for \(first.formatted()) s after the cut: start 0.1–0.3 s after it."))
            }
        }
        // At most two primary moves start within 0.1 s; a stagger group counts once
        for (index, start) in starts.enumerated() {
            let together = Set(starts[index...].prefix { $0.start - start.start < 0.1 }.map(\.key))
            if together.count > 2 {
                findings.append(Finding(rule: .simultaneousMoves, scene: scene.id, message: "\(together.count) things start at \(start.start.formatted()) s: stagger them."))
                break
            }
        }
        for timed in layers {
            let entrances = timed.moves.filter { $0.kind != .exit && !$0.kind.isCamera }
            if let exit = timed.moves.first(where: { $0.kind == .exit }), let entrance = entrances.map({ $0.end - $0.start }).max(),
               exit.end - exit.start >= entrance {
                findings.append(Finding(
                    rule: .exitLength, scene: scene.id, layer: timed.layer.id, message: "Leaves no faster than it came in: an exit is shorter than the entrance."
                ))
            }
            if let typing = timed.moves.first(where: { $0.kind == .type }), Double(timed.characters) / max(typing.end - typing.start, 1e-3) > fastestTyping {
                findings.append(Finding(rule: .typingRate, scene: scene.id, layer: timed.layer.id, message: "Typed faster than 25 characters a second."))
            }
        }
        let stillest = layers.contains { $0.moves.contains { designMoves.contains($0.kind) } } ? designStillness : longestStillness
        if !isEndCard, let gap = longestStillness(layers, scene: scene, cameraMoves: cameraMoves, live: live), gap.length > stillest {
            findings.append(Finding(
                rule: .stillness, scene: scene.id,
                message: "Nothing moves and nothing new is read from \(gap.start.formatted()) s for \(gap.length.formatted(.number.precision(.fractionLength(1)))) s."
            ))
        }
        return findings
    }

    /// The longest stretch with no move running, no text being read and no live take playing.
    private static func longestStillness(
        _ layers: [TimedLayer], scene: MotionScene, cameraMoves: [(start: Double, duration: Double)], live: [String: Double]
    ) -> (start: Double, length: Double)? {
        var busy = cameraMoves.filter { $0.duration > 0 }.map { ($0.start, $0.start + $0.duration) }
        for timed in layers {
            busy += timed.moves.map { ($0.start, $0.end) }
            if case .text(let text) = timed.layer.content {
                busy.append((timed.shown, timed.shown + ReadingTime.hold(for: text.text)))
            }
            // A live take plays from the scene's start, its last frame held after it
            if case .lifted(let lifted) = timed.layer.content, let duration = live[lifted.asset] {
                busy.append((0, duration))
            }
        }
        var gap: (start: Double, length: Double)?
        var reached = 0.0
        for (start, end) in busy.sorted(by: { $0.0 < $1.0 }) {
            if start - reached > gap?.length ?? 0 {
                gap = (reached, start - reached)
            }
            reached = max(reached, end)
        }
        if scene.duration - reached > gap?.length ?? 0 {
            gap = (reached, scene.duration - reached)
        }
        return gap
    }

    // MARK: - Text

    private static func textFindings(_ layers: [TimedLayer], scene: MotionScene, canvas: MotionCanvas, context: MoveContext) -> [Finding] {
        var findings: [Finding] = []
        let safe = LayoutRules.safeArea(of: canvas.size)
        for timed in layers {
            guard case .text(let text) = timed.layer.content else { continue }
            let id = timed.layer.id
            if text.size < LayoutRules.minimumTextSize(of: canvas.size) {
                findings.append(Finding(rule: .textSize, scene: scene.id, layer: id, message: "Text under 32 px at 1080p isn't read on a phone."))
            }
            // A control's label is read against the control and at a glance, with the click that changes it
            let controls = self.controls(under: timed, at: timed.shown, in: layers, context: context)
            let control = controls.last
            // Read against the nearest fill under it: a chip's translucent tint shows the tile under it
            let contrast = LayoutRules.contrast(text.color, controls.last { $0.filled }?.color ?? canvas.background)
            if contrast < LayoutRules.minimumContrast(forSize: text.size, canvas: canvas.size) {
                let ratio = contrast.formatted(.number.precision(.fractionLength(1)))
                findings.append(Finding(rule: .contrast, scene: scene.id, layer: id, message: "Contrast \(ratio):1 against the background is too low."))
            }
            let leaves = timed.moves.first { $0.kind == .exit }?.start ?? scene.duration
            if timed.group == nil, control == nil, timed.shown > 0, leaves - timed.shown < ReadingTime.hold(for: text.text) - 1e-6 {
                let held = (leaves - timed.shown).formatted(.number.precision(.fractionLength(1)))
                let needed = ReadingTime.hold(for: text.text).formatted(.number.precision(.fractionLength(1)))
                findings.append(Finding(rule: .readingTime, scene: scene.id, layer: id, message: "Held \(held) s once shown; \"\(text.text)\" needs \(needed) s."))
            }
            // At rest, as laid out: top-level layers only, whose position is on the canvas. A voice line follows its caret
            // and runs off to the left on purpose (spec 0015)
            let size = TextImage(text, scale: 0).size
            let transform = timed.layer.transform
            let frame = CGRect(
                x: transform.position.x - transform.anchor.x * size.width * transform.scale, y: transform.position.y - transform.anchor.y * size.height * transform.scale,
                width: size.width * transform.scale, height: size.height * transform.scale
            )
            let isVoice = timed.layer.moves.contains { $0.kind == .voice }
            if scene.layers.contains(where: { $0.id == id }), !isVoice, transform.rotation == .zero, transform.position.z == 0, !safe.contains(frame.insetBy(dx: 1, dy: 1)) {
                findings.append(Finding(rule: .safeArea, scene: scene.id, layer: id, message: "Text reaches outside the safe area (90% of the frame)."))
            }
        }
        return findings
    }

    /// The rectangles `text` sits in at `time`, bottom first, where their morphs have taken them then, beside it in the same
    /// group or at the top: a pill's label (spec 0014), a tile's name and its chip. Their colours then, and whether each is
    /// filled or an outline.
    private static func controls(under text: TimedLayer, at time: Double, in layers: [TimedLayer], context: MoveContext) -> [Control] {
        guard case .text(let content) = text.layer.content else { return [] }
        let middle = centre(of: text.layer, size: TextImage(content, scale: 0).size, at: time, context: context)
        let shapes = layers.filter { $0.parent == text.parent && $0.layer.id != text.layer.id }.compactMap { timed -> Control? in
            // On screen then: come in, not gone
            let entrance = timed.moves.filter { !actions.contains($0.kind) }.map(\.start).min() ?? 0
            let exit = timed.moves.filter { $0.kind == .exit }.map(\.start).min() ?? .infinity
            guard case .shape(let shape) = timed.layer.content, !shape.isGlyph, entrance <= time, time < exit else { return nil }
            let state = ShapeMorph(shape, moves: timed.layer.moves, context: context)?.state(at: time)
                ?? ShapeMorph.State(size: shape.size, radius: shape.cornerRadius, color: shape.color, stroke: shape.stroke ?? 0)
            let place = centre(of: timed.layer, size: state.size, at: time, context: context)
            let box = CGRect(x: place.x - state.size.width / 2, y: place.y - state.size.height / 2, width: state.size.width, height: state.size.height)
            return Control(box: box, color: state.color, filled: state.stroke == 0 && state.color.alpha >= 0.5)
        }
        return shapes.filter { $0.box.contains(middle) }
    }

    /// A rectangle as a label sees it: where it is, its colour, and whether that's a fill or only an outline.
    nonisolated private struct Control {
        let box: CGRect
        let color: RGBAColor
        let filled: Bool
    }

    /// A layer's middle at `time`, its morphs' and scrolls' places applied, in its parent's space.
    private static func centre(of layer: MotionLayer, size: CGSize, at time: Double, context: MoveContext) -> CGPoint {
        let base = CGPoint(x: layer.transform.position.x, y: layer.transform.position.y)
        let place = MoveExpansion.placeTracks(of: layer.moves, from: base, in: context)
        let anchor = layer.transform.anchor
        return CGPoint(
            x: base.x + (place[.positionX] ?? []).reduce(0) { $0 + $1.value(at: time) } + (0.5 - anchor.x) * size.width * layer.transform.scale,
            y: base.y + (place[.positionY] ?? []).reduce(0) { $0 + $1.value(at: time) } + (0.5 - anchor.y) * size.height * layer.transform.scale
        )
    }
}

// MARK: - Beats

nonisolated extension MotionLint {

    /// Under a beat, every scene is a whole number of beats, so its cuts land on them: a cut off the grid moves a drop or a
    /// break by up to half a beat (spec 0015).
    private static func beatFindings(_ document: MotionDocument) -> [Finding] {
        guard let style = SoundRules.beat(document.sound.style) else { return [] }
        let (beat, frame) = (style.beat, 1 / Double(document.canvas.frameRate))
        return document.scenes.compactMap { scene in
            let beats = scene.duration / beat
            guard abs(beats - beats.rounded()) * beat > frame else { return nil }
            let (shorter, longer) = (max(beats.rounded(.down), 1) * beat, beats.rounded(.up) * beat)
            return Finding(
                rule: .beats, scene: scene.id,
                message: "\(seconds(scene.duration)) s isn't a whole number of \(beat.formatted(.number.precision(.fractionLength(3)))) s beats: make it "
                    + "\(shorter.formatted(.number.precision(.fractionLength(3)))) or \(longer.formatted(.number.precision(.fractionLength(3)))) s."
            )
        }
    }
}
