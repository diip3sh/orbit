//
//  ScreenshotTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import Foundation
import ImageIO
@preconcurrency import ScreenCaptureKit
import Testing
@testable import Reco

@MainActor
struct ScreenshotTests {

    private let defaults = TemporaryDefaults()

    /// Creates a SettingsStore backed by a fresh, empty UserDefaults suite.
    private func makeSettings() -> SettingsStore {
        SettingsStore(defaults: defaults.make())
    }

    // MARK: - Screenshot

    @Test func filenameUsesTheSharedFormatWithAScreenshotPrefixAndTheCaptureTime() throws {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 14, minute: 5, second: 9))!
        let screenshot = try Screenshot(image: .filled(width: 4, height: 4), scale: 2, date: date)

        #expect(screenshot.filename == "Reco_Screenshot_2026-09-28-14.05.09.png")
    }

    @Test func pointSizeIsThePixelSizeOverTheScale() throws {
        let screenshot = try Screenshot(image: .filled(width: 600, height: 400), scale: 2, date: .now)

        #expect(screenshot.pointSize == CGSize(width: 300, height: 200))
    }

    @Test func croppingCutsTheSourceRectInPixelsAndKeepsScaleAndDate() throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let display = try Screenshot(image: .filled(width: 600, height: 400), scale: 2, date: date)

        let area = try #require(display.cropped(to: CGRect(x: 10, y: 20, width: 100, height: 50)))

        #expect(area.image.width == 200)
        #expect(area.image.height == 100)
        #expect(area.scale == 2)
        #expect(area.date == date)
    }

    @Test func croppingOutsideTheShotGivesNothing() throws {
        let display = try Screenshot(image: .filled(width: 600, height: 400), scale: 2, date: .now)

        let isOutside = display.cropped(to: CGRect(x: 400, y: 0, width: 50, height: 50)) == nil
        #expect(isOutside)
    }

    // MARK: - PNG

    @Test func pngDataDecodesToTheSamePixelSize() async throws {
        let data = try await ScreenshotService.pngData(of: .filled(width: 30, height: 20))

        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 30)
        #expect(decoded.height == 20)
    }

    // MARK: - canCapture

    @Test func canCaptureWhileIdleAndNothingElseIsHappening() {
        #expect(ScreenshotController.canCapture(recorderState: .idle, isCountingDown: false, isCapturing: false))
    }

    @Test func cannotCaptureWhileRecording() {
        #expect(!ScreenshotController.canCapture(recorderState: .recording, isCountingDown: false, isCapturing: false))
    }

    @Test func cannotCaptureWhileStopping() {
        #expect(!ScreenshotController.canCapture(recorderState: .stopping, isCountingDown: false, isCapturing: false))
    }

    @Test func cannotCaptureDuringACountdown() {
        #expect(!ScreenshotController.canCapture(recorderState: .idle, isCountingDown: true, isCapturing: false))
    }

    @Test func cannotCaptureAnotherScreenshotWhileOneIsInFlight() {
        #expect(!ScreenshotController.canCapture(recorderState: .idle, isCountingDown: false, isCapturing: true))
    }

    // MARK: - Area selection size

    @Test func areaSelectionAtTheMinimumSizeIsValid() {
        #expect(AreaSelectionView.isValidSelection(CGRect(x: 10, y: 10, width: 24, height: 24)))
    }

    @Test func plainClickOrNarrowDragIsNotASelection() {
        #expect(!AreaSelectionView.isValidSelection(.zero))
        #expect(!AreaSelectionView.isValidSelection(CGRect(x: 0, y: 0, width: 23, height: 400)))
        #expect(!AreaSelectionView.isValidSelection(CGRect(x: 0, y: 0, width: 400, height: 23)))
    }

    @Test func releasingABigEnoughDragConfirmsAScreenshotAndAdjustsARecording() {
        let drag = CGRect(x: 10, y: 10, width: 200, height: 100)
        #expect(AreaSelectionView.drawingRelease(of: drag, confirmsOnRelease: true) == .confirm)
        #expect(AreaSelectionView.drawingRelease(of: drag, confirmsOnRelease: false) == .adjust)
    }

    @Test func plainClickCancelsAScreenshotAndKeepsARecordingSelectionOpen() {
        #expect(AreaSelectionView.drawingRelease(of: .zero, confirmsOnRelease: true) == .cancel)
        #expect(AreaSelectionView.drawingRelease(of: .zero, confirmsOnRelease: false) == .reset)
    }

    // MARK: - configuration

    @Test func configurationUsesThePixelSizeAndSourceRect() {
        let settings = makeSettings()
        let sourceRect = CGRect(x: 10, y: 20, width: 300, height: 200)

        let config = ScreenshotService.configuration(
            pixelSize: CGSize(width: 600, height: 400),
            sourceRect: sourceRect,
            isWindowCapture: false,
            settings: settings
        )

        #expect(config.width == 600)
        #expect(config.height == 400)
        #expect(config.sourceRect == sourceRect)
    }

    @Test func configurationScalesToFitOnlyForWindowCaptures() {
        let settings = makeSettings()

        let window = ScreenshotService.configuration(pixelSize: .zero, sourceRect: nil, isWindowCapture: true, settings: settings)
        #expect(window.scalesToFit == true)

        let display = ScreenshotService.configuration(pixelSize: .zero, sourceRect: nil, isWindowCapture: false, settings: settings)
        #expect(display.scalesToFit == false)
    }

    @Test func configurationUsesShowCursorNotCapturesCursor() {
        let settings = makeSettings()
        settings.recordInputTelemetry = true
        #expect(settings.showCursor)
        #expect(!settings.capturesCursor)

        let shown = ScreenshotService.configuration(pixelSize: .zero, sourceRect: nil, isWindowCapture: false, settings: settings)
        #expect(shown.showsCursor == true)

        settings.showCursor = false
        let hidden = ScreenshotService.configuration(pixelSize: .zero, sourceRect: nil, isWindowCapture: false, settings: settings)
        #expect(hidden.showsCursor == false)
    }

    @Test func configurationIgnoresShadowsWhenShowWindowShadowsIsOff() {
        let settings = makeSettings()
        settings.showWindowShadows = false

        let config = ScreenshotService.configuration(pixelSize: .zero, sourceRect: nil, isWindowCapture: false, settings: settings)

        #expect(config.ignoreShadowsDisplay == true)
        #expect(config.ignoreShadowsSingleWindow == true)
    }
}
