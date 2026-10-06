//
//  WebPageRenderer.swift
//  Reco
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
    private var frameCall: (id: Int, continuation: CheckedContinuation<PageFrame?, Never>)?
    private var frameCallCount = 0

    /// How long a page runs in real time once loaded, before the take freezes its clock.
    static let settleTime = Duration.seconds(1)

    static let loadTimeout = Duration.seconds(60)

    /// How often a frame may find the page gone, e.g. navigating after a click, before the take fails.
    private static let maximumReloads = 5

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "WebPageRenderer")

    init(script: WebScript) {
        self.script = script
        let configuration = WKWebViewConfiguration()
        for source in [WebClockScript.source, WebMuteScript.source] + [script.hide.map(WebHideScript.source(hiding:))].compactMap({ $0 }) {
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
    /// telemetry, the zooms its script asked for (``WebTakeZooms``) and what went wrong on the page
    /// (``WebTakeIssues``). Cancelling the task stops it; the caller removes the partial movie.
    ///
    /// With `crop`, a box of the viewport in whole CSS pixels, only that box is drawn and written: a
    /// motion document's live layer (spec 0011). The telemetry stays the viewport's.
    func render(to url: URL, crop: CGRect? = nil, bitsPerPixel: Double, progress: (Double) -> Void) async throws -> Rendered {
        guard let pageURL = script.url else { throw WebRenderError.noURL }
        // Ordered in, off every display, so WebKit sees a visible window
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        try await load(pageURL)
        try await Task.sleep(for: Self.settleTime)

        let size = crop.map { CGSize(width: $0.width * CGFloat(script.scale), height: $0.height * CGFloat(script.scale)) } ?? script.videoSize
        let writer = try WebMovieWriter(url: url, size: size, frameRate: WebScript.frameRate, bitsPerPixel: bitsPerPixel)
        var take = Take(script: script)
        do {
            for frame in 0..<script.frameCount {
                try Task.checkCancellation()
                try await play(Double(frame) / Double(WebScript.frameRate), of: &take)
                try await writer.append(try await snapshot(of: crop), frame: frame)
                progress(Double(frame + 1) / Double(script.frameCount))
            }
            try await writer.finish(frameCount: script.frameCount)
        } catch {
            await writer.cancel()
            throw error
        }
        let telemetry = take.telemetry.finished { StandardCursors.sprite(of: $0, id: $1) }
        // A zoom on an element ends as the page scrolls or is replaced under it, as a held rest's does
        let scrolls = take.script.scrolls.map(\.range.lowerBound) + telemetry.navigations.map(\.time)
        return Rendered(telemetry: telemetry, zooms: take.zooms.segments(endingAt: scrolls), issues: take.issues.messages)
    }

    /// What a take leaves besides its movie.
    nonisolated struct Rendered: Sendable {
        var telemetry: InputTelemetry
        var zooms: [ZoomSegment]
        var issues: [String]
    }

    /// What a take keeps from one frame to the next.
    private struct Take {

        /// The script, its scrolls to an element aimed again as they start, at the page as it is then.
        var script: WebScript
        var aimed = Set<UUID>()
        var pointer: PointerTrack
        var telemetry: WebTakeTelemetry
        var zooms: WebTakeZooms
        var issues: WebTakeIssues

        /// Where the pointer and the page were in the last frame.
        var location: CGPoint?
        var scroll: CGPoint?
        var page: URL?
        var time = -Double.infinity

        init(script: WebScript) {
            self.script = script
            pointer = PointerTrack(script: script)
            telemetry = WebTakeTelemetry(script: script)
            zooms = WebTakeZooms(viewport: script.viewport)
            issues = WebTakeIssues(viewport: script.viewport)
        }
    }

    /// Plays the take's frame at `time` on the page: steps its clock, scrolls it, moves and presses
    /// the pointer, and records what happened.
    private func play(_ time: Double, of take: inout Take) async throws {
        let scroll = take.script.scrollOffset(at: time)
        let aiming = take.script.scrolls.filter { $0.target != nil && !take.aimed.contains($0.id) && $0.range.lowerBound <= time }
        // The cursor clip starting this frame: its target is checked and its shown element measured
        let arriving = script.pointer.first {
            $0.range.lowerBound > take.time + WebScript.pressTolerance && $0.range.lowerBound <= time + WebScript.pressTolerance
        }
        let selectors = take.pointer.selectors(at: time) + aiming.compactMap(\.target?.selector) + [arriving?.show].compactMap { $0 }
        let page = try await advance(to: time, scroll: scroll, selectors: selectors)
        for clip in aiming {
            take.aimed.insert(clip.id)
            aim(clip, in: &take, at: page, scrolledTo: scroll)
        }

        let location = take.pointer.location(at: time, elementFrames: page.boxes)
        // WebKit hit-tests only on a move, and a window that's never active gets none of its own when
        // the page scrolls or changes under the pointer
        if let location, location != take.location || scroll != take.scroll || webView.url != take.page {
            webView.sendPointer(.move, at: location)
        }
        let scrolled = take.scroll.map { CGVector(dx: $0.x - scroll.x, dy: $0.y - scroll.y) }
        // The page after the first that replaced the last frame's; the first is the one asked for
        let opened = take.page != nil && Self.isAnotherPage(webView.url, than: take.page) ? webView.url : nil
        (take.location, take.scroll, take.page) = (location, scroll, webView.url)
        // A page a click opened shows from its top: where the script had scrolled belongs to the page before
        if opened != nil, let index = take.script.scrolls.lastIndex(where: { $0.range.lowerBound <= time }) {
            take.script.scrolls[index].offset = .zero
        }
        // Not on a target the page doesn't have now: the press would land on whatever is there
        let presses = script.presses(after: take.time, through: time).filter { press in
            guard let selector = press.target.selector, page.boxes[selector] == nil else { return true }
            take.issues.skippedClick(selector, at: time)
            return false
        }
        if let location {
            for press in presses {
                webView.sendPointer(press.isDown ? .press : .release, at: location)
            }
        }
        // After the press, which put the caret in the field. Not into a field the page doesn't have now
        var typed: [Character] = []
        for key in script.keystrokes(after: take.time, through: time) {
            guard let selector = key.target.selector, page.boxes[selector] != nil, await type(key.character, into: selector) else { continue }
            typed.append(key.character)
        }
        // Checked where each cursor clip starts, as Playwright checks an action's target
        let (cursor, cover) = await hold(at: location, aimingAt: arriving?.target.selector)
        if let selector = arriving?.target.selector {
            take.issues.check(selector, at: time, frame: page.boxes[selector], cover: cover)
        }
        if let arriving {
            show(arriving, at: page, in: &take, time: time)
        }
        take.telemetry.record(
            time: time, cursor: location, presses: presses, shape: CursorKind(css: cursor), scrolled: scrolled, typed: typed, opened: opened
        )
        take.time = time
    }

    /// Frames the element `clip` shows, where `page` has it as the clip starts at `time`.
    private func show(_ clip: PointerClip, at page: PageFrame, in take: inout Take, time: Double) {
        guard let show = clip.show else { return }
        if let frame = page.boxes[show], WebTakeZooms.canFrame(frame, in: script.viewport) {
            take.zooms.show(frame, during: clip.range)
        } else {
            take.issues.notShown(show, at: time)
        }
    }

    /// Whether `url` is another page than `page`, not another place on it: a link to an anchor
    /// changes the fragment, and the page scrolls there without being replaced.
    private static func isAnotherPage(_ url: URL?, than page: URL?) -> Bool {
        func withoutFragment(_ url: URL?) -> URL? {
            guard let url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
            components.fragment = nil
            return components.url
        }
        return withoutFragment(url) != withoutFragment(page)
    }

    /// Aims `clip` at its element where `page`, scrolled to `scroll`, shows it now.
    private func aim(_ clip: ScrollClip, in take: inout Take, at page: PageFrame, scrolledTo scroll: CGPoint) {
        guard let target = clip.target, let index = take.script.scrolls.firstIndex(where: { $0.id == clip.id }) else { return }
        let start = take.script.scrollOffset(at: clip.range.lowerBound)
        guard let frame = page.boxes[target.selector] else {
            // A scroll Reco added before a cursor clip is that clip's check to report
            if target.placement == .top {
                take.issues.notFound(target.selector, at: clip.range.lowerBound)
            }
            // Nowhere, rather than to where it was planned on a page that may be another
            take.script.scrolls[index].offset = start
            return
        }
        let shown = frame.offsetBy(dx: scroll.x - start.x, dy: scroll.y - start.y)
        take.script.scrolls[index].offset = target.offset(showing: shown, from: start, viewport: script.viewport, pageHeight: page.pageHeight)
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

    /// The boxes of the elements a frame asked for, by selector, in viewport CSS pixels, and the
    /// page's height.
    private typealias PageFrame = (boxes: [String: CGRect], pageHeight: Double)

    /// Steps the page's clock to the take's `time`, scrolls it to `scroll`, and returns the frames
    /// of the elements `selectors` match.
    ///
    /// When a click opened another page, the frame waits for it to load and settle, off the clock:
    /// the movie cuts straight to the new page.
    private func advance(to time: Double, scroll: CGPoint, selectors: [String]) async throws -> PageFrame {
        var reloads = 0
        while true {
            // Not into a page that's being replaced: the call could outlive it
            if !webView.isLoading, let frame = await callFrame(time: time, scroll: scroll, selectors: selectors) {
                return frame
            }
            guard !hasCrashed else { throw WebRenderError.pageCrashed }
            reloads += 1
            guard reloads <= Self.maximumReloads else { throw WebRenderError.loadFailed("The page kept reloading.") }
            try await waitWhileLoading()
            try await Task.sleep(for: Self.settleTime)
        }
    }

    /// Runs the clock script's frame step, or returns `nil` when the page isn't ready or is
    /// replaced meanwhile.
    private func callFrame(time: Double, scroll: CGPoint, selectors: [String]) async -> PageFrame? {
        frameCallCount += 1
        let id = frameCallCount
        return await withCheckedContinuation { continuation in
            frameCall = (id, continuation)
            Task {
                var frame: PageFrame?
                do {
                    let result = try await webView.callAsyncJavaScript(
                        "return await window.__reco.frame(time, x, y, selectors)",
                        arguments: ["time": time, "x": scroll.x, "y": scroll.y, "selectors": selectors],
                        contentWorld: .page
                    )
                    if let result = result as? [String: Any], let boxes = result["boxes"] as? [String: Any] {
                        let frames = boxes.compactMapValues { value -> CGRect? in
                            guard let box = value as? [Double], box.count == 4 else { return nil }
                            return CGRect(x: box[0], y: box[1], width: box[2], height: box[3])
                        }
                        frame = (frames, result["height"] as? Double ?? 0)
                    }
                } catch {
                    logger.info("Frame at \(time) s found the page gone: \(error.localizedDescription)")
                }
                finishFrameCall(id, frame: frame)
            }
        }
    }

    /// Ends frame call `id`, or whichever is in flight when `nil`.
    private func finishFrameCall(_ id: Int? = nil, frame: PageFrame? = nil) {
        guard let frameCall, id == nil || id == frameCall.id else { return }
        self.frameCall = nil
        frameCall.continuation.resume(returning: frame)
    }

    private func waitWhileLoading() async throws {
        let deadline = ContinuousClock.now + Self.loadTimeout
        while webView.isLoading {
            guard ContinuousClock.now < deadline else { throw WebRenderError.loadTimedOut }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Seeks the animations the pointer just started to the current frame, and returns the CSS
    /// cursor at `location`, `default` when the page can't say, e.g. while a click navigates. Given
    /// the `selector` the cursor aims at, also what covers its element there, if anything does.
    private func hold(at location: CGPoint?, aimingAt selector: String?) async -> (cursor: String, cover: String?) {
        let result = try? await webView.callAsyncJavaScript(
            "return window.__reco.hold(x, y, selector)",
            arguments: [
                "x": location.map { $0.x as Any } ?? NSNull(),
                "y": location.map { $0.y as Any } ?? NSNull(),
                "selector": selector.map { $0 as Any } ?? NSNull()
            ],
            contentWorld: .page
        )
        let values = result as? [String: Any]
        return (values?["cursor"] as? String ?? "default", values?["cover"] as? String)
    }

    /// Types `character` into the element `selector` matches. False when the page has none, or is
    /// being replaced.
    private func type(_ character: Character, into selector: String) async -> Bool {
        let result = try? await webView.callAsyncJavaScript(
            WebTypeScript.source, arguments: ["selector": selector, "text": String(character)], contentWorld: .defaultClient
        )
        return result as? Bool == true
    }

    /// The page, or its box `rect`, drawn at the take's scale. WebKit paints it for the requested
    /// width, so a 2× take is sharp on any display.
    private func snapshot(of rect: CGRect? = nil, scale: Int? = nil) async throws -> CGImage {
        let configuration = WKSnapshotConfiguration()
        if let rect {
            configuration.rect = rect
        }
        configuration.snapshotWidth = NSNumber(value: (rect?.width ?? script.viewport.width) * CGFloat(scale ?? script.scale) / window.backingScaleFactor)
        let image = try await webView.takeSnapshot(configuration: configuration)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw WebRenderError.snapshotFailed
        }
        return cgImage
    }
}

// MARK: - Inspecting

extension WebPageRenderer {

    /// Loads the script's page and lists what it shows at scroll 0: see ``WebInspectScript``.
    /// `selectors` are the ones to also return the box of.
    func inspect(selectors: [String]) async throws -> PageInspection {
        // Settled in real time, as in a take: the page's own scripts finish drawing before it's read
        try await withLoadedPage { webView in
            let result = try await webView.callAsyncJavaScript(
                WebInspectScript.source, arguments: ["selectors": selectors], contentWorld: .defaultClient
            )
            guard let json = result as? String else { throw WebRenderError.loadFailed("The page couldn't be read.") }
            var inspection = try JSONDecoder().decode(PageInspection.self, from: Data(json.utf8))
            inspection.renderCost = try await renderCost()
            return inspection
        }
    }

    /// Seconds of rendering per second of video at scale 1 and 2, from one snapshot of the page at
    /// each: the snapshot is the cost of a frame, 14 ms on a simple page and 310 ms on linear.app at
    /// 2× (M5), the rest of a frame a few ms. Lets an agent choose a scale the run's time allows.
    private func renderCost() async throws -> [String: Double] {
        var cost: [String: Double] = [:]
        for scale in [1, 2] {
            let start = ContinuousClock.now
            _ = try await snapshot(scale: scale)
            let seconds = (ContinuousClock.now - start) / .seconds(1)
            cost[String(scale)] = (seconds * Double(WebScript.frameRate) * 100).rounded() / 100
        }
        return cost
    }
}

// MARK: - Loaded page

extension WebPageRenderer {

    /// Loads the script's page, lets it settle as a take does, and runs `body` on its web view while
    /// it's ordered in: what lifts UI for motion documents (``UICapture``).
    func withLoadedPage<T>(_ body: (WKWebView) async throws -> T) async throws -> T {
        guard let pageURL = script.url else { throw WebRenderError.noURL }
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        try await load(pageURL)
        try await Task.sleep(for: Self.settleTime)
        return try await body(webView)
    }
}

// MARK: - WKNavigationDelegate

extension WebPageRenderer: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // A refused connection commits a blank page instead of failing (measured on macOS 26.5)
        guard webView.url?.scheme != "about" else {
            return finishLoading(.failure(WebRenderError.loadFailed("nothing answered at that address.")))
        }
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
