//
//  WebPageRenderer.swift
//  BetterCapture
//

import AppKit
import OSLog
import WebKit

/// Renders a ``WebScript`` into a movie and its telemetry, one frame at a time, in a web view off
/// every display (spec 0005).
///
/// Each frame steps the page's clock by exactly one frame (``WebClockScript``), so the movie plays
/// at full frame rate however long a frame takes to draw. One renderer renders one take.
@MainActor
final class WebPageRenderer: NSObject {

    private let script: WebScript
    private let window: OffscreenWebWindow
    private let webView: WKWebView

    /// The first load's outcome, awaited by ``load(_:)``.
    private var loading: CheckedContinuation<Void, any Error>?

    /// Whether the page's web content process quit, e.g. out of memory.
    private var hasCrashed = false

    /// The frame call in flight, which a new page ends: WebKit fails a call into a page that went
    /// away only once it's garbage collected, 106 s after a click opened the Apple Store.
    private var frameCall: (id: Int, continuation: CheckedContinuation<[String: CGRect]?, Never>)?
    private var frameCallCount = 0

    /// How long a page runs in real time once loaded, before the take freezes its clock.
    static let settleTime = Duration.seconds(1)

    static let loadTimeout = Duration.seconds(60)

    /// How often a frame may find the page gone, e.g. navigating after a click, before the take fails.
    private static let maximumReloads = 5

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "WebPageRenderer")

    init(script: WebScript) {
        self.script = script
        let configuration = WKWebViewConfiguration()
        for source in [WebClockScript.source, WebMuteScript.source] {
            configuration.userContentController.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        // Media plays as it would for a visitor who clicked, silenced by the mute script
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // The preview's store: cookies set there, like a dismissed banner's, apply to the take too
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: CGRect(origin: .zero, size: script.viewport), configuration: configuration)
        window = OffscreenWebWindow(size: script.viewport)
        window.contentView = webView
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    /// Renders the take into a movie at `url`, reporting progress from 0 to 1, and returns its
    /// telemetry. Cancelling the task stops it; the caller removes the partial movie.
    func render(to url: URL, bitsPerPixel: Double, progress: (Double) -> Void) async throws -> InputTelemetry {
        guard let pageURL = script.url else { throw WebRenderError.noURL }
        // Ordered in, off every display, so WebKit sees a visible window
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        try await load(pageURL)
        try await Task.sleep(for: Self.settleTime)

        let writer = try WebMovieWriter(url: url, size: script.videoSize, frameRate: WebScript.frameRate, bitsPerPixel: bitsPerPixel)
        var take = WebTakeTelemetry(script: script)
        var pointer = PointerTrack(script: script)
        do {
            var location: CGPoint?
            var scroll: CGPoint?
            var page: URL?
            var previousTime = -Double.infinity
            for frame in 0..<script.frameCount {
                try Task.checkCancellation()
                let time = Double(frame) / Double(WebScript.frameRate)
                let newScroll = script.scrollOffset(at: time)

                let elementFrames = try await advance(to: time, scroll: newScroll, selectors: pointer.selectors(at: time))
                let newLocation = pointer.location(at: time, elementFrames: elementFrames)
                // WebKit hit-tests only on a move, and a window that's never active gets none of its
                // own when the page scrolls or changes under the pointer
                if let newLocation, newLocation != location || newScroll != scroll || webView.url != page {
                    webView.sendPointer(.move, at: newLocation)
                }
                location = newLocation
                scroll = newScroll
                page = webView.url
                let presses = script.presses(after: previousTime, through: time)
                if let location {
                    for press in presses {
                        webView.sendPointer(press.isDown ? .press : .release, at: location)
                    }
                }
                let cursor = await hold(at: location)

                try await writer.append(try await snapshot(), frame: frame)
                take.record(time: time, cursor: location, presses: presses, shape: CursorKind(css: cursor))
                previousTime = time
                progress(Double(frame + 1) / Double(script.frameCount))
            }
            try await writer.finish(frameCount: script.frameCount)
        } catch {
            await writer.cancel()
            throw error
        }
        return take.finished { StandardCursors.sprite(of: $0, id: $1) }
    }

    // MARK: - Page

    /// Loads `url`, until the page has finished loading or failed.
    private func load(_ url: URL) async throws {
        let timeout = Task { [weak self] in
            try await Task.sleep(for: Self.loadTimeout)
            self?.finishLoading(.failure(WebRenderError.loadTimedOut))
        }
        defer { timeout.cancel() }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                loading = continuation
                webView.load(URLRequest(url: url))
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finishLoading(.failure(CancellationError()))
            }
        }
    }

    private func finishLoading(_ result: Result<Void, any Error>) {
        loading?.resume(with: result)
        loading = nil
    }

    /// Steps the page's clock to the take's `time`, scrolls it to `scroll`, and returns the frames
    /// of the elements `selectors` match, by selector.
    ///
    /// When a click opened another page, the frame waits for it to load and settle, off the clock:
    /// the movie cuts straight to the new page.
    private func advance(to time: Double, scroll: CGPoint, selectors: [String]) async throws -> [String: CGRect] {
        var reloads = 0
        while true {
            // Not into a page that's being replaced: the call could outlive it
            if !webView.isLoading, let boxes = await callFrame(time: time, scroll: scroll, selectors: selectors) {
                return boxes
            }
            guard !hasCrashed else { throw WebRenderError.pageCrashed }
            reloads += 1
            guard reloads <= Self.maximumReloads else { throw WebRenderError.loadFailed("The page kept reloading.") }
            try await waitWhileLoading()
            try await Task.sleep(for: Self.settleTime)
        }
    }

    /// Runs the clock script's frame step, returning the boxes, or `nil` when the page isn't ready
    /// or is replaced meanwhile.
    private func callFrame(time: Double, scroll: CGPoint, selectors: [String]) async -> [String: CGRect]? {
        frameCallCount += 1
        let id = frameCallCount
        return await withCheckedContinuation { continuation in
            frameCall = (id, continuation)
            Task {
                var boxes: [String: CGRect]?
                do {
                    let result = try await webView.callAsyncJavaScript(
                        "return await window.__betterCapture.frame(time, x, y, selectors)",
                        arguments: ["time": time, "x": scroll.x, "y": scroll.y, "selectors": selectors],
                        contentWorld: .page
                    )
                    boxes = (result as? [String: Any])?.compactMapValues { value in
                        guard let box = value as? [Double], box.count == 4 else { return nil }
                        return CGRect(x: box[0], y: box[1], width: box[2], height: box[3])
                    }
                } catch {
                    logger.info("Frame at \(time) s found the page gone: \(error.localizedDescription)")
                }
                finishFrameCall(id, boxes: boxes)
            }
        }
    }

    /// Ends frame call `id`, or whichever is in flight when `nil`.
    private func finishFrameCall(_ id: Int? = nil, boxes: [String: CGRect]? = nil) {
        guard let frameCall, id == nil || id == frameCall.id else { return }
        self.frameCall = nil
        frameCall.continuation.resume(returning: boxes)
    }

    private func waitWhileLoading() async throws {
        let deadline = ContinuousClock.now + Self.loadTimeout
        while webView.isLoading {
            guard ContinuousClock.now < deadline else { throw WebRenderError.loadTimedOut }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Seeks the animations the pointer just started to the current frame, and returns the CSS
    /// cursor at `location`. `default` when the page can't say, e.g. while a click navigates.
    private func hold(at location: CGPoint?) async -> String {
        let result = try? await webView.callAsyncJavaScript(
            "return window.__betterCapture.hold(x, y)",
            arguments: ["x": location.map { $0.x as Any } ?? NSNull(), "y": location.map { $0.y as Any } ?? NSNull()],
            contentWorld: .page
        )
        return result as? String ?? "default"
    }

    /// The page drawn at the take's scale. WebKit paints it for the requested width, so a 2× take
    /// is sharp on any display.
    private func snapshot() async throws -> CGImage {
        let configuration = WKSnapshotConfiguration()
        configuration.snapshotWidth = NSNumber(value: script.viewport.width * CGFloat(script.scale) / window.backingScaleFactor)
        let image = try await webView.takeSnapshot(configuration: configuration)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw WebRenderError.snapshotFailed
        }
        return cgImage
    }
}

// MARK: - WKNavigationDelegate

extension WebPageRenderer: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishLoading(.success(()))
    }

    /// The page before is gone, and with it any frame call into it.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        finishFrameCall()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        failLoading(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        failLoading(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        hasCrashed = true
        finishLoading(.failure(WebRenderError.pageCrashed))
        finishFrameCall()
    }

    /// A load the page cancelled, e.g. by redirecting while loading, is replaced by another.
    private func failLoading(_ error: any Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        finishLoading(.failure(WebRenderError.loadFailed(error.localizedDescription)))
    }
}

// MARK: - WKUIDelegate

extension WebPageRenderer: WKUIDelegate {

    /// A link that opens a new window opens in the take's instead.
    func webView(
        _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        webView.load(navigationAction.request)
        return nil
    }
}
