---
name: product-walkthrough
description: Record a product walkthrough video of a website with an agent — research the product, plan the beats, decide what the camera frames, then record. Portable: the method and the rules the recorder must implement, with the numbers that were measured to work.
---

# Product walkthrough: what to shoot, where to zoom

A walkthrough made by an agent fails in one of three ways: it doesn't know what the product is
(so it hovers whatever the home page lists), it has no story (so it jumps around), or the camera
zooms on the wrong things (headings, navigation, empty space). This skill fixes all three with one
rule: **the zoom is a decision in the plan, not a side effect of where the cursor stopped.**

It has two parts. Part 1 is the method the agent follows. Part 2 is what the recorder has to
implement so the method can work (the `show` step, zoom fitting, navigation rules). Numbers are the
ones measured on real takes (linear.app, apple.com, 1440×900 viewport).

---

## Part 1 — The method (give this to the agent)

### 1. Research. Don't record anything until you can say in one sentence what the product is for.

- Inspect the page you were given, then the two to four pages its **product or features
  navigation** links to (use their `href`). A page's **meta description and headings** say what
  it shows.
- If you have web search or fetch, read the product's features or docs page too, and what a
  review names as its best features.
- Output of this step: one sentence on what the product is, and the three features that matter
  most, each with the page or section that shows it best.

### 2. Plan. Write a shot list of four to six beats that tell one story.

| Beat | What it is | Typical length |
|---|---|---|
| 1 | What the product is: the hero (headline + product screenshot) | 3–5 s |
| 2–4 | The two or three strongest features, each on its own page or section | 6–10 s each |
| 5 | The call to action | 3 s |

For every beat write down:
- **the one element the viewer should see** — a product screenshot, a feature card, a short
  heading *with its text*. Not a nav item, not a decorative image, not empty space.
- **the page it is on** and **how to get there** — a click on the link that opens the page, or a
  scroll to the section.

Rules of thumb that fixed real takes:
- Show **the thing itself, not the heading above it**. A heading is only worth framing when it is
  the message (a hero tagline, the CTA line).
- Show **the hero or a whole section when you want to stay zoomed out**. A full-width element
  means "no zoom here" — that is a legitimate beat, not a failure.
- One feature page is not a walkthrough. Visit at least two.
- Never park the cursor on the navigation while a page loads.

### 3. Record. One or two steps per beat, every step with a `show`.

- `show` = the element the video zooms on during that step. The video zooms on nothing else.
- Hover **something in or beside what you show** for 2–3 s, so the shown element is in view when
  the step starts. (The recorder scrolls the *hovered* element into view, not the shown one.)
- To open a page: click its link, then hover that page's hero with `show` on it.
- Pacing: 1 s still at the start, 0.8–1 s between steps for the cursor to travel, 1.5–3 s per
  hover or click, 1.5–3 s per scroll, 45–60 s in all unless asked otherwise.
- Scale 2 (device pixel ratio 2): it stays sharp when the video zooms in 2–3×; takes at scale 1
  come out blurred as soon as the camera moves in. Drop to 1 only when the recorder's render cost
  says a minute at 2× takes more than ~8 minutes (a very heavy page).
- If the result has warnings, fix those steps and record **once more, only once**. Then stop and
  report whatever the second result says. (Unbounded retries loop forever on a page that can't be
  fixed by re-recording.)
- Reply in one or two sentences saying what the video shows, without paths or selectors.

### Step shape (what a plan turns into)

```json
{
  "url": "https://example.com",
  "scale": 1,
  "steps": [
    { "action": "hover", "selector": "h1.hero",          "show": "section.hero",         "duration": 3 },
    { "action": "hover", "selector": "h3.card-1-title",  "show": "figure.card-1",        "duration": 2.5 },
    { "action": "click", "selector": "a[href='/plan']",  "show": "a[href='/plan']" },
    { "action": "hover", "selector": "h1.plan-hero",     "show": "h1.plan-hero",         "duration": 2.5 },
    { "action": "scroll", "selector": "section.forecast" },
    { "action": "hover", "selector": "figcaption.forecast", "show": "figure.forecast",   "duration": 3 },
    { "action": "hover", "selector": "a.cta",            "show": "h2.cta-heading",       "duration": 2.5 }
  ]
}
```

---

## Part 2 — What the recorder must implement

The method only works if the recorder makes `show` mean something exact. These are the rules Reco
implements; port them, the numbers included.

### A. Zoom from `show`, not from cursor rests

Auto-zoom from telemetry ("zoom where the cursor stopped") is fine for human screen recordings
and wrong for agent takes: the agent can only stop the cursor on hoverable elements, and the
interesting pixels are usually elsewhere (the screenshot under the heading). So:

- Each cursor step (hover / click / type) takes an optional `show` selector.
- **Once any step has `show`, zooms come only from `show` steps.** Steps without it don't zoom.
  Mixed mode (some from the plan, some from rests) gives the agent no way to say "no zoom here".
- Measure the shown element's box **where its step starts**, in viewport coordinates, after the
  recorder's own scroll-into-view for the hovered element has finished.
- Save the zooms with the take (Reco writes the editor project next to the movie), so the editor
  opens with them and never regenerates over them.

### B. Fitting the zoom

```
visible   = element box ∩ viewport
scale     = min(3, 0.8 × viewport.width / visible.width, 0.8 × viewport.height / visible.height)
if scale < 1.1 → no zoom (the element is nearly the whole view)
center    = visible's midpoint as fractions of the video, clamped so the view stays inside the frame
```

- **0.8** — the element fills at most 80% of the view, so it has room around it.
- **3×** — the most a page rendered at 2× stays sharp. At 1× render, 3× is already soft; prefer 2×
  scale for text-heavy shots or render at 2×.
- **1.1** — below this a zoom is a wobble, not a zoom; drop it.
- Less than **50%** of the element in view → don't frame it; report it (see D).

### C. When a zoom ends

- At its step's end, **or 0.3 s after the page starts to scroll or is replaced under it**. 0.3 s
  is about how long the camera spring takes to start moving out, so the scroll shows the page at
  full size instead of a magnified blur sliding past.
- **If the page scrolls or changes within 0.5 s of the zoom's start, make no zoom at all.** 0.5 s
  is the camera's lead time (the spring finishes 96% of a move in 0.5 s): a click that opens a page
  would zoom in and straight back out — a visible jolt. Drop it.
- If the next zoom starts within **1 s**, extend this one to the next one's start, so the view
  pans across instead of zooming out and in.
- Zooms never overlap; cursor steps don't overlap, so a zoom never reaches past the next step's
  start.

### D. Warnings the agent can act on

Check each step where it starts, the way Playwright checks an action's target, and report once per
selector and kind:
- the hovered element is missing / outside the view / covered by something else (say by what);
- a click's element is missing, so the click was left out;
- a scroll's element is missing, so the page didn't move;
- **the shown element wasn't on the page or mostly in view, so the video doesn't zoom there** —
  "Scroll to it first, or show an element in view then."

Each message carries the time ("At 12.5 s …") so the agent can map it to a step.

### E. Navigation rules (both bit us)

- **A page a click opens shows from its top.** The script's scroll offset belonged to the previous
  page; zero it when the URL changes. Before this, linear.app/plan opened 3,774 px down and then
  scrolled up to its hero.
- **A link to an anchor is not a navigation.** Compare URLs without the fragment, or the reset
  above breaks in-page links.
- Record navigations (time + URL) in the take's telemetry. Any zoom from cursor rests must end at
  a navigation as at a scroll, so a zoom on a nav link doesn't hang over the page it opened.
- Render frames wait, off the page's clock, while the new page loads; a frame call still in flight
  when the new page commits must be ended, not awaited.

### F. Defaults that read well

| Thing | Value |
|---|---|
| First step starts | 1.0 s |
| Gap between steps (cursor travel) | 0.8 s (Fitts's law: ~0.96 s for an 800 px move to a 40 px target) |
| Hover / click default length | 1.5 s (2–3 s in walkthroughs, so the viewer can read) |
| Scroll default length | 2.0 s |
| Render scale | 2 by default; 1 only when render cost at 2 > 8 s per video second |
| Tail after the last step | 1.5 s |
| Scroll-into-view before a hover | ≤ 1 s, ends 15% from the viewport edge, only when there's ≥ 0.2 s of room |
| Scroll zoom hold | 0.3 s |
| Camera lead time | 0.5 s |
| Pan-across merge gap | 1.0 s |
| Typing | first key 0.3 s after the click, 0.08 s per key (12/s), 0.8 s to read it after |

### G. Give the agent research it can use

- `inspect_page` should return the page's **meta / Open Graph description** and its headings with
  text, plus a link's `href`, so the agent can learn what each page shows and follow the product
  navigation without guessing URLs.
- Scroll the page down and back before reading it (0.8 viewport steps, 100 ms each) so lazy
  sections and images are listed and cached.
- If the agent runtime allows it, enable read-only web search and fetch for the research step and
  nothing else (no shell, no writes).

### H. Run hygiene

- Cap re-records at one in the prompt *and* consider capping them in the app; an agent on a page
  with a persistent warning will otherwise re-record forever.
- Measure the render cost per page and return it from inspection (one snapshot at each scale, ×
  frame rate = seconds of rendering per second of video), so the agent picks scale 2 by default and
  1 only where it must. CPU page snapshots cost 14 ms (simple page) to 310 ms (linear.app at 2×)
  per frame; supabase.com is 43 ms at 2×, so a minute renders in under 3 minutes.

---

## Checklist before you call a walkthrough done

- [ ] The agent stated what the product is before recording.
- [ ] Four to six beats; at least two feature pages or sections; ends on the CTA.
- [ ] Every cursor step has a `show`; shown things are screenshots, cards or the message, not nav.
- [ ] No zoom on a click that opens a page; the opened page starts at its top.
- [ ] No warnings on the final take, or the second take's warnings were reported honestly.
- [ ] Check the frames (a contact sheet at each beat), not the summary.
