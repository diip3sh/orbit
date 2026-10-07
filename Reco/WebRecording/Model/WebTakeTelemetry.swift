//
//  WebTakeTelemetry.swift
//  Reco
//

import CoreGraphics
import Foundation

/// A web take's telemetry, recorded frame by frame as it renders: the cursor where it moved, the
/// clicks, the scrolling, and the cursor's shape where it changed.
///
/// Locations are viewport CSS pixels. The one ``InputTelemetry/Geometry`` entry maps them into the
/// video by the script's scale.
nonisolated struct WebTakeTelemetry: Sendable {

    private(set) var telemetry: InputTelemetry

    /// Each cursor kind shown so far with its sprite id, in the order they appeared.
    private(set) var spriteKinds: [CursorKind] = []

    init(script: WebScript) {
        let viewport = CGRect(origin: .zero, size: script.viewport)
        telemetry = InputTelemetry(
            capture: .init(kind: .web, videoSize: script.videoSize, cursorInVideo: false),
            // Nothing is typed in a take, so there are no keystrokes to miss
            keystrokesAvailable: true,
            geometry: [.init(time: 0, screenRect: viewport, contentRect: viewport, contentScale: 1, scaleFactor: CGFloat(script.scale))]
        )
    }

    /// Records one frame at `time`: where the cursor is, if anywhere, the presses and releases
    /// delivered with it, the cursor's shape, `nil` for the arrow, and how far the page scrolled
    /// since the last frame, as a wheel would report it (negative going down the page).
    mutating func record(time: Double, cursor location: CGPoint?, presses: [WebScript.Press], shape: CursorKind?, scrolled: CGVector? = nil) {
        if let scrolled, scrolled != .zero {
            let viewport = telemetry.geometry[0].contentRect
            telemetry.scrolls.append(.init(time: time, location: location ?? CGPoint(x: viewport.midX, y: viewport.midY), delta: scrolled))
        }
        guard let location else { return }
        if telemetry.cursor.last?.location != location {
            telemetry.cursor.append(.init(time: time, location: location))
        }
        for press in presses {
            telemetry.clicks.append(.init(time: time, location: location, button: .left, isDown: press.isDown, clickCount: 1))
        }
        let kind = shape ?? .arrow
        let sprite = spriteKinds.firstIndex(of: kind) ?? {
            spriteKinds.append(kind)
            return spriteKinds.count - 1
        }()
        if telemetry.cursorShapes.last?.sprite != sprite {
            telemetry.cursorShapes.append(.init(time: time, sprite: sprite))
        }
    }

    /// The finished telemetry, with each kind's sprite from `sprite(kind, id)`.
    func finished(sprite: (CursorKind, Int) -> InputTelemetry.CursorSprite?) -> InputTelemetry {
        var telemetry = telemetry
        telemetry.cursorSprites = spriteKinds.enumerated().compactMap { sprite($0.element, $0.offset) }
        return telemetry
    }
}
