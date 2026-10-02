//
//  SettingsView.swift
//  Reco
//
//  Created by Joshua Sattler on 29.01.26.
//

import AppKit
import KeyboardShortcuts
import SwiftUI

/// The settings window for Reco
struct SettingsView: View {
    @Bindable var settings: SettingsStore
    var updaterService: UpdaterService
    var agentBridge: AgentBridgeServer

    /// The tab showing, which "Set Up Agents…" in the Record with AI Agent panel switches.
    @AppStorage(AgentsSettingsView.tabStorageKey) private var tab = "general"

    var body: some View {
        TabView(selection: $tab) {
            Tab("General", systemImage: "gearshape", value: "general") {
                GeneralSettingsView(settings: settings, updaterService: updaterService)
            }

            Tab("Video", systemImage: "video", value: "video") {
                VideoSettingsView(settings: settings)
            }

            Tab("Audio", systemImage: "waveform", value: "audio") {
                AudioSettingsView(settings: settings)
            }

            Tab("Shortcuts", systemImage: "keyboard", value: "shortcuts") {
                ShortcutsSettingsView()
            }

            Tab("Agents", systemImage: "terminal", value: AgentsSettingsView.tag) {
                AgentsSettingsView(server: agentBridge)
            }
        }
        .frame(width: 500, height: 420)
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Recording") {
                KeyboardShortcuts.Recorder("Toggle Recording", name: .toggleRecording)
                KeyboardShortcuts.Recorder("Pause/Resume Recording", name: .pauseRecording)
                KeyboardShortcuts.Recorder("Cancel Recording", name: .cancelRecording)
                KeyboardShortcuts.Recorder("Restart Recording", name: .restartRecording)
            }

            Section("Web Recording") {
                KeyboardShortcuts.Recorder("Record with AI Agent", name: .recordWithAgent)
            }

            Section("Content Selection") {
                KeyboardShortcuts.Recorder("Select Content", name: .selectContent)
                KeyboardShortcuts.Recorder("Select Area", name: .selectArea)
            }

            Section("Screenshots") {
                KeyboardShortcuts.Recorder("Capture Area", name: .captureArea)
                KeyboardShortcuts.Recorder("Capture Window", name: .captureWindow)
                KeyboardShortcuts.Recorder("Capture Screen", name: .captureScreen)
            }

            Section {
                Text("Shortcuts work globally, even when Reco is not focused.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Video Settings

struct VideoSettingsView: View {
    @Bindable var settings: SettingsStore

    private var alphaChannelHelpText: String {
        switch settings.videoCodec {
        case .proRes4444:
            return "ProRes 4444 always includes alpha channel support"
        case .hevc:
            return "Enable transparency support for HEVC"
        case .h264, .proRes422:
            return "Alpha channel not supported by this codec"
        }
    }

    private var hdrHelpText: String {
        if settings.videoCodec.supportsHDR {
            return "Enable 10-bit HDR capture for high dynamic range content"
        } else {
            return "HDR is only supported with ProRes 422 and ProRes 4444 codecs"
        }
    }

    private var qualityHelpText: String {
        if settings.videoCodec.supportsQualitySetting {
            return "Controls the video bitrate. Higher quality produces sharper output with larger files"
        } else {
            return "ProRes codecs use fixed-quality encoding"
        }
    }

    private let captureNativeResHelpText = """
        When enabled, captures at the display's native pixel resolution. \
        When disabled, captures at the logical (1x) resolution. Has no effect on non-Retina displays
        """

    var body: some View {
        Form {
            Section("Recording") {
                Picker("Frame Rate", selection: $settings.frameRate) {
                    ForEach(FrameRate.allCases) { rate in
                        Text(rate.displayName).tag(rate)
                    }
                }

                Picker("Codec", selection: $settings.videoCodec) {
                    ForEach(VideoCodec.allCases) { codec in
                        let isSupported = settings.containerFormat.supportedVideoCodecs.contains(codec)
                        if isSupported {
                            Text(codec.rawValue).tag(codec)
                        } else {
                            Text("\(codec.rawValue) (not supported for \(settings.containerFormat.rawValue.uppercased()))")
                                .foregroundStyle(.secondary)
                                .tag(codec)
                        }
                    }
                }

                Picker("Container", selection: $settings.containerFormat) {
                    ForEach(ContainerFormat.allCases) { format in
                        Text(".\(format.rawValue)").tag(format)
                    }
                }

                Picker("Quality", selection: $settings.videoQuality) {
                    ForEach(VideoQuality.allCases) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
                .disabled(!settings.videoCodec.supportsQualitySetting)
                .help(qualityHelpText)
            }

            Section("Advanced") {
                Toggle("Capture Alpha Channel", isOn: $settings.captureAlphaChannel)
                    .disabled(!settings.videoCodec.canToggleAlpha || !settings.containerFormat.supportsAlphaChannel)
                    .help(alphaChannelHelpText)

                Toggle("HDR Recording", isOn: $settings.captureHDR)
                    .disabled(!settings.videoCodec.supportsHDR)
                    .help(hdrHelpText)

                Toggle("Native Resolution", isOn: $settings.captureNativeResolution)
                    .help(captureNativeResHelpText)

                Toggle(isOn: $settings.recordInputTelemetry) {
                    Text("Record Input Telemetry")
                    Text("Saves cursor, clicks, scrolls and keystrokes next to each recording. All but the cursor need Input Monitoring permission (relaunch after granting).")
                }
                .onChange(of: settings.recordInputTelemetry) { _, isEnabled in
                    // Ask up front; without Input Monitoring clicks, scrolls and keystrokes are simply skipped
                    if isEnabled && !CGPreflightListenEventAccess() {
                        _ = CGRequestListenEventAccess()
                    }
                }

                Toggle(isOn: $settings.keepSystemCursorInVideo) {
                    Text("Keep System Cursor in Video")
                    Text("When off, the cursor is left out of the video so the editor can redraw it smoothly. Recordings have no cursor until edited.")
                }
                .disabled(!settings.recordInputTelemetry)
            }

            Section("Display Elements") {
                Toggle("Show Cursor", isOn: $settings.showCursor)
                    .disabled(settings.leavesCursorToEditor)
                    .help(settings.leavesCursorToEditor ? "The cursor is left for the editor while Record Input Telemetry is on" : "")
                Toggle("Show Wallpaper", isOn: $settings.showWallpaper)
                Toggle("Show Menu Bar", isOn: $settings.showMenuBar)
                Toggle("Show Dock", isOn: $settings.showDock)
                Toggle("Show Reco", isOn: $settings.showReco)
            }

            Section("Window Capture") {
                Toggle("Show Window Shadows", isOn: $settings.showWindowShadows)
                    .help("Include window shadows when capturing individual windows")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("Sources") {
                Toggle("Capture System Audio", isOn: $settings.captureSystemAudio)
                    .help("Record audio from applications and system sounds")

                Toggle("Capture Microphone", isOn: $settings.captureMicrophone)
                    .help("Record audio from the default microphone input")
            }

            Section("Format") {
                Picker("Codec", selection: $settings.audioCodec) {
                    ForEach(AudioCodec.allCases) { codec in
                        let isSupported = settings.containerFormat.supportedAudioCodecs.contains(codec)
                        if isSupported {
                            Text(codec.rawValue).tag(codec)
                        } else {
                            Text("\(codec.rawValue) (not supported for \(settings.containerFormat.rawValue.uppercased()))")
                                .foregroundStyle(.secondary)
                                .tag(codec)
                        }
                    }
                }
                .help("AAC is compressed, PCM is uncompressed lossless (MOV only)")
            }

            Section {
                Text("Audio tracks are recorded separately for post-processing flexibility.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Bindable var settings: SettingsStore
    @Bindable var updaterService: UpdaterService

    /// Formats the output directory path for display
    private var displayPath: String {
        let path = settings.outputDirectory.path(percentEncoded: false)
        // Replace home directory with ~ for cleaner display
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    var body: some View {
        Form {
            Section("Output Location") {
                LabeledContent {
                    HStack {
                        Button("Change...") {
                            selectOutputDirectory()
                        }

                        if settings.hasCustomOutputDirectory {
                            Button("Reset", role: .destructive) {
                                settings.resetOutputDirectory()
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text(displayPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            Section("Recording") {
                Picker("Countdown", selection: $settings.countdownDuration) {
                    ForEach(CountdownDuration.allCases) { duration in
                        Text(duration.displayName).tag(duration)
                    }
                }
            }

            Section("Software Updates") {
                Toggle("Automatically check for updates", isOn: $updaterService.automaticallyChecksForUpdates)

                LabeledContent("Updates") {
                    Button("Check for Update") {
                        updaterService.checkForUpdates()
                    }
                    .disabled(!updaterService.canCheckForUpdates)
                }
            }

            AboutSection()
        }
        .formStyle(.grouped)
        .padding()
    }

    /// Opens an NSOpenPanel to select a custom output directory
    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Select Output Directory"
        panel.message = "Choose where recordings will be saved"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.outputDirectory

        if panel.runModal() == .OK, let url = panel.url {
            settings.setCustomOutputDirectory(url)
        }
    }
}

// MARK: - About Section

struct AboutSection: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var gitSHA: String {
        Bundle.main.infoDictionary?["GitSHA"] as? String ?? "dev"
    }

    var body: some View {
        Section("About") {
            LabeledContent("Version", value: "v\(appVersion) (\(gitSHA))")

            LabeledContent("Source Code") {
                Link("github.com/diip3sh/reco", destination: URL(string: "https://github.com/diip3sh/reco")!)
            }

            LabeledContent("Based On") {
                Link("BetterCapture by Joshua Sattler", destination: URL(string: "https://github.com/jsattler/BetterCapture")!)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let settings = SettingsStore()
    SettingsView(
        settings: settings,
        updaterService: UpdaterService(),
        agentBridge: AgentBridgeServer(tools: AgentTools(settings: settings) { _ in })
    )
}
