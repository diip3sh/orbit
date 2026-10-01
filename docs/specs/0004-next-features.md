# Next features

> What to build after the editor, ranked. From a September 2026 survey of 14 recorders and
> screenshot tools and of Apple's on-device frameworks.

## Why

The editor (spec 0003) covers Screen Studio's core loop: auto-zoom, a smoothed cursor, click and key
overlays, the canvas and export. What's still missing is of two kinds:

- **Common:** what four or more of the surveyed apps ship. Captions (9 apps), a camera track (7),
  motion blur (6), speed changes (6), blur masks (6), voice cleanup (6), GIF (5), crop (5), and
  silence and filler removal (5).
- **Ours:** what our telemetry makes exact. We have the cursor at 60 Hz, every click, key and scroll,
  and the cursor's images; other apps guess these from pixels.

Everything here stays on-device, sandboxed and free of third-party code. It uses Apple frameworks,
measured below on an M5 running macOS 26.5.

## Expected outcome

- Zooms and cursor moves look like Screen Studio's: motion blur, a cursor that loops, click sounds.
- A talk-over recording gets captions, cleaner audio and suggested cuts for silences and "um"s.
  Typing parts can be sped up with one click.
- Private details can be masked by hand or found automatically.
- Recordings export as GIFs, can be cropped, and fill vertical and square canvases.
- Screenshots can be annotated and given a background, and a closed card can be brought back.
- A web page can be recorded from a script: scrolls, hovers and clicks on a timeline, rendered
  frame by frame at 2× and 60 fps, then finished in the editor like any recording.

## Plan at a glance

Sizes as in spec 0003: S is up to a day, M a few days, L a week or more. Items marked L get their
own spec before any code.

| # | Feature | Area | Size | Needs | Evidence |
|---|---|---|---|---|---|
| N1 | Motion blur on camera and cursor | Editor | M | — | Screen Studio (headline), Canvid (on by default), FocuSee, Screenize, OpenScreen |
| N2 | Cursor: loop to start, stop before end, tilt | Editor | S | — | Screen Studio, FocuSee 2.5, Canvid 3.0, open-recorder |
| N3 | Click sounds | Editor | S | — | Screen Studio 3.3, FocuSee |
| N4 | Enhance voice (noise removal) | Editor | S–M | — | 6 apps; Screen Studio 3.7.1, Cap Studio Sound |
| N5 | Transcript and captions, SRT/VTT | Editor | L | macOS 26 | 9 apps; Screen Studio added Apple's engine in 3.5 |
| N6 | Remove silences and filler words | Editor | M | N5 for fillers | Descript, Loom, Tella, FocuSee, Cap |
| N7 | Speed per part, speed up typing | Editor | L | — | Screen Studio's signature; FocuSee "Smart Pacing" |
| N8 | Masks: blur, pixelate, spotlight | Editor | M | — | 6 apps |
| N9 | Find sensitive info | Editor, card | M | N8 | Xnapper, Snagit, Canvid |
| N10 | GIF export, copy frame | Editor | M | — | 5 apps; Screen Studio 3.6 copies frames |
| N11 | Crop | Editor | M | — | 5 apps |
| N12 | Fill vertical and square canvases | Editor | M | — | Screen Studio, Canvid, Rapidemo |
| N13 | Annotate screenshots | Card | L | — | Every screenshot app; the card reserves the slot |
| N14 | Screenshot backgrounds, auto balance | Card | M | — | Xnapper's whole product; CleanShot headline |
| N15 | Restore a closed card; history | Card | S / M | — | CleanShot, Snagit |
| N16 | Small capture wins | Screenshots | S each | — | CleanShot, Shottr, Snagit |
| N17 | Freeze screen and loupe while selecting | Screenshots | M | — | CleanShot |
| N18 | Scrolling capture | Screenshots | L | — | CleanShot, Shottr, Snagit (all headline) |
| N19 | Camera as its own track | Recorder, editor | L | — | 7 apps |
| N20 | Cancel and restart a recording | Recorder | S | — | Loom |
| N21 | Hide desktop icons in recordings | Recorder | S | check first | CleanShot, Screen Studio |
| N22 | Scripted web recordings | New mode | L+ | — | Tino Zabinskiy's recorder (Sep 2026); none of the surveyed apps |

## Order

1. **Motion (N1–N3).** The biggest visible step. It uses data we already have and needs no new
   permission.
   - **Scripted web recordings (N22)** can run in parallel as their own track. Everything after its
     render step is the editor we have, and N1 and N2 make its output better.
2. **Voice (N4–N6).** N4 first: it works on macOS 15 and is nearly free. Then the transcript, which
   N6 builds on.
3. **Pace (N7).** Changes `TimeMap`, so it goes after the features that add cuts.
4. **Privacy (N8, N9).**
5. **Output (N10–N12).**
6. **Screenshots (N13–N18).** N13, N14 and N15 make the card complete; scrolling capture comes last.
7. **Camera (N19).**

N20 and N21 are small and can land any time.

Every item follows spec 0003's standards: a pure core with tests, performance measured before a
claim, docs updated, and the 8 ms frame budget kept.

## Items

### N1 — Motion blur on camera and cursor

- **What:** blur along the view's movement while it zooms or pans, and along the cursor's path.
  There is one amount each, in the Zoom and Cursor sections. Screen Studio has three sliders
  (cursor, zoom-in, pan); start with two.
- **How:** while the camera moves, `FrameRenderer` draws the source frame 8 times at camera
  transforms sampled across the shutter interval and averages them (`CIColorMatrix` at 1/8, then
  `CIAdditionCompositing`). When it barely moves, it draws once, so frames without a zoom stay the
  source's pixels exactly. `CameraPath` is already sampled at 120 Hz. The cursor works the same way
  with `CursorPath` positions.
- **Measured** at 4K with a Metal `CIContext`:
  - The 8-sample average took about 1.6 ms, against 2.2 ms for a plain passthrough in the same run,
    so re-measure it in our renderer.
  - `CIMotionBlur` took 6–7 ms p50, and `CIZoomBlur` about 10 ms, over the budget on its own. Don't
    use either.
  - The cost inside band-by-band rendering (`CanvasLayout.regions`) is unmeasured.
- **Verify:**
  - A still frame is byte-identical to today's.
  - A frame mid-zoom is blurred along the motion.
  - 4K p95 stays under 8 ms on an M1.

### N2 — Cursor: loop to start, stop before end, tilt

- **What:**
  - *Loop:* in the last second, the cursor glides back to where it was in the first frame, so a
    video or GIF loops.
  - *Stop before end:* the cursor holds still for the last N seconds, which hides the reach for
    Stop.
  - *Tilt:* the arrow leans a little in the direction it moves.
- **How:** three `CursorStyle` settings, applied in `CursorPath` (pure). Tilt is a rotation about
  the hotspot in `FrameRenderer`.
- **Verify:** `CursorPath` tests. The last frame's position equals the first's, and tilt is zero at
  rest.

### N3 — Click sounds

- **What:** a soft click at every recorded press, with a volume control in the Clicks section.
- **How:** mix the clicks offline, once per cut change, into a cached file. Use `AVAudioEngine`
  manual rendering, as N4 does, placing clicks through `TimeMap`, and add the file as one extra
  composition track under the existing `AVAudioMix`. Inserting a sound asset 3,000 times into the
  composition would slow every rebuild. The sound must be our own recording.
- **Verify:** in an export, the click onsets land within one audio buffer of the telemetry click
  times.

### N4 — Enhance voice

- **What:** an Enhance Voice switch on the microphone track in the Audio section.
- **How:** `AUSoundIsolation` (macOS 13; `kAUSoundIsolationSoundType_HighQualityVoice` on macOS 15),
  as an `AVAudioUnitEffect` in an offline `AVAudioEngine`. Render the mic track once to a cached
  file and swap it into the composition.
- **Measured:**
  - 7.2 s of 48 kHz audio took 0.08 s.
  - The noise-only RMS went from 0.0162 to 0.0005 with the Voice type, and to 0.0038 with
    HighQualityVoice.
  - It works in the sandbox.
- **Not used:** voice processing I/O. It's live-only echo cancellation and lowers other apps' audio.
- **Verify:**
  - A noisy test recording's noise floor drops.
  - The track length is unchanged.
  - The system-audio track is untouched.

### N5 — Transcript and captions (macOS 26)

- **What:**
  - Transcribe speech on-device and show captions burned into the video: a line at the bottom, with
    the current word optionally highlighted.
  - Fix words in the inspector.
  - Export SRT and VTT beside the movie.
- **How:** `SpeechAnalyzer` + `SpeechTranscriber`, with `attributeOptions: [.audioTimeRange,
  .transcriptionConfidence]`. `AssetInventory` installs the models into system storage, not the app.
  - **Measured:** 28.2 min of audio transcribed in 24.9 s (about 68× real time). In the sandbox it
    needed no usage key, no prompt and no entitlement.
  - **Gotcha:** `AVAudioFile` reads only a movie's first audio track, which is system audio when
    there are two. Decode the mic track with `AVAssetReader` and feed it
    `AnalyzerInput(buffer:bufferStartTime:)`.
  - Words (text, source range, confidence) go in the project.
  - `RenderPlan` draws each caption line once as an image, like `KeystrokeChip`, so there is no text
    layout per frame.
- **macOS 15:** hidden. `SFSpeechRecognizer` stops tasks after 1 minute and needs a permission
  prompt, so it isn't worth a fallback.
- **Verify:**
  - Word times fall within 100 ms of a scripted `say` recording.
  - 10 minutes transcribe in under 15 s.
  - Captions sit in the canvas at every size.

### N6 — Remove silences and filler words

- **What:** Remove Silences and Remove Filler Words list the cuts they propose in the inspector.
  Applying them is one undoable edit.
- **How:**
  - **Silences** come from audio energy, which works on macOS 15: `AVAssetReader` and
    `vDSP.rootMeanSquare` per 20 ms, a threshold above the track's noise floor, and gaps of 0.8 s or
    more cut down to 0.3 s. `SpeechDetector` (macOS 26) is the alternative.
  - **Fillers** are "um" and "uh" words from N5. On synthesized speech they came back as timed words
    with confidence 0.33–0.57. On real speech this is unverified, so measure on real recordings
    before promising it.
  - Cuts go through `TimeMap`'s cut operations, so the 25 ms fades come free.
- **Ours:** never cut a silence while the telemetry shows clicking, typing or scrolling. Something
  is happening on screen there, which audio-only tools can't know.
- **Verify:** on a scripted recording with known pauses, every pause of at least 0.8 s is proposed,
  and none during typing.

### N7 — Speed per part, and speeding up typing

- **What:**
  - Each kept part gets a speed from 1× to 8×.
  - Speed Up Typing proposes 2–4× for stretches of typing, with an "Apply all" button.
- **How:**
  - A speed list in the project: source range and rate.
  - `TimeMap` stays the only converter and becomes piecewise linear.
  - `CompositionBuilder` uses `AVMutableComposition.scaleTimeRange`; audio keeps its pitch through
    `audioTimePitchAlgorithm` on the player item and the export.
  - Typing stretches come from `keys`: gaps under 1 s, at least 3 s long, shortcuts left out. The
    detector is a pure function next to `AutoZoomGenerator`.
- **Risk:** the camera, cursor and overlays are timed in source time, so at 4× a zoom animation and
  a click ring play 4× as fast. Decide in its spec (see Open questions).
- **Verify:**
  - `TimeMap` round-trip tests.
  - The export's length equals the sum of each part's length divided by its speed.
  - The pitch is unchanged.

### N8 — Masks: blur, pixelate, spotlight

- **What:** a mask lane, like the zoom lane, holding rectangles that blur or pixelate what's under
  them, or dim everything else (spotlight). Pixelation adds noise so it can't be reversed, as
  CleanShot's does.
- **How:**
  - A mask list in the project: source range, rectangle as fractions of the video, and kind.
  - `FrameRenderer` applies masks to the source frame before the zoom transform, so they stay on
    the content. It uses `CIPixellate` or a clamped `CIGaussianBlur` cropped to the rectangle, and
    `CIBlendWithMask` for the spotlight.
  - Bands a mask doesn't touch skip it.
  - Reuses the patterns of `ZoomLane` and `ZoomBlock`.
- **Verify:** pixels outside a blur mask are unchanged, and a zoomed frame with a mask stays within
  budget.

### N9 — Find sensitive info

- **What:** Find Sensitive Info proposes masks over emails, phone numbers, card numbers and API
  keys. The same finder runs on the screenshot card.
- **How:** a pure `SensitiveTextFinder`.
  - **OCR:** `RecognizeTextRequest` on sampled frames (1–2 Hz, and when the frame changes).
  - **Matching:** `NSDataDetector` for emails (they come back as `mailto:` links) and phone numbers,
    or `DataDetection` on macOS 26. A regex plus a Luhn check for card numbers, which neither
    detector finds. Known key prefixes (`sk-`, `ghp_`, `AKIA`, `xox`).
  - `RecognizedText.boundingBox(for:)` turns a match into a box. Boxes seen in consecutive samples
    join into one mask.
- **Measured** on a 4K frame with 120 lines of text:
  - `.fast` took about 150 ms, but only with `minimumTextHeightFraction` at 0.008; at the default it
    found nothing at 26 px.
  - `.accurate` took about 2 s.
  - The detectors took 13–29 ms.
  - So 10 minutes at 1 Hz take about 90 s: run it in the background, with progress.
- **Risk:** text that moves between samples is missed. Every suggestion is shown for review, and the
  UI never claims it found everything.

### N10 — GIF export, copy frame

- **What:**
  - GIF in the export sheet: looping, 480–960 px, 25 or 50 fps.
  - Copy Frame copies the current frame at output size.
- **How:**
  - `AVAssetExportSession` can't write GIF, so read frames with
    `AVAssetReaderVideoCompositionOutput` (the same video composition) and write them with
    `CGImageDestination` (`UTType.gif`, `kCGImagePropertyGIFLoopCount` 0,
    `kCGImagePropertyGIFUnclampedDelayTime`).
  - Copy Frame draws with `FrameRenderer` and copies with `ImagePasteboard`.
- **Measured:**
  - About 15 ms per 1080p frame.
  - Delays are stored in hundredths of a second, which is why the rates are 25 and 50 fps.
  - Each frame gets its own palette with no dithering, so gradients band. The default slate canvas
    will.
  - ImageIO keeps a frame that already has 256 colours or fewer bit-exact, so dithering can be ours
    (see Open questions).
- **Other formats:** APNG uses the same code and comes out about 6.6× larger. Animated WebP can't be
  written.

### N11 — Crop

- **What:** crop the recording to a rectangle, for example to hide the menu bar or a sidebar.
- **How:** a crop in the project, as fractions of the video.
  - `CanvasLayout` treats the crop as the video: output size, shadow and corners.
  - Zoom focus and cursor positions map through one function.
  - Auto-zoom ignores presses outside the crop, as it already ignores those outside the video.

### N12 — Fill vertical and square canvases

- **What:** in 9:16 or 1:1, a Fill option keeps the view zoomed in and following the cursor, instead
  of showing a thin 16:9 strip.
- **How:** `CameraPath` gets a base view, the largest rectangle of the canvas's shape that fits in
  the video. Between zooms it follows the cursor with the existing dead zone, and zooms scale from
  it. No renderer change: the view is already one transform.

### N13 — Annotate screenshots (own spec)

- **What:** tools on the card:
  - arrow, line, rectangle, ellipse, text
  - highlighter, step counter
  - blur and pixelate, spotlight
  - crop
- **How:**
  - Marks are vector shapes over the image, drawn with Core Graphics into the copied or saved PNG.
  - Undo; marks stay editable until the card closes.
  - Blur and pixelate reuse N8's filters; one-click redaction reuses N9.

### N14 — Screenshot backgrounds

- **What:** put a screenshot on a gradient, colour or picture, with padding, corners and a shadow.
  Auto Balance centres the content with even margins.
- **How:** reuse `CanvasStyle` and `CanvasLayout`'s backdrop on a still image. Auto Balance trims
  borders of one uniform colour, then pads evenly.

### N15 — Restore a closed card; history

- **S:** Restore Last Screenshot in the menu brings back the last closed card from memory.
- **M, opt-in:** keep screenshots for 30 days in the app's Caches folder and list them. This
  conflicts with "nothing is written until Save" (see Open questions).

### N16 — Small capture wins

Each is S:
- **Self-timer** (3, 5 or 10 s), reusing `RecordingCountdown`.
- **Capture Previous Area**, alongside F7's remembered selection.
- **QR codes** in Recognize Text: `DetectBarcodesRequest` next to the text request; the payload is
  copied.
- **Screenshot URLs:** `reco://capture-area`, `capture-window` and `capture-screen`, with
  `?then=copy|save|pin`, for Raycast and Shortcuts.
- **HDR screenshots** on macOS 26: `SCScreenshotConfiguration.dynamicRange = .hdr`, saved as HEIC.
- **Pins:** an opacity setting, and a click-through mode.

### N17 — Freeze screen and loupe while selecting

Capture the display once when area selection opens, show it under the overlay, and crop from that
image, so hover states and open menus survive. A loupe next to the pointer shows pixels for exact
edges. Recording keeps the live selection.

### N18 — Scrolling capture (own spec)

1. **Manual scrolling first:**
   - Capture the region with `SCScreenshotManager.captureImage(in:)` (macOS 15.2) as the user
     scrolls.
   - Align each capture with the last by matching row hashes with vDSP, which works because screen
     pixels are exact. Crop fixed headers first, since they break whole-image alignment.
   - Vision's `TrackTranslationalImageRegistrationRequest` is the fallback.
2. **Then auto-scroll:** post scroll-wheel `CGEvent`s. Apple DTS says this is allowed in the sandbox
   after `CGRequestPostEventAccess`.

### N19 — Camera as its own track (own spec; spec 0003 open question 3)

- **Recording:**
  - Record the camera to `<name>.camera.mov` with `AVCaptureMovieFileOutput`, which can pause and
    resume with the screen.
  - Align it by host time (`synchronizationClock` → host clock with `CMSyncConvertTime`).
  - The camera entitlement is already in the app for Presenter Overlay.
  - It can't run at the same time as Presenter Overlay: once the user turns that on, the session
    stops delivering the normal camera stream.
- **Editor:**
  - A camera bubble with a corner, size and shape.
  - Layouts per part on a lane: bubble, side by side, camera only, hidden.
  - The bubble shrinks during zooms.
- **Background blur or removal:** `CIFilter.personSegmentation()`. Measured at 1080p: `.fast` 3.1 ms
  (256×192 mask), `.balanced` 10.2 ms; the mask is always 4:3.

### N20 — Cancel and restart a recording

- **What:** shortcuts plus `reco://cancel` and `reco://restart`.
  - Cancel throws away the movie and its telemetry.
  - Restart cancels, then starts again with the same selection.
- **Verify:** after a cancel, the output folder has no new file.

### N21 — Hide desktop icons in recordings (check first)

- **What:** leave Finder's desktop-icon windows (`kCGDesktopIconWindowLevel`) out of the display's
  `SCContentFilter`, so icons are missing from the video without touching the real desktop.
- **Check:** this is unverified. Confirm the icons are separate windows that SCK can exclude on
  macOS 15 and 26.

### N22 — Scripted web recordings (own spec: `0005-web-recordings.md`)

- **Seen in** Tino Zabinskiy's programmatic recorder
  ([post](https://x.com/0x_tino/status/2104615778817577471), 28 Sep 2026, 39 s demo). You load a
  URL at a viewport preset (Desktop 1440 is 1440×900), add Scroll, Hover and Click clips on a
  timeline, and it exports the video at 2× and 60 fps. The demo shows:
  - **Tracks:** Cursor, with hover and click clips aimed at a page element (e.g.
    `button.relative.block`), and Scroll · Page, with clips like "0 → 1485" and "1485 → 4231".
  - **Scroll clips:** a target (window or element), an axis, start and duration, and point B, set
    by scrolling the page there and pressing Set point B. Point A is the previous scroll's point B,
    so the page never jumps. Easing is Linear, In, Out or In-out, or a cubic-bezier you edit.
  - **Cursor settings:** style, size, smoothing, path curve (curved moves between targets), and a
    click effect of ripple, press or none.
  - Loop playback, a snapping switch, undo and reload.
- **Why it fits us:** a scripted take produces what a recording does, a movie plus a telemetry
  sidecar with exact cursor positions and clicks. So auto-zoom, the cursor, click highlights, the
  canvas and export work unchanged, and the zooms land exactly on the clicks. None of the surveyed
  apps can do this.
- **How:**
  - **The page:** a `WKWebView` in an offscreen window at the viewport size. The app already has
    `com.apple.security.network.client`.
  - **Rendering frame by frame, not in real time.** WebKit has no public virtual-time API, so
    inject a `WKUserScript` at document start. It replaces `requestAnimationFrame`,
    `setTimeout`/`setInterval`, `Date.now` and `performance.now` with a virtual clock, and seeks CSS
    animations and transitions through `document.getAnimations()`, as Puppeteer's timesnap and
    timecut do. Each frame:
    1. Advance the clock by 1/60 s.
    2. Apply the eased scroll.
    3. Move the pointer.
    4. Take a 2× snapshot with `takeSnapshot(with:)`.
    5. Append it to `AVAssetWriter`.
  - **Real hovers and clicks:** `:hover` responds only to real pointer events, so send `NSEvent`
    mouse moves, downs and ups to our own web view. That happens in-process and needs no
    permission. Plain moves reach only scrollbars in a window that isn't key; right-button drags
    get the full hit test (measured, spec 0005).
  - **Targets:** click an element in the preview to pick it, and `elementFromPoint` builds a
    selector for it. Its rectangle is read every frame, so the cursor stays on it while the page
    scrolls.
  - **The cursor:** eased, curved moves between targets, written to the telemetry at 60 Hz along
    with the clicks. The editor draws it.
- **Measured** (spec 0005): a 2880×1800 snapshot takes 14 ms for a simple page, 35 ms for
  apple.com and 310 ms for linear.app, so a 30 s video takes 30 s to 9 min to render.
- **Mac apps, later:** the same timeline could drive a native app in real time by posting `CGEvent`s
  while recording, which the sandbox allows after `CGRequestPostEventAccess`. It could only aim at
  screen points, though, because targeting an element needs Accessibility.
- **Verify:**
  - Two renders of the same script are identical frame for frame.
  - A CSS animation lands on the same frame in every render.
  - The telemetry's click points fall on the targeted elements.

## Later

- **Edit by transcript:** deleting words cuts them. Builds on N5 and N6.
- **Titles and chapters** with Foundation Models (macOS 26, Apple Intelligence turned on). A session
  holds 4,096 tokens (TN3193), about 1,500 words, roughly a 10-minute talk, so longer transcripts
  need chunking. Chapters would become timeline markers and an MP4 chapter track.
- **Step guide from a recording:** a frame at each click, with the text near the click read by
  Vision, exported as Markdown. Snagit's Step Capture; our click telemetry makes it exact.
- **Loupe zoom:** magnify a circle around the cursor instead of the whole frame, like Screen
  Studio's Glass Loupe (in beta).
- **Smarter zoom targets without Accessibility:**
  - Size zooms to Vision text boxes near typing.
  - Zoom on scroll bursts; scrolls are recorded but unused today.
  - Zoom out when a click causes a large change on screen.
- **3D perspective shots** (Cap, FocuSee, open-recorder, Rapidemo): `CIPerspectiveTransform` in the
  video's single transform.
- **Also:**
  - A cursor-only ProRes 4444 export for other editors, as Cap has.
  - Style presets.
  - Text cards.
  - Music from the user's own file.

## Not doing

- **Share links, comments and view counts:** they need a server.
- **AI avatars, voiceover and generated B-roll.**
- **Anything that needs Accessibility**, such as Screenize's zooms sized to the element under the
  cursor. The App Sandbox forbids it, and DTS confirms it. It would need a separate unsandboxed
  build.
- **Do Not Disturb during recording:** there's no public API. Users can run a Focus shortcut.
- **Animated WebP:** ImageIO can't write it (macOS 26.5).
- **A `SFSpeechRecognizer` fallback on macOS 15:** its 1-minute task limit and permission prompt
  rule it out.

## Open questions

1. **Speed and overlays (N7):** at 4×, should click rings, key chips and zoom springs keep their
   on-screen duration, or play 4× as fast? Keeping it means timing them in output time.
2. **Where derived audio lives (N3, N4):** beside the recording (the editor holds the output
   folder's scope while it's open), or in Caches, regenerated when missing.
3. **GIF dithering (N10):** ship ImageIO's undithered frames, or add ordered dithering for
   gradients.
4. **Screenshot history on disk (N15):** it breaks "nothing is written until Save". Should it be
   opt-in?
5. **Camera track and Presenter Overlay (N19):** keep both, or replace Presenter Overlay?
6. **macOS 26-only features (N5, N6 fillers):** hide them on 15.2, or show them disabled with a
   note?
7. **Scripted recordings (N22):** only web pages at first, or also Mac apps played in real time?
   And does it come before the voice work? That depends on whether designers or talk-over creators
   are the first audience.

## Research

**Apps:**
- Screen Studio: [changelog](https://screen.studio/changelog), [roadmap](https://screen.studio/roadmap),
  [cursor](https://screen.studio/guide/cursor), [typing speed-up](https://screen.studio/guide/speed-up-typing-segments),
  [captions](https://screen.studio/guide/captions)
- Recorders:
  - [Cap releases](https://github.com/CapSoftware/Cap/releases)
  - [FocuSee](https://focusee.imobie.com/)
  - [Canvid changelog](https://www.canvid.com/changelog)
  - [Tella changelog](https://www.tella.com/docs/changelog)
  - [open-recorder](https://github.com/imbhargav5/open-recorder)
  - [Screenize](https://github.com/syi0808/screenize)
- Screenshot tools:
  - [CleanShot features](https://cleanshot.com/features)
  - [CleanShot URL API](https://cleanshot.com/docs-api)
  - [Shottr scrolling capture](https://shottr.cc/kb/scrollingcapture)
  - [Xnapper](https://xnapper.com/)
  - [Snagit 2026](https://support.techsmith.com/hc/en-us/articles/41975263481613-Snagit-Mac-2026-Version-History)
- Transcript editing:
  - [Descript word gaps](https://help.descript.com/hc/en-us/articles/10164807277453-Shorten-word-gaps)
  - [Loom filler and silence removal](https://support.atlassian.com/loom/docs/remove-filler-words-and-silences-from-your-video/)

**Apple:**
- Speech: [WWDC25 SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/),
  [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber)
- Foundation Models: [TN3193 context window](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)
- Audio: [WWDC23 voice processing](https://developer.apple.com/videos/play/wwdc2023/10235/)
- Camera: [WWDC23 Presenter Overlay and camera](https://developer.apple.com/videos/play/wwdc2023/10136/)
- Data detection: [DataDetection](https://developer.apple.com/documentation/datadetection)
- Screenshots: [SCScreenshotConfiguration](https://developer.apple.com/documentation/screencapturekit/scscreenshotconfiguration)
- Sandbox:
  - [Accessibility in the sandbox (DTS)](https://developer.apple.com/forums/thread/707680)
  - [Posting events in the sandbox (DTS)](https://developer.apple.com/forums/thread/789896)

The measurements in this spec were taken on an M5 running macOS 26.5.2, in Debug. The speech and
sound-isolation runs were also repeated inside a sandboxed test app.
