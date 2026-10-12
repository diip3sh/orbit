//
//  WebCleanPageTests.swift
//  RecoTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
@testable import Reco

/// What keeps a take's page clean (spec 0010, step 1): its overlays listed, and hidden from the first frame.
@MainActor
struct WebCleanPageTests {

    /// A red cookie banner fixed to the bottom, a sticky navigation bar holding a fixed menu, and a
    /// plain box.
    private static let page = """
        <!doctype html><html><body style="margin: 0; height: 2000px; background: #fff">
        <nav id="bar" style="position: sticky; top: 0; height: 40px; background: #eee">Home
          <div id="menu" style="position: fixed; top: 0; right: 0; width: 50px; height: 20px">Menu</div></nav>
        <div id="cookies" style="position: fixed; left: 0; bottom: 0; width: 100%; height: 80px; background: rgb(255, 0, 0)">We use cookies</div>
        <div style="position: fixed; left: 0; top: 3000px; width: 10px; height: 10px">Off screen</div>
        </body></html>
        """

    private func script(hiding hide: [String]? = nil) -> WebScript {
        var script = WebScript()
        script.url = URL(string: "data:text/html;charset=utf-8," + (Self.page.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""))
        script.viewport = CGSize(width: 640, height: 400)
        script.scale = 1
        script.duration = 0.5
        script.hide = hide
        return script
    }

    @Test func inspectingListsTheOutermostOverlaysInView() async throws {
        let inspection = try await WebPageRenderer(script: script()).inspect(selectors: [])

        let overlays = try #require(inspection.overlays)
        #expect(overlays.map(\.selector) == ["#bar", "#cookies"])
        #expect(overlays.map(\.position) == ["sticky", "fixed"])
        #expect(overlays[1].text == "We use cookies")
        #expect(overlays[1].box.rect == CGRect(x: 0, y: 320, width: 640, height: 80))
    }

    @Test func inspectingReadsTheBrand() async throws {
        let page = """
            <!doctype html><html><body style="margin: 0; background: rgb(16, 16, 16)">
            <a href="/" style="position: absolute; left: 20px; top: 10px"><svg id="mark" width="30" height="20"></svg></a>
            <a href="#" style="position: absolute; left: 400px; top: 10px; background: rgb(255, 0, 0)">Log in</a>
            <h1 style="font-family: 'Tiempos Headline', Georgia, serif; color: oklch(0.95 0 0)">Launch videos</h1>
            <a href="#" style="display: inline-block; width: 200px; height: 50px; background: rgb(94, 106, 210)">Get started</a>
            </body></html>
            """
        var script = script()
        script.url = URL(string: "data:text/html;charset=utf-8," + (page.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""))

        let brand = try #require(try await WebPageRenderer(script: script).inspect(selectors: []).brand)

        #expect(brand.background == "#101010")
        #expect(brand.text == "#eeeeee" || brand.text == "#efefef")
        #expect(brand.accent == "#5e6ad2")
        #expect(brand.face == "serif")
        #expect(brand.font == "Tiempos Headline")
    }

    @Test func inspectingListsWhatAMotionVideoCanLift() async throws {
        let page = """
            <!doctype html><html><body style="margin: 0; background: #fff">
            <section style="height: 300px; background: #eee"><div id="card" style="width: 300px; height: 160px; border-radius: 12px; \
            background: rgb(20, 20, 30)"><div id="inner" style="width: 300px; height: 160px; border-radius: 12px; background: #222">Plans</div></div></section>
            <div id="flat" style="width: 300px; height: 160px; background: #333"></div>
            <div id="small" style="width: 100px; height: 40px; border-radius: 8px; background: #333"></div>
            </body></html>
            """
        var script = script()
        script.url = URL(string: "data:text/html;charset=utf-8," + (page.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""))

        let liftable = try #require(try await WebPageRenderer(script: script).inspect(selectors: []).liftable)

        // The rounded card once (its child has the same box); not the full-width section, the square box or the small one
        #expect(liftable.map(\.selector) == ["#card"])
        #expect(liftable.first?.box.radius == 12)
        #expect(liftable.first?.background == "#14141e")
        #expect(liftable.first?.kind == "panel")
    }

    @Test func aTakeOfLocalhostRenders() async throws {
        let pages = try await LocalPages.serving(["/": "<!doctype html><html><body style=\"background: rgb(0, 255, 0)\"></body></html>"])
        var script = script()
        script.url = URL(string: pages.url("/").absoluteString.replacing("127.0.0.1", with: "localhost"))
        let movie = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: movie) }

        _ = try await WebPageRenderer(script: script).render(to: movie, bitsPerPixel: 0.4) { _ in }

        let frame = CIImage(cgImage: try await AVAssetImageGenerator(asset: AVURLAsset(url: movie)).image(at: .zero).image)
        #expect(frame.pixel(at: CGPoint(x: 10, y: 10))[1] > 200)
        withExtendedLifetime(pages) {}
    }

    @Test func hiddenOverlaysAreGoneFromTheFirstFrame() async throws {
        let movie = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: movie) }
        // An invalid selector spoils only its own rule
        _ = try await WebPageRenderer(script: script(hiding: ["#cookies", "::nonsense("])).render(to: movie, bitsPerPixel: 0.4) { _ in }

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: movie))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let frame = CIImage(cgImage: try await generator.image(at: .zero).image)
        // The banner's place, 40 px up from the bottom, shows the white page
        #expect(frame.pixel(at: CGPoint(x: 320, y: 40)).prefix(3).allSatisfy { $0 > 240 })
    }
}
