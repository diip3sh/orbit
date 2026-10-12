//
//  WebHideScript.swift
//  Reco
//

import Foundation

/// The script that hides a take's overlays (spec 0010, step 1): a style injected at document start,
/// so they're gone from the first frame on every page. A rule per selector, so one the page's CSS
/// can't parse spoils only itself.
enum WebHideScript {

    static func source(hiding selectors: [String]) -> String {
        let list = (try? JSONEncoder().encode(selectors)).flatMap { String(bytes: $0, encoding: .utf8) } ?? "[]"
        return """
        (() => {
          const style = document.createElement('style');
          style.textContent = \(list).map((selector) => `${selector} { visibility: hidden !important; }`).join('\\n');
          document.documentElement.appendChild(style);
        })();
        """
    }
}
