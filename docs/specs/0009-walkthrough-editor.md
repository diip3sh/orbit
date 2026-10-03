# 0009 — Walkthrough editor

Status: stages 1–2 built 2026-10-02 (`feat/ui-polish`); stages 3–6 planned. Builds on specs 0005 (web
recordings), 0006–0008 (agents).

## Idea

A web script knows the element behind every hover, click and keystroke, so a walkthrough's effects can
be exact instead of inferred: each is a property of a step, previewed in the Web Recording window with
Play, rendered by the editor's existing pipeline, and settable by an agent through `record_page`.

## Stage 1 — Zoom per step (built)

- `PointerClip.zoom` (`nil` = off; the inspector offers 1.5×, 2×, 3×; agents 1.25–4). The camera is in
  0.4 s before the clip and out 0.6 s after (`WebCamera.leadIn`, `hold`).
- **Preview:** `WebStage` scales and moves the page to the zoom's focus at the playhead
  (`WebStage.camera(for:)`), spring-animated; off while picking, since the web view's clicks don't follow
  a SwiftUI transform.
- **Render:** `WebPageRenderer.renderTake` writes `<movie>.edit.json` with `WebCamera.segments(for:telemetry:)`:
  one fixed `ZoomSegment` per zoomed clip, centred where the take's cursor was on its target, windows that
  meet handing over so the view pans. A script without zooms writes no project, so the editor auto-zooms
  it as before.
- **Agents:** `steps[].zoom` in `record_page`; the prompt asks agents to zoom on what a viewer should see.

## Stage 2 — Type (built)

- `PointerClip.Action.type` with `text`: the cursor goes to the field, clicks it (focus), then the text
  appears evenly from 0.2 s in to 0.1 s before the end (`typedText(at:)`). Its length defaults to
  `typingDuration(for:)`: 0.08 s a letter, at least 1 s.
- `WebTypingScript` sets the text in an isolated content world, where `value =` reaches the native setter
  past framework wrappers (React's value tracker), then fires `input`. The take sends only changed fields
  each frame; the preview sets every type clip's field at the playhead (empty before it starts).
- Window: **Type** in the timeline header, Type in the inspector's Action with a Text field, clips show
  “their text”. Agents: `{"action":"type","selector":…,"text":…}`, at most 500 characters.
- Measured 2026-10-02: a WebKit test types into an `<input>` and a contenteditable and the page hears one
  `input` each; a real render of wikipedia.org typed "Screen recording" into `#searchInput` letter by
  letter, with both 2× zooms in the `.edit.json`.

## Planned

| Stage | What |
|---|---|
| 3 | Spotlight (dim all but the target), highlight outline, per-click effect, drawn by the editor's overlays |
| 4 | Captions and callouts per step, then narration (on-device speech) and chapters |
| 5 | Browser frame, speed ramps, 9:16 follow-camera export |
| 6 | Agents set all of it through `record_page` |

Not yet: keystroke telemetry for typed text (the editor's keystroke chip doesn't show typing), Key and
Wait actions, a camera lane for zooms independent of clips.
