# CLAUDE.md

Coding rules, Swift/SwiftUI conventions and git workflow live in AGENTS.md — follow them:

@AGENTS.md

This file covers what AGENTS.md doesn't: how to build this fork, what it adds on top of upstream
[jsattler/BetterCapture](https://github.com/jsattler/BetterCapture), where that code lives, and what's next.

## What this fork is

Reco is a macOS menu bar screen recorder (ScreenCaptureKit + AVAssetWriter, not sandboxed since 2026-10-01, spec 0007), forked from BetterCapture
and renamed: its own bundle ID (`com.diip3sh.Reco`), `reco://` links, and Reco in every name.
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
xcodebuild -scheme Reco -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bc-build/dd \
  CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=$TEAM \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER="" build -quiet \
  && { pkill -x Reco; open /tmp/bc-build/dd/Build/Products/Debug/Reco.app; }
```

- Tests: same command with `test` instead of `build -quiet` (Swift Testing, 615 tests). `ExportServiceTests.keepsATransparentBackgroundInProRes4444`
  reads alpha 254 instead of 255 with Xcode 26.0.1 on macOS 26.5.2, also without this fork's later changes.
- Lint: `swiftlint lint --quiet <files>` — new code must be clean. Pre-existing warnings:
  `AssetWriter.swift` (file_length, type_body_length, 2× function_body_length) and
  `RecorderViewModel.swift` (file_length, type_body_length). Don't make them worse; SwiftLint skips
  extensions for type_body_length, so new logic goes in same-file extensions or new types.
- Keep build output outside the repo (`/tmp/bc-build`). If the build fails with "There is no
  XCFramework found", `rm -rf /tmp/bc-build` and rebuild (moved DerivedData breaks SPM paths).
- **Don't use ad-hoc signing (`CODE_SIGN_IDENTITY="-"`)**: the code hash changes every build, so
  macOS forgets the Screen Recording permission and prompts forever. If a permission gets stuck:
  `tccutil reset ScreenCapture com.diip3sh.Reco`, then relaunch.
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

## Release builds

**Rule:** every push to `main` that touches the app is built, tested and published to users as an
update by GitHub Actions. **Before pushing to `main`, read `docs/RELEASE.md` and follow its
checklist**; it also covers the workflow, versions, secrets and installing.

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
- New features get a feature folder, `Reco/<Feature>/{Model,Render,Service,ViewModel,View}`
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
| `Service/InputTelemetryRecorder.swift` | Cursor polling (≤60 Hz), a listen-only `CGEventTap` for clicks, scrolls and keys (a global mouse monitor without it), writes the sidecar |
| `Service/CaptureGeometryTracker.swift` | Per-frame `SCStreamFrameInfo` geometry on the capture queue, stored only on change |
| `Service/AssetWriter.swift` | `sessionStartTime` (host time of file time 0) |
| `ViewModel/RecorderViewModel.swift` | Starts telemetry after the last `try` in `startRecording`, writes the sidecar in `stopRecording` while the output folder's security scope is held |

Key facts:
- **Time:** events are stored as host-clock seconds while recording (tap events are stamped on
  arrival; `NSEvent.timestamp`, `CMClockGetHostTimeClock`, SCStream PTS all share it) and rebased at
  stop by `sessionStartTime`.
- **Position:** locations are global CG points, top-left origin. Map to video pixels with
  `InputTelemetry.videoPixel(for:geometry:)` using the `geometry` entry in effect at that time.
  Verified against real frames for display and window captures.
- **Window shadows:** with "Show Window Shadows" on, SCK draws window + shadow scaled into the frame.
  SCK reports only the shadow's total size, so the top/bottom split uses the measured
  `InputTelemetry.shadowTopFraction = 0.35` (macOS 27). Re-measure if Apple changes shadows.
- **Clicks, scrolls and keystrokes** need Input Monitoring (requested when the toggle is turned on;
  effective after relaunch). Without it `keystrokesAvailable` is false, `keys` is empty, and clicks
  and scrolls come from a global `NSEvent` monitor, which needs Accessibility.

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
`reco://pause`. The SCStream keeps running while paused (instant resume, macOS recording
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
recorded (area, window, or display) and the seconds in the menu bar. `reco://toggle` /
`toggle-copy` skip the countdown (and cancel one that's running) so automation stays precise.

| File | Role |
|---|---|
| `Service/RecordingCountdown.swift` | `@Observable` tick loop (`remaining`), cancellable, injectable one-second sleep for tests |
| `View/CountdownOverlay.swift`, `View/CountdownView.swift` | Click-through, non-activating `.screenSaver` dark panel with the number on a 150 pt glass disc (`editorGlass`) that grows in from its centre (`panelPresentation`) and counts with `numericText`; Esc as a temporary global hotkey |
| `Model/CountdownDuration.swift` | Setting enum (`SettingsStore.countdownDuration`) |
| `ViewModel/RecorderViewModel.swift` | `// MARK: - Countdown` extension: `startRecordingWithCountdown()`, `cancelCountdown()`; `toggleRecording(countdown:)` |

Key facts:
- State stays `.idle` while counting (`isRecording` false); `countdown.isRunning` is the flag. When it
  ends, the panel is ordered out *before* the normal `startRecording()`, so it never lands in the video;
  that is why the disc has no exit animation.
- Cancel: Esc, or starting again (menu, shortcut). Nothing is created. Esc is
  `KeyboardShortcuts.events(.keyDown, for: Shortcut(.escape))`: a Carbon hotkey, registered only during
  the countdown, so it swallows Esc system-wide only then. If another app holds a global Esc hotkey,
  registration fails silently; the menu/shortcut still cancel.

### C2 / C7 / C8 / C14 — Quick Access card, text recognition, pins, clipboard (`feat/screenshot-card`)

A CleanShot-style card for each screenshot. After Capture Area it opens beside the pointer, where the drag
ended, on the pointer's sides facing away from the captured area (`Screenshot.region`,
`panelFrame(in:size:pointer:awayFrom:)`). Otherwise it opens in the bottom-left corner of the screen under the
mouse (clear of notifications and the menu bar popover, top-right). The card takes the screenshot's shape
(`cardSize(for:)`: fitted in 260×220, never enlarged, at least 200×120) on an 8 pt glass edge. Under the pointer
the shot dims and shows **Copy ⌘C** and **Save ⌘S** (the shortcut shown dimmed in the button), with Close, **Recognize Text** and **Pin** as small
icons in its corners; hidden, they stay in the view so the shortcuts still work. The card takes key when it appears, without
activating the app, so the shortcuts work until another window is clicked; typing goes to the card meanwhile.
It grows from the card's corner nearest the pointer (`QuickAccessController.anchor(for:pointer:)`, the
bottom-left without a region) and shrinks back there when closed, copied, saved or pinned; `hide()` and
`restore()` stay instant. Drag the card by its 8 pt edge: it follows the pointer 1:1 from where it
was grabbed (`PanelDragger`), and a flick that projects past the screen's edge (`GesturePhysics.flickExit`)
throws it off at the release speed and closes it; a slow drag stays where dropped, a flick inwards too. Drag the shot into
any app to drop the image. The card and the pre-record overlay have no window shadow: it outlines
the rectangle around their rounded glass. Nothing is written until **Save**. The card stays until
closed, copied, saved, pinned, or replaced by the next screenshot. `AppDelegate` wires
`ScreenshotController.onWillCapture` to `hide()` so the card never lands in the next shot, and `onDidCapture` to
`show(_:)` for a new screenshot or `restore()` (same card, same place) when the capture is cancelled or fails.

- **Copy** (C14): PNG data only, then closes. **Save**: writes to `~/Pictures/Reco`, then closes; on
  failure the card stays and the Screenshot Failed notification is sent. **Recognize Text** (C7): the
  image's text to the clipboard. **Pin** (C8): the image in its own panel, then closes. Recognize Text
  confirms on the card for 1.5 s.

| File | Role |
|---|---|
| `QuickAccess/View/QuickAccessController.swift`, `QuickAccessPanel.swift` | Non-activating borderless `.floating` dark panel (key on appearing, `hidesOnDeactivate = false`), enter/exit through `panelPresentation` (`exitDelay` before ordering out; leaving panels are tracked so `hide()` clears them too), placement (`panelFrame`), owns the card's view model and the pins |
| `QuickAccess/ViewModel/QuickAccessViewModel.swift` | One screenshot's intents and feedback, the drag-out file; reports up through `onClose`/`onPin` |
| `QuickAccess/View/QuickAccessView.swift`, `PanelDragger.swift` | Card layout on `editorGlass` (16 pt radius), hover scrim and controls (`.editorPrimary` Copy/Save, dark corner icons), a solid toast; a `DragGesture` on the edge drives `PanelDragger` (screen coordinates, `VelocityTracker`, flick exit), `.onDrag` on the shot. Annotate goes first in the top-right corner once it exists (one line) |
| `QuickAccess/View/PinController.swift`, `PinView.swift` | One `.floating` panel per pin at the shot's point size fitted to the screen (`frame(for:at:in:)`), aspect-locked resize, drag anywhere, close on hover; appears from and closes into its bottom-left corner (`panelPresentation`, a `PanelPresence` per pin) |
| `QuickAccess/Service/ImageDownsampler.swift` | Card preview drawn from the captured `CGImage` off the main actor |
| `Screenshot/Service/TextRecognizer.swift` | Vision `RecognizeTextRequest` (accurate, automatic language) off the main actor; `joined(_:)` orders lines top to bottom |
| `Service/ImagePasteboard.swift` | PNG data on the pasteboard (Slack, Messages, Figma, Preview) |

Key facts:
- The full-size `CGImage` is held only by the card and pins; the card shows a preview drawn at 2× of its
  largest size.
- Drag-out offers the file URL and PNG data. The file is written in the background to
  `temporaryDirectory/<UUID>/<save name>` when the card appears (a drop reads the URL at once, so it must
  exist first) and deleted when the card closes.
- The card and pins are Reco windows, so captures leave them out unless Show Reco is on.
- A window shadow doesn't follow the fade, so pins have it off while entering and leaving and turn it on
  (`invalidateShadow()`) once settled. The card has none.

### S1 — Editor, phase 1: shell and playback (`feat/editor-shell`, spec 0003)

Opens a recording in its own window with the preview, transport controls and a timeline (filmstrip,
click/key lanes, playhead, scrubbing). Entry points: **Edit** on the recording-saved notification (its
default action when the cursor was left out of the video), **Edit Last Recording** in the menu bar, and
`reco://edit-last`. Keys: space play/pause, ←/→ step a frame, ⌘Z/⇧⌘Z undo/redo.

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

A recording with telemetry opens with automatic zooms on its clicks, typing, where the cursor
rested and what it circled. The zoom lane
under the timeline shows every zoom: click to select, drag to move, handles to resize, **Z** adds
one at the playhead, **⌫** deletes the selected one. The inspector's Zoom section sets its scale
and focus (follow the cursor, or a fixed point dragged on a picture of the frame) and regenerates
the automatic zooms.

| File | Role |
|---|---|
| `Editor/Model/ZoomSegment.swift` | Source range, scale, focus (fractions of the video, top-left origin), `isAutomatic`; every edit of the zoom list, which keeps it sorted and apart and makes the zoom it changes manual |
| `Editor/Service/AutoZoomGenerator.swift` | Pure: groups presses (clicks, and keys at the last click), cursor rests and circles that are close in time and fit one view; `Configuration` holds the constants |
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
- The cursor rests where it stays within 2% of the video for 0.5 s, at least 15% from where it last
  rested; the rest counts when it arrived. Recordings without clicks still zoom: two real 13 s
  window recordings got 2 and 3 zooms.
- Circling zooms from when it starts: the path, in steps of 1% of the video, turns all the way round
  within one view, without a pause or a turn sharper than 135°, and ends within half its size of
  where it started; the move into it is trimmed off. Real circling was 40–110 pt across, a turn
  every 0.3–0.5 s, with oval, pointed ends. On three real recordings it found all 10 circled spots and
  nothing else; without the closure rule, the curve leading into a circle joined it. Measured on an
  M5, Debug, 10 min of cursor at 60 Hz: circles add 15–45 ms to the ~34 ms generation takes, once,
  when a recording opens or zooms are regenerated.
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

The editor and Recordings windows use the system's colors, so they follow the user's appearance (light
or dark) and accent color: the window background (80%) the desktop frosts through, text in the label
tones (ink, dim, faint), separators instead of boxes, a label-colored Export button, and the accent
(`EditorTheme.accent`, `Color.accentColor`; the asset catalog's AccentColor is empty) for the playhead and
the selection. No panel forces an appearance. The preview sits on a faint dot grid, the transport floats on
glass under it. Nothing else is colored: clicks, keys and zooms are greys, and the default canvas is a
slate gradient.

| File | Role |
|---|---|
| `Editor/View/EditorTheme.swift` | System colors by role, spacing on a 4-point grid, and the motion tokens: `motion` (spring, response 0.35, critically damped: every state change), `quickMotion` (0.15: hover, release), `momentumMotion` (damping 0.8: only after a flick), `fadeMotion` (Reduce Motion's cross-fade) and `release(velocity:distance:)` (a drag's release speed handed to a spring) |
| `Editor/View/View+EditorGlass.swift`, `EditorGlassGroup.swift` | Liquid Glass on macOS 26 (`glassEffect`, `GlassEffectContainer`), a material with a hairline before; `editorWindowBackground()`; `editorMotion(value:)` animates unless Reduce Motion is on (`nil` skips it); `withMotion { }` is the same for code with no environment; Increase Contrast adds a `dim` edge to every glass surface |
| `Editor/View/EditorBackdrop.swift`, `StageDotGrid.swift` | The frosted desktop behind the window; the dot grid behind the preview, fading out before the stage's edges |
| `Editor/View/EditorButtonStyle.swift` | `.editorPrimary` (off-white) and `.editorGhost` (hairline) text buttons; every press shows on the frame it lands, only hover and release ease |
| `View/PanelPresentation.swift`, `PanelPresence.swift` | `panelPresentation(isPresented:anchor:)`: a floating panel fades and settles from 0.96 anchored at its source and goes back there (opacity only with Reduce Motion); `exitDelay` is how long its window stays; `PanelPresence` carries the flag for controllers whose view model can't. Used by the agent bar, Quick Access card, pins, pre-record overlay and countdown |
| `View/MenuRowButtonStyle.swift` | `.menuRow` for the popover's rows: a fill 4 pt in from the edges, 0.08 on hover, 0.14 the moment it's pressed, dimmed when disabled |
| `Model/GesturePhysics.swift` | Pure: `project` (momentum), `rubberband`/`rubberbanded` (resistance past a boundary), `relativeVelocity`, `velocityMatchedDuration`, `flickExit`, and `VelocityTracker` (the last 0.1 s of a drag) |
| `Editor/View/EditorWindowManager.swift` | `makeWindow`: content under a transparent title bar |
| `Editor/View/EditorStage.swift`, `TransportBar.swift`, `EditorIconButtonStyle.swift` | The preview in the canvas's shape with a checkerboard behind transparent canvases; the glass transport |
| `Editor/View/TimelineRuler.swift`, `Playhead.swift`, `ZoomBlock.swift` | The ruler (the finest scale whose labels stay 72 pt apart), the playhead's knob, the zoom blocks |
| `Editor/View/Inspector*.swift`, `TilePicker.swift`, `CanvasInspectorSection.swift` | Sections that fold away under a dim title, sliders with their values, switches, and tiles whose highlight slides; a notice on top when the telemetry is missing |
| `Editor/View/ExportSheet.swift`, `ExportProgressBar.swift` | Native pickers in a grid with a line on what the format is for; progress |

Key facts:
- Glass only on controls over the stage, never on the timeline (content) or over the live video:
  each glass shape costs a sampling pass on the GPU the compositor also uses.
- The inspector keeps the system `.inspector`, which macOS 26 draws as glass, so it has no background.
- Text is ink by default, so it doesn't dim when disabled: `InspectorSection` fades disabled content.
- Avoid what reads as generated: no gradients or glows in the chrome, no second accent, no cards
  and badges where a native control works, no all-caps titles, hover as a fill step (no lifts or
  scaling).
- Two visual families, one motion system: the system-native popover and Settings, and this studio
  look (editor, Recordings, Web Recording, the agent bar and the floating capture panels: Quick Access card,
  pins, pre-record overlay, countdown).
- Motion follows the apple-design skill: respond on press, move 1:1 from the grab point, springs that start
  from the current value, bounce only after a flick, symmetric enter and exit from the source. Timeline
  clip and trim-handle drags resist past the ends (`rubberbanded`) and release into `release(velocity:distance:)`,
  so what the timeline refuses springs home from where it was shown; the zoom focus pad keeps the offset
  from where its outline was grabbed.
- The pre-record overlay drops from the status item (`panelPresentation(anchor: .top)`); dismissing stops the
  preview at once, and showing it again during the exit turns it round and restarts the preview. Its Live
  mark (`LiveIndicator`, also on the popover's preview) is a red dot and a word, static.
- Area selection fades its dim in over 0.12 s on the first drag (instant with Reduce Motion), and its
  Confirm and Cancel are system buttons (glass on macOS 26) with Return and Esc as key equivalents.
- Skipped on purpose: Settings, the menu bar label, the export sheet, momentum on timeline edits, rubber-banding
  area selection, pin flick, scrubbing.
- `ImageRenderer` can't draw glass content, AppKit controls, `ScrollView`s or the player, and
  `screencapture`/`cacheDisplay` need permission or miss SwiftUI; check the look in the app.

### C1 — Screenshots

Menu bar **Capture Area / Capture Window / Capture Screen** and global shortcuts of the same names
(Settings → Shortcuts → Screenshots, no defaults; no URLs yet). Both follow `canCapture(alongside:)`: idle only,
so a shortcut pressed while recording, counting down or capturing is ignored and logged.
Capture Area freezes the screen first: every display is captured when it starts (`ScreenshotService.captureDisplays`),
the overlay shows that picture (`AreaSelectionPanel.show(_:over:)`), and the area is cut from it
(`Screenshot.cropped(to:)`), so hover states, tooltips and open menus the overlay takes away from the apps
under it are still in the shot. Capture Area shoots as soon as the drag ends (`AreaSelectionOverlay.present(confirmsOnRelease:)`); a click, a
drag under 24 pt (`AreaSelectionView.drawingRelease`) or Esc cancels. Its overlay never activates the app or
takes key, so a menu or dropdown open in another app stays open and lands in the shot; Esc is a temporary
global hotkey, as in the countdown. macOS ignores cursor changes from an app that isn't frontmost, so
`BackgroundCursor` turns on the window server's private `SetsCursorInBackground` switch while the overlay is up
(looked up at run time; without it the pointer just stays an arrow). Not yet seen working in the app. Recording keeps drag, adjust and Confirm, and takes the keyboard for Return.
Captures at native pixels with the recording visibility settings into memory (`Screenshot`: image, scale,
capture time) and hands it to `ScreenshotController.onDidCapture` (the Quick Access card, C2). Nothing is
written until the card's **Save**: `ScreenshotController.save(_:)` writes
`Reco_Screenshot_<capture time>.png` into `~/Pictures/Reco` (`ScreenshotService.directory`), whichever folder
recordings go to.

| File | Role |
|---|---|
| `Screenshot/Model/Screenshot.swift` | The captured `CGImage`, its scale and capture time; `filename`, `pointSize` |
| `Screenshot/ViewModel/ScreenshotController.swift` | Owned by `AppDelegate` (which registers the shortcuts); permission check, selection, `isCapturing`, `canCapture`, `onWillCapture`/`onDidCapture`, `save(_:)` with the failure notification |
| `Screenshot/Service/ScreenshotService.swift` | Display lookup, `SCScreenshotManager.captureImage`, save into `~/Pictures/Reco`, PNG via ImageIO (`@concurrent`) |
| `Screenshot/Service/WindowPicker.swift` | System `SCContentSharingPicker` in `.window` mode, observed only while picking |
| `Screenshot/View/ScreenshotButtons.swift` | The three popover rows |
| `Service/SCContentFilter+CaptureScale.swift` | Window-scale fix shared with recording (moved from `RecorderViewModel`) |

Key facts:
- Shared with recording: `CaptureSizeCalculator.sourceRect` (area → display rect), `filter.captureScale`,
  `SettingsStore.filename(prefix:fileExtension:date:)`, `ContentFilterService.applySettings`.
- `SCContentSharingPicker.shared` reports results to every observer. `CaptureEngine.isPickingContent`
  makes the recording selection ignore picks it didn't ask for.
- Cursor follows `showCursor`, not `capturesCursor`: there's no editor to redraw it.
- Capture Screen waits 250 ms for the popover's close animation (only matters with Show Reco on).
- Window shots use the window recording config: SCK fits window + shadow into the window's frame, so
  shadow padding is uneven (same as recordings).
- Verified on an M2 (1710×1112 pt, 2×): screen 3420×2224, window and area at 2×, sRGB, no Reco UI.

### S2 — Web recordings (`feat/web-recordings`, spec 0005)

**New Web Recording…** in the menu bar opens a window with a live web page at a viewport preset, a
timeline with a Cursor lane (Hover, Click) and a Scroll lane, and an inspector. **Hover** and
**Click** add a clip at the playhead and start pick mode: the next click in the page aims the clip at
that element. **Scroll** adds a clip ending where the page is scrolled now. **Render** plays the
script frame by frame into `Reco_Web_<date>.mov` and its telemetry sidecar in the output
folder, then opens it in the editor, where auto-zoom, the cursor and the canvas work as on any
recording.

| File | Role |
|---|---|
| `WebRecording/Model/WebScript.swift` | URL, viewport, scale, length, the two lanes; scroll offset, cursor position and presses at any time |
| `WebRecording/Model/PointerTrack.swift` | The cursor's location frame by frame: follows its target during a clip, rests after it, travels on an arc |
| `WebRecording/Model/WebTakeTelemetry.swift`, `CursorKind+CSS.swift` | The take's telemetry (`capture.kind` `web`); CSS `cursor` values to standard cursors |
| `WebRecording/Service/WebClockScript.swift` | The page's own clock (rAF, timers, `Date`, `performance.now`, animations), stepped by the renderer |
| `WebRecording/Service/WebPageRenderer.swift`, `WebMovieWriter.swift`, `OffscreenWebWindow.swift` | The take: an offscreen web view, one clock step, pointer events and snapshot per frame, HEVC out |
| `WebRecording/Service/WebMuteScript.swift` | Silences the take's page: media elements, and Web Audio through a silent gain |
| `WebRecording/Service/WebPreviewController.swift`, `WebPickScript.swift` | The window's live page (`pageZoom` to fit), pick mode in its own content world, scrubbing |
| `WebRecording/ViewModel/WebRecordingViewModel.swift` | Edits with undo, picking, playhead, render; the script kept in `~/Library/Application Support/com.diip3sh.Reco` (`WebScriptStore`) |
| `Model/TimelineClip.swift`, `Editor/View/TimelineLane.swift`, `TimelineBlock.swift` | Lane operations and the lane and block views, shared with the zoom lane |
| `Model/EditCoalescing.swift` | Which edits share an undo step, for the editor and this window |

Key facts (measured on an M5, macOS 26.5, spec 0005):
- **Hover:** WebKit hit-tests a plain mouse move only in an active window; otherwise it goes to
  scrollbars alone. `WKWebView.sendPointer(.move, at:)` sends a right-button drag, which is always
  hit-tested; the page sees `buttons: 0` and no press. Clicks are real mouse downs and ups. A move
  is also sent when the page scrolls or changes under a resting pointer: WebKit's own move after a
  scroll needs an active window.
- **Visibility:** a page in an occluded or offscreen window is hidden (rAF stops, pages pause
  media). `OffscreenWebWindow` reports its `occlusionState` as visible.
- **Clock:** follows real time while the page loads (freezing it from the start broke linear.app),
  then moves exactly 1/60 s per frame. A 300 ms hover transition read exactly half-way at 150 ms.
  Animations are finished at their end so `transitionend` fires; nested timers wait ≥ 4 ms. An
  animation the page pauses (`pause()`, CSS `animation-play-state`) holds its time.
- **Navigation:** a scripted click that opens a page cuts to it: frames wait off the clock while it
  loads, and a frame call still in flight when the new page commits is ended (WebKit fails it only
  once garbage collected, 106 s measured). A 6 s 2× take of apple.com/macbook-pro that clicks Buy
  and scrolls the store rendered in 17.8 s.
- **Loading:** a frame waits up to 5 s for images in view and fonts; what misses that isn't waited
  for again (a hung image cost one frame 5 s, not every frame). The first load waits for the page's
  `didFinish`, so a subresource that hangs from the start fails the take after a minute.
- **Speed:** snapshots are painted on the CPU: 2880×1800 took 14 ms (simple page), 35 ms
  (apple.com) and 310 ms (linear.app; 64 ms at 1×). A 3 s apple.com take rendered in 8.5 s.
- The take and the preview share the default website data store, so a cookie banner dismissed in
  the preview stays dismissed in the take.
- App Transport Security blocks plain `http://` pages (measured on neverssl.com); `http://localhost` loads.

### S3 — Agent Bridge (`feat/agent-bridge`, spec 0006)

Coding agents (Claude Code, Codex, OpenCode, Cursor, Gemini CLI, Claude Desktop, Grok Build) record a
web page from its address. **Settings → Agents** finds the installed ones and adds a server named `reco` to
each one's own settings. The agent then calls three MCP tools: `inspect_page` (selectors and boxes of a
page), `record_page` (hover, click and scroll steps rendered like spec 0005, opened in the editor) and
`render_status`. Started with `--mcp`, the app only pipes stdio to the running app's Unix socket, and
starts the app first if needed.

| File | Role |
|---|---|
| `RecoMain.swift` | `@main`: `--mcp` runs `AgentBridgeClient`, else `RecoApp.main()` |
| `AgentBridge/Service/AgentBridgeClient.swift` | The `--mcp` process: launches Reco if the socket is absent, token line, stdin/stdout pipe |
| `AgentBridge/Service/AgentBridgeServer.swift` | `NWListener` on `URL.recoSupport/agent.sock`; one SDK `Server` per connection; the per-install token |
| `AgentBridge/Service/AgentSocketTransport.swift` | MCP `Transport` actor: first line must be the token, then newline-delimited JSON |
| `AgentBridge/Service/AgentTools.swift` | Runs the tools; one render at a time, long-poll `wait` |
| `AgentBridge/Service/AgentConfigStore.swift` | Reads and edits agents' settings; atomic rename, refuses symlinks |
| `AgentBridge/Model/` | Pure: `AgentKind`, `AgentJSONConfig`, `AgentTOMLConfig`, `AgentToken`, `LineBuffer`, `AgentToolCatalog`, `InspectPageRequest`, `RecordPageRequest`, `RecordPlan`, `RenderStatus` |
| `AgentBridge/ViewModel`, `View` | `AgentsSettingsViewModel`, `AgentsSettingsView` |
| `WebRecording/Service/WebPageRenderer.swift` | `inspect(selectors:)` and `renderTake(_:settings:progress:)`, shared with the window |
| `WebRecording/Service/WebInspectScript.swift`, `Model/PageInspection.swift` | What `inspect_page` returns |
| `WebRecording/Service/WebPickScript.swift` | `selectorFunctions`, shared so pick and inspect name elements alike |

Key facts:
- The socket is `~/Library/Application Support/com.diip3sh.Reco/agent.sock` (61 bytes plus the user
  name; a Unix socket path holds 104), found through the password database's home, not `$HOME`. No HTTP
  server or TCP port. Any process of the same user can reach it, so the token (`RECO_BRIDGE_TOKEN` in the agent's
  `env`, kept in UserDefaults as `agentBridgeToken`) is the guard: checked once per connection as its
  first line, and never logged.
- `record_page` and `render_status` wait 45 s, `inspect_page` 40 s: under the 60 s tool timeout of Codex
  and Claude Desktop. A longer render is followed with `render_status`.
- Windsurf is left out (config path unverifiable). `CODEX_HOME`, `GROK_HOME`, XDG and `OPENCODE_CONFIG`
  aren't followed (they could be now); `opencode.jsonc` isn't handled.
- Edited JSON keeps its content but its key order becomes sorted. Files with comments are refused.
- The test host is Reco, so its server takes `agent.sock` from a running Reco while tests run.
- The `--mcp` client is covered by `AgentBridgeClientTests`: the test host starts another copy of itself.
- Config files are written through a temporary file next to the target, then `rename(2)`.

### S4 — Agent recording (`feat/agent-bridge`, spec 0007)

**Record with AI Agent…** in the menu bar, and the shortcut of the same name (Settings → Shortcuts →
Web Recording, no default), open a Spotlight-style bar: website address, a description of the video,
an agent, a model and **Record**. Reco runs the agent's command line headlessly with only its own
three MCP tools allowed; the agent records through the bridge (S3) and the editor opens. While it
runs the bar and the menu bar (a sparkle, "AI", then the render's percent) show it; **Cancel** stops
the command line. A failure shows its reason with **Retry** in the bar and in a notification.

| File | Role |
|---|---|
| `AgentRecording/Model/AgentRecordingRequest.swift`, `AgentInvocation.swift` | Pure: the prompt; every agent's exact arguments, environment and support files (`make(for:in:)`, the one place that knows the flags) |
| `AgentRecording/Model/AgentModelCatalog.swift`, `AgentRunOutcome.swift`, `OutputTail.swift`, `LoginEnvironment.swift` | Pure: model lists; process end + render → outcome; the last 16 KB and the reason shown; login shell environment parsing and `PATH` lookup |
| `AgentRecording/Service/AgentProcess.swift` | `Process` with pipes, time limit, cancel (SIGTERM, SIGKILL after 3 s); `loginEnvironment()` |
| `AgentRecording/ViewModel/AgentRecordingViewModel.swift` | Fields, remembered agent and model, `refreshAgents()`, `run`/`retry`/`cancel`, `menuBarText`; watches `AgentTools.job` |
| `AgentRecording/View/AgentRecordingPanelController.swift`, `AgentRecordingView.swift`, `AgentRecordingFooter.swift`, `AgentRecordingFailure.swift` | The non-activating `QuickAccessPanel`, its content, footer by state, failure row |
| `Service/ContainerMigration.swift`, `Service/URL+RecoPaths.swift` | One-time move from the old sandbox container; `userHome` and `recoSupport` |
| `Service/NotificationService.swift` | `AGENT_RECORDING_FAILED` category with Retry |
| `RecoApp.swift` (`MenuBarLabel`) | `fixedWidthImage(_:reference:symbol:)`, shared by the timer and the agent state |

Key facts:
- Commands run with the user's **login shell environment** (`$SHELL -l -i -c "printf marker; env -0"`, 10 s,
  read again each time the bar opens; 0.86 s here), never through a shell string; binaries are found on
  that `PATH`. Claude Desktop has no command line and isn't offered.
- Only Reco's tools run: Claude `--tools "" --allowedTools mcp__reco__*`, Codex `approve` mode and a
  read-only sandbox, OpenCode inline permission config, Gemini policy file, Grok `dontAsk` (its read-only
  built-ins remain), Cursor workspace `cli.json`. Codex wasn't run (not installed).
- Claude Code gets Reco's server from `AgentRun/reco-mcp.json` with `--strict-mcp-config` (spec 0008), so it
  needs no connecting and works with `CLAUDE_CONFIG_DIR` set; Cursor gets its workspace `mcp.json`. Both are
  offered once their command line is on `PATH`; the others must be connected.
- The run's limit is **15 minutes** (a 30 s apple.com take at 2x is 1–2 minutes; linear.app needs 18 for 60 s).
  After the agent exits its render is waited for.
- Outcome rules (in order): cancelled; a new render `done` is a success even after a bad exit; time-out;
  launch failure; non-zero exit with the last output lines; zero exit with a failed render; zero exit
  without a render. The bridge token is replaced by "…" in any reason.
- "Set Up Agents…" sends `showSettingsWindow:` (`openSettings` belongs to a scene) after writing the
  Agents tab to the `settingsTab` default.
- The panel's motion follows the apple-design skill: one `isPresented` flag drives a bounce-free spring,
  so closing and reopening mid-animation retargets; Reduce Motion cross-fades, Reduce Transparency is solid.

### S5 — Agent chat and reliable web takes (`feat/ui-polish`, spec 0008)

A web take's editor has **Style | Agent** at the top of the inspector. Agent is a chat: the conversation that
made the take, the run's state ("Looking at apple.com…", "Recording… 42%", Cancel) and a message box (↩
records, ⌥↩ new line) with the agent and model. Sending has the agent record the take again with the change;
the window swaps to the new take in the same look, the conversation carried over. Takes are checked as they
render and the problems go back to the agent as `warnings`.

| File | Role |
|---|---|
| `AgentRecording/Model/AgentChatMessage.swift`, `AgentRecordedTake.swift` | A message (user, agent, failure); a run's take with its conversation and the take it replaces |
| `AgentRecording/Model/AgentRecordingRequest.swift` | `take` (`RecordPageRequest(script:)`) and `conversation` in the prompt; replies of a sentence or two |
| `AgentRecording/ViewModel/AgentChatViewModel.swift` | Per editor window: reads `<name>.web.json`, sends through the one runner, failure folding, saving |
| `AgentRecording/View/AgentChatView.swift`, `AgentChatMessageRow.swift`, `AgentChatComposer.swift` | The chat |
| `WebRecording/Model/WebTake.swift` | `<name>.web.json` v1: the take's script and conversation, written by `renderTake` |
| `WebRecording/Model/WebTakeIssues.swift` | A cursor target missing, outside the view or covered at its clip's start; skipped clicks; unfound scrolls |
| `WebRecording/Model/ScrollClip.swift` | `Target` (`top` or `intoView`), aimed again on the clip's first frame |
| `AgentBridge/Model/RecordPlan.swift` | An `intoView` scroll before each cursor clip where there's room; blind clicks refused |
| `Editor/View/EditorWindowManager.swift` | `open(_ take: AgentRecordedTake)`: loads the new take, then swaps it into the replaced take's window (same hosting controller), in its look (`EditorProject.styled(like:)`) |

Key facts:
- A 60 s apple.com take at 2× renders in 81–91 s on an M5. Claude Code made one from "a 1 minute demo of
  apple.com…" in 207 s and 6 turns ($0.72): it got a "menu covers your target" warning, added a hover to
  close the menu and recorded again with none.
- In-view means wholly inside the viewport; an `intoView` scroll moves as little as it takes, ending 15%
  from the edge, up to 1 s long, after the previous cursor clip and scroll, and only with 0.2 s of room.
- The cursor stays inside the viewport and glides in from its middle before the first clip (≤ 1 s).
- Web takes: zooms hold for each whole stop (`AutoZoomGenerator.Configuration(for:)`), every stop counts,
  a scroll ends one 0.3 s in and splits groups; the cursor isn't smoothed (Movement disabled). Web
  telemetry records scrolls; a scroll starts after 0.25 s without events.
- While a run of Reco's own goes, a finished render doesn't open by itself; the run's end opens its take.
- The swap loads the new take before showing it: a window whose hosting view shows the loading placeholder
  shrinks to its minimum, and a new controller resizes the window to itself. Per-take views are `.id`'d
  inside `.inspector`, not around it: an `.id` around it laid the split out 160 pt wider than the window.
- Chat turns measured from the editor (Claude Code, default model): 48 s, 86 s, 30 s and 21 s, each a new take.
- On macOS 26.5 a refused connection commits `about:blank` and finishes; `didFinish` on `about:` fails the load.
- `inspect_page` scrolls the page down and back first (0.8 viewport steps, 100 ms), leaves out elements off
  to the sides and gives links an `href`. Step defaults: first at 1 s, 0.8 s apart, 1.5 s per hover or
  click, 2 s per scroll, 1.5 s after the last.

### Telemetry JSON (version 3)

```
version, keystrokesAvailable,
capture:       { kind: display|window|area|web, videoSize: [w,h], cursorInVideo }  // missing → true
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

## Permission findings and the sandbox decision

**2026-10-01: the App Sandbox is removed** (spec 0007): agent command lines need the user's `PATH`,
logins and settings, and a sandboxed parent's children inherit the sandbox. Entitlements are only
`device.audio-input` and `device.camera`. Paths: `URL.userHome` (passwd, ignores `$HOME`),
`URL.recoSupport` (`~/Library/Application Support/com.diip3sh.Reco`: `WebScript.json`, `agent.sock`,
`AgentRun/`). `ContainerMigration` moves the old container's settings (agent token included) and
Application Support files over once. Test `UserDefaults` suites come from `TemporaryDefaults` (named by a temp path, so no plists
land in `~/Library/Preferences`). Unsandboxed, `startAccessingSecurityScopedResource()` returns false for a plain
`NSOpenPanel` URL, so never treat false as failure.

The findings below were measured while sandboxed; the TCC facts (Accessibility, Input Monitoring)
should hold but need re-measuring.


- `NSEvent.mouseLocation` polling works without any permission. Global mouse/scroll monitors need
  Accessibility (Apple DTS, developer.apple.com/forums/thread/811443): on macOS 26.3 two recordings
  made while clicking got no clicks or scrolls.
- Global `NSEvent` **key** monitors never fire in the sandbox (need Accessibility) — don't use them.
- Listen-only `CGEvent.tapCreate(.cgSessionEventTap, …, .listenOnly)` works once Input Monitoring is
  granted; no entitlement or Info.plist key needed. It records keys, clicks and scrolls.
- `NSCursor.currentSystem` works in the sandbox.

## Roadmap status

| Item | Status |
|---|---|
| F1 input telemetry | Done |
| F2 cursor sprites | Done, incl. editor spec Phase 0 (hidden cursor, `cursorInVideo`, `kind`); a real recording still has to confirm kinds for I-beam/hand |
| F3 `.reco` project bundle | **Not needed for editor v1**, which uses a `<name>.edit.json` sidecar (spec 0003, open question 2). Revisit when opening recordings from outside the output folder |
| F4 pause / resume | Done and verified on real recordings: audio ticks land within ~30 ms across pauses, all tracks match video length (incl. stop while paused) |
| F5 countdown | Done |
| F6 audio robustness (mic hot-swap #208, gain #209, level meters #153) | Todo |
| F7 remember last selection (#172) | Todo |
| F8 Swift 6 language mode | Done (`chore/swift-6-mode`); needs one real recording to rule out runtime isolation crashes |
| C2 Quick Access card | Done; buttons, card drag, drag-out and pins still need a hands-on check |
| C7 recognize text (OCR) | Done, from the card |
| C8 pin screenshot | Done, from the card |
| C14 copy image to clipboard (PNG) | Done (`ImagePasteboard`) |
| S1 editor phase 1: shell and playback | Done; open/scrub/close still need a check on a real 10-min 4K recording (see spec 0003) |
| S1 editor phase 2: render pipeline, click highlights, keystrokes, export | Done; highlight placement still needs checking on real recordings of each capture kind. 4K render measured at the 8 ms p95 budget on an M1 (see spec 0003) |
| S1 editor phase 3: trim, split and cut, audio volume | Done; trimming, cutting and clicks at cuts still need a check in the app on a real recording |
| S1 editor phase 4: auto-zoom, zoom lane, camera | Done; auto-zoom placement, full-frame-rate transitions and editing zooms on the timeline still need a check in the app on real recordings |
| S1 editor phase 5: cursor | Done; smoothing, shapes, idle hiding and the 4K render budget (measured under load) still need a check in the app on real recordings |
| S1 editor phase 6: canvas and export polish | Done; the canvas, a background picture after relaunch, HDR recordings (ProRes too, whose frames carry the tags), transparent exports and the Recordings window still need a check in the app |
| S1 editor design: system colors, glass transport, new timeline and inspector | Done; glass, hover and animations still need a look in the app on macOS 26 and 15 |
| C1 screenshots (area, window, screen) | Done, verified on real captures; each shot opens the Quick Access card and is saved only from it |
| S2 web recordings (spec 0005) | Done and tested; the window's view model was driven end to end on apple.com (pick, render, editor, export). The window itself (buttons, timeline dragging, pick banner) still needs clicking through by hand |
| S3 agent bridge (spec 0006): MCP server for coding agents | Done; tested over the real socket (token, `initialize`, `tools/list`, error calls), the `--mcp` process (`AgentBridgeClientTests`), config editors and plans. Not yet tried: real agents connected by hand, a real `record_page` render, Gatekeeper on another Mac |
| S4 agent recording (spec 0007): Record with AI Agent bar, no App Sandbox | Done and tested with fakes and real `/bin/sh` processes; the login-shell environment was read on this Mac (0.86 s). Not yet tried: any real agent run, the panel in the app (focus, Esc, picker menus, Reduce Motion/Transparency), the update from the sandboxed release (migration), Codex |
| S5 agent chat and reliable web takes (spec 0008) | Done and tested: real Claude Code runs from the prompt and from the chat in the app (sent through accessibility), 60 s apple.com takes checked frame by frame. Not yet tried: Retry and Cancel by hand, VoiceOver, Reduce Motion, other agents |

What to build next, ranked from a September 2026 survey of competitors and Apple's on-device APIs:
`docs/specs/0004-next-features.md`.

Reference repos for later work: `syi0808/screenize` and `imbhargav5/open-recorder` are Apache-2.0
(portable with attribution). `lzhgus/Capso` (BSL, bans screen-capture use) and
`lihaoyun6/QuickRecorder` (AGPL) are **ideas only — never copy code**.

## Known open items

- New editor windows open at their 560×492 minimum instead of 1280×800 (seen on `feat/ui-polish` before
  spec 0008 too): the window takes the loading placeholder's size.

- Not yet verified on real recordings: area capture mapping, a window moved/resized mid-recording.
- `RecorderViewModel` is over SwiftLint's type size limit (pre-existing); split it before adding more.

## Verifying against real recordings

Recordings can be scripted: select content once in the menu, then drive the running build with
`open -g -a /tmp/bc-build/dd/Build/Products/Debug/Reco.app "reco://toggle"` (starts
when content is selected, stops when recording; no countdown), `reco://pause` and
`reco://edit-last` (opens the editor). Use `-a` with the path:
a plain `open` may launch another copy (e.g. Xcode's DerivedData build). Play `afplay` ticks at
logged wall times, then check each tick lands where expected in the audio, shifted by the paused time.
Watch the app's logs with `/usr/bin/log stream --level info --predicate 'subsystem == "com.diip3sh.Reco"'`
(the full path matters: in zsh, `log` is a builtin).

Frame-level checks beat eyeballing. With `ffmpeg`/`ffprobe` (Homebrew):
- Stream lengths: `ffprobe -v error -show_entries stream=codec_type,duration,nb_frames -of compact <file>`
- Frame at a time: `ffmpeg -ss <t> -i <file> -frames:v 1 out.png`, crop around
  `InputTelemetry.videoPixel(...)` to check the cursor tip lands on the prediction.
