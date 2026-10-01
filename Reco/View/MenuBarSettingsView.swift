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

    var body: some View {
        HStack {
            Text(name)
                .font(.body.weight(.medium))
                .foregroundStyle(isDisabled ? .secondary : .primary)
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
                .fill(Color.primary.opacity(isHovered && !isDisabled ? 0.08 : 0))
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .editorMotion(EditorTheme.quickMotion, value: isHovered)
    }
}

// MARK: - Expandable Picker Row

/// Represents a single option in a `MenuBarExpandablePicker`
struct PickerOption<Value: Hashable & Equatable> {
    let value: Value
    let label: String
    var isDisabled: Bool = false
    var disabledMessage: String?
}

/// A menu bar style picker that expands inline to show options
struct MenuBarExpandablePicker<SelectionValue: Hashable & Equatable>: View {
    let name: String
    @Binding var selection: SelectionValue
    let options: [PickerOption<SelectionValue>]
    @State private var isExpanded = false

    /// Convenience initializer for simple options without disabled state
    init(
        name: String,
        selection: Binding<SelectionValue>,
        options: [(value: SelectionValue, label: String)]
    ) {
        self.name = name
        self._selection = selection
        self.options = options.map { PickerOption(value: $0.value, label: $0.label) }
    }

    /// Full initializer with disabled state support
    init(
        name: String,
        selection: Binding<SelectionValue>,
        optionsWithState: [PickerOption<SelectionValue>]
    ) {
        self.name = name
        self._selection = selection
        self.options = optionsWithState
    }

    var body: some View {
        VStack(spacing: 0) {
            ExpandableHeader(title: name, value: currentLabel, isExpanded: $isExpanded)

            // Expanded options
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(options, id: \.value) { option in
                        PickerOptionRow(
                            label: option.label,
                            isSelected: selection == option.value,
                            isDisabled: option.isDisabled,
                            disabledMessage: option.disabledMessage
                        ) {
                            selection = option.value
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
        options.first { $0.value == selection }?.label ?? ""
    }
}

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

/// A single option row in an expandable picker
struct PickerOptionRow: View {
    let label: String
    let isSelected: Bool
    var isDisabled: Bool = false
    var disabledMessage: String?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                    if isDisabled, let message = disabledMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.callout.weight(.semibold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.menuRow)
        .disabled(isDisabled)
    }
}

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

/// A menu bar style expandable section
struct MenuBarExpandableSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            ExpandableHeader(title: title, isExpanded: $isExpanded)

            // Expanded content
            if isExpanded {
                VStack(spacing: 0) {
                    content
                }
                .padding(.leading, 12)
                .background(.quaternary.opacity(0.3))
            }
        }
    }
}

// MARK: - Video Settings Section

/// Video settings section with header and inline content
struct VideoSettingsSection: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Video")

            // Content Filter Section
            MenuBarExpandableSection(title: "Content Filter") {
                MenuBarToggle(name: "Show Cursor", isOn: $settings.showCursor, isDisabled: settings.leavesCursorToEditor)
                MenuBarToggle(name: "Show Wallpaper", isOn: $settings.showWallpaper)
                MenuBarToggle(name: "Show Menu Bar", isOn: $settings.showMenuBar)
                MenuBarToggle(name: "Show Dock", isOn: $settings.showDock)
                MenuBarToggle(name: "Show Window Shadows", isOn: $settings.showWindowShadows)
                MenuBarToggle(name: "Show Reco", isOn: $settings.showReco)
            }

            // Frame Rate Picker
            MenuBarExpandablePicker(
                name: "Frame Rate",
                selection: $settings.frameRate,
                options: FrameRate.allCases.map { ($0, $0.displayName) }
            )

            // Video Codec Picker (shows all codecs, disables incompatible ones)
            MenuBarExpandablePicker(
                name: "Codec",
                selection: $settings.videoCodec,
                optionsWithState: VideoCodec.allCases.map { codec in
                    let isSupported = settings.containerFormat.supportedVideoCodecs.contains(codec)
                    return PickerOption(
                        value: codec,
                        label: codec.rawValue,
                        isDisabled: !isSupported,
                        disabledMessage: isSupported ? nil : "Not supported for \(settings.containerFormat.rawValue.uppercased())"
                    )
                }
            )

            // Container Format Picker
            MenuBarExpandablePicker(
                name: "Container",
                selection: $settings.containerFormat,
                options: ContainerFormat.allCases.map { ($0, $0.rawValue.uppercased()) }
            )

            // Alpha Channel Toggle (disabled if codec doesn't support or container doesn't support)
            MenuBarToggle(
                name: "Capture Alpha Channel",
                isOn: $settings.captureAlphaChannel,
                isDisabled: !settings.videoCodec.canToggleAlpha || !settings.containerFormat.supportsAlphaChannel
            )

            // HDR Recording Toggle (disabled for codecs that don't support HDR)
            MenuBarToggle(
                name: "HDR Recording",
                isOn: $settings.captureHDR,
                isDisabled: !settings.videoCodec.supportsHDR
            )
        }
    }
}

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

            // Audio Codec Picker (shows all codecs, disables incompatible ones)
            MenuBarExpandablePicker(
                name: "Audio Codec",
                selection: $settings.audioCodec,
                optionsWithState: AudioCodec.allCases.map { codec in
                    let isSupported = settings.containerFormat.supportedAudioCodecs.contains(codec)
                    return PickerOption(
                        value: codec,
                        label: codec.rawValue,
                        isDisabled: !isSupported,
                        disabledMessage: isSupported ? nil : "Not supported for \(settings.containerFormat.rawValue.uppercased())"
                    )
                }
            )
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
        VideoSettingsSection(settings: SettingsStore())
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
