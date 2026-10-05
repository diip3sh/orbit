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

    private func makeView(showsActions: Bool) throws -> (AreaSelectionView, Spy) {
        let screen = try #require(NSScreen.screens.first)
        let view = AreaSelectionView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            screen: screen,
            confirmsOnRelease: false,
            showsActions: showsActions
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
