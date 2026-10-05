//
//  CaptureToolbarOptions.swift
//  Reco
//

import SwiftUI

/// The countdown as a chip with its value, and what the take records as switches: system audio,
/// microphone, camera. On is the live colour; the rest is a menu away.
struct CaptureToolbarOptions: View {
    let viewModel: CaptureToolbarViewModel

    private var settings: SettingsStore { viewModel.settings }

    var body: some View {
        Menu {
            Picker("Countdown", selection: Bindable(settings).countdownDuration) {
                ForEach(CountdownDuration.allCases) { duration in
                    Text(duration.displayName).tag(duration)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: EditorTheme.tightSpacing) {
                ToolbarIcon(.toolbarCountdown)
                Text(settings.countdownDuration == .off ? "Off" : "\(settings.countdownDuration.rawValue)s")
                    .monospacedDigit()
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .accessibilityHidden(true)
            }
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.captureToolbar)
        .fixedSize()
        .captureToolbarTooltip("Countdown")

        // Each tooltip says what a click does now
        CaptureToolbarSwitch(
            title: "System Audio", icon: .toolbarSystemAudio, isOn: settings.captureSystemAudio,
            tooltip: settings.captureSystemAudio ? "Mute Audio" : "Record Audio", shortcut: .systemAudio,
            action: viewModel.toggleSystemAudio
        )
        CaptureToolbarSwitch(
            title: "Microphone", icon: .toolbarMic, isOn: settings.captureMicrophone,
            tooltip: settings.captureMicrophone ? "Mute Mic" : "Record Mic", shortcut: .microphone,
            action: viewModel.toggleMicrophone
        )
        CaptureToolbarSwitch(
            title: "Camera", icon: .toolbarCamera, isOn: settings.presenterOverlayEnabled,
            tooltip: settings.presenterOverlayEnabled ? "Hide Camera" : "Show Camera", shortcut: .camera,
            action: viewModel.toggleCamera
        )
    }
}

/// One of what the take records, as a switch with its key
private struct CaptureToolbarSwitch: View {
    let title: String
    let icon: ImageResource
    let isOn: Bool
    let tooltip: String
    let shortcut: CaptureToolbarShortcut
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label { Text(title) } icon: { ToolbarIcon(icon) }
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.captureToolbar(isOn: isOn))
        .captureToolbarTooltip(tooltip, shortcut: shortcut)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
