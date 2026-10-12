//
//  DocumentExpansion+Editorial.swift
//  Reco
//

import CoreGraphics

/// Editorial films' wordmark opening out of its mark (spec 0017), measured on ElevenLabs' launch film (4.43–6.3 s).
nonisolated extension DocumentExpansion {

    /// A group of a mark, a name (one text or more, such as a bold word and a regular one) and, with three layers or more, a
    /// tagline last, laid out as it ends, unfolding: the mark alone where the whole line's middle
    /// will be, the line 1.125× its size; the mark parts to its place as the name is typed out of it, the two centred; then the
    /// line slides to its place as the tagline is swept in, settling to its size. Moves a child already has are kept, and so
    /// are keyframes set by hand; the unfold stays on the group for its sound.
    static func unfolded(_ group: MotionLayer, sizes: [String: CGSize], context: MoveContext) -> MotionLayer {
        guard let unfold = group.moves.first(where: { $0.kind == .unfold }), case .group(var children) = group.content, children.count > 1 else { return group }
        let start = MoveExpansion.timing(of: unfold, in: context).start
        let boxes = children.map { box(of: $0, sizes: sizes) }
        let tagline = children.count > 2 ? children.count - 1 : nil
        let whole = boxes.dropFirst().reduce(boxes[0]) { $0.union($1) }
        let named = boxes.indices.filter { $0 != tagline }.map { boxes[$0] }.reduce(boxes[0]) { $0.union($1) }
        let (grown, position) = (MoveExpansion.unfoldScale, group.transform.position)
        let (slide, settle) = (MoveExpansion.unfoldSlide, MoveExpansion.unfoldSettle)
        var group = group
        let unset = { (property: MotionProperty, keyframes: [Keyframe]) in
            if group.keyframes[property] == nil {
                group.keyframes[property] = keyframes
            }
        }
        // The mark and name centred where the whole line's middle ends, grown; then the line to its place
        unset(.positionX, [
            Keyframe(time: start + slide.start, value: position.x + whole.midX - grown * named.midX, easing: MoveExpansion.unfoldSlideEasing),
            Keyframe(time: start + slide.start + slide.duration, value: position.x)
        ])
        let settling = MotionEasing.spring(response: settle.response)
        unset(.scale, [Keyframe(time: start + settle.start, value: grown, easing: settling), Keyframe(time: start + settle.start + settle.duration, value: 1)])
        // Grown about the group's place: its line kept where it ends, up and down
        unset(.positionY, [
            Keyframe(time: start + settle.start, value: position.y + whole.midY * (1 - grown), easing: settling),
            Keyframe(time: start + settle.start + settle.duration, value: position.y)
        ])
        // The mark from the middle of the mark and name to its place
        if children[0].keyframes[.positionX] == nil {
            let place = children[0].transform.position.x
            children[0].keyframes[.positionX] = [
                Keyframe(time: start, value: place + named.midX - boxes[0].midX, easing: MoveExpansion.unfoldPartEasing),
                Keyframe(time: start + MoveExpansion.unfoldPart, value: place)
            ]
        }
        // The name typed out of the mark before the line slides, its parts one after another; the tagline swept in
        let letters = { (layer: MotionLayer) -> Double in
            guard case .text(let text) = layer.content else { return 0 }
            return Double(text.text.count)
        }
        let name = children.indices.dropFirst().filter { $0 != tagline }.map { letters(children[$0]) }.reduce(0, +)
        let perLetter = min(MoveExpansion.unfoldLetter, (slide.start - MoveExpansion.unfoldTyping) / max(name, 1))
        var typed = start + MoveExpansion.unfoldTyping
        for index in children.indices.dropFirst() where letters(children[index]) > 0 {
            let duration = perLetter * letters(children[index])
            defer { typed += index == tagline ? 0 : duration }
            guard !children[index].moves.contains(where: \.kind.needsText) else { continue }
            children[index].moves.insert(
                index == tagline ? MotionMove(.sweep, start: start + MoveExpansion.unfoldTagline) : MotionMove(.type, start: typed, duration: duration), at: 0
            )
        }
        group.content = .group(children)
        return group
    }

    /// `layer`'s box in its parent's space.
    private static func box(of layer: MotionLayer, sizes: [String: CGSize]) -> CGRect {
        let size: CGSize = if case .text(let text) = layer.content { TextImage(text, scale: 0).size } else { MotionPlan.size(of: layer.content, sizes: sizes) }
        let (width, height) = (size.width * layer.transform.scale, size.height * layer.transform.scale)
        let (place, anchor) = (layer.transform.position, layer.transform.anchor)
        return CGRect(x: place.x - anchor.x * width, y: place.y - anchor.y * height, width: width, height: height)
    }
}
