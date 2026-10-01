//
//  WebPreviewControllerTests.swift
//  RecoTests
//

import Foundation
import Testing
import WebKit
@testable import Reco

@MainActor
struct WebPreviewControllerTests {

    /// A button the page's script marks as hovered when the pointer enters it, as many sites do, and
    /// a menu that isn't shown.
    private static let page = """
        <!doctype html><html><body style="margin: 0">
        <button class="buy" style="position: absolute; left: 20px; top: 20px; width: 100px; height: 40px"></button>
        <nav id="menu" style="display: none"></nav>
        <script>
        const buy = document.querySelector('.buy');
        buy.onmouseover = () => buy.classList.add('is-hovered');
        </script></body></html>
        """

    private let viewport = CGSize(width: 640, height: 400)

    @Test(.timeLimit(.minutes(1))) func picksWithoutTheClassesThePageAddsOnHover() async throws {
        let preview = WebPreviewController(viewport: viewport)
        let window = OffscreenWebWindow(size: viewport)
        window.contentView = preview.webView
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        try await load(preview)

        preview.setPicking(true)
        let point = CGPoint(x: 40, y: 30)
        let target = await withCheckedContinuation { continuation in
            preview.onPick = { continuation.resume(returning: $0) }
            preview.webView.sendPointer(.move, at: point)
            preview.webView.sendPointer(.press, at: point)
            preview.webView.sendPointer(.release, at: point)
        }

        #expect(target.selector == "button.buy")
        #expect(target.anchor == CGPoint(x: 0.2, y: 0.25))
        #expect(target.point == point)
    }

    @Test func placesAHiddenTargetAtItsPoint() async throws {
        let preview = WebPreviewController(viewport: viewport)
        try await load(preview)
        var script = WebScript()
        script.pointer = [PointerClip(range: 0..<1, action: .hover, target: WebTarget(selector: "#menu", point: CGPoint(x: 70, y: 90)))]

        #expect(await preview.show(script, at: 0.5, scrolling: false) == CGPoint(x: 70, y: 90))
    }

    /// Loads ``page`` and waits until it has finished loading.
    private func load(_ preview: WebPreviewController) async throws {
        preview.load(URL(string: "data:text/html;charset=utf-8," + (Self.page.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")))
        let isLoaded = "return location.protocol === 'data:' && document.readyState === 'complete'"
        // The call fails while the page is replaced
        while (try? await preview.webView.callAsyncJavaScript(isLoaded, contentWorld: .page)) as? Bool != true {
            try await Task.sleep(for: .milliseconds(50))
        }
    }
}
