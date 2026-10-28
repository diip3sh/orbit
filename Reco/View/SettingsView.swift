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

    /// The pane showing, which "Set Up Agents…" in the Record with AI Agent panel switches.
    @AppStorage(AgentsSettingsView.tabStorageKey) private var tab = SettingsTab.general

    /// The title bar's height, which the window adds to the content's.
    @State private var titlebarInset: CGFloat = 0

    private static let windowSize = CGSize(width: 856, height: 700)

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            SettingsSidebar(selection: $tab)
                .frame(width: 210)

            Group {
                switch tab {
                case .general:
                    GeneralSettingsView(settings: settings, updaterService: updaterService)
                case .video:
                    VideoSettingsView(settings: settings)
                case .screenshots:
                    ScreenshotSettingsView(settings: settings)
                case .audio:
                    AudioSettingsView(settings: settings)
                case .shortcuts:
                    ShortcutsSettingsView()
                case .agents:
                    AgentsSettingsView(server: agentBridge)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(EditorTheme.smallSpacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        // The window is sized from the safe area, so the title bar's height comes off the content's
        .frame(width: Self.windowSize.width, height: Self.windowSize.height - titlebarInset)
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { titlebarInset = $0 }
        .editorWindowBackground()
        // No title bar background or its line over the pane's scroll view: the pane's title is its own header
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar(removing: .title)
        .background(SettingsWindowConfigurator())
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    var body: some View {
        SettingsPage("Shortcuts") {
            SettingsSection("Capture Toolbar") {
                ShortcutRow("Screenshot", name: .showScreenshotToolbar)
                ShortcutRow("Record", name: .showRecordingToolbar)
            }

            SettingsSection("Recording") {
                ShortcutRow("Toggle Recording", name: .toggleRecording)
                ShortcutRow("Pause/Resume Recording", name: .pauseRecording)
                ShortcutRow("Restart Recording", name: .restartRecording)
                ShortcutRow("Cancel Recording", name: .cancelRecording)
            }

            SettingsSection("Web Recording") {
                ShortcutRow("Record with AI Agent", name: .recordWithAgent)
            }

            SettingsSection("Content Selection") {
                ShortcutRow("Select Content", name: .selectContent)
                ShortcutRow("Select Area", name: .selectArea)
            }

            SettingsSection("Screenshots", footer: "Shortcuts work globally, even when Orbit is not focused.") {
                ShortcutRow("Capture Area", name: .captureArea)
                ShortcutRow("Capture Previous Area", name: .capturePreviousArea)
                ShortcutRow("Capture Window", name: .captureWindow)
                ShortcutRow("Capture Screen", name: .captureScreen)
            }
        }
    }
}

/// A shortcut's name with its recorder on the right edge.
private struct ShortcutRow: View {
    let title: LocalizedStringKey
    let name: KeyboardShortcuts.Name

    init(_ title: LocalizedStringKey, name: KeyboardShortcuts.Name) {
        self.title = title
        self.name = name
    }

    var body: some View {
        LabeledContent(title) {
            KeyboardShortcuts.Recorder(for: name)
                .fixedSize()
        }
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
        SettingsPage("Video") {
            SettingsSection("Recording") {
                SettingsPicker("Frame Rate", selection: $settings.frameRate, value: settings.frameRate.displayName) {
                    ForEach(FrameRate.allCases) { rate in
                        Text(rate.displayName).tag(rate)
                    }
                }

                SettingsPicker("Codec", selection: $settings.videoCodec, value: settings.videoCodec.rawValue) {
                    ForEach(VideoCodec.allCases) { codec in
                        let isSupported = settings.containerFormat.supportedVideoCodecs.contains(codec)
                        if isSupported {
                            Text(codec.rawValue).tag(codec)
                        } else {
                            Text("\(codec.rawValue) (not supported for \(settings.containerFormat.rawValue.uppercased()))")
                                .foregroundStyle(EditorTheme.dim)
                                .tag(codec)
                        }
                    }
                }

                SettingsPicker("Container", selection: $settings.containerFormat, value: ".\(settings.containerFormat.rawValue)") {
                    ForEach(ContainerFormat.allCases) { format in
                        Text(".\(format.rawValue)").tag(format)
                    }
                }

                SettingsPicker("Quality", selection: $settings.videoQuality, value: settings.videoQuality.rawValue) {
                    ForEach(VideoQuality.allCases) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
                .disabled(!settings.videoCodec.supportsQualitySetting)
                .help(qualityHelpText)
            }

            SettingsSection("Advanced") {
                Toggle("Capture Alpha Channel", isOn: $settings.captureAlphaChannel)
                    .disabled(!settings.videoCodec.canToggleAlpha || !settings.containerFormat.supportsAlphaChannel)
                    .help(alphaChannelHelpText)

                Toggle("HDR Recording", isOn: $settings.captureHDR)
                    .disabled(!settings.videoCodec.supportsHDR)
                    .help(hdrHelpText)

                Toggle("Native Resolution", isOn: $settings.captureNativeResolution)
                    .help(captureNativeResHelpText)

                Toggle(isOn: $settings.recordInputTelemetry) {
                    SettingsLabel(
                        "Record Input Telemetry",
                        detail: """
                            Saves cursor, clicks, scrolls and keystrokes next to each recording. \
                            All but the cursor need Input Monitoring permission (relaunch after granting).
                            """
                    )
                }
                .onChange(of: settings.recordInputTelemetry) { _, isEnabled in
                    // Ask up front; without Input Monitoring clicks, scrolls and keystrokes are simply skipped
                    if isEnabled && !CGPreflightListenEventAccess() {
                        _ = CGRequestListenEventAccess()
                    }
                }

                Toggle(isOn: $settings.keepSystemCursorInVideo) {
                    SettingsLabel(
                        "Keep System Cursor in Video",
                        detail: "When off, the cursor is left out of the video so the editor can redraw it smoothly. Recordings have no cursor until edited."
                    )
                }
                .disabled(!settings.recordInputTelemetry)
            }

            SettingsSection("Display Elements") {
                Toggle("Show Cursor", isOn: $settings.showCursor)
                    .disabled(settings.leavesCursorToEditor)
                    .help(settings.leavesCursorToEditor ? "The cursor is left for the editor while Record Input Telemetry is on" : "")
                Toggle("Show Wallpaper", isOn: $settings.showWallpaper)
                Toggle("Show Menu Bar", isOn: $settings.showMenuBar)
                Toggle("Show Dock", isOn: $settings.showDock)
                Toggle("Show Desktop Icons", isOn: $settings.showDesktopIcons)
                Toggle("Show Orbit", isOn: $settings.showReco)
            }

            SettingsSection("Window Capture") {
                Toggle("Show Window Shadows", isOn: $settings.showWindowShadows)
                    .help("Include window shadows when capturing individual windows")
            }
        }
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        SettingsPage("Audio") {
            SettingsSection("Sources") {
                Toggle("Capture System Audio", isOn: $settings.captureSystemAudio)
                    .help("Record audio from applications and system sounds")

                Toggle("Capture Microphone", isOn: $settings.captureMicrophone)
                    .help("Record audio from the default microphone input")
            }

            SettingsSection("Format", footer: "Audio tracks are recorded separately for post-processing flexibility.") {
                SettingsPicker("Codec", selection: $settings.audioCodec, value: settings.audioCodec.rawValue) {
                    ForEach(AudioCodec.allCases) { codec in
                        let isSupported = settings.containerFormat.supportedAudioCodecs.contains(codec)
                        if isSupported {
                            Text(codec.rawValue).tag(codec)
                        } else {
                            Text("\(codec.rawValue) (not supported for \(settings.containerFormat.rawValue.uppercased()))")
                                .foregroundStyle(EditorTheme.dim)
                                .tag(codec)
                        }
                    }
                }
                .help("AAC is compressed, PCM is uncompressed lossless (MOV only)")
            }
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Bindable var settings: SettingsStore
    @Bindable var updaterService: UpdaterService

    var body: some View {
        SettingsPage("General") {
            SettingsSection("Output Location") {
                FolderSettingRow(
                    title: "Recordings",
                    folder: settings.outputDirectory,
                    isCustom: settings.hasCustomOutputDirectory,
                    change: selectOutputDirectory,
                    reset: settings.resetOutputDirectory
                )
                FolderSettingRow(
                    title: "Screenshots",
                    folder: settings.screenshotDirectory,
                    isCustom: settings.hasCustomScreenshotDirectory,
                    change: selectScreenshotDirectory,
                    reset: settings.resetScreenshotDirectory
                )
            }

            SettingsSection("Recording") {
                SettingsPicker("Countdown", selection: $settings.countdownDuration, value: settings.countdownDuration.displayName) {
                    ForEach(CountdownDuration.allCases) { duration in
                        Text(duration.displayName).tag(duration)
                    }
                }
            }

            SettingsSection("Software Updates") {
                Toggle("Automatically Check for Updates", isOn: $updaterService.automaticallyChecksForUpdates)

                LabeledContent("Updates") {
                    Button("Check for Updates…") {
                        updaterService.checkForUpdates()
                    }
                    .disabled(!updaterService.canCheckForUpdates)
                }
            }

            AboutSection()
        }
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

    private func selectScreenshotDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Select Screenshot Folder"
        panel.message = "Choose where screenshots will be saved"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.screenshotDirectory

        if panel.runModal() == .OK, let url = panel.url {
            settings.screenshotDirectory = url
        }
    }
}

/// A save folder: its path, with Change… and, once changed, Reset
private struct FolderSettingRow: View {

    let title: String
    let folder: URL
    let isCustom: Bool
    let change: () -> Void
    let reset: () -> Void

    /// The path with the home folder as ~
    private var displayPath: String {
        let path = folder.path(percentEncoded: false)
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    var body: some View {
        LabeledContent {
            HStack {
                Button("Change…", action: change)

                if isCustom {
                    Button("Reset", role: .destructive, action: reset)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                    Text(displayPath)
                        .font(.theme(.subheadline, .mono))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.theme(.subheadline))
                .foregroundStyle(EditorTheme.dim)
            }
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
        SettingsSection("About") {
            LabeledContent("Version") {
                Text(verbatim: "v\(appVersion) (\(gitSHA))")
                    .font(.theme(.callout, .mono))
                    .textSelection(.enabled)
            }

            LabeledContent("Source Code") {
                AboutLink("github.com/diip3sh/reco", destination: URL(string: "https://github.com/diip3sh/reco")!)
            }

            LabeledContent("Based On") {
                AboutLink("BetterCapture by Joshua Sattler", destination: URL(string: "https://github.com/jsattler/BetterCapture")!)
            }

            // Paper Shaders' NOTICE (Apache-2.0): the motion editor's backgrounds are ported from them
            LabeledContent("Motion Backgrounds") {
                AboutLink("Powered by Paper Shaders, © 2026 Paper", destination: URL(string: "https://shaders.paper.design")!)
            }
        }
    }
}

/// A link in the About card, as text in the accent.
private struct AboutLink: View {
    let title: String
    let destination: URL

    init(_ title: String, destination: URL) {
        self.title = title
        self.destination = destination
    }

    var body: some View {
        Link(destination: destination) {
            Text(verbatim: title)
                .font(.theme(.body, weight: .medium))
                // The fill's colour set: `accent` follows the system and greys out with the window
                .foregroundStyle(EditorTheme.accentFill)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
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
