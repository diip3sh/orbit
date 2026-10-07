# Scripted web recordings

> Record a web page from a script: hovers, clicks and scrolls placed on a timeline, rendered frame
> by frame at 60 fps, then finished in the editor like any recording. N22 in spec 0004.

## Why

Designers show interactive work (hover states, scroll-driven animations, transitions) as videos.
Recording one by hand takes many takes: the cursor wobbles, scrolls stutter, and a slow page drops
frames. Tino Zabinskiy's recorder (Sep 2026) scripts the take instead. None of the 14 apps surveyed
in spec 0004 can.

We can do it better than a plain renderer because the result is also a recording: a movie plus a
telemetry sidecar with the cursor, clicks and cursor shapes, all exact. Auto-zoom, the smoothed
cursor, click highlights, the canvas and export then work unchanged, and the zooms land exactly on
the clicks.

## Expected outcome

- **New Web Recording…** in the menu bar opens a window with:
  - the page, at a viewport preset;
  - a timeline with a Cursor lane (Hover and Click clips) and a Scroll lane;
  - an inspector for the selected clip.
- Clip targets are picked by clicking an element in the page. Scroll clips end where the page is
  scrolled to.
- **Render** writes `Reco_Web_<date>.mov` and its `.telemetry.json` into the output folder
  at 1× or 2× and 60 fps, then opens the recording in the editor.
- Every frame advances the page's clock exactly 1/60 s, however long the frame takes to render, so
  the video never drops or stretches a frame.

## Measured (prototype, M5, macOS 26.5.2)

A command-line prototype drove a `WKWebView` in an offscreen window.

- **Hover needs a drag event.** WebKit hit-tests a mouse move only when the page's window is
  active; otherwise the move goes to scrollbars alone (`WebPage.cpp`, `handleMouseEvent`), so
  `:hover` and `mousemove` never happen. A `rightMouseDragged` event gets the full hit test even in a
  window that isn't key. On a test page:
  - `:hover` applied at once, and `mousemove` fired.
  - The page saw `buttons: 0`, since WebKit reads the real button state. No `pointerdown`,
    `contextmenu`, `dragstart` or `selectstart` fired.
  - A later `mouseDown`/`mouseUp` pair fired pointerdown, mousedown, pointerup, mouseup and click.
  - The next `evaluateJavaScript` already saw the move: events and scripts arrive in order.
- **Visibility.** An offscreen window (or one at alpha 0) counts as occluded, so WebKit marks the page
  hidden: `document.hidden` is true, `requestAnimationFrame` stops, and pages pause their media and
  carousels (apple.com did). An `NSWindow` subclass whose `occlusionState` returns `.visible` makes
  the page visible while the window stays offscreen, off every display.
- **Clock.** A `WKUserScript` at document start replaces `requestAnimationFrame`, the timers, `Date`
  and `performance.now` with a clock of its own, and pauses and seeks every `document.getAnimations()`
  entry (CSS animations and transitions).
  - The clock follows real time until the render starts, then moves only when told. A clock frozen
    from the start broke linear.app ("This page couldn't load"); following real time while loading
    fixed it.
  - A 300 ms `:hover` transition read exactly halfway after 150 ms of the clock (rgb 128, 0, 128).
  - A frozen page is the same frame for frame across renders. Pages that load while playing
    (lazy images, network) aren't: apple.com matched 0 of 60 frames between two renders.
- **Snapshots** (`takeSnapshot(with:)`, 1440×900 viewport) are painted on the CPU, so they cost more
  with pixels and effects:

  | Page | 2× (2880×1800) p50 | 1× p50 |
  |---|---|---|
  | Test page | 14 ms | — |
  | apple.com/macbook-pro | 35 ms | — |
  | linear.app | 310 ms | 64 ms |

  So a 30 s video takes 30 s to 9 min to render. Snapshots include images and video frames.
- **End to end** (the app's renderer, in its sandbox): a 3 s take of apple.com/macbook-pro at 2×,
  180 frames, took 8.5 s. That includes about 2 s of loading and settling, so roughly 36 ms a frame.
  The editor's loader opened it with its telemetry, and auto-zoom placed a zoom on its click.
- **Through the window's view model** (its intents, targets picked by real mouse events in the
  preview): a 6 s take of apple.com/macbook-pro at 2×, hovering, clicking Buy (which opens the
  store) and scrolling the store page, rendered 360 frames in 17.8 s into the output folder. The
  editor opened it with one automatic zoom on the click, and exported it in 3.5 s.

## Approach

A feature folder, `Reco/WebRecording/{Model,Service,ViewModel,View}`.

### Script (`Model/`, pure)

- `WebScript`:
  - the URL, viewport (CSS px), scale (1× or 2×) and duration;
  - `pointer`, the Cursor lane's clips;
  - `scrolls`, the Scroll lane's clips.
- Clips have an `id` and a time `range`. Each lane's clips are sorted and apart, and edited through
  the same operations as zooms (`TimelineClip`, shared with `ZoomSegment`).
- **Pointer clip:** Hover or Click, and a target.
  - The cursor arrives at the target at the clip's start and stays until its end, following the
    element if the page moves it. A click presses at the start and releases 0.1 s later; the page's
    `click` fires on the release.
  - After a clip the cursor rests where it was, as a real mouse does while the page scrolls under
    it. Following the element instead flew the cursor off the top of the page as it scrolled.
  - Between clips it travels from where it rested on a gentle arc, eased in and out, ending at the
    next clip's start and taking the gap up to 1 s.
  - Before the first clip, it waits in the middle of the view, then travels to the first target
    (spec 0008: the take opens wide, and the first stop is an arrival the editor zooms on).
- **Target:** a CSS selector made when the user picks an element, the point picked within its box (as
  fractions), and the picked point in the viewport, used when the selector matches nothing.
- **Scroll clip:** where the page is scrolled to at its end, and an easing (linear, ease in, ease out,
  ease in-out: CSS's cubic Béziers). It starts from where the previous clip ended, or the top, so the
  page never jumps.
- `WebScript` answers, for any time:
  - the scroll offset;
  - where the cursor is: following a target, resting after one, or travelling between two with
    its progress;
  - which presses happen between two times.
- `PointerTrack` turns that into a location frame by frame. It needs the targets' element frames
  now, and remembers where the cursor rested.
- The last script is kept in Application Support, so the window reopens with it.

### Render (`Service/`)

`WebPageRenderer` (main actor, WebKit's thread) does a take:

1. A fresh `WKWebView` in an offscreen window, visible to WebKit through the `occlusionState`
   override, loads the URL with the clock script.
2. When the page has loaded and settled for 1 s, the clock freezes.
3. For each frame `n` at `t = n / 60`:
   1. **Advance:** one call moves the clock to `t`, runs due timers, animation frames and animations,
      scrolls to the timeline's offset, waits for a real rendering update (so intersection observers
      fire), waits for images in view and fonts to load, and returns the targets' rectangles (none
      for an element that isn't rendered, so the cursor goes to the target's point). The wait is up
      to 5 s, and what misses it isn't waited for again: an image that never loaded cost the first
      frame 5 s and the other 59 frames 1 s in all, not 5 s each.
   2. **Pointer:** the cursor's position comes from the timeline and the rectangles. A
      `rightMouseDragged` goes to the web view if the cursor moved or the page scrolled or changed
      under it (WebKit's own move after a scroll needs an active window), and a press or release if
      one is due. A second call pauses any animation those started (hover transitions) at the
      current time and returns the element's CSS `cursor`.
   3. **Snapshot** at the scale, appended to the movie at `n / 60` s.
   A click that opens another page makes the next frame find the old one gone. That frame waits,
   off the clock, for the new page to load and settle, so the movie cuts straight to it. No frame
   call goes into a page that's loading, and one still in flight when a new page commits is ended:
   WebKit fails a call into a page that went away only once it's garbage collected, 106 s after a
   click opened the Apple Store.
   4. **Telemetry:** the cursor sample, clicks, and the cursor shape (`pointer` → pointing hand,
      `text` → I-beam, else arrow) when it changed.
4. The movie is HEVC, SDR tagged BT.709, at the high quality setting's bitrate. `WebMovieWriter`
   writes it off the main actor.

The clock steps an animation by pausing it and setting its time, which hides the page's own pauses,
so they're kept: `pause()` and `play()` calls, and CSS `animation-play-state` (a marquee that stops on
hover). The page is muted (`WebMuteScript`): media elements, and Web Audio through a silent gain. A
web content process that quits fails the take with "The page crashed."

**Telemetry** (version 3):
- `capture.kind` is the new `web`, `videoSize` is the viewport times the scale, and `cursorInVideo`
  is false.
- Locations are viewport CSS pixels. One `geometry` entry maps them to the video: the viewport as
  both `screenRect` and `contentRect`, `contentScale` 1 and `scaleFactor` the scale.
- `keystrokesAvailable` is true with no keys: nothing was typed.

### Window (`ViewModel/`, `View/`)

- **Page:** a live `WKWebView` the user browses, shown at the viewport's CSS size through
  `pageZoom`, so it lays out as the render will.
  - **Pick** outlines the element under the pointer. A click makes it the selected clip's target
    instead of reaching the page. The page gets no pointer events meanwhile, so classes it adds on
    hover stay out of the selector.
- **Timeline:** the editor's ruler, playhead and clip look (`TimelineRuler`, `Playhead`, blocks like
  `ZoomBlock`). Clips are dragged to move and resized by their handles. ⌫ deletes, ⌘Z undoes.
  **Hover**, **Click** and **Scroll** add a clip at the playhead.
- **Inspector:**
  - With a clip selected: its target and Pick, or its scroll position and Use Current Scroll; start
    and length; easing.
  - Otherwise: the URL, viewport preset, scale and duration.
- **Render** shows progress, can be cancelled, and opens the editor when done.

## Phases

1. **Core** (done): script, timeline, easing, `PointerTrack`, and the lane operations shared with
   zooms (`TimelineClip`), with tests.
2. **Render** (done): the clock script, renderer, writer and telemetry. Tested by rendering a local
   page with a hover and a click and checking the movie's frames and the telemetry.
3. **Window** (built, not yet tried by hand): page, pick, timeline, inspector, render, and
   **New Web Recording…** in the menu bar. The timeline's lanes and blocks are the editor's zoom
   lane made generic (`TimelineLane`, `TimelineBlock`).
4. **Later:**
   - playing the script in the page;
   - custom Bézier easing;
   - element scroll containers and horizontal scrolls;
   - `<video>` elements seeked to the clock;
   - iframes;
   - typing;
   - rendering in parallel web views;
   - Mac apps driven by posted `CGEvent`s.

## Verify

- `WebScriptTests`:
  - scroll offsets at a clip's ends and eased in between;
  - the chain between scroll clips;
  - the cursor's arrival, rest and travel, and presses in ranges;
  - the cursor resting while the page scrolls the target away.
- `WebPageRendererTests`, on a local page:
  - the movie has `duration × 60` frames at the right size;
  - a hovered button is exactly half-way through its 300 ms transition at frame 9;
  - the page reacts to the click on its release frame, and the scroll reaches its band, which is
    hovered once it passes under the resting cursor;
  - the telemetry's clicks land on the button's centre, and the cursor shape is the pointing hand
    over it and the arrow once the page scrolls it away;
  - animations the page pauses on hover, by CSS and by script, hold while hovered;
  - a hidden target puts the cursor on its point, and the page's media is muted.
- `WebPreviewControllerTests`: pick mode leaves out classes the page adds on hover; the preview
  places a hidden target at its point.
- `WebRecordingViewModelTests`: addresses, adding, picking, moving, undoing (back to no page), the
  length's limits, and the script kept between launches.
- `EditCoalescingTests`: which edits share an undo step.
- In the app: a script on a real site renders and opens in the editor, and auto-zoom lands on its
  clicks.

## Open questions

1. **Heavy pages:** linear.app takes about 310 ms a frame at 2×. Is a parallel render (several web
   views, each a slice) worth its complexity, or is 1× enough?
2. **Repeatability:** pages that load as they play differ between renders. Should Render first
   scroll through the whole page to load everything?
3. **Mac apps:** play the same timeline on a native app in real time with posted `CGEvent`s, aimed at
   screen points (no Accessibility)?
