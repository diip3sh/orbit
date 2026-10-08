//
//  QuickAccessViewModel+Annotation.swift
//  Reco
//

import Foundation
import OSLog

// MARK: - Annotating (spec 0015)

extension QuickAccessViewModel {

    /// Grows the card into the annotation editor, with the marks made so far.
    func annotate() {
        if annotation == nil {
            annotation = AnnotationEditor(screenshot: plainScreenshot)
        }
        isAnnotating = true
        onReshape?()
    }

    /// Back to the card, showing the shot with its marks; they stay editable until the card closes.
    func finishAnnotating() async {
        annotation?.commitText()
        isAnnotating = false
        await compose()
        onReshape?()
    }

    /// Shows what the plain shot, the marks and the background make together; reports `annotationFailed` when the
    /// marks couldn't be drawn and shows the shot without them.
    func compose() async {
        var shown = plainScreenshot
        do {
            if let document = annotation?.document, !document.isEmpty {
                shown = try await AnnotationFlattener.flatten(document, on: shown)
            }
        } catch {
            logger.error("Couldn't draw the annotations: \(error.localizedDescription)")
            show(.annotationFailed)
        }
        if hasBackground {
            do {
                shown = try await ScreenshotFramer.framing(shown, with: background())
            } catch {
                logger.error("Couldn't put the screenshot on a background: \(error.localizedDescription)")
                hasBackground = false
                show(.backgroundFailed)
            }
        }
        if await !display(shown) {
            show(.annotationFailed)
        }
    }
}
