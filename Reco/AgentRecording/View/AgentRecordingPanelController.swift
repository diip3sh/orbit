//
//  AgentRecordingPanelController.swift
//  Reco
//

import AppKit
import SwiftUI

/// Shows the Record with AI Agent panel (spec 0007): a bar near the top of the screen under the
/// pointer, like Spotlight.
///
/// It takes the keyboard without activating Reco, so the app in front stays in front. It goes when
/// it loses key (a click elsewhere, ⌘-Tab, a window opening) or on Esc, and a run it started
/// carries on without it.
@MainActor
final class AgentRecordingPanelController: NSObject, NSWindowDelegate {

    nonisolated static let width: CGFloat = 600

    /// How far down the screen the panel's top edge sits, as a share of the usable height.
    nonisolated static let topInset: CGFloat = 0.22

    private let viewModel: AgentRecordingViewModel
    private var panel: NSPanel?

    /// The usable area of the screen the panel opened on.
    private var visibleFrame = CGRect.zero
    private var removal: Task<Void, Never>?

    init(viewModel: AgentRecordingViewModel) {
        self.viewModel = viewModel
        super.init()
        viewModel.onSucceeded = { [weak self] in self?.close() }
    }

    /// Opens the panel, or brings back one that's on its way out.
    func show() {
        removal?.cancel()
        removal = nil
        viewModel.isPresented = true
        Task { await viewModel.refreshAgents() }

        if let panel {
            panel.ignoresMouseEvents = false
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }) ?? NSScreen.main else { return }
        visibleFrame = screen.visibleFrame

        let panel = QuickAccessPanel(
            contentRect: Self.frame(height: 160, in: visibleFrame),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        // The view animates itself, which the system's own window animation would only distort
        panel.animationBehavior = .none
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: AgentRecordingView(
            model: viewModel,
            onClose: { [weak self] in self?.close() },
            onHeightChange: { [weak self] in self?.resize(toHeight: $0) }
        ))
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    /// Fades the panel out, then takes it off screen.
    func close() {
        guard panel != nil, removal == nil else { return }
        viewModel.isPresented = false
        removal = Task {
            try? await Task.sleep(for: PanelPresentation.exitDelay)
            guard !Task.isCancelled else { return }
            panel?.orderOut(nil)
            panel = nil
            removal = nil
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    /// Keeps the top edge where it is as the content grows and shrinks.
    private func resize(toHeight height: CGFloat) {
        guard let panel, height > 0 else { return }
        panel.setFrame(Self.frame(height: height, in: visibleFrame), display: true)
        panel.invalidateShadow()
    }

    /// The panel's frame at `height`: centred across `visibleFrame`, its top edge `topInset` of
    /// the way down, and never below it.
    nonisolated static func frame(height: CGFloat, in visibleFrame: CGRect) -> CGRect {
        let top = visibleFrame.maxY - topInset * visibleFrame.height
        let origin = CGPoint(
            x: max(min(visibleFrame.midX - width / 2, visibleFrame.maxX - width), visibleFrame.minX),
            y: max(top - height, visibleFrame.minY)
        )
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }
}
