//
//  AnnotationTests.swift
//  RecoTests
//
//  Created by Diip3sh on 08.10.26.
//

import CoreGraphics
import CoreImage
import Testing
@testable import Reco

struct AnnotationTests {

    private let red = AnnotationStyle.colors[0]

    private func mark(_ shape: Annotation.Shape, width: Double = 4) -> Annotation {
        Annotation(shape: shape, color: red, lineWidth: width)
    }

    @Test func stepsAreNumberedInOrderAndRenumberedWhenOneGoes() {
        var document = AnnotationDocument()
        let first = mark(.step(center: CGPoint(x: 10, y: 10)))
        let arrow = mark(.arrow(start: .zero, end: CGPoint(x: 50, y: 50)))
        let second = mark(.step(center: CGPoint(x: 20, y: 20)))
        let third = mark(.step(center: CGPoint(x: 30, y: 30)))
        for annotation in [first, arrow, second, third] {
            document.add(annotation)
        }
        #expect(document.stepNumber(of: first) == 1)
        #expect(document.stepNumber(of: second) == 2)
        #expect(document.stepNumber(of: third) == 3)
        #expect(document.stepNumber(of: arrow) == nil)

        document.remove(second.id)

        #expect(document.stepNumber(of: third) == 2)
    }

    @Test func hitTestingPicksTheTopmostMarkAndNeedsTheStrokeForLines() {
        var document = AnnotationDocument()
        let box = mark(.rectangle(CGRect(x: 0, y: 0, width: 100, height: 100)))
        let line = mark(.line(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 100, y: 100)))
        document.add(box)
        document.add(line)

        // On the line, which is on top
        #expect(document.annotation(at: CGPoint(x: 50, y: 50))?.id == line.id)
        // Inside the box's bounds but far from the line
        #expect(document.annotation(at: CGPoint(x: 90, y: 10))?.id == box.id)
        #expect(document.annotation(at: CGPoint(x: 200, y: 200)) == nil)
    }

    @Test func movingKeepsTheShapeAndShiftsEveryPoint() {
        let highlight = mark(.highlight([CGPoint(x: 1, y: 1), CGPoint(x: 5, y: 5)]))
        let moved = highlight.moved(by: CGSize(width: 10, height: -1))
        #expect(moved.shape == .highlight([CGPoint(x: 11, y: 0), CGPoint(x: 15, y: 4)]))
        #expect(moved.id == highlight.id)

        let ellipse = mark(.ellipse(CGRect(x: 0, y: 0, width: 20, height: 10))).moved(by: CGSize(width: 3, height: 4))
        #expect(ellipse.shape == .ellipse(CGRect(x: 3, y: 4, width: 20, height: 10)))
    }

    @Test func toolsMakeTheirShapesFromADragAndNothingFromATap() {
        let start = CGPoint(x: 10, y: 20)
        let end = CGPoint(x: 60, y: 40)
        #expect(AnnotationTool.rectangle.shape(from: end, to: start) == .rectangle(CGRect(x: 10, y: 20, width: 50, height: 20)))
        #expect(AnnotationTool.arrow.shape(from: start, to: end) == .arrow(start: start, end: end))
        #expect(AnnotationTool.blur.shape(from: start, to: end) == .blur(CGRect(x: 10, y: 20, width: 50, height: 20)))
        #expect(AnnotationTool.arrow.shape(from: start, to: CGPoint(x: 12, y: 21)) == nil)
        #expect(AnnotationTool.step.shape(from: start, to: start) == .step(center: start))
        #expect(AnnotationTool.select.shape(from: start, to: end) == nil)
        #expect(AnnotationTool.crop.shape(from: start, to: end) == nil)
    }

    @Test func aCropStaysInsideTheShotAndTheWholeShotIsNoCrop() {
        let size = CGSize(width: 100, height: 80)
        #expect(AnnotationDocument.crop(CGRect(x: -10, y: 10, width: 50, height: 100), in: size) == CGRect(x: 0, y: 10, width: 40, height: 70))
        #expect(AnnotationDocument.crop(CGRect(x: 0, y: 0, width: 100, height: 80), in: size) == nil)
        #expect(AnnotationDocument.crop(CGRect(x: 200, y: 0, width: 10, height: 10), in: size) == nil)
        let tiny = AnnotationDocument.crop(CGRect(x: 95, y: 75, width: 1, height: 1), in: size)
        #expect(tiny == CGRect(x: 92, y: 72, width: 8, height: 8))
    }

    @Test func effectsAreGroupedByKind() {
        var document = AnnotationDocument()
        document.add(mark(.blur(CGRect(x: 0, y: 0, width: 10, height: 10))))
        document.add(mark(.spotlight(CGRect(x: 20, y: 20, width: 10, height: 10))))
        document.add(mark(.blur(CGRect(x: 40, y: 40, width: 10, height: 10))))
        document.add(mark(.text("hi", origin: .zero)))

        let effects = document.effects

        #expect(effects.map(\.kind) == [.blur, .spotlight])
        #expect(effects[0].rects.count == 2)
        #expect(document.hasEffects)
    }
}

struct AnnotationRendererTests {

    /// A 2× shot of 40×30 points: 80×60 pixels, black
    private func blackShot() throws -> Screenshot {
        let image = try CGImage.drawn(width: 80, height: 60) {
            $0.setFillColor(CGColor(gray: 0, alpha: 1))
            $0.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
        }
        return Screenshot(image: image, scale: 2, date: .now)
    }

    @Test func aRectanglesStrokeLandsOnItsPixelsAndNowhereElse() async throws {
        let shot = try blackShot()
        var document = AnnotationDocument()
        let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
        document.add(Annotation(shape: .rectangle(CGRect(x: 10, y: 10, width: 20, height: 10)), color: white, lineWidth: 2))

        let drawn = try await AnnotationFlattener.flatten(document, on: shot)
        let image = CIImage(cgImage: drawn.image)

        #expect(drawn.image.width == 80 && drawn.image.height == 60)
        // The left edge at x 10 pt (20 px, 2 pt wide = 4 px); Core Image's y is from the bottom: y 15 pt is pixel row 60 - 30
        #expect(image.pixel(at: CGPoint(x: 20, y: 30))[0] > 200)
        // Inside the rectangle stays black, as does the outside
        #expect(image.pixel(at: CGPoint(x: 40, y: 30))[0] < 10)
        #expect(image.pixel(at: CGPoint(x: 5, y: 5))[0] < 10)
    }

    @Test func textAndStepsDrawSomething() async throws {
        let shot = try blackShot()
        var document = AnnotationDocument()
        let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
        document.add(Annotation(shape: .text("Hi", origin: CGPoint(x: 2, y: 2)), color: white, lineWidth: 2))
        document.add(Annotation(shape: .step(center: CGPoint(x: 30, y: 20)), color: white, lineWidth: 4))

        let drawn = try await AnnotationFlattener.flatten(document, on: shot)
        let image = CIImage(cgImage: drawn.image)

        // The step's disc is white at its centre's pixel ring (the number is black over it): a pixel just off centre
        #expect(image.pixel(at: CGPoint(x: 60 + 10, y: 60 - 40))[0] > 200)
        // Somewhere in the text's box a pixel is lit
        var lit = false
        for column in stride(from: 4, to: 40, by: 2) where !lit {
            for row in stride(from: 40, to: 58, by: 2) where image.pixel(at: CGPoint(x: column, y: row))[0] > 100 {
                lit = true
            }
        }
        #expect(lit)
    }

    /// The noise is meant to move a cell's brightness by at most 6%: a random red over a small random alpha came out
    /// far over 1 once unpremultiplied, so a flat grey of 95 pixelated to 89–255 (2026-10-08)
    @Test func pixelateMovesEachCellOnlyALittle() async throws {
        let image = try CGImage.drawn(width: 400, height: 300) {
            $0.setFillColor(CGColor(gray: 0.3, alpha: 1))
            $0.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        var document = AnnotationDocument()
        document.add(Annotation(shape: .pixelate(CGRect(x: 0, y: 0, width: 200, height: 150)), color: AnnotationStyle.colors[0], lineWidth: 4))

        let pixelated = CIImage(cgImage: try await AnnotationFlattener.flatten(document, on: Screenshot(image: image, scale: 2, date: .now)).image)

        let base = CIImage(cgImage: image).pixel(at: CGPoint(x: 5, y: 5))[0]
        var values: [UInt8] = []
        for column in stride(from: 3, to: 400, by: 13) {
            for row in stride(from: 3, to: 300, by: 11) {
                values.append(pixelated.pixel(at: CGPoint(x: column, y: row))[0])
            }
        }
        let (low, high) = (try #require(values.min()), try #require(values.max()))
        #expect(low >= base - 8 && low < base)
        #expect(high <= base + 8 && high > base)
    }

    @Test func anEmptyDocumentReturnsTheShotItself() async throws {
        let shot = try blackShot()
        let same = try await AnnotationFlattener.flatten(AnnotationDocument(), on: shot)
        #expect(same.image === shot.image)
    }

    @Test func aBlurChangesOnlyItsRectangleAndACropGivesTheCroppedSize() async throws {
        // Left half white, right half black
        let image = try CGImage.drawn(width: 80, height: 60) {
            $0.setFillColor(CGColor(gray: 1, alpha: 1))
            $0.fill(CGRect(x: 0, y: 0, width: 40, height: 60))
            $0.setFillColor(CGColor(gray: 0, alpha: 1))
            $0.fill(CGRect(x: 40, y: 0, width: 40, height: 60))
        }
        let shot = Screenshot(image: image, scale: 2, date: .now)
        var document = AnnotationDocument()
        document.add(Annotation(shape: .blur(CGRect(x: 15, y: 5, width: 10, height: 20)), color: AnnotationStyle.colors[0], lineWidth: 4))

        let blurred = CIImage(cgImage: try await AnnotationFlattener.flatten(document, on: shot).image)

        // Across the edge inside the blur, grey; outside it, the edge stays sharp
        let inside = blurred.pixel(at: CGPoint(x: 39, y: 30))[0]
        #expect(inside > 30 && inside < 225)
        #expect(blurred.pixel(at: CGPoint(x: 39, y: 5))[0] > 240)
        #expect(blurred.pixel(at: CGPoint(x: 41, y: 5))[0] < 15)

        document.crop = CGRect(x: 10, y: 5, width: 20, height: 15)
        let cropped = try await AnnotationFlattener.flatten(document, on: shot)
        #expect(cropped.image.width == 40 && cropped.image.height == 30)
        #expect(cropped.pointSize == CGSize(width: 20, height: 15))
    }
}

@MainActor
struct AnnotationEditorTests {

    private func editor() throws -> AnnotationEditor {
        AnnotationEditor(screenshot: Screenshot(image: try .filled(width: 200, height: 100), scale: 2, date: .now))
    }

    @Test func aDragMakesAMarkAndUndoTakesItBack() throws {
        let editor = try editor()
        editor.tool = .rectangle
        editor.begin(at: CGPoint(x: 10, y: 10))
        editor.drag(to: CGPoint(x: 30, y: 20))
        #expect(editor.draft?.shape == .rectangle(CGRect(x: 10, y: 10, width: 20, height: 10)))
        editor.end(at: CGPoint(x: 40, y: 30))

        #expect(editor.draft == nil)
        #expect(editor.document.annotations.map(\.shape) == [.rectangle(CGRect(x: 10, y: 10, width: 30, height: 20))])
        #expect(editor.canUndo && !editor.canRedo)

        editor.undo()
        #expect(editor.document.isEmpty)
        #expect(editor.canRedo)
        editor.redo()
        #expect(editor.document.annotations.count == 1)
    }

    @Test func aMoveIsOneUndoStepAndDeleteRemovesTheSelection() throws {
        let editor = try editor()
        editor.tool = .ellipse
        editor.begin(at: CGPoint(x: 10, y: 10))
        editor.drag(to: CGPoint(x: 50, y: 50))
        editor.end(at: CGPoint(x: 50, y: 50))

        editor.tool = .select
        editor.begin(at: CGPoint(x: 30, y: 30))
        editor.drag(to: CGPoint(x: 35, y: 30))
        editor.drag(to: CGPoint(x: 40, y: 30))
        editor.end(at: CGPoint(x: 40, y: 30))

        #expect(editor.document.annotations.first?.shape == .ellipse(CGRect(x: 20, y: 10, width: 40, height: 40)))
        #expect(editor.selection != nil)
        editor.undo()
        #expect(editor.document.annotations.first?.shape == .ellipse(CGRect(x: 10, y: 10, width: 40, height: 40)))
        editor.redo()

        editor.delete()
        #expect(editor.document.isEmpty)
        #expect(editor.selection == nil)
    }

    @Test func textIsPlacedByAClickAndKeptOnCommitUnlessBlank() throws {
        let editor = try editor()
        editor.tool = .text
        editor.begin(at: CGPoint(x: 5, y: 5))
        editor.end(at: CGPoint(x: 5, y: 5))
        #expect(editor.isEditingText)
        editor.text = "  "
        editor.commitText()
        #expect(editor.document.isEmpty && !editor.isEditingText)

        editor.begin(at: CGPoint(x: 5, y: 5))
        editor.end(at: CGPoint(x: 5, y: 5))
        editor.text = "Hello"
        editor.commitText()
        #expect(editor.document.annotations.first?.shape == .text("Hello", origin: CGPoint(x: 5, y: 5)))
    }

    @Test func pickingAColorRestylesTheSelectedMark() throws {
        let editor = try editor()
        editor.tool = .step
        editor.begin(at: CGPoint(x: 20, y: 20))
        editor.end(at: CGPoint(x: 20, y: 20))
        editor.tool = .select
        editor.begin(at: CGPoint(x: 20, y: 20))
        editor.end(at: CGPoint(x: 20, y: 20))
        #expect(editor.selection != nil)

        editor.color = AnnotationStyle.colors[4]
        editor.lineWidth = 8

        #expect(editor.document.annotations.first?.color == AnnotationStyle.colors[4])
        #expect(editor.document.annotations.first?.lineWidth == 8)
    }

    @Test func aCropDragSetsTheCropAndCropsNothingSmallerThanAClick() throws {
        let editor = try editor()
        editor.tool = .crop
        editor.begin(at: CGPoint(x: 10, y: 10))
        editor.drag(to: CGPoint(x: 60, y: 40))
        #expect(editor.cropDraft == CGRect(x: 10, y: 10, width: 50, height: 30))
        editor.end(at: CGPoint(x: 60, y: 40))
        #expect(editor.document.crop == CGRect(x: 10, y: 10, width: 50, height: 30))

        editor.begin(at: CGPoint(x: 10, y: 10))
        editor.end(at: CGPoint(x: 12, y: 12))
        #expect(editor.document.crop == CGRect(x: 10, y: 10, width: 50, height: 30))
    }
}
