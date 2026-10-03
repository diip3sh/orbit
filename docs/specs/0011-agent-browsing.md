# 0011 — Agent browsing: learn the site, then record it

Status: built 2026-10-02 (`feat/ui-polish`). Extends specs 0006 and 0008.

## Why

With only `inspect_page`, the agent planned a walkthrough blind: one list of selectors and boxes, no picture,
no idea what a menu or tab shows. Its videos skipped sections and clicked the wrong things. Claude in Chrome
works because it looks at the page and tries things first. Reco's agent now does the same, in the Web
Recording window's live preview, where the user watches it.

## What

Six MCP tools act on the window's preview (opened without taking focus if needed). Each returns JSON and a
JPEG screenshot (at most 1280 px wide, quality 0.7) as MCP image content:

| Tool | Does |
|---|---|
| `open_page` | Loads a URL at a viewport; returns the inspected elements; the preview highlights them |
| `look` | Scrolls to `y` (or stays) and shows what's in view, with scroll position and page height |
| `read_page` | Headings and the page's text (at most 15,000 characters) |
| `hover`, `click` | Scroll the element into the middle, highlight it, send real pointer events |
| `type` | Clicks the element and types `text` into it |

After an action the tool waits 600 ms and for any navigation it started, then reports the page it ended on.
The prompt asks the agent to explore every section, read it and try its menus and tabs before calling
`record_page`, and to aim for 20–60 s with zoom on the steps that matter.

## Rules

- Browsing is refused while the window renders a take.
- The tools are in `AgentToolCatalog.names`, so Cursor's allowlist and Claude's `mcp__reco__*` cover them.

Verified through the bridge on wikipedia.org: open, look at y 600, read, click into en.wikipedia.org; each
returned its screenshot.

Not yet: key presses (Enter, Esc), drag, going back, a real Claude Code run judged end to end.
