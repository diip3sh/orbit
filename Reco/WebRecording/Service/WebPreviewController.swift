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

    /// The page's layout size, in CSS pixels.
    var viewport: CGSize {
        didSet { fit(width: webView.frame.width) }
    }

    private var isPicking = false
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
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        logger.error("Preview couldn't load: \(error.localizedDescription)")
    }
}
