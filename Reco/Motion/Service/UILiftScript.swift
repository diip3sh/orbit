//
//  UILiftScript.swift
//  Reco
//

import Foundation

/// The scripts that lift one element off a page (spec 0011, spike B), run in Reco's own content
/// world; the DOM and its styles are shared with the page.
enum UILiftScript {

    /// Scrolls the element `selector` matches into view, as little as it takes, and returns
    /// `{box: [x, y, width, height], fill}` in viewport CSS pixels, or `null` when there's none.
    /// `fill` is the nearest painted background from the element up: a card with a transparent
    /// background would otherwise lose the page behind it.
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
    return { box: [box.x, box.y, box.width, box.height], fill };
    """#

    /// With `on`, hides everything but the element and makes the page behind it transparent, so a
    /// snapshot of the page with `drawsBackground` off has real alpha around it (Linear's card
    /// corners read alpha 0); without, undoes that. With `fill` null, the element's own transparent
    /// background stays so: a live take's matte, its painted shape.
    ///
    /// No ancestor is hidden: under `body * { visibility: hidden }` WebKit left out supabase.com's
    /// code card's own background though it computed as visible, so the elements beside the path
    /// from the root are hidden instead, and the path's own paint made transparent. A
    /// `backdrop-filter` is turned off: with the page hidden it has nothing to blur.
    static let isolate = #"""
    let style = document.getElementById('__reco_lift');
    if (!style) {
      style = document.createElement('style');
      style.id = '__reco_lift';
      document.documentElement.appendChild(style);
    }
    document.querySelectorAll('[data-reco-lift], [data-reco-lift-path]').forEach(node => {
      node.removeAttribute('data-reco-lift');
      node.removeAttribute('data-reco-lift-path');
    });
    style.textContent = '';
    const element = on ? document.querySelector(selector) : null;
    if (element) {
      element.setAttribute('data-reco-lift', '');
      for (let node = element.parentElement; node; node = node.parentElement) node.setAttribute('data-reco-lift-path', '');
      style.textContent = `[data-reco-lift-path] { background: transparent !important; border-color: transparent !important;
          box-shadow: none !important; outline: none !important; backdrop-filter: none !important; -webkit-backdrop-filter: none !important; }
        [data-reco-lift-path] > :not([data-reco-lift-path], [data-reco-lift]), [data-reco-lift-path]::before, [data-reco-lift-path]::after {
          visibility: hidden !important; }
        ${fill ? `[data-reco-lift] { background-color: ${fill} !important; }` : ''}
        [data-reco-lift], [data-reco-lift] * { backdrop-filter: none !important; -webkit-backdrop-filter: none !important; }`;
    }
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    return true;
    """#
}
