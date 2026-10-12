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
        .map((element) => ({
          color: hex(getComputedStyle(element).backgroundColor), box: element.getBoundingClientRect(),
          radius: parseFloat(getComputedStyle(element).borderTopLeftRadius) || 0
        }))
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
      const size = parseFloat(style.fontSize) || 16;
      const spacing = parseFloat(style.letterSpacing);
      return {
        background, text: hex(style.color) || '#000000', accent: actions[0]?.color ?? undefined, face,
        font: familyName(style.fontFamily),
        logo: mark ? { selector: selectorFor(mark), box: pageBox(mark) } : undefined,
        heading: {
          weight: parseInt(style.fontWeight) || 400, tracking: Number.isFinite(spacing) ? Math.round(spacing / size * 1000) / 1000 : 0,
          uppercase: style.textTransform === 'uppercase', size: Math.round(size / innerWidth * 1000) / 1000
        },
        palette: paletteOf(), gradients: gradientsOf(),
        radius: { button: actions[0]?.radius, card: cardRadius() }
      };
    };
    // A family as people name it: next/font's "__Inter_d65c78" is Inter
    const familyName = (families) => {
      const first = families.split(',')[0].replace(/["']/g, '').trim();
      const mangled = /^__(.+?)_[0-9a-f]{5,}$/i.exec(first);
      return mangled ? mangled[1].replace(/_/g, ' ') : first;
    };
    // The colours painted on the page's first three screens, most area first
    const paletteOf = () => {
      const area = new Map();
      for (const element of document.querySelectorAll('body, body *')) {
        const box = element.getBoundingClientRect();
        if (box.width < 4 || box.height < 4 || box.bottom < 0 || box.top > innerHeight * 3) continue;
        const color = hex(getComputedStyle(element).backgroundColor);
        if (color) area.set(color, (area.get(color) || 0) + Math.min(box.width, innerWidth) * Math.min(box.height, innerHeight));
      }
      return [...area.entries()].sort((first, second) => second[1] - first[1]).slice(0, 8).map(([color]) => color);
    };
    // Gradients painted on the page, as their colour stops, largest first
    const gradientsOf = () => {
      const found = [];
      for (const element of document.querySelectorAll('body, body *')) {
        const image = getComputedStyle(element).backgroundImage;
        if (!image.includes('gradient(')) continue;
        const box = element.getBoundingClientRect();
        const stops = (image.match(/(rgba?|hsla?|oklch|oklab|lab|lch|color)\([^)]*\)|#[0-9a-f]{3,8}\b/gi) || []).map(hex).filter(Boolean);
        if (new Set(stops).size >= 2) found.push({ stops: [...new Set(stops)].slice(0, 5), area: box.width * box.height });
      }
      return found.sort((first, second) => second.area - first.area).slice(0, 3).map((gradient) => gradient.stops);
    };
    // The corner radius most painted panels share
    const cardRadius = () => {
      const counts = new Map();
      for (const element of document.querySelectorAll('body *')) {
        const box = element.getBoundingClientRect();
        if (box.width < 120 || box.height < 60 || box.top > innerHeight * 3) continue;
        const style = getComputedStyle(element);
        const radius = parseFloat(style.borderTopLeftRadius) || 0;
        if (radius > 0 && (hex(style.backgroundColor) || parseFloat(style.borderTopWidth) > 0)) counts.set(radius, (counts.get(radius) || 0) + 1);
      }
      return [...counts.entries()].sort((first, second) => second[1] - first[1])[0]?.[0];
    };
    // The files of the faces the heading and the body are set in, so the video can be set in them (spec 0019): @font-face
    // rules read from the page's stylesheets (fetched again when they're another origin's), the Latin file of the closest weight
    const fontsOf = async () => {
      const faces = [];
      const read = (css, base) => {
        for (const block of css.match(/@font-face\s*{[^}]*}/gi) || []) {
          const family = /font-family\s*:\s*(['"]?)([^;'"]+)\1/i.exec(block)?.[2]?.trim();
          const weights = (/font-weight\s*:\s*([^;}]+)/i.exec(block)?.[1] || '400').trim().split(/\s+/)
            .map((value) => value === 'bold' ? 700 : value === 'normal' ? 400 : parseInt(value));
          const italic = /font-style\s*:\s*(italic|oblique)/i.test(block);
          const range = /unicode-range\s*:\s*([^;}]+)/i.exec(block)?.[1];
          const sources = [...block.matchAll(/url\((['"]?)([^'")]+)\1\)\s*(?:format\((['"]?)([^'")]+)\3\))?/gi)]
            .filter((match) => !match[2].startsWith('data:'))
            .map((match) => ({ url: new URL(match[2], base).href, format: (match[4] || match[2]).toLowerCase() }));
          const source = sources.find((candidate) => candidate.format.includes('woff2'))
            || sources.find((candidate) => /woff|truetype|opentype|\.ttf|\.otf/.test(candidate.format));
          if (family && source && !italic) {
            const latin = !range || /U\+0{1,4}(-|,|$)|U\+0000-00FF/i.test(range);
            faces.push({ family: family.toLowerCase(), low: weights[0] || 400, high: weights[1] || weights[0] || 400, latin, url: source.url });
          }
        }
      };
      for (const sheet of [...document.styleSheets]) {
        let css = null;
        try { css = [...sheet.cssRules].map((rule) => rule.cssText).join('\n'); } catch {}
        if (css === null && sheet.href) {
          try { css = await (await fetch(sheet.href)).text(); } catch {}
        }
        if (css) read(css, sheet.href || location.href);
      }
      const faceFor = (element, role) => {
        if (!element) return undefined;
        const style = getComputedStyle(element);
        const css = style.fontFamily.split(',')[0].replace(/["']/g, '').trim().toLowerCase();
        const weight = parseInt(style.fontWeight) || 400;
        const distance = (face) => weight < face.low ? face.low - weight : weight > face.high ? weight - face.high : 0;
        const face = faces.filter((candidate) => candidate.family === css).sort((first, second) => (second.latin - first.latin) || distance(first) - distance(second))[0];
        return face ? { role, family: familyName(style.fontFamily), weight, url: face.url } : undefined;
      };
      const heading = [...document.querySelectorAll('h1, h2')].find(isVisible);
      const body = [...document.querySelectorAll('p, li')].find((element) => isVisible(element) && element.innerText.trim().length > 20) || document.body;
      const found = [faceFor(heading, 'heading'), faceFor(body, 'body')].filter(Boolean);
      return found.filter((font, index) => found.findIndex((other) => other.url === font.url) === index);
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
      brand: await (async () => {
        try {
          const brand = brandOf();
          try { brand.fonts = await fontsOf(); } catch {}
          return brand;
        } catch {
          return undefined;
        }
      })(),
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
