//
//  RecoApp.swift
//  Reco
//
//  Created by Joshua Sattler on 29.01.26.
//

import AppKit
import SwiftUI

struct RecoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var updaterService = UpdaterService()

    /// The recorder lives on the app delegate so URLs can be handled before the
    /// menu bar popover has ever been opened. See ``AppDelegate``.
    private var viewModel: RecorderViewModel { appDelegate.viewModel }

    var body: some Scene {
        // Menu bar extra - the primary interface
        // Using .window style to support custom toggle switches
        MenuBarExtra {
            MenuBarView(
                viewModel: viewModel,
                screenshots: appDelegate.screenshots,
                editLastRecording: appDelegate.editLastRecording,
                showRecordings: appDelegate.showRecordings,
                showWebRecording: appDelegate.showWebRecording,
                showAgentRecording: appDelegate.showAgentRecording,
                agentRecording: appDelegate.agentRecording
            )
                .task {
                    await viewModel.requestPermissionsOnLaunch()
                }
        } label: {
            MenuBarLabel(viewModel: viewModel, agentRecording: appDelegate.agentRecording)
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Settings {
            SettingsView(settings: viewModel.settings, updaterService: updaterService, agentBridge: appDelegate.agentBridge)
        }
    }
}

/// The label shown in the menu bar (icon, countdown seconds, duration timer, pause symbol while paused,
/// or the agent's progress while one records a web page)
struct MenuBarLabel: View {
    let viewModel: RecorderViewModel
    let agentRecording: AgentRecordingViewModel

    var body: some View {
        if viewModel.isPaused {
            Image(systemName: "pause.circle")
        } else if viewModel.isRecording {
            // Render the duration into a fixed-size image so the
            // NSStatusItem never recalculates its width on each tick.
            Image(nsImage: timerImage)
        } else if let remaining = viewModel.countdown.remaining {
            Image(systemName: "\(remaining).circle")
        } else if let text = agentRecording.menuBarText {
            Image(nsImage: fixedWidthImage(text, reference: "100%", symbol: "sparkles"))
                .accessibilityLabel(agentRecording.progress.map { "Recording with an agent, \(Int(($0 * 100).rounded())) percent" } ?? "Recording with an agent")
        } else {
            Image(systemName: "record.circle")
        }
    }

    private var timerImage: NSImage {
        // Use the widest possible string for the current format to
        // compute a stable size that won't change between ticks.
        let referenceText: String = if viewModel.recordingDuration >= 3600 {
            "0:00:00"
        } else {
            "00:00"
        }
        return fixedWidthImage(viewModel.formattedDuration, reference: referenceText)
    }

    /// Renders `text`, after an optional symbol, into an ``NSImage`` as wide as `reference` would be, so
    /// the NSStatusItem never recalculates its width as the text changes.
    private func fixedWidthImage(_ text: String, reference: String, symbol: String? = nil) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let icon = symbol.flatMap {
            NSImage(systemSymbolName: $0, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        }
        let iconWidth = icon.map { ceil($0.size.width) + 4 } ?? 0

        let referenceSize = (reference as NSString).size(withAttributes: attrs)
        let imageSize = NSSize(
            width: iconWidth + ceil(referenceSize.width),
            height: max(ceil(referenceSize.height), icon.map { ceil($0.size.height) } ?? 0)
        )

        let textSize = (text as NSString).size(withAttributes: attrs)
        let origin = NSPoint(
            x: iconWidth + (ceil(referenceSize.width) - textSize.width) / 2,
            y: (imageSize.height - textSize.height) / 2
        )

        let image = NSImage(size: imageSize, flipped: false) { _ in
            icon?.draw(at: NSPoint(x: 0, y: (imageSize.height - (icon?.size.height ?? 0)) / 2), from: .zero, operation: .sourceOver, fraction: 1)
            (text as NSString).draw(at: origin, withAttributes: attrs)
            return true
        }
        image.isTemplate = true
        return image
    }
}
