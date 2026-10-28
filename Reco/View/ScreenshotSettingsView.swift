//
//  ScreenshotSettingsView.swift
//  Reco
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// Settings → Screenshots: HDR, the history, and the background a card's Add Background puts a shot on.
struct ScreenshotSettingsView: View {
    @Bindable var settings: SettingsStore
    @State private var confirmsClearingHistory = false

    var body: some View {
        SettingsPage("Screenshots") {
            if #available(macOS 26.0, *) {
                SettingsSection(
                    "Capture",
                    footer: "Screen and area screenshots keep HDR content's brightness and are saved as HEIC. Copied screenshots stay standard PNGs."
                ) {
                    Toggle("Capture HDR Screenshots", isOn: $settings.capturesHDRScreenshots)
                }
            }

            SettingsSection(
                "History",
                footer: """
                    Every screenshot you take, copied or not, is kept in the Library for this long, then deleted, unless you save it. \
                    Only screenshots you save go into your folder.
                    """
            ) {
                SettingsPicker(
                    "Keep Screenshots",
                    selection: $settings.screenshotHistoryRetention,
                    value: settings.screenshotHistoryRetention.displayName
                ) {
                    ForEach(ScreenshotHistoryRetention.allCases) { retention in
                        Text(retention.displayName).tag(retention)
                    }
                }
                Toggle("Show Screenshots in the Notch", isOn: $settings.showsScreenshotsInNotch)
                LabeledContent("Unsaved Screenshots") {
                    Button("Clear History…") {
                        confirmsClearingHistory = true
                    }
                }
            }
            .confirmationDialog("Clear screenshot history?", isPresented: $confirmsClearingHistory) {
                Button("Clear History", role: .destructive) {
                    Task { await ScreenshotHistory.clear() }
                }
            } message: {
                Text("Screenshots you haven't saved are deleted for good.")
            }

            SettingsSection(
                "Background",
                footer: "What a screenshot's card adds when you click its background button. Auto Balance trims borders of one colour first, so the padding is even."
            ) {
                ScreenshotBackgroundSettings(settings: settings)
            }
        }
    }
}

/// The background's controls, the editor's canvas controls bound to the setting, and Auto Balance.
private struct ScreenshotBackgroundSettings: View {
    @Bindable var settings: SettingsStore
    @State private var wallpapers: [SystemWallpaper] = []
    @State private var imageURL: URL?
    @State private var choosesImage = false

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "Settings")

    var body: some View {
        CanvasStyleControls(
            canvas: $settings.screenshotBackground.canvas, wallpapers: wallpapers, imageURL: imageURL,
            setImage: setImage, choosesImage: $choosesImage
        )
        Toggle("Auto Balance", isOn: $settings.screenshotBackground.autoBalances)
            .task { wallpapers = await SystemWallpaper.installed() }
            .task(id: settings.screenshotBackground.canvas.imageBookmark) {
                imageURL = settings.screenshotBackground.canvas.imageBookmark.flatMap(BackgroundImageLoader.url)?.resolvingSymlinksInPath()
            }
            .fileImporter(isPresented: $choosesImage, allowedContentTypes: [.image]) { result in
                if case .success(let url) = result {
                    setImage(url)
                }
            }
    }

    private func setImage(_ url: URL) {
        do {
            try settings.setScreenshotBackgroundImage(url)
        } catch {
            logger.error("No bookmark for \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
