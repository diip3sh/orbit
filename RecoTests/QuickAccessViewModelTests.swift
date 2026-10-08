//
//  QuickAccessViewModelTests.swift
//  RecoTests
//
//  Created by Diip3sh on 29.09.26.
//

import AppKit
import ImageIO
import Testing
@testable import Reco

@MainActor
struct QuickAccessViewModelTests {

    @Test func copyPutsThePNGOnThePasteboardConfirmsAndCloses() async throws {
        let pasteboard = NSPasteboard(name: .init("QuickAccessViewModelTests-\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        let probe = CardProbe()
        let model = try probe.makeModel(pasteboard: pasteboard)
        defer { model.removeDragFile() }

        await model.copy()

        let png = try #require(pasteboard.data(forType: .png))
        let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
        #expect(CGImageSourceCreateImageAtIndex(source, 0, nil)?.width == 40)
        #expect(model.feedback == .copied)
        #expect(probe.closed == 1)
    }

    @Test func saveConfirmsAndClosesOnceSaved() async throws {
        let probe = CardProbe()
        let model = try probe.makeModel()
        defer { model.removeDragFile() }

        await model.save()

        #expect(probe.saved == [model.screenshot.date])
        #expect(model.feedback == .saved)
        #expect(probe.closed == 1)
    }

    @Test func aFailedSaveKeepsTheCardOpen() async throws {
        let probe = CardProbe()
        let model = try probe.makeModel(saveSucceeds: false)
        defer { model.removeDragFile() }

        await model.save()

        #expect(probe.saved.count == 1)
        #expect(model.feedback == nil)
        #expect(probe.closed == 0)
    }

    @Test func pinPinsThenCloses() throws {
        let probe = CardProbe()
        let model = try probe.makeModel()
        defer { model.removeDragFile() }

        model.pin()

        #expect(probe.pinned == 1)
        #expect(probe.closed == 1)
    }

    @Test func closeCloses() throws {
        let probe = CardProbe()
        let model = try probe.makeModel()
        defer { model.removeDragFile() }

        model.close()

        #expect(probe.closed == 1)
    }

    @Test func recognizingNoTextSaysSoAndLeavesThePasteboard() async throws {
        let pasteboard = NSPasteboard(name: .init("QuickAccessViewModelTests-\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("previous", forType: .string)
        let probe = CardProbe()
        let model = try probe.makeModel(image: .filled(width: 400, height: 200), pasteboard: pasteboard)
        defer { model.removeDragFile() }

        await model.recognizeText()

        #expect(model.feedback == .noTextFound)
        #expect(!model.isRecognizingText)
        #expect(pasteboard.string(forType: .string) == "previous")
        #expect(probe.closed == 0)
    }

    @Test func hidingNothingSensitiveSaysSoAndKeepsTheShot() async throws {
        let probe = CardProbe()
        let model = try probe.makeModel(image: .filled(width: 400, height: 200))
        defer { model.removeDragFile() }
        let before = model.screenshot.image

        await model.hideSensitiveInfo()

        #expect(model.feedback == .nothingToHide)
        #expect(!model.isHidingSensitiveInfo)
        #expect(model.screenshot.image === before)
        #expect(probe.closed == 0)
    }

    @Test func theBackgroundGoesOnAndComesOffAgain() async throws {
        let probe = CardProbe()
        var background = ScreenshotBackground()
        background.canvas.padding = 0.1
        background.autoBalances = false
        probe.background = background
        let model = try probe.makeModel(image: .filled(width: 400, height: 200))
        defer { model.removeDragFile() }
        let plain = model.screenshot.image
        #expect(!model.hasBackground)

        await model.toggleBackground()

        #expect(model.hasBackground)
        #expect(!model.isChangingBackground)
        // The canvas an export at the original size would draw: 10% padding around the shot's own pixels
        let shot = CGSize(width: 400, height: 200)
        let canvas = CanvasLayout.size(
            for: shot, aspect: .source, padding: 0.1, shorterSide: CanvasLayout.nativeShorterSide(for: shot, style: background.layoutStyle)
        )
        #expect(canvas == CGSize(width: 454, height: 252))
        #expect(model.screenshot.image.width == Int(canvas.width))
        #expect(model.screenshot.image.height == Int(canvas.height))
        #expect(model.screenshot.pointSize == CGSize(width: canvas.width / 2, height: canvas.height / 2))
        #expect(model.preview.width == Int(canvas.width))
        #expect(probe.reshaped == 1)
        #expect(model.feedback == nil)

        await model.toggleBackground()

        #expect(!model.hasBackground)
        #expect(model.screenshot.image === plain)
        #expect(probe.reshaped == 2)
        #expect(probe.closed == 0)
    }

    @Test func aFramedShotThatHidesNothingKeepsItsBackground() async throws {
        let probe = CardProbe()
        let model = try probe.makeModel(image: .filled(width: 400, height: 200))
        defer { model.removeDragFile() }
        await model.toggleBackground()
        let framed = model.screenshot.image

        await model.hideSensitiveInfo()

        #expect(model.feedback == .nothingToHide)
        #expect(model.hasBackground)
        #expect(model.screenshot.image === framed)
    }
}

/// Builds card models and records what they ask their owner to do
@MainActor
private final class CardProbe {
    var saved: [Date] = []
    var closed = 0
    var pinned = 0
    var reshaped = 0
    var background = ScreenshotBackground()

    func makeModel(image: CGImage? = nil, saveSucceeds: Bool = true, pasteboard: NSPasteboard = .general) throws -> QuickAccessViewModel {
        let image = try image ?? .filled(width: 40, height: 20)
        let model = QuickAccessViewModel(
            screenshot: Screenshot(image: image, scale: 2, date: .now),
            preview: image,
            previewPixelSize: 520,
            save: { [unowned self] screenshot in
                saved.append(screenshot.date)
                return saveSucceeds
            },
            background: { [unowned self] in background },
            pasteboard: pasteboard
        )
        model.onClose = { [unowned self] in closed += 1 }
        model.onPin = { [unowned self] in pinned += 1 }
        model.onReshape = { [unowned self] in reshaped += 1 }
        return model
    }
}
