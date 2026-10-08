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
      <div style="background: rgb(0, 0, 0); padding: 20px"><div id="glassy" style="width: 300px; height: 100px; background: rgba(255, 255, 255, 0.2)"></div></div>
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
        let lifted = try await lift(["card": "#card", "clear": "#clear", "glassy": "#glassy", "tall": "#tall"])
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

        // A translucent one keeps the page under it, blended, so nothing shows through it: Linear's
        // panels are a few percent white over black
        let glassy = try Pixels(try lifted.lift("glassy").url).color(column: 300, row: 100)
        #expect(glassy.alpha == 255)
        #expect(abs(Int(glassy.red) - 51) <= 6 && abs(Int(glassy.blue) - 51) <= 6)

        // Taller than the view: lifted whole
        let tall = try lifted.lift("tall")
        #expect(tall.size == CGSize(width: 200, height: 1500))
        #expect(try Pixels(tall.url).color(column: 200, row: 2990).red > 200)
    }

    /// A search dialog that only exists once its button is clicked, typed into: results come 0.3 s after
    /// the field changes. Under it, a heading that shows itself (`visibility: visible` inside a hidden
    /// header) and a border a stylesheet forces, as Supabase's docs have.
    private static let search = """
    <!doctype html>
    <html><head><style>body #dialog { border: 1px solid rgb(255, 0, 0) !important; }</style></head>
    <body style="margin: 0; background: #fff">
      <header style="position: absolute; left: 100px; top: 100px"><h1 style="visibility: visible; color: rgb(255, 0, 0); margin: 0; font: 40px sans-serif">Docs</h1></header>
      <button id="open" onclick="document.getElementById('dialog').hidden = false">Search</button>
      <div id="dialog" hidden style="position: fixed; left: 100px; top: 100px; width: 400px; border-radius: 12px; background: rgb(34, 34, 34)">
        <div style="height: 48px; display: flex; align-items: center">
          <input style="flex: 1; margin-left: 40px; border: 0; background: transparent; color: #fff; font: 16px sans-serif; outline: none">
        </div>
        <div id="results"></div>
      </div>
      <script>
        document.querySelector('#dialog input').addEventListener('input', event => {
          clearTimeout(window.pending);
          window.pending = setTimeout(() => {
            document.getElementById('results').innerHTML = event.target.value.length > 1
              ? [0, 1, 2].map(index => `<div aria-selected="${index === 0}" style="height: 30px; margin-top: 4px; background: rgb(0, 0, 255)"></div>`).join('') : '';
          }, 300);
        });
        document.querySelector('#dialog input').addEventListener('keydown', event => {
          if (event.key !== 'ArrowDown') return;
          const items = [...document.querySelectorAll('#results [aria-selected]')];
          const index = items.findIndex(item => item.getAttribute('aria-selected') === 'true');
          items.forEach((item, other) => item.setAttribute('aria-selected', String(other === Math.min(index + 1, items.length - 1))));
        });
      </script>
    </body></html>
    """

    /// Clicked open, typed into and lifted bare: its empty field, each letter's row, and the whole dialog
    /// once its results came, where the text ends each time; nothing of the page or of its own surface.
    @Test func typesIntoADialogOpenedByAClick() async throws {
        let pages = try await LocalPages.serving(["/": Self.search])
        let bundle = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).motion")
        defer { try? FileManager.default.removeItem(at: bundle) }
        var asset = MotionAsset(id: "search", url: pages.url("/"), selector: "#dialog", viewport: CGSize(width: 800, height: 600))
        (asset.glass, asset.before) = (true, [RecordPageRequest.Step(action: "click", selector: "#open")])
        asset.typing = MotionAsset.Typing(field: "input", text: "ab", select: 1)
        var document = MotionDocument()
        document.assets = [asset]

        try await UICapture.lift(["search": 2], of: document, into: bundle)

        let typing = try #require(UILiftCache.typing(asset, in: bundle))
        // Under the dialog's border, as wide as the dialog
        #expect(typing.row == CGRect(x: 0, y: 1, width: 402, height: 48))
        #expect(typing.ends.count == 3 && typing.ends[0] < typing.ends[1] && typing.ends[1] < typing.ends[2])
        // Three results of 30 px, 4 px apart, under the row and the border; the first selected, then the second
        #expect(typing.settled == [2] && typing.heights == [152])
        #expect(typing.selections == [68, 102])
        #expect(FileManager.default.fileExists(atPath: UILiftCache.selectedURL(of: asset, presses: 1, scale: 2, in: bundle).path(percentEncoded: false)))
        #expect(typing.fontSize == 16)
        for length in [1, 2] {
            #expect(FileManager.default.fileExists(atPath: UILiftCache.typedURL(of: asset, length: length, scale: 2, in: bundle).path(percentEncoded: false)))
        }
        let settled = try Pixels(UILiftCache.settledURL(of: asset, length: 2, scale: 2, in: bundle))
        #expect(settled.height == 304)
        let empty = try Pixels(try #require(UILiftCache.best(asset, in: bundle)).url)
        // Bare: its border, the stylesheet's own, and its fill are gone; the heading under it never shows
        #expect(empty.color(column: 1, row: 48).alpha == 0)
        #expect(empty.color(column: 300, row: 48).alpha == 0)
        let red = { (column: Int, row: Int) in empty.color(column: column, row: row).red > 200 && empty.color(column: column, row: row).green < 100 }
        #expect(!(0..<empty.height).contains { row in (0..<empty.width).contains { red($0, row) } })
    }

    /// A marketing page's drawing of a prompt box: its text emptied and typed back a character at a time,
    /// the caret's place measured each time, and the page left as it was for its other lifts.
    @Test func typesIntoAMockupThatIsNoField() async throws {
        let page = """
        <!doctype html>
        <html><body style="margin: 0; background: #fff">
          <div id="box" style="width: 400px; padding: 16px; border-radius: 12px; background: rgb(34, 34, 34)">
            <p style="margin: 0; color: #fff; font: 16px/40px sans-serif"><span id="prompt"><b>@Agent</b> plan the launch</span></p>
          </div>
        </body></html>
        """
        let pages = try await LocalPages.serving(["/": page])
        let bundle = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).motion")
        defer { try? FileManager.default.removeItem(at: bundle) }
        var asset = MotionAsset(id: "box", url: pages.url("/"), selector: "#box", viewport: CGSize(width: 800, height: 600))
        asset.typing = MotionAsset.Typing(field: "#prompt", text: "ship it")
        var other = MotionAsset(id: "after", url: pages.url("/"), selector: "#prompt", viewport: CGSize(width: 800, height: 600))
        other.bare = true
        var document = MotionDocument()
        document.assets = [asset, other]

        try await UICapture.lift(["box": 2, "after": 2], of: document, into: bundle)

        let typing = try #require(UILiftCache.typing(asset, in: bundle))
        #expect(typing.ends.count == 8)
        #expect(zip(typing.ends, typing.ends.dropFirst()).allSatisfy { $0 < $1 })
        // Empty, the caret sits where the text starts, the box's padding; typed, where the laid-out text
        // ends: "ship it" in 16 px sans-serif is about 50 px
        #expect(abs(typing.ends[0] - 16) < 1)
        #expect((40...70).contains(typing.ends[7] - 16))
        // On the text's line, not the empty inline box's top (a line with nothing in it has no height): 16 px
        // padding, then half the 40 px line
        #expect((33...39).contains(typing.line))
        for length in 1...7 {
            #expect(FileManager.default.fileExists(atPath: UILiftCache.typedURL(of: asset, length: length, scale: 2, in: bundle).path(percentEncoded: false)))
        }
        // The page's own text came back for the next lift: wider than "ship it" alone
        let after = try #require(UILiftCache.best(other, in: bundle))
        #expect(after.size.width > typing.ends[7] - 16 + 40)
    }

    /// A region lifts only that part of the element: the top of a long article.
    @Test func liftsARegionOfALongElement() async throws {
        let pages = try await LocalPages.serving(["/": Self.page])
        let bundle = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).motion")
        defer { try? FileManager.default.removeItem(at: bundle) }
        var asset = MotionAsset(id: "tall", url: pages.url("/"), selector: "#tall", viewport: CGSize(width: 800, height: 600))
        asset.region = CGRect(x: 0, y: 0, width: 200, height: 300)
        var document = MotionDocument()
        document.assets = [asset]

        try await UICapture.lift(["tall": 2], of: document, into: bundle)

        let lift = try #require(UILiftCache.best(asset, in: bundle))
        #expect(lift.size == CGSize(width: 200, height: 300))
        let middle = try Pixels(lift.url).color(column: 200, row: 300)
        #expect(middle.red == 255 && middle.green == 0 && middle.alpha == 255)
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
