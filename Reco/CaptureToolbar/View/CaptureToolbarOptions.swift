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
        .captureToolbarTooltip("Countdown: \(settings.countdownDuration == .off ? "Off" : "\(settings.countdownDuration.rawValue)s")")

        option("System Audio", icon: .toolbarSystemAudio, isOn: settings.captureSystemAudio, action: viewModel.toggleSystemAudio)
        option("Microphone", icon: .toolbarMic, isOn: settings.captureMicrophone, action: viewModel.toggleMicrophone)
        option("Camera", icon: .toolbarCamera, isOn: settings.presenterOverlayEnabled, action: viewModel.toggleCamera)
    }

    private func option(_ title: String, icon: ImageResource, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { Text(title) } icon: { ToolbarIcon(icon) }
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.captureToolbar(isOn: isOn))
        .captureToolbarTooltip("\(title): \(isOn ? "On" : "Off")")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
