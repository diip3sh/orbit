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
        case sceneLengths, typingRate, stillness, hookLength, endingLength, rollLength, busyField, material
    }

    nonisolated struct Finding: Equatable, Sendable {
        let rule: Rule
        let scene: String
        var layer: String?
        let message: String
    }

    /// Nothing moving and nothing to read for longer than this is a frozen stretch.
    static let longestStillness = 1.5

    /// Typing faster than the fastest reference (25 characters a second) reads as a paste.
    static let fastestTyping = 25.0

    static func findings(in document: MotionDocument, sizes: [String: CGSize] = [:]) -> [Finding] {
        let expanded = DocumentExpansion.expanded(document, sizes: sizes)
        var findings: [Finding] = []
        // Live takes and how long they play, as record_page times them
        let live = document.assets.reduce(into: [String: Double]()) { live, asset in
            if let plan = try? asset.takePlan() {
                live[asset.id] = plan.duration
            }
        }
        for (scene, source) in zip(expanded.scenes, document.scenes) {
            let context = MoveContext(sceneDuration: scene.duration, canvas: document.canvas.size)
            let layers = timed(scene.layers, in: context, group: nil)
            findings += textFindings(layers, scene: scene, canvas: document.canvas)
            findings += timingFindings(layers, scene: scene, isEndCard: source.shot?.kind.isEnding == true, live: live)
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
            if let shot = source.shot, shot.kind == .macro, (source.field ?? document.canvas.field) == .satin {
                findings += materialFindings(shot, scene: scene.id, assets: document.assets)
            }
            if let field = source.field, field.isBusy {
                findings.append(Finding(rule: .busyField, scene: scene.id, message: "The \(field.rawValue) field competes with what's over it: use plain or satin."))
            }
        }
        if document.canvas.field.isBusy, let first = document.scenes.first {
            findings.append(Finding(
                rule: .busyField, scene: first.id, message: "The canvas's \(document.canvas.field.rawValue) field competes with what's over it: use plain or satin."
            ))
        }
        let lengths = document.scenes.map(\.duration)
        if lengths.count >= 4, let longest = lengths.max(), let shortest = lengths.min(), longest < 3 * shortest {
            findings.append(Finding(
                rule: .sceneLengths, scene: document.scenes[0].id,
                message: "The longest scene should be at least 3× the shortest (\(longest.formatted()) s against \(shortest.formatted()) s): vary the pace."
            ))
        }
        return findings
    }

    /// UI in macro over satin is glass or bare: as the page paints it, its fill reads as a flat box cut out
    /// of another picture (the L1 shot the user found "really bad" next to Raycast's).
    private static func materialFindings(_ shot: MotionShot, scene: String, assets: [MotionAsset]) -> [Finding] {
        let shown = Set(shot.stops.compactMap(\.asset))
        return assets.filter { shown.contains($0.id) && $0.steps == nil && !$0.isBare }.map { asset in
            Finding(rule: .material, scene: scene, message: "\"\(asset.id)\" shows over satin as the page paints it: set glass (a control, card or code) or bare (page text).")
        }
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

        let moves: [TimedMove]

        /// When a text layer is fully shown, and its character count.
        var shown = 0.0
        var characters = 0
    }

    private static func timed(_ layers: [MotionLayer], in context: MoveContext, group: String?) -> [TimedLayer] {
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
            timed.characters = context.characters
            timed.shown = moves.filter { $0.kind != .exit }.map(\.end).max() ?? 0
            // A group's layers (a cascade's rows, a roll's words) move as one staggered whole
            if case .group(let children) = layer.content {
                return [timed] + self.timed(children, in: context, group: group ?? layer.id)
            }
            return [timed]
        }
    }

    private static func timingFindings(_ layers: [TimedLayer], scene: MotionScene, isEndCard: Bool, live: [String: Double]) -> [Finding] {
        var findings: [Finding] = []
        let cameraMoves = scene.camera.moves.map { MoveExpansion.timing(of: $0, in: MoveContext(sceneDuration: scene.duration, canvas: .zero)) }
        let cameraMovesAtCut = cameraMoves.contains { $0.start < 0.3 } || scene.seam == .cutOnMotion
        let starts = layers.flatMap { layer in layer.moves.map { (start: $0.start, key: layer.group ?? layer.layer.id + "\($0.start)") } }.sorted { $0.start < $1.start }

        if let first = starts.first?.start {
            if first < 0.1 {
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
        if !isEndCard, let gap = longestStillness(layers, scene: scene, cameraMoves: cameraMoves, live: live), gap.length > longestStillness {
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

    private static func textFindings(_ layers: [TimedLayer], scene: MotionScene, canvas: MotionCanvas) -> [Finding] {
        var findings: [Finding] = []
        let safe = LayoutRules.safeArea(of: canvas.size)
        for timed in layers {
            guard case .text(let text) = timed.layer.content else { continue }
            let id = timed.layer.id
            if text.size < LayoutRules.minimumTextSize(of: canvas.size) {
                findings.append(Finding(rule: .textSize, scene: scene.id, layer: id, message: "Text under 32 px at 1080p isn't read on a phone."))
            }
            let contrast = LayoutRules.contrast(text.color, canvas.background)
            if contrast < LayoutRules.minimumContrast(forSize: text.size, canvas: canvas.size) {
                let ratio = contrast.formatted(.number.precision(.fractionLength(1)))
                findings.append(Finding(rule: .contrast, scene: scene.id, layer: id, message: "Contrast \(ratio):1 against the background is too low."))
            }
            let leaves = timed.moves.first { $0.kind == .exit }?.start ?? scene.duration
            if timed.group == nil, timed.shown > 0, leaves - timed.shown < ReadingTime.hold(for: text.text) - 1e-6 {
                let held = (leaves - timed.shown).formatted(.number.precision(.fractionLength(1)))
                let needed = ReadingTime.hold(for: text.text).formatted(.number.precision(.fractionLength(1)))
                findings.append(Finding(rule: .readingTime, scene: scene.id, layer: id, message: "Held \(held) s once shown; \"\(text.text)\" needs \(needed) s."))
            }
            // At rest, as laid out: top-level layers only, whose position is on the canvas
            let size = TextImage(text, scale: 0).size
            let transform = timed.layer.transform
            let frame = CGRect(
                x: transform.position.x - transform.anchor.x * size.width * transform.scale, y: transform.position.y - transform.anchor.y * size.height * transform.scale,
                width: size.width * transform.scale, height: size.height * transform.scale
            )
            if scene.layers.contains(where: { $0.id == id }), transform.rotation == .zero, transform.position.z == 0, !safe.contains(frame.insetBy(dx: 1, dy: 1)) {
                findings.append(Finding(rule: .safeArea, scene: scene.id, layer: id, message: "Text reaches outside the safe area (90% of the frame)."))
            }
        }
        return findings
    }
}
