//
//  PointerTrack.swift
//  Reco
//

import CoreGraphics

/// The cursor's location through a take, asked frame by frame in time order.
///
/// During a clip the cursor follows its target's element, so it stays on it if the page moves it,
/// until the clip types. Between clips it rests where it was, as a real mouse does while the page
/// scrolls under it, and travels from there to the next target.
nonisolated struct PointerTrack: Sendable {

    let script: WebScript

    /// Where the cursor was when it last followed a target, in viewport CSS pixels.
    private var rest: CGPoint?

    init(script: WebScript) {
        self.script = script
    }

    /// The selectors whose elements place the cursor at `time`.
    func selectors(at time: Double) -> [String] {
        let targets: [WebTarget] = switch script.pointerPosition(at: time) {
        case .following(let target): [target]
        case .resting(let target): rest == nil ? [target] : []
        case .travelling(let start, let end, _): rest == nil ? [start, end] : [end]
        case nil: []
        }
        return targets.compactMap(\.selector)
    }

    /// Where the cursor is at `time`, in viewport CSS pixels, given the frames of the elements the
    /// targets' selectors matched now. `nil` when the Cursor lane is empty. Like a mouse on a
    /// screen, it stays inside the viewport, even when its element is out of view.
    mutating func location(at time: Double, elementFrames: [String: CGRect]) -> CGPoint? {
        let viewport = CGRect(origin: .zero, size: script.viewport)
        let inView = { (point: CGPoint) in CGPoint(x: min(max(point.x, 0), viewport.maxX - 1), y: min(max(point.y, 0), viewport.maxY - 1)) }
        let locate = { (target: WebTarget) in inView(target.location(elementFrame: target.selector.flatMap { elementFrames[$0] })) }
        switch script.pointerPosition(at: time) {
        case .following(let target):
            let location = locate(target)
            rest = location
            return location
        case .resting(let target):
            return rest ?? locate(target)
        case .travelling(let start, let end, let progress):
            // The arc may bow past an edge the targets are near
            return inView(WebScript.travelPoint(from: rest ?? locate(start), to: locate(end), progress: progress))
        case nil:
            return nil
        }
    }
}
