//
//  MenuBarView.swift
//  Reco
//
//  Created by Joshua Sattler on 29.01.26.
//

import SwiftUI
import ScreenCaptureKit

/// The main menu bar interface for Reco
struct MenuBarView: View {
    @Bindable var viewModel: RecorderViewModel
    let screenshots: ScreenshotController
    let editLastRecording: () -> Void
    let showLibrary: () -> Void
    let showWebRecording: () -> Void
    let showAgentRecording: () -> Void
    let agentRecording: AgentRecordingViewModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss
    private var isRecording: Bool { viewModel.isRecording }

    var body: some View {
        VStack(spacing: 0) {
            // Permission status banner (only when idle)
            if !isRecording,
               viewModel.permissionService.screenRecordingState != .granted ||
                (viewModel.settings.captureMicrophone && viewModel.permissionService.microphoneState != .granted) ||
                (viewModel.settings.presenterOverlayEnabled && viewModel.permissionService.cameraState != .granted) {
                PermissionStatusBanner(
                    permissionService: viewModel.permissionService,
                    showMicrophonePermission: viewModel.settings.captureMicrophone,
                    showCameraPermission: viewModel.settings.presenterOverlayEnabled
                )
                MenuBarDivider()
            }

            // Why the last recording failed, until dismissed: notifications may be off
            if let error = viewModel.lastError, !isRecording {
                MenuBarErrorRow(message: error.localizedDescription, dismiss: viewModel.dismissError)
                MenuBarDivider()
            }

            // Stop and pause while recording; saving; the countdown's cancel; otherwise what to
            // record, and Start once it's chosen
            if isRecording {
                RecordingButton(
                    duration: viewModel.formattedDuration
                ) {
                    Task {
                        await viewModel.stopRecording()
                    }
                }
                .padding(.top, 8)

                MenuBarActionButton(
                    title: viewModel.isPaused ? "Resume Recording" : "Pause Recording",
                    systemImage: viewModel.isPaused ? "play.circle" : "pause.circle",
                    shortcut: .pauseRecording
                ) {
                    viewModel.togglePause()
                }
            } else if viewModel.state == .stopping {
                // Finishing the file takes a moment; nothing can start meanwhile
                HStack(spacing: EditorTheme.mediumSpacing) {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 20)
                    Text("Saving Recording…")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, EditorTheme.mediumSpacing)
                .padding(.vertical, EditorTheme.smallSpacing)
                .padding(.top, EditorTheme.smallSpacing)
            } else if let remaining = viewModel.countdown.remaining {
                MenuBarActionButton(
                    title: "Cancel Countdown (\(remaining))",
                    systemImage: "xmark.circle"
                ) {
                    viewModel.cancelCountdown()
                }
                .padding(.top, 8)
            } else {
                SectionHeader(title: "Record")
                    .padding(.top, 8)
                if viewModel.hasContentSelected {
                    MenuBarActionButton(title: "Start Recording", systemImage: "record.circle", isDisabled: !viewModel.canStartRecording, shortcut: .toggleRecording) {
                        Task {
                            await viewModel.startRecordingWithCountdown()
                            dismiss()
                        }
                    }
                    ContentSelectionButton(viewModel: viewModel) { dismiss() }
                    SelectedContentPreview(viewModel: viewModel)
                } else {
                    // Choosing is the first step, so it's what the menu offers; Start follows it
                    MenuBarActionButton(title: "Record Area…", systemImage: "rectangle.dashed.badge.record", shortcut: .selectArea) {
                        dismiss()
                        Task { await viewModel.presentAreaSelection() }
                    }
                    MenuBarActionButton(title: "Record Window or Display…", systemImage: "macwindow", shortcut: .selectContent) {
                        viewModel.presentPicker()
                    }
                }

                SectionHeader(title: "Screenshot")
                    .padding(.top, 4)
                ScreenshotButtons(controller: screenshots, recorder: viewModel)
            }

            // What each take captures; video formats and the content filter are in Settings → Video
            Group {
                AudioSettingsSection(
                    settings: viewModel.settings,
                    audioDeviceService: viewModel.audioDeviceService
                )

                PresenterOverlaySettingsSection(
                    settings: viewModel.settings,
                    cameraDeviceService: viewModel.cameraDeviceService,
                    permissionService: viewModel.permissionService
                )
            }
            // Fixed from the countdown until the file is saved
            .disabled(viewModel.state != .idle || viewModel.countdown.isRunning)

            MenuBarDivider()

            // Bottom Actions
            if viewModel.lastRecordingURL != nil {
                MenuBarActionButton(title: "Edit Last Recording", systemImage: "film") {
                    editLastRecording()
                    dismiss()
                }
            }

            MenuBarActionButton(title: "Library…", systemImage: "square.grid.2x2") {
                showLibrary()
                dismiss()
            }

            MenuBarActionButton(title: "New Web Recording…", systemImage: "globe") {
                showWebRecording()
                dismiss()
            }

            if agentRecording.isRunning {
                MenuBarActionButton(title: "Cancel Agent Recording", systemImage: "xmark.circle") {
                    agentRecording.cancel()
                }
            } else {
                MenuBarActionButton(title: "Record with AI Agent…", systemImage: "sparkles", shortcut: .recordWithAgent) {
                    showAgentRecording()
                    dismiss()
                }
            }

            MenuBarDivider()

            MenuBarActionButton(title: "Settings…", systemImage: "gear") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            }

            MenuBarActionButton(title: "Quit Reco", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.bottom, 8)
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Error

/// The last recording failure, in the popover's row layout, with a button to put it away.
struct MenuBarErrorRow: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: EditorTheme.mediumSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, EditorTheme.mediumSpacing)
        .padding(.vertical, EditorTheme.smallSpacing)
        .padding(.top, EditorTheme.tightSpacing)
    }
}

// MARK: - Selected Content

/// What's selected to record, as a picture, live on request, and Reset to choose again.
struct SelectedContentPreview: View {
    let viewModel: RecorderViewModel
    @State private var currentPreview: NSImage?

    var body: some View {
        PreviewThumbnailView(
            previewImage: currentPreview,
            isLivePreviewActive: viewModel.previewService.isCapturing,
            onStartLivePreview: {
                Task {
                    await viewModel.startPreview()
                }
            },
            onStopLivePreview: {
                Task {
                    await viewModel.stopPreview()
                }
            }
        )
        .onChange(of: viewModel.previewService.previewImage) { _, newImage in
            currentPreview = newImage
        }
        .onAppear {
            currentPreview = viewModel.previewService.previewImage
        }

        Button {
            Task {
                await viewModel.resetSelection()
            }
        } label: {
            Text("Reset Selection")
                .font(.body.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.gray.opacity(0.15), in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Recording Button

/// A combined button that shows recording status and allows stopping. The red is the one color
/// in the popover: it means stop.
struct RecordingButton: View {
    let duration: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "stop.circle")
                    .foregroundStyle(.red)
                    .frame(width: 20)

                Text("Stop Recording")
                    .font(.body.weight(.semibold))

                Spacer()

                Text(duration)
                    .font(.body.weight(.medium).monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .buttonStyle(.menuRow)
    }
}

// MARK: - Content Selection Button

/// A split button that triggers the active content selection mode, with a dropdown chevron to switch modes.
/// The left portion triggers the action; the right chevron opens a dropdown to change the mode.
/// Styled consistently with other menu bar rows.
struct ContentSelectionButton: View {
    let viewModel: RecorderViewModel
    var onDismissPanel: (() -> Void)?
    @AppStorage(ContentSelectionMode.storageKey) private var mode: ContentSelectionMode = .pickContent
    @State private var isDropdownExpanded = false

    /// Whether content has been selected via the currently active mode
    private var hasActiveSelection: Bool {
        switch mode {
        case .pickContent:
            viewModel.hasContentSelected && !viewModel.isAreaSelection
        case .selectArea:
            viewModel.isAreaSelection
        }
    }

    private var buttonLabel: String {
        hasActiveSelection ? "Change \(mode.label.split(separator: " ").last, default: "Content")…" : "\(mode.label)…"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main button row: the action, and beside it the chevron that opens the modes
            HStack(spacing: 0) {
                Button {
                    triggerAction()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mode.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        Text(buttonLabel)
                            .font(.body.weight(.medium))

                        Spacer()
                    }
                    .padding(.leading, 12)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.menuRow)

                Button {
                    withMotion { isDropdownExpanded.toggle() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isDropdownExpanded ? 90 : 0))
                        .frame(width: 36, height: 28)
                }
                .buttonStyle(.menuRow)
            }

            // Dropdown options
            if isDropdownExpanded {
                VStack(spacing: 0) {
                    DeviceRow(
                        name: ContentSelectionMode.pickContent.label,
                        icon: ContentSelectionMode.pickContent.icon,
                        isSelected: mode == .pickContent
                    ) {
                        mode = .pickContent
                        withMotion { isDropdownExpanded = false }
                    }

                    DeviceRow(
                        name: ContentSelectionMode.selectArea.label,
                        icon: ContentSelectionMode.selectArea.icon,
                        isSelected: mode == .selectArea
                    ) {
                        mode = .selectArea
                        withMotion { isDropdownExpanded = false }
                    }
                }
                .padding(.leading, 12)
                .background(.quaternary.opacity(0.3))
            }
        }
    }

    private func triggerAction() {
        switch mode {
        case .pickContent:
            viewModel.presentPicker()
        case .selectArea:
            onDismissPanel?()
            Task {
                await viewModel.presentAreaSelection()
            }
        }
    }
}

// MARK: - Permission Status Banner

/// A banner showing missing permissions with buttons to open System Settings
struct PermissionStatusBanner: View {
    let permissionService: PermissionService
    let showMicrophonePermission: Bool
    let showCameraPermission: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Permissions Required")
                    .font(.body.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if permissionService.screenRecordingState != .granted {
                PermissionRow(
                    title: "Screen Recording",
                    isGranted: false
                ) {
                    permissionService.openScreenRecordingSettings()
                }
            }

            if showMicrophonePermission && permissionService.microphoneState != .granted {
                PermissionRow(
                    title: "Microphone",
                    isGranted: false
                ) {
                    permissionService.openMicrophoneSettings()
                }
            }

            if showCameraPermission && permissionService.cameraState != .granted {
                PermissionRow(
                    title: "Camera",
                    isGranted: false
                ) {
                    permissionService.openCameraSettings()
                }
            }
        }
        .padding(.bottom, 8)
    }
}

/// A single permission row with status and action button
struct PermissionRow: View {
    let title: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isGranted ? .green : .red)
                    .font(.callout)

                Text(title)
                    .font(.callout)

                Spacer()

                if !isGranted {
                    Text("Open Settings")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .buttonStyle(.menuRow)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(
        viewModel: RecorderViewModel(),
        screenshots: .init(settings: SettingsStore(), notificationService: .init(settings: SettingsStore())),
        editLastRecording: {},
        showLibrary: {},
        showWebRecording: {},
        showAgentRecording: {},
        agentRecording: AgentRecordingViewModel(
            tools: AgentTools(settings: SettingsStore()) { _ in },
            reportFailure: { _ in },
            token: ""
        )
    )
}
