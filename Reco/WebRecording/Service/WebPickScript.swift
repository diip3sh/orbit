//
//  WebPickScript.swift
//  Reco
//

import Foundation

/// The preview's pick mode, run in its own content world so the page can't see or break it.
///
/// While on, the element under the pointer is outlined and a click picks it instead of reaching the
/// page: the `pick` message handler gets its selector, where in its box it was clicked (fractions)
/// and the point in the viewport. The selector climbs from the element until it matches only it:
/// an id where there is one, else the tag with up to three classes, and `:nth-of-type` among
/// siblings that would match too. The page gets no pointer events meanwhile, so classes it adds on
/// hover never reach the selector.
enum WebPickScript {

    static let messageName = "pick"

    /// `unique` and `selectorFor`, shared with ``WebInspectScript`` so both name elements alike.
    static let selectorFunctions = #"""
    const unique = (selector) => { try { return document.querySelectorAll(selector).length === 1; } catch { return false; } };
    const selectorFor = (element) => {
      const parts = [];
      for (let node = element; node && node.nodeType === Node.ELEMENT_NODE; node = node.parentElement) {
        let part;
        if (node.id && unique('#' + CSS.escape(node.id))) {
          part = '#' + CSS.escape(node.id);
        } else {
          part = node.localName + [...node.classList].slice(0, 3).map((name) => '.' + CSS.escape(name)).join('');
          const parent = node.parentElement;
          if (parent && parent.querySelectorAll(':scope > ' + part).length > 1) {
            const siblings = [...parent.children].filter((child) => child.localName === node.localName);
            part += ':nth-of-type(' + (siblings.indexOf(node) + 1) + ')';
          }
        }
        parts.unshift(part);
        const selector = parts.join(' > ');
        if (unique(selector)) return selector;
      }
      return parts.join(' > ');
    };
    """#

    static let source = #"""
    (() => {
      let outline = null;
      \#(selectorFunctions)
      const show = (element) => {
        if (!outline) {
          outline = document.createElement('div');
          outline.style.cssText = 'position:fixed;pointer-events:none;z-index:2147483647;box-sizing:border-box;' +
            'border:2px solid #8b5cf6;border-radius:3px;background:rgba(139,92,246,0.15)';
          document.documentElement.appendChild(outline);
        }
        const box = element.getBoundingClientRect();
        Object.assign(outline.style, { left: box.x + 'px', top: box.y + 'px', width: box.width + 'px', height: box.height + 'px' });
      };
      const block = (event) => { event.preventDefault(); event.stopImmediatePropagation(); };
      const move = (event) => { block(event); if (event.target instanceof Element) show(event.target); };
      const pick = (event) => {
        block(event);
        const element = event.target;
        if (!(element instanceof Element)) return;
        const box = element.getBoundingClientRect();
        window.webkit.messageHandlers.pick.postMessage({
          selector: selectorFor(element),
          anchor: [box.width ? (event.clientX - box.x) / box.width : 0.5, box.height ? (event.clientY - box.y) / box.height : 0.5],
          point: [event.clientX, event.clientY]
        });
      };
      const blocked = ['mousedown', 'mouseup', 'pointerdown', 'pointerup', 'dblclick', 'auxclick', 'contextmenu', 'pointermove',
        'mouseover', 'mouseout', 'mouseenter', 'mouseleave', 'pointerover', 'pointerout', 'pointerenter', 'pointerleave'];
      window.__recoPick = (on) => {
        const method = on ? addEventListener : removeEventListener;
        method('mousemove', move, true);
        method('click', pick, true);
        for (const type of blocked) method(type, block, true);
        if (!on && outline) { outline.remove(); outline = null; }
      };
    })();
    """#
}
