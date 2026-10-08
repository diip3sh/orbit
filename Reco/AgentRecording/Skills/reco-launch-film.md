---
name: reco-launch-film
description: Reco's method for a launch film, after New Raycast's, the bar the user approved. The product's real UI in macro on glass, typed into and stepped through, whips between its parts, ending on the word-swap closing, over one of three looks chosen from the brand (black satin, grainy light, dither) with seams in that look's language. Use it before making a motion video with edit_motion, and for any chat change beyond a small tweak (a new scene, a new look, "make it better").
---

# A launch film, Reco's way

## The bar

The user approved one film, and every new one is judged next to it: Supabase's docs, 24 s, five scenes,
in the look of New Raycast (2026).

1. 0–3.2 s. Black satin alone for a second, then the docs' search dialog cuts in on glass at 14×, cut off
   by the frame's right edge, its caret blinking, the camera easing back.
2. 3.2–7.6 s. Closer on the field: "row level security" typed at a person's pace, the results growing
   under it after each word.
3. 7.6–10.2 s. The results at 10×: the selection steps down two and back up, the camera following it.
4. 10.2–15 s. The page that result opens: its heading held, then a whip down to its code block on glass.
5. 15–24 s. Black: SUPABASE and a product word swapped beside it every 0.42 s, SUPABASE DOCS together,
   BUILD IN A WEEKEND under them, the logo alone.

There is no title card, no slide, no card cascade and no whole screenshot in it. Every shot is one real
control so close that its type is 10–20 % of the frame's height, and in every shot something happens: a
caret, typing, results arriving, a selection moving, a whip.

The whole film is this document:

```json
{
  "version": 1,
  "canvas": {"size": [1920, 1080], "frameRate": 30, "field": "satin", "background": "#000000", "pacing": "beats"},
  "style": {"text": "#ededed", "face": "sans"},
  "assets": [
    {"id": "bar", "url": "https://supabase.com/docs", "selector": "[role=dialog]", "glass": true,
     "before": [{"action": "click", "selector": "button[aria-haspopup=\"dialog\"]"}], "typing": {"field": "input", "text": ""}},
    {"id": "search", "url": "https://supabase.com/docs", "selector": "[role=dialog]", "glass": true,
     "before": [{"action": "click", "selector": "button[aria-haspopup=\"dialog\"]"}], "typing": {"field": "input", "text": "row level security"}},
    {"id": "results", "url": "https://supabase.com/docs", "selector": "[role=dialog]", "glass": true,
     "before": [{"action": "click", "selector": "button[aria-haspopup=\"dialog\"]"}],
     "typing": {"field": "input", "text": "row level security", "select": 2}},
    {"id": "column", "url": "https://supabase.com/docs/guides/database/postgres/row-level-security", "viewport": [1440, 1100],
     "selector": "#sb-docs-guide-main-article", "bare": true, "region": [[0, 0], [706, 852]]},
    {"id": "code", "url": "https://supabase.com/docs/guides/database/postgres/row-level-security", "viewport": [1440, 1100],
     "selector": "#sb-docs-guide-main-article > div:nth-of-type(2)", "glass": true},
    {"id": "logo", "url": "https://supabase.com/docs", "selector": "nav img[alt=\"Supabase wordmark\"]"}
  ],
  "scenes": [
    {"id": "bar", "duration": 3.2, "shot": {"shot": "macro", "ui": "bar", "view": [[-47, -12], [137, 77]]}},
    {"id": "typed", "duration": 4.4, "shot": {"shot": "macro", "ui": "search", "view": [[-44, -40], [256, 144]]}},
    {"id": "results", "duration": 2.6, "shot": {"shot": "macro", "ui": "results", "view": [[-15, 35], [192, 108]]}},
    {"id": "page", "duration": 4.8, "shot": {"shot": "macro", "items": [
      {"ui": "column", "view": [[-42, -69], [356, 200]]}, {"ui": "code", "view": [[-33, -32], [274, 154]]}]}},
    {"id": "closing", "duration": 9, "shot": {"shot": "closing", "text": "Supabase",
      "items": [{"text": "Row level security"}, {"text": "Auth"}, {"text": "Database"}, {"text": "Storage"}, {"text": "Realtime"},
                {"text": "Edge functions"}, {"text": "Vector"}, {"text": "Cron"}, {"text": "Docs"}],
      "detail": "Build in a weekend", "ui": "logo"}}
  ]
}
```

The search dialog was 576 CSS px wide and 48 tall before anything was typed; the article column 706 wide.

That film is the satin look. The light and dither looks below keep its shots, timing and closing, and change
the ground under the glass and the seams between scenes. Choose the look from the brand (section 5): every
product getting the same black satin is its own tell.

## What reads as generated: never

- A headline alone in the middle of the frame as a shot, or a title between scenes. Words belong to the
  closing; at most one `hook`, and only if the UI can't say what the product is.
- A whole page or app shrunk to fit the frame: its type is 1–3 % of the frame's height, unreadable.
- Cards sliding in from the side, cascades of cards, everything fading in. `uiHero`, `uiFocus`,
  `uiCascade`, `featureSequence` and `title` belong to other looks, not this one.
- A fade, `zoomThrough` or `push` between macro shots.
- A shot where nothing happens: only a drift, no typing, no selection, no whip.
- Two looks in one film, or a seam from another look (a dither seam in a light film); Paper's fields (light,
  dither, halo) under type instead of under a macro's glass.
- Hype copy: revolutionary, seamless, unlock, supercharge; exclamation marks; questions to the viewer.

## 1. Find the product's real moments

The film is only as good as the moments you find. Spend the research on this, with inspect_page (its
`selectors` argument returns the boxes of elements you name, such as the parts of a panel) and web search or
fetch if you have them:

- **A search or command palette.** Docs sites (`/docs`) nearly always have one behind a Search or ⌘K button.
  Make an asset whose `before` clicks that button, whose `selector` is the dialog (`[role=dialog]`,
  `[cmdk-dialog]`, `.DocSearch-Modal`) and whose `typing.field` is its input. Results that change as you type,
  and a selection the arrow keys move (`select`), are the best macro material there is.
- **A prompt or chat box** (AI products): type the product's own example prompt into it. When it is a
  drawing of a box on a marketing page rather than a real input, typing still works: `typing.field` is the
  element holding its text; Reco empties it and types the text in.
- **The product's own UI:** an editor, a code block, an issue with its labels, a diff, a status line, a chart.
  These are stills for a macro tour: one asset, several views, a whip between each.
- **The page a result opens:** its heading and first paragraph as `bare`, its code block or card as `glass`.

Then choose three to five moments that make one continuous action: open, type, results, choose, what it
shows. One product, one action, seen up close. A signed-in app beats a marketing mockup, and a mockup beats
marketing text.

## 2. Assets

- `glass: true` on every control, card and code block; `bare: true` on page text (a heading with its
  paragraphs) over satin only: over light or dither, page text goes on glass too, or the ground's light runs
  through its letters. An asset is always one or the other, except the logo: the glass shows the ground
  through it, tinted with the light or dither under it.
- Glass stands in for an element's own back: its fill, and a picture laid over its whole back (a theme
  preview, an illustration) are left out, so a marketing card shows only its heading and controls. Choose
  elements whose content is the product's UI.
- One element each: a dialog, a field, a card, a code block. A long article is cut with `region` (CSS px).
- One element in several states (empty, typed, its results with a selection) is several assets with the same
  url, selector and `before`, and different `typing`. A field typed in one scene shows its text already
  typed in later scenes.
- `select: n` lifts the first n results under the first selected; the macro steps down to them and back up
  to the first, the camera following.
- Write every asset in one edit_motion call, then call capture_ui. Its reply gives each asset's size in CSS
  px, which views are measured in. Fix an asset it can't capture (its selector, its `before`) with set_asset,
  or drop it.

## 3. Shots

**`macro`**: most of the film. `ui` and `view`, or `items` [{ui, view}] for several stops in one shot.

- `view` [[x, y], [width, height]] is what the frame shows, in CSS px from the element's top-left corner,
  roughly in the frame's 16:9 shape. A smaller view is closer.
- Aim for the element's main text at 10–20 % of the frame's height: a 14–16 px font wants a view 80–160 px
  tall (the film: 77 for the empty bar, 144 while typing, 108 on the results, 154–200 on a page).
- Let the element run off the frame on one or two sides. A negative x or y shows the ground round its corner.
- For typing, frame the field's start, with room for the text and the results under it.
- Open on an empty field only when something in the frame reads: a placeholder, an icon, a toolbar. A
  mockup's box with nothing in it is a dark rectangle; open on its typing instead.

Reco does the rest:

- It frames each view, holds and creeps 3 % closer, and whips in 0.35 s to the next stop.
- The first scene opens on 1 s of its ground alone before the control cuts in. In light and dither the
  ground swells in from black, and the control arrives in the look's seam (0.9 s of light out of the
  ground's shape, 0.8 s of dots) instead of cutting in; typing waits for it.
- Typing starts 0.65 s after the control shows, at a person's pace: about 8 characters a second, slower
  into each word, with the results after each word.
- A selection steps down from 0.55 s, 0.47 s apart, then back up.

**`closing`**: always the end.

- `text`: the product's name.
- `items`: 5–9 of its words (its products or features, or what it is for).
- `detail`: its tagline, a few words.
- `ui`: the logo, an `img` or `svg` asset from its navigation.
- Duration: 0.42 s a word plus 4.5 s, and 1.6 s more with the logo.

## 4. Timing and seams

Scene lengths:

| Scene | Length |
|---|---|
| The opening macro | 3–3.5 s; 4–4.5 s in light and dither, where the control takes its seam to arrive |
| Typing | 1.2 s plus the text's characters / 7 |
| Results with a selection | 2.5–3 s |
| A tour | 1.5–2.5 s a stop, plus 0.35 s a whip |
| The closing | As above |

20–35 s in all.

Seams:

- **`cut`** between macros of the same element, cutting in closer or out wider: that is the look. A cut
  keeps the ground: in light and dither the scene after it has the same field as the one before.
- **`whip`** to another element or page: the camera streaks out of one scene and into the next.
- **The look's own seam** to another element or page, in the light and dither looks, for one or two of the
  scene changes (whips for the rest, and inside a macro's tour):
  - `glow` (light): a front of grainy light crosses the frame out of the next scene's field's shape (from
    `bloom`'s blob outwards, up from `sunlit`'s wave, in from `ember`'s corners), the next scene behind it; 0.9 s.
  - `dither` (dither): the frame turns to the brand's dots from its edges in, its UI drawn in them for a
    moment, then resolves into the next scene; 0.8 s.
- The closing comes in on a cut (satin), or on `ring` (light and dither): a ring of smoke opening from the
  middle, the closing inside it; 1 s.

## 5. The look and style

Choose one look from inspect_page's brand and what the product is, and keep the whole film in it:

| Look | Fields | Seams | For |
|---|---|---|---|
| Satin | `satin` | cut, whip | A brand without a hue (black, white, grey accent), or a dark UI whose colour is all in the UI |
| Light | `ember`, `sunlit`, `bloom`, `orb`, `ripple` | cut, whip, glow; ring into the closing | A brand with a clear hue: AI, design, creative and consumer products |
| Dither | `matrix`, `warp`, `swirl`, `tide` | cut, whip, dither; ring into the closing | A technical product with a brand colour: databases, APIs, infrastructure, developer platforms |

- Light and dither take their colour from `style.accent`: set it to the brand's colour, never a grey (a grey
  accent makes them grey: choose satin then).
- In the light and dither looks, give each scene after a whip or the look's seam its own field from the look's
  list (`field` on the scene), so the ground changes as the story moves on; a scene after a cut keeps the field
  before it:
  - the opening on one with its light in the middle, alone for its first second: `bloom`, `orb`, `matrix`;
  - the macros after it on ones that keep their light round the UI: `ember` (two corners), `sunlit` (rising
    from below), `ripple`, `warp`, `tide`, `swirl`.
- The closing is drawn on black in every look.
- canvas: `{"size": [1920, 1080], "frameRate": 30, "field": <the opening's field>, "background": "#000000", "pacing": "beats"}`.
- style:
  - `text` is a light grey such as `#ededed`, not white.
  - `dim`, `accent` and `face` come from inspect_page's brand.

A light film's scenes, for example (a dither film the same with its fields and `dither`):

```json
[{"id": "bar", "duration": 4.1, "field": "bloom", "shot": {"shot": "macro", "ui": "bar", "view": [[-40, -12], [140, 79]]}},
 {"id": "typed", "duration": 4.4, "field": "bloom", "seam": "cut", "shot": {"shot": "macro", "ui": "search", "view": [[-40, -40], [256, 144]]}},
 {"id": "page", "duration": 4.8, "field": "sunlit", "seam": "glow", "shot": {"shot": "macro", "items": [
   {"ui": "column", "view": [[-42, -69], [356, 200]]}, {"ui": "code", "view": [[-33, -32], [274, 154]]}]}},
 {"id": "closing", "duration": 9, "seam": "ring", "shot": {"shot": "closing", "text": "…", "items": [], "detail": "…", "ui": "logo"}}]
```

## 6. Check, then finish

Call preview_motion and look at every frame:

- Is it one control, large, running off the frame?
- Is its type readable: sharp, not tiny?
- Is any frame empty, or showing the wrong element?
- Did the typing and the results show?

Fix everything in one edit_motion call and preview again; stop after three previews. Then call
export_recording with the bundle, format h264, resolution 2160.

## Changing a film from the chat

1. Read the film first with edit_motion and no operations.
2. Change what the user asks and keep everything else:

   | They say | Do |
   |---|---|
   | "Closer" | A smaller view |
   | "Slower" | Durations × 1.5 |
   | "More motion" | Another stop in a macro, or a `whip` seam |
   | "Another look", "more colour" | Another look from section 5: every scene's field and the seams with it |
   | "Another moment" | A new asset, then capture_ui |

3. Preview once. Don't export unless asked.
