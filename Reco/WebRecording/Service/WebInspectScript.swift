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
/// the ones the caller wants the box of: the first element each matches, with its corner radius.
enum WebInspectScript {

    /// The most elements listed; `truncated` says when there were more.
    static let maximumElements = 200

    /// The most overlays listed.
    static let maximumOverlays = 20

    /// The most liftable elements listed, largest first.
    static let maximumLiftable = 30

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
    // Any CSS color as #rrggbb, through a canvas, so oklch() and color() read like the rest; null when transparent
    const swatch = document.createElement('canvas').getContext('2d', { willReadFrequently: true });
    const hex = (color) => {
      swatch.clearRect(0, 0, 1, 1);
      swatch.fillStyle = color;
      swatch.fillRect(0, 0, 1, 1);
      const [red, green, blue, alpha] = swatch.getImageData(0, 0, 1, 1).data;
      return alpha < 128 ? null : '#' + [red, green, blue].map((value) => value.toString(16).padStart(2, '0')).join('');
    };
    const painted = (element) => {
      for (let node = element; node; node = node.parentElement) {
        const color = hex(getComputedStyle(node).backgroundColor);
        if (color) return color;
      }
      return null;
    };
    const brandOf = () => {
      const background = painted(document.elementFromPoint(innerWidth / 2, innerHeight / 2)) || painted(document.body) || '#ffffff';
      const heading = [...document.querySelectorAll('h1, h2')].find(isVisible) || document.body;
      const style = getComputedStyle(heading);
      const families = style.fontFamily.toLowerCase();
      const face = /monospace|mono\b/.test(families) ? 'mono' : /(^|,)\s*serif\b/.test(families) && !/sans/.test(families.split(',')[0]) ? 'serif' : 'sans';
      // The main call to action: the largest painted link or button on the first screen
      const actions = visible.filter((element) => element.matches('a[href], button, [role=button]') && element.getBoundingClientRect().top < innerHeight)
        .map((element) => ({ color: hex(getComputedStyle(element).backgroundColor), box: element.getBoundingClientRect() }))
        .filter((action) => action.color && action.color !== background)
        .sort((first, second) => second.box.width * second.box.height - first.box.width * first.box.height);
      const home = [...document.querySelectorAll('a[href]')].filter(isVisible).find((link) => {
        try {
          const url = new URL(link.href);
          return url.origin === location.origin && url.pathname === '/' && link.querySelector('img, svg') && link.getBoundingClientRect().top < 200;
        } catch {
          return false;
        }
      });
      const mark = home?.querySelector('img, svg');
      return {
        background, text: hex(style.color) || '#000000', accent: actions[0]?.color ?? undefined, face,
        font: style.fontFamily.split(',')[0].replace(/["']/g, '').trim(),
        logo: mark ? { selector: selectorFor(mark), box: pageBox(mark) } : undefined
      };
    };
    // What a motion video can lift alone: a painted, rounded box (a card, a panel, an app mockup) or a
    // picture, at least 120×60 CSS px, narrower than the page (a full-bleed section isn't one), largest
    // first, one of each box
    const liftableOf = () => {
      const found = [];
      for (const element of document.querySelectorAll('body *')) {
        const box = element.getBoundingClientRect();
        if (box.width < 120 || box.height < 60 || box.width > innerWidth * 0.96 || !isVisible(element)) continue;
        const style = getComputedStyle(element);
        const radius = parseFloat(style.borderTopLeftRadius) || 0;
        const background = hex(style.backgroundColor);
        const picture = ['img', 'video', 'canvas', 'picture'].includes(element.localName) && box.width >= 200 && box.height >= 120;
        const painted = radius > 0 && (background || style.boxShadow !== 'none' || parseFloat(style.borderTopWidth) > 0);
        if (!picture && !painted) continue;
        found.push({ element, area: box.width * box.height, entry: {
          selector: selectorFor(element), kind: picture ? element.localName : 'panel', text: textOf(element),
          box: { ...pageBox(element), radius }, background: background ?? undefined
        } });
      }
      const listed = [];
      for (const candidate of found.sort((first, second) => second.area - first.area)) {
        const box = candidate.entry.box;
        const same = listed.some((entry) => Math.abs(entry.box.x - box.x) < 2 && Math.abs(entry.box.y - box.y) < 2 &&
          Math.abs(entry.box.width - box.width) < 2 && Math.abs(entry.box.height - box.height) < 2);
        if (!same) listed.push(candidate.entry);
        if (listed.length === \#(maximumLiftable)) break;
      }
      return listed;
    };
    const description = (document.querySelector('meta[name="description" i], meta[property="og:description"]')?.content || '').trim();
    const result = {
      title: document.title,
      url: location.href,
      description: description ? description.slice(0, 300) : undefined,
      viewport: { width: innerWidth, height: innerHeight },
      page_height: document.documentElement.scrollHeight,
      elements: visible.slice(0, \#(maximumElements)).map((element) => ({
        selector: selectorFor(element), role: roleOf(element), text: textOf(element), box: pageBox(element),
        // Where a link goes, to inspect the page a click opens
        href: element.localName === 'a' && element.href ? element.href.slice(0, 200) : undefined
      })),
      truncated: visible.length > \#(maximumElements),
      // Fixed and sticky, the outermost of each: a navigation bar, a cookie banner, a chat button
      overlays: [...document.querySelectorAll('body *')].filter((element) => {
        const position = getComputedStyle(element).position;
        if (position !== 'fixed' && position !== 'sticky') return false;
        for (let node = element.parentElement; node && node !== document.body; node = node.parentElement) {
          if (['fixed', 'sticky'].includes(getComputedStyle(node).position)) return false;
        }
        const box = element.getBoundingClientRect();
        return box.width > 1 && box.height > 1 && box.bottom > 0 && box.top < innerHeight && isVisible(element);
      }).slice(0, \#(maximumOverlays)).map((element) => ({
        selector: selectorFor(element), position: getComputedStyle(element).position, text: textOf(element), box: pageBox(element)
      })),
      // A page this can't read is still listed
      brand: (() => { try { return brandOf(); } catch { return undefined; } })(),
      liftable: (() => { try { return liftableOf(); } catch { return undefined; } })()
    };
    if (selectors.length) {
      result.boxes = {};
      for (const selector of selectors) {
        try {
          const element = document.querySelector(selector);
          if (element) result.boxes[selector] = { ...pageBox(element), radius: parseFloat(getComputedStyle(element).borderTopLeftRadius) || 0 };
        } catch {}
      }
    }
    return JSON.stringify(result);
    """#
}
