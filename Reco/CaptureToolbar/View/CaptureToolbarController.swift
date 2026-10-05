//
//  CaptureToolbarController.swift
//  Reco
//

import AppKit
import SwiftUI

/// A borderless floating panel. It takes key before a take, so Return and Esc reach the toolbar without
/// activating Reco, and never during one, so typing stays with the app being recorded.
private final class CaptureToolbarPanel: NSPanel {
    var acceptsKey = true

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        // The glass draws its own edge and shadow; the window's would outline the whole rectangle
        hasShadow = false
        level = .floating
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // The view animates itself, which the system's own window animation would only distort
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { acceptsKey }
}

/// The tooltip's window: never key, and never in the pointer's way, so it can sit over anything.
private final class CaptureTooltipPanel: NSPanel {
    override var canBecomeKey: Bool { false }

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        // The chip draws its own shadow; the window's would outline the whole rectangle
        hasShadow = false
        level = .floating
        // The pointer passes through it, so nothing under it is blocked
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .none
    }
}

/// Clicks land on the first press although the panel isn't key during a take.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Shows the capture toolbar at the bottom centre of the screen under the pointer, above the Dock: when
/// asked, when content to record is chosen, and for the whole take, from any start (menu, shortcut,
/// `reco://`). It goes once the take is saved. Dragged, it follows the pointer 1:1, resists past the
/// screen's edges and comes to rest where its momentum carries it, or home when that is near. Each
/// control's tooltip rises from the bar, in its own window, out of the pointer's way.
///
/// Reco's windows are left out of display and area recordings unless Settings shows them
/// (`ContentFilterRules`), and the bar is on screen when the filter is built, so it stays out of the file.
@MainActor
final class CaptureToolbarController {

    let viewModel: CaptureToolbarViewModel

    private var panel: CaptureToolbarPanel?
    private let presence = PanelPresence()

    /// Takes the panel off screen once its exit has played; cancelled by a `show()` meanwhile.
    private var removal: Task<Void, Never>?

    /// Narrows the panel once the bar's change of state has played, so the leaving controls aren't cut off
    private var narrowing: Task<Void, Never>?

    /// Where the bar was dropped: the middle of its bottom edge. Nil at home.
    private var anchor: CGPoint?

    /// Names the control under the pointer, in a window above the bar
    private let tooltips = CaptureToolbarTooltips()
    private var tooltipPanel: NSPanel?

    /// Orders the tooltip's window out once its exit has played
    private var tooltipRemoval: Task<Void, Never>?

    /// The picker for a window or a display, drawn above the bar in this same window
    private let pickerPresence = PanelPresence()
    private var pickerRemoval: Task<Void, Never>?

    private var barSize: CGSize = .zero
    private var tracker = VelocityTracker()
    private var grabOffset: CGSize?
    private var lastState: RecorderViewModel.RecordingState = .idle

    private var margin: CGFloat { CaptureToolbarView.margin }

    /// The bar's windows sit one step above the area selection overlay (`.screenSaver`, which covers the
    /// whole screen) while one is being drawn, so its Record stays clickable and confirms the selection;
    /// the rest of the time they keep the floating level and stay under anything the user puts in front.
    private var level: NSWindow.Level {
        viewModel.areaSelection.isPresented ? Self.selectionLevel : .floating
    }

    private static let selectionLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)

    init(viewModel: CaptureToolbarViewModel) {
        self.viewModel = viewModel
        viewModel.onHide = { [weak self] animated in self?.hide(animated: animated) }
        viewModel.recorder.onSelectionChange = { [weak self] in
            guard let self else { return }
            viewModel.selectionDidChange()
            if viewModel.recorder.hasContentSelected {
                show()
            }
        }
        observeRecorder()
        observeAreaSelection()
        observeTooltips()
        observePicker()
    }

    func show() {
        removal?.cancel()
        removal = nil
        presence.isShown = true

        let panel = self.panel ?? makePanel()
        panel.ignoresMouseEvents = false
        panel.acceptsKey = viewModel.recorder.state == .idle
        if panel.acceptsKey {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    /// Takes the toolbar away after its exit, or at once (before a screenshot, so it isn't in it)
    func hide(animated: Bool) {
        guard let panel else { return }
        removal?.cancel()
        presence.isShown = false
        panel.ignoresMouseEvents = true
        tooltips.unhover(immediately: true)
        viewModel.sources.cancel()

        guard animated else {
            // At once: neither the bar nor its tooltip is in the shot
            dismissTooltips(afterExit: false)
            remove(panel)
            return
        }
        removal = Task {
            try? await Task.sleep(for: PanelPresentation.exitDelay)
            guard !Task.isCancelled else { return }
            remove(panel)
        }
    }

    private func makePanel() -> CaptureToolbarPanel {
        let panel = CaptureToolbarPanel()
        panel.level = level
        let view = CaptureToolbarView(
            viewModel: viewModel,
            presence: presence,
            pickerPresence: pickerPresence,
            tooltips: tooltips,
            onSizeChange: { [weak self] in self?.fit($0) },
            onBarSizeChange: { [weak self] in self?.barSize = $0 },
            onDrag: { [weak self] in self?.drag() },
            onDragEnd: { [weak self] in self?.endDrag() }
        )
        let hostingView = FirstMouseHostingView(rootView: view)
        // The panel is sized here, and narrows only after the bar's animation
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        self.panel = panel

        // A click in another app or on the desktop closes the picker, as it would close any popover
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.viewModel.sources.cancel() }
        }

        // A drop on another screen doesn't follow the bar to this one
        if let anchor, !screenUnderPointer.visibleFrame.contains(anchor) {
            self.anchor = nil
        }
        let fitted = hostingView.fittingSize
        barSize = CGSize(width: fitted.width - margin * 2, height: fitted.height - margin * 2)
        fit(fitted)
        return panel
    }

    private func remove(_ panel: NSPanel) {
        panel.orderOut(nil)
        self.panel = nil
        removal = nil
        narrowing?.cancel()
    }

    // MARK: - Area selection

    /// Rises above the area selection while one is up, so its Record reaches the bar and not the overlay
    private func observeAreaSelection() {
        withObservationTracking {
            _ = viewModel.areaSelection.isPresented
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.areaSelectionDidChange()
                self?.observeAreaSelection()
            }
        }
    }

    private func areaSelectionDidChange() {
        let level = self.level
        panel?.level = level
        tooltipPanel?.level = level
        // The overlay's own windows were ordered in after the bar, so it is brought forward again
        if let panel, panel.isVisible, level != .floating {
            panel.orderFrontRegardless()
        }
    }

    // MARK: - Recording

    private func observeRecorder() {
        withObservationTracking {
            _ = viewModel.recorder.state
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.recorderStateDidChange()
                self?.observeRecorder()
            }
        }
    }

    private func recorderStateDidChange() {
        let state = viewModel.recorder.state
        defer { lastState = state }

        switch state {
        case .recording where lastState != .recording:
            show()
            // Ordering out a key panel gives key back to the app in front; it returns without it
            if let panel, panel.isKeyWindow {
                panel.orderOut(nil)
                panel.orderFrontRegardless()
            }
        case .idle where lastState == .stopping:
            hide(animated: true)
        default:
            break
        }
    }

    // MARK: - Sizing

    /// Sizes the panel to its content (plus its margin) around the anchor. Widening is at once, narrowing
    /// after the change of state has played: the bar is centred in the panel either way, so it doesn't shift.
    private func fit(_ size: CGSize) {
        guard let panel, size.width > 0, size.height > 0 else { return }
        narrowing?.cancel()

        guard size.width < panel.frame.width, panel.isVisible else {
            place(panel, size: size)
            return
        }
        narrowing = Task {
            try? await Task.sleep(for: PanelPresentation.exitDelay)
            guard !Task.isCancelled else { return }
            place(panel, size: size)
        }
    }

    private func place(_ panel: NSPanel, size: CGSize) {
        let bottomCentre = anchor ?? homeAnchor
        let barOrigin = CGPoint(x: bottomCentre.x - barSize.width / 2, y: bottomCentre.y)
        let origin = CaptureToolbarPlacement.windowOrigin(for: barOrigin, windowSize: size, barSize: barSize, margin: margin)
        panel.setFrame(CGRect(x: origin.x.rounded(), y: origin.y, width: size.width, height: size.height), display: true)
    }

    private var screenUnderPointer: NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private var homeAnchor: CGPoint {
        let visibleFrame = (panel?.screen ?? screenUnderPointer).visibleFrame
        let origin = CaptureToolbarPlacement.home(size: barSize, in: visibleFrame)
        return CGPoint(x: origin.x + barSize.width / 2, y: origin.y)
    }

    // MARK: - Dragging

    /// Follows the pointer 1:1 from where the bar was grabbed, resisting past the screen's edges.
    private func drag() {
        guard let panel, let screen = panel.screen else { return }
        tooltips.setDragging(true)
        let mouse = NSEvent.mouseLocation
        let bar = CaptureToolbarPlacement.barOrigin(inWindow: panel.frame, barSize: barSize, margin: margin)
        let offset = grabOffset ?? CGSize(width: mouse.x - bar.x, height: mouse.y - bar.y)
        grabOffset = offset
        tracker.add(mouse, at: ProcessInfo.processInfo.systemUptime)

        let pointerLed = CGPoint(x: mouse.x - offset.width, y: mouse.y - offset.height)
        let shown = CaptureToolbarPlacement.dragged(pointerLed, size: barSize, in: screen.visibleFrame)
        panel.setFrameOrigin(
            CaptureToolbarPlacement.windowOrigin(for: shown, windowSize: panel.frame.size, barSize: barSize, margin: margin)
        )
    }

    /// Lets the bar go at the release speed, to where its momentum carries it inside the screen.
    private func endDrag() {
        defer {
            tooltips.setDragging(false)
            grabOffset = nil
            tracker = VelocityTracker()
        }
        guard grabOffset != nil, let panel, let screen = panel.screen else { return }

        let velocity = tracker.velocity
        let released = CaptureToolbarPlacement.barOrigin(inWindow: panel.frame, barSize: barSize, margin: margin)
        let rest = CaptureToolbarPlacement.resting(released, velocity: velocity, size: barSize, in: screen.visibleFrame)
        let home = CaptureToolbarPlacement.home(size: barSize, in: screen.visibleFrame)
        anchor = rest == home ? nil : CGPoint(x: rest.x + barSize.width / 2, y: rest.y)

        let target = CGRect(
            origin: CaptureToolbarPlacement.windowOrigin(for: rest, windowSize: panel.frame.size, barSize: barSize, margin: margin),
            size: panel.frame.size
        )
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(target, display: true)
            return
        }
        let distance = hypot(target.minX - panel.frame.minX, target.minY - panel.frame.minY)
        NSAnimationContext.runAnimationGroup { context in
            // Leaves at the release speed: this curve starts at slope 3
            context.duration = GesturePhysics.velocityMatchedDuration(distance: distance, velocity: hypot(velocity.dx, velocity.dy))
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.75, 0.5, 1)
            panel.animator().setFrame(target, display: true)
        }
    }
}

// MARK: - Tooltips

extension CaptureToolbarController {

    /// Follows what the pointer is over: the tooltip's window appears, refits and moves while a control
    /// is hovered, and plays its exit once the pointer leaves it.
    private func observeTooltips() {
        withObservationTracking {
            _ = tooltips.target
            _ = tooltips.isShown
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.tooltipsDidChange()
                self?.observeTooltips()
            }
        }
    }

    private func tooltipsDidChange() {
        guard let barPanel = panel, barPanel.isVisible, tooltips.isShown, let target = tooltips.target else {
            dismissTooltips(afterExit: true)
            return
        }
        showTooltips(target, above: barPanel)
    }

    /// Places the tooltip's window above the hovered control, sized for its text; the bubble animates
    /// its own change of text.
    private func showTooltips(_ target: CaptureToolbarTooltips.Target, above barPanel: NSPanel) {
        tooltipRemoval?.cancel()
        let panel = tooltipPanel ?? makeTooltipPanel()

        let frame = CaptureToolbarPlacement.rectAbove(
            barFrame: barPanel.frame,
            size: CaptureToolbarTooltipView.size(for: target.text),
            midX: barPanel.frame.minX + margin + target.midX,
            in: (barPanel.screen ?? screenUnderPointer).visibleFrame
        )
        tooltips.pointsUp = frame.maxY <= barPanel.frame.minY
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
    }

    /// Orders the tooltip's window out at once, or once its chip's exit has played
    private func dismissTooltips(afterExit: Bool) {
        tooltipRemoval?.cancel()
        guard let tooltipPanel else { return }
        if !afterExit {
            tooltipPanel.orderOut(nil)
            return
        }
        guard tooltipPanel.isVisible else { return }
        tooltipRemoval = Task {
            try? await Task.sleep(for: PanelPresentation.exitDelay)
            guard !Task.isCancelled else { return }
            tooltipPanel.orderOut(nil)
        }
    }

    private func makeTooltipPanel() -> NSPanel {
        let panel = CaptureTooltipPanel()
        panel.level = level
        let hostingView = NSHostingView(rootView: CaptureToolbarTooltipView(tooltips: tooltips))
        // The panel is sized here, from the text the tooltips state holds
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        tooltipPanel = panel
        return panel
    }
}

// MARK: - Picker

extension CaptureToolbarController {

    /// Mounts the picker while it is open, once it has something to show, and unmounts it once its exit
    /// has played (a choice, Esc, a mode change, or a click elsewhere).
    private func observePicker() {
        withObservationTracking {
            _ = viewModel.sources.kind
            _ = viewModel.sources.hasSomethingToShow
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.pickerDidChange()
                self?.observePicker()
            }
        }
    }

    /// The picker waits until it has something to show, so it arrives in one move: a warm load lays out
    /// the finished tiles, and a slow one a spinner that stands for the wait.
    private func pickerDidChange() {
        let picker = viewModel.sources
        guard picker.isOpen, picker.hasSomethingToShow else {
            dismissPicker()
            return
        }
        pickerRemoval?.cancel()
        pickerRemoval = nil
        pickerPresence.isShown = true
        tooltips.unhover(immediately: true)
    }

    /// Takes the picker away: the view animates its exit, and it is unmounted once that has played, so
    /// the bar's window can shrink back around the bar alone.
    private func dismissPicker() {
        guard pickerPresence.isShown else { return }
        pickerRemoval?.cancel()
        pickerRemoval = Task {
            try? await Task.sleep(for: PanelPresentation.exitDelay)
            guard !Task.isCancelled else { return }
            pickerPresence.isShown = false
        }
    }
}
