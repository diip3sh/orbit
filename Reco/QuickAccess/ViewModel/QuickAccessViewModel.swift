//
//  QuickAccessViewModel.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import Accessibility
import AppKit
import OSLog
import UniformTypeIdentifiers

/// State and intents of the Quick Access card for one screenshot, which stays in memory until saved.
@MainActor
@Observable
final class QuickAccessViewModel {

    /// A short confirmation shown on the card
    enum Feedback {
        case textCopied
        case noTextFound

        var message: String {
            switch self {
            case .textCopied: "Text Copied"
            case .noTextFound: "No Text Found"
            }
        }
    }

    let screenshot: Screenshot

    /// Drawn at the card's size; the full image is only encoded when copied, saved or dragged
    let preview: CGImage

    /// False once the card is on its way out, which plays its exit; set by `QuickAccessController`
    var isPresented = true

    private(set) var feedback: Feedback?
    private(set) var isRecognizingText = false

    /// Closes the card. Set by `QuickAccessController`, cleared when the card goes away.
    @ObservationIgnored var onClose: (@MainActor () -> Void)?

    /// Pins the screenshot where the card is. Set by `QuickAccessController`.
    @ObservationIgnored var onPin: (@MainActor () -> Void)?

    private let saveScreenshot: @MainActor (Screenshot) async -> Bool
    private let pasteboard: NSPasteboard
    /// Holds the drag-out file under the save name; unique per card so two cards never share a file
    private let dragFolder = URL.temporaryDirectory.appending(path: UUID().uuidString)
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "QuickAccess")

    @ObservationIgnored private var dragFile: URL?
    @ObservationIgnored private var dragFileTask: Task<Void, Never>?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    /// - Parameter save: Saves into the output folder and reports failures itself; returns whether it saved
    init(screenshot: Screenshot, preview: CGImage, save: @escaping @MainActor (Screenshot) async -> Bool, pasteboard: NSPasteboard = .general) {
        self.screenshot = screenshot
        self.preview = preview
        self.saveScreenshot = save
        self.pasteboard = pasteboard
        writeDragFile()
    }

    func close() {
        onClose?()
    }

    /// Copies the full image as PNG, then closes
    func copy() async {
        do {
            let png = try await ScreenshotService.pngData(of: screenshot.image)
            ImagePasteboard.copy(png: png, to: pasteboard)
            onClose?()
        } catch {
            logger.error("Couldn't encode the screenshot to copy: \(error.localizedDescription)")
        }
    }

    /// Saves into the output folder, then closes; a failed save keeps the card open
    func save() async {
        if await saveScreenshot(screenshot) {
            onClose?()
        }
    }

    /// Copies the text in the image; the card stays open
    func recognizeText() async {
        isRecognizingText = true
        defer { isRecognizingText = false }
        do {
            let text = try await TextRecognizer.text(in: screenshot.image)
            guard !text.isEmpty else {
                show(.noTextFound)
                return
            }
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            show(.textCopied)
        } catch {
            logger.error("Text recognition failed: \(error.localizedDescription)")
        }
    }

    /// Pins the screenshot, then closes the card
    func pin() {
        onPin?()
        onClose?()
    }

    /// The drag-out item: the PNG file (Finder, Slack, Messages) plus its data (apps that only take images).
    /// Empty until the file is written, a fraction of a second after the card appears.
    func dragItem() -> NSItemProvider {
        guard let dragFile else { return NSItemProvider() }
        let provider = NSItemProvider(object: dragFile as NSURL)
        provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
            do {
                let data = try Data(contentsOf: dragFile)
                completion(data, nil)
            } catch {
                completion(nil, error)
            }
            return nil
        }
        return provider
    }

    /// Deletes the drag-out file when the card closes.
    ///
    /// ponytail: assumes drop receivers copy the file on drop (Finder and Slack do). If Messages or Mail lose
    /// an unsent attachment after the card closes, leave the file for the system to purge instead.
    func removeDragFile() {
        dragFileTask?.cancel()
        try? FileManager.default.removeItem(at: dragFolder)
    }

    /// Written up front, off the main actor: a drop reads the file URL at once, so the file must already exist
    private func writeDragFile() {
        let url = dragFolder.appending(path: screenshot.filename)
        dragFileTask = Task {
            do {
                try await ScreenshotService.writePNG(screenshot.image, to: url)
                guard !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: dragFolder)
                    return
                }
                dragFile = url
            } catch {
                logger.error("Couldn't write the drag-out file: \(error.localizedDescription)")
            }
        }
    }

    /// Shows `feedback` for 1.5 s and announces it to VoiceOver
    private func show(_ feedback: Feedback) {
        self.feedback = feedback
        AccessibilityNotification.Announcement(feedback.message).post()
        feedbackTask?.cancel()
        feedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self.feedback = nil
        }
    }
}
