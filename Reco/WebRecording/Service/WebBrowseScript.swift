//
//  WebBrowseScript.swift
//  Reco
//

/// Scripts an agent's browsing runs in the live page (spec 0011), in the preview's content world.
nonisolated enum WebBrowseScript {

    /// Brings the element `selector` matches to the middle of the viewport and returns its box in the
    /// viewport's CSS pixels and its text, or `null` when nothing matches.
    static let locate = """
        let element = null;
        try { element = document.querySelector(selector); } catch {}
        if (!element) return null;
        element.scrollIntoView({ block: 'center', inline: 'center', behavior: 'instant' });
        const box = element.getBoundingClientRect();
        // A password's value is a secret, and this goes to the agent (as in WebInspectScript's valueOf)
        const value = ['checkbox', 'radio', 'password'].includes(element.type) ? '' : element.value;
        const text = (element.getAttribute('aria-label') || element.innerText || value || '').replace(/\\s+/g, ' ').trim().slice(0, 60);
        return [box.x, box.y, box.width, box.height, text];
        """

    /// The page's text as a reader sees it: its headings with where they are, then its visible text
    /// in order, cut to `limit` characters.
    static let read = """
        const headings = [...document.querySelectorAll('h1, h2, h3')]
          .filter((h) => h.getClientRects().length)
          .map((h) => ({ level: Number(h.localName[1]), text: h.innerText.replace(/\\s+/g, ' ').trim().slice(0, 120), y: Math.round(h.getBoundingClientRect().y + scrollY) }))
          .filter((h) => h.text);
        const text = document.body.innerText.split('\\n').map((line) => line.replace(/\\s+/g, ' ').trim()).filter(Boolean).join('\\n');
        return JSON.stringify({
          title: document.title, url: location.href, page_height: document.documentElement.scrollHeight,
          viewport_height: innerHeight, scroll_y: Math.round(scrollY), headings,
          text: text.slice(0, limit), truncated: text.length > limit
        });
        """

    /// Where the page is: its address, height and scroll, as JSON.
    static let position = """
        return JSON.stringify({
          url: location.href, title: document.title, page_height: document.documentElement.scrollHeight,
          viewport_height: innerHeight, scroll_y: Math.round(scrollY)
        });
        """
}
