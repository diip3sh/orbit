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
import UniformTypeIdentifiers
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

    // MARK: - HDR

    /// Extended linear sRGB at twice SDR white, as an HDR capture holds where the screen showed HDR
    private func brighterThanWhite(width: Int, height: Int) throws -> CGImage {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 16, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue
                | CGImageByteOrderInfo.order16Little.rawValue
        ))
        context.setFillColor(try #require(CGColor(colorSpace: colorSpace, components: [2, 2, 2, 1])))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    @Test func anHDRScreenshotIsNamedHEICAndCropsBothImages() throws {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 14, minute: 5, second: 9))!
        let display = try Screenshot(image: .filled(width: 600, height: 400), scale: 2, date: date, hdrImage: brighterThanWhite(width: 600, height: 400))
        #expect(display.filename == "Reco_Screenshot_2026-09-28-14.05.09.heic")

        let area = try #require(display.cropped(to: CGRect(x: 10, y: 20, width: 100, height: 50)))
        #expect(area.hdrImage?.width == 200)
        #expect(area.hdrImage?.height == 100)
    }

    @Test func anHDRScreenshotIsWrittenAsHEICWithAGainMap() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let screenshot = try Screenshot(image: .filled(width: 64, height: 48), scale: 2, date: .now, hdrImage: brighterThanWhite(width: 64, height: 48))
        let url = folder.appending(path: screenshot.filename)

        try await ScreenshotService.write(screenshot, to: url)

        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.heic.identifier)
        let gainMap = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeISOGainMap)
        #expect(gainMap != nil)
    }

    @Test func theSDRPictureClipsWhatIsBrighterThanWhite() throws {
        let sdr = try #require(ScreenshotService.standardRange(of: brighterThanWhite(width: 4, height: 2)))
        #expect(sdr.bitsPerComponent == 8)
        #expect(sdr.colorSpace?.name == CGColorSpace.sRGB)

        let bytes = try #require(sdr.dataProvider?.data as Data?)
        #expect(bytes.prefix(4) == Data([255, 255, 255, 255]))
    }

    @Test func anSDRScreenshotIsWrittenAsPNG() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let screenshot = try Screenshot(image: .filled(width: 30, height: 20), scale: 2, date: .now)
        let url = folder.appending(path: screenshot.filename)

        try await ScreenshotService.write(screenshot, to: url)

        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.png.identifier)
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
