//
//  CaptureToolbarLiveControls.swift
//  Reco
//

import KeyboardShortcuts
import SwiftUI

/// During a take: what it records, shown but fixed until it ends, and the live pill with the time,
/// cancel, restart, pause and stop. The time is red while it runs, dim while paused.
struct CaptureToolbarLiveControls: View {
    let recorder: RecorderViewModel

    private var settings: SettingsStore { recorder.settings }

    var body: some View {
        HStack(spacing: 2) {
            indicator("System Audio", short: "Audio", icon: .toolbarSystemAudio, isOn: settings.captureSystemAudio)
            indicator("Microphone", short: "Mic", icon: .toolbarMic, isOn: settings.captureMicrophone)
            indicator("Camera", short: "Camera", icon: .toolbarCamera, isOn: settings.presenterOverlayEnabled)
        }
        .captureToolbarPill()

        HStack(spacing: EditorTheme.tightSpacing) {
            Text(recorder.formattedDuration)
                .font(.title3.monospacedDigit())
                .foregroundStyle(recorder.isPaused ? Color.secondary : CaptureToolbarView.recording)
                .contentTransition(.numericText())
                .editorMotion(EditorTheme.quickMotion, value: recorder.formattedDuration)
                .padding(.leading, EditorTheme.mediumSpacing)
                .padding(.trailing, EditorTheme.tightSpacing)
                .accessibilityLabel(recorder.isPaused ? "Paused at \(recorder.formattedDuration)" : "Recording, \(recorder.formattedDuration)")

            Button {
                Task { await recorder.cancelRecording() }
            } label: {
                Label("Cancel Recording", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.captureToolbar)
            .captureToolbarTooltip("Cancel", shortcut: Self.shortcut(for: .cancelRecording))

            Button {
                Task { await recorder.restartRecording() }
            } label: {
                Label("Restart Recording", systemImage: "arrow.counterclockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.captureToolbar)
            .captureToolbarTooltip("Restart", shortcut: Self.shortcut(for: .restartRecording))

            Button {
                recorder.togglePause()
            } label: {
                Label {
                    Text(recorder.isPaused ? "Resume" : "Pause")
                } icon: {
                    if recorder.isPaused {
                        Image(systemName: "play.fill")
                    } else {
                        ToolbarIcon(.toolbarPause)
                    }
                }
                .labelStyle(.iconOnly)
            }
            .buttonStyle(.captureToolbar)
            // The bar doesn't take key during a take, so the keys shown are the global shortcuts
            .captureToolbarTooltip(recorder.isPaused ? "Resume" : "Pause", shortcut: Self.shortcut(for: .pauseRecording))

            Button {
                Task { await recorder.stopRecording() }
            } label: {
                Label { Text("Stop Recording") } icon: { ToolbarIcon(.toolbarStop) }
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(CaptureToolbarStopButtonStyle())
            .captureToolbarTooltip("Stop", shortcut: Self.shortcut(for: .toggleRecording))
        }
        .captureToolbarPill(tint: CaptureToolbarView.recording.mix(with: CaptureToolbarView.ground, by: recorder.isPaused ? 0.9 : 0.7))
    }

    private func indicator(_ title: String, short: String, icon: ImageResource, isOn: Bool) -> some View {
        ToolbarIcon(icon)
            .foregroundStyle(isOn ? CaptureToolbarView.live : .secondary)
            .opacity(isOn ? 1 : 0.5)
            .frame(width: 36, height: 36)
            .accessibilityLabel("\(title): \(isOn ? "On" : "Off")")
            .captureToolbarTooltip("\(short) \(isOn ? "On" : "Off")")
    }

    private static func shortcut(for name: KeyboardShortcuts.Name) -> String? {
        KeyboardShortcuts.getShortcut(for: name)?.description
    }
}

/// Stop, from the moodboard's recording bar: a dark square on white, the brightest thing on the bar.
private struct CaptureToolbarStopButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(CaptureToolbarView.ground)
            .frame(width: 36, height: 36)
            .background(.white.opacity(configuration.isPressed ? 0.75 : 1), in: .rect(cornerRadius: 12, style: .continuous))
            .contentShape(.rect(cornerRadius: 12, style: .continuous))
    }
}
