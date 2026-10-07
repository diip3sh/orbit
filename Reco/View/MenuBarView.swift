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
    let showScreenshotToolbar: () -> Void
    let showRecordingToolbar: () -> Void
    let editLastRecording: () -> Void
    let showLibrary: () -> Void
    let showWebRecording: () -> Void
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

            // The ways in first; saving, the take's controls and choosing what to capture are on the capture toolbar
            VStack(spacing: 0) {
                if viewModel.state == .stopping {
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
                } else if viewModel.state == .idle {
                    MenuBarActionButton(
                        title: "Screenshot", systemImage: "camera.viewfinder", isDisabled: viewModel.countdown.isRunning,
                        shortcut: .showScreenshotToolbar
                    ) {
                        dismiss()
                        showScreenshotToolbar()
                    }
                    MenuBarActionButton(
                        title: "Record", systemImage: "record.circle", isDisabled: viewModel.countdown.isRunning,
                        shortcut: .showRecordingToolbar
                    ) {
                        dismiss()
                        showRecordingToolbar()
                    }
                }

                MenuBarActionButton(title: "Product Record", systemImage: "globe") {
                    showWebRecording()
                    dismiss()
                }

                MenuBarActionButton(title: "Library", systemImage: "square.grid.2x2") {
                    showLibrary()
                    dismiss()
                }

                if viewModel.lastRecordingURL != nil {
                    MenuBarActionButton(title: "Edit Last Recording", systemImage: "film") {
                        editLastRecording()
                        dismiss()
                    }
                }

                if agentRecording.isRunning {
                    MenuBarActionButton(title: "Cancel Agent Recording", systemImage: "xmark.circle") {
                        agentRecording.cancel()
                    }
                }
            }
            .padding(.top, 8)

            // What each take captures (it opens with its own divider); video formats and the content filter are in Settings → Video
            CaptureSettingsSection(
                settings: viewModel.settings,
                audioDeviceService: viewModel.audioDeviceService,
                cameraDeviceService: viewModel.cameraDeviceService,
                permissionService: viewModel.permissionService
            )
            // Fixed from the countdown until the file is saved
            .disabled(viewModel.state != .idle || viewModel.countdown.isRunning)

            MenuBarDivider()

            MenuBarActionButton(title: "Settings…", systemImage: "gear") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            }

            MenuBarActionButton(title: "Quit Orbit", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.bottom, 8)
        }
        .frame(width: 288)
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
            .padding(.vertical, 6)
        }
        .buttonStyle(.menuRow)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(
        viewModel: RecorderViewModel(),
        showScreenshotToolbar: {},
        showRecordingToolbar: {},
        editLastRecording: {},
        showLibrary: {},
        showWebRecording: {},
        agentRecording: AgentRecordingViewModel(
            tools: AgentTools(settings: SettingsStore()) { _ in },
            reportFailure: { _ in },
            token: ""
        )
    )
}
