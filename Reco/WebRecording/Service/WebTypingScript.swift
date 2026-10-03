//
//  WebTypingScript.swift
//  Reco
//

import Foundation

/// Puts typed text into fields (spec 0009), for the take and the window's preview alike.
///
/// It runs in an isolated content world, where assigning `value` calls the element's native setter
/// past any wrapper the page's framework installed (React tracks the last value it set there), and
/// then fires an `input` event, which the page's listeners handle as typing. A field with no selector
/// is the focused element, which a type clip's click focused.
nonisolated enum WebTypingScript {

    /// Expects `fields`: `[[selector or null, text]]`.
    static let source = """
        for (const [selector, text] of fields) {
          let element = null;
          try { element = selector ? document.querySelector(selector) : document.activeElement; } catch {}
          if (!element) continue;
          if (element.isContentEditable) {
            if (element.textContent === text) continue;
            element.textContent = text;
          } else if ('value' in element) {
            if (element.value === text) continue;
            element.value = text;
          } else {
            continue;
          }
          element.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text.slice(-1) || null }));
        }
        """

    /// `typing` as the script's `fields` argument.
    static func fields(_ typing: [WebScript.Typing]) -> [[Any]] {
        typing.map { [$0.selector as Any? ?? NSNull(), $0.text] }
    }
}
