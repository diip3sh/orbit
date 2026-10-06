//
//  WebTypingTests.swift
//  RecoTests
//

import Foundation
import Testing
import WebKit
@testable import Reco

@MainActor
struct WebTypingTests {

    private func typeClip(_ range: Range<Double>, text: String?) -> PointerClip {
        PointerClip(range: range, action: .type, target: WebTarget(selector: "#email", point: .zero), text: text)
    }

    @Test func letterByLetterThroughTheClip() {
        // Typing starts 0.3 s after the press and types a letter every 0.08 s: until 1.86 s
        let clip = typeClip(1..<2, text: "abcdefg")

        #expect(clip.typedText(at: 1.29).isEmpty)
        #expect(clip.typedText(at: 1.31) == "a")
        #expect(clip.typedText(at: 1.55) == "abcd")
        #expect(clip.typedText(at: 1.86) == "abcdefg")
        #expect(clip.typedText(at: 5) == "abcdefg")
    }

    @Test func aShortClipTypesFasterToShowTheWholeText() {
        // From half-way, 1.1 s, to 0.1 s before its end: all at once
        let clip = typeClip(1..<1.2, text: "abc")

        #expect(clip.typedText(at: 1.09).isEmpty)
        #expect(clip.typedText(at: 1.1) == "abc")
    }

    @Test func onlyTypeClipsWithTextType() {
        #expect(typeClip(1..<2, text: nil).typedText(at: 5).isEmpty)
        var click = typeClip(1..<2, text: "abc")
        click.action = .click
        #expect(click.typedText(at: 5).isEmpty)
    }

    @Test func aTypeClipLastsAsLongAsItsText() {
        // 0.3 s to the first letter, 0.08 s a letter, 0.8 s to read it
        #expect(abs(PointerClip.typingDuration(for: "hi") - 1.26) < 1e-9)
        #expect(abs(PointerClip.typingDuration(for: String(repeating: "x", count: 20)) - 2.7) < 1e-9)
    }

    @Test func typingClicksItsFieldFirstAndClearsWhenScrubbedBack() throws {
        var script = WebScript()
        script.duration = 5
        script.pointer = [typeClip(1..<2, text: "hi")]

        #expect(script.presses(after: 0, through: 5).map(\.time) == [1, 1.1])
        #expect(script.typing(at: 0.5).map(\.text) == [""])
        #expect(script.typing(at: 3).map(\.text) == ["hi"])
        #expect(script.typing(at: 3).first?.selector == "#email")
    }

    @Test func theScriptTypesIntoAPageAsTheUserWould() async throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        webView.loadHTMLString("""
            <input id="email"><div id="editor" contenteditable></div>
            <script>window.heard = []; document.addEventListener('input', e => heard.push(e.target.id + ':' + (e.target.value ?? e.target.textContent)));</script>
            """, baseURL: nil)
        for _ in 0..<100 where webView.isLoading {
            try await Task.sleep(for: .milliseconds(20))
        }
        let fields: [WebScript.Typing] = [
            .init(clip: UUID(), selector: "#email", text: "a@b.co"),
            .init(clip: UUID(), selector: "#editor", text: "Hi")
        ]

        _ = try await webView.callAsyncJavaScript(WebTypingScript.source, arguments: ["fields": WebTypingScript.fields(fields)], contentWorld: .defaultClient)
        // The same text again is no new typing
        _ = try await webView.callAsyncJavaScript(WebTypingScript.source, arguments: ["fields": WebTypingScript.fields(fields)], contentWorld: .defaultClient)

        let value = try await webView.evaluateJavaScript("document.getElementById('email').value") as? String
        let heard = try await webView.evaluateJavaScript("heard") as? [String]
        #expect(value == "a@b.co")
        #expect(heard == ["email:a@b.co", "editor:Hi"])
    }
}
