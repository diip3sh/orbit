# 0009 — Walkthrough editor

Status: stages 1–2 built 2026-10-02 (`feat/ui-polish`), show steps 2026-10-06 (`feat/walkthrough-show`);
stages 3–6 planned. Builds on specs 0005 (web recordings), 0006–0008 (agents).

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
- **Agents:** replaced by show steps (below); `record_page` no longer takes `zoom`. The window keeps it.

## Stage 2 — Type (built)

- `PointerClip.Action.type` with `text`: the cursor goes to the field, clicks it (focus), then the first
  letter comes 0.3 s later and one every 0.08 s, faster when the clip is too short, ending at least 0.1 s
  before it (`typedText(at:)`). Its length defaults to `typingDuration(for:)`: 0.3 s, 0.08 s a letter and
  0.8 s to read it, at least 1 s.
- `WebTypingScript` sets the text in an isolated content world, where `value =` reaches the native setter
  past framework wrappers (React's value tracker), then fires `input`. The take sends only changed fields
  each frame; the preview sets every type clip's field at the playhead (empty before it starts).
- Window: **Type** in the timeline header, Type in the inspector's Action with a Text field, clips show
  “their text”. Agents: `{"action":"type","selector":…,"text":…}`, at most 500 characters.
- Measured 2026-10-02: a WebKit test types into an `<input>` and a contenteditable and the page hears one
  `input` each; a real render of wikipedia.org typed "Screen recording" into `#searchInput` letter by
  letter, with both 2× zooms in the `.edit.json`.

## Show steps and the walkthrough method (built)

Agent walkthroughs failed three ways: the agent didn't know what the product was, had no story, or the
camera zoomed on headings, navigation and empty space, because auto-zoom follows where the cursor stops and
an agent can only stop it on hoverable elements. So the zoom is a decision in the plan.

- **Method** (`AgentRecordingRequest.prompt`, `AgentToolCatalog.instructions`): research what the product is
  (the page, the two to four product pages its navigation links to, web search when the agent has it:
  Claude Code runs get read-only `WebSearch` and `WebFetch`); plan four to six beats (hero, two or three
  features on their own pages or sections, the call to action), each with the one element to see; record
  one or two steps a beat, every cursor step with a `show`. Re-record once on warnings, then report.
  `AgentTools` refuses a third `record_page` in a run Reco started (`maximumRecordings`).
- **`show`** (`PointerClip.show`, `record_page` `steps[].show`): a selector for what the video zooms on during
  a hover, click or type. Once any clip has one, only show clips zoom (`WebCamera.showsElements`), so a step
  without one means "no zoom here"; a take with show steps always writes `<movie>.edit.json`, empty or not,
  so the editor never auto-zooms over it.
- **Measured where the step starts** (`WebPageRenderer.play`), after the scroll that brought the hovered
  element into view. Less than half of it in view (`WebCamera.visiblePart`) → no zoom and a warning.
- **Fitting** (`WebCamera.fit`): scale = min(3, 0.8 × view ÷ element) on each axis, none under 1.1 (nearly the
  whole view: a hero or full-width section is a beat without zoom); centre clamped inside the frame.
  3× is as far as a 2× render stays sharp; 1× is soft at 3×.
- **Timing** (`WebCamera.showSegments`, `PageChanges`): a zoom lasts its step; one ending under 1 s before the
  next is held until it (`panGap`), so the view pans across; then each ends 0.3 s after the page starts to
  scroll or is replaced (`PageChanges.hold`: the spring starting out, so the scroll shows the page whole), and
  one the page changes under within 0.5 s of its start isn't made (`leadTime`: the spring finishes 96% of a
  move in 0.5 s, so a click that opens a page would zoom in and straight out). Web takes' auto-zooms end at
  page changes by the same rule (`AutoZoomGenerator`).
- **Scrolling** (`RecordPlan.script(page:)`, `ScrollClip.Target`): before each cursor step Reco adds a scroll
  of at most 1 s (`intoViewDuration`) that brings its element 15% clear of the view's edges, when the Scroll
  lane has 0.2 s of room after the previous step; it stays put when the element is clear already. Scrolls
  to an element aim again as they start in the take, at the page as it is then. Steps after a click may be
  on another page, so their elements are found when the take gets there; a click or scroll whose element
  the first page lacks is an error before rendering.
- **Navigation** (`WebPageRenderer.Take`): a page a click opens shows from its top (the scrolls that started
  before belonged to the page it replaced; without this, linear.app/plan opened 3,774 px down, as reported
  with the method). URLs are
  compared without their fragment, so a link to an anchor isn't a navigation. Navigations go into the
  telemetry (`navigations`), and scrolling too, as a wheel would report it.
- **Warnings** (`WebTakeIssues`, `RenderStatus.warnings`): each step checked where it starts, once per
  selector and kind, with its time: a hovered element missing, outside the view (the cursor stops at the
  edge, `PointerTrack`) or covered (named, from `elementFromPoint`); a click's element missing, so the click
  is left out; a scroll's element missing, so the page didn't move; a shown element missing or mostly out
  of view. A staged plan (the chat) reports what the first page lacks.
- **Research** (`WebInspectScript`): `inspect_page` and `open_page` return the meta or Open Graph description
  and links' `href`, after scrolling the page down and back (0.8 of the view a step, 100 ms each) so lazy
  sections are listed and cached.
- **Defaults** (`RecordPlan`): first step at 1 s, 0.8 s between steps (Fitts's law puts an 800 px move to a
  40 px target at ~0.96 s), 1.5 s a hover or click, 2 s a scroll, 1.5 s after the last; scale 1, since a
  minute of a heavy page takes 15+ minutes at 2×.
- **Window:** the inspector's Show field; Play frames the shown element as the take will
  (`WebStage.camera(for:)`, from `WebPreviewController.show`), without the page-change rules.

Not yet: a real agent run with show steps on a product site, checked frame by frame.

## Planned

| Stage | What |
|---|---|
| 3 | Spotlight (dim all but the target), highlight outline, per-click effect, drawn by the editor's overlays |
| 4 | Captions and callouts per step, then narration (on-device speech) and chapters |
| 5 | Browser frame, speed ramps, 9:16 follow-camera export |
| 6 | Agents set all of it through `record_page` |

Not yet: keystroke telemetry for typed text (the editor's keystroke chip doesn't show typing), Key and
Wait actions, a camera lane for zooms independent of clips.
