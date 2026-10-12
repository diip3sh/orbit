//
//  NotchShelfController.swift
//  Reco
//

import AppKit
import SwiftUI

/// Never key, never main, and free to sit over the menu bar and the notch
private final class NotchPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        // The shape is black on black: a shadow would outline the whole rectangle
        hasShadow = false
        level = .statusBar
        isReleasedWhenClosed = false
        // A panel hides when its app isn't active, which Reco rarely is
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        // The view animates itself
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// A window is kept below the menu bar by default
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Takes the pointer only where the shelf is, and reports it entering and leaving there. The window is
/// much bigger than the shape (it never resizes, so the shape never outgrows it), so what is outside the
/// `activeRect` (screen coordinates) must neither be hit nor tracked.
///
/// An `.activeAlways` tracking area delivers enter and exit while Reco isn't the active app, and needs no
/// Accessibility permission, unlike a global `NSEvent` monitor.
/// Not generic for the same reason as FirstMouseHostingView in CaptureToolbarController: Xcode 26.6's
/// Release optimizer crashes inlining the deinit of an `NSHostingView<Content>` subclass.
private final class NotchHostingView: NSHostingView<AnyView> {
    var activeRect: () -> CGRect = { .zero }
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?
    var onMove: ((CGPoint?) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Clicks outside the active rect fall through. Where the window is also fully transparent the window
    /// server passes them on to what is below (the menu bar); this keeps the view from taking them first.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let window else { return nil }
        let screenPoint = window.convertPoint(toScreen: superview?.convert(point, to: nil) ?? point)
        return Self.contains(activeRect(), screenPoint) ? super.hitTest(point) : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        refreshTracking()
    }

    /// Tracks the active rect, which moves with the shelf's state
    func refreshTracking() {
        trackingAreas.filter { $0.owner === self }.forEach(removeTrackingArea)
        guard let window else { return }
        let rect = convert(window.convertFromScreen(activeRect()), from: nil)
        addTrackingArea(NSTrackingArea(rect: rect, options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved], owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) {
        onMove?(nil)
        onExit?()
    }

    override func mouseMoved(with event: NSEvent) { onMove?(convert(event.locationInWindow, from: nil)) }

    /// The top edge counts: a pointer pushed against the top of the screen sits on its last row, which
    /// `CGRect.contains` leaves out.
    static func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
        rect.insetBy(dx: 0, dy: -1).contains(point)
    }
}

/// One screen's panel and view model. The panel is one fixed frame for the shelf's whole life
/// (`NotchGeometry.window`); the shape animates inside it, and what is outside the shape is click-through.
@MainActor
private final class NotchShelf {
    let panel = NotchPanel()
    let viewModel: NotchShelfViewModel
    private let hostingView: NotchHostingView

    init(screen: NSScreen, settings: SettingsStore) {
        let geometry = NotchGeometry(screenFrame: screen.frame, leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea)
        let viewModel = NotchShelfViewModel(geometry: geometry) { [settings] in (settings.screenshotDirectory, ScreenshotHistory.directory) }
        self.viewModel = viewModel

        hostingView = NotchHostingView(rootView: AnyView(NotchShelfView(viewModel: viewModel).themed()))
        hostingView.sizingOptions = []
        hostingView.activeRect = { [weak viewModel] in viewModel?.activeRect ?? .zero }
        hostingView.onEnter = { [weak viewModel] in viewModel?.pointerEntered() }
        hostingView.onExit = { [weak viewModel] in viewModel?.pointerExited() }
        hostingView.onMove = { [weak viewModel] in viewModel?.pointer = $0 }
        panel.contentView = hostingView
        panel.setFrame(geometry.window, display: false)
        observeState()
    }

    func show() {
        panel.orderFrontRegardless()
    }

    /// Takes the shelf away at once, e.g. before a screenshot, so it isn't in it
    func hide() {
        viewModel.collapse()
        panel.orderOut(nil)
    }

    /// Follows the active rect as the shelf peeks, opens and closes. A tracking area one turn late is
    /// invisible (the shape is what the eye sees), unlike a window that resizes behind it.
    private func observeState() {
        withObservationTracking {
            _ = viewModel.isExpanded
            _ = viewModel.isPeeking
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.stateChanged()
                self?.observeState()
            }
        }
    }

    private func stateChanged() {
        hostingView.refreshTracking()
        // Away for a screenshot, it isn't there to hover
        guard panel.isVisible else { return }
        // A tracking area made around a pointer that is already inside sends no enter, and one made away
        // from it no exit: say so ourselves when the pointer and the view model disagree.
        let isInside = NotchHostingView.contains(viewModel.activeRect, NSEvent.mouseLocation)
        if isInside && !viewModel.isHovering {
            viewModel.pointerEntered()
        } else if !isInside && viewModel.isHovering {
            viewModel.pointerExited()
        }
    }
}

/// Puts the notch shelf (spec 0013) over the notch of every screen, or a pill at the top centre of one
/// without a notch, while Settings has it on. Rebuilt when the screens change. It is taken away
/// as a screenshot starts (`hide()`) so it never lands in one, and comes back when it ends (`restore()`).
@MainActor
final class NotchShelfController {

    private let settings: SettingsStore
    private var shelves: [NotchShelf] = []
    private var isHidden = false

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        rebuild()
        observeSetting()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
    }

    func hide() {
        isHidden = true
        shelves.forEach { $0.hide() }
    }

    func restore() {
        isHidden = false
        shelves.forEach { $0.show() }
    }

    private func rebuild() {
        shelves.forEach { $0.hide() }
        shelves = []
        guard settings.showsScreenshotsInNotch else { return }
        shelves = NSScreen.screens.map { NotchShelf(screen: $0, settings: settings) }
        if !isHidden {
            shelves.forEach { $0.show() }
        }
    }

    private func observeSetting() {
        withObservationTracking {
            _ = settings.showsScreenshotsInNotch
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.rebuild()
                self?.observeSetting()
            }
        }
    }
}
