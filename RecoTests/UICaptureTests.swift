//
//  UICaptureTests.swift
//  RecoTests
//

import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Testing
@testable import Reco

/// Lifts from a real page in WebKit, served locally.
@MainActor
struct UICaptureTests {

    private static let page = """
    <!doctype html>
    <html><body style="margin: 0; background: #fff">
      <div style="height: 1200px"></div>
      <div id="card" style="width: 400px; height: 200px; margin-left: 100px; border-radius: 24px; background: rgb(34, 34, 34)"></div>
      <div style="background: rgb(0, 0, 255); padding: 20px"><div id="clear" style="width: 300px; height: 100px"></div></div>
      <div id="tall" style="width: 200px; height: 1500px; background: rgb(255, 0, 0)"></div>
    </body></html>
    """

    /// A bundle lifted from the page; `pages` serves it while kept.
    private struct Lifted {
        let bundle: URL
        let document: MotionDocument
        let pages: LocalPages

        func lift(_ id: String) throws -> UILiftCache.Lift {
            let asset = try #require(document.assets.first { $0.id == id })
            return try #require(UILiftCache.best(asset, in: bundle))
        }
    }

    private func lift(_ selectors: [String: String], scale: Int = 2) async throws -> Lifted {
        let pages = try await LocalPages.serving(["/": Self.page])
        let bundle = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).motion")
        var document = MotionDocument()
        document.assets = selectors.map { MotionAsset(id: $0.key, url: pages.url("/"), selector: $0.value, viewport: CGSize(width: 800, height: 600)) }
        try await UICapture.lift(selectors.mapValues { _ in scale }, of: document, into: bundle)
        return Lifted(bundle: bundle, document: document, pages: pages)
    }

    @Test func liftsAnElementAloneWithRealAlphaAtItsScale() async throws {
        let lifted = try await lift(["card": "#card", "clear": "#clear", "tall": "#tall"])
        defer { try? FileManager.default.removeItem(at: lifted.bundle) }

        let card = try lifted.lift("card")
        #expect(card.scale == 2)
        #expect(card.size == CGSize(width: 400, height: 200))
        let pixels = try Pixels(card.url)
        #expect(pixels.width == 800)
        // Outside the rounded corner: the page behind is gone
        #expect(pixels.color(column: 1, row: 1).alpha == 0)
        let middle = pixels.color(column: 400, row: 200)
        #expect(middle.alpha == 255)
        #expect(abs(Int(middle.red) - 34) <= 6)

        // A card with no background of its own keeps the one behind it
        let clear = try Pixels(try lifted.lift("clear").url).color(column: 300, row: 100)
        #expect(clear.blue > 200)
        #expect(clear.alpha == 255)

        // Taller than the view: lifted whole
        let tall = try lifted.lift("tall")
        #expect(tall.size == CGSize(width: 200, height: 1500))
        #expect(try Pixels(tall.url).color(column: 200, row: 2990).red > 200)
    }

    @Test func aMissingElementFailsTheLift() async throws {
        await #expect(throws: UICaptureError.notFound("gone", "#gone")) {
            _ = try await lift(["gone": "#gone"])
        }
    }

    @Test func aPlanLiftsWhatItShowsAtTheScaleItNeeds() async throws {
        let lifted = try await lift(["card": "#card"], scale: 1)
        defer { try? FileManager.default.removeItem(at: lifted.bundle) }
        var document = lifted.document
        // Twice the CSS size on a 1080p canvas, exported at 4K: 4 image pixels per CSS pixel
        document.scenes = [MotionScene(id: "one", duration: 1, layers: [MotionLayer(
            id: "ui", content: .lifted(UIContent(asset: "card", width: 800)), transform: Transform3D(position: [960, 540, 0])
        )])]

        let plan = try await UICapture.plan(for: document, bundle: lifted.bundle, shorterSide: 2160)

        #expect(plan.liftsNeeded.isEmpty)
        #expect(try lifted.lift("card").scale == 4)
        #expect(plan.scenes[0].layers[0].image?.extent.size == CGSize(width: 1600, height: 800))
    }
}

// MARK: - Live

extension UICaptureTests {

    /// A white panel with rounded corners on a blue page, and a field in it.
    private static let form = """
    <!doctype html>
    <html><body style="margin: 0; background: rgb(0, 0, 255)">
      <div id="panel" style="position: absolute; left: 100px; top: 100px; width: 400px; height: 200px; box-sizing: border-box;
                             padding: 20px; background: #fff; border-radius: 16px">
        <input id="field" style="width: 300px; height: 40px; font: 28px sans-serif; color: #000; border: 0; outline: 0; background: #fff">
      </div>
    </body></html>
    """

    @Test func aLiveLayerPlaysItsTakeWithItsCursorInsideTheElement() async throws {
        let pages = try await LocalPages.serving(["/": Self.form])
        let bundle = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).motion")
        defer { try? FileManager.default.removeItem(at: bundle) }
        var document = MotionDocument()
        document.canvas.size = CGSize(width: 960, height: 540)
        document.assets = [MotionAsset(
            id: "form", url: pages.url("/"), selector: "#panel", viewport: CGSize(width: 800, height: 600),
            steps: [RecordPageRequest.Step(action: "type", selector: "#field", text: "hello")]
        )]
        // Longer than the take, which holds its last frame
        document.scenes = [MotionScene(id: "one", duration: 5, layers: [MotionLayer(
            id: "live", content: .lifted(UIContent(asset: "form")), transform: Transform3D(position: [480, 270, 0])
        )])]
        try document.validate()

        let start = ContinuousClock.now
        let plan = try await UICapture.plan(for: document, bundle: bundle)
        let baked = ContinuousClock.now - start
        let live = try #require(plan.liveLayers.first?.live)
        #expect(plan.bakesNeeded.isEmpty)
        #expect(plan.scenes[0].layers[0].size == CGSize(width: 400, height: 200))
        #expect(live.duration == 4)

        // Baked at the scale it's shown: a CSS pixel is a canvas pixel here
        let take = try #require(UILiftCache.take(document.assets[0], in: bundle))
        #expect(take.info.scale == 1)
        #expect(take.matte != nil)
        // The keys are typed where the cursor is: on the field, 20 CSS px in from the panel's corner
        let path = try #require(live.cursor)
        let keyTime = try #require(take.telemetry.keys.first?.time)
        let point = path.position(at: keyTime)
        let field = CGRect(x: 20, y: 200 - 60, width: 300, height: 40)
        #expect(field.contains(CGPoint(x: point.x - live.origin.x, y: point.y - live.origin.y)))

        let composition = try await MotionCompositionBuilder.composition(for: plan)
        let before = try Pixels(try await ExportService.frame(of: composition, at: CMTime(value: 30, timescale: 60)))
        let after = try Pixels(try await ExportService.frame(of: composition, at: CMTime(value: 285, timescale: 60)))
        // The layer spans 280...680 × 170...370 on the canvas: white inside, the canvas outside its rounded corner
        #expect(before.color(column: 480, row: 340).red > 240)
        #expect(before.color(column: 281, row: 171).red < 40)
        #expect(before.color(column: 281, row: 171).blue < 60)
        // Typed text shows in the field after, and still in the held last frame
        let darkInField = { (pixels: Pixels) in
            (300..<600).reduce(0) { count, column in count + (190..<230).filter { pixels.color(column: column, row: $0).red < 100 }.count }
        }
        #expect(darkInField(before) < 20)
        #expect(darkInField(after) > 100)
        print("MEASURE live bake of a 4 s take, 400×200 CSS px at 2x: \(baked)")
    }
}

/// An image's sRGB pixels, from the top-left.
private struct Pixels {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init(_ url: URL) throws {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        try self.init(try #require(CGImageSourceCreateImageAtIndex(source, 0, nil)))
    }

    init(_ image: CGImage) throws {
        (width, height) = (image.width, image.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.bytes = bytes
    }

    struct Color {
        let red, green, blue, alpha: UInt8
    }

    func color(column: Int, row: Int) -> Color {
        let index = (row * width + column) * 4
        return Color(red: bytes[index], green: bytes[index + 1], blue: bytes[index + 2], alpha: bytes[index + 3])
    }
}
