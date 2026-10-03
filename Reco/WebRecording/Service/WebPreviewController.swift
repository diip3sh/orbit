//
//  WebPreviewController.swift
//  Reco
//

import AppKit
import OSLog
import WebKit

/// The Web Recording window's live page: a web view the user browses, laid out at the script's
/// viewport and shrunk to fit with `pageZoom`, so it looks as the take will.
///
/// It shares the website data store with ``WebPageRenderer``: a cookie banner dismissed here stays
/// dismissed in the take.
@MainActor
final class WebPreviewController: NSObject {

    let webView: WKWebView

    /// Called with the element the user clicked in pick mode.
    var onPick: ((WebTarget) -> Void)?

    /// Called with why a page didn't load, to show over the stage.
    var onLoadFailed: ((String) -> Void)?

    /// The page's layout size, in CSS pixels.
    var viewport: CGSize {
        didSet { fit(width: webView.frame.width) }
    }

    private var isPicking = false

    /// An agent waiting for the page it opened to finish loading (spec 0011).
    private var loadWaiter: CheckedContinuation<Void, any Error>?

    private let pickWorld = WKContentWorld.world(name: "RecoPick")
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "WebPreviewController")

    init(viewport: CGSize) {
        self.viewport = viewport
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController.addUserScript(
            WKUserScript(source: WebPickScript.source, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: pickWorld)
        )
        webView = WKWebView(frame: CGRect(origin: .zero, size: viewport), configuration: configuration)
        super.init()
        // Through a handler that doesn't retain the controller: the content controller keeps it
        configuration.userContentController.add(PickHandler { [weak self] in self?.picked($0) }, contentWorld: pickWorld, name: WebPickScript.messageName)
        webView.navigationDelegate = self
    }

    /// Loads `url`, or a blank page for none.
    func load(_ url: URL?) {
        if let url {
            webView.load(URLRequest(url: url))
        } else {
            webView.loadHTMLString("", baseURL: nil)
        }
    }

    /// Lays the page out at the viewport's width in CSS pixels across `width` points.
    func fit(width: CGFloat) {
        guard width > 0, viewport.width > 0 else { return }
        webView.pageZoom = width / viewport.width
    }

    /// Outlines the element under the pointer and makes the next click pick it, or stops.
    func setPicking(_ isPicking: Bool) {
        self.isPicking = isPicking
        webView.evaluateJavaScript("window.__recoPick?.(\(isPicking))", in: nil, in: pickWorld)
    }

    /// Where the page is scrolled to: the viewport's top-left corner in the page, in CSS pixels.
    func scrollOffset() async -> CGPoint? {
        let offset = try? await webView.evaluateJavaScript("[scrollX, scrollY]", contentWorld: pickWorld) as? [Double]
        guard let offset, offset.count == 2 else { return nil }
        return CGPoint(x: offset[0], y: offset[1])
    }

    /// Returns where `script`'s cursor is at `time`, in viewport CSS pixels, after scrolling the page
    /// to where the script has it then when `scrolling`. Resting and travelling cursors are placed
    /// from their targets as they are now; the take can only tell by playing up to `time`.
    func show(_ script: WebScript, at time: Double, scrolling: Bool) async -> CGPoint? {
        var track = PointerTrack(script: script)
        let offset = script.scrollOffset(at: time)
        let scroll: Any = scrolling ? [offset.x, offset.y] : NSNull()
        let arguments: [String: Any] = ["scroll": scroll, "selectors": track.selectors(at: time)]
        let result = try? await webView.callAsyncJavaScript(Self.showScript, arguments: arguments, contentWorld: pickWorld)
        // The fields hold what's typed by then; only those with a selector, as the preview's focus is the user's
        let fields = script.typing(at: time).filter { $0.selector != nil }
        if !fields.isEmpty {
            _ = try? await webView.callAsyncJavaScript(WebTypingScript.source, arguments: ["fields": WebTypingScript.fields(fields)], contentWorld: pickWorld)
        }
        var frames: [String: CGRect] = [:]
        for (selector, box) in result as? [String: [Double]] ?? [:] where box.count == 4 {
            frames[selector] = CGRect(x: box[0], y: box[1], width: box[2], height: box[3])
        }
        return track.location(at: time, elementFrames: frames)
    }

    /// Scrolls to `scroll` unless it's null, and returns the boxes of the elements `selectors` match
    /// and that are rendered, as the take does.
    private static let showScript = """
        if (scroll) window.scrollTo({ left: scroll[0], top: scroll[1], behavior: 'instant' });
        const boxes = {};
        for (const selector of selectors) {
          let element = null;
          try { element = document.querySelector(selector); } catch {}
          const box = element?.getClientRects().length ? element.getBoundingClientRect() : null;
          if (box) boxes[selector] = [box.x, box.y, box.width, box.height];
        }
        return boxes;
        """

    private func picked(_ body: Any) {
        guard let pick = body as? [String: Any],
              let anchor = pick["anchor"] as? [Double], anchor.count == 2,
              let point = pick["point"] as? [Double], point.count == 2
        else { return }
        onPick?(WebTarget(
            selector: pick["selector"] as? String,
            anchor: CGPoint(x: anchor[0], y: anchor[1]),
            point: CGPoint(x: point[0], y: point[1])
        ))
    }

    /// Forwards pick messages without retaining their receiver.
    private final class PickHandler: NSObject, WKScriptMessageHandler {
        let receive: (Any) -> Void

        init(_ receive: @escaping (Any) -> Void) {
            self.receive = receive
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            receive(message.body)
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebPreviewController: WKNavigationDelegate {

    /// A new page starts without pick mode, so it's turned back on.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if isPicking {
            setPicking(true)
        }
        finishLoadWait(nil)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        failed(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        failed(error)
    }

    /// Reports why the page didn't load, except a load the next one replaced.
    private func failed(_ error: any Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        logger.error("Preview couldn't load: \(error.localizedDescription)")
        onLoadFailed?("The page couldn't be loaded: \(error.localizedDescription)")
        finishLoadWait(error)
    }
}

// MARK: - Browsing

/// What an agent does in the live page while it learns a site (spec 0011): wait for a page, look at
/// it, read it, and point, hover and click as a person would. The window shows all of it.
extension WebPreviewController {

    enum BrowseError: LocalizedError {
        case timedOut
        case noSnapshot

        var errorDescription: String? {
            switch self {
            case .timedOut: "The page took more than 30 seconds to load."
            case .noSnapshot: "The page couldn't be captured."
            }
        }
    }

    /// Waits until the page that's loading has finished, or failed.
    func waitUntilLoaded(timeout: Duration = .seconds(30)) async throws {
        guard webView.isLoading else { return }
        try await withCheckedThrowingContinuation { continuation in
            finishLoadWait(CancellationError())
            loadWaiter = continuation
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.finishLoadWait(BrowseError.timedOut)
            }
        }
    }

    fileprivate func finishLoadWait(_ error: (any Error)?) {
        guard let waiter = loadWaiter else { return }
        loadWaiter = nil
        if let error {
            waiter.resume(throwing: error)
        } else {
            waiter.resume()
        }
    }

    /// Runs `source` as a function body in the preview's own content world, where the page's scripts
    /// can't see or change it.
    func evaluate(_ source: String, arguments: [String: Any] = [:]) async throws -> Any? {
        try await webView.callAsyncJavaScript(source, arguments: arguments, contentWorld: pickWorld)
    }

    func scroll(toY y: Double) async {
        _ = try? await evaluate("window.scrollTo({ left: 0, top: y, behavior: 'instant' })", arguments: ["y": y])
    }

    /// What the viewport shows, as a JPEG at most `maximumWidth` pixels wide: small enough to send an
    /// agent every step, sharp enough to read a page's text.
    func screenshot(maximumWidth: Int = 1280) async throws -> Data {
        let image = try await webView.takeSnapshot(configuration: nil)
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw BrowseError.noSnapshot }
        let scale = min(1, Double(maximumWidth) / Double(source.width))
        let width = Int((Double(source.width) * scale).rounded())
        let height = Int((Double(source.height) * scale).rounded())
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw BrowseError.noSnapshot }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = context.makeImage(),
              let jpeg = NSBitmapImageRep(cgImage: scaled).representation(using: .jpeg, properties: [.compressionFactor: 0.7])
        else { throw BrowseError.noSnapshot }
        return jpeg
    }

    /// Moves the pointer to `point` in the viewport's CSS pixels, with the real events a take sends, so
    /// CSS hover states and hover menus show as they will in the video.
    func hover(at point: CGPoint) {
        webView.sendPointer(.move, at: viewPoint(point))
    }

    /// The page it shows now, which a click may have changed.
    var currentURL: URL? { webView.url }

    /// Presses or releases the mouse at `point` in the viewport's CSS pixels, as a take does.
    func press(_ isDown: Bool, at point: CGPoint) {
        webView.sendPointer(isDown ? .press : .release, at: viewPoint(point))
    }

    /// Clicks at `point` in the viewport's CSS pixels: a move, a press and a release.
    func click(at point: CGPoint) {
        let location = viewPoint(point)
        webView.sendPointer(.move, at: location)
        webView.sendPointer(.press, at: location)
        webView.sendPointer(.release, at: location)
    }

    /// The preview is laid out in CSS pixels and shrunk with `pageZoom`.
    private func viewPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * webView.pageZoom, y: point.y * webView.pageZoom)
    }
}

