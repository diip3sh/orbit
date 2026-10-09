//
//  WebPageRenderer+Image.swift
//  Reco
//

import Foundation

extension WebPageRenderer {
    /// An address of an image rather than a page (a brand's mark as SVG) is shown as a page of that one `img`
    /// filling the viewport, so it can be lifted like any element, an SVG sharp at any scale. Opened as itself, an
    /// SVG is an XML document and the lift's script failed in it (spec 0015).
    nonisolated static func imagePage(for url: URL) -> String? {
        guard ["svg", "png", "jpg", "jpeg", "webp", "gif"].contains(url.pathExtension.lowercased()) else { return nil }
        let source = url.absoluteString.replacing("\"", with: "%22")
        return """
            <!doctype html><html><body style="margin:0;background:transparent">\
            <img src="\(source)" alt="" style="display:block;width:100vw;height:100vh;object-fit:contain">\
            </body></html>
            """
    }
}
