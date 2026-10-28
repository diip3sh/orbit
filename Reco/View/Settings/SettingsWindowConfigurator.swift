//
//  SettingsWindowConfigurator.swift
//  Reco
//

import AppKit
import SwiftUI

/// Runs the Settings (and Library and editor) window's content under a transparent title bar and moves the
/// traffic lights into the first panel's top row.
struct SettingsWindowConfigurator: NSViewRepresentable {

    /// The title bar's row at the top of the sidebar and the pane, which the traffic lights sit in.
    static let titlebarHeight: CGFloat = 52

    /// The height of the row the traffic lights sit in the middle of: the editor's header is taller.
    var rowHeight = titlebarHeight

    /// The close button's centre from the window's top-left corner: the window's 8 pt inset and the
    /// panel's 1 pt edge, 20 pt in, and the middle of the row.
    static func firstButtonCenter(rowHeight: CGFloat) -> CGPoint {
        CGPoint(x: 8 + 1 + 20 + 6, y: 8 + 1 + rowHeight / 2)
    }

    /// From one traffic light's centre to the next.
    static let buttonSpacing: CGFloat = 20

    func makeNSView(context: Context) -> NSView {
        WindowObservingView(rowHeight: rowHeight)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowObservingView: NSView {

    private static let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]

    private let rowHeight: CGFloat

    private var observers: [NSObjectProtocol] = []

    init(rowHeight: CGFloat) {
        self.rowHeight = rowHeight
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeObservers()
        guard let window else { return }

        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        // An empty toolbar makes the title bar as tall as the sidebar's top row, so the buttons
        // moved into it aren't clipped
        if window.toolbar == nil {
            window.toolbar = NSToolbar()
        }
        window.toolbarStyle = .unified

        // AppKit puts the buttons back whenever it lays the title bar out: move them again. Deferred,
        // because its layout runs after this observer (it re-centres the zoom button in the title bar's
        // own height, not the row's) and a synchronous move loses to it
        for button in buttons(of: window) {
            button.postsFrameChangedNotifications = true
            observers.append(NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification, object: button, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.placeButtonsAfterLayout() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.placeButtonsAfterLayout() }
        })
        placeButtons()
        placeButtonsAfterLayout()
    }

    /// A placement pass after the current event, when AppKit's title bar layout has settled.
    private func placeButtonsAfterLayout() {
        Task { @MainActor [weak self] in
            self?.placeButtons()
        }
    }

    private func buttons(of window: NSWindow) -> [NSButton] {
        Self.buttonTypes.compactMap { window.standardWindowButton($0) }
    }

    private func placeButtons() {
        guard let window, let frameView = window.contentView?.superview else { return }
        let height = frameView.bounds.height
        let firstButtonCenter = SettingsWindowConfigurator.firstButtonCenter(rowHeight: rowHeight)
        for (index, button) in buttons(of: window).enumerated() {
            guard let superview = button.superview else { continue }
            let center = CGPoint(
                x: firstButtonCenter.x + CGFloat(index) * SettingsWindowConfigurator.buttonSpacing,
                y: height - firstButtonCenter.y
            )
            let local = superview.convert(frameView.convert(center, to: nil), from: nil)
            let origin = CGPoint(x: (local.x - button.frame.width / 2).rounded(), y: (local.y - button.frame.height / 2).rounded())
            if button.frame.origin != origin {
                button.setFrameOrigin(origin)
            }
        }
    }

    private func removeObservers() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }
}
