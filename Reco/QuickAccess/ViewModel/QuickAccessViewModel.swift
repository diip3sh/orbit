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
    enum Feedback: Equatable {
        case copied
        case saved
        case textCopied
        case codeCopied
        case noTextFound
        case copyFailed
        case textFailed
        case hidden(Int)
        case nothingToHide
        case backgroundFailed
        case annotationFailed

        var message: String {
            switch self {
            case .copied: "Copied"
            case .saved: "Saved"
            case .textCopied: "Text Copied"
            case .codeCopied: "Code Copied"
            case .noTextFound: "No Text Found"
            case .copyFailed: "Couldn't Copy"
            case .textFailed: "Couldn't Read the Text"
            case .hidden(let count): count == 1 ? "Hid 1 Item" : "Hid \(count) Items"
            case .nothingToHide: "Nothing Sensitive Found"
            case .backgroundFailed: "Couldn't Add the Background"
            case .annotationFailed: "Couldn't Draw the Marks"
            }
        }

        /// Copied and Saved show on their own button instead
        var isToast: Bool {
            self != .copied && self != .saved
        }
    }

    /// What the card shows and every action uses: replaced, with its preview, when its private text is hidden or
    /// it's put on a background
    private(set) var screenshot: Screenshot

    /// Drawn at the card's size; the full image is only encoded when copied, saved or dragged
    private(set) var preview: CGImage

    /// False once the card is on its way out, which plays its exit; set by `QuickAccessController`
    var isPresented = true

    private(set) var feedback: Feedback?
    private(set) var isRecognizingText = false
    private(set) var isHidingSensitiveInfo = false

    /// Whether the shot is on the background from Settings; off for every new card
    var hasBackground = false
    private(set) var isChangingBackground = false

    /// The marks made on this shot, once Annotate has been clicked; kept until the card closes
    var annotation: AnnotationEditor?

    /// Whether the card is grown into the annotation editor
    var isAnnotating = false

    /// The card's size on screen, which the controller sets as it fits the card to the shot or the editor
    var cardSize = CGSize.zero

    /// Closes the card. Set by `QuickAccessController`, cleared when the card goes away.
    @ObservationIgnored var onClose: (@MainActor () -> Void)?

    /// Pins the screenshot where the card is. Set by `QuickAccessController`.
    @ObservationIgnored var onPin: (@MainActor () -> Void)?

    /// The shot changed shape, as a background does. Set by `QuickAccessController`, which refits the card.
    @ObservationIgnored var onReshape: (@MainActor () -> Void)?

    /// The shot without its background, which Hide Sensitive Info works on, so the background goes over the
    /// hidden text and comes off without undoing it
    @ObservationIgnored var plainScreenshot: Screenshot

    private let previewPixelSize: CGFloat
    private let saveScreenshot: @MainActor (Screenshot) async -> Bool
    private let didCopy: @MainActor (Screenshot) async -> Void
    let background: @MainActor () -> ScreenshotBackground
    private let pasteboard: NSPasteboard
    /// Holds the drag-out file under the save name; unique per card so two cards never share a file
    private let dragFolder = URL.temporaryDirectory.appending(path: UUID().uuidString)
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "QuickAccess")

    @ObservationIgnored private var dragFile: URL?
    @ObservationIgnored private var dragFileTask: Task<Void, Never>?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    /// - Parameters:
    ///   - preview: The shot drawn at most `previewPixelSize` on its longer side; a replaced shot's is drawn the same
    ///   - save: Saves into the output folder and reports failures itself; returns whether it saved
    ///   - didCopy: Told after the shot was put on the pasteboard
    ///   - background: The background Add Background puts the shot on, read when it's clicked
    init(
        screenshot: Screenshot, preview: CGImage, previewPixelSize: CGFloat, save: @escaping @MainActor (Screenshot) async -> Bool,
        didCopy: @escaping @MainActor (Screenshot) async -> Void, background: @escaping @MainActor () -> ScreenshotBackground,
        pasteboard: NSPasteboard = .general
    ) {
        self.screenshot = screenshot
        plainScreenshot = screenshot
        self.preview = preview
        self.previewPixelSize = previewPixelSize
        self.saveScreenshot = save
        self.didCopy = didCopy
        self.background = background
        self.pasteboard = pasteboard
        writeDragFile()
    }

    func close() {
        onClose?()
    }

    /// Copies the full image as PNG, confirms on the button, then closes
    func copy() async {
        await flattenIfAnnotating()
        do {
            let png = try await ScreenshotService.pngData(of: screenshot.image)
            ImagePasteboard.copy(png: png, to: pasteboard)
            confirmThenClose(.copied)
            await didCopy(screenshot)
        } catch {
            logger.error("Couldn't encode the screenshot to copy: \(error.localizedDescription)")
            show(.copyFailed)
        }
    }

    /// Saves into the output folder, confirms on the button, then closes; a failed save keeps the card open
    func save() async {
        await flattenIfAnnotating()
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

    /// Pixelates the emails, phone numbers, card numbers and API keys in the shot; the card stays open, showing
    /// the result. Copy, Save, Pin and drag-out then use the hidden shot.
    func hideSensitiveInfo() async {
        isHidingSensitiveInfo = true
        defer { isHidingSensitiveInfo = false }
        do {
            let (hidden, count) = try await ScreenshotRedactor.hidingSensitiveText(in: plainScreenshot)
            guard count > 0 else {
                show(.nothingToHide)
                return
            }
            plainScreenshot = hidden
            annotation?.replaceScreenshot(hidden)
            await compose()
            show(.hidden(count))
        } catch {
            logger.error("Couldn't hide sensitive text: \(error.localizedDescription)")
            show(.textFailed)
        }
    }

    /// Puts the shot on the background from Settings, or takes it off again; the card refits to the new shape and
    /// Copy, Save, Pin and drag-out use what it shows.
    func toggleBackground() async {
        isChangingBackground = true
        defer { isChangingBackground = false }
        hasBackground.toggle()
        await compose()
    }

    /// Flattens the marks into the shot before it leaves the card from the editor: Copy and Save work there too
    private func flattenIfAnnotating() async {
        guard isAnnotating else { return }
        await compose()
    }

    /// Shows `shot` in place of the current one, with a new preview and drag-out file; `false` when no preview
    /// could be drawn, in which case nothing changes.
    func display(_ shot: Screenshot) async -> Bool {
        guard let preview = await ImageDownsampler.thumbnail(of: shot.image, maxPixelSize: previewPixelSize) else { return false }
        let reshaped = shot.pointSize != screenshot.pointSize
        screenshot = shot
        self.preview = preview
        removeDragFile()
        writeDragFile()
        if reshaped {
            onReshape?()
        }
        return true
    }

    /// Pins the screenshot, then closes the card
    func pin() async {
        await flattenIfAnnotating()
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
                try await ScreenshotService.write(screenshot, to: url)
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
    func show(_ feedback: Feedback) {
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
