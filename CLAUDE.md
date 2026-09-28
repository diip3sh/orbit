# CLAUDE.md

Coding rules, Swift/SwiftUI conventions and git workflow live in AGENTS.md — follow them:

@AGENTS.md

This file covers what AGENTS.md doesn't: how to build this fork, what it adds on top of upstream
[jsattler/BetterCapture](https://github.com/jsattler/BetterCapture), where that code lives, and what's next.

## What this fork is

BetterCapture is a sandboxed macOS menu bar screen recorder (ScreenCaptureKit + AVAssetWriter).
This fork is working towards a free Screen Studio / CleanShot X alternative: record input telemetry
now, build an editor (auto-zoom, smooth cursor, backgrounds) on top of it later.

Architecture of the original app: `docs/architecture/OVERVIEW.md`, `docs/architecture/OUTPUT.md`,
`docs/concepts/VIDEO.md`, `docs/concepts/AUDIO.md`.

## Build, run, test

The project is signed with upstream's team (`DMX24B5FC3`), which you won't have. Build with your
own Apple Development certificate — don't commit signing changes:

```sh
# Find your team ID: the OU= field
security find-identity -v -p codesigning
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject

TEAM=<YOUR_TEAM_ID>
xcodebuild -scheme BetterCapture -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bc-build/dd \
  CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=$TEAM \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER="" build -quiet \
  && { pkill -x BetterCapture; open /tmp/bc-build/dd/Build/Products/Debug/BetterCapture.app; }
```

- Tests: same command with `test` instead of `build -quiet` (Swift Testing, 333 tests).
- Lint: `swiftlint lint --quiet <files>` — new code must be clean. Pre-existing warnings:
  `AssetWriter.swift` (file_length, type_body_length, 2× function_body_length) and
  `RecorderViewModel.swift` (file_length, type_body_length). Don't make them worse; SwiftLint skips
  extensions for type_body_length, so new logic goes in same-file extensions or new types.
- Keep build output outside the repo (`/tmp/bc-build`). If the build fails with "There is no
  XCFramework found", `rm -rf /tmp/bc-build` and rebuild (moved DerivedData breaks SPM paths).
- **Don't use ad-hoc signing (`CODE_SIGN_IDENTITY="-"`)**: the code hash changes every build, so
  macOS forgets the Screen Recording permission and prompts forever. If a permission gets stuck:
  `tccutil reset ScreenCapture com.sattlerjoshua.BetterCapture`, then relaunch.
- New `.swift` files need no pbxproj edit (file-system synchronized groups).
- Don't call an ObjC API whose completion handler is `() -> Void` through Swift's async import
  (`await writer.finishWriting()`). `AVAssetExportSession.export(to:as:)` is back-deployed below
  macOS 26, so its body is compiled into the app with a same-named but incompatible thunk, and the
  linker may keep that copy: `AssetWriter` crashed on every stop. Use an explicit continuation, as
  `AVAssetWriter.finishWritingWithoutAsyncImport()` does.
- App target defaults to MainActor isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), Swift 6
  language mode. Types used off the main actor must be marked `nonisolated`: Swift 6 checks
  isolation at runtime too, so main-actor code called from a capture queue crashes instead of racing.
  ScreenCaptureKit isn't Sendable-annotated; files that pass its types across actors use
  `@preconcurrency import ScreenCaptureKit`.
- Test suites that touch main-actor app types (most models) are marked `@MainActor`.

## Quality bar

We are building a small, fast, polished app. Every change is minimal, clean and production quality;
AGENTS.md's rules apply, and these add to them.

### Architecture

MVVM with `@Observable` (Apple's pattern, and upstream's), built as a **functional core with an
imperative shell**. No TCA, VIPER, Clean-Architecture layers or DI frameworks: they add a dependency
or indirection that doesn't pay for itself in an AVFoundation app.

| Layer | Holds | Rules |
|---|---|---|
| Core (`Model/`, pure helpers in `Service/`) | Value types and pure functions: time mapping, geometry, pauses, dedup, auto-zoom, smoothing, settings rules | `nonisolated`, `Sendable`, no side effects or singletons, fully unit tested. E.g. `RecordingPauses`, `CursorShapeTracker`, `InputTelemetry.videoPixel` |
| Shell (`Service/`) | One service per system boundary: ScreenCaptureKit, AVAssetWriter, event taps, files | Thin: gather input, call the core, apply the result. Explicit isolation: `@MainActor`, or `nonisolated` + a lock |
| `ViewModel/` | `@MainActor @Observable` state and intents | Calls services; no rules that belong in the core |
| `View/` | Layout | Reads view-model state, calls intents; no logic |

- Dependencies point down only: View → ViewModel → Service → Core. Services report up through
  delegates or `async` results, never by reaching into a view model.
- New features get a feature folder, `BetterCapture/<Feature>/{Model,Render,Service,ViewModel,View}`
  (see spec 0003). Existing layer folders stay as they are.
- One rule, one place: logic lives in exactly one function that every caller reuses (e.g.
  `SettingsStore.capturesCursor` drives both the capture and the telemetry). Never re-derive it.
- Protocols only where a test needs a fake or there are two real conformers.

### Code

- The smallest change that fully solves the problem. Delete before adding; no speculative options,
  wrappers or "just in case" code.
- Match the surrounding code. Name things by meaning. Comments say *why*, and record measured facts
  with their numbers (like `shadowTopFraction`) so nobody re-derives them.
- Done means: zero compiler warnings, all tests pass, SwiftLint clean on touched files, new logic
  has tests, and docs (this file, specs) match the code.

### Performance

The app records 4K60 in real time, and the editor must render a frame in under 8 ms.
- Hot paths (capture queue, compositor, per-frame and per-event code): no allocation that grows
  with recording length, no I/O or logging per sample, no main-actor hops, locks held only briefly.
- Precompute once, look up per frame (binary search, O(1) sampled tracks); build images once, never
  per frame.
- Keep heavy work off the main actor (`@concurrent`) and high-frequency values out of observed state.
- Measure before and after optimising (`OSSignposter`, Instruments). A performance claim needs a number.
- Prefer Apple frameworks (AVFoundation, Core Image on Metal, Accelerate) over hand-rolled or
  third-party code.

## Features added in this fork

Branches are stacked: `feat/input-telemetry` → `feat/cursor-sprites` → `feat/pause-resume`.

### F1 — Input telemetry sidecar (`feat/input-telemetry`)

Optional setting **Settings → Video → Advanced → Record Input Telemetry** (off by default). Writes
`<video>.telemetry.json` next to each recording with cursor positions, clicks, scrolls and
keystrokes (key code + modifiers only, never characters), all on the video timeline.

| File | Role |
|---|---|
| `Model/InputTelemetry.swift` | Codable file format, pure conversion helpers (`videoTime`, `rebased`, `videoPixel`, `topLeft`, `modifierNames`) |
| `Service/InputTelemetryRecorder.swift` | Cursor polling (≤60 Hz), global mouse/scroll monitor, listen-only key `CGEventTap`, writes the sidecar |
| `Service/CaptureGeometryTracker.swift` | Per-frame `SCStreamFrameInfo` geometry on the capture queue, stored only on change |
| `Service/AssetWriter.swift` | `sessionStartTime` (host time of file time 0) |
| `ViewModel/RecorderViewModel.swift` | Starts telemetry after the last `try` in `startRecording`, writes the sidecar in `stopRecording` while the output folder's security scope is held |

Key facts:
- **Time:** events are stored as host-clock seconds while recording (`NSEvent.timestamp`,
  `CMClockGetHostTimeClock`, SCStream PTS all share it) and rebased at stop by `sessionStartTime`.
- **Position:** locations are global CG points, top-left origin. Map to video pixels with
  `InputTelemetry.videoPixel(for:geometry:)` using the `geometry` entry in effect at that time.
  Verified against real frames for display and window captures.
- **Window shadows:** with "Show Window Shadows" on, SCK draws window + shadow scaled into the frame.
  SCK reports only the shadow's total size, so the top/bottom split uses the measured
  `InputTelemetry.shadowTopFraction = 0.35` (macOS 27). Re-measure if Apple changes shadows.
- **Keystrokes** need Input Monitoring (requested when the toggle is turned on; effective after
  relaunch). Without it `keystrokesAvailable` is false and `keys` is empty.

### F2 — Cursor sprites (`feat/cursor-sprites`)

When telemetry is on, each distinct system cursor image (arrow, I-beam, hand, resize…) is stored once
in the JSON (largest bitmap as base64 PNG, size + hotspot in points), plus a track of when the
cursor changed shape. Standard cursors also get a `kind` (`CursorKind`). Lets the editor redraw the
cursor, so with telemetry on the cursor is **left out of the video** unless
**Settings → Video → Advanced → Keep System Cursor in Video** is on (off by default); "Show Cursor"
is disabled meanwhile. `capture.cursorInVideo` records which applied.

| File | Role |
|---|---|
| `Service/CursorShapeTracker.swift` | Pure dedup by fingerprint (size + hotspot + smallest bitmap's pixels); PNG encoded and kind looked up only for new shapes |
| `Service/StandardCursors.swift` | Fingerprints of the running OS's 44 standard `NSCursor`s; another app's arrow is byte-identical to `NSCursor.arrow`, so exact match classifies |
| `Service/InputTelemetryRecorder.swift` | `sampleCursorShape(at:)` reads `NSCursor.currentSystem` at ≤15 Hz |
| `Model/SettingsStore.swift` | `keepSystemCursorInVideo`, `leavesCursorToEditor`, `capturesCursor` (used for `SCStreamConfiguration.showsCursor`) in the `// MARK: - Cursor Capture` extension |

Arrow and I-beam bitmaps go up to 10× (280×400 px); other standard cursors only 2×, so the captured
PNG is as sharp as anything `NSCursor` offers at edit time.

Risk: `NSCursor.currentSystem` is marked "to be deprecated" with no public replacement. If it starts
returning nil, sprites are simply empty; nothing else breaks.

### F4 — Pause / resume (`feat/pause-resume`, upstream issue #174)

Menu bar **Pause/Resume** button, global shortcut **Pause/Resume Recording** (no default), and
`bettercapture://pause`. The SCStream keeps running while paused (instant resume, macOS recording
indicator stays on); every sample is dropped and the paused time is cut from the file.

| File | Role |
|---|---|
| `Service/RecordingPauses.swift` | Pure struct: per sample, drop (`nil`) or return paused time to subtract |
| `Service/AssetWriter.swift` | `timelineOffset(of:duration:)` rebases every track, the CFR grid and head silence padding by `sessionAnchor + pausedTime`; `pause`/`resume`/`pauseIntervals` in the `// MARK: - Pausing` extension; last frame captured while paused is shown from the resume point |
| `ViewModel/RecorderViewModel.swift` | `isPaused` flag (state stays `.recording`), `togglePause()` extension, timer excludes paused time |
| `Model/InputTelemetry.swift` | `rebased(anchor:duration:pauses:)` drops events inside pauses and shifts later ones |

Audio buffers straddling a pause edge are dropped whole (gap ≤ ~21 ms per edge, marked `ponytail:`).

### F5 — Countdown (`feat/countdown`)

**Settings → General → Recording → Countdown**: Off / 3 / 5 / 10 s (default 3). Every user start (menu
Start, pre-record overlay Start, Toggle Recording shortcut) shows a big number centred on what will be
recorded (area, window, or display) and the seconds in the menu bar. `bettercapture://toggle` /
`toggle-copy` skip the countdown (and cancel one that's running) so automation stays precise.

| File | Role |
|---|---|
| `Service/RecordingCountdown.swift` | `@Observable` tick loop (`remaining`), cancellable, injectable one-second sleep for tests |
| `View/CountdownOverlay.swift`, `View/CountdownView.swift` | Click-through, non-activating `.screenSaver` panel with the number; Esc as a temporary global hotkey |
| `Model/CountdownDuration.swift` | Setting enum (`SettingsStore.countdownDuration`) |
| `ViewModel/RecorderViewModel.swift` | `// MARK: - Countdown` extension: `startRecordingWithCountdown()`, `cancelCountdown()`; `toggleRecording(countdown:)` |

Key facts:
- State stays `.idle` while counting (`isRecording` false); `countdown.isRunning` is the flag. When it
  ends, the panel is ordered out *before* the normal `startRecording()`, so it never lands in the video.
- Cancel: Esc, or starting again (menu, shortcut). Nothing is created. Esc is
  `KeyboardShortcuts.events(.keyDown, for: Shortcut(.escape))`: a Carbon hotkey, registered only during
  the countdown, so it swallows Esc system-wide only then. If another app holds a global Esc hotkey,
  registration fails silently; the menu/shortcut still cancel.

### S1 — Editor, phase 1: shell and playback (`feat/editor-shell`, spec 0003)

Opens a recording in its own window with the preview, transport controls and a timeline (filmstrip,
click/key lanes, playhead, scrubbing). Entry points: **Edit** on the recording-saved notification (its
default action when the cursor was left out of the video), **Edit Last Recording** in the menu bar, and
`bettercapture://edit-last`. Keys: space play/pause, ←/→ step a frame, ⌘Z/⇧⌘Z undo/redo.

| File | Role |
|---|---|
| `Editor/View/EditorWindowManager.swift` | One `NSWindow` + `NSHostingController` per recording, owned by `AppDelegate`; `.regular` activation policy while any is open; holds the output folder's security scope until the window's project is saved |
| `Editor/ViewModel/EditorViewModel.swift` | Loads source + project, `edit(_:_:)` (one undo step, registers redo), 1 s debounced autosave, `close()` |
| `Editor/ViewModel/PlaybackController.swift` | `AVPlayer`, coalesced zero-tolerance seeks (QA1820), frame stepping, end of item |
| `Editor/Service/EditorSourceLoader.swift` | Asset properties + telemetry off the main actor; telemetry problems never block opening |
| `Editor/Service/ProjectStore.swift`, `Editor/Model/EditorProject.swift` | `<name>.edit.json` v1 (`cuts`), atomic writes; only written after an edit |
| `Editor/Render/TimeMap.swift` | Output ↔ source time; the only type that knows about cuts |
| `Editor/Model/FrameGrid.swift` | Frame index ↔ time on the CFR grid the writer uses |
| `Model/UnsupportedVersionError.swift` | Thrown by `InputTelemetry` (reads v2–v3) and `EditorProject` (v1) for other versions |

Key facts:
- The playhead is observed only while paused (`pausedTime`); during playback views read
  `currentTime` inside `TimelineView(.animation)`, so a tick redraws the playhead and time label only.
- Frame stepping uses `AVPlayerItem.step(byCount:)` (decodes one frame; a seek decodes from the last
  keyframe, up to 2 s back) unless a seek is still in flight.

### S1 — Editor, phase 2: render pipeline, overlays, export (`feat/editor-shell`, spec 0003)

Click highlights (a ring that grows and fades) and a keystroke chip, drawn live in the preview and
into exports by one custom compositor. An inspector (toolbar toggle) holds their styles; **Export…**
writes `<name>-edited.mp4` (HEVC, H.264) or `.mov` (ProRes 422) next to the recording and reveals it.

| File | Role |
|---|---|
| `Editor/Render/RenderPlan.swift` | `Sendable` snapshot built off the main actor on every edit: click markers already in Core Image pixels, keystroke chips, and images drawn once (`OverlayImages`) |
| `Editor/Render/FrameRenderer.swift` | `(source frame, source time, plan) -> CIImage`; the only place pixels are decided |
| `Editor/Render/EditorCompositor.swift`, `EditorInstruction.swift`, `CompositionBuilder.swift` | `AVVideoCompositing` with one shared `CIContext`; the instruction carries the plan; the same video composition feeds `AVPlayerItem` and `AVAssetExportSession` |
| `Editor/Service/KeyLabelFormatter.swift` | Key code + modifiers → "⇧⌘K" with the current layout (`UCKeyTranslate`); TIS is read on the main actor only |
| `Editor/Service/ExportService.swift` | `AVAssetExportSession.export(to:as:)` + `states(updateInterval:)`; cancelling the task cancels it |
| `Editor/View/EditorInspector.swift`, `ExportSheet.swift` | Style controls (bound through `EditorViewModel.clickHighlights`/`keystrokes`), format + progress |

Key facts:
- **Privacy:** keystrokes show only shortcuts (⌘/⌃/⌥) and special keys unless "Show All Keys" is on.
- Inspector changes are coalescing edits: the same control changed again within 1 s joins its undo step.
- A new plan swaps the player item's video composition; while paused, the frame is re-seeked to redraw.
- The compositor's `CIContext` has color management off: frames stay in the source's encoding (its
  tags are copied to the output) and overlays blend in it. Measured on an M1, Debug, 4K with a ring
  and a chip: ~5 ms p50 / 8 ms p95 per frame, versus 10 / 13 ms with linear-light compositing. A
  10-min plan (3,000 clicks, 12,000 keys) builds in ~24 ms.
- `InputTelemetry.geometry(at:)` and `RandomAccessCollection.partitioningIndex` are the shared lookups.

### S1 — Editor, phase 3: trim and cut (`feat/editor-shell`, spec 0003)

The timeline always spans the whole recording: cut parts are dimmed and the playhead skips them.
Each kept part has a handle on both edges; dragging one trims or restores. **S** splits at
the playhead, clicking selects the part between splits and cuts, **⌫** cuts it. The inspector's
Audio section sets each track's volume and mute.

| File | Role |
|---|---|
| `Editor/Render/TimeMap.swift` | Output ↔ source time by binary search, and every cut operation: normalize, add, restore, move a kept range's edge, divide at splits |
| `Editor/Render/CompositionBuilder.swift`, `EditorComposition.swift` | `AVMutableComposition` of the kept ranges (every track, source track IDs), the video composition, and the `AVAudioMix` with volumes and fades |
| `Editor/ViewModel/EditorViewModel.swift` | `// MARK: - Cutting` extension: `split()`, `select(at:)`, `deleteSelection()`, `moveStart`/`moveEnd(ofKeptRange:to:)`; rebuilds swap only what changed |
| `Editor/View/EditorTimelineView.swift`, `TrimHandle.swift` | Source-time timeline: dimmed cuts, splits, selection, handles |
| `Editor/Model/AudioMixSettings.swift` | Volume and mute per audio track, by the recording's track order |

Key facts:
- Everything in the project and on the timeline is source time; only the player, the transport's
  time label and the compositor's requests are output time. `TimeMap` is the only converter.
- Cuts are normalized as frame boundaries (integers); the last boundary is the recording's end
  wherever it falls, so a trailing cut never leaves a sliver. Something must stay: trims keep a
  frame per kept part, and the last part can't be cut.
- `splits` are saved in the project, so a split is an undoable edit. Splits inside cuts are kept
  and come back if the cut is restored.
- A new player item is made only when the cuts change (the playhead stays on its content); other
  edits swap the video composition, volumes only the mix.
- Audio fades 25 ms at every cut. The mix lags its ramps by ~10 ms: at a cut, 10 ms ramps still
  left 57% of the volume, 20 ms 20%, 25 ms 2%.
- Audio tracks are named by the writer's order: two tracks are system audio then microphone; one
  track is just "Audio" since it could be either.

### S1 — Editor, phase 4: zoom (`feat/editor-shell`, spec 0003)

A recording with telemetry opens with automatic zooms on its clicks and typing. The zoom lane
under the timeline shows every zoom: click to select, drag to move, handles to resize, **Z** adds
one at the playhead, **⌫** deletes the selected one. The inspector's Zoom section sets its scale
and focus (follow the cursor, or a fixed point dragged on a picture of the frame) and regenerates
the automatic zooms.

| File | Role |
|---|---|
| `Editor/Model/ZoomSegment.swift` | Source range, scale, focus (fractions of the video, top-left origin), `isAutomatic`; every edit of the zoom list, which keeps it sorted and apart and makes the zoom it changes manual |
| `Editor/Service/AutoZoomGenerator.swift` | Pure: groups presses (clicks, and keys at the last click) that are close in time and fit one view; `Configuration` holds the constants |
| `Editor/Render/CameraPath.swift` | The view over time, sampled at 120 Hz: a critically damped spring per axis, scale in log space, follow-cursor with a dead zone |
| `Editor/Render/FrameRenderer.swift` | Draws clicks, magnifies the frame to the view, then draws the keystroke chip unmagnified |
| `Editor/View/ZoomLane.swift`, `ZoomFocusPad.swift` | The timeline's zoom lane; the inspector's fixed-focus picker |
| `Editor/ViewModel/EditorViewModel.swift` | `// MARK: - Zooming` extension; `selection` is an `EditorSelection` (a segment or a zoom), and ⌫ removes either |

Key facts:
- A new project (no `.edit.json`) gets the automatic zooms; they're saved with the first edit.
  Regenerating replaces automatic zooms and keeps manual ones; editing a zoom makes it manual.
- Zooms closer than 1 s merge when their presses fit one view; otherwise the first ends where the
  second starts, so the view pans across instead of zooming out and in. Presses outside the video
  (e.g. beside a recorded window) are ignored.
- The spring (10 rad/s) finishes 96% of a move in 0.5 s and stops within 0.04 px at 4K after
  about 1.4 s, so frames with no zoom are the source's pixels exactly.
- Only cursor samples inside follow-cursor zooms are placed. Measured on an M1, Debug, 10 min with
  455 zooms (half following the cursor): the plan builds in ~45 ms (camera 36 ms, cursor 9 ms);
  0.1 ms without zooms. A zoomed 4K frame with a ring and a chip renders in 4.7 ms p50 / 8.1 ms p95
  (4.2 / 7.4 unzoomed).
- The soft-zoom hint shows when the recording has under 2 video pixels per screen point
  (`InputTelemetry.pixelsPerPoint`); telemetry doesn't record the Native Resolution setting itself.

### S1 — Editor, phase 5: cursor (`feat/editor-shell`, spec 0003)

A recording made without the cursor gets it back in the editor: drawn from its recorded images at a
smoothed position, sharp when zoomed, with its hot spot on every click highlight. The inspector's
Cursor section shows or hides it and sets its size, movement (Mellow, Smooth, Fast), shrinking on
click and hiding when idle.

| File | Role |
|---|---|
| `Editor/Render/CursorPath.swift` | Positions without jitter, smoothed by a spring at 120 Hz and eased onto each click; the size (capture's pixels per point × style × press) and the idle fade |
| `Editor/Render/CursorShapeTrack.swift` | Shape changes without the brief ones, each image decoded once per plan; an arrow when the telemetry has none |
| `Editor/Render/Spring.swift` | The critically damped spring the camera and the cursor share |
| `Editor/Render/FrameRenderer.swift` | Draws the cursor after zooming, scaled in one step from its recorded resolution |
| `Editor/Model/CursorStyle.swift` | The inspector's settings; `Smoothing.frequency` holds the presets' springs |
| `Service/StandardCursors.swift` | `png(of:)`, shared with the recorder, and `arrowSprite`, the fallback read when the editor opens |

Key facts:
- Drawn only when `capture.cursorInVideo` is false, so the editor never draws a second cursor.
- The path passes exactly through every click and release at its time: the offset from the smoothed
  path to the click point eases in over 0.5 s before and out over 175 ms after, never past the
  neighbouring clicks, and is added at lookup, so it's exact between samples too.
- Presets are critically damped springs at 7, 12.5 and 25 rad/s, trailing a steady move by 290, 160
  and 80 ms. Smooth is Cap's default (tension 470, mass 3) without its 0.03% overshoot. A move back
  by less than 2 pt is jitter and dropped.
- Shapes shown for under 150 ms are dropped. A press shrinks the cursor to 0.8× over 130 ms while
  held. Idle hiding fades out over 0.3 s after 2 s without a move or click, and back in before the
  next one.
- The camera and the cursor are built in parallel (`async let`): measured on an M1, Debug, for 10
  minutes with 455 zooms, 3,000 clicks, 12,000 keys and the cursor moving throughout at 60 Hz, the
  plan builds in ~42 ms instead of ~105 (camera 38 ms, cursor 35 ms).
- The cursor adds 1–1.4 ms to a 4K frame, like any overlay: Core Image composites it over the whole
  frame, so its image's size doesn't matter (34×46 px costs the same as the 280×400 px arrow);
  `highQualityDownsample` adds at most 0.2 ms. These were measured under load (load average 3),
  where a frame without the cursor took 7.5 ms p50, 10.7 ms p95, against 4.2 and 7.4 in phase 4.

### S1 — Editor, phase 6: canvas and export polish (`feat/editor-shell`, spec 0003)

The recording sits on a canvas: a shape (original, 16:9, 9:16, 1:1, 4:3), a gradient, color,
picture or transparent background, padding, rounded corners and a shadow. New projects get the
styled default. Export picks a size and frame rate, and adds ProRes 4444, which keeps a
transparent background; HDR recordings stay HDR in HEVC and ProRes. **Recordings…** in the menu
bar lists the output folder's recordings with pictures; a click opens one in the editor.

| File | Role |
|---|---|
| `Editor/Model/CanvasStyle.swift` | The inspector's canvas settings; `plain` is the recording as it is |
| `Editor/Render/CanvasLayout.swift` | Output size, the video's frame and rounded mask, the backdrop (background and shadow) drawn once into an IOSurface, and the regions frames are drawn in |
| `Editor/Render/FrameRenderer.swift` | `draw(_:at:plan:into:context:)`: the frame region by region, for the compositor and the tests alike |
| `Editor/Render/RenderResources.swift`, `RenderTarget.swift` | What plans draw with from the system (key labels, arrow, background picture); what a plan is for (the preview, or an export's size and dynamic range) |
| `Editor/Render/HDREditorCompositor.swift`, `Editor/Model/DynamicRange.swift` | 10-bit or half-float frames in, half-float out; SDR, PQ or HLG from the track's transfer function |
| `Editor/Service/BackgroundImageLoader.swift` | Security-scoped bookmark to the chosen picture, read upright, in sRGB, at most 4096 px |
| `Editor/Model/ExportSettings.swift`, `Editor/View/ExportSheet.swift` | Format, size (a shorter side) and frame rate; only smaller ones are offered |
| `Editor/Service/RecordingLibrary.swift`, `Editor/ViewModel/RecordingsViewModel.swift`, `Editor/View/RecordingsView.swift` | The Recordings window, opened by `EditorWindowManager.showRecordings()` |

Key facts:
- The canvas keeps the video's shorter side (9:16 from 4K is 2160×3840), and padding (8%), corner
  radius (1.5%) and the shadow's blur (3%) are shares of it. An export at another size is drawn at
  that size, not scaled afterwards. Zoom and canvas placement are one transform, so the video is
  resampled once; the cursor is drawn at its final scale.
- Frames are drawn region by region (`CanvasLayout.regions`): the padding from the backdrop alone,
  the video in 8 bands, its rounded corners with the mask. Core Image evaluates every overlay
  across the whole region it renders; in bands it skips them where they aren't. Measured on an M1,
  Debug, 4K with a ring and a chip, load average 4–6: 3 ms p50 plain (7 drawn whole), 3.7–5 ms on
  the default canvas (9 whole), p95 under 7.5 ms. The backdrop takes 4 ms to draw (17 the first time).
- A transparent background keeps its alpha only in ProRes 4444; other formats export it black.
- HDR frames are drawn without color management too: the plan draws its overlays once in the
  recording's encoding (`OverlayImages.encoded`), SDR white at 203 nits (BT.2408). Their
  semi-transparent parts (the chip's backing, the cursor's shadow, a fading ring) blend in PQ's
  encoding, so over HDR they look a little darker than in SDR. Measured on an M1, Debug, 4K with a
  ring and a chip, load average 2–3: 4–4.6 ms p50 and 5–8 ms p95, against 6.7–8.1 and 10–13 with
  a color-managed context; SDR took 3–3.5 in the same runs. Converting the backdrop costs 9–11 ms
  more per HDR plan (20 the first time), alongside the camera and cursor. The composition is
  tagged BT.2020 and the recording's PQ or HLG; H.264 exports are SDR.
- The Recordings window lists movies in the output folder, newest first, without `-edited`
  exports, reads the list whenever it comes forward, and holds the folder's scope while open.

### S1 — Editor design (`feat/editor-shell`)

The editor and Recordings windows are always dark, a studio: the preview sits raised on a near-black
stage, the transport floats on glass under it, and the timeline and inspector are neutral greys with
one signal orange (`EditorTheme.accent`) for the playhead, the selection and Export.

| File | Role |
|---|---|
| `Editor/View/EditorTheme.swift` | Colors and the one animation every state change uses |
| `Editor/View/View+EditorGlass.swift`, `EditorGlassGroup.swift` | Liquid Glass on macOS 26 (`glassEffect`, `.glassProminent`, `GlassEffectContainer`), a material with a hairline before; `editorMotion(value:)` animates unless Reduce Motion is on |
| `Editor/View/EditorWindowManager.swift` | `makeWindow`: dark appearance, content under a transparent title bar |
| `Editor/View/EditorStage.swift`, `TransportBar.swift`, `EditorIconButtonStyle.swift` | The preview in the canvas's shape with a checkerboard behind transparent canvases; the glass transport |
| `Editor/View/TimelineRuler.swift`, `Playhead.swift`, `ZoomBlock.swift` | The ruler (the finest scale whose labels stay 72 pt apart), the playhead's knob, the zoom blocks |
| `Editor/View/Inspector*.swift`, `TilePicker.swift`, `CanvasInspectorSection.swift` | The inspector's sections, sliders with their values, switches, and tiles whose highlight slides |
| `Editor/View/ExportFormatCard.swift`, `ExportProgressBar.swift` | The export sheet's format cards and progress |

Key facts:
- Glass only on controls over the stage, never on the timeline (content) or over the live video:
  each glass shape costs a sampling pass on the GPU the compositor also uses.
- The inspector keeps the system `.inspector`, which macOS 26 draws as glass, so it has no background.
- `ImageRenderer` can't draw glass content, AppKit controls, `ScrollView`s or the player, and
  `screencapture`/`cacheDisplay` need permission or miss SwiftUI; check the look in the app.

### Telemetry JSON (version 3)

```
version, keystrokesAvailable,
capture:       { kind: display|window|area, videoSize: [w,h], cursorInVideo }  // missing → true
geometry:      [{ time, screenRect, contentRect, boundingRect?, contentScale, scaleFactor }]
cursor:        [{ time, location: [x,y] }]            // only when changed
clicks:        [{ time, location, button, isDown, clickCount }]
scrolls:       [{ time, location, delta: [dx,dy] }]
keys:          [{ time, keyCode, modifiers: [..], isRepeat }]
cursorSprites: [{ id, kind?, size, hotspot, png: base64 }]
cursorShapes:  [{ time, sprite }]
```
CG geometry types encode as arrays (`CGRect` → `[[x,y],[w,h]]`). Bump `version` on incompatible changes
and update `InputTelemetry.supportedVersions`; version 2 files lack `cursorInVideo` and the cursor fields.

## Sandbox findings (measured, keep the app sandboxed)

- `NSEvent.mouseLocation` polling and global mouse/scroll monitors work without any permission.
- Global `NSEvent` **key** monitors never fire in the sandbox (need Accessibility) — don't use them.
- Listen-only `CGEvent.tapCreate(.cgSessionEventTap, …, .listenOnly)` works once Input Monitoring is
  granted; no entitlement or Info.plist key needed.
- `NSCursor.currentSystem` works in the sandbox.

## Roadmap status

| Item | Status |
|---|---|
| F1 input telemetry | Done |
| F2 cursor sprites | Done, incl. editor spec Phase 0 (hidden cursor, `cursorInVideo`, `kind`); a real recording still has to confirm kinds for I-beam/hand |
| F3 `.bettercapture` project bundle | **Not needed for editor v1**, which uses a `<name>.edit.json` sidecar (spec 0003, open question 2). Revisit when opening recordings from outside the output folder |
| F4 pause / resume | Done and verified on real recordings: audio ticks land within ~30 ms across pauses, all tracks match video length (incl. stop while paused) |
| F5 countdown | Done |
| F6 audio robustness (mic hot-swap #208, gain #209, level meters #153) | Todo |
| F7 remember last selection (#172) | Todo |
| F8 Swift 6 language mode | Done (`chore/swift-6-mode`); needs one real recording to rule out runtime isolation crashes |
| S1 editor phase 1: shell and playback | Done; open/scrub/close still need a check on a real 10-min 4K recording (see spec 0003) |
| S1 editor phase 2: render pipeline, click highlights, keystrokes, export | Done; highlight placement still needs checking on real recordings of each capture kind. 4K render measured at the 8 ms p95 budget on an M1 (see spec 0003) |
| S1 editor phase 3: trim, split and cut, audio volume | Done; trimming, cutting and clicks at cuts still need a check in the app on a real recording |
| S1 editor phase 4: auto-zoom, zoom lane, camera | Done; auto-zoom placement, full-frame-rate transitions and editing zooms on the timeline still need a check in the app on real recordings |
| S1 editor phase 5: cursor | Done; smoothing, shapes, idle hiding and the 4K render budget (measured under load) still need a check in the app on real recordings |
| S1 editor phase 6: canvas and export polish | Done; the canvas, a background picture after relaunch, HDR recordings (ProRes too, whose frames carry the tags), transparent exports and the Recordings window still need a check in the app |
| S1 editor design: dark studio, glass transport, new timeline and inspector | Done; glass, hover and animations still need a look in the app on macOS 26 and 15 |

Reference repos for later work: `syi0808/screenize` and `imbhargav5/open-recorder` are Apache-2.0
(portable with attribution). `lzhgus/Capso` (BSL, bans screen-capture use) and
`lihaoyun6/QuickRecorder` (AGPL) are **ideas only — never copy code**.

## Known open items

- Not yet verified on real recordings: area capture mapping, a window moved/resized mid-recording.
- `RecorderViewModel` is over SwiftLint's type size limit (pre-existing); split it before adding more.

## Verifying against real recordings

Recordings can be scripted: select content once in the menu, then drive the running build with
`open -g -a /tmp/bc-build/dd/Build/Products/Debug/BetterCapture.app "bettercapture://toggle"` (starts
when content is selected, stops when recording; no countdown), `bettercapture://pause` and
`bettercapture://edit-last` (opens the editor). Use `-a` with the path:
a plain `open` may launch another copy (e.g. Xcode's DerivedData build). Play `afplay` ticks at
logged wall times, then check each tick lands where expected in the audio, shifted by the paused time.
Watch the app's logs with `/usr/bin/log stream --level info --predicate 'subsystem == "com.sattlerjoshua.BetterCapture"'`
(the full path matters: in zsh, `log` is a builtin).

Frame-level checks beat eyeballing. With `ffmpeg`/`ffprobe` (Homebrew):
- Stream lengths: `ffprobe -v error -show_entries stream=codec_type,duration,nb_frames -of compact <file>`
- Frame at a time: `ffmpeg -ss <t> -i <file> -frames:v 1 out.png`, crop around
  `InputTelemetry.videoPixel(...)` to check the cursor tip lands on the prediction.
