//
//  ShotLayout+Macro.swift
//  Reco
//

import CoreGraphics

/// New Raycast's macro as the film the user approved shot it (spec 0012, L0 and the port): one control so
/// close the frame cuts it off, the camera holding on part of it, creeping, then whipping to the next part.
/// The film's cameras were keyed by hand; these rules make them from the stops' views, so an agent names
/// what to look at and never a camera position.
nonisolated extension ShotLayout {

    /// The opening: the ground alone, then the control cut in (Raycast's bar at 1.0 s).
    static let macroBreath = 1.0

    /// Over each hold the camera creeps 3 % closer (the film's 1.2–3 %); the opening instead pulls back
    /// 4.5 % after the cut in (its 14 → 13.35×).
    static let macroCreep = 0.03
    static let macroOpeningPull = 0.045

    /// Typing starts this long after the control shows (the film's 0.65 s).
    static let macroTypingDelay = 0.65

    /// A view fills this much of the frame in the direction it fills first, its edges just inside.
    static let macroFill = 0.92

    /// The widest an element shows, in pixels at 1080p: a lift is at most 8,192 px wide, so a 1080p export
    /// is as sharp as the page and a 4K one within twice its lift (the film's bar was 8,064 px at 14×).
    static let macroWidest = 8192.0

    /// An element whose size isn't known yet, in CSS pixels.
    static let macroUnmeasured = CGSize(width: 640, height: 400)

    /// The gap between two elements a macro shows, stacked as a page would have them.
    static let macroGap = 64.0

    /// A selection's presses: down to the lifted ones from 0.55 s, 0.47 s apart, then back up to the
    /// first, 0.58 s after and 0.14 s apart, as the film stepped through its results.
    static let macroPresses = (first: 0.55, down: 0.47, turn: 0.58, up: 0.14)

    /// "Typed long ago": a field typed into by an earlier scene shows its text from the start.
    static let typedBefore = -60.0

    static func macro(_ shot: MotionShot, in context: Context) -> Layout {
        let size = context.size
        let unit = size.height / 1080
        let stops = shot.stops
        guard !stops.isEmpty else { return Layout() }
        let shows = context.index == 0 ? macroBreath : 0

        // Each element once, at a CSS pixel a 1080p pixel, stacked in the order they're first framed
        var frames: [String: CGRect] = [:]
        var layout = Layout()
        var top = 0.0
        for asset in stops.compactMap(\.asset) where frames[asset] == nil {
            let css = context.sizes[asset] ?? macroUnmeasured
            let frame = CGRect(x: 0, y: top, width: css.width * unit, height: css.height * unit)
            frames[asset] = frame
            top = frame.maxY + macroGap * unit
            var layer = uiLayer("\(context.scene.id).ui\(layout.layers.count)", asset: asset, width: frame.width, at: [frame.midX, frame.midY, 0])
            if case .lifted(var content) = layer.content, let source = context.assets[asset] {
                content.typingStart = typingStart(of: source, shows: shows, in: context)
                content.presses = presses(of: source, shows: shows)
                layer.content = .lifted(content)
            }
            if shows > 0 {
                layer.keyframes[.opacity] = [Keyframe(time: 0, value: 0, easing: .hold), Keyframe(time: shows, value: 1)]
            }
            layout.layers.append(layer)
        }

        // What each stop frames, and how close that takes the camera
        let views = stops.compactMap { stop -> (region: CGRect, zoom: Double)? in
            guard let asset = stop.asset, let frame = frames[asset] else { return nil }
            let view = stop.view ?? defaultView(of: frame.size, unit: unit, in: size)
            let region = CGRect(x: frame.minX + view.minX * unit, y: frame.minY + view.minY * unit, width: view.width * unit, height: view.height * unit)
            let fits = macroFill * min(size.width / max(region.width, 1), size.height / max(region.height, 1))
            return (region, min(max(fits, 1), max(macroWidest * unit / frame.width, 1)))
        }

        layout.camera = macroCamera(framing: views, after: shows, in: context)
        return layout
    }

    /// The camera on the first view, holding on each in turn (holds share the scene after the opening and
    /// the whips), creeping closer, and whipping to the next.
    private static func macroCamera(framing views: [(region: CGRect, zoom: Double)], after shows: Double, in context: Context) -> MotionCamera {
        var camera = MotionCamera()
        guard let first = views.first else { return camera }
        let whip = MoveExpansion.whipDuration
        let hold = max((context.scene.duration - shows - whip * Double(views.count - 1)) / Double(views.count), 0.1)
        camera.position = [first.region.midX, first.region.midY, CameraProjection.dolly(forZoom: first.zoom, canvas: context.size)]
        var time = shows
        for (index, view) in views.enumerated() {
            let opening = context.index == 0 && index == 0
            var creep = MotionMove(opening ? .pullBack : .push, start: time, duration: hold)
            creep.intensity = opening ? macroOpeningPull / MoveExpansion.pullBackZoom : macroCreep / MoveExpansion.pushZoom
            camera.moves.append(creep)
            time += hold
            guard index + 1 < views.count else { break }
            let next = views[index + 1]
            var move = MotionMove(.whip, start: time, duration: whip)
            move.target = CGPoint(x: next.region.midX, y: next.region.midY)
            move.intensity = next.zoom / (view.zoom * (opening ? 1 : 1 + macroCreep))
            camera.moves.append(move)
            time += whip
        }
        return camera
    }

    /// Without a view, the element's top-left corner in the frame's shape, half its width across: where a
    /// search field's icon and placeholder are. In CSS pixels.
    private static func defaultView(of frame: CGSize, unit: Double, in canvas: CGSize) -> CGRect {
        let width = 0.5 * frame.width / unit
        return CGRect(x: 0, y: 0, width: width, height: width * canvas.height / canvas.width)
    }

    /// When a typing asset's text is typed: shown typed when an earlier macro typed the same text into
    /// the same field (the film's results, after its search), else a beat after the control shows.
    private static func typingStart(of asset: MotionAsset, shows: Double, in context: Context) -> Double? {
        guard let typing = asset.typing, !typing.text.isEmpty else { return nil }
        let typedEarlier = context.earlierShots.filter { $0.kind == .macro }.flatMap(\.stops).contains { stop in
            guard let other = stop.asset.flatMap({ context.assets[$0] }), let typed = other.typing else { return false }
            return other.url == asset.url && other.selector == asset.selector && typed.field == typing.field && typed.text == typing.text
        }
        return typedEarlier ? typedBefore : shows + macroTypingDelay
    }

    /// A selection's presses: down through the results lifted selected, then back to the first.
    private static func presses(of asset: MotionAsset, shows: Double) -> [UIContent.Press]? {
        guard let count = asset.typing?.select, count > 0 else { return nil }
        let timing = macroPresses
        let downs = (0..<count).map { UIContent.Press(key: .arrowDown, time: shows + timing.first + timing.down * Double($0)) }
        let turn = shows + timing.first + timing.down * Double(count - 1) + timing.turn
        let ups = (0..<count).map { UIContent.Press(key: .arrowUp, time: turn + timing.up * Double($0)) }
        return downs + ups
    }
}
