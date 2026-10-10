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

- Tests: same command with `test` instead of `build -quiet` (Swift Testing, 760 tests). `ExportServiceTests.keepsATransparentBackgroundInProRes4444`
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
- Don't add `.metal` files: Xcode 26 builds them only with the separately downloaded Metal Toolchain,
  which every builder and CI would need. Core Image kernels are `.metal.txt` resources compiled at run
  time (`FieldRenderer`).
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
or dark): the window background (60%) the desktop frosts through, text in the label
tones (ink, dim, faint), separators instead of boxes, a label-colored Export button, controls in ink
(`EditorSlider`, the `.inspector` switch, `EditorSegmentedPicker`: no system accent anywhere), and one accent
(`EditorTheme.accent`, a warm orange, whatever the user's accent color) for the playhead and
the selection. No panel forces an appearance. The preview sits on a faint dot grid, the transport floats on
glass under it, the timeline lies in a rounded tray (`EditorTheme.tray`, 5% of the label color, 10 pt
continuous corners) inset from the window's edges, and the inspector and the agent chat share a glass panel
floating beside them (`EditorSidePanel`, 320 pt wide, 10 pt corners), which the toolbar button slides away.
The ground lets the desktop through at 60%. Nothing else is colored: clicks, keys and zooms are greys, and the default canvas is a
slate gradient.

| File | Role |
|---|---|
| `Editor/View/EditorTheme.swift` | System colors by role, spacing on a 4-point grid, and the motion tokens: `motion` (spring, response 0.35, critically damped: every state change), `quickMotion` (0.15: hover, release), `momentumMotion` (damping 0.8: only after a flick), `slideMotion` (response 0.4, damping 0.72: a switch's knob, a tab's thumb, landing with a small bounce), `fadeMotion` (Reduce Motion's cross-fade) and `release(velocity:distance:)` (a drag's release speed handed to a spring) |
| `Editor/View/View+EditorGlass.swift`, `EditorGlassGroup.swift` | Liquid Glass on macOS 26 (`glassEffect`, `GlassEffectContainer`), a material with a hairline before; `editorWindowBackground()`; `editorMotion(value:)` animates unless Reduce Motion is on (`nil` skips it); `withMotion { }` is the same for code with no environment; Increase Contrast adds a `dim` edge to every glass surface |
| `Editor/View/EditorBackdrop.swift`, `StageDotGrid.swift` | The frosted desktop behind the window; the dot grid behind the preview, fading out before the stage's edges |
| `Editor/View/EditorButtonStyle.swift` | `.editorPrimary` (off-white) and `.editorGhost` (hairline) text buttons; every press shows on the frame it lands (the button shrinks to 0.97, icon buttons to 0.92), only hover and release ease |
| `Editor/View/MaterializeTransition.swift` | `.materialize(offset:)`: SwiftUI content sharpens from a 6 pt blur, settles from 0.98 and fades in, and leaves the same way (opacity only with Reduce Motion). Chat rows, the chat's empty state, the stage's error. Not for AppKit controls or the player, which SwiftUI can't blur |
| `View/PanelPresentation.swift`, `PanelPresence.swift` | `panelPresentation(isPresented:anchor:)`: a floating panel fades and settles from 0.96 anchored at its source and goes back there (opacity only with Reduce Motion); `exitDelay` is how long its window stays; `PanelPresence` carries the flag for controllers whose view model can't. Used by the agent bar, Quick Access card, pins, pre-record overlay and countdown |
| `View/MenuRowButtonStyle.swift` | `.menuRow` for the popover's rows: a fill 4 pt in from the edges, 0.08 on hover, 0.14 the moment it's pressed, dimmed when disabled |
| `Model/GesturePhysics.swift` | Pure: `project` (momentum), `rubberband`/`rubberbanded` (resistance past a boundary), `relativeVelocity`, `velocityMatchedDuration`, `flickExit`, and `VelocityTracker` (the last 0.1 s of a drag) |
| `Editor/View/EditorWindowManager.swift` | `makeWindow`: content under a transparent title bar; `contained(_:)` puts the editor's hosting controller a level under the window's content |
| `Editor/View/EditorSidePanel.swift`, `EditorSegmentedPicker.swift` | The glass side panel with Style and Agent, each coming in from its side of the switch (`.materialize(sideways:)`), and the switch between them, a rounded bar (8 pt): one thumb that springs to the chosen word, chosen on press, carried along by a drag, shrinking while held |
| `Editor/View/EditorSlider.swift`, `EditorSwitch.swift`, `InspectorToggleStyle.swift` | The slider (6 pt track in ink, a white pill that follows from where it was grabbed and grows while held; a press on the track springs it there; the track brightens under the pointer) and the switch (ink when on; the knob springs across and stretches while pressed); both stand in for the system control to accessibility |
| `Editor/View/EditorStage.swift`, `TransportBar.swift`, `EditorIconButtonStyle.swift` | The preview in the canvas's shape with a checkerboard behind transparent canvases; the glass transport |
| `Editor/View/TimelineRuler.swift`, `Playhead.swift`, `ZoomBlock.swift` | The ruler (the finest scale whose labels stay 72 pt apart), the playhead's knob, the zoom blocks |
| `Editor/View/Inspector*.swift`, `TilePicker.swift`, `CanvasInspectorSection.swift` | Sections that fold away under a dim title (the controls are uncovered as the section grows and the sections below slide with it, one `withMotion`), sliders with their values, switches, and tiles whose highlight slides; a notice on top when the telemetry is missing |
| `Editor/View/ExportSheet.swift`, `ExportProgressBar.swift` | Native pickers in a grid with a line on what the format is for; progress |

Key facts:
- Glass only on controls over the stage, never on the timeline (content) or over the live video:
  each glass shape costs a sampling pass on the GPU the compositor also uses.
- The side panel replaces the system `.inspector`: that one is a flat column on macOS 26, glass drawn on it doesn't show,
  and toggling it ended in a layout loop that crashed the app (`NSSplitViewItem setCollapsed`, 300 layout passes). What lies
  on the panel (the chat's message box, chips, the switch) is a fill, never glass on glass.
- As a window's own content, `NSHostingView` resized the editor window to its smallest size once the recording had loaded
  (`updateAnimatedWindowSize`, whatever its `sizingOptions`); hosted a level down it doesn't, so the window opens at
  1280×800 and holds its own minimum (`EditorView.minimumSize`, 900×560).
- The filmstrip and lanes have no least width (`minWidth: 0`): their tiles are sized from the measured width, which kept a
  narrowing window's content wide.
- A binding unwrapped with `Binding(_:)` traps if its view outlives the value: the zoom focus pad fades out after Follow
  Cursor has removed the fixed focus, which crashed the app. It reads the view model with a fallback instead.
- Text is ink by default, so it doesn't dim when disabled: `InspectorSection` fades disabled content.
- Avoid what reads as generated: no gradients or glows in the chrome, no second accent, no cards
  and badges where a native control works, no all-caps titles, hover as a fill step (no lifts or
  scaling; only a press scales).
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
each one's own settings. The agent then calls four MCP tools: `inspect_page` (selectors and boxes of a
page), `record_page` (hover, click, type and scroll steps rendered like spec 0005, opened in the editor),
`render_status` and `export_recording` (the take as a finished MP4, MOV or GIF, spec 0009). Started with `--mcp`, the app only pipes stdio to the running app's Unix socket, and
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
an agent, a model and **Record**. Reco runs the agent's command line headlessly with its own four MCP
tools allowed (Claude Code also web search and fetch, to research the product); the agent records through
the bridge (S3) and the editor opens. `reco://record-agent?url=<page>&prompt=<text>` fills the bar and
starts the run (for scripting and tests). While it
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
- Only Reco's tools run, and for Claude the read-only web ones: `--tools WebSearch,WebFetch --allowedTools mcp__reco__* WebSearch WebFetch`; Codex `approve` mode and a
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

A web take's editor has **Style | Agent** at the top of the side panel. Agent is a chat: the conversation that
made the take, the run's state ("Looking at apple.com…", "Recording… 42%", Cancel) and a message box (↩
records, ⌥↩ new line) with the agent and model. Sending has the agent record the take again with the change;
the window swaps to the new take in the same look, the conversation carried over. Takes are checked as they
render and the problems go back to the agent as `warnings`.

| File | Role |
|---|---|
| `AgentRecording/Model/AgentChatMessage.swift`, `AgentRecordedTake.swift` | A message (user, agent, failure); a run's take with its conversation and the take it replaces |
| `AgentRecording/Model/AgentRecordingRequest.swift` | `take` (`RecordPageRequest(script:)`) and `conversation` in the prompt; replies of a sentence or two |
| `AgentRecording/ViewModel/AgentChatViewModel.swift` | Per editor window: reads `<name>.web.json`, sends through the one runner, failure folding, saving |
| `AgentRecording/View/AgentChatView.swift`, `AgentChatMessageRow.swift`, `AgentChatComposer.swift` | The chat: the conversation scrolls under the switch and the message box (`editorBar`: `safeAreaBar` on macOS 26, whose scroll edge effect blurs it away there; not yet seen scrolled), a filled rounded rectangle with the message, the agent and model menus and Record, which is Stop while a run goes |
| `AgentRecording/View/AgentChatEmptyState.swift`, `AgentChatStatus.swift`, `AgentChatFailure.swift` | Before the first message: three requests that go into the box. A run's step under a breathing sparkle with a band of light crossing it every 1.6 s (still with Reduce Motion). A failure with Retry |
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

### Stand-out roadmap, first batch (`feat/stand-out-roadmap`, spec 0009)

What recorders are checked for, and what an agent needs to go from a page to a finished file.

- **Cursor** (inspector's Cursor section): **Loop to Start** (glides back to its first position over the last
  second, so a GIF loops), **Stop Before End** (0–3 s; hides the reach for Stop), **Tilt When Moving**, **Motion Blur**.
- **Motion blur** (Zoom section, default 50%): frames in which the camera moves are averaged from samples
  across a shutter of up to 1/24 s; the cursor likewise along its own move.
- **GIF export** and **Copy Frame** (⇧⌘C, transport bar): a GIF is 540 px at 25 fps unless chosen (720/540/360,
  50/25 fps), loops, and repeated frames only show longer.
- **Cancel / Restart Recording**: menu bar rows while recording, shortcuts of the same names (no defaults),
  `reco://cancel` and `reco://restart` (no countdown). Nothing is left in the output folder.
- **`export_recording`** (MCP): a recording's path and a format in, the exported file's path out; with the saved
  edit, or as the recording would open in the editor. Called again with the same arguments, it follows the export.
- **Type steps** in web takes: a click clip with `text` types it into its field key by key; `"action":"type"` in
  `record_page`, a Type field in the Web Recording inspector.
- **Shown elements** (`show` on a `record_page` cursor step, `PointerClip.show`): the video zooms on that element
  while the step runs (framed to fill 80% of the view, 1.1–3×; a whole section makes no zoom), ending as the page
  scrolls or is replaced under it (none at all when that happens within 0.5 s of its start, as a click that opens a page
  does: the view would zoom in and straight back out) and panning to a zoom that follows within 1 s. Once any step shows, only shown
  steps zoom: the take is rendered with its `.edit.json` already written. One not mostly in view where its step
  starts is a warning. No field in the Web Recording window yet.
- **Walkthrough playbook** (`AgentRecordingRequest.playbook`, in every new-take prompt; a short form in the MCP
  server's `instructions`): research (inspect_page on the page and the pages its navigation links to, each with its
  meta description; web search or fetch if the agent has them), a shot list of four to six beats, then record with
  a show on every step at scale 2 (sharp when zoomed; the first takes at scale 1 came out blurred), 45–60 s. A
  re-record with warnings is tried once, then the agent must stop and report.
- **`render_cost`** in `inspect_page`: seconds of rendering per second of video at scale 1 and 2, from one snapshot of
  the page at each (`WebPageRenderer.renderCost`). The playbook drops to scale 1 only above 8 at 2×. Measured on this
  M5: supabase.com 1.6 / 2.6 (26 / 43 ms a frame), linear.app ~4 / ~18.

| File | Role |
|---|---|
| `Editor/Render/CursorPath.swift` | `shown` (first to last source time in the output), hold and loop applied at lookup, `tilt(at:)` |
| `Editor/Render/FrameRenderer.swift` | `blurOffsets(distance:most:)`, `average`, the camera's and cursor's samples |
| `Editor/Render/RenderTarget.swift` | `blurSamples`: 8 for the preview, 16 for exports |
| `Editor/Model/GIFFrame.swift`, `Editor/Service/GIFWriter.swift` | One frame taken out of ImageIO's single-image GIF, and the animation's bytes around it; the reader loop |
| `Editor/Service/ExportService.swift` | `export(recordingAt:settings:)` (headless), `export(_:of:resources:settings:)` (shared with the editor), `frame(of:at:)` |
| `Editor/Model/ExportSettings.swift` | `conformed(shorterSide:frameRate:)`: the one place that knows which sizes and rates a format offers |
| `AgentBridge/Model/ExportRecordingRequest.swift`, `ExportStatus.swift` | The tool's arguments and result |
| `WebRecording/Model/PointerClip.swift` | `text`, `keystrokes` (0.3 s after the click, 0.08 s apart, or closer to fit the clip) |
| `WebRecording/Service/WebTypeScript.swift`, `Model/USKeyCodes.swift` | `keydown`, `execCommand("insertText")`, `keyup` on the field; Enter submits its form. Key codes of a US keyboard for the telemetry |
| `WebRecording/Model/WebTakeZooms.swift` | Pure: the zooms shown elements ask for, from their boxes where their clips start; `WebPageRenderer.render` returns them and `renderTake` saves the project |
| `AgentRecording/Model/AgentRecordingRequest.swift` | `playbook`, `changePlaybook`: the method the prompt gives an agent |
| `ViewModel/RecorderViewModel.swift` | `// MARK: - Cancelling` extension |

Key facts:
- ImageIO keeps every frame of a GIF until it's finalized: 750 frames of 960×540 peaked at 3.1 GB (M5, macOS 26.5).
  Each frame is encoded as its own GIF and spliced, 8 ms a frame, memory at one frame. A 7 s 2880×1800 take
  exported as an 864×540 GIF in 1.3 s (5 MB, 169 frames) and as HEVC in 4.1 s.
- Each GIF frame has its own 256 colors and no dithering, so gradients band (spec 0004, open question 3).
- Motion blur, M5, Debug, 4K with a ring and a chip, load average 3, mid-zoom: 8 samples 2.8 ms p50 (1.3
  unblurred), 7.9 ms on the default canvas (2.8 unblurred); 16 samples 5.5 and 12.5 ms. A still view is drawn
  once, so its pixels are unchanged. Not measured on an M1, where a 4K preview will drop frames during camera moves.
- `CIColorMatrix` works on unpremultiplied color: scaling RGB and alpha both darkens by the share squared.
  Averaging scales alpha only (`fading(to:)`), then `CIAdditionCompositing`.
- A web take's typing is in its telemetry as keys (`keys`), so zooms hold on a field while it's typed into;
  characters a US keyboard has no key for are typed but not recorded.
- A web take records the pages its clicks open as `navigations` (a link to an anchor isn't one: only the fragment
  changes); auto-zoom ends a zoom at one as at a scroll, so a zoom on a nav link doesn't hang over the page it opened.
  A page a click opens shows from its top: the script's scroll offset belonged to the page before, so the renderer
  zeroes the last scroll clip's offset (before that, linear.app/plan opened 3,774 px down and scrolled up to its hero).
- `RecoTests/LocalPages.swift` serves a few pages on `127.0.0.1` for renderer tests that need a real navigation:
  `data:` pages can't link to each other. The editor applies a replaced take's look to the new
  take's stored project too (`EditorViewModel.load`), so shown zooms survive a chat re-record.
- `unmatched_selectors` names only selectors missing before any click: after a click the steps may be on the page it
  opened, and the take checks them where their clips start. Reported before, a supabase.com run spent its one retry on
  three selectors that were fine and reported the video as broken when it wasn't.
- Without a method the agent hovered headings and parked the cursor on the navigation, and auto-zoom followed it;
  three linear.app takes made that way had no flow. `show` moves the choice of what the viewer sees from the
  cursor's rests to the plan.
- `AVComposition` isn't Sendable; the GIF writer gets it through `nonisolated(unsafe)` since it's never changed
  once built.
- Tilt is `-0.2 rad × tanh(speed / 1500 pt/s)` about the hot spot; the loop's glide is at most half the output.

### S6 — Motion editor, phase 1: document, core, compositor (`remotion`, spec 0011)

A `<name>.motion` bundle (`document.json`, `assets/`) holds scenes of layers (text, image, shape, group)
on planes in 3D, keyframed, seen by one camera. `open -a Reco <name>.motion` opens a window with the
preview, play and step, and Export (HEVC, ProRes 4444, GIF) as `<name>-edited` next to the bundle.

| File | Role |
|---|---|
| `Motion/Model/MotionDocument.swift` and the types it holds | v1 format, defaults for every optional field, `validate()` (`MotionDocumentError`) |
| `Motion/Model/MotionEasing.swift`, `PropertyTrack.swift`, `Keyframe.swift` | Linear, hold, CSS cubic Bézier (`Model/CubicBezier.swift`, shared with web takes' `Easing`), critically damped spring; scale in log space |
| `Motion/Model/Transform3D.swift`, `Motion/Render/CameraProjection.swift` | Layer matrix (CSS rotation order and directions), the camera's projection |
| `Motion/Render/TextImage.swift` | Core Text image of a text layer, with word and line boxes |
| `Motion/Render/MotionPlan.swift` | Built off the main actor: flattened layers, tracks, images and shadows drawn once at the largest scale shown; `placements(of:at:)` |
| `Motion/Render/MotionFrameRenderer.swift`, `MotionCompositor.swift`, `MotionInstruction.swift` | The only place motion pixels are decided: `CIPerspectiveTransform` per layer, blur, opacity, shadow |
| `Motion/Render/MotionCompositionBuilder.swift` | The placeholder movie stretched to the video's length drives the compositor |
| `Motion/Service/MotionStore.swift`, `MotionExporter.swift` | Bundle I/O; export through `ExportService` |
| `Motion/ViewModel/MotionEditorViewModel.swift`, `Motion/View/*` | The window; `PlaybackControls`, `PlaybackTime` are shared with the editor's transport |

Key facts:
- A composition whose video track holds only `insertEmptyTimeRange` has a duration of 0 and no track
  (`AVAssetReaderVideoCompositionOutput` asserts): a 1-frame 16×16 movie scaled with `scaleTimeRange`
  drives preview, export and GIF (spike A).
- Shadows are blurred once per plan and projected with their layer: per frame, a 40 px shadow cost most
  of a 1080p frame (3.6 / 8.6 ms p50 / p95 against 1.7 / 2.5, M5, Debug).
- Golden frames: `RecoTests/Fixtures/motion-demo-*.png`, drawn from `motion-demo.json` at 480 px. A
  missing golden fails its test and writes the frame to the temporary folder to review and copy in.

### S6 — Motion editor, phase 2: real UI layers (`remotion`, spec 0011)

`document.assets` lists UI on web pages (address, selector, viewport); a `ui` layer shows one. A still
is lifted alone with real alpha at the scale the plan shows it; an asset with `record_page` steps is a
live take of the element's box, played from its scene's start with its cursor. Both are captured into
the bundle when a plan first needs them.

| File | Role |
|---|---|
| `Motion/Model/MotionAsset.swift`, `UIContent.swift` | The asset (`takePlan()` times its steps as `record_page` does) and the `ui` layer (`LayerContent.lifted`, coded `ui`) |
| `Motion/Service/UICapture.swift`, `UILiftScript.swift` | `plan(for:bundle:…)` builds, captures what the plan asks for (`liftsNeeded`, `bakesNeeded`), builds again; `lift` (one page load per address) and `bake` |
| `Motion/Service/UILiftCache.swift` | `assets/lifts/<key>@<n>x.png`, `assets/live/<key>.mov` with telemetry, `-matte.png` and `TakeInfo` (crop, radius, scale; 0 while only measured); the key hashes address, selector, viewport, hide and steps |
| `Motion/Render/MotionPlan+Live.swift` | `Live` (movie, cursor in the take's space, crop origin), `LayerKey`, `liveLayers` |
| `Motion/Render/MotionCompositionBuilder.swift`, `MotionCompositor.swift`, `MotionFrameRenderer.swift` | A track per live layer; its frame cropped, masked by the element's radius, with the cursor |
| `WebRecording/Service/WebPageRenderer.swift` | `withLoadedPage` (shared with `inspect`), `render(to:crop:…)` |
| `WebRecording/Service/WebClockScript.swift`, `WebHideScript.swift`, `WebInspectScript.swift` | Media on the take's clock; `WebScript.hide`; `PageInspection.overlays` and `brand` |
| `AgentRecording/ViewModel/AgentRecordingViewModel.swift` | `signIn()` → `EditorWindowManager.showWebRecording(at:)` |

Key facts:
- Lifts: whole scales 1–8× image pixels per CSS pixel; sharper ones are kept. Scroll as little as it
  takes, wait for the element's finite animations (≤ 5 s), hide what's beside the path from the root
  (never an ancestor: WebKit then dropped supabase.com's card background), `backdrop-filter` off.
- Live takes are measured first (`bakesNeeded` 0), then rendered at the scale shown (≤ 8×, movie ≤ 8,192 px), and
  cut to their matte (the element lifted without a fill): a radius left a square wrapper's grey around a pill.
- A track holds its asset weakly: inserting a track whose `AVURLAsset` is gone fails with -12780.
- Costs (M5, Debug): a still lift 2.7–8.5 s with the page load, linear.app at 8× 30 s; a 6 s live take
  of a 694×48 element 10.6 s; a 1080p frame with a live layer 1.1 / 3.1 ms p50 / p95.
- Two 8× WebKit snapshots at once made the GPU process quit; one at a time they don't.
- Web takes (spec 0010 step 1): media plays on the take's clock (`WebClockScript`: really paused,
  seeked each frame while in view, `seeked` waited up to 5 s once); `hide` selectors are a style at
  document start (`WebHideScript`); `inspect_page` adds `overlays` and `brand` (colors via a canvas, so
  `oklch()` reads as hex). **Sign In…** in the agent bar opens the Web Recording window on its address.
  cardboard.ai's hero videos pause themselves 2 s after landing on a desktop; hovered, one matched
  its source frame for frame.

### S6 — Motion editor, phase 3: grammar v1 (`remotion`, spec 0011)

Documents name shots and moves instead of keyframes: `{"shot": "uiHero", "ui": "app"}` in a scene,
`{"move": "blurWipe"}` on a layer, `"seam": "zoomThrough"` on a scene. The plan lays shots out and
expands moves when it's built; keyframes set by hand override a property's moves. The window gains a
scenes lane and an inspector (Scene, Layer, Rules) whose every change is an undo step.

| File | Role |
|---|---|
| `Motion/Model/MotionMove.swift`, `MotionSeam.swift`, `MotionShot.swift`, `ShotItem.swift`, `StyleTokens.swift` | The grammar's names in the document (`problem(on:)`, `problem(assets:)` validate them); `MotionCanvas.pacing` |
| `Motion/Grammar/MotionEasing+Grammar.swift` | `enter`, `enterFast`, `cascade`, `exit`, `move` (measured), `longSettle` (`MotionEasing.settle`) |
| `Motion/Grammar/MoveExpansion.swift`, `TextReveal.swift`, `ZoomPath.swift` | A move's tracks (factors or amounts on the base), reveals, van Wijk pans; the only place timings and distances live |
| `Motion/Grammar/ShotLayout.swift`, `DocumentExpansion.swift`, `SeamExpansion.swift` | Shots to layers by `LayoutRules`; rolls and cascades to other layers' moves; seams to camera tracks and transitions |
| `Motion/Grammar/LayoutRules.swift`, `ReadingTime.swift`, `MotionLint.swift` | The rules, one place each, used by shots and the lint |
| `Motion/Render/MotionPlan+Grammar.swift`, `MotionPlan+Images.swift` | Camera moves and seams in the plan; images, shadows and focus drawn once |
| `Motion/Render/MotionFrameRenderer.swift` | Reveals, focus, depth of field, frame blur, push and fade between scenes |
| `Motion/ViewModel/MotionEditorViewModel+Editing.swift`, `Motion/View/MotionScenesLane.swift`, `MotionInspector.swift` and its sections | Edits with undo, the lane, the inspector |

Key facts:
- A property's value is its keyframes if it has any, else its base times its factor moves (`scale`,
  `opacity`, `shadow`) or plus its other moves (`MotionPlan.value`). A camera's `scale` is the lens.
- Depth of field: camera `focus` (sharp z) and `aperture` (blur per 100 px of depth); a tilted plane
  gets `CIMaskedVariableBlur` from two gradients projected with it.
- `CIPerspectiveTransform` maps an image's extent to the quad: a revealed text image keeps its
  whole extent (clear where hidden), or it stretches.
- A brand varies the video: the face picks the headline's reveal (sans wipe, serif line mask, mono
  typing); drift-and-cut drifts every shot but the end card, beats eases the camera.
- Golden frames `RecoTests/Fixtures/motion-grammar-*.png` from `motion-grammar.json` (a card lifted
  into the bundle, so nothing loads from the web).
- Costs (M5, Debug): plans 0.09–0.26 s; 1080p frames 0.6–6.6 ms p95, cardboard.ai's zooming shots in
  beats 8.3–8.7; a focus is drawn once per plan (9.4 → 4.6 ms p95).

### S6 — Motion editor, phase 4: agent (`remotion`, spec 0011)

**Launch Video | Walkthrough** in the agent bar (`reco://record-agent?mode=launch`): from an address
alone the agent researches, writes a motion video with `edit_motion`, lifts its UI (`capture_ui`),
looks at a contact sheet (`preview_motion`) and exports 4K (`export_recording` takes bundles). The
motion window's side panel has **Style | Agent**: a chat whose messages carry the selected scene and
layer, kept in the bundle's `chat.json`.

| File | Role |
|---|---|
| `Motion/Model/MotionEdit.swift`, `AgentBridge/Model/EditMotionRequest.swift` | The nine operations and their application; a batch all or none, then validated; new bundles' names |
| `AgentBridge/Model/AgentToolCatalog+Motion.swift` | `edit_motion`'s description: all an agent knows of the grammar |
| `Motion/Grammar/MotionSummary.swift` | What `edit_motion` replies: scenes, layers (a shot's too), moves with their times, findings |
| `Motion/Service/ContactSheet.swift`, `DesignCheck.swift` | `preview_motion`'s moments and sheet; flat frames and too much accent |
| `AgentBridge/Service/AgentTools+Motion.swift` | The motion tools; edits go through the open window (one undo step) or the store |
| `Motion/Model/MotionScene.swift` | `shotMoves`: moves set on a shot's layers or camera, kept apart from the shot |
| `AgentRecording/Model/AgentRecordingRequest.swift` | `mode`, `motion` (bundle, selection), the launch and motion-change playbooks, 20 min limit |
| `Motion/View/MotionSidePanel.swift` | Style and Agent; `AgentChatViewModel` works on bundles too |
| `WebRecording/Service/WebInspectScript.swift` | `liftable` |

Key facts:
- An agent's run from the address took 2.7–3.4 min; the linear.app run used $1.07 at API prices (13 turns, Opus 5.5); runs use the user's own agent and login, so on a subscription that is plan usage, not a charge.
  Runs keep no session and print text, so the app doesn't know a run's cost.
- Chat edits took 30–75 s and changed only their targets ("slower" one scene's duration, "word by
  word" one layer's moves, "8 frames earlier" one move's start by 0.133 s).
- A lift hides descendants that have a `backdrop-filter` and no text or picture (`data-reco-lift-veil`):
  WebKit drew linear.app's progressive blur as streaks. Lifts are keyed with `liftVersion` 2.
- Drift is capped at 4% of the width per scene, its zoom slowed with it: a 10 s scene had drifted
  captions off frame. `featureSequence` doesn't drift; its parts leave 0.1 s apart.
- One capture at a time (`UICapture.isCapturing`): two at once made the WebKit GPU process quit.
- `AgentProcess` reads pipes with `read(2)`; `availableData` threw on a non-blocking pipe and crashed the app.

### S7 — Motion quality, Q2.1: fields (`remotion`, spec 0012)

A scene can be drawn over a lit, textured field instead of the plain background: `canvas.field` for the
video, `scene.field` for one scene (`ember`, `matrix`, `halo`, `sunlit`, `plain`), coloured from
`style.accent` by rule. The four looks were picked by eye from a gallery of Paper Shaders
(Apache-2.0; its NOTICE is in Settings → About, its licence in the bundle).

| File | Role |
|---|---|
| `Motion/Model/MotionField.swift`, `OKLCH.swift` | The names; OKLCH to and from sRGB, gamut-mapped by chroma |
| `Motion/Render/FieldPalette.swift` | A field's colours from the brand: the picked lightness steps and hue offsets, the brand's hue, its chroma up to the picked one's; cool greys without a hue |
| `Motion/Render/FieldKernels.metal.txt`, `FieldNoise.png` | The GLSL ported to Core Image stitchable kernels, and the shaders' noise texture |
| `Motion/Render/FieldRenderer.swift` | Compiles each kernel alone at run time and draws a field at a time and size |
| `Motion/Render/MotionFrameRenderer.swift` | Each scene's layers over its own field, on the video's clock |

Key facts:
- A field is drawn as the 1280×720 gallery tile it was picked on (pixel ratio 2), scaled to the frame.
  Against the WebGL originals at u_time 4: 50.8–72.0 dB PSNR. The grain gradient's `fwidth` is taken
  to the other pixel of the 2×2 quad as a GPU does; forward differences gave 27–33 dB.
- Compiled together, Core Image drew only the first sampling kernel it drew; the other came out
  transparent (macOS 26.5). Each kernel is compiled alone (`#define <name>_ONLY`).
- Cost (M5, Debug, 1080p p50): ember 2.7–4.1 ms, halo 3.0, sunlit 2.6, matrix 0.35. The preview
  (`MotionPlan.isPreview`) draws the soft looks at most at 720p and scales them up (1.4–1.6 ms); exports
  draw them whole (4K: ~10 ms).
- A push seam moves whole frames, each with its field.

### S7 — Motion quality, direction L1: the Raycast look (`remotion`, spec 0012)

After the user rejected the ported fields as pasted behind the old video, they picked three directions
from verified launch films (`docs/references/launch-films.md`): New Raycast, Nothing OS 5.0, and 3D UI
layers. The films are measured in `docs/references/style-guide.md` (copies in `~/Movies/Reco/references/`,
outside the repo). L1 rebuilds Raycast's grammar on real UI: a macro live shot over satin, a whip.

| File | Role |
|---|---|
| `Motion/Render/MotionFrameRenderer.swift` | Motion blur from a 180° shutter (`FrameRenderer.blurOffsets`, `average`) |
| `Motion/Service/MatteFill.swift` | A live take's matte as coverage: alpha scaled to the element's median paint, holes its outline encloses filled |
| `Editor/Render/CursorPath.swift` | The cursor hides from a typed key (no ⌘ or ⌃) until it moves or clicks, as macOS does |
| `WebRecording/Model/WebScript.swift`, `Service/WebPageRenderer.swift` | A clip rests from its first key; the renderer measures typed-into fields itself |

Key facts:
- Supabase's partner search is a translucent field (alpha 0.13) in a faint border: its painted matte was
  its placeholder's letters, so typed text showed only through them. Coverage fixes it; a filter that
  empties card slots still shows them as dark boxes, since the matte is the page as loaded.
- Typing grew the field a clear button and moved its centre 12 pt; the pointer followed it, which showed
  the I-beam during typing. A take's keys can't be typed into a field whose box wasn't measured.
- Motion blur costs nothing on still frames; a whip at 1080p averages up to 16 frames in an export.

### S7 — The approved film in the engine (`remotion`, spec 0012)

The user approved a 24 s Supabase docs film in New Raycast's look, rendered by a Python look-dev pass
(spec 0012, L0). It is ported into the engine phase by phase, each checked against the film's frames. Phase 1
is its ground: `satin` is now the film's cloth, lit afresh for each shot, and the film's grain. Phase 2 is
lifted UI on glass (`"glass": true` on a still asset) and small elements drawn sharp in macro. Phase 3 is
typing: a still asset's `typing` (a field and text) shown typed into from a `ui` layer's `typingStart`. Phase 4
captures UI that only exists after a click (`before` steps) and a typing asset's states, from the live page. Phase 5
moves a typed field's selection (`typing.select`, a layer's `presses`) with the camera following, and samples a whip's
motion blur as the film did. Phase 6 is the `closing` shot, New Raycast's ending. With them the whole film is one
document the app captures from supabase.com and exports in 90 s (`~/Movies/Reco/quality/port/`).

| File | Role |
|---|---|
| `Motion/Render/SatinSetup.swift` | The film's four shots' lighting: folds, pools, key, exposure, defocus, drift, and the wide shot's slab of matte glass |
| `Motion/Render/FieldKernels.metal.txt` | `satinGround` (folds lit in linear light on a coarse grid), `satinFinish` (exposed, encoded, the chamfered slab), `filmGrainNoise`, `filmGrain` |
| `Motion/Render/FieldRenderer.swift` | `Shot` (the scene's place among those over its field, its start, the camera's move since); satin in stages; `grained` |
| `Motion/Render/MotionPlan.swift`, `MotionFrameRenderer.swift` | `Scene.fieldShot`; `camera(of:at:)`; a field follows the camera from where the scene opened; grain over satin frames |
| `Motion/Render/GlassRenderer.swift`, `FieldKernels.metal.txt` (`glassPanel`) | A glass layer's panel in frame space through the inverse of its projection: the field seen through it, pool, sheen, rim, shadow; the content clipped to it |
| `Motion/Render/SatinSetup.swift` (`Glass`) | How each shot's light falls on glass (L0's stills, after Raycast's pill) |
| `Motion/Model/MotionAsset.swift`, `Motion/Service/UILiftScript.swift`, `UICapture.swift`, `UILiftCache.swift` | `glass`; `bare` (content alone, no fill: a page's text on satin); `region` (part of a long element); lifted bare (`isolate`'s `bare`); every still's corner radius kept beside its lift (`Shape`) |
| `Motion/Model/HumanTyping.swift` | Pure: key times at a person's pace, when results settle (a word's end), the caret's blink, the field's growth |
| `Motion/Render/TypedField.swift`, `MotionPlan+Dressing.swift` | A layer's typing: its lifts at their own scale, keys, settled states; glass and typing put on a still's layer |
| `Motion/Render/MotionFrameRenderer.swift` (`typed`) | The field at a moment: the last settled results, the row as typed, the caret; its glass as tall as the field is then |
| `UILiftCache.Typing` | Where a typing asset's lifts are (`-typed-<n>`, `-settled-<n>`) and what they show: the row, where the text ends at each length, its line and size, the settled lengths and heights |
| `Motion/Service/UICapture+Typing.swift`, `UILiftScript` (`click`, `settle`, `field`) | `before` steps run once a still's page loads; a typing asset typed a character at a time at the video's pace, its row lifted each time, the whole element once a word's results settle |

Key facts:
- The k-th scene over satin takes setup k mod 4 on its own clock, so each shot opens as the film's did
  wherever it starts. Paper's looks keep the video's clock.
- Fields follow the camera's move since the scene began (the cloth 15 %, the slab 35 %), not its absolute
  look: before, a zoomed camera magnified a field from the first frame.
- Against the film's ground at 1080p: 50–64 dB, mean difference 0.02–0.17 levels; the largest differences
  are the film's own (one-sided gradients and its cubic resize at the frame's edges, and pixel centres on
  whole numbers, half a pixel off Core Image's, along the slab's groove).
- The cloth is lit on a 540-row grid (the film's 270), blurred and scaled up: 2.2–2.5 ms for a 1080p frame
  with readback (M5, Debug).
- Grain is the film's exactly: Gaussian noise through OpenCV's 0.6 px kernel, 2.32 levels in the mid-tones
  (2.339 measured after rounding, as the film's), neighbours correlated 0.44, none in black; on a grid of at
  most 1080 rows, scaled up past it. Core Image's own 0.6 px blur correlated 0.54 and needed a guessed scale.
- Glass against the film's four shots (the film's own lifts in a bundle, its cameras keyed): 47.5–54 dB with
  pixel centres matched (the film's glass, like its slab, was half a pixel off); 41 dB on the page's code,
  where the film shrank its 8× lift bilinearly. Supabase's code block captured live with `glass` is pixel for
  pixel the film's lift. The rim is 0.87 CSS px, so it scales with the element.
- Layer images may be sharper than 4× while they fit 8,192 px (a search bar at 14× on 1080p); stills lift past
  8× while they fit 8,192 px. Big layers keep the old caps, so memory is never worse.
- `CIPerspectiveTransform` maps an image's extent out to whole pixels: a lift stretched to 5800.3 px drew 0.6 px
  off. Lifts and images are drawn at whole pixels.
- Typing follows the film: 0.118 s between keys ±, 0.11 s more at a space and 0.04 s before one ("row level
  security" in 2.4 s), jitter from FNV-1a of the text so it never changes; results 0.22 s after a word's last key;
  the caret solid 0.5 s after a key, then 0.53 s on and off with 0.08 s fades, 0.072 em wide and 1.19 em tall, 250 of
  255; the field grows to its results on a 16 rad/s spring (95 % in 0.3 s).
- A typed field is drawn at its lifts' own whole scale, so rows and results line up on whole pixels and the projection
  is the one resampling; at the shown scale with rounding the rows sat 0.16 px off (44 dB). Against the film's shots 1
  and 2 (16 frames, its lifts, the engine's key times): 53.3–55.1 dB, no shift.
- A typing asset whose states aren't lifted (or not at the scale shown) asks the plan for a lift: all of it is lifted
  again. Supabase's search ("row level security", 22 lifts at 8×) captured in 27.8 s.
- The row is the field's first ancestor across nine tenths of the element's width: right whether or not results have
  come yet. Where the text ends is measured after each key (canvas `measureText` with the field's font).
- Captured live, Supabase's dialog matched the film's lab lifts pixel for pixel where the page was the same: the empty
  field, rows 3, 4, 9, 10 and 18, the results at "row" and at the end. The rest differed by the input's own endless
  shine (where in its cycle the snapshot fell) and, at "row level", which result cmdk had selected; the typing frames
  drawn from it matched the film at 53–54 dB, 33 dB while that selection showed.
- A press moves the selection one result (never above the first); the camera follows each move 0.06 s late over 0.3 s
  eased out, one additive track per press, so presses closer than the move (the film's last two, 0.14 s apart) blend.
  Against the film's shot 3 with the same follow and blur: 50.5–50.9 dB on all nine frames, mid-follow too.
- Motion exports take a blur sample every 3 px a point travels, up to 96 (the film's; 16 left its whip in ghosts 20 px
  apart); the preview keeps the editor's 8. The whip against the film's: 49.8–57.7 dB, each 96-sample frame drawn in
  0.2–0.4 s (M5, Debug).
- The whole film as one document (five scenes, six assets captured live, the film's cameras): exported frames against the
  approved film's, read through AVFoundation as QuickTime shows them, match where the page is the same (the bar, the
  typing, the page and its code, 32–45 dB); what differs is the site's state (cmdk's selection, the input's shine), the
  key times (the engine's own jitter), the closing's type, and the results shot's camera by a few pixels. ffmpeg reads
  AVFoundation's BT.709 HEVC 1.7–2.4 levels darker than AVFoundation does (x265's not), so compare through AVFoundation.
- `closing` lays out as the film: mono caps 2.5 % of the frame tall, the name's left edge at 0.32 of the width, each word's
  right edge at 0.68, cut every 0.42 s; the last held 0.74 s, sliding together over 1.4 s, the dimmed line 0.3 s later,
  the logo alone 1.55 s after. Against the film, every line's box within 1–3 px and the same word at every moment; the
  type is SF Mono, 8 % narrower than the docs' Source Code Pro the film lifted (a brand's own font is Q1).
- Three capture fixes on the way: isolation hides everything inside what it hides (a child's own `visibility: visible`
  beat the inherited hidden, and Supabase's docs heading showed through the dialog; `liftVersion` 3); bare stripping is
  inline `!important` (a stylesheet rule lost to the site's own and kept the dialog's border); a word's results wait at
  least 1.2 s and typing goes at the video's pace (faster, the results kept an older selection).

### S7 — Launch films by the agent: macro, whip, skill (`remotion`, spec 0012 L4 and Q4)

The approved film's grammar named for the agent, and the method shipped as a skill. A `macro` shot frames
`view`s of real UI (CSS px from the element's top-left) one after another: the camera holds, creeps closer and
whips to the next. A `whip` seam streaks the camera out of one scene and into the next. Agents no longer key
cameras: the approved Supabase film is four macro shots and its closing. Launch Video runs and the motion chat
give Claude Code the `reco-launch-film` skill in its run's folder; other agents read it in their prompt.

| File | Role |
|---|---|
| `Motion/Grammar/ShotLayout+Macro.swift` | Views to camera position and dolly, creeps, whips; the opening's 1 s of ground; when typing starts; a selection's presses |
| `Motion/Model/MotionShot.swift`, `ShotItem.swift` | `macro`, `view`, `stops` |
| `Motion/Grammar/MoveExpansion.swift`, `SeamExpansion.swift`, `Motion/Render/MotionPlan+Grammar.swift` | The `whip` move and seam; a move after a whip looks from its target; a seam's travel by each side's magnification |
| `Motion/Grammar/MotionLint.swift` | `material`: a macro over satin shows glass or bare UI |
| `Motion/Service/UICapture+Typing.swift`, `UILiftScript.swift` | Typing into a mockup that isn't a field (`clearMockup`, `typeMockup`, `restoreMockup`); its caret from the laid-out text |
| `AgentRecording/Skills/reco-launch-film.md`, `AgentRecording/Model/AgentSkill.swift` | The skill (bundled), its path in the run, its method without front matter |
| `AgentRecording/Model/AgentInvocation.swift`, `AgentRecordingRequest.swift` | `makesMotion`: the skill file, `Skill` in `--tools` and `--allowedTools`; prompts load or inline it |
| `AgentBridge/Model/InspectPageRequest.swift` | `selectors`: boxes of the parts of a panel |

Key facts:
- **Framing.** A view fills 92 % of the frame where it binds. The element is never wider than 8,192 px at
  1080p (a lift's limit), so 4K is within 2× of its lift.
- **Holds and moves.** Holds share the scene evenly. The camera creeps 3 % closer over each hold; the opening
  instead pulls back 4.5 % after the cut-in. A whip is 0.35 s on (0.7, 0, 0.15, 1).
- **Typing and selections.**
  - Typing starts 0.65 s after the control shows.
  - A field an earlier macro typed shows its text from the start (`typedBefore`).
  - `select: n` steps down at 0.55 s, 0.47 s apart, then back up 0.58 s later, 0.14 s apart (the film's).
- **Rebuilt from views alone,** the approved film's frames match it: the bar, typing, results, page and code.
  Only the page's whip lands 0.6 s later, since holds are even.
- **The whip seam** leaves over the last 0.15 s (half a frame's width) and arrives over 0.45 s (0.8 of one), on
  the exit and out-expo easings; the speeds meet at the cut, about ten widths a second.
- **Mockups.**
  - A mockup's computed font isn't what draws it: on linear.app the caret, measured with a canvas, fell a third
    behind the text. A mockup's caret is the laid-out text's last line box.
  - Its text is `pre-wrap`, so a space moves the caret.
  - Empty, its line has no height, so its inline box sat at the line's top, 13 px above linear.app's text: a
    zero-width space stands in while it's measured.
- **Running the skill.**
  - `--tools WebSearch,WebFetch` hides the Skill tool; with `Skill` added, a headless run in a folder with
    `.claude/skills/<name>/SKILL.md` loads it.
  - `--setting-sources project` would hide the user's own skills, but it also drops their settings (login
    helpers), so it isn't used.
- **The first linear.app run from its address** (Claude Code, default model) took 9.2 min:
  - It typed "@Linear create issues and assign to me" into the homepage's prompt mockup.
  - It whipped across the issue board, an issue and its diff, then closed on 9 words.
  - The film is 31.5 s at 4K, every frame sharp.
- **A later run** took 6.9 min and made a 32.3 s film. It opened on the empty prompt with its toolbar, typed with
  the caret on the text's end, then toured the board, an issue the agent took and its diff.

### S7 — Looks: light and dither, seams in their language (`remotion`, spec 0012)

Every launch film came out in the same black satin. A film now keeps to one of three looks, chosen by the agent
from the brand: **satin** (Raycast's), **light** (Paper's grain gradient in the accent's hue: `ember`, `sunlit`,
`bloom`, `orb`, `ripple`) or **dither** (Paper's dithering in the accent: `matrix`, `warp`, `swirl`, `tide`). The
macro's glass shows the ground through it, tinted. Each look has its own seam, drawn over the whole frame, UI and
all: `glow` (a front of grainy light out of the next scene's field's shape), `dither` (the frame turned to the
brand's dots from its edges in, its UI drawn in them, then into the next scene) and `ring` (a ring of smoke
opening from the middle, the next scene inside: into a closing).

| File | Role |
|---|---|
| `Motion/Model/MotionField.swift`, `MotionSeam.swift` | The new fields, `Family` (satin, light, dither, smoke, plain), the seams and their family |
| `Motion/Render/FieldKernels.metal.txt` | `grainShape` (wave, corners, ripple, blob, sphere), `ditherShape` (warp, wave, swirl, sphere), the camera's view as an argument, `glowSeam`, `ditherSeam`, `ringSeam`; `glassPanel` in colour |
| `Motion/Render/FieldRenderer.swift`, `FieldPalette.swift` | Each field's shape and settings (the picked look's for its shader's other shapes); `seam(_:between:progress:at:size:)` |
| `Motion/Grammar/SeamExpansion.swift`, `Motion/Render/MotionPlan+Grammar.swift` | The seams' lengths and easing (dither steps at 15 fps); a seam takes the next scene's field when it's of its family, else the family's first pick |
| `Motion/Grammar/MotionLint.swift` | `look`: one look a film, a seam only into its language, a cut keeps the ground; `busyField` only under type; `material` over any field |
| `Motion/Render/MotionFrameRenderer.swift` (`ground`), `MotionPlan.Scene.arrival` | A light or dither opening: the ground swells in from black, the control arrives in the look's seam |
| `AgentRecording/Skills/reco-launch-film.md`, `AgentBridge/Model/AgentToolCatalog+Motion.swift` | Which look for which brand, a field per scene, the seams |

Key facts:
- **Two images of one kernel moved differently in one frame** (motion blur's samples, a seam's two scenes) drew
  one of them as streaks of the other's edge pixels (macOS 26.5, Core Image): a transform on a stitchable kernel's
  output isn't kept per image. Fields take the camera's move as an argument; the preview's uniform scale is safe.
  Drawn together, two instances round 1 level differently from each alone.
- Glass samples the ground in colour now; over satin all three channels are equal, so its golden frames are unchanged.
- Over light and dither, page text goes on glass too (`material` lints `bare` there): Supabase's docs heading, bare
  over swirl, didn't read. The dithers that fill the frame (warp, swirl, tide) light their dots at 0.55 of the
  sphere's, the seam's dots at full strength.
- The seams start exactly on the scene before and end on the next (within a level), their light gone at both ends.
- **Glow** is a band of light ordered seven tenths by place (out of the middle for a blob, sphere or ripples, up from
  below for a wave, in from the corners) and three tenths by the field's shape. Ordered by the shape, it crossed the
  shape's flat stretches at once: ripples flooded bolt.new's frame cyan. Its front spans just the order's range
  (further out, it crossed nothing for the first third), eased out-cubic as the ring is (eased in and out, both showed
  nothing for a third of the seam, then crossed the frame in 0.2 s), the palette's palest stop at its heart and the
  brand's hue at its edges (in the hue alone it read as a neon ring).
- `bloom`, `orb` and `ripple` take sunlit's three hues (the lead, a violet 35° on, a pale grey), the ground the user
  singled out in bolt.new's film; with ember's one hue their blob and rings were flat.
- **The opening** of a light or dither film (`arrival`): the ground swells in from black over 0.6 s, and at 1 s the
  control arrives in the look's seam (light out of the ground's own shape, 0.9 s; dots from the edges, 0.8 s); typing
  starts 0.65 s after it. Satin's still cuts in, as Raycast's bar did.
- A **cut keeps the ground** (lint): bolt.new's cut in closer on its prompt jumped from a blob of light to two corners.
- Bare and glass lifts drop a **backdrop**: a descendant laid over the whole element (absolutely positioned, 90 % of
  its area) with nothing to read, as they drop its fill. bolt.new's design card was a lime picture under its heading,
  which glass turned to olive mud (`liftVersion` 5).
- **The caret's line.** In a rich-text editor, an empty field's probe goes at the start of its last block: appended to
  ProseMirror's field, after its paragraph, it opened a line of its own, and bolt.new's caret sat a line under the
  text. A textarea's line is its first, at its top, not its middle (bolt.new's other hero prompt is two lines tall).
  bolt.new serves either prompt.
- **A typed field is marked once** (`data-reco-field`) and keys go to the mark. Joined to the element's selector, an
  agent's field selector that named the element too ("X X .ProseMirror") found nothing, and bolt.new's prompt took no
  typing while it measured fine. A field whose text never moves fails its capture (`notTyped`), so the agent hears it.
- Look-dev from the Linear 9 film's lifts, re-grounded (1080p, M5, Debug): both 32 s films exported in 39 s together.
- **From the app, no instructions** (Claude Code): supabase.com chose dither (5 min, 26 s 4K); bolt.new light in its
  blue (8 min, 27 s 4K); lovable.dev light in pink, but its UI is light: a white prompt box unglazed, a card's 7× lift
  without its animated list, and 4K failed (WebKit's GPU process quit lifting the prompt at 11×), so 1080p. Glass for
  light UI is still to build. After the opening, glow, backdrop and caret fixes, bolt.new again (four runs, 5–11 min
  each): the last, `Bolt 5`, 29 s at 4K, typed on its line, a glow, a whip, the ring.

### S8 — Motion sound (`remotion`, spec 0013)

Every motion video gets a score and quiet effects made for its own picture: generated on device from the plan's
times, mixed as the hand-made Supabase film was (`~/Movies/Reco/quality/audio/score.py`, round 6, the closing
Raycast's), nothing recorded or licensed. The preview plays it; HEVC, H.264 and ProRes exports carry it; GIFs
don't. `sound` in the document turns the score or the effects off or moves their level; agents use `set_sound`
only when asked; the side panel's Style has a Sound section.

| File | Role |
|---|---|
| `Motion/Model/MotionSound.swift` | The document's `sound`: `score`, `effects`, `scoreLevel`, `effectsLevel` (−24…6 dB) |
| `Motion/Sound/SoundRules.swift` | Every number, one place each: chords, levels, hits, keys, whips, the closing, frame snapping |
| `Motion/Sound/SoundCueSheet+Plan.swift`, `+Score.swift`, `SoundCueList.swift` | Pure: plan → cue sheet (`MotionPlan.sound`, made in `build`); first UI, cuts, typing, whips from the camera's speed, the body's chords, `ClosingCues` |
| `Motion/Sound/SoundSignal.swift`, `SoundVoices.swift`, `+Score.swift` | vDSP: seeded noise, Butterworth sections, oscillators; the voices; wavetable pads |
| `Motion/Sound/SoundRoom.swift`, `SoundFinish.swift`, `Loudness.swift`, `ScoreRenderer.swift` | The room by DFT convolution, stopped at the cut to black; the finish (−16 LUFS, ≤ −1.5 dBTP); BS.1770-4; the render |
| `Motion/Service/SoundCache.swift` | `assets/sound/<sheet hash>.caf`, 24-bit Apple Lossless, `soundVersion`, three kept |
| `Motion/Render/MotionCompositionBuilder.swift` | `composition(for:sound:)`: the audio track, trimmed to the video |
| `Motion/View/MotionSoundSection.swift` | Score and Effects switches and levels |

Key facts:
- **Rules.** A chord a shot (D major, walked back so the shot before black is I), changing 0.04 s before each cut
  and at a whip's landing inside a scene; a glass and thump as the first UI shows; a quiet swish and thump on
  plain cuts; keys, a blip per settled word, arrows with a blip, Enter before a selection's cut; a whip's riser,
  whoosh at its speed peak, landing thump and glass; the closing as Raycast's: a hit on black, IV with a felt
  arpeggio under the words (no sound of a word's own), I, vi, V, the logo quietest. No effect from the cut to
  black on. Every cue on the frame that first shows its moment (⌈t·fps⌉/fps).
- **Whips** are found from the camera's speed across the frame (240 Hz, over 5 widths a second, bounded at 1 %
  of the peak), so keyed cameras count as moves do; the camera following a selection peaks near 3.
- **Against `score.py`.** The Supabase film's document gives its 105 cues and 9 chords; rendered: −16.0 LUFS (ffmpeg
  agrees), closing levels within 0.3 dB, bands within 1 point, centroid 425 Hz against 411. The whoosh peaks at the
  measured 11.903 s, not the hand-made 11.97; keys follow the engine's own typing.
- **Speed (M5, Debug).** The sheet comes with the plan (0.10 s); the Supabase film's 24 s are made in 0.34–0.41 s,
  everything per sample on vDSP. The preview waits for it once per timing edit; other edits read the cache.
- A field blips as its words settle only if it grows to 1.5× its empty height (results): bolt.new's chat prompt
  popped on every word.
- An AAC export's cue lands within 1 ms of where it was made (`AVAssetReader`, priming applied); ProRes is PCM.
  From the app, `Bolt 6`'s AAC was its cue sheet's sound sample for sample (0 lag at every cue checked), and the
  approved Supabase film exported at −16.0 LUFS like the hand-made one.
- `vDSP.DFT` is deprecated on macOS 26: `vDSP.DiscreteFourierTransform` (macOS 12+).

### S9 — Motion design films (`remotion`, spec 0014)

A second kind of launch film, after LordyVisuals' Spotify Jam concept (`~/Movies/Reco/references/spotify-jam-lordyvisuals.mp4`):
the UI rebuilt as shapes, type and lifted parts, one object morphing from state to state (list → pill → flood → chips → caret →
type → check), letters springing in, a pointer clicking, bursts and ripples, on a 125 BPM beat. Agents get it as a second skill,
`reco-motion-design`, whose references Claude Code reads one file at a time; launch prompts choose a skill, or both for a
longer film.

| File | Role |
|---|---|
| `Motion/Model/MotionMove.swift`, `ShapeContent.swift`, `LayerShadow.swift`, `MotionCanvas.swift` | The moves `morph`, `flood`, `pop`, `press`, `click`, `spin`, `burst`, `ripple`, `letters`, `kinetic`, `scroll` and their fields (`size`, `radius`, `color`, `stroke`, `to`); shapes' `stroke` and `kind` (triangle and seven glyphs); a shadow's `color` (a glow); `fieldStrength` |
| `Motion/Render/ShapeMorph.swift` | A rectangle's states from its morphs and floods, each from where the last left it, generated each frame |
| `Motion/Grammar/MoveExpansion.swift` | Pop and press tracks, letters and kinetic reveals, `placeTracks` (morph and scroll `to`), the measured numbers |
| `Motion/Grammar/BurstExpansion.swift`, `DocumentExpansion.swift` | Particles behind a layer, rings over it, seeded by its id; a cascade's rows rising as its group's scroll brings them in |
| `Motion/Render/MotionPointer.swift`, `ShapeGlyph.swift` | The system's arrow and pointing hand on a click's target (a group too); triangles and glyphs drawn once |
| `Motion/Render/MotionFrameRenderer.swift`, `+Reveal.swift`, `+Design.swift` | Morphing shapes and their glow per frame, pointers over a scene, letters in the room around their text, the kinetic caret and tint, particles drawn sharp, the toned-down field |
| `Motion/Sound/SoundCueList.swift` (`design`) | A blip a pop, a key a press or click, a riser and hit on a flood, glass on a burst, kinetic keys, a whoosh on a fast scroll |
| `Motion/Grammar/MotionLint.swift` | A control's label is read against its control and at a glance; actions don't delay reading; a toned-down field isn't busy |
| `AgentRecording/Skills/reco-motion-design*.md`, `Model/AgentSkill.swift` | The skill and its references (the film, moves, recipes, longer films, a whole example), installed as `.claude/skills/reco-motion-design/` |
| `AgentRecording/Model/AgentInvocation.swift`, `AgentRecordingRequest.swift` | `Read` allowed only in `./.claude/skills/**`; the prompt's skill choice |

Key facts:
- **The reference, measured** (30 fps): the pill grows 340 → 590 px in 0.43 s (`MotionEasing.morph`, fitted); the flood dips to
  0.6 in 0.17 s and fills past the corners in 0.4 s out-cubic; letters 0.036 s apart (11 in 0.4 s) and overshoot
  (`MotionEasing.overshoot`, CSS's out-back, the first easing that does); kinetic type 13 characters a second; the hand 8 % of the
  frame's height; the queue scrolls 1.83 heights in 1.5 s; one hard cut in 19 s, on a beat of its 125 BPM track (−14.3 LUFS).
- At 1080p it reads at the reference's scale: rows 1070 px wide and 215 apart, the pill 560×184 with 64 px type, kinetic type
  150 px. Ember at `fieldStrength` 0.45 sits behind the UI as the brand's light; at 1, and sunlit or bloom at any strength, it
  swamped it.
- `CIRoundedRectangleStrokeGenerator` draws its line inside the extent. A colour morph mixes premultiplied, so a fill drains to
  clear without passing through black. A ripple's rings go over their layer (they show across a flood), a burst's particles
  under it, in the shape's colour at the burst (a white disc turning green throws green).
- The system cursor images carry clear margins for their shadow: the pointer is sized by the hand's drawn rows.
- **Smoother (D7), measured again on the reference's transitions.**
  - A letter comes up from 0.7 of its line below at 0.3×, is at 1.35× a quarter line above its place 0.1 s in, and settles
    over 0.3 s (`TextReveal.letterPose`). Its reveal is drawn with room around the text, onto the quad grown by it.
  - The flood grows into the frame's shape (corners 0.35 of its height) to 1.05× what covers the frame: seen growing
    over 0.3 s, where the round pill had to reach 3–4 widths and filled the frame in two frames.
  - Bands are drawn inside their rectangle, so they leave with the iris; thin rings open by half the layer's side.
  - Particles are drawn at the frame's own time under motion blur (`isSharp`): a 180° shutter made them rays.
  - The pointer comes up from below the frame in 0.3 s, out-cubic, and its travel counts for motion blur.
  - Camera moves chain (`MoveExpansion.cameraContexts`): a pan in then a pan back out replaces a cut.
  - A kinetic caret shows 0.3 s before the first letter, so the caret from the scene before holds across the cut.
  - The lint holds a motion-design scene still for at most 0.72 s (a beat and a half), and counts a group once.
- `--tools …,Read --allowedTools … "Read(./.claude/skills/**)" --permission-mode dontAsk`: a headless run read its skill's
  reference and was denied a file outside it.
- Look-dev in the app (`~/Movies/Reco/quality/design/`): the reference's beats rebuilt from Spotify's web player (signed out,
  rows `div:nth-of-type(n) > [data-encore-id=listRow]` at a phone viewport) matched its frames beat for beat; that document is
  the skill's example. Spotify's nav logo lifts with a grey box behind it even bare: open question.

### S10 — Story films and score styles (`remotion`, spec 0015)

A third kind of launch film, after Lovable's chat launch (`~/Movies/Reco/references/lovable-launch.mp4`). One person's
request is told through the product's own prompt: their voice typed big in the brand's gradient, the product's controls
clicked in macro, and its answers arriving as things over the `aurora` ground, cut to a 170 BPM beat. Agents get it as a
third skill, `reco-story-film`. The score has styles: `ambient` (spec 0013's pads, the default), `groove` (Lovable's
drum and bass) and `house` (the Spotify Jam's). The motion-design skill writes `house`.

| File | Role |
|---|---|
| `Motion/Model/MotionField.swift`, `Render/AuroraSetup.swift`, `FieldKernels.metal.txt` (`auroraField`) | `aurora`: soft lights summed and read through a ramp from black via navy into the brand's gradient; a setup per scene, the last ringing a dark middle |
| `Motion/Model/StyleTokens.swift` | `gradient` (2–5 colours, cool end first) and `brandGradient` (its own, three steps from the accent, or silver) |
| `Motion/Model/MotionMove.swift`, `Grammar/MoveExpansion+Story.swift`, `TextReveal.swift` | `voice`, `reply`, `shimmer`, `wash`, `scatter`, `show`, `hide` |
| `Motion/Render/MotionPlan+Layers.swift`, `LayerTint.swift` | A voice line's follow track (on its group if it's in one); tints, a group's wash going to its layers |
| `Motion/Render/MotionFrameRenderer+Story.swift` | New words in the gradient behind a thin caret, shimmers, washes, gradients from one stretched ramp |
| `Motion/Render/MotionPointer.swift`, `ShapeGlyph.swift` | The hand scaled by the camera's magnification and carried over a cut; `chevron`, `mic`, `terminal`, `branch` glyphs |
| `Motion/Model/MotionSound.swift`, `Sound/BeatGrid.swift`, `BeatForm.swift`, `BeatScore.swift`, `SoundRules+Beat.swift`, `SoundVoices+Beat.swift`, `SoundFinish+Beat.swift` | `sound.style`; a grid fitted to the cuts, the form from the scenes, the arrangement, the voices, the −14 LUFS finish |
| `AgentRecording/Skills/reco-story-film*.md`, `Model/AgentSkill.swift` | The skill, its references (the film, recipes, the reference rebuilt as an example) |

Key facts:
- **The reference, measured.**
  - Its ground is black in 55–77 % of a frame and lit in 10–25 %.
  - Voice is typed at 12–16 characters a second; the newest words stay in the gradient for 0.8 s.
  - A wash takes 1.2 s; reply words arrive 0.1–0.2 s apart; a scatter throws out a stack in 0.45 s.
  - Macro shots are 3.6× with the hand as large as the pill.
  - Its music is 170 BPM drum and bass in F♯ at −15.8 LUFS: an intro without drums, a break under the big statement,
    drums out under the end words. The Spotify Jam's is 125 BPM house, F♯add9 ↔ A♯m7, −14.3 LUFS.
- **The aurora.** A dark ellipse lit round its edge drew a ring round every frame; the film's light comes from one or two
  places, so it's soft lights summed. Six setups were fitted to six of the film's frames by how much each lights. The
  light goes out over the video's last 2 s, and the first scene's light grows in over 0.6 s.
- **Voice.** Centred on its anchor while it grows, then the caret is held at 70 % of the width. It's drawn sharp: its
  follow, motion-blurred, doubled its letters. The lint reads typed text as it's typed, since Lovable cut away 0.1 s
  after the last letter.
- **Ramps.** A 1-pixel ramp scaled 100,000 times taller had its region of interest rounded to nothing ("No need to
  render"), so a ramp is clamped instead. Gradients cropped side by side left a hairline at each seam.
- **Beat scores.**
  - A score is cues, so the sheet stays the cache key; ambient sheets encode exactly as before.
  - The tempo is fitted within ±3 % so the most cuts land within 25 ms of a beat. A cut off the grid moves a drop by up
    to half a beat, so the skills put cuts on beats.
  - A logo's mark (a shape up to a quarter of the canvas) counts as words, so the end words make the outro, at most
    four bars.
- **Sound, measured.** Both styles detect their tempo, their band levels are within 1–2 dB of the references' bodies,
  and they finish at −14 LUFS, ≤ −1 dBTP. Nobody has listened to them yet.
- **Speed.** The Lovable rebuild (24 s) exports at 1080p in 10–17 s; its score renders in 0.4 s (M5, Debug).
- **Look-dev.** The look-dev is in `~/Movies/Reco/quality/story/`: `Lovable Rebuild.motion`, the skill's example.
- **Lint under a beat.**
  - `beats` flags a scene more than a frame off a whole number of beats; the Spotify example's scenes were moved onto
    the 0.48 s grid.
  - A scene's first move may land on its cut. The 0.1 s wait left the ground alone at every cut of the first Orca film.
- **The first Orca film from the app.** The run (Claude Code, default model) took 19 min and made a 38.5 s 4K film in
  20 scenes, every one whole beats. Its frames showed:
  - the logo lifted without `bare` sat on a black box;
  - a whole diff at 900 px had 10 px code;
  - task rows spun in smeared.

  The skill now says to lift the logo bare, to show dense panes close (text at least 28 px), and to cascade rows.
- **Run again** (`Orca 2`, 19.5 min, 37.1 s at 4K, 18 scenes). Every cut opens on content, the logo is clean, and the
  diff and terminals read. It added the 27 agent chips and a "Wants to run `pnpm migrate latest`" approval, and its
  groove breaks under "Ready for release.". A copy is on the Desktop as `Orca ADE.mp4`.
- **The user's verdict on it: "really bad" next to Lovable's.** Its answers were lifted panes (a terminal and a diff run off
  both sides, 27 agent chips cut at their ends), a docs `img` blurred at 4K, a mockup lifted mid-animation (grey loading
  bars), the box's type two thirds of Lovable's, no colour, and a ground of rings in blue to mint.
- **A rebuild by hand** (`~/Movies/Reco/quality/story/Orca Rebuild.motion`, `Orca vs Lovable stills.png`) set the bar the
  skill now teaches: the box at Lovable's size, the agents as a bento in their brand colours with their marks, the files
  as a collage of coloured cards, the diff rebuilt at 34 px, end words with a glow.
- **Marks.** An image address (`.svg`, `.png`, …) is lifted from a page of that one `img`
  (`WebPageRenderer.imagePage`): opened as itself, an SVG is an XML document and the lift script failed. A `ui` layer's
  `tint` draws the lift in one colour, so Simple Icons' black marks sit white on their tiles.
- **The aurora's lights are elongated** (`elongation`, `angle`), refitted to the film's seven frames in OKLab with the
  ramp's core: colour error 0.011–0.034 from 0.07–0.23. Round lights drew rings. The navy never climbs past the
  gradient's first colour, or two lights meeting drew a bright line. A monochrome brand gets violet, electric blue, ice.
- **A third run from the app** with the new skill (10 min, 30.4 s at 4K, `~/Desktop/Orca ADE v3.mp4`) made the agents'
  bento with their marks, the diff at 34 px, five PRs as a collage and "Merge all" in macro, every answer whole.
- `DesignCheck.cutText` names text off the frame unless the camera is 2× or closer or it's a voice line. Contrast is read
  against the nearest fill in the text's own group (nested groups compared other tiles' shapes).
- **The user found v3 still short**, and asked for Orca's own theme and Reco's shaders, with only Lovable's motion. The
  skill now takes the look from the brand: the product's theme (ground, surfaces, borders, fonts, status colours) over one
  of Reco's looks (dither, light, the aurora only for a gradient brand, satin). Its seams mark three turns: the opening,
  the first answer and the end words, then `ring` into the logo on `halo`. A black and white brand gets `warp` at 0.45
  and a grey-into-white gradient.
  - A first scene that isn't a macro arrives in the seam named on it, after the ground swells in (`Scene.arrivesAt`).
  - Under a shutter, opacity is read at the frame's own time (`placements(of:at:shown:)`): a hide/show swap drew both labels.
  - `DesignCheck.overlappingText` names a text drawn over another.
  - The fourth run from the app (`~/Movies/Reco/Orca 4-edited.mp4`, 10.5 min, 33.5 s at 4K) chose all of this
    unprompted. Its flaw: a diff's line numbers were stacked at one place. The fifth (`Orca 5`, copied to
    `~/Desktop/Orca ADE v4.mp4`, 10.5 min, 33.2 s) had none.
- **The user's notes on v4** (the wash not smooth, cards basic, the scatter rough, the music bad):
  - A wash is a curved front of the gradient's light out of the box's corner (`washLight`), gliding over 0.66 s.
  - A filled rectangle with `glass` is a pane of glass (`GlassRenderer`, 2.5 px rim); every story surface is glass.
  - Story films run at 60 fps; a scatter's stack is there from the cut.
  - The groove is wider: chords, claps and open hats in stereo (a second take as the side), hats at ±0.45, the pad
    3 dB up, no synthesized voice in the intro (`soundVersion` 2). Not yet listened to.
  - H.264 at 4K stops at 30 fps (its preset); story films export HEVC for 4K60. The sixth run is `~/Desktop/Orca ADE v5.mp4`.
- **Then** (a check on "Merged", "too punchy … the same sound everywhere"): the finish's label is anchored at its left with
  the check before it, and `DesignCheck.overlappingText` names a glyph over text. Story films leave the groove for the
  ambient chords and a sound a transition (`SoundCueList+Story`): a dither seam's `bits`, a glow's air, the ring's swell
  and hit, a wash's shimmer, a chime when things turn to done, a quieter swish alone on cuts, no keys under a voice.
  A scene's clicks share one pointer, gliding from press to press as the hand. Seventh run: `~/Desktop/Orca ADE v6.mp4`.

### S11 — Flow films (`remotion`, spec 0016)

A fourth kind of launch film, after two light AI launch reels (Vantae, IrukaDark; copies in
`~/Movies/Reco/references/new/`): one unbroken flow on a white ground lit by the brand, every scene growing out of the last.
It ships as the `reco-flow-film` skill, the prompt's default for a product whose own UI is light (the story film stays the
default for a dark one).

| File | Role |
|---|---|
| `Motion/Render/AuroraSetup+Haze.swift`, `FieldPalette`, `FieldRenderer`, `auroraField` | `haze`: the aurora's lights read through a ramp from paper white into `style.gradient` (pale to deep), five setups, wandering 6× as far and 5× as fast, swinging round |
| `Motion/Render/MotionFrameRenderer+Seams.swift`, `FieldKernels.metal.txt` (`meltSeam`) | `dive` (the camera through the last click into the next scene, tilting) and `melt` (by light and place, grain, the brand's colours at the front); `transitioned` draws every seam |
| `Motion/Grammar/MoveExpansion+Flow.swift` | `fly`: a mark on an arc onto its place, banking |
| `Motion/Render/TextSelection.swift`, `MotionFrameRenderer+Flow.swift`, `MotionPointer.swift` | `select`: a text selected line by line as the arrow drags along its end (`Click.sweep`) |
| `AgentRecording/Skills/reco-flow-film*.md` | The skill, the two reels measured, recipes, Vantae's reel rebuilt as the example |

Key facts:
- **The references.** Vantae is still in 1 % of its 0.1 s steps (median change 5.7), IrukaDark in 22 % (2.9); a film of
  cards that appear and wait, in half. Vantae's ground is a deep blue blob (`#0436e7` → `#0b92f6`) turning round `#f5fbfd`,
  IrukaDark's a pastel orb on `#fcfcfc`. Their music is a beat (126 BPM house, 176 BPM breaks); flow films keep the quiet
  chords and a sound a transition.
- **Stillness.** Vantae's rebuild was still in 53 % at first: pushes at intensity 0.4–0.9 over white move few pixels. With
  the haze's wander and pushes at 2.5–3 it's 15 % (median 2.8). The skill asks for a camera move in every scene.
- **Melt.** Ordered by light alone, a white frame dissolved at once into a frame of blue grain; 40 % of the order is place,
  from the top left, so a plain frame has a front.
- **Dive.** Its window follows the clicked thing as the scene before goes on under the seam (`expandSource(into:at:plan:)`):
  fixed where it was at the cut, it slid off a drifting macro's send button.
- **Light grounds** (`MotionPlan.isLight`): what goes behind a stack or expand dims to 0.15 black, not 0.55.
- The lint lets a story film's first move land on its cut, and any scene after a seam other than a cut.

### Telemetry JSON (version 3)

```
version, keystrokesAvailable,
capture:       { kind: display|window|area|web, videoSize: [w,h], cursorInVideo }  // missing → true
geometry:      [{ time, screenRect, contentRect, boundingRect?, contentScale, scaleFactor }]
cursor:        [{ time, location: [x,y] }]            // only when changed
clicks:        [{ time, location, button, isDown, clickCount }]
scrolls:       [{ time, location, delta: [dx,dy] }]
keys:          [{ time, keyCode, modifiers: [..], isRepeat }]
navigations:   [{ time, url }]                        // web takes: pages a click opened; missing → none
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
| N20 cancel / restart recording (spec 0009) | Done; not yet tried on a real recording (the output folder after a cancel, a restart's new file) |
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
| S1 editor design: system colors, glass transport, new timeline and inspector | Done; glass, hover and animations still need a look in the app on macOS 26 and 15. The side panel, tray, chat and its empty state were checked in window captures on macOS 26.5 (dark); a run's status, failure card and the transitions in motion were not |
| C1 screenshots (area, window, screen) | Done, verified on real captures; each shot opens the Quick Access card and is saved only from it |
| S2 web recordings (spec 0005) | Done and tested; the window's view model was driven end to end on apple.com (pick, render, editor, export). The window itself (buttons, timeline dragging, pick banner) still needs clicking through by hand |
| S3 agent bridge (spec 0006): MCP server for coding agents | Done; tested over the real socket (token, `initialize`, `tools/list`, error calls), the `--mcp` process (`AgentBridgeClientTests`), config editors and plans. Not yet tried: real agents connected by hand, a real `record_page` render, Gatekeeper on another Mac |
| S4 agent recording (spec 0007): Record with AI Agent bar, no App Sandbox | Done and tested with fakes and real `/bin/sh` processes; the login-shell environment was read on this Mac (0.86 s). Not yet tried: any real agent run, the panel in the app (focus, Esc, picker menus, Reduce Motion/Transparency), the update from the sandboxed release (migration), Codex |
| S5 agent chat and reliable web takes (spec 0008) | Done and tested: real Claude Code runs from the prompt and from the chat in the app (sent through accessibility), 60 s apple.com takes checked frame by frame. Not yet tried: Retry and Cancel by hand, VoiceOver, Reduce Motion, other agents |

| Spec 0009 batch 1: cursor loop/hold/tilt, motion blur, GIF, copy frame, `export_recording`, type steps, shown elements, playbook | Done and tested; a real web take was exported as GIF and HEVC and its frames checked (zoom blur, cursor trail, tilt, loop); linear.app walkthroughs run from the app through `reco://record-agent`. Not yet tried: the new controls in the app, a GIF of a long recording, typing on real sites (React forms, search boxes), `export_recording` from a real agent |
| S6 motion editor (spec 0011): launch videos as motion design from the real UI | Phases 0 and 1 done: benchmark, spikes, document, renderer, preview and export. Phase 2 done: lifts, live layers, media on the take's clock, `hide`, sign-in, `brand`. Phase 3 done: moves, seams, shots, lint, scenes lane and inspector; the benchmark rebuilt in 10 lines and three sites rendered, awaiting the user's side-by-side. Phase 4 done: agent tools, Launch Video mode, chat with selection; three sites run from their address with clean lint and design check, three chat edits change only their targets; cost recorded for one run. The window seen in a window capture; editing by hand not yet tried |
| S7 motion quality (spec 0012) | Motion reel picked. Q2.1 fields ported, then rejected by the user as pasted behind the old video; directions picked from launch films (Raycast, Nothing OS 5.0, 3D layers). L1a–c built (satin, coverage mattes, typing cursor rules, parallax, motion blur), but the user found the test shot "really bad" next to Raycast. L0: still frames matched to Raycast's (glass for lifted UI, hero scale, a better ground), then a 24 s Supabase docs film in that look rendered as a look-dev pass outside the engine. The user approved the film; its port into the engine has begun: phases 1 (satin, grain), 2 (glass, sharp macro) and 3 (typing, caret, results) done, matching the film at 47–64 dB; phase 4 captures UI behind a click and typing states live (Supabase's search, matching the film's lifts); phase 5 the selection, the camera following it, the whip's blur; phase 6 the `closing` shot; the whole film now made by the app from one document, matching the approved one where the site is the same. L4/Q4: the film's grammar named (`macro` views, `whip` move and seam, mockup typing) and its method shipped as the `reco-launch-film` skill; Launch Video runs on linear.app from the address make macro films on glass over satin. Looks: light and dither grounds (Paper's other shapes) and seams in their language (`glow`, `dither`, `ring`), the agent choosing the look from the brand. Next: the user's verdict on them |
| S8 motion sound (spec 0013) | S1–S4 done: cue sheet from the plan, voices, room, finish, loudness, cache, preview and export, `set_sound`, the Sound section; the Supabase film's sheet matches the hand-made score. Next: the user's listening round (S5) |
| S9 motion design (spec 0014) | D1–D5 done: morphs, floods, pops, clicks, bursts, ripples, letters, kinetic type, scrolls; their sounds; the `reco-motion-design` skill with references read on demand; look-dev matching the Spotify Jam reference. D6: a Spotify film made from the app (9 min, 30 s 4K, every named movement). D7: smoother after the user's review (letters, flood, bands, sharp particles, pointer, spin, chained pans, stillness lint, skill and example rebuilt). Next: the user's verdict |
| S10 story films and score styles (spec 0015) | Reference measured (picture and music; the Spotify Jam's music too); `aurora`, the brand gradient, voice, reply, shimmer, wash, scatter, show/hide, UI glyphs, the hand in macro; `groove` and `house` scores fitted to the cuts; the `reco-story-film` skill; the reference rebuilt in the engine and checked frame by frame; `beats` lint. Orca ADE made from the app twice; the user found it "really bad". Rebuilt by hand to Lovable's bar (stills checked), and the engine (elongated aurora lights, SVG marks with `tint`, text-off-frame check) and skill (answers as coloured things, Lovable's type sizes) changed to match. A third run from the app follows the new recipes. The user found it short still: the look now comes from the product's theme over Reco's shader looks (Orca: `warp` dither, its seams, the halo), Lovable giving only the motion; the shutter swap fix, the opening's arrival, and the overlapping-text check. Then glass cards, a corner wash, 60 fps and a wider groove after the user's notes; then a sound for each transition instead of a beat. Next: the user's verdict, a listening round |
| S11 flow films (spec 0016) | Both reels measured; `haze`, `dive`, `melt`, `fly`, `select` and their sounds; the `reco-flow-film` skill with Vantae's reel rebuilt as its example and IrukaDark's pieces checked; the default for light products. Next: films from the app, the user's verdict |

What to build next: `docs/specs/0012-motion-quality.md` (October 2026), phases Q1–Q6; spec 0011's phases 5–7 wait for it. The earlier
order: `docs/specs/0009-stand-out-roadmap.md`. The N items' details, ranked from a September 2026 survey of competitors and Apple's on-device APIs:
`docs/specs/0004-next-features.md`.

Reference repos for later work: `syi0808/screenize` and `imbhargav5/open-recorder` are Apache-2.0
(portable with attribution). `lzhgus/Capso` (BSL, bans screen-capture use) and
`lihaoyun6/QuickRecorder` (AGPL) are **ideas only — never copy code**.

## Known open items

- Not yet verified on real recordings: area capture mapping, a window moved/resized mid-recording.
- `RecorderViewModel` is over SwiftLint's file length limit (pre-existing, 711 lines after cancel/restart); split it before adding more.

## Verifying against real recordings

Recordings can be scripted: select content once in the menu, then drive the running build with
`open -g -a /tmp/bc-build/dd/Build/Products/Debug/Reco.app "reco://toggle"` (starts
when content is selected, stops when recording; no countdown), `reco://pause` and
`reco://edit-last` (opens the editor); `open -a <app> <movie>` opens any recording in the editor. Use `-a` with the path:
a plain `open` may launch another copy (e.g. Xcode's DerivedData build). Play `afplay` ticks at
logged wall times, then check each tick lands where expected in the audio, shifted by the paused time.
Watch the app's logs with `/usr/bin/log stream --level info --predicate 'subsystem == "com.diip3sh.Reco"'`
(the full path matters: in zsh, `log` is a builtin).

Frame-level checks beat eyeballing. With `ffmpeg`/`ffprobe` (Homebrew):
- Stream lengths: `ffprobe -v error -show_entries stream=codec_type,duration,nb_frames -of compact <file>`
- Frame at a time: `ffmpeg -ss <t> -i <file> -frames:v 1 out.png`, crop around
  `InputTelemetry.videoPixel(...)` to check the cursor tip lands on the prediction.
