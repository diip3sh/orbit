//
//  WebInspectScript.swift
//  Reco
//

import Foundation

/// The page's visible, interactive elements for an agent to aim at (spec 0006), run in its own
/// content world as the body of an async function that returns a JSON string, decoded as
/// ``PageInspection``. It scrolls through the page first, so what loads on the way is listed too.
///
/// Selectors come from ``WebPickScript/selectorFunctions``, so they are the ones the pick mode makes.
/// Boxes are in page CSS pixels (the viewport's box plus the scroll). `selectors` (an argument) are
/// the ones the caller wants the box of: the first element each matches.
enum WebInspectScript {

    /// The most elements listed; `truncated` says when there were more.
    static let maximumElements = 200

    /// How far the page is scrolled at a time while it loads what's further down, as a share of the
    /// viewport's height, and how long each step waits.
    static let preloadStep = 0.8
    static let preloadDelay = 100

    static let source = #"""
    \#(WebPickScript.selectorFunctions)
    // Content that loads as it scrolls into view (lazy images, sections that reveal themselves) is
    // there before the page is read, and cached for the take: down the page and back, as screenshot
    // services do. At most 40 steps.
    const pause = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));
    for (let y = 0, step = 0; y < document.documentElement.scrollHeight && step < 40; y += innerHeight * \#(preloadStep), step++) {
      scrollTo({ left: 0, top: y, behavior: 'instant' });
      await pause(\#(preloadDelay));
    }
    scrollTo({ left: 0, top: 0, behavior: 'instant' });
    await pause(300);
    const interactive = 'a[href], button, input:not([type=hidden]), select, textarea, summary, [role=button], [role=link], ' +
      '[role=tab], [role=menuitem], [role=checkbox], [role=switch], [onclick], [tabindex]:not([tabindex="-1"]), h1, h2, h3';
    const implicitRoles = { a: 'link', button: 'button', select: 'combobox', textarea: 'textbox', summary: 'button', h1: 'heading', h2: 'heading', h3: 'heading' };
    const isVisible = (element) => {
      const box = element.getBoundingClientRect();
      // Not off to a side either, like a carousel's other slides: the page only scrolls down
      if (!element.getClientRects().length || box.width <= 1 || box.height <= 1 || box.right <= 0 || box.left >= innerWidth) return false;
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
        selector: selectorFor(element), role: roleOf(element), text: textOf(element), box: pageBox(element),
        // Where a link goes, to inspect the page a click opens
        href: element.localName === 'a' && element.href ? element.href.slice(0, 200) : undefined
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
