//
//  DocumentExpansion.swift
//  Reco
//

import CoreGraphics
import Foundation

/// Turns what the grammar names into what the plan draws: shots into layers and camera moves, a
/// roll into its words, a cascade into its rows' moves. Every other move stays for the plan to
/// expand on its layer (``MoveExpansion``).
nonisolated enum DocumentExpansion {

    /// A roll's words swap in 0.2 s (0.1–0.23 measured on Linear for Agents), moving 0.35 em.
    static let rollTransition = 0.2
    static let rollDistance = 0.35

    /// Rows of a cascade start 2–2.5 frames apart at 30 fps, the whole group within 0.5 s.
    static let cascadeStagger = 0.075
    static let longestStagger = 0.5

    /// - Parameter sizes: The UI assets' sizes in CSS pixels, for those already lifted or measured.
    static func expanded(_ document: MotionDocument, sizes: [String: CGSize]) -> MotionDocument {
        var output = document
        for index in document.scenes.indices {
            var result = laidOut(document, scene: index, sizes: sizes)
            let context = MoveContext(sceneDuration: result.duration, canvas: document.canvas.size)
            result.layers = result.layers.map { expanded($0, in: context) }
            output.scenes[index] = result
        }
        return output
    }

    /// A scene with its shot laid out under its own layers, before rolls and cascades are split: the
    /// layers a person edits.
    static func laidOut(_ document: MotionDocument, scene index: Int, sizes: [String: CGSize]) -> MotionScene {
        let scene = document.scenes[index]
        guard let shot = scene.shot else { return scene }
        var result = scene
        let layout = ShotLayout.layout(shot, in: ShotLayout.Context(scene: scene, index: index, canvas: document.canvas, style: document.style, sizes: sizes))
        let shotLayers = layout.layers.map { layer in
            var layer = layer
            layer.moves = scene.shotMoves[layer.id] ?? layer.moves
            return layer
        }
        result.layers = merged(shotLayers, with: scene.layers)
        result.camera.position = scene.camera.position ?? layout.camera.position
        result.camera.moves = (scene.shotMoves[MotionScene.cameraID] ?? layout.camera.moves) + scene.camera.moves
        result.camera.keyframes = layout.camera.keyframes.merging(scene.camera.keyframes) { $1 }
        return result
    }

    /// A shot's layers with the scene's own: one with a shot layer's id replaces it, the rest go on top.
    private static func merged(_ shotLayers: [MotionLayer], with own: [MotionLayer]) -> [MotionLayer] {
        let replacing = Dictionary(own.map { ($0.id, $0) }) { first, _ in first }
        let shotIDs = Set(shotLayers.map(\.id))
        return shotLayers.map { replacing[$0.id] ?? $0 } + own.filter { !shotIDs.contains($0.id) }
    }

    private static func expanded(_ layer: MotionLayer, in context: MoveContext) -> MotionLayer {
        var layer = layer
        if case .group(let children) = layer.content {
            layer.content = .group(children.map { expanded($0, in: context) })
        }
        if let cascade = layer.moves.first(where: { $0.kind == .cascade }), case .group(let rows) = layer.content {
            layer.moves.removeAll { $0.kind == .cascade }
            layer.content = .group(cascaded(rows, by: cascade))
        }
        if let roll = layer.moves.first(where: { $0.kind == .roll }), case .text(let text) = layer.content {
            layer.moves.removeAll { $0.kind == .roll }
            return rolled(layer, text: text, roll: roll, in: context)
        }
        return layer
    }

    /// Each row rises in turn.
    private static func cascaded(_ rows: [MotionLayer], by cascade: MotionMove) -> [MotionLayer] {
        let start = cascade.start ?? MoveExpansion.entranceStart
        let stagger = rows.count > 1 ? min(cascadeStagger, longestStagger / Double(rows.count - 1)) : 0
        return rows.enumerated().map { index, row in
            var row = row
            var rise = MotionMove(.rise, start: start + Double(index) * stagger, duration: cascade.duration ?? 1.05)
            rise.intensity = cascade.intensity
            row.moves.insert(rise, at: 0)
            return row
        }
    }

    // MARK: - Roll

    /// The text as a group: what comes before its last word, then the last word and each of the
    /// roll's words in its place, one after another. The layer's own moves go on each part, a reveal
    /// timed so the whole line still reveals as one.
    private static func rolled(_ layer: MotionLayer, text: TextContent, roll: MotionMove, in scene: MoveContext) -> MotionLayer {
        var lastWord: Range<String.Index>?
        text.text.enumerateSubstrings(in: text.text.startIndex..., options: .byWords) { _, range, _, _ in lastWord = range }
        let image = TextImage(text, scale: 0)
        guard let lastWord, let box = image.words.last else { return layer }
        let prefix = String(text.text[..<lastWord.lowerBound])
        let words = [String(text.text[lastWord])] + (roll.words ?? [])
        let origin = CGPoint(x: -layer.transform.anchor.x * image.size.width, y: -layer.transform.anchor.y * image.size.height)

        // The layer's reveal over the whole text, split at the last word
        var context = scene
        context.measure(image)
        let reveal = layer.moves.first { $0.kind.needsText }
        let perCharacter = reveal.map { characterTime(of: $0, characters: text.text.count, in: context) } ?? 0
        let revealStart = reveal.map { MoveExpansion.timing(of: $0, in: context).start } ?? 0
        let revealEnd = reveal.map { MoveExpansion.timing(of: $0, in: context) }.map { $0.start + $0.duration } ?? 0
        let start = roll.start ?? (reveal == nil ? 1 : revealEnd + 0.5)
        let interval = (roll.duration ?? 0.5 * Double(words.count - 1)) / Double(max(words.count - 1, 1))

        // A word-by-word reveal goes by words: the part's first word starts at its turn
        let perWord = reveal.map { wordTime(of: $0, words: image.words.count, in: context) } ?? 0

        func part(_ id: String, _ string: String, at point: CGPoint, revealFrom offset: Int, word: Int) -> MotionLayer {
            var content = text
            content.text = string
            content.width = nil
            content.alignment = .leading
            var transform = Transform3D(position: [point.x, point.y, 0])
            transform.anchor = .zero
            let line = LineReveal(start: revealStart, perCharacter: perCharacter, perWord: perWord, context: context)
            let moves = layer.moves.map { move in
                move.kind.needsText ? partReveal(move, of: content, character: offset, word: word, line: line) : move
            }
            return MotionLayer(id: id, content: .text(content), transform: transform, moves: moves)
        }

        var parts: [MotionLayer] = []
        if !prefix.isEmpty {
            parts.append(part("\(layer.id).prefix", prefix, at: prefixOrigin(prefix, of: text, in: image, at: origin), revealFrom: 0, word: 0))
        }
        let offset = text.text.distance(from: text.text.startIndex, to: lastWord.lowerBound)
        let top = origin.y + box.minY
        for (index, word) in words.enumerated() {
            let wordLayer = part(
                "\(layer.id).word\(index)", word, at: .zero, revealFrom: index == 0 ? offset : text.text.count,
                word: index == 0 ? image.words.count - 1 : image.words.count
            )
            // In a group of its own, so the roll's keyframes don't override the moves the word carries
            parts.append(MotionLayer(
                id: "\(layer.id).roll\(index)", content: .group([wordLayer]), transform: Transform3D(position: [origin.x + box.minX, top, 0]),
                keyframes: rollKeyframes(word: index, of: words.count, turns: (start, interval), top: top, distance: rollDistance * text.size)
            ))
        }
        var group = layer
        group.content = .group(parts)
        group.moves = []
        return group
    }

    /// Where a rolled text's prefix, drawn alone and leading, goes so it starts where its first word
    /// was in the whole line: a centred line in a wider box would leave a gap before the rolling word.
    private static func prefixOrigin(_ prefix: String, of text: TextContent, in image: TextImage, at origin: CGPoint) -> CGPoint {
        var alone = text
        alone.text = prefix
        alone.width = nil
        alone.alignment = .leading
        guard let first = image.words.first, let own = TextImage(alone, scale: 0).words.first else { return origin }
        return CGPoint(x: origin.x + first.minX - own.minX, y: origin.y + first.minY - own.minY)
    }

    /// How long a reveal takes per character of a text `characters` long.
    private static func characterTime(of reveal: MotionMove, characters: Int, in context: MoveContext) -> Double {
        let duration = MoveExpansion.timing(of: reveal, in: context).duration
        let count = Double(characters)
        return reveal.kind == .type ? duration / max(count, 1) : (duration - min(0.3, duration)) / max(count - 1, 1)
    }

    /// A reveal over a whole rolled line: when it starts, how far apart its characters and words
    /// start, and where it runs.
    nonisolated private struct LineReveal {
        let start: Double
        let perCharacter: Double
        let perWord: Double
        let context: MoveContext
    }

    /// A reveal on part of a rolled text, starting where the whole line's reaches it: at character
    /// `offset`, or at word `word` for a word-by-word reveal.
    private static func partReveal(_ move: MotionMove, of content: TextContent, character offset: Int, word: Int, line: LineReveal) -> MotionMove {
        var shifted = move
        if move.kind == .wordByWord {
            let words = TextImage(content, scale: 0).words.count
            shifted.start = line.start + Double(word) * line.perWord
            shifted.duration = Double(max(words - 1, 0)) * line.perWord + min(0.45, MoveExpansion.timing(of: move, in: line.context).duration)
            return shifted
        }
        shifted.start = line.start + Double(offset) * line.perCharacter
        shifted.duration = move.kind == .lineMask ? move.duration : Double(content.text.count) * line.perCharacter + (move.kind == .type ? 0 : 0.3)
        return shifted
    }

    /// How far apart a word-by-word reveal's words start, over a text of `words` words.
    private static func wordTime(of reveal: MotionMove, words: Int, in context: MoveContext) -> Double {
        let duration = MoveExpansion.timing(of: reveal, in: context).duration
        return (duration - min(0.45, duration)) / Double(max(words - 1, 1))
    }

    /// Word `index` of a roll's `count` coming in from below at its turn and leaving upwards at the
    /// next's; turns start at `turns.start`, `turns.interval` apart. Keyframes are values, not
    /// changes: from `top`, where the word sits.
    private static func rollKeyframes(
        word index: Int, of count: Int, turns: (start: Double, interval: Double), top: Double, distance: Double
    ) -> [MotionProperty: [Keyframe]] {
        let (start, interval) = turns
        var keyframes: [MotionProperty: [Keyframe]] = [:]
        if index > 0 {
            let entering = start + Double(index - 1) * interval
            keyframes[.opacity] = [Keyframe(time: entering, value: 0, easing: .enter), Keyframe(time: entering + rollTransition, value: 1)]
            keyframes[.positionY] = [Keyframe(time: entering, value: top + distance, easing: .enter), Keyframe(time: entering + rollTransition, value: top)]
        }
        if index < count - 1 {
            let leaving = start + Double(index) * interval
            keyframes[.opacity, default: [Keyframe(time: 0, value: 1)]] += [Keyframe(time: leaving, value: 1, easing: .exit), Keyframe(time: leaving + rollTransition, value: 0)]
            keyframes[.positionY, default: [Keyframe(time: 0, value: top)]] += [
                Keyframe(time: leaving, value: top, easing: .exit), Keyframe(time: leaving + rollTransition, value: top - distance)
            ]
        }
        return keyframes
    }
}
