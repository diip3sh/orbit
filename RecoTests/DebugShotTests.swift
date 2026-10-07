//
//  DebugShotTests.swift
//  RecoTests
//
//  Temporary: renders the look tests of spec 0012's direction (L0–L3). Delete before committing.
//

import AppKit
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
            let arguments: [String: Any] = ["selector": selector, "fill": fill]
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

    private static func write(_ image: NSImage, to url: URL) async throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw WebRenderError.snapshotFailed }
        try await ScreenshotService.writePNG(cgImage, to: url)
        print("LAB WROTE \(url.lastPathComponent) \(cgImage.width)x\(cgImage.height)")
    }
}
