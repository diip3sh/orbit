//
//  UICapture.swift
//  Reco
//

import AppKit
import OSLog
import WebKit

/// Captures UI off web pages into a motion bundle (spec 0011, phase 2): a still asset's element
/// snapshotted alone, with real alpha around it, at the scale its plan shows it; a live asset's take
/// baked into a movie.
@MainActor
enum UICapture {

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "UICapture")

    /// Whether a capture is running: one at a time, since two 8× WebKit snapshots at once made the
    /// GPU process quit (phase 2), and a window's preview and an agent's tool can both ask.
    private static var isCapturing = false

    /// Builds the plan for `document`, lifting and baking what it needs first. Only a capture tells
    /// the plan an element's size, so a plan that captured asks again once: at most two rounds.
    static func plan(for document: MotionDocument, bundle: URL, shorterSide: CGFloat? = nil, frameRate: Int? = nil) async throws -> MotionPlan {
        var plan = await MotionPlan.build(document, bundle: bundle, shorterSide: shorterSide, frameRate: frameRate)
        for _ in 0..<2 where !plan.liftsNeeded.isEmpty || !plan.bakesNeeded.isEmpty {
            while isCapturing {
                try await Task.sleep(for: .milliseconds(100))
            }
            isCapturing = true
            defer { isCapturing = false }
            // What another capture took meanwhile isn't taken again
            plan = await MotionPlan.build(document, bundle: bundle, shorterSide: shorterSide, frameRate: frameRate)
            for asset in document.assets {
                if let scale = plan.bakesNeeded[asset.id] {
                    try await bake(asset, at: scale, into: bundle)
                }
            }
            if !plan.liftsNeeded.isEmpty {
                try await lift(plan.liftsNeeded, of: document, into: bundle)
            }
            plan = await MotionPlan.build(document, bundle: bundle, shorterSide: shorterSide, frameRate: frameRate)
        }
        return plan
    }

    /// Bakes `asset`'s live take into the bundle at `scale` video pixels per CSS pixel: the page
    /// looked at as `record_page` does, the steps aimed at it, and the take rendered frame by frame,
    /// only the element's box where the page first shows it, with its matte. At scale 0 it only
    /// measures the box, so the plan can say how large the take is shown. Nothing for a still.
    static func bake(_ asset: MotionAsset, at scale: Int, into bundle: URL) async throws {
        guard var plan = try asset.takePlan() else { return }
        let start = ContinuousClock.now
        let page = try await WebPageRenderer(script: plan.inspectionScript).inspect(selectors: plan.selectors + [asset.selector])
        guard let box = page.boxes?[asset.selector] else { throw UICaptureError.notFound(asset.id, asset.selector) }
        // Whole CSS pixels, so the movie's size is whole and even
        let crop = box.rect.integral
        guard CGRect(origin: .zero, size: asset.viewport).contains(crop) else { throw UICaptureError.outOfView(asset.id, asset.selector) }
        var info = UILiftCache.TakeInfo(crop: crop, radius: box.radius ?? 0, scale: 0, duration: plan.duration)
        guard scale > 0 else {
            try FileManager.default.createDirectory(at: UILiftCache.infoURL(of: asset, in: bundle).deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(info).write(to: UILiftCache.infoURL(of: asset, in: bundle), options: .atomic)
            return
        }
        plan.scale = scale
        let script = try plan.script(page: page).script

        let movie = UILiftCache.movieURL(of: asset, in: bundle)
        try FileManager.default.createDirectory(at: movie.deletingLastPathComponent(), withIntermediateDirectories: true)
        let partial = movie.deletingLastPathComponent().appending(path: "\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: partial) }
        let rendered = try await WebPageRenderer(script: script).render(to: partial, crop: crop, bitsPerPixel: VideoQuality.high.hevcBitsPerPixel) { _ in }
        try JSONEncoder().encode(rendered.telemetry).write(to: InputTelemetry.sidecarURL(for: movie), options: .atomic)

        // The element's painted shape, which the take's box is cut to: a radius can't describe a pill
        // in a square wrapper, or a panel with a row of chips under it
        var still = WebScript()
        (still.url, still.viewport, still.hide) = (asset.url, asset.viewport, asset.hide)
        let matte = try await WebPageRenderer(script: still).withLoadedPage { webView in
            webView.setValue(false, forKey: "drawsBackground")
            return try await lift(asset, at: script.scale, from: webView, filled: false)
        }
        try await ScreenshotService.writePNG(matte, to: UILiftCache.matteURL(of: asset, in: bundle))
        try? FileManager.default.removeItem(at: movie)
        try FileManager.default.moveItem(at: partial, to: movie)
        // Last: a take is whole once its info has a scale
        info.scale = scale
        try JSONEncoder().encode(info).write(to: UILiftCache.infoURL(of: asset, in: bundle), options: .atomic)
        for issue in rendered.issues {
            logger.warning("\(asset.id, privacy: .public): \(issue, privacy: .public)")
        }
        logger.info("Baked \(asset.id, privacy: .public): \(script.duration) s of \(Int(crop.width))x\(Int(crop.height)) CSS px at \(scale)x in \(ContinuousClock.now - start)")
    }

    /// Lifts each still in `scales` (image pixels per CSS pixel, by asset id), loading each page once.
    static func lift(_ scales: [String: Int], of document: MotionDocument, into bundle: URL) async throws {
        let assets = document.assets.filter { scales[$0.id] != nil }
        let pages = Dictionary(grouping: assets) {
            "\($0.url.absoluteString) \(Int($0.viewport.width))x\(Int($0.viewport.height)) \(($0.hide ?? []).joined(separator: ","))"
        }
        try FileManager.default.createDirectory(at: bundle.appending(path: "assets/lifts"), withIntermediateDirectories: true)
        for key in pages.keys.sorted() {
            guard let page = pages[key], let first = page.first else { continue }
            var script = WebScript()
            script.url = first.url
            script.viewport = first.viewport
            script.hide = first.hide
            try await WebPageRenderer(script: script).withLoadedPage { webView in
                // The page draws no background of its own, so what the isolating style hides is transparent
                webView.setValue(false, forKey: "drawsBackground")
                for asset in page {
                    let scale = scales[asset.id] ?? 2
                    let start = ContinuousClock.now
                    let image = try await lift(asset, at: scale, from: webView)
                    let url = UILiftCache.url(of: asset, scale: scale, in: bundle)
                    let partial = url.appendingPathExtension("partial")
                    try await ScreenshotService.writePNG(image, to: partial)
                    // Whole or not at all: a lift's header alone would pass for one
                    try? FileManager.default.removeItem(at: url)
                    try FileManager.default.moveItem(at: partial, to: url)
                    logger.info("Lifted \(asset.id, privacy: .public) at \(scale)x: \(image.width)x\(image.height) px in \(ContinuousClock.now - start)")
                }
            }
        }
    }

    /// The element `asset` names, alone on a transparent page, `scale` image pixels per CSS pixel;
    /// unless `filled`, without the background behind a transparent element.
    private static func lift(_ asset: MotionAsset, at scale: Int, from webView: WKWebView, filled: Bool = true) async throws -> CGImage {
        var placed = try await place(asset, in: webView)
        // Taller than the view: the view grows to hold it (a page laid out in viewport heights grows with it)
        if placed.box.height > asset.viewport.height, let window = webView.window {
            window.setContentSize(CGSize(width: asset.viewport.width, height: placed.box.height.rounded(.up)))
            placed = try await place(asset, in: webView)
        }
        defer { webView.window?.setContentSize(asset.viewport) }
        let bounds = CGRect(origin: .zero, size: webView.bounds.size)
        guard bounds.insetBy(dx: -1, dy: -1).contains(placed.box), placed.box.width >= 1, placed.box.height >= 1 else {
            throw UICaptureError.outOfView(asset.id, asset.selector)
        }

        let arguments: [String: Any] = ["selector": asset.selector, "fill": filled ? placed.fill : NSNull()]
        _ = try await webView.callAsyncJavaScript(UILiftScript.isolate, arguments: arguments.merging(["on": true]) { $1 }, contentWorld: .defaultClient)
        let configuration = WKSnapshotConfiguration()
        configuration.rect = placed.box.intersection(bounds)
        configuration.snapshotWidth = NSNumber(value: configuration.rect.width * CGFloat(scale) / (webView.window?.backingScaleFactor ?? 1))
        let snapshot: Result<NSImage, any Error>
        do {
            snapshot = .success(try await webView.takeSnapshot(configuration: configuration))
        } catch {
            snapshot = .failure(error)
        }
        // The page as it was, for the next asset
        _ = try await webView.callAsyncJavaScript(UILiftScript.isolate, arguments: arguments.merging(["on": false]) { $1 }, contentWorld: .defaultClient)
        guard let image = try snapshot.get().cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw WebRenderError.snapshotFailed
        }
        return image
    }

    private static func place(_ asset: MotionAsset, in webView: WKWebView) async throws -> (box: CGRect, fill: String) {
        let result = try await webView.callAsyncJavaScript(UILiftScript.place, arguments: ["selector": asset.selector], contentWorld: .defaultClient)
        guard let result = result as? [String: Any], let box = result["box"] as? [Double], box.count == 4 else {
            throw UICaptureError.notFound(asset.id, asset.selector)
        }
        return (CGRect(x: box[0], y: box[1], width: box[2], height: box[3]), result["fill"] as? String ?? "transparent")
    }
}
