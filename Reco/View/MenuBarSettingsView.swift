//
//  MenuBarSettingsView.swift
//  Reco
//
//  Created by Joshua Sattler on 02.02.26.
//

import SwiftUI

// MARK: - Section Divider

/// A styled divider for menu bar sections
struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}

// MARK: - Section Header

/// A styled section header for menu bar (bold, not uppercase)
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }
}

// MARK: - Menu Bar Divider (smaller)

/// A styled divider for menu bar
struct MenuBarDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}

// MARK: - Toggle Row

/// A menu bar style toggle with a switch on the right side and hover effect
struct MenuBarToggle: View {
    let name: String
    @Binding var isOn: Bool
    var isDisabled: Bool = false
    @State private var isHovered = false
    /// Off while the popover's settings are locked, from the countdown until the file is saved
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack {
            Text(name)
                .font(.body.weight(.medium))
                .foregroundStyle(isDisabled || !isEnabled ? .secondary : .primary)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.8)
                .disabled(isDisabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(.rect)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(isHovered && !isDisabled && isEnabled ? 0.08 : 0))
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .editorMotion(EditorTheme.quickMotion, value: isHovered)
    }
}

// MARK: - Expandable Picker Row

// MARK: - Expandable Header

/// The header row of an expandable section: its title, the current value if there is one, and a
/// chevron that turns when it's open. Toggles with the app's one motion.
struct ExpandableHeader: View {
    let title: String
    var value: String?
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withMotion { isExpanded.toggle() }
        } label: {
            HStack {
                Text(title)
                    .font(.body.weight(.medium))
                Spacer()
                if let value {
                    Text(value)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.menuRow)
    }
}

// MARK: - Picker Option Row

// MARK: - Device Row (for microphone selection)

/// A device selection row: its icon in a fixed column, a checkmark when selected
struct DeviceRow: View {
    let name: String
    let icon: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text(name)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.callout.weight(.semibold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .buttonStyle(.menuRow)
    }
}

// MARK: - Microphone Expandable Picker

/// A microphone picker with device rows
struct MicrophoneExpandablePicker: View {
    @Binding var selectedID: String?
    let devices: [AudioInputDevice]
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            ExpandableHeader(title: "Microphone", value: currentLabel, isExpanded: $isExpanded)

            // Expanded device options
            if isExpanded {
                VStack(spacing: 0) {
                    // System Default option
                    DeviceRow(
                        name: "System Default",
                        icon: "mic",
                        isSelected: selectedID == nil
                    ) {
                        selectedID = nil
                        withMotion { isExpanded = false }
                    }

                    // Available devices
                    ForEach(devices) { device in
                        DeviceRow(
                            name: device.name,
                            icon: device.isDefault ? "mic.fill" : "mic",
                            isSelected: selectedID == device.id
                        ) {
                            selectedID = device.id
                            withMotion { isExpanded = false }
                        }
                    }
                }
                .padding(.leading, 12)
                .background(.quaternary.opacity(0.3))
            }
        }
    }

    private var currentLabel: String {
        if let id = selectedID, let device = devices.first(where: { $0.id == id }) {
            return device.name
        }
        return "System Default"
    }
}

// MARK: - Expandable Section (for arbitrary content)

// MARK: - Video Settings Section


// MARK: - Audio Settings Section

/// Audio settings section with header and inline content
struct AudioSettingsSection: View {
    @Bindable var settings: SettingsStore
    let audioDeviceService: AudioDeviceService

    var body: some View {
        VStack(spacing: 0) {
            // Separator before Audio section
            SectionDivider()

            SectionHeader(title: "Audio")

            // System Audio Toggle
            MenuBarToggle(name: "Capture System Audio", isOn: $settings.captureSystemAudio)

            // Microphone Toggle
            MenuBarToggle(name: "Capture Microphone", isOn: $settings.captureMicrophone)

            // Microphone Source Picker (only shown when microphone is enabled)
            if settings.captureMicrophone {
                MicrophoneExpandablePicker(
                    selectedID: $settings.selectedMicrophoneID,
                    devices: audioDeviceService.availableDevices
                )
            }
        }
    }
}

// MARK: - Camera Expandable Picker

/// A camera picker with device-style rows, matching the microphone picker pattern
struct CameraExpandablePicker: View {
    @Binding var selectedID: String?
    let devices: [CameraDevice]
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            ExpandableHeader(title: "Camera", value: currentLabel, isExpanded: $isExpanded)

            // Expanded device options
            if isExpanded {
                VStack(spacing: 0) {
                    // System Default option
                    DeviceRow(
                        name: "System Default",
                        icon: "camera",
                        isSelected: selectedID == nil
                    ) {
                        selectedID = nil
                        withMotion { isExpanded = false }
                    }

                    // Available devices
                    ForEach(devices) { device in
                        DeviceRow(
                            name: device.name,
                            icon: "camera",
                            isSelected: selectedID == device.id
                        ) {
                            selectedID = device.id
                            withMotion { isExpanded = false }
                        }
                    }
                }
                .padding(.leading, 12)
                .background(.quaternary.opacity(0.3))
            }
        }
    }

    private var currentLabel: String {
        if let id = selectedID, let device = devices.first(where: { $0.id == id }) {
            return device.name
        }
        return "System Default"
    }
}

// MARK: - Presenter Overlay Settings Section

/// Presenter Overlay toggle and camera picker
struct PresenterOverlaySettingsSection: View {
    @Bindable var settings: SettingsStore
    let cameraDeviceService: CameraDeviceService
    let permissionService: PermissionService

    var body: some View {
        VStack(spacing: 0) {
            SectionDivider()

            SectionHeader(title: "Camera")

            MenuBarToggle(name: "Presenter Overlay", isOn: $settings.presenterOverlayEnabled)

            if settings.presenterOverlayEnabled {
                CameraExpandablePicker(
                    selectedID: $settings.selectedCameraID,
                    devices: cameraDeviceService.availableDevices
                )
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
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        PresenterOverlaySettingsSection(
            settings: SettingsStore(),
            cameraDeviceService: CameraDeviceService(),
            permissionService: PermissionService()
        )
        AudioSettingsSection(settings: SettingsStore(), audioDeviceService: AudioDeviceService())
    }
    .frame(width: 320)
    .padding(.vertical, 8)
}
