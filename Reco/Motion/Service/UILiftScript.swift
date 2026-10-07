//
//  UILiftScript.swift
//  Reco
//

import Foundation

/// The scripts that lift one element off a page (spec 0011, spike B), run in Reco's own content
/// world; the DOM and its styles are shared with the page.
enum UILiftScript {

    /// Scrolls the element `selector` matches into view, as little as it takes, and returns
    /// `{box: [x, y, width, height], fill, radius}` in viewport CSS pixels, or `null` when there's
    /// none. `fill` is the nearest painted background from the element up: a card with a transparent
    /// background would otherwise lose the page behind it. `radius` is its top-left corner's.
    ///
    /// `scrollIntoView`, not `scrollTo`: cardboard.ai scrolls inside its own container, where
    /// `window.scrollTo` left its tiles out of view. As little as it takes: linear.app fades its hero
    /// out as the page scrolls, and centred it read opacity 0.09. The wait lets lazy images and
    /// reveal animations that start on scrolling finish (spike B); then the finite animations on
    /// the element, its ancestors and inside it, up to 5 s: linear.app's hero fades in over ~2 s
    /// after loading, and lifted a second in it read opacity 0.
    static let place = #"""
    const element = document.querySelector(selector);
    if (!element) return null;
    element.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    await new Promise(resolve => setTimeout(resolve, 900));
    const entering = document.getAnimations().filter(animation => {
      const target = animation.effect?.target;
      const end = animation.effect?.getComputedTiming().endTime ?? Infinity;
      return target && Number.isFinite(end) && (target.contains(element) || element.contains(target));
    });
    await Promise.race([
      Promise.all(entering.map(animation => animation.finished.catch(() => null))),
      new Promise(resolve => setTimeout(resolve, 5000))
    ]);
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    const box = element.getBoundingClientRect();
    const clear = 'rgba(0, 0, 0, 0)';
    let fill = clear;
    for (let node = element; node && fill === clear; node = node.parentElement) fill = getComputedStyle(node).backgroundColor;
    if (fill === clear) fill = getComputedStyle(document.body).backgroundColor;
    const corner = getComputedStyle(element).borderTopLeftRadius;
    const radius = corner.endsWith('%') ? parseFloat(corner) / 100 * Math.min(box.width, box.height) : parseFloat(corner) || 0;
    return { box: [box.x, box.y, box.width, box.height], fill, radius };
    """#

    /// Clicks the element `selector` matches, as a script can, after scrolling it into view: what opens
    /// a dialog before it's lifted (Supabase's search). Returns whether it was there.
    static let click = #"""
    const element = document.querySelector(selector);
    if (!element) return false;
    element.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    element.click();
    return true;
    """#

    /// Waits until nothing on the page has changed for `quiet` milliseconds and its finite animations
    /// and transitions have ended (a button fading in as a field fills), or `most` have passed, then
    /// for two frames: a dialog has opened, a search's results have come.
    static let settle = #"""
    const started = performance.now();
    await new Promise(resolve => {
      let quietly;
      const finish = () => { observer.disconnect(); clearTimeout(quietly); clearTimeout(limit); resolve(); };
      const observer = new MutationObserver(() => { clearTimeout(quietly); quietly = setTimeout(finish, quiet); });
      const limit = setTimeout(finish, most);
      quietly = setTimeout(finish, quiet);
      observer.observe(document.documentElement, { subtree: true, childList: true, attributes: true, characterData: true });
    });
    const running = document.getAnimations().filter(animation => Number.isFinite(animation.effect?.getComputedTiming().endTime ?? Infinity));
    await Promise.race([
      Promise.all(running.map(animation => animation.finished.catch(() => null))),
      new Promise(resolve => setTimeout(resolve, Math.max(most - (performance.now() - started), 0)))
    ]);
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    return true;
    """#

    /// The field `field` typed into inside the element `selector` matches, in CSS pixels from the
    /// element's top-left corner: `{row: [x, y, width, height], end, line, fontSize, selected, box: [x,
    /// y, width, height]}`, or `null`. The row is the field's first ancestor across nine tenths of the
    /// element's width (or the element), as wide as the element: what typing changes, apart from results
    /// under it. `end` is where its text ends now, `line` its centre line, `selected` the selected
    /// result's centre line (`aria-selected` or cmdk's `data-selected`), if any; `box` the element in the
    /// viewport.
    static let field = #"""
    const element = document.querySelector(selector);
    const input = element?.querySelector(field);
    if (!element || !input) return null;
    const box = element.getBoundingClientRect();
    let row = input;
    while (row !== element && row.getBoundingClientRect().width < 0.9 * box.width) row = row.parentElement;
    const band = row.getBoundingClientRect();
    const style = getComputedStyle(input);
    const context = document.createElement('canvas').getContext('2d');
    context.font = style.font;
    const place = input.getBoundingClientRect();
    const text = 'value' in input ? input.value : input.textContent;
    const start = place.x + parseFloat(style.borderLeftWidth) + parseFloat(style.paddingLeft) - (input.scrollLeft || 0);
    const chosen = element.querySelector('[aria-selected="true"], [data-selected="true"]')?.getBoundingClientRect();
    return { row: [0, band.y - box.y, box.width, band.height], end: start + context.measureText(text).width - box.x,
             line: place.y + place.height / 2 - box.y, fontSize: parseFloat(style.fontSize),
             selected: chosen ? chosen.y + chosen.height / 2 - box.y : null, box: [box.x, box.y, box.width, box.height] };
    """#

    /// Presses the down arrow in the field `selector` matches, as cmdk's lists take it: a key down and up
    /// on the field.
    static let pressDown = #"""
    const field = document.querySelector(selector);
    if (!field) return false;
    const init = { key: 'ArrowDown', code: 'ArrowDown', keyCode: 40, which: 40, bubbles: true, cancelable: true };
    field.dispatchEvent(new KeyboardEvent('keydown', init));
    field.dispatchEvent(new KeyboardEvent('keyup', init));
    return true;
    """#

    /// With `on`, hides everything but the element and makes the page behind it transparent, so a
    /// snapshot of the page with `drawsBackground` off has real alpha around it (Linear's card
    /// corners read alpha 0); without, undoes that. With `fill` null, the element's own transparent
    /// background stays so: a live take's matte, its painted shape. With `bare`, the element's own
    /// background, border and shadow go too, for glass to stand in for them (Supabase's search dialog,
    /// spec 0012, L0).
    ///
    /// No ancestor is hidden: under `body * { visibility: hidden }` WebKit left out supabase.com's
    /// code card's own background though it computed as visible, so the elements beside the path
    /// from the root are hidden instead, everything in them too (a child's own `visibility: visible`
    /// beats an inherited hidden: Supabase's docs heading showed through its search dialog), and the
    /// path's own paint made transparent. Bare, the element's own paint goes in its inline style with
    /// `!important`, which no stylesheet beats (in a stylesheet Supabase's dialog kept its border), and
    /// comes back with the rest. A
    /// `backdrop-filter` is turned off: with the page hidden it has nothing to blur. Inside the
    /// element, a layer with one and nothing of its own to show is hidden: linear.app fades its
    /// issue list out with a stack of them (a progressive blur), and turned off, their tints drew
    /// as stepped bands across the list's right and bottom.
    static let isolate = #"""
    let style = document.getElementById('__reco_lift');
    if (!style) {
      style = document.createElement('style');
      style.id = '__reco_lift';
      document.documentElement.appendChild(style);
    }
    document.querySelectorAll('[data-reco-lift-bare]').forEach(node => {
      node.setAttribute('style', node.getAttribute('data-reco-lift-bare'));
      node.removeAttribute('data-reco-lift-bare');
    });
    document.querySelectorAll('[data-reco-lift], [data-reco-lift-path], [data-reco-lift-veil]').forEach(node => {
      node.removeAttribute('data-reco-lift');
      node.removeAttribute('data-reco-lift-path');
      node.removeAttribute('data-reco-lift-veil');
    });
    style.textContent = '';
    const element = on ? document.querySelector(selector) : null;
    if (element) {
      element.setAttribute('data-reco-lift', '');
      if (bare) {
        element.setAttribute('data-reco-lift-bare', element.getAttribute('style') ?? '');
        for (const [name, value] of [['background', 'transparent'], ['border-color', 'transparent'], ['box-shadow', 'none'], ['outline', 'none']]) {
          element.style.setProperty(name, value, 'important');
        }
      }
      for (const node of element.querySelectorAll('*')) {
        const computed = getComputedStyle(node);
        const filter = computed.backdropFilter || computed.webkitBackdropFilter || 'none';
        if (filter !== 'none' && !node.innerText?.trim() && !node.querySelector('img, svg, video, canvas, picture')) {
          node.setAttribute('data-reco-lift-veil', '');
        }
      }
      for (let node = element.parentElement; node; node = node.parentElement) node.setAttribute('data-reco-lift-path', '');
      style.textContent = `[data-reco-lift-path] { background: transparent !important; border-color: transparent !important;
          box-shadow: none !important; outline: none !important; backdrop-filter: none !important; -webkit-backdrop-filter: none !important; }
        [data-reco-lift-path] > :not([data-reco-lift-path], [data-reco-lift]), [data-reco-lift-path] > :not([data-reco-lift-path], [data-reco-lift]) *,
        [data-reco-lift-path]::before, [data-reco-lift-path]::after {
          visibility: hidden !important; }
        ${fill ? `[data-reco-lift] { background-color: ${fill} !important; }` : ''}
        [data-reco-lift], [data-reco-lift] * { backdrop-filter: none !important; -webkit-backdrop-filter: none !important; }
        [data-reco-lift-veil] { visibility: hidden !important; }`;
    }
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    return true;
    """#
}
