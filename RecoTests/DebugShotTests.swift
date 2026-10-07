//
//  DebugShotTests.swift
//  RecoTests
//
//  Temporary: renders the look tests of spec 0012's direction (L0–L3). Delete before committing.
//

import AppKit
import AVFoundation
import CoreImage
import Foundation
import Testing
import WebKit
@testable import Reco

@MainActor
struct DebugShotTests {

    static let scratch = "/private/tmp/claude-501/-Users-divyendra-orca-ssentch/00e31081-8885-4c36-a94f-be1c70a565c8/scratchpad"

    @Test func renderShot() async throws {
        let bundle = URL(filePath: Self.scratch + "/shot/Satin.motion")
        let data = try Data(contentsOf: bundle.appending(path: "document.json"))
        let document = try JSONDecoder().decode(MotionDocument.self, from: data)
        try document.validate()
        var settings = ExportSettings()
        settings.resolution = 1080
        settings.frameRate = 60
        let url = try await MotionExporter.export(document, bundle: bundle, settings: settings) { _ in }
        print("EXPORTED \(url.path())")
    }

    /// A page lab: `lab/job.json` lists pages and steps (run script, wait, inspect, shoot the view,
    /// lift an element); results land next to it.
    struct Job: Decodable {
        struct Page: Decodable {
            let url: URL
            let width: Double
            let height: Double
            let steps: [Step]
        }
        struct Step: Decodable {
            let kind: String
            let name: String?
            let js: String?
            let selector: String?
            let scale: Int?
            let fill: Bool?
            let wait: Double?
        }
        let pages: [Page]
    }

    @Test func lab() async throws {
        let root = URL(filePath: Self.scratch + "/lab")
        let job = try JSONDecoder().decode(Job.self, from: Data(contentsOf: root.appending(path: "job.json")))
        for page in job.pages {
            var script = WebScript()
            script.url = page.url
            script.viewport = CGSize(width: page.width, height: page.height)
            do {
                try await WebPageRenderer(script: script).withLoadedPage { webView in
                    for step in page.steps {
                        try await Self.run(step, in: webView, root: root)
                        if let wait = step.wait {
                            try await Task.sleep(for: .seconds(wait))
                        }
                    }
                }
            } catch {
                print("LAB FAILED \(page.url): \(error)")
            }
        }
        print("LAB DONE")
    }

    private static func run(_ step: Job.Step, in webView: WKWebView, root: URL) async throws {
        let name = step.name ?? "out"
        switch step.kind {
        case "js":
            let result = try await webView.callAsyncJavaScript(step.js ?? "", arguments: [:], contentWorld: .defaultClient)
            print("LAB JS \(name): \(String(describing: result))")
        case "inspect":
            let result = try await webView.callAsyncJavaScript(WebInspectScript.source, arguments: ["selectors": [String]()], contentWorld: .defaultClient)
            try (result as? String ?? "").write(to: root.appending(path: "\(name).json"), atomically: true, encoding: .utf8)
            print("LAB INSPECT \(name)")
        case "shot":
            webView.setValue(true, forKey: "drawsBackground")
            let configuration = WKSnapshotConfiguration()
            configuration.snapshotWidth = NSNumber(value: webView.bounds.width * CGFloat(step.scale ?? 1) / (webView.window?.backingScaleFactor ?? 1))
            try await write(webView.takeSnapshot(configuration: configuration), to: root.appending(path: "\(name).png"))
        case "lift":
            webView.setValue(false, forKey: "drawsBackground")
            let selector = step.selector ?? "body"
            let placed = try await webView.callAsyncJavaScript(UILiftScript.place, arguments: ["selector": selector], contentWorld: .defaultClient)
            guard let placed = placed as? [String: Any], let box = placed["box"] as? [Double] else {
                print("LAB LIFT \(name): not found")
                return
            }
            let fill: Any = step.fill == false ? NSNull() : (placed["fill"] as? String ?? "transparent")
            let arguments: [String: Any] = ["selector": selector, "fill": fill, "bare": false]
            _ = try await webView.callAsyncJavaScript(UILiftScript.isolate, arguments: arguments.merging(["on": true]) { $1 }, contentWorld: .defaultClient)
            let configuration = WKSnapshotConfiguration()
            configuration.rect = CGRect(x: box[0], y: box[1], width: box[2], height: box[3]).intersection(webView.bounds)
            configuration.snapshotWidth = NSNumber(value: configuration.rect.width * CGFloat(step.scale ?? 2) / (webView.window?.backingScaleFactor ?? 1))
            let image = try await webView.takeSnapshot(configuration: configuration)
            _ = try await webView.callAsyncJavaScript(UILiftScript.isolate, arguments: arguments.merging(["on": false]) { $1 }, contentWorld: .defaultClient)
            try await write(image, to: root.appending(path: "\(name).png"))
            print("LAB LIFT \(name): box \(box)")
        case "snap":
            // The page as it is (isolated by the job's own scripts), the element's box at `scale`
            webView.setValue(false, forKey: "drawsBackground")
            let box = try await webView.callAsyncJavaScript(
                "const r = document.querySelector(selector).getBoundingClientRect(); return [r.x, r.y, r.width, r.height]",
                arguments: ["selector": step.selector ?? "body"], contentWorld: .defaultClient
            ) as? [Double] ?? [0, 0, webView.bounds.width, webView.bounds.height]
            let configuration = WKSnapshotConfiguration()
            configuration.rect = CGRect(x: box[0], y: box[1], width: box[2], height: box[3]).intersection(webView.bounds)
            configuration.snapshotWidth = NSNumber(value: configuration.rect.width * CGFloat(step.scale ?? 2) / (webView.window?.backingScaleFactor ?? 1))
            try await write(webView.takeSnapshot(configuration: configuration), to: root.appending(path: "\(name).png"))
            print("LAB SNAP \(name): box \(box)")
        default:
            print("LAB unknown step \(step.kind)")
        }
    }

    /// Satin frames for the film comparison: `lab/satin.json` lists frames (setup, time in the shot,
    /// the camera's shift and zoom, a grain frame or none); each is written as `satin/<name>.png`.
    struct SatinFrame: Decodable {
        let name: String
        let setup: Int
        let time: Double
        let shift: [Double]?
        let zoom: Double?
        let grain: Int?
        let size: [Double]?
        let flat: Double?
    }

    @Test func satin() async throws {
        let root = URL(filePath: Self.scratch + "/lab")
        let frames = try JSONDecoder().decode([SatinFrame].self, from: Data(contentsOf: root.appending(path: "satin.json")))
        try FileManager.default.createDirectory(at: root.appending(path: "satin"), withIntermediateDirectories: true)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let source = try String(contentsOf: try #require(Bundle.main.url(forResource: "FieldKernels.metal", withExtension: "txt")), encoding: .utf8)
        for name in ["satinGround", "satinFinish", "filmGrainNoise", "filmGrain"] {
            do {
                print("LAB KERNEL \(name): \(try CIKernel.kernels(withMetalString: "#define \(name)_ONLY\n" + source).map { type(of: $0) })")
            } catch {
                print("LAB KERNEL \(name) FAILED: \(error)")
            }
        }
        for frame in frames {
            let size = CGSize(width: frame.size?[0] ?? 1920, height: frame.size?[1] ?? 1080)
            let shot = FieldRenderer.Shot(
                index: frame.setup, start: 0, shift: CGVector(dx: frame.shift?[0] ?? 0, dy: frame.shift?[1] ?? 0), zoom: frame.zoom ?? 1
            )
            var image = FieldRenderer.image(.satin, palette: FieldPalette(.satin, accent: nil, background: MotionCanvas().background), at: frame.time, size: size, shot: shot)
            if let flat = frame.flat {
                image = CIImage(color: CIColor(red: flat, green: flat, blue: flat)).cropped(to: CGRect(origin: .zero, size: size))
            }
            if let grain = frame.grain {
                image = FieldRenderer.grained(image, index: grain, size: size)
            }
            let clock = ContinuousClock.now
            let cgImage = try #require(context.createCGImage(image, from: CGRect(origin: .zero, size: size), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)))
            let elapsed = ContinuousClock.now - clock
            try await ScreenshotService.writePNG(cgImage, to: root.appending(path: "satin/\(frame.name).png"))
            print("LAB SATIN \(frame.name) \(elapsed)")
        }
        print("LAB DONE")
    }

    /// The glass check (spec 0012, phase 2): `lab/glass/document.json` drawn by the engine, its lifts
    /// seeded from the film's captures, each frame beside the film's (with the engine's grain).
    struct GlassJob: Decodable {
        struct Lift: Decodable {
            let asset: String
            let file: String
            let scale: Int
            let radius: Double
            /// `typed` or `settled` with the text's length; the asset's own lift without.
            let kind: String?
            let length: Int?
        }
        struct Frame: Decodable {
            let name: String
            let time: Double
        }
        let lifts: [Lift]
        let frames: [Frame]
        let typing: [String: UILiftCache.Typing]?
    }

    @Test func glass() async throws {
        let root = URL(filePath: Self.scratch + "/lab/" + (ProcessInfo.processInfo.environment["LAB_CHECK"] ?? "glass"))
        let job = try JSONDecoder().decode(GlassJob.self, from: Data(contentsOf: root.appending(path: "job.json")))
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(contentsOf: root.appending(path: "document.json")))
        try document.validate()
        let bundle = root.appending(path: "Check.motion")
        try? FileManager.default.removeItem(at: bundle)
        try FileManager.default.createDirectory(at: bundle.appending(path: "assets/lifts"), withIntermediateDirectories: true)
        for lift in job.lifts {
            let asset = try #require(document.assets.first { $0.id == lift.asset })
            let target = switch lift.kind {
            case "typed": UILiftCache.typedURL(of: asset, length: lift.length ?? 0, scale: lift.scale, in: bundle)
            case "settled": UILiftCache.settledURL(of: asset, length: lift.length ?? 0, scale: lift.scale, in: bundle)
            case "selected": UILiftCache.selectedURL(of: asset, presses: lift.length ?? 0, scale: lift.scale, in: bundle)
            default: UILiftCache.url(of: asset, scale: lift.scale, in: bundle)
            }
            try FileManager.default.copyItem(at: URL(filePath: lift.file), to: target)
            try JSONEncoder().encode(UILiftCache.Shape(radius: lift.radius)).write(to: UILiftCache.shapeURL(of: asset, in: bundle))
        }
        for (id, typing) in job.typing ?? [:] {
            let asset = try #require(document.assets.first { $0.id == id })
            try JSONEncoder().encode(typing).write(to: UILiftCache.typingURL(of: asset, in: bundle))
        }
        let plan = await MotionPlan.build(document, bundle: bundle, shorterSide: 1080)
        print("LAB GLASS lifts needed \(plan.liftsNeeded)")
        try FileManager.default.createDirectory(at: root.appending(path: "out"), withIntermediateDirectories: true)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let extent = CGRect(origin: .zero, size: plan.outputSize)
        let srgb = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        for frame in job.frames {
            let clock = ContinuousClock.now
            let image = try #require(context.createCGImage(MotionFrameRenderer.image(at: frame.time, plan: plan), from: extent, format: .RGBA8, colorSpace: srgb))
            print("LAB GLASS \(frame.name) drawn in \(ContinuousClock.now - clock)")
            try await ScreenshotService.writePNG(image, to: root.appending(path: "out/\(frame.name).png"))
            let reference = try #require(CIImage(contentsOf: root.appending(path: "ref/\(frame.name).png")))
            let grained = FieldRenderer.grained(reference, index: Int((frame.time * Double(plan.frameRate)).rounded()), size: plan.outputSize)
            let referenceImage = try #require(context.createCGImage(grained, from: extent, format: .RGBA8, colorSpace: srgb))
            try await ScreenshotService.writePNG(referenceImage, to: root.appending(path: "out/\(frame.name)-ref.png"))
        }
        print("LAB DONE")
    }

    /// The capture check: `lab/capture/document.json` captured from the web as the app does, then drawn.
    @Test func capture() async throws {
        let root = URL(filePath: Self.scratch + "/lab/capture")
        let job = try JSONDecoder().decode(GlassJob.self, from: Data(contentsOf: root.appending(path: "job.json")))
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(contentsOf: root.appending(path: "document.json")))
        let bundle = root.appending(path: "Check.motion")
        try? FileManager.default.removeItem(at: bundle)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        let clock = ContinuousClock.now
        let plan = try await UICapture.plan(for: document, bundle: bundle, shorterSide: 1080)
        print("LAB CAPTURE took \(ContinuousClock.now - clock), still needed \(plan.liftsNeeded)")
        for asset in document.assets {
            print("LAB CAPTURE \(asset.id): \(String(describing: UILiftCache.best(asset, in: bundle)))")
        }
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let srgb = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try FileManager.default.createDirectory(at: root.appending(path: "out"), withIntermediateDirectories: true)
        for frame in job.frames {
            let image = try #require(context.createCGImage(
                MotionFrameRenderer.image(at: frame.time, plan: plan), from: CGRect(origin: .zero, size: plan.outputSize), format: .RGBA8, colorSpace: srgb
            ))
            try await ScreenshotService.writePNG(image, to: root.appending(path: "out/\(frame.name).png"))
        }
        print("LAB DONE")
    }

    /// The whole film from `lab/film-engine/document.json`: captured from the web and exported as the app does.
    @Test func film() async throws {
        let root = URL(filePath: Self.scratch + "/lab/film-engine")
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(contentsOf: root.appending(path: "document.json")))
        try document.validate()
        let bundle = root.appending(path: "Film.motion")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try Data(contentsOf: root.appending(path: "document.json")).write(to: MotionStore.documentURL(in: bundle))
        var settings = ExportSettings()
        settings.resolution = 1080
        settings.frameRate = 30
        if ProcessInfo.processInfo.environment["LAB_STILLS"] != nil {
            // Frames as the renderer draws them, before the encoder
            let plan = try await UICapture.plan(for: document, bundle: bundle, shorterSide: 1080, frameRate: 30)
            let context = CIContext(options: [.workingColorSpace: NSNull()])
            let srgb = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            for time in [0.5, 2.0, 4.5, 5.5, 10.6, 13.6] {
                let image = try #require(context.createCGImage(MotionFrameRenderer.image(at: time, plan: plan), from: CGRect(origin: .zero, size: plan.outputSize), format: .RGBA8, colorSpace: srgb))
                try await ScreenshotService.writePNG(image, to: root.appending(path: "still-\(time).png"))
            }
            print("LAB FILM stills")
            return
        }
        let clock = ContinuousClock.now
        let url = try await MotionExporter.export(document, bundle: bundle, settings: settings) { _ in }
        print("LAB FILM exported \(url.path()) in \(ContinuousClock.now - clock)")
    }

    /// The editor's preview of the film bundle: every frame drawn as its compositor draws it, timed per scene.
    @Test func preview() async throws {
        let bundle = URL(filePath: NSHomeDirectory() + "/Movies/Reco/Supabase Docs Film.motion")
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(contentsOf: MotionStore.documentURL(in: bundle)))
        var plan = try await UICapture.plan(for: document, bundle: bundle, shorterSide: 1080)
        plan.isPreview = true
        let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 1920, 1080, kCVPixelFormatType_32BGRA, [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        let output = try #require(buffer)
        var times: [String: [Double]] = [:]
        for frame in 0..<Int(plan.duration * 30) {
            let time = Double(frame) / 30
            let clock = ContinuousClock.now
            try MotionFrameRenderer.draw(at: time, plan: plan, into: output, context: context)
            let elapsed = ContinuousClock.now - clock
            let scene = plan.scenes[plan.sceneIndex(at: time)]
            times[scene.field == .plain ? "closing" : "satin \(scene.fieldShot)", default: []].append(Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000)
        }
        for (name, list) in times.sorted(by: { $0.key < $1.key }) {
            let sorted = list.sorted()
            print("LAB PREVIEW \(name): \(list.count) frames, p50 \(sorted[sorted.count / 2]) ms, p95 \(sorted[sorted.count * 95 / 100]) ms, max \(sorted.last ?? 0) ms")
        }
    }

    /// Frames of two movies as AVFoundation decodes them (what QuickTime shows), for level checks.
    @Test func decode() async throws {
        let root = URL(filePath: Self.scratch + "/port/filmcmp")
        let movies = ["engine": URL(filePath: Self.scratch + "/lab/film-engine/Film-edited.mp4"),
                      "film": URL(filePath: NSHomeDirectory() + "/Movies/Reco/quality/L1/supabase-docs-film.mp4")]
        for (name, url) in movies {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            (generator.requestedTimeToleranceBefore, generator.requestedTimeToleranceAfter) = (.zero, .zero)
            for time in [0.5, 2.0, 4.5, 10.6] {
                let (image, _) = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600))
                try await ScreenshotService.writePNG(image, to: root.appending(path: "av-\(name)-\(time).png"))
            }
        }
        print("LAB DONE")
    }

    private static func write(_ image: NSImage, to url: URL) async throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw WebRenderError.snapshotFailed }
        try await ScreenshotService.writePNG(cgImage, to: url)
        print("LAB WROTE \(url.lastPathComponent) \(cgImage.width)x\(cgImage.height)")
    }
}
