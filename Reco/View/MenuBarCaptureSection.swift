//
//  MenuBarCaptureSection.swift
//  Reco
//

import SwiftUI

/// What each take captures, as one section of two rows that open in place: Audio (system audio,
/// microphone and its device) and Camera (the presenter overlay). Folded away by default, so the
/// popover's lower half is two rows of state rather than a settings pane. Whether a group was left
/// open is remembered: whoever changes a microphone changes it often.
struct CaptureSettingsSection: View {
    @Bindable var settings: SettingsStore
    let audioDeviceService: AudioDeviceService
    let cameraDeviceService: CameraDeviceService
    let permissionService: PermissionService

    /// Where the user left each group. Not settings, so they stay in `UserDefaults` rather than
    /// `SettingsStore`, which writes the recordings' configuration.
    @AppStorage("captureAudioExpanded") private var isAudioExpanded = false
    @AppStorage("captureCameraExpanded") private var isCameraExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            SectionDivider()

            SectionHeader(title: "Capture")

            CaptureGroupRow(
                title: "Audio",
                systemImage: "speaker.wave.2",
                value: audioSummary,
                isExpanded: $isAudioExpanded
            )

            if isAudioExpanded {
                VStack(spacing: 0) {
                    MenuBarToggle(name: "Capture System Audio", isOn: $settings.captureSystemAudio)
                    MenuBarToggle(name: "Capture Microphone", isOn: $settings.captureMicrophone)

                    // The device only matters once the microphone is on
                    if settings.captureMicrophone {
                        MicrophoneExpandablePicker(
                            selectedID: $settings.selectedMicrophoneID,
                            devices: audioDeviceService.availableDevices
                        )
                    }
                }
                .padding(.leading, 12)
                .background(.quaternary.opacity(0.3))
            }

            CaptureGroupRow(
                title: "Camera",
                systemImage: "video",
                value: settings.presenterOverlayEnabled ? "On" : "Off",
                isExpanded: $isCameraExpanded
            )

            if isCameraExpanded {
                VStack(spacing: 0) {
                    MenuBarToggle(name: "Presenter Overlay", isOn: $settings.presenterOverlayEnabled)

                    if settings.presenterOverlayEnabled {
                        CameraExpandablePicker(
                            selectedID: $settings.selectedCameraID,
                            devices: cameraDeviceService.availableDevices
                        )
                    }
                }
                .padding(.leading, 12)
                .background(.quaternary.opacity(0.3))
            }
        }
        .onChange(of: settings.presenterOverlayEnabled) { _, isEnabled in
            // Ask up front rather than letting the first recording fail on a denied camera
            guard isEnabled else { return }

            Task {
                await permissionService.requestCameraPermission()
            }
        }
    }

    /// What the two audio switches add up to, with the group closed.
    private var audioSummary: String {
        switch (settings.captureSystemAudio, settings.captureMicrophone) {
        case (true, true): "System + Microphone"
        case (true, false): "System"
        case (false, true): "Microphone"
        case (false, false): "Off"
        }
    }
}

// MARK: - Group Row

/// A row of the Capture section: its symbol in the fixed column, its name, what it is set to, and a
/// chevron that turns as the group opens under it.
struct CaptureGroupRow: View {
    let title: String
    let systemImage: String
    let value: String
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withMotion { isExpanded.toggle() }
        } label: {
            HStack(spacing: EditorTheme.mediumSpacing) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text(title)
                    .font(.body.weight(.medium))

                Spacer()

                Text(value)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, EditorTheme.mediumSpacing)
            .padding(.vertical, EditorTheme.tightSpacing)
        }
        .buttonStyle(.menuRow)
    }
}

// MARK: - Preview

#Preview {
    CaptureSettingsSection(
        settings: SettingsStore(),
        audioDeviceService: AudioDeviceService(),
        cameraDeviceService: CameraDeviceService(),
        permissionService: PermissionService()
    )
    .frame(width: 320)
    .padding(.vertical, 8)
}
