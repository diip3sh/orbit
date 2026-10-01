//
//  WebInspectScript.swift
//  Reco
//

import Foundation

/// The page's visible, interactive elements for an agent to aim at (spec 0006), run in its own
/// content world as the body of a function that returns a JSON string, decoded as ``PageInspection``.
///
/// Selectors come from ``WebPickScript/selectorFunctions``, so they are the ones the pick mode makes.
/// Boxes are in page CSS pixels (the viewport's box plus the scroll). `selectors` (an argument) are
/// the ones the caller wants the box of: the first element each matches.
enum WebInspectScript {

    /// The most elements listed; `truncated` says when there were more.
    static let maximumElements = 200

    static let source = #"""
    \#(WebPickScript.selectorFunctions)
    const interactive = 'a[href], button, input:not([type=hidden]), select, textarea, summary, [role=button], [role=link], ' +
      '[role=tab], [role=menuitem], [role=checkbox], [role=switch], [onclick], [tabindex]:not([tabindex="-1"]), h1, h2, h3';
    const implicitRoles = { a: 'link', button: 'button', select: 'combobox', textarea: 'textbox', summary: 'button', h1: 'heading', h2: 'heading', h3: 'heading' };
    const isVisible = (element) => {
      const box = element.getBoundingClientRect();
      if (!element.getClientRects().length || box.width <= 1 || box.height <= 1) return false;
      const style = getComputedStyle(element);
      return style.visibility !== 'hidden' && style.opacity !== '0';
    };
    const pageBox = (element) => {
      const box = element.getBoundingClientRect();
      return { x: box.x + scrollX, y: box.y + scrollY, width: box.width, height: box.height };
    };
    // A checkbox's value is "on" and a password's is a secret: neither says what the element is
    const valueOf = (element) => ['checkbox', 'radio', 'password'].includes(element.type) ? '' : element.value;
    const textOf = (element) => {
      const text = element.getAttribute('aria-label') || element.innerText || valueOf(element) || element.getAttribute('alt') || element.getAttribute('title') || '';
      return text.replace(/\s+/g, ' ').trim().slice(0, 60);
    };
    const roleOf = (element) => element.getAttribute('role') || implicitRoles[element.localName] || (element.localName === 'input' ? element.type : 'generic');
    const visible = [...document.querySelectorAll(interactive)].filter(isVisible);
    const result = {
      title: document.title,
      url: location.href,
      viewport: { width: innerWidth, height: innerHeight },
      page_height: document.documentElement.scrollHeight,
      elements: visible.slice(0, \#(maximumElements)).map((element) => ({
        selector: selectorFor(element), role: roleOf(element), text: textOf(element), box: pageBox(element)
      })),
      truncated: visible.length > \#(maximumElements)
    };
    if (selectors.length) {
      result.boxes = {};
      for (const selector of selectors) {
        try {
          const element = document.querySelector(selector);
          if (element) result.boxes[selector] = pageBox(element);
        } catch {}
      }
    }
    return JSON.stringify(result);
    """#
}
