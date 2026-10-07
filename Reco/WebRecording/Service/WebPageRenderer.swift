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

    /// What a render finds besides the movie.
    struct Output {
        var telemetry: InputTelemetry

        /// Where the elements the script's show clips zoom on were.
        var shots: [WebCamera.Shot]

        /// What went wrong on the page, for the agent that wrote the script (``WebTakeIssues``).
        var warnings: [String]
    }

    /// Renders the take into a movie at `url`, reporting progress from 0 to 1. Cancelling the task
    /// stops it; the caller removes the partial movie.
    func render(to url: URL, bitsPerPixel: Double, progress: (Double) -> Void) async throws -> Output {
        guard let pageURL = script.url else { throw WebRenderError.noURL }
        // Ordered in, off every display, so WebKit sees a visible window
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        try await load(pageURL)
        try await Task.sleep(for: Self.settleTime)

        let writer = try WebMovieWriter(url: url, size: script.videoSize, frameRate: WebScript.frameRate, bitsPerPixel: bitsPerPixel)
        var take = Take(script: script, page: webView.url)
        do {
            for frame in 0..<script.frameCount {
                try Task.checkCancellation()
                try await play(Double(frame) / Double(WebScript.frameRate), of: &take)
                try await writer.append(try await snapshot(), frame: frame)
                progress(Double(frame + 1) / Double(script.frameCount))
            }
            try await writer.finish(frameCount: script.frameCount)
        } catch {
            await writer.cancel()
            throw error
        }
        return Output(telemetry: take.telemetry.finished { StandardCursors.sprite(of: $0, id: $1) }, shots: take.shots, warnings: take.issues.messages)
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

    /// Runs the clock script's frame step, or returns `nil` when the page isn't ready or is replaced
    /// meanwhile.
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

// MARK: - Playing

extension WebPageRenderer {

    /// What a take keeps from one frame to the next.
    private struct Take {

        /// The script, with each scroll aimed as it starts at the page as it is then, and the scrolls of
        /// a page another replaced dropped.
        var script: WebScript
        var aimed = Set<UUID>()
        var pointer: PointerTrack
        var telemetry: WebTakeTelemetry
        var issues: WebTakeIssues
        var shots: [WebCamera.Shot] = []

        /// The page shown, without its fragment: a link to an anchor on it doesn't open another.
        var page: URL?

        /// Where the pointer and the page were in the last frame, and when it was.
        var location: CGPoint?
        var scroll: CGPoint?
        var time = -Double.infinity

        /// Whether the button is down: a press whose element was missing is left out with its release.
        var isPressed = false

        /// What each type clip's field was last given, so the page hears only new letters.
        var typed: [UUID: String] = [:]

        init(script: WebScript, page: URL?) {
            self.script = script
            pointer = PointerTrack(script: script)
            telemetry = WebTakeTelemetry(script: script)
            issues = WebTakeIssues(viewport: script.viewport)
            self.page = page.map(Self.withoutFragment)
        }

        static func withoutFragment(_ url: URL) -> URL {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.fragment = nil
            return components?.url ?? url
        }

        /// Whether `url` is another page than the one shown.
        func isNew(_ url: URL?) -> Bool {
            url.map(Self.withoutFragment).map { $0 != page } ?? false
        }

        /// The page at `url` replaced the one shown at `time`. It shows from its top: the scrolls that
        /// started before belonged to the page it replaced.
        mutating func navigate(to url: URL, at time: Double) {
            page = Self.withoutFragment(url)
            telemetry.navigated(to: url, at: time)
            script.scrolls.removeAll { $0.range.lowerBound < time }
            scroll = nil
        }
    }

    /// Plays the take's frame at `time` on the page: steps its clock, scrolls it, moves and presses
    /// the pointer, types, and records what happened. Each cursor clip is checked where it starts.
    private func play(_ time: Double, of take: inout Take) async throws {
        let previous = take.time
        let arriving = take.script.pointer.first {
            $0.range.lowerBound > previous + WebScript.pressTolerance && $0.range.lowerBound <= time + WebScript.pressTolerance
        }
        var aiming: [ScrollClip] = []
        var frame: PageFrame
        repeat {
            if let url = webView.url, take.isNew(url) {
                take.navigate(to: url, at: time)
            }
            aiming = take.script.scrolls.filter { !take.aimed.contains($0.id) && $0.range.lowerBound <= time }
            let selectors = take.pointer.selectors(at: time) + aiming.compactMap(\.target?.selector) + [arriving?.show].compactMap(\.self)
            frame = try await advance(to: time, scroll: take.script.scrollOffset(at: time), selectors: selectors)
        // A page that a click opened while the frame waited for it is played again from its top
        } while take.isNew(webView.url)
        let scroll = take.script.scrollOffset(at: time)
        for clip in aiming {
            take.aimed.insert(clip.id)
            aim(clip, in: &take, at: frame, scrolledTo: scroll)
        }

        let location = take.pointer.location(at: time, elementFrames: frame.boxes)
        // Only when the cursor moves: WebKit hit-tests only on a move, so what scrolls under a resting
        // cursor (a sticky nav's menu) doesn't react, as only the script's targets should
        if let location, location != take.location {
            webView.sendPointer(.move, at: location)
        }
        let scrolled = take.scroll.map { CGVector(dx: $0.x - scroll.x, dy: $0.y - scroll.y) } ?? .zero
        (take.location, take.scroll) = (location, scroll)
        let presses = take.script.presses(after: previous, through: time).filter { press in
            // Not on an element the page doesn't have now: the press would land on whatever is there
            if press.isDown, let selector = press.target.selector, frame.boxes[selector] == nil {
                take.issues.skippedClick(selector, at: press.time)
                return false
            }
            defer { take.isPressed = press.isDown }
            return press.isDown || take.isPressed
        }
        if let location {
            for press in presses {
                webView.sendPointer(press.isDown ? .press : .release, at: location)
            }
        }
        await type(at: time, in: &take)
        let (cursor, cover) = await hold(at: location, aimingAt: arriving?.target.selector)
        if let arriving {
            check(arriving, in: &take, at: frame, cover: cover)
        }
        take.telemetry.record(time: time, cursor: location, presses: presses, shape: CursorKind(css: cursor), scrolled: scrolled)
        take.time = time
    }

    /// Gives each type clip's field the letters typed since the last frame.
    private func type(at time: Double, in take: inout Take) async {
        let typing = take.script.typing(at: time).filter { $0.text != take.typed[$0.clip, default: ""] }
        guard !typing.isEmpty else { return }
        _ = try? await webView.callAsyncJavaScript(WebTypingScript.source, arguments: ["fields": WebTypingScript.fields(typing)], contentWorld: .defaultClient)
        for field in typing {
            take.typed[field.clip] = field.text
        }
    }

    /// Checks cursor `clip`'s element as the clip starts, the way Playwright checks an action's
    /// target, and finds where the element it shows is.
    private func check(_ clip: PointerClip, in take: inout Take, at frame: PageFrame, cover: String?) {
        let start = clip.range.lowerBound
        if let selector = clip.target.selector {
            take.issues.check(selector, at: start, frame: frame.boxes[selector], cover: cover)
        }
        if let show = clip.show, let visible = take.issues.shown(show, at: start, frame: frame.boxes[show]) {
            take.shots.append(WebCamera.Shot(range: clip.range, visible: visible))
        }
    }

    /// Aims `clip` at its element where `frame`, scrolled to `scroll`, shows it now, and keeps it
    /// inside the page.
    private func aim(_ clip: ScrollClip, in take: inout Take, at frame: PageFrame, scrolledTo scroll: CGPoint) {
        guard let index = take.script.scrolls.firstIndex(where: { $0.id == clip.id }) else { return }
        let start = take.script.scrollOffset(at: clip.range.lowerBound)
        let bottom = max(frame.pageHeight - script.viewport.height, 0)
        guard let target = clip.target else {
            take.script.scrolls[index].offset.y = min(clip.offset.y, bottom)
            return
        }
        guard let box = frame.boxes[target.selector] else {
            // A scroll Reco added before a cursor clip is that clip's check to report
            if target.placement == .top {
                take.issues.notFound(target.selector, at: clip.range.lowerBound)
            }
            // Nowhere, rather than to where it was planned on a page that may be another
            take.script.scrolls[index].offset = start
            return
        }
        let shown = box.offsetBy(dx: scroll.x - start.x, dy: scroll.y - start.y)
        take.script.scrolls[index].offset = target.offset(showing: shown, from: start, viewport: script.viewport, pageHeight: frame.pageHeight)
    }
}

// MARK: - Inspecting

extension WebPageRenderer {

    /// Loads the script's page and lists what it shows at scroll 0: see ``WebInspectScript``.
    /// `selectors` are the ones to also return the box of.
    func inspect(selectors: [String]) async throws -> PageInspection {
        guard let pageURL = script.url else { throw WebRenderError.noURL }
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        try await load(pageURL)
        // Real time, as in a take: the page's own scripts finish drawing before it's read
        try await Task.sleep(for: Self.settleTime)
        let result = try await webView.callAsyncJavaScript(
            WebInspectScript.source, arguments: ["selectors": selectors], contentWorld: .defaultClient
        )
        guard let json = result as? String else { throw WebRenderError.loadFailed("The page couldn't be read.") }
        return try JSONDecoder().decode(PageInspection.self, from: Data(json.utf8))
    }
}

// MARK: - Output folder

extension WebPageRenderer {

    /// Renders `script` into a new movie in the output folder, with its telemetry and editor project
    /// beside it, and returns the movie and what went wrong on the page. A failed or cancelled take
    /// leaves no movie.
    static func renderTake(_ script: WebScript, settings: SettingsStore, progress: (Double) -> Void) async throws -> (movie: URL, warnings: [String]) {
        let accessesOutputDirectory = settings.startAccessingOutputDirectory()
        defer {
            if accessesOutputDirectory {
                settings.stopAccessingOutputDirectory()
            }
        }
        let filename = SettingsStore.filename(prefix: "Reco_Web", fileExtension: "mov", date: .now)
        let movie = settings.outputDirectory.appending(path: filename)
        do {
            let output = try await WebPageRenderer(script: script).render(
                to: movie, bitsPerPixel: VideoQuality.high.hevcBitsPerPixel, progress: progress
            )
            try JSONEncoder().encode(output.telemetry).write(to: InputTelemetry.sidecarURL(for: movie), options: .atomic)
            // The script's zooms, exactly, for the editor, even none when it shows elements; without
            // any it auto-zooms as on any recording
            let zooms = WebCamera.segments(for: script, telemetry: output.telemetry, shots: output.shots)
            if !zooms.isEmpty || WebCamera.showsElements(script) {
                try await ProjectStore.write(EditorProject(zooms: zooms), for: movie)
            }
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "WebPageRenderer").info("Rendered \(filename)")
            return (movie, output.warnings)
        } catch {
            try? FileManager.default.removeItem(at: movie)
            throw error
        }
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
