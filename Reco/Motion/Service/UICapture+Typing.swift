//
//  UICapture+Typing.swift
//  Reco
//

import Foundation
import WebKit

/// What a still does on its page before it's lifted, and a field typed into lifted state by state
/// (spec 0012, the film's port, phase 4), as the film's lab captured Supabase's search.
extension UICapture {

    /// Runs `asset`'s `before` steps on its loaded page: the clicks and typing that bring up what it
    /// lifts, each followed by the page settling.
    static func prepare(_ asset: MotionAsset, in webView: WKWebView) async throws {
        for step in asset.before ?? [] {
            let selector = step.selector ?? ""
            if step.action == "type" {
                for character in step.text ?? "" {
                    _ = try await webView.callAsyncJavaScript(WebTypeScript.source, arguments: ["selector": selector, "text": String(character)], contentWorld: .defaultClient)
                }
            } else if try await webView.callAsyncJavaScript(UILiftScript.click, arguments: ["selector": selector], contentWorld: .defaultClient) as? Bool != true {
                throw UICaptureError.notFound(asset.id, selector)
            }
            try await settle(webView, quiet: 0.3, most: 3)
        }
    }

    /// Lifts a typing asset at `scale` into `bundle`: the element with its field empty, the field's row
    /// with each length of the text typed, the whole element once each word's results settle, and where
    /// the text ends each time (``UILiftCache/Typing``). WebKit's snapshots draw no caret; the renderer
    /// draws its own.
    static func liftTyping(_ asset: MotionAsset, at scale: Int, from webView: WKWebView, into bundle: URL) async throws {
        guard let typing = asset.typing else { return }
        let placed = try await place(asset, in: webView)
        let arguments = isolation(of: asset, placed: placed)
        _ = try await webView.callAsyncJavaScript(UILiftScript.isolate, arguments: arguments.merging(["on": true]) { $1 }, contentWorld: .defaultClient)
        let lifted: Result<UILiftCache.Typing, any Error>
        do {
            lifted = .success(try await typeAndLift(typing, of: asset, at: scale, from: webView, into: bundle))
        } catch {
            lifted = .failure(error)
        }
        _ = try await webView.callAsyncJavaScript(UILiftScript.isolate, arguments: arguments.merging(["on": false]) { $1 }, contentWorld: .defaultClient)
        try JSONEncoder().encode(try lifted.get()).write(to: UILiftCache.typingURL(of: asset, in: bundle), options: .atomic)
        try JSONEncoder().encode(UILiftCache.Shape(radius: placed.radius)).write(to: UILiftCache.shapeURL(of: asset, in: bundle), options: .atomic)
    }

    /// Types `typing`'s text a character at a time into its isolated element, lifting as it goes; the
    /// empty element last, as a lift is whole only once its file is there.
    private static func typeAndLift(
        _ typing: MotionAsset.Typing, of asset: MotionAsset, at scale: Int, from webView: WKWebView, into bundle: URL
    ) async throws -> UILiftCache.Typing {
        let selector = "\(asset.selector) \(typing.field)"
        let empty = try await measure(typing, of: asset, in: webView)
        let base = try await snapshot(empty.box, at: scale, from: webView)
        var lifted = UILiftCache.Typing(row: empty.row, ends: [empty.end], line: empty.line, fontSize: empty.fontSize, settled: [], heights: [])
        let words = Set(HumanTyping.settledLengths(of: typing.text))
        for (index, character) in typing.text.enumerated() {
            _ = try await webView.callAsyncJavaScript(WebTypeScript.source, arguments: ["selector": selector, "text": String(character)], contentWorld: .defaultClient)
            let length = index + 1
            // At the video's pace, so the page keeps up as it would with a person (typed faster, Supabase's
            // results kept an older selection); a word's results come from the network, so they're waited
            // for: Supabase's took over 0.5 s with nothing changing on the page meanwhile
            if words.contains(length) {
                try await Task.sleep(for: .seconds(1.2))
                try await settle(webView, quiet: 0.6, most: 6)
            } else {
                try await Task.sleep(for: .seconds(0.12))
                try await settle(webView, quiet: 0.06, most: 1)
            }
            let field = try await measure(typing, of: asset, in: webView)
            lifted.ends.append(field.end)
            let row = field.row.offsetBy(dx: field.box.minX, dy: field.box.minY)
            try await ScreenshotService.writePNG(try await snapshot(row, at: scale, from: webView), to: UILiftCache.typedURL(of: asset, length: length, scale: scale, in: bundle))
            if words.contains(length) {
                guard CGRect(origin: .zero, size: webView.bounds.size).insetBy(dx: -1, dy: -1).contains(field.box) else {
                    throw UICaptureError.outOfView(asset.id, asset.selector)
                }
                let url = UILiftCache.settledURL(of: asset, length: length, scale: scale, in: bundle)
                try await ScreenshotService.writePNG(try await snapshot(field.box, at: scale, from: webView), to: url)
                lifted.settled.append(length)
                lifted.heights.append(field.box.height)
            }
        }
        if (typing.select ?? 0) > 0 {
            lifted.selections = try await select(in: asset, at: scale, from: webView, into: bundle)
        }
        let url = UILiftCache.url(of: asset, scale: scale, in: bundle)
        let partial = url.appendingPathExtension("partial")
        try await ScreenshotService.writePNG(base, to: partial)
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: partial, to: url)
        return lifted
    }

    /// Presses the down arrow in `asset`'s typed field as many times as it selects, lifting the whole
    /// element each time; where the selected result's centre is before and after each press.
    private static func select(in asset: MotionAsset, at scale: Int, from webView: WKWebView, into bundle: URL) async throws -> [Double] {
        guard let typing = asset.typing, let most = typing.select, most > 0 else { return [] }
        let selector = "\(asset.selector) \(typing.field)"
        var selections = [try await measure(typing, of: asset, in: webView).selected]
        for presses in 1...most {
            _ = try await webView.callAsyncJavaScript(UILiftScript.pressDown, arguments: ["selector": selector], contentWorld: .defaultClient)
            try await Task.sleep(for: .seconds(0.12))
            try await settle(webView, quiet: 0.15, most: 1.5)
            let field = try await measure(typing, of: asset, in: webView)
            try await ScreenshotService.writePNG(
                try await snapshot(field.box, at: scale, from: webView), to: UILiftCache.selectedURL(of: asset, presses: presses, scale: scale, in: bundle)
            )
            selections.append(field.selected)
        }
        // A list with nothing marked selected can't be followed
        guard selections.allSatisfy({ $0 != nil }) else { throw UICaptureError.notFound(asset.id, "the selected result in \(asset.selector)") }
        return selections.compactMap(\.self)
    }

    /// The typed-into field as ``UILiftScript/field`` measures it.
    private struct Field {
        var row: CGRect
        var end: Double
        var line: Double
        var fontSize: Double
        var selected: Double?
        var box: CGRect
    }

    private static func measure(_ typing: MotionAsset.Typing, of asset: MotionAsset, in webView: WKWebView) async throws -> Field {
        let result = try await webView.callAsyncJavaScript(
            UILiftScript.field, arguments: ["selector": asset.selector, "field": typing.field], contentWorld: .defaultClient
        )
        guard let result = result as? [String: Any], let row = result["row"] as? [Double], let box = result["box"] as? [Double], row.count == 4, box.count == 4,
              let end = result["end"] as? Double, let line = result["line"] as? Double, let fontSize = result["fontSize"] as? Double else {
            throw UICaptureError.notFound(asset.id, "\(asset.selector) \(typing.field)")
        }
        return Field(
            row: CGRect(x: row[0], y: row[1], width: row[2], height: row[3]), end: end, line: line, fontSize: fontSize,
            selected: result["selected"] as? Double, box: CGRect(x: box[0], y: box[1], width: box[2], height: box[3])
        )
    }

    /// Waits until the page hasn't changed for `quiet` seconds, at most `most`.
    static func settle(_ webView: WKWebView, quiet: Double, most: Double) async throws {
        _ = try await webView.callAsyncJavaScript(UILiftScript.settle, arguments: ["quiet": quiet * 1000, "most": most * 1000], contentWorld: .defaultClient)
    }
}
