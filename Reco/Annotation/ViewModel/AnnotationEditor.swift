//
//  AnnotationEditor.swift
//  Reco
//

import CoreGraphics
import Foundation
import Observation
import OSLog

/// The marks on one screenshot while the card is open (spec 0015): the document and its undo history, the strip's
/// tool and style, the mark being drawn, the text being typed, and the shot with its effects for the canvas to show
/// under the marks. Every point is in the shot's points from its top-left corner.
@MainActor
@Observable
final class AnnotationEditor {

    private(set) var document = AnnotationDocument()
    var tool = AnnotationTool.arrow
    var color = AnnotationStyle.colors[0] {
        didSet { restyleSelection() }
    }
    var lineWidth = AnnotationStyle.lineWidths[1] {
        didSet { restyleSelection() }
    }
    private(set) var selection: Annotation.ID?

    /// The mark being dragged out, drawn over the document until the drag ends.
    private(set) var draft: Annotation?
    /// The crop being dragged out.
    private(set) var cropDraft: CGRect?

    /// Where text is being typed, and what; nil when no field shows.
    private(set) var textOrigin: CGPoint?
    var text = ""

    /// The shot with the document's effects in it, for the canvas; the shot itself while they render.
    private(set) var base: CGImage

    private(set) var canUndo = false
    private(set) var canRedo = false

    let pointSize: CGSize
    /// The shot as the marks are drawn on it.
    private(set) var screenshot: Screenshot

    @ObservationIgnored private var past: [AnnotationDocument] = []
    @ObservationIgnored private var future: [AnnotationDocument] = []
    @ObservationIgnored private var dragStart: CGPoint?
    @ObservationIgnored private var dragged: Annotation.ID?
    /// The document before a move began, so the whole move is one undo step.
    @ObservationIgnored private var beforeMove: AnnotationDocument?
    @ObservationIgnored private var baseTask: Task<Void, Never>?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "Annotation")

    init(screenshot: Screenshot) {
        self.screenshot = screenshot
        pointSize = screenshot.pointSize
        base = screenshot.image
    }

    /// The same shot with other pixels (its sensitive text hidden); the marks stay where they are.
    func replaceScreenshot(_ screenshot: Screenshot) {
        guard screenshot.pointSize == pointSize else { return }
        self.screenshot = screenshot
        base = screenshot.image
        if document.hasEffects {
            renderBase()
        }
    }

    // MARK: - Gestures

    /// A press at `point`: with Select, picks the mark there to move; otherwise starts a mark or the crop.
    func begin(at point: CGPoint) {
        commitText()
        dragStart = point
        switch tool {
        case .select:
            dragged = document.annotation(at: point)?.id
            selection = dragged
            beforeMove = document
        case .crop:
            cropDraft = nil
        default:
            selection = nil
        }
    }

    /// The pointer moved to `point` while pressed.
    func drag(to point: CGPoint) {
        guard let start = dragStart else { return }
        switch tool {
        case .select:
            guard let dragged, let moved = document[dragged]?.moved(by: CGSize(width: point.x - start.x, height: point.y - start.y)) else { return }
            var edited = document
            edited.update(moved)
            document = edited
            dragStart = point
        case .crop:
            cropDraft = AnnotationDocument.crop(CGRect(x: start.x, y: start.y, width: point.x - start.x, height: point.y - start.y), in: pointSize)
        case .highlighter:
            if case .highlight(let points)? = draft?.shape {
                draft?.shape = .highlight(points + [point])
            } else {
                draft = mark(.highlight([start, point]))
            }
        default:
            draft = tool.shape(from: start, to: point).map(mark)
        }
    }

    /// The press ended at `point`: a drag keeps what it made, a click places text or a step.
    func end(at point: CGPoint) {
        defer {
            dragStart = nil
            dragged = nil
            beforeMove = nil
            draft = nil
            cropDraft = nil
        }
        guard let start = dragStart else { return }
        switch tool {
        case .select:
            if let beforeMove {
                record(document, from: beforeMove)
            }
        case .crop:
            guard hypot(point.x - start.x, point.y - start.y) >= AnnotationDocument.minimumSize else { return }
            edit { $0.crop = cropDraft }
        case .text:
            textOrigin = point
            text = ""
        default:
            if let shape = releasedShape(from: start, to: point) {
                edit { $0.add(mark(shape)) }
            }
        }
    }

    /// The mark a release at `point` finishes. Made again to the release point: the last drag event may not be
    /// the release's.
    private func releasedShape(from start: CGPoint, to point: CGPoint) -> Annotation.Shape? {
        guard tool == .highlighter else { return tool.shape(from: start, to: point) }
        guard case .highlight(let points)? = draft?.shape else { return nil }
        return .highlight(points + [point])
    }

    // MARK: - Text

    /// Keeps the text typed, as a mark; nothing when it's blank.
    func commitText() {
        guard let origin = textOrigin else { return }
        textOrigin = nil
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""
        guard !typed.isEmpty else { return }
        edit { $0.add(mark(.text(typed, origin: origin))) }
    }

    func cancelText() {
        textOrigin = nil
        text = ""
    }

    var isEditingText: Bool {
        textOrigin != nil
    }

    // MARK: - Editing

    func delete() {
        guard let selection else { return }
        edit { $0.remove(selection) }
        self.selection = nil
    }

    func undo() {
        guard let previous = past.popLast() else { return }
        future.append(document)
        apply(previous, previous: document)
    }

    func redo() {
        guard let next = future.popLast() else { return }
        past.append(document)
        apply(next, previous: document)
    }

    /// One undo step changing the document by `change`.
    private func edit(_ change: (inout AnnotationDocument) -> Void) {
        var edited = document
        change(&edited)
        record(edited, from: document)
    }

    private func record(_ edited: AnnotationDocument, from previous: AnnotationDocument) {
        guard edited != previous else { return }
        past.append(previous)
        future.removeAll()
        apply(edited, previous: previous)
    }

    /// Shows `document`; the effects render again when they differ from `previous`'s (a move changes the document
    /// as it goes, so the comparison is against the step's start, not the last frame).
    private func apply(_ document: AnnotationDocument, previous: AnnotationDocument) {
        let effectsChanged = document.effects.map(\.rects) != previous.effects.map(\.rects)
            || document.effects.map(\.kind) != previous.effects.map(\.kind)
        self.document = document
        canUndo = !past.isEmpty
        canRedo = !future.isEmpty
        if effectsChanged {
            renderBase()
        }
    }

    /// A new mark in the strip's colour and width.
    private func mark(_ shape: Annotation.Shape) -> Annotation {
        Annotation(shape: shape, color: color, lineWidth: lineWidth)
    }

    /// A colour or width picked while a mark is selected changes that mark.
    private func restyleSelection() {
        guard let selection, var selected = document[selection] else { return }
        selected.color = color
        selected.lineWidth = lineWidth
        edit { $0.update(selected) }
    }

    /// The shot with its effects, off the main actor; the last render wins.
    private func renderBase() {
        baseTask?.cancel()
        let document = document
        let screenshot = screenshot
        baseTask = Task {
            do {
                let rendered = try await Self.effects(of: document, on: screenshot)
                guard !Task.isCancelled else { return }
                base = rendered
            } catch {
                logger.error("Couldn't render the effects: \(error.localizedDescription)")
            }
        }
    }

    @concurrent
    private static func effects(of document: AnnotationDocument, on screenshot: Screenshot) async throws -> CGImage {
        try AnnotationFlattener.effects(of: document, on: screenshot.image, scale: screenshot.scale)
    }
}
