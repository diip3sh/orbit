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

    /// A short confirmation shown on the card: on the Copy or Save button, or as a toast for text
    enum Feedback {
        case copied
        case saved
        case textCopied
        case codeCopied
        case noTextFound
        case copyFailed
        case textFailed

        var message: String {
            switch self {
            case .copied: "Copied"
            case .saved: "Saved"
            case .textCopied: "Text Copied"
            case .codeCopied: "Code Copied"
            case .noTextFound: "No Text Found"
            case .copyFailed: "Couldn't Copy"
            case .textFailed: "Couldn't Read the Text"
            }
        }

        /// Copied and Saved show on their own button instead
        var isToast: Bool {
            self != .copied && self != .saved
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

    /// Copies the full image as PNG, confirms on the button, then closes
    func copy() async {
        do {
            let png = try await ScreenshotService.pngData(of: screenshot.image)
            ImagePasteboard.copy(png: png, to: pasteboard)
            confirmThenClose(.copied)
        } catch {
            logger.error("Couldn't encode the screenshot to copy: \(error.localizedDescription)")
            show(.copyFailed)
        }
    }

    /// Saves into the output folder, confirms on the button, then closes; a failed save keeps the card open
    func save() async {
        if await saveScreenshot(screenshot) {
            confirmThenClose(.saved)
        }
    }

    /// Copies what a QR code or barcode in the image holds, or else its text; the card stays open
    func recognizeText() async {
        isRecognizingText = true
        defer { isRecognizingText = false }
        do {
            async let codes = TextRecognizer.codes(in: screenshot.image)
            async let text = TextRecognizer.text(in: screenshot.image)
            // A shot with a code in it is taken for the code's sake: its link, not the words around it. Finding
            // codes failing still leaves the text.
            let found = (try? await codes) ?? ""
            let copied = found.isEmpty ? try await text : found
            guard !copied.isEmpty else {
                show(.noTextFound)
                return
            }
            pasteboard.clearContents()
            pasteboard.setString(copied, forType: .string)
            show(found.isEmpty ? .textCopied : .codeCopied)
        } catch {
            logger.error("Text recognition failed: \(error.localizedDescription)")
            show(.textFailed)
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

    /// Shows Copied or Saved and closes in the same moment: the button confirms while the card fades out,
    /// so nothing waits on a pause
    private func confirmThenClose(_ feedback: Feedback) {
        show(feedback)
        onClose?()
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
