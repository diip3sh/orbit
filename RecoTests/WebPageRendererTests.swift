//
//  WebPageRendererTests.swift
//  RecoTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
@testable import Reco

@MainActor
struct WebPageRendererTests {

    private let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    /// A blank button that turns from blue to red over a 300 ms hover transition and turns the page
    /// green when clicked, above a yellow band 500 px down a 3000 px page, cyan while hovered.
    private static let page = """
        <!doctype html><html><head><style>
        body { margin: 0; height: 3000px; background: rgb(255, 255, 255); }
        #buy { position: absolute; left: 100px; top: 100px; width: 200px; height: 60px; border: 0; padding: 0;
               background: rgb(0, 0, 255); transition: background-color 300ms linear; cursor: pointer; }
        #buy:hover { background: rgb(255, 0, 0); }
        #band { position: absolute; left: 0; top: 500px; width: 100%; height: 400px; background: rgb(255, 255, 0); }
        #band:hover { background: rgb(0, 255, 255); }
        </style></head><body><button id="buy"></button><div id="band"></div>
        <script>document.getElementById('buy').onclick = () => { document.body.style.background = 'rgb(0, 255, 0)'; };</script>
        </body></html>
        """

    /// A box whose halves fade from blue to red every second: the left by a CSS animation that
    /// pauses while hovered, the right by the page's script, which pauses it when the pointer enters.
    private static let pausingPage = """
        <!doctype html><html><head><style>
        body { margin: 0; background: rgb(255, 255, 255); }
        #box { position: absolute; left: 300px; top: 0; width: 200px; height: 100px; animation: fade 1s linear infinite; }
        #box:hover { animation-play-state: paused; }
        #inner { position: absolute; left: 100px; top: 0; width: 100px; height: 100px; }
        @keyframes fade { from { background-color: rgb(0, 0, 255); } to { background-color: rgb(255, 0, 0); } }
        </style></head><body><div id="box"><div id="inner"></div></div>
        <script>
        const fade = document.getElementById('inner').animate(
          [{ backgroundColor: 'rgb(0, 0, 255)' }, { backgroundColor: 'rgb(255, 0, 0)' }], { duration: 1000, iterations: Infinity });
        document.getElementById('box').onmouseenter = () => fade.pause();
        </script></body></html>
        """

    private var script: WebScript {
        var script = Self.script(for: Self.page)
        let buy = WebTarget(selector: "#buy", point: .zero)
        script.pointer = [
            PointerClip(range: 0..<0.4, action: .hover, target: buy),
            PointerClip(range: 0.5..<0.8, action: .click, target: buy)
        ]
        script.scrolls = [ScrollClip(range: 0.8..<1, offset: CGPoint(x: 0, y: 500), easing: .easeInOut)]
        return script
    }

    @Test func rendersEveryFrameOnThePagesOwnClock() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let movie = folder.appending(path: "take.mov")
        var progress: [Double] = []

        let (telemetry, issues) = try await WebPageRenderer(script: script).render(to: movie, bitsPerPixel: 0.4) { progress.append($0) }

        #expect(progress.count == 60)
        #expect(progress.last == 1)
        let asset = AVURLAsset(url: movie)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(try await track.load(.naturalSize) == CGSize(width: 640, height: 400))
        #expect(try await frameCount(of: asset) == 60)

        // The hover transition: blue, half-way at 150 ms, then red
        #expect(try await pixel(at: CGPoint(x: 150, y: 110), frame: 0, of: asset).isClose(to: [0, 0, 255]))
        #expect(try await pixel(at: CGPoint(x: 150, y: 110), frame: 9, of: asset).isClose(to: [128, 0, 128]))
        #expect(try await pixel(at: CGPoint(x: 150, y: 110), frame: 20, of: asset).isClose(to: [255, 0, 0]))
        // The click, whose release at 0.6 s is frame 36, then the scroll down to the band, which is
        // hovered once it passes under the resting cursor
        #expect(try await pixel(at: CGPoint(x: 20, y: 20), frame: 35, of: asset).isClose(to: [255, 255, 255]))
        #expect(try await pixel(at: CGPoint(x: 20, y: 20), frame: 36, of: asset).isClose(to: [0, 255, 0]))
        #expect(try await pixel(at: CGPoint(x: 20, y: 200), frame: 59, of: asset).isClose(to: [0, 255, 255]))

        #expect(telemetry.capture.kind == .web)
        #expect(telemetry.clicks.map(\.time) == [0.5, 0.6])
        #expect(telemetry.clicks.map(\.isDown) == [true, false])
        #expect(telemetry.clicks.allSatisfy { $0.location == CGPoint(x: 200, y: 130) })
        // The cursor rests on the button's spot while the page scrolls, over the band by the end
        #expect(telemetry.cursor.map(\.location) == [CGPoint(x: 200, y: 130)])
        #expect(telemetry.cursorSprites.map(\.kind) == [.pointingHand, .arrow])
        #expect(telemetry.cursorShapes.map(\.sprite) == [0, 1])
        // Scrolling down the page, as a wheel reports it
        #expect(telemetry.scrolls.first?.time == 49.0 / 60)
        #expect(telemetry.scrolls.allSatisfy { $0.delta.dy < 0 })
        #expect(issues.isEmpty)
    }

    @Test func holdsTheAnimationsThePagePauses() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        var script = Self.script(for: Self.pausingPage)
        script.pointer = [
            PointerClip(range: 0..<0.1, action: .hover, target: WebTarget(selector: nil, point: CGPoint(x: 50, y: 300))),
            PointerClip(range: 0.5..<1, action: .hover, target: WebTarget(selector: "#box", anchor: CGPoint(x: 0.25, y: 0.5), point: .zero))
        ]

        let movie = try await render(script).movie

        for point in [CGPoint(x: 320, y: 50), CGPoint(x: 450, y: 50)] {
            // Fading while the cursor travels, then held from its arrival at 0.5 s
            #expect(try await !pixel(at: point, frame: 0, of: movie).isClose(to: pixel(at: point, frame: 20, of: movie)))
            #expect(try await pixel(at: point, frame: 45, of: movie).isClose(to: pixel(at: point, frame: 59, of: movie)))
        }
    }

    @Test func aHiddenTargetFallsBackToItsPoint() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        var script = Self.script(for: #"<!doctype html><html><body><button id="menu" style="display: none">Menu</button></body></html>"#)
        script.pointer = [PointerClip(range: 0..<1, action: .hover, target: WebTarget(selector: "#menu", point: CGPoint(x: 40, y: 60)))]

        let telemetry = try await render(script).telemetry

        #expect(telemetry.cursor.map(\.location) == [CGPoint(x: 40, y: 60)])
    }

    @Test func aScrollToAnElementAimsAtWhereThePageHasItWhenTheScrollStarts() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        // A banner the page adds after loading moves the band 300 px further down than planned
        var script = Self.script(for: """
            <!doctype html><html><body style="margin: 0"><div style="height: 1000px"></div>
            <div id="band" style="height: 100px; background: rgb(0, 0, 255)"></div><div style="height: 2000px"></div><script>
            setTimeout(() => document.body.insertAdjacentHTML('afterbegin', '<div style="height: 300px"></div>'), 50);
            </script></body></html>
            """)
        script.scrolls = [ScrollClip(range: 0.2..<0.8, offset: CGPoint(x: 0, y: 1000 - 60), target: .init(selector: "#band", placement: .top))]

        let movie = try await render(script).movie

        // Its top 15% of the 400 px viewport down, at 60 px
        #expect(try await pixel(at: CGPoint(x: 20, y: 70), frame: 59, of: movie).isClose(to: [0, 0, 255]))
        #expect(try await !pixel(at: CGPoint(x: 20, y: 50), frame: 59, of: movie).isClose(to: [0, 0, 255]))
    }

    @Test func aCoveredOrMissingTargetIsReportedAndAMissingOnesClickLeftOut() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        // A click anywhere turns the page green; the button is under a menu that covers the page
        var script = Self.script(for: """
            <!doctype html><html><body><button id="buy">Buy</button>
            <div id="menu" style="position: fixed; inset: 0; background: rgb(255, 255, 255)">Menu</div><script>
            addEventListener('click', () => { document.body.style.background = 'rgb(0, 255, 0)'; });
            </script></body></html>
            """)
        script.pointer = [
            PointerClip(range: 0..<0.3, action: .hover, target: WebTarget(selector: "#buy", point: .zero)),
            PointerClip(range: 0.5..<0.8, action: .click, target: WebTarget(selector: "#gone", point: CGPoint(x: 320, y: 200)))
        ]
        // Reco's own scroll before the click, which finds nothing either: the click's check says so
        script.scrolls = [ScrollClip(range: 0.3..<0.5, offset: .zero, target: .init(selector: "#gone", placement: .intoView))]

        let rendered = try await render(script)
        let (movie, issues) = (rendered.movie, rendered.issues)

        #expect(issues.count == 3)
        #expect(issues.first?.contains(##"div#menu ("Menu") covered "#buy""##) == true)
        #expect(issues.dropFirst().allSatisfy { $0.contains("#gone") })
        // Once for its press and release
        #expect(issues.filter { $0.contains("its click was left out") }.count == 1)
        #expect(try await !pixel(at: CGPoint(x: 600, y: 380), frame: 59, of: movie).isClose(to: [0, 255, 0]))
    }

    @Test func mutesThePagesMedia() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        // Green when both the page's audio element and one it plays from script are muted
        let script = Self.script(for: """
            <!doctype html><html><body><audio id="sound" src="data:audio/wav;base64," autoplay></audio><script>
            const played = new Audio();
            played.play().catch(() => {});
            setTimeout(() => {
              document.body.style.background = sound.muted && played.muted ? 'rgb(0, 255, 0)' : 'rgb(255, 0, 0)';
            }, 100);
            </script></body></html>
            """)

        let movie = try await render(script).movie

        #expect(try await pixel(at: CGPoint(x: 20, y: 20), frame: 0, of: movie).isClose(to: [0, 255, 0]))
    }

    @Test func rendersIntoAFolderThatDoesNotExistYet() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let movie = folder.appending(path: "Not Yet/take.mov")

        _ = try await WebPageRenderer(script: script).render(to: movie, bitsPerPixel: 0.4) { _ in }

        #expect(FileManager.default.fileExists(atPath: movie.path(percentEncoded: false)))
    }

    @Test func failsWhenThePageCantLoad() async throws {
        var script = script
        script.url = URL(string: "https://nonexistent.invalid/")

        await #expect(throws: WebRenderError.self) {
            try await WebPageRenderer(script: script).render(to: folder.appending(path: "take.mov"), bitsPerPixel: 0.4) { _ in }
        }
    }

    @Test func inspectingListsTheButtonAndTheBoxesAskedFor() async throws {
        let inspection = try await WebPageRenderer(script: Self.script(for: Self.page)).inspect(selectors: ["#band", "#nope"])

        #expect(inspection.viewport == PageInspection.Size(width: 640, height: 400))
        #expect(inspection.pageHeight == 3000)
        #expect(!inspection.truncated)
        let buy = try #require(inspection.elements.first)
        #expect(inspection.elements.count == 1)
        #expect(buy.selector == "#buy")
        #expect(buy.role == "button")
        #expect(buy.box.rect == CGRect(x: 100, y: 100, width: 200, height: 60))
        // Only what matched, in page pixels
        #expect(inspection.boxes?.keys.sorted() == ["#band"])
        #expect(inspection.boxes?["#band"]?.rect == CGRect(x: 0, y: 500, width: 640, height: 400))
    }

    @Test func inspectingNamesRolesAndTextAndSkipsWhatIsntVisible() async throws {
        let page = """
            <!doctype html><html><body style="margin: 0">
            <a href="/pricing" id="pricing">  Pricing   and
              plans </a>
            <button id="close" aria-label="Close dialog">x</button>
            <button id="gone" style="display: none">Gone</button>
            <button id="ghost" style="opacity: 0">Ghost</button>
            <button id="hidden" style="visibility: hidden">Hidden</button>
            <input id="agree" type="checkbox"><input id="password" type="password" value="hunter2">
            <input id="secret" type="hidden">
            <input id="name" value="Ada">
            <h1 id="title">Hello</h1>
            <div id="plain">Not interactive</div>
            </body></html>
            """

        let inspection = try await WebPageRenderer(script: Self.script(for: page)).inspect(selectors: [])

        let found: [[String]] = inspection.elements.map { [$0.selector, $0.role, $0.text] }
        #expect(found == [
            ["#pricing", "link", "Pricing and plans"], ["#close", "button", "Close dialog"], ["#agree", "checkbox", ""],
            ["#password", "password", ""], ["#name", "text", "Ada"], ["#title", "heading", "Hello"]
        ])
        // Nothing asked for, so no boxes at all
        #expect(inspection.boxes == nil)
    }

    @Test func inspectingStopsAtTwoHundredElements() async throws {
        let links = (0..<250).map { "<a href=\"#\($0)\">Link \($0)</a>" }.joined(separator: "<br>")

        let inspection = try await WebPageRenderer(script: Self.script(for: "<!doctype html><html><body>\(links)</body></html>")).inspect(selectors: [])

        #expect(inspection.elements.count == WebInspectScript.maximumElements)
        #expect(inspection.truncated)
    }

    /// A take of `page` at 640 × 400, 1×, for a second.
    private static func script(for page: String) -> WebScript {
        var script = WebScript()
        script.url = URL(string: "data:text/html;charset=utf-8," + (page.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""))
        script.viewport = CGSize(width: 640, height: 400)
        script.scale = 1
        script.duration = 1
        return script
    }

    /// Renders `script` into the test's folder.
    private func render(_ script: WebScript) async throws -> Rendered {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let movie = folder.appending(path: "take.mov")
        let (telemetry, issues) = try await WebPageRenderer(script: script).render(to: movie, bitsPerPixel: 0.4) { _ in }
        return Rendered(telemetry: telemetry, movie: AVURLAsset(url: movie), issues: issues)
    }

    private struct Rendered {
        let telemetry: InputTelemetry
        let movie: AVURLAsset
        let issues: [String]
    }

    @concurrent nonisolated private func frameCount(of asset: AVAsset) async throws -> Int {
        let reader = try AVAssetReader(asset: asset)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        reader.startReading()
        var count = 0
        while let sample = output.copyNextSampleBuffer() {
            count += CMSampleBufferGetNumSamples(sample)
        }
        return count
    }

    /// The sRGB pixel at `point`, in page pixels from the top-left corner, of frame number `frame`.
    @concurrent nonisolated private func pixel(at point: CGPoint, frame: Int, of asset: AVAsset) async throws -> [UInt8] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = CIImage(cgImage: try await generator.image(at: CMTime(value: CMTimeValue(frame), timescale: 60)).image)
        return image.pixel(at: CGPoint(x: point.x, y: image.extent.height - 1 - point.y))
    }
}

private extension [UInt8] {

    /// Whether the red, green and blue are within what HEVC's compression moves flat colours.
    func isClose(to color: [UInt8]) -> Bool {
        zip(self, color).allSatisfy { abs(Int($0) - Int($1)) <= 12 }
    }
}
