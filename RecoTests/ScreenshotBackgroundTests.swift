//
//  ScreenshotBackgroundTests.swift
//  RecoTests
//

import CoreGraphics
import CoreImage
import Foundation
import SwiftUI
import Testing
@testable import Reco

struct UniformBordersTests {

    /// `width` × `height` RGBA pixels of `border`, with `content` filled in `rect` (top-left origin).
    private func pixels(width: Int, height: Int, border: [UInt8], content: [UInt8], in rect: CGRect) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                let inside = rect.contains(CGPoint(x: CGFloat(column) + 0.5, y: CGFloat(row) + 0.5))
                pixels.replaceSubrange((row * width + column) * 4..<(row * width + column + 1) * 4, with: inside ? content : border)
            }
        }
        return pixels
    }

    @Test func theContentIsWhatIsntTheCornersColour() {
        let content = CGRect(x: 3, y: 2, width: 5, height: 4)
        let pixels = pixels(width: 12, height: 10, border: [20, 20, 20, 255], content: [200, 50, 50, 255], in: content)

        let rect = pixels.withUnsafeBufferPointer { UniformBorders.contentRect(width: 12, height: 10, bytesPerRow: 48, pixels: $0) }

        #expect(rect == content)
    }

    @Test func aDitheredBorderWithinTheToleranceIsStillBorder() {
        var pixels = pixels(width: 12, height: 10, border: [20, 20, 20, 255], content: [200, 50, 50, 255], in: CGRect(x: 3, y: 2, width: 5, height: 4))
        // The pixel at (1, 1) a shade off; at (10, 8) over the tolerance
        pixels[(1 * 12 + 1) * 4] = 20 + UInt8(UniformBorders.tolerance)
        pixels[(8 * 12 + 10) * 4 + 1] = 20 + UInt8(UniformBorders.tolerance) + 1

        let rect = pixels.withUnsafeBufferPointer { UniformBorders.contentRect(width: 12, height: 10, bytesPerRow: 48, pixels: $0) }

        #expect(rect == CGRect(x: 3, y: 2, width: 8, height: 7))
    }

    @Test func oneColourAllOverIsLeftWhole() {
        let pixels = pixels(width: 6, height: 4, border: [9, 9, 9, 255], content: [9, 9, 9, 255], in: .zero)

        let rect = pixels.withUnsafeBufferPointer { UniformBorders.contentRect(width: 6, height: 4, bytesPerRow: 24, pixels: $0) }

        #expect(rect == CGRect(x: 0, y: 0, width: 6, height: 4))
    }

    @Test func trimmingCutsTheImageToItsContent() throws {
        let image = try CGImage.drawn(width: 60, height: 40) {
            $0.setFillColor(CGColor(gray: 0.9, alpha: 1))
            $0.fill(CGRect(x: 0, y: 0, width: 60, height: 40))
            $0.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            $0.fill(CGRect(x: 15, y: 10, width: 30, height: 20))
        }

        let trimmed = UniformBorders.trimmed(image)

        #expect(trimmed.width == 30)
        #expect(trimmed.height == 20)
        #expect(CIImage(cgImage: trimmed).pixel(at: .zero) == CIImage(cgImage: image).pixel(at: CGPoint(x: 20, y: 20)))
        let plain = try CGImage.filled(width: 8, height: 8)
        #expect(UniformBorders.trimmed(plain) === plain)
    }
}

struct ScreenshotFramerTests {

    private func shot(width: Int = 400, height: Int = 200) throws -> Screenshot {
        Screenshot(image: try .filled(width: width, height: height), scale: 2, date: .now, region: CGRect(x: 1, y: 2, width: 3, height: 4))
    }

    @Test func theShotKeepsItsPixelsInsideThePadding() async throws {
        var background = ScreenshotBackground()
        background.canvas.background = .color
        background.canvas.color = RGBAColor(red: 0, green: 0, blue: 1, alpha: 1)
        background.canvas.padding = 0.1
        background.canvas.cornerRadius = 0
        background.canvas.shadow = 0
        background.autoBalances = false

        let shot = try shot()
        let framed = try await ScreenshotFramer.framing(shot, with: background)

        let image = CIImage(cgImage: framed.image)
        let red = CIImage(cgImage: shot.image).pixel(at: .zero)
        #expect(framed.image.width == 454 && framed.image.height == 252)
        // The shot's own pixels at the centre and at the frame's edges, on whole pixels; the colour in the padding
        #expect(image.pixel(at: CGPoint(x: 227, y: 126)) == red)
        #expect(image.pixel(at: CGPoint(x: 27, y: 26)) == red)
        #expect(image.pixel(at: CGPoint(x: 426, y: 225)) == red)
        #expect(image.pixel(at: CGPoint(x: 26, y: 26)) == [0, 0, 255, 255])
        #expect(image.pixel(at: CGPoint(x: 2, y: 2)) == [0, 0, 255, 255])
        #expect(framed.scale == 2)
        #expect(framed.hdrImage == nil)
        #expect(framed.region == CGRect(x: 1, y: 2, width: 3, height: 4))
    }

    @Test func aClearBackgroundKeepsItsAlphaAndRoundsTheCorners() async throws {
        var background = ScreenshotBackground()
        background.canvas.background = .transparent
        background.canvas.padding = 0.1
        background.canvas.cornerRadius = 0.05
        background.canvas.shadow = 0
        background.autoBalances = false

        let shot = try shot()
        let framed = try await ScreenshotFramer.framing(shot, with: background)

        let image = CIImage(cgImage: framed.image)
        #expect(image.pixel(at: CGPoint(x: 2, y: 2))[3] == 0)
        // The shot's corner pixel is rounded off into the clear padding (12.6 px radius); its middle stays
        #expect(image.pixel(at: CGPoint(x: 27, y: 26))[3] < 16)
        #expect(image.pixel(at: CGPoint(x: 227, y: 126)) == CIImage(cgImage: shot.image).pixel(at: .zero))
    }

    @Test func autoBalanceTrimsTheBordersBeforePadding() async throws {
        let image = try CGImage.drawn(width: 600, height: 400) {
            $0.setFillColor(CGColor(gray: 0.2, alpha: 1))
            $0.fill(CGRect(x: 0, y: 0, width: 600, height: 400))
            $0.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            $0.fill(CGRect(x: 50, y: 100, width: 400, height: 200))
        }
        var background = ScreenshotBackground()
        background.canvas.padding = 0.1

        let framed = try await ScreenshotFramer.framing(Screenshot(image: image, scale: 2, date: .now), with: background)

        // The same canvas a 400 × 200 shot gets
        #expect(framed.image.width == 454 && framed.image.height == 252)
        background.autoBalances = false
        let whole = try await ScreenshotFramer.framing(Screenshot(image: image, scale: 2, date: .now), with: background)
        #expect(whole.image.width > 600)
    }
}

@MainActor
struct ScreenshotBackgroundSettingTests {

    @Test func theSettingIsTheDefaultUntilChangedAndThenKept() throws {
        let defaults = TemporaryDefaults()
        let suite = defaults.make()
        let settings = SettingsStore(defaults: suite)
        #expect(settings.screenshotBackground == ScreenshotBackground())

        settings.screenshotBackground.canvas.padding = 0.2
        settings.screenshotBackground.autoBalances = false

        let kept = SettingsStore(defaults: suite).screenshotBackground
        #expect(kept.canvas.padding == 0.2)
        #expect(!kept.autoBalances)
        #expect(kept.layoutStyle.aspect == .source)
    }

    @Test func aSettingSavedBeforeAutoBalanceDecodesWithItsDefault() throws {
        let data = Data(#"{"canvas":{"padding":0.3}}"#.utf8)

        let background = try JSONDecoder().decode(ScreenshotBackground.self, from: data)

        #expect(background.canvas.padding == 0.3)
        #expect(background.canvas.shadow == CanvasStyle().shadow)
        #expect(background.autoBalances)
    }

    @Test func theLayoutStyleIsAlwaysTheShotsOwnShapeFitted() {
        var background = ScreenshotBackground()
        background.canvas.aspect = .portrait
        background.canvas.fillsFrame = true

        #expect(background.layoutStyle.aspect == .source)
        #expect(!background.layoutStyle.fillsFrame)
        #expect(background.layoutStyle.padding == background.canvas.padding)
    }

    @Test func aRefittedCardKeepsTheCornerItGrewFrom() {
        let frame = CGRect(x: 100, y: 100, width: 260, height: 160)
        let size = CGSize(width: 200, height: 200)

        // Bottom-left stays; top-right stays
        #expect(QuickAccessController.refitted(frame, to: size, anchor: .bottomLeading) == CGRect(x: 100, y: 100, width: 200, height: 200))
        #expect(QuickAccessController.refitted(frame, to: size, anchor: .topTrailing) == CGRect(x: 160, y: 60, width: 200, height: 200))
    }
}
