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

    @Test func copyPutsThePNGOnThePasteboardAndClosesTheCard() async throws {
        let pasteboard = NSPasteboard(name: .init("QuickAccessViewModelTests-\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        let probe = CardProbe()
        let model = try probe.makeModel(pasteboard: pasteboard)
        defer { model.removeDragFile() }

        await model.copy()

        let png = try #require(pasteboard.data(forType: .png))
        let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
        #expect(CGImageSourceCreateImageAtIndex(source, 0, nil)?.width == 40)
        #expect(probe.closed == 1)
    }

    @Test func saveClosesTheCardOnceSaved() async throws {
        let probe = CardProbe()
        let model = try probe.makeModel()
        defer { model.removeDragFile() }

        await model.save()

        #expect(probe.saved == [model.screenshot.date])
        #expect(probe.closed == 1)
    }

    @Test func aFailedSaveKeepsTheCardOpen() async throws {
        let probe = CardProbe()
        let model = try probe.makeModel(saveSucceeds: false)
        defer { model.removeDragFile() }

        await model.save()

        #expect(probe.saved.count == 1)
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
}

/// Builds card models and records what they ask their owner to do
@MainActor
private final class CardProbe {
    var saved: [Date] = []
    var closed = 0
    var pinned = 0

    func makeModel(image: CGImage? = nil, saveSucceeds: Bool = true, pasteboard: NSPasteboard = .general) throws -> QuickAccessViewModel {
        let image = try image ?? .filled(width: 40, height: 20)
        let model = QuickAccessViewModel(
            screenshot: Screenshot(image: image, scale: 2, date: .now),
            preview: image,
            save: { [unowned self] screenshot in
                saved.append(screenshot.date)
                return saveSucceeds
            },
            pasteboard: pasteboard
        )
        model.onClose = { [unowned self] in closed += 1 }
        model.onPin = { [unowned self] in pinned += 1 }
        return model
    }
}
