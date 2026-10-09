//
//  AreaSelectionViewTests.swift
//  RecoTests
//

import AppKit
import Testing
@testable import Reco

@MainActor
struct AreaSelectionViewTests {

    /// Records what the view tells its delegate, so a selection's becoming confirmable is visible
    /// without the overlay's own buttons
    private final class Spy: AreaSelectionViewDelegate {
        var confirmable: [Bool] = []
        var confirmed: CGRect?
        var startedDrawing = 0

        func areaSelectionView(_ view: AreaSelectionView, didConfirmSelection rect: CGRect, on screen: NSScreen) {
            confirmed = rect
        }

        func areaSelectionViewDidCancel(_ view: AreaSelectionView) {}

        func areaSelectionViewDidBeginDrawing(_ view: AreaSelectionView) {
            startedDrawing += 1
        }

        func areaSelectionView(_ view: AreaSelectionView, canConfirm: Bool) {
            confirmable.append(canConfirm)
        }
    }

    private func makeView(showsActions: Bool, frozenScreen: CGImage? = nil) throws -> (AreaSelectionView, Spy) {
        let screen = try #require(NSScreen.screens.first)
        let view = AreaSelectionView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            screen: screen,
            confirmsOnRelease: false,
            showsActions: showsActions,
            frozenScreen: frozenScreen
        )
        let spy = Spy()
        view.delegate = spy
        return (view, spy)
    }

    private func mouse(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type,
                location: point,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
    }

    /// Drags from `origin` to `end`, the way a user draws an area
    private func draw(_ view: AreaSelectionView, from origin: CGPoint, to end: CGPoint) throws {
        view.mouseDown(with: try mouse(.leftMouseDown, at: origin))
        view.mouseDragged(with: try mouse(.leftMouseDragged, at: end))
        view.mouseUp(with: try mouse(.leftMouseUp, at: end))
    }

    // MARK: - Confirmability

    /// The toolbar's Record confirms the selection it opened, so the overlay has to report it as
    /// confirmable even though it draws no buttons of its own
    @Test func aDrawnAreaIsConfirmableWithoutTheOverlaysOwnButtons() throws {
        let (view, spy) = try makeView(showsActions: false)

        try draw(view, from: CGPoint(x: 60, y: 60), to: CGPoint(x: 360, y: 260))

        #expect(spy.confirmable == [true])
        #expect(view.subviews.isEmpty)
    }

    @Test func aDrawnAreaIsConfirmableWithTheOverlaysOwnButtons() throws {
        let (view, spy) = try makeView(showsActions: true)

        try draw(view, from: CGPoint(x: 60, y: 60), to: CGPoint(x: 360, y: 260))

        #expect(spy.confirmable == [true])
        #expect(!view.subviews.isEmpty)
    }

    @Test func drawingAgainTakesConfirmabilityAwayUntilSomethingIsDrawn() throws {
        let (view, spy) = try makeView(showsActions: false)
        try draw(view, from: CGPoint(x: 60, y: 60), to: CGPoint(x: 360, y: 260))

        // A press outside the area starts a new one
        view.mouseDown(with: try mouse(.leftMouseDown, at: CGPoint(x: 600, y: 600)))

        #expect(spy.confirmable == [true, false])
    }

    /// Nothing drawn, nothing to confirm: a press that starts a selection on its own is not one
    @Test func anEmptyOverlayHasNothingToConfirm() throws {
        let (view, spy) = try makeView(showsActions: false)

        view.mouseDown(with: try mouse(.leftMouseDown, at: CGPoint(x: 60, y: 60)))
        view.mouseUp(with: try mouse(.leftMouseUp, at: CGPoint(x: 60, y: 60)))

        #expect(spy.confirmable.isEmpty)
        #expect(spy.confirmed == nil)
    }

    // MARK: - Loupe

    /// A picture of the screen at 2 px per point.
    private func frozenScreen(of screen: NSScreen) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: Int(screen.frame.width) * 2, height: Int(screen.frame.height) * 2, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        return try #require(context.makeImage())
    }

    @Test func theLoupeFollowsThePointerOverAFrozenScreenAndRestsWithTheSelection() throws {
        let screen = try #require(NSScreen.screens.first)
        let (view, _) = try makeView(showsActions: false, frozenScreen: try frozenScreen(of: screen))

        view.mouseMoved(with: try mouse(.mouseMoved, at: CGPoint(x: 100, y: 500)))
        let loupe = try #require(view.loupe)
        #expect(loupe.frame == LoupeGeometry.frame(beside: CGPoint(x: 100, y: 500), in: view.bounds))
        #expect(loupe.pixel == CGPoint(x: 200, y: (screen.frame.height - 500) * 2))

        // Drawing keeps it on the pointer, and the release leaves it over the corner it ends on
        view.mouseDown(with: try mouse(.leftMouseDown, at: CGPoint(x: 100, y: 500)))
        view.mouseDragged(with: try mouse(.leftMouseDragged, at: CGPoint(x: 400, y: 300)))
        #expect(view.loupe?.pixel == CGPoint(x: 800, y: (screen.frame.height - 300) * 2))
        view.mouseUp(with: try mouse(.leftMouseUp, at: CGPoint(x: 400, y: 300)))
        #expect(view.loupe != nil)

        // Inside the drawn selection, where the buttons are, it goes away; over a handle it's back
        view.mouseMoved(with: try mouse(.mouseMoved, at: CGPoint(x: 250, y: 400)))
        #expect(view.loupe == nil)
        view.mouseMoved(with: try mouse(.mouseMoved, at: CGPoint(x: 400, y: 500)))
        #expect(view.loupe != nil)

        // Gone when the pointer leaves the display
        let exit = try #require(NSEvent.enterExitEvent(
            with: .mouseExited, location: CGPoint(x: 400, y: 500), modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 0, trackingNumber: 0, userData: nil
        ))
        view.mouseExited(with: exit)
        #expect(view.loupe == nil)
    }

    @Test func theLoupeDrawsTheScreensPixelsTheRightWayUp() throws {
        // Red, with green two pixels right of (10, 20), blue two below and yellow two above, from the top-left corner
        let context = try #require(CGContext(
            data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        for (color, column, row) in [(NSColor.green, 12, 20), (.blue, 10, 22), (.yellow, 10, 18)] {
            context.setFillColor(color.cgColor)
            // CGContext fills with a bottom-left origin
            context.fill(CGRect(x: column, y: 99 - row, width: 1, height: 1))
        }
        let loupe = LoupeView(image: try #require(context.makeImage()))
        loupe.pixel = CGPoint(x: 10, y: 20)

        let rep = try #require(loupe.bitmapImageRepForCachingDisplay(in: loupe.bounds))
        loupe.cacheDisplay(in: loupe.bounds, to: rep)

        // Cells are 4 points; two cells from the centre (60, 60) is 8 points. The rep counts pixels from its top-left corner
        let scale = rep.pixelsWide / Int(loupe.bounds.width)
        let channels = { (column: Int, row: Int) -> [CGFloat] in
            let color = rep.colorAt(x: column * scale, y: row * scale)?.usingColorSpace(.deviceRGB)
            // Which channels are on: the named colours come back through the device space a shade off
            return [color?.redComponent ?? -1, color?.greenComponent ?? -1, color?.blueComponent ?? -1].map { $0 > 0.5 ? 1 : 0 }
        }
        #expect(channels(68, 60) == [0, 1, 0])
        #expect(channels(60, 68) == [0, 0, 1])
        #expect(channels(60, 52) == [1, 1, 0])
        #expect(channels(52, 60) == [1, 0, 0])
    }

    @Test func thereIsNoLoupeOverTheLiveScreen() throws {
        let (view, _) = try makeView(showsActions: false)

        view.mouseMoved(with: try mouse(.mouseMoved, at: CGPoint(x: 100, y: 500)))

        #expect(view.loupe == nil)
    }

    @Test func confirmingTheDrawnAreaReportsItsScreenRect() throws {
        let (view, spy) = try makeView(showsActions: false)
        let screen = try #require(NSScreen.screens.first)
        try draw(view, from: CGPoint(x: 60, y: 60), to: CGPoint(x: 360, y: 260))

        view.confirmSelectionIfValid()

        let expected = CGRect(x: 60, y: 60, width: 300, height: 200)
            .offsetBy(dx: screen.frame.origin.x, dy: screen.frame.origin.y)
        #expect(spy.confirmed == expected)
    }
}
