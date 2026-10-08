# CLAUDE.md

Coding rules, Swift/SwiftUI conventions and git workflow live in AGENTS.md — follow them:

@AGENTS.md

This file covers what AGENTS.md doesn't: how to build this fork, what it adds on top of upstream
[jsattler/BetterCapture](https://github.com/jsattler/BetterCapture), where that code lives, and what's next.

## What this fork is

Reco is a macOS menu bar screen recorder (ScreenCaptureKit + AVAssetWriter, not sandboxed since 2026-10-01, spec 0007), forked from BetterCapture
and renamed: its own bundle ID (`com.diip3sh.Reco`), `reco://` links, and Reco in every name.
**Users see it as Orbit** (2026-10-05): `CFBundleDisplayName`, user-facing strings, the release title,
the DMG and the app's file name in it (`RELEASE_NAME` in `fork-release.yml`). The target, scheme, module,
executable, bundle ID, `reco://`, the agents' `reco` MCP server key, `Reco_*` file names and `Movies/Reco`
stay Reco, so installed copies keep updating (Sparkle matches the DMG's `Orbit.app` by bundle ID and
installs at the old path), their permissions and settings, and connected agents. `CFBundleName` stays
Reco: the generated plist's value wins over `Info.plist`. Release install steps: `dist/install-notes.md`.
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

- Tests: same command with `test` instead of `build -quiet` (Swift Testing, 862 tests).
- Lint: `swiftlint lint --quiet <files>` — new code must be clean. Pre-existing warnings:
  `AssetWriter.swift` (file_length, type_body_length, 2× function_body_length),
  `RecorderViewModel.swift` (file_length, type_body_length) and `AreaSelectionOverlay.swift`
  (file_length, type_body_length). Don't make them worse; SwiftLint skips
  extensions for type_body_length, so new logic goes in same-file extensions or new types.
- Keep build output outside the repo (`/tmp/bc-build`). If the build fails with "There is no
  XCFramework found", `rm -rf /tmp/bc-build` and rebuild (moved DerivedData breaks SPM paths).
- Incremental builds can keep a stale layout of a generic view: on 2026-10-05 `InspectorSection`'s stored
  properties changed and changed back, its users weren't recompiled (`WebRecordingInspector.o` stayed older than
  `InspectorSection.swift`), and opening Web Recording crashed with `EXC_BAD_ACCESS` in an "outlined copy" of it.
  A crash in compiler-generated copy code right after such an edit: `rm -rf
  /tmp/bc-build/dd/Build/Intermediates.noindex/Reco.build` and rebuild.
- Never subclass `NSHostingView<Content>` with a generic `Content`: Swift 6.3.3's Release optimizer
  (Xcode 26.6, `EarlyPerfInliner`, x86_64 whole-module) crashes in the deinit of such a subclass. Measured
  2026-10-05: Debug was fine and so was a local arm64 Release build, so it showed up only in CI's Release
  job. `FirstMouseHostingView` (capture toolbar) and `NotchHostingView` (notch shelf) are
  `NSHostingView<AnyView>`, their call sites wrapping the root in `AnyView(...)`. `xcodebuild`'s summary
  hides a compiler crash like this; read the raw log or the `.xcresult` for it.
- **Never launch an ad-hoc signed build.** Its designated requirement is pinned to its cdhash
  (`designated => cdhash H"…"`), which changes on every build, while TCC stores the cert-anchored
  requirement (`anchor apple generic and certificate leaf[subject.CN] = "Apple Development: …"`). So
  tccd logs `Failed to match existing code requirement for subject com.diip3sh.Reco and service
  kTCCServiceScreenCapture` and macOS asks for Screen Recording again — **while System Settings still
  lists Reco as allowed**, because that row survives (auth_value=2) and simply stops matching. Nothing
  is actually lost; the app just isn't recognised.
  - This Mac has one valid Apple Development identity, and Xcode's own build signs **ad-hoc with no
    team identifier** (`Signature=adhoc`, `TeamIdentifier=not set`). So ⌘R, or any `xcodebuild`
    without the settings below, produces a Reco that cannot keep the permission — and it lands in
    `~/Library/Developer/Xcode/DerivedData/Reco-*/Build/Products/Debug/Reco.app`, a second copy whose
    path becomes the process's responsiblePath. Measured 2026-10-05: that is exactly what happened.
  - `scripts/dev.sh` now refuses to launch a build whose `TeamIdentifier` is unset, and names a Reco
    that is running from another build.
  - `tccutil reset ScreenCapture com.diip3sh.Reco` looks the app up through Launch Services, which
    doesn't index `/tmp`, so it answers `No such bundle identifier` (-10814) for a dev build. Fix a
    stuck grant in System Settings → Privacy & Security instead: remove Reco, launch the signed build,
    grant again. Microphone is the same and keeps its row in the per-user TCC database, not the system
    one (`kTCCServiceMicrophone` is absent from the system db while `kTCCServiceScreenCapture` is there).
- Live reload: `brew install --cask injectioniii`, run it, open this project in it, then run the app. Saving
  a Swift file patches the running Debug build (`DebugInjection`; Debug has `-interposable` and no hardened
  runtime). Changes it can't patch (new stored properties, type layout) need a relaunch: `scripts/dev.sh`
  rebuilds and relaunches on save.
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
| `Model/SettingsStore+CursorCapture.swift` | `keepSystemCursorInVideo`, `leavesCursorToEditor`, `capturesCursor` (used for `SCStreamConfiguration.showsCursor`) |

Arrow and I-beam bitmaps go up to 10× (280×400 px); other standard cursors only 2×, so the captured
PNG is as sharp as anything `NSCursor` offers at edit time.

Risk: `NSCursor.currentSystem` is marked "to be deprecated" with no public replacement. If it starts
returning nil, sprites are simply empty; nothing else breaks.

### F4 — Pause / resume (`feat/pause-resume`, upstream issue #174)

Menu bar **Pause/Resume** button, global shortcut **Pause/Resume Recording** (⌘7), and
`reco://pause`. The SCStream keeps running while paused (instant resume, macOS recording
indicator stays on); every sample is dropped and the paused time is cut from the file.

| File | Role |
|---|---|
| `Service/RecordingPauses.swift` | Pure struct: per sample, drop (`nil`) or return paused time to subtract |
| `Service/AssetWriter.swift` | `timelineOffset(of:duration:)` rebases every track, the CFR grid and head silence padding by `sessionAnchor + pausedTime`; `pause`/`resume`/`pauseIntervals` in the `// MARK: - Pausing` extension; last frame captured while paused is shown from the resume point |
| `ViewModel/RecorderViewModel.swift` | `isPaused` flag (state stays `.recording`), `togglePause()` extension, timer excludes paused time |
| `Model/InputTelemetry.swift` | `rebased(anchor:duration:pauses:)` drops events inside pauses and shifts later ones |

Audio buffers straddling a pause edge are dropped whole (gap ≤ ~21 ms per edge, marked `ponytail:`).

### N21 — Hide desktop icons (spec 0004)

**Settings → Video → Display Elements → Show Desktop Icons** (on by default). Off, display and area recordings leave out
Finder's one display-sized window at `kCGDesktopIconWindowLevel` (`ContentFilterRules.desktopIconLevel`, matched with
Finder's bundle ID: WindowManager has an empty window at that level while macOS hides desktop items), so the icons are
missing from the video while the desktop stays as it is. Verified on macOS 27.0.1 by capturing that window alone and the
display without it.

### N20 — Cancel and restart (spec 0004)

The capture toolbar's live pill has **Cancel** (trash) and **Restart** beside Pause; global shortcuts **Cancel
Recording** and **Restart Recording** (Settings → Shortcuts, no defaults: a stray global key would throw a take away),
`reco://cancel` and `reco://restart`. `RecorderViewModel.cancelRecording()` stops what feeds the take (`endCapture()`,
shared with `stopRecording`), drops the buffered telemetry (`InputTelemetryRecorder.discard()`) and cancels the writer,
which deletes the movie: nothing is saved, notified or opened. It also cancels a countdown. `restartRecording()` cancels,
then starts again on the same selection, through the countdown unless it came from `reco://restart`.

### F5 — Countdown (`feat/countdown`)

**Settings → General → Recording → Countdown**: Off / 3 / 5 / 10 s (default 3). Every user start (the capture
toolbar's Record, Toggle Recording shortcut) shows a big number centred on what will be
recorded (area, window, or display) and the seconds in the menu bar. `reco://toggle` /
`toggle-copy` skip the countdown (and cancel one that's running) so automation stays precise.

| File | Role |
|---|---|
| `Service/RecordingCountdown.swift` | `@Observable` tick loop (`remaining`), cancellable, injectable one-second sleep for tests |
| `View/CountdownOverlay.swift`, `View/CountdownView.swift` | Click-through, non-activating `.screenSaver` dark panel with the number on a 150 pt disc of the capture toolbar's dark glass (`captureToolbarPill(in:)`) that grows in from its centre (`panelPresentation`) and counts with `numericText`; Esc as a temporary global hotkey |
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
(`cardSize(for:)`: fitted in 260×220, never enlarged, at least 200×120) on an 8 pt glass edge. **Copy ⌘C** and
**Save ⌘S** (the shortcut shown dimmed in the button) always sit along its bottom edge; under the pointer the shot
dims and shows Close, **Recognize Text** and **Pin** as small icons in its corners. The card takes key when it appears, without
activating the app, so the shortcuts work until another window is clicked; typing goes to the card meanwhile.
It grows from the card's corner nearest the pointer (`QuickAccessController.anchor(for:pointer:)`, the
bottom-left without a region) and shrinks back there when closed, copied, saved or pinned; `hide()` and
`restore()` stay instant. Drag the card by its 8 pt edge: it follows the pointer 1:1 from where it
was grabbed (`PanelDragger`), and a flick that projects past the screen's edge (`GesturePhysics.flickExit`)
throws it off at the release speed and closes it; a slow drag stays where dropped, a flick inwards too. Drag the shot into
any app to drop the image. The card and the capture toolbar have no window shadow: it outlines
the rectangle around their rounded glass. Nothing is written until **Save**. The card stays until
closed, copied, saved, pinned, or replaced by the next screenshot. **Esc** closes it, like the Close button and
a flick: the panel is key while it shows, so `QuickAccessView` handles it (`.onExitCommand`), not the window.
`AppDelegate` wires `ScreenshotController.onWillCapture` to `hide()` so the card never lands in the next shot, and
`onDidCapture` to `show(_:)` for a new screenshot or `restore()` (same card, same place) when the capture is
cancelled or fails. The capture toolbar is hidden the same way but **isn't** brought back by a cancelled capture:
it was only the way in, so Esc on an area selection closes that state and leaves the screen as it was.

- **Copy** (C14): PNG data only; the button turns to ✓ Copied as the card starts closing, so it confirms during the
  fade. **Save**: writes to the screenshot folder, then the same with ✓ Saved; each button is as wide as its wider label; on failure the card stays and the Screenshot Failed
  notification is sent. **Recognize Text** (C7): the
  image's text to the clipboard, or, when it holds QR codes or barcodes, their payloads (N16: `TextRecognizer.codes`, Vision's
  `DetectBarcodesRequest` alongside the text request; Code Copied). **Pin** (C8): the image in its own panel, then closes. Recognize Text
  confirms on the card for 1.5 s.

| File | Role |
|---|---|
| `QuickAccess/View/QuickAccessController.swift`, `QuickAccessPanel.swift` | Non-activating borderless `.floating` dark panel (key on appearing, `hidesOnDeactivate = false`), enter/exit through `panelPresentation` (`exitDelay` before ordering out; leaving panels are tracked so `hide()` clears them too), placement (`panelFrame`), owns the card's view model and the pins |
| `QuickAccess/ViewModel/QuickAccessViewModel.swift` | One screenshot's intents and feedback, the drag-out file; reports up through `onClose`/`onPin` |
| `QuickAccess/View/QuickAccessView.swift`, `PanelDragger.swift` | Card layout on `editorGlass` (16 pt radius), hover scrim and controls (Copy and Save both `.editorPrimary`: secondary's accent text over the shot read as a disabled Copy; dark corner icons), a solid toast; icons are 1.5 pt line
SVGs in `Assets.xcassets/LineIcons` as template vectors, drawn by `LineIcon` in `CornerButtonStyle`'s dark circles (both shared with pins): Hugeicons
stroke-rounded (MIT) cancel, checkmark circle, scan text and pin, as in the capture toolbar (the app's icons are SF Symbols and Hugeicons only); a `DragGesture` on the edge drives `PanelDragger` (screen coordinates, `VelocityTracker`, flick exit), `.onDrag` on the shot. Annotate goes first in the top-right corner once it exists (one line) |
| `QuickAccess/View/PinController.swift`, `PinView.swift` | One `.floating` panel per pin at the shot's point size fitted to the screen (`frame(for:at:in:)`), aspect-locked resize, drag anywhere, 8 pt rounded corners with a faint edge, the card's close button on hover; appears from and closes into its bottom-left corner (`panelPresentation`, a `PanelPresence` per pin) |
| `QuickAccess/Service/ImageDownsampler.swift` | Card preview drawn from the captured `CGImage` off the main actor |
| `Screenshot/Service/TextRecognizer.swift` | Vision `RecognizeTextRequest` (accurate, automatic language) off the main actor; `joined(_:)` orders lines top to bottom |
| `Service/ImagePasteboard.swift` | PNG data on the pasteboard (Slack, Messages, Figma, Preview) |

Key facts:
- The full-size `CGImage` is held only by the card, pins and `QuickAccessController.closedScreenshot`; the card shows a
  preview drawn at 2× of its largest size.
- **Restore Last Screenshot** (N15; menu bar, idle only, shown while there is one) brings back the last card that went
  away (closed, copied, saved, pinned, flicked or replaced by the next screenshot) in the screen's corner, from memory; a
  card showing takes its place. One screenshot is kept, until quit.
- Drag-out offers the file URL and PNG data. The file is written in the background to
  `temporaryDirectory/<UUID>/<save name>` when the card appears (a drop reads the URL at once, so it must
  exist first) and deleted when the card closes.
- The card is hidden as a capture starts (`onWillCapture`); pins and other Reco windows are in the shot.
- A window shadow doesn't follow the fade, so pins have it off while entering and leaving and turn it on
  (`invalidateShadow()`) once settled. The card has none.

### S1 — Editor, phase 1: shell and playback (`feat/editor-shell`, spec 0003)

Opens a recording in its own window with the preview, transport controls and a timeline (filmstrip,
click/key lanes, playhead, scrubbing). Every recording with video opens in it as soon as it is saved
(`RecorderViewModel.onRecordingFinished`, wired to `EditorWindowManager.open` in `AppDelegate`), with no
Recording Saved notification; a take copied by `reco://toggle-copy` keeps the notification instead, so automation
isn't interrupted. Also **Edit** on that notification (its default action when the cursor was left out of the
video), **Edit Last Recording** in the menu bar, and `reco://edit-last`. Keys: space play/pause, ←/→ step a frame, ⌘Z/⇧⌘Z undo/redo.

| File | Role |
|---|---|
| `Editor/View/EditorWindowManager.swift` | One `NSWindow` + `NSHostingController` per recording, owned by `AppDelegate`; `.regular` activation policy while any is open; holds the output folder's security scope until the window's project is saved |
| `Editor/ViewModel/EditorViewModel.swift` | Loads source + project, `edit(_:_:)` (one undo step, registers redo), 1 s debounced autosave, `rename(to:)` (saves, moves the files, reopens at the playhead, `onRename` re-keys the window), `close()` |
| `Editor/Model/RecordingRename.swift`, `Editor/Service/RecordingRenamer.swift`, `Editor/View/RecordingNameField.swift` | Pure rules (valid names, the field's name without the web prefix, which files move); the all-or-nothing move; the title bar's click-to-rename field |
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
switches the window to **export** (2026-10-07; a sheet until 2026-10-06, then a page that slid over the editor): the
preview stays, the transport and timeline slide down out of the window and the preview grows into the room, and only the
inspector's content changes, to the export's options (`ExportOptions`, in the inspector's own sections and `SegmentedChoice`).
One `.inspector` serves both modes so the column never moves; it opens at `EditorInspector.idealWidth` (380 pt, picked by hand
in a 1533 pt window) and always shows during export. Both ways run on a 0.25 s critically damped spring, a cross-fade with
Reduce Motion. The title bar shows the recording's name in both modes (`RecordingNameField`, in the leading toolbar item; the window's title is
hidden and not bridged, since SwiftUI draws a bridged title whatever `titleVisibility` says, and set by hand for the Window
menu; a flexible `ToolbarSpacer` holds the buttons at the trailing edge): a click turns it into an AppKit field (`@FocusState`
didn't reach a field in the toolbar, and its field editor took Esc) that renames the movie and its
telemetry and project (`RecordingRename`, `RecordingRenamer`; Return or leaving the field commits, Esc cancels, and Esc doesn't
also trigger Back meanwhile). A web recording's `Reco_Web_` prefix is kept but hidden in the field, and names ending in `-edited`
are refused, since the Library tells kinds apart by file name alone. Back is a back/forward pair (`ControlGroup`, `.navigation` style;
forward always disabled) in the title bar, in front of the recording's name (`ControlGroup`'s navigation style is a capsule only in a
toolbar; in the inspector it drew a bordered box). **Back**/Esc returns; Esc is Cancel while an export runs, and Back is disabled then. Export opens and leaves on a
paused frame, and the editor's keys (S, Z, ⌫, arrows, Space) go with the transport. `ExportSession` holds one visit's settings,
running export and result, so the toolbar and the inspector share it. The inspector is laid out in this order: **Export As**
(MP4 (HEVC), ProRes, GIF), **Output Size** (Original, 720p, 1080p, 4K, with the pixel size under it; only sizes under the canvas's are
enabled), **Frame Rate** (15, 30, 60 fps; not above the recording's, and a GIF's at most 30) and **Quality** (Studio, Social Media, Web,
Web (Low), as rows each with its estimated size; none for a GIF, whose size depends on what's on screen). Under a line, **Export ↩**
writes `<name>-edited.mp4`, `.mov` (ProRes 422, or 4444 when the canvas is transparent) or `.gif` next to the recording, then offers
**Share…** (`ShareLink`: AirDrop, Mail, Messages…) and **Show in Finder** with the file's real size; **Copy to Clipboard ⌘↩** exports the
same file to a temporary folder and puts its URL (and a GIF's data) on the pasteboard (`FilePasteboard`). Under the buttons, "Estimated max
size" for the chosen quality. The estimate is honest because the export encodes to a bitrate it sets itself: MP4 at 0.20, 0.10, 0.05 and
0.025 bits per pixel per frame for the four qualities (plus AAC at 128 kbit/s), ProRes 422 as HQ, 422, LT and Proxy at Apple's target
rates for 1080p29.97 scaled to the size and frame rate (220, 147, 102, 45 Mbit/s; 4444: 330) with 16-bit PCM audio, all times the output
duration (`ExportSettings.estimatedBytes`). Measured on 640×360 frames of grain, 2 s: the MP4's average bitrate came out at 1.06, 1.07 and
1.05 times the target for Studio, Social Media and Web; Web (Low), whose 0.025 is under what that content costs at the encoder's coarsest,
came out at 1.55. Flat frames come out far under, so the number is a maximum.
Web Recording has no export of its own: Render opens the editor, and this is its export.

| File | Role |
|---|---|
| `Editor/Render/RenderPlan.swift` | `Sendable` snapshot built off the main actor on every edit: click markers already in Core Image pixels, keystroke chips, and images drawn once (`OverlayImages`) |
| `Editor/Render/FrameRenderer.swift` | `(source frame, source time, plan) -> CIImage`; the only place pixels are decided |
| `Editor/Render/EditorCompositor.swift`, `EditorInstruction.swift`, `CompositionBuilder.swift` | `AVVideoCompositing` with one shared `CIContext`; the instruction carries the plan; the same video composition feeds `AVPlayerItem` and the export's reader |
| `Editor/Service/KeyLabelFormatter.swift` | Key code + modifiers → "⇧⌘K" with the current layout (`UCKeyTranslate`); TIS is read on the main actor only |
| `Editor/Service/ExportService.swift`, `MovieEncoder.swift`, `GIFEncoder.swift`, `GIFMuxer.swift` | The export: an `AVAssetReader` (the composition's frames and the mixed audio) feeding an `AVAssetWriter` (HEVC at the quality's average bitrate in MP4, a ProRes flavour in MOV, AAC or PCM), fed per input on a queue with `requestMediaDataWhenReady`; cancelling the task stops the reader and removes the partial file. A GIF is written a frame at a time: ImageIO encodes each frame on its own and `GIFMuxer` joins them (ImageIO's own animated GIF holds every frame until the end: 19 GB for 30 s of 1786×1080 at 30 fps, against 54 MB above idle this way, measured), each delay in whole centiseconds from the cumulative rounding |
| `Editor/View/EditorInspectorSections.swift`, `ExportOptions.swift`, `Editor/ViewModel/ExportSession.swift` | Style controls (bound through `EditorViewModel.clickHighlights`/`keystrokes`); export's options (format, size, frame rate, quality, actions, progress) and its state; `Model/ExportSettings.swift` (pure: availability rules and size estimates), `ExportQuality.swift`, `ExportFormat.swift`, `ExportDestination.swift` |

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
Audio tab sets each track's volume and mute, and holds the background audio (below).

| File | Role |
|---|---|
| `Editor/Render/TimeMap.swift` | Output ↔ source time by binary search, and every cut operation: normalize, add, restore, move a kept range's edge, divide at splits |
| `Editor/Render/CompositionBuilder.swift`, `EditorComposition.swift` | `AVMutableComposition` of the kept ranges (every track, source track IDs), the video composition, and the `AVAudioMix` with volumes and fades |
| `Editor/ViewModel/EditorViewModel.swift` | `// MARK: - Cutting` extension: `split()`, `select(at:)`, `deleteSelection()`, `moveStart`/`moveEnd(ofKeptRange:to:)`; rebuilds swap only what changed |
| `Editor/View/EditorTimelineView.swift`, `TrimHandle.swift` | Source-time timeline: dimmed cuts, splits, selection, handles |
| `Editor/Model/AudioMixSettings.swift` | Volume and mute per audio track, by the recording's track order |

Key facts:
- Everything in the project and on the timeline is source time; the player, the transport's time
  label, the compositor's requests and the plan's click markers, keystroke chips and camera are
  output time (speed, below). `TimeMap` is the only converter.
- Cuts are normalized as frame boundaries (integers); the last boundary is the recording's end
  wherever it falls, so a trailing cut never leaves a sliver. Something must stay: trims keep a
  frame per kept part, and the last part can't be cut.
- `splits` are saved in the project, so a split is an undoable edit. Splits inside cuts are kept
  and come back if the cut is restored.
- A new player item is made only when the cuts or speeds change (the playhead stays on its content); other
  edits swap the video composition, volumes only the mix.
- Audio fades 25 ms at every cut. The mix lags its ramps by ~10 ms: at a cut, 10 ms ramps still
  left 57% of the volume, 20 ms 20%, 25 ms 2%.
- Audio tracks are named by the writer's order: two tracks are system audio then microphone; one
  track is just "Audio" since it could be either.

### S2 — Speed per part, Speed Up Typing (spec 0014, N7)

Select a part, then the transport's **Speed** menu sets it to 1×, 1.5×, 2×, 3×, 4× or 8× (one undo step; its
ends become splits); the timeline labels each part that isn't at 1×. **Motion → Speed → Speed Up Typing** speeds
every stretch of typing still at 1× in one undo step: 2× under 6 s, 3× under 12 s, 4× beyond.

| File | Role |
|---|---|
| `Editor/Model/SpeedRange.swift` | A source range and its rate; `EditorProject.speeds` (cut parts keep theirs) |
| `Editor/Render/TimeMap.swift` | Kept ranges divided at speed edges into `pieces`, each lasting length / rate in the output; `rate(atSource:)`, `outputTime(ifKept:)`, `speeds(setting:for:)`, `speeds(adding:)` |
| `Editor/Service/TypingStretches.swift` | Pure: presses that aren't auto-repeats, gaps under 1 s, at least 3 s; ⌃/⌥/⌘ ends a stretch |
| `Editor/Render/CompositionBuilder.swift` | Each piece inserted at its output length (to the nanosecond): video scaled with `scaleTimeRange`, audio at another speed from its sped-up file (`ExtraAudio.fastParts`, silent without one); music fills the output |
| `Editor/Service/SpeedAudio.swift`, `EditorViewModel+Audio.swift` | Each audio track's (and the click sounds') part at another speed, run through `AVAudioUnitTimePitch` in an offline `AVAudioEngine` with 0.25 s of context read on each side, to an Apple Lossless CAF in `temporaryDirectory/Reco Speed Audio/`; rendered once per part and rate (`fastPartAudio`), deleted when the window closes |
| `Editor/ViewModel/EditorViewModel+Speed.swift`, `Editor/View/SpeedInspectorSection.swift` | `selectedSpeed`, `setSpeed`, `typingSpeedUps`, `speedUpTyping()`; the Motion tab's Speed section |

Key facts:
- Click rings, keystroke chips and the camera are timed on the output, so a ring lasts its duration and a zoom
  eases at its pace in a 4× part; the camera also eases across a cut now instead of jumping. Presses inside cuts
  are dropped from the plan. The cursor (position, shape, press shrink, idle fade) stays on source time, since it
  is content; the loop's glide is the last second of output. Motion blur's shutter is in output seconds, so a
  fast part blurs the cursor more.
- **Audio is never scaled in the composition.** `AVAssetReaderAudioMixOutput` (the export's audio) applies a scaled
  edit's rate change only after it has converted past it (`AppendRateChange: scheduling rate change at unscaled t=9600,
  but we previously did a conversion for t=13056`): a 1 s test recording with 0.2–0.6 s at 4× (0.7 s of output) mixed to
  0.709–0.808 s across runs with every pitch algorithm, and exported at 0.775 s. So fast parts' audio is pre-rendered
  (`SpeedAudio`) and inserted unscaled; the mix and the export now come out at exactly 0.7 s. The time-pitch keeps the
  pitch (440 Hz stays within 10 Hz) and puts a part's sound where it belongs: a tone starting 75 ms into a 4× part reaches
  half its level at 73 ms, spread over about 23 ms (60–83 ms from 2% to 80%). Measured on an M2, Debug, load average 12:
  2 min of stereo AAC renders in 1.18 s at 2×, 0.67 s at 4×, 0.43 s at 8×; a rebuild waits for new parts, once.
- A fast part shows the source frame under each output frame (every 4th at 4×), no blending. A 1× project builds
  the same composition as before.
- `ponytail:` click sounds are on the source timeline, so a fast part time-stretches them too.
- Not measured yet: the plan's extra mapping (one binary search per press, zoom and cursor sample) and the
  compositor's extra `sourceTime(atOutput:)` lookups per frame.

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
| `Editor/ViewModel/EditorViewModel+Zooming.swift` | The zooming extension (moved out of `EditorViewModel.swift`, which was at the 500-line limit); `selection` is an `EditorSelection` (a segment or a zoom), and ⌫ removes either |

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
- **Motion blur** (2026-10-08; Motion tab, `EditorProject.motionBlur`, 0 to 1, 0 = off): the shutter is
  `motionBlur / output frame rate` seconds (`RenderPlan.shutter`; 1 = open the whole frame; the export's rate comes
  through `RenderTarget.frameRate`, the preview uses the recording's). While the video's corners travel 0.5 px or more
  across the shutter, `FrameRenderer.placements(at:plan:)` returns one placement per 2 px of travel, 2 to `RenderPlan.maximumBlurSamples` (8 in exports, 2 in the preview: 8 cost 12.4–14 ms p95 at 4K mid-zoom on an M2 in Debug, 2 cost 5.6), evenly
  spaced and centred on the frame's time, and the frame is drawn at each, scaled to its share of the alpha
  (`fading(to:)`; `CIColorMatrix` on all four channels would divide the colour twice, since Core Image unpremultiplies
  first) and added (`CIAdditionCompositing`). Under 0.5 px, and with blur off, it draws once with the same graph as
  before, so frames without camera motion (the spring stops within 0.04 px of its target) are byte-identical to today's
  (tested with the buffers' bytes). The cursor blurs the same way when it moves 1 px or more on screen, including the
  camera's move: its image is placed at each sample, the samples summed, and the sum composited over the frame once.
  Measured 2026-10-08 on a MacBook Air (Mac14,2, M2), Debug, load average ~5.5 (WindowServer and two Chrome GPU
  processes), 4K frame on the default canvas with a ring and a chip, blur 1 at 60 fps, 300 renders alternating with
  blur 0 so load hits both: at the peak of a 2× zoom (8 samples) 9.5–11 ms p50 / 12.4–14 p95, against 4.2–4.5 / 5.2–6.8
  without blur; over the 1 s a zoom's frames blur (60 of 90 at 60 fps, 8 samples for the first 0.6 s) 11.0 p50 / 13.8 p95.
  Each sample costs about 0.7–0.9 ms, so **a fast 4K zoom with blur on doesn't hold the 8 ms budget** (the preview
  drops frames over that stretch; an export isn't real time); blur is off by default and costs nothing off. Fewer
  samples (4: 6.0 p50 / 9.5 p95; 2: 4.3 / 5.6) trade ghosting for time. Sharing the clamped frame between the samples
  made no difference. The cursor's blur is cheap: moving 30 px a frame with no camera motion, 3.7–3.9 ms p50 /
  5.3–5.6 p95 with 8 samples against 3.7–3.9 / 5.0–5.2 without.
- The soft-zoom hint shows when the recording has under 2 video pixels per screen point
  (`InputTelemetry.pixelsPerPoint`); telemetry doesn't record the Native Resolution setting itself.

### S1 — Editor, phase 5: cursor (`feat/editor-shell`, spec 0003)

A recording made without the cursor gets it back in the editor: drawn from its recorded images at a
smoothed position, sharp when zoomed, with its hot spot on every click highlight. The inspector's
Cursor tab (2026-10-07) holds the Cursor section (show or hide, style, size with Reset, "Always Use Pointer",
shrinking on click, hiding when idle, "Tilt While Moving", "Loop Position", "Stop Before End") and the Clicks section (effect, color, size, duration,
buttons, click sound). Movement (Mellow, Smooth, Fast, None) is in the Motion tab.

| File | Role |
|---|---|
| `Editor/Render/CursorPath.swift` | Positions without jitter, smoothed by a spring at 120 Hz and eased onto each click; the size (capture's pixels per point × style × press) and the idle fade |
| `Editor/Render/CursorShapeTrack.swift` | Shape changes without the brief ones, each image decoded once per plan; an arrow when the telemetry has none |
| `Editor/Render/Spring.swift` | The critically damped spring the camera and the cursor share |
| `Editor/Render/FrameRenderer.swift` | Draws the cursor after zooming, scaled in one step from its recorded resolution |
| `Editor/Model/CursorStyle.swift` | The inspector's settings (`Appearance`, `alwaysUsesArrow`, `loops`); `Smoothing.frequency` holds the presets' springs; `init(from:)` takes defaults for missing keys |
| `Editor/Render/OverlayImages.swift` | `whiteArrow()` and `dot()`, the cursor styles' images, drawn once per plan; `ring(diameter:color:filled:)` |
| `Editor/Model/ClickHighlightStyle.swift` | `Effect` (off, circle, ripple) with the rings' count, start size and timing; an old project's `isEnabled` decodes into it |
| `Editor/Render/ClickSound.swift`, `Service/ClickSoundWriter.swift`, `Render/ExtraAudio.swift`, `Model/BackgroundAudio.swift`, `Service/BackgroundAudioLoader.swift` | The click sound's samples, press onsets and mixing (pure); the file written from them; the extra files a composition holds (clicks, background music); the chosen music (bookmark, name, volume and mute) and its opening |
| `Editor/ViewModel/EditorViewModel+Audio.swift` | Writes the click file the first time it's wanted, deletes it on close |
| `Service/StandardCursors.swift` | `png(of:)`, shared with the recorder, and `arrowSprite`, the fallback read when the editor opens |

Key facts:
- Drawn only when `capture.cursorInVideo` is false, so the editor never draws a second cursor.
- The path passes exactly through every click and release at its time: the offset from the smoothed
  path to the click point eases in over 0.5 s before and out over 175 ms after, never past the
  neighbouring clicks, and is added at lookup, so it's exact between samples too.
- Presets are critically damped springs at 7, 12.5 and 25 rad/s, trailing a steady move by 290, 160
  and 80 ms. Smooth is Cap's default (tension 470, mass 3) without its 0.03% overshoot. A move back
  by less than 2 pt is jitter and dropped. **None** (`Smoothing.off`, `frequency` is `nil`) follows the recorded positions
  as they are: no spring and no jitter filter, each position held until the next (sampled at 120 Hz like the others);
  clicks and the loop's glide still ease on.
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
- **Styles** (`CursorStyle.appearance`): macOS (the recorded images; "Always Use Pointer" draws the recorded arrow, or the
  system's `arrowSprite`, in place of every shape), White (the macOS arrow outline in white with a 1.25 pt black
  stroke and a soft shadow, hot spot on the tip) and Dot (a 16 pt translucent grey disc with a white edge, hot spot
  at the centre). White and Dot are drawn once per plan at 8 pixels per point, so they stay sharp at the 10× zoom
  the recorded arrow is sized for; `style.size` scales them like any cursor. HDR plans convert them with
  `encoded(in:)` like the recorded ones.
- **Loop Position** (`CursorStyle.loops`): over the last second of output (less when the last kept range is shorter: the
  glide stays inside it) the path eases onto where the first frame has the cursor, so the last frame's position equals
  the first's exactly (`CursorPath.Loop`, `RenderPlan.cursorLoop(for:)`; the target is the path without the glide,
  so it is set last in the init). Only the position loops: the cursor's size, shape and idle fade don't.
- **Stop Before End** (`CursorStyle.stopDuration`, 0–3 s of output, 0 off; N2): from `RenderPlan.cursorStop(before:for:)`, that
  long before the last frame, `CursorPath` clamps the time its position, size and opacity are read at, so the reach for
  Stop doesn't show. With Loop Position on too, the cursor holds still and then glides back in the last second.
- **Tilt While Moving** (`CursorStyle.tilts`; N2): the arrow leans against its horizontal motion, clockwise moving right,
  up to `CursorPath.maximumTilt` (12°), 76% of it (tanh 1) at `tiltSpeed` (800 pt/s), eased by the Smooth spring
  (12.5 rad/s); computed once per plan at 120 Hz from the finished path, so it straightens at rest, at the stop and into
  the loop's glide. `FrameRenderer` rotates the image about its hot spot (a 0 angle is the identity, so frames without
  it are unchanged). Picked 2026-10-08, not yet checked by eye.
- **Copy Frame** (transport, ⇧⌘C; N10): the frame at the playhead as a PNG at Original export size in SDR, on the
  pasteboard (`EditorViewModel.copyFrame()`): an export-target plan in the composition, one frame read by
  `FrameGrabber` (`AVAssetImageGenerator`, zero tolerance), `ScreenshotService.pngData`, `ImagePasteboard`. A check
  shows on the button for 1.5 s.
- **Click effects** (`ClickHighlightStyle.effect`): None; Circle, the old ring (faint fill, grows from 40%); Ripple, two
  unfilled rings that grow from 20% with the same cubic ease-out, each fading as it grows, each lasting 70% of the
  duration, the second starting 30% after the first, so the effect ends with the duration and
  `ClickMarker.active` is unchanged. One ring image per plan either way. Measured on an M2 (Mac14,2), Debug, load average
  5.5, a 3840×2160 frame on the default canvas (3572×2160), three clicks 0.1 s apart all showing, 300 frames each:
  no effect 2.6 ms p50 / 3.4 ms p95, Circle (3 rings) 3.6 / 4.1, Ripple (6 rings) 3.8 / 4.2.
- **Click sound** (`AudioMixSettings.clickVolume`, 0 is off, Clicks section): a synthesised 20 ms click (2.4 kHz body, 5.2 kHz
  edge, chosen on 2026-10-07, not yet checked by ear; no licensed asset) at every press of every button, on the source timeline.
  Written once per editor window as Apple Lossless CAF (48 kHz mono, a second of samples at a time) in
  `temporaryDirectory/Reco Click Sounds/<UUID>.caf` the first time the volume is above 0, inserted per kept range
  like the recording's tracks (so cuts leave out the clicks inside them) as a track above the recording's IDs and mixed
  at the volume with the same 25 ms cut fades; deleted when the window closes. Lowering the volume to 0 only changes
  the mix: the file and the player item stay. Exports read every audio track through the mix, so they include it
  (and `ExportSession` counts it for the size estimate). ALAC keeps each onset to the sample (the first non-zero sample
  is the onset or the one after it, since the click starts at a zero crossing); AAC would shift it by its priming.
  Measured on an M2, Debug: 10 minutes with 3,000 presses writes in 0.97 s to 3.3 MB (the silent 10 minutes alone: 146 KB).
- **Background audio** (`AudioMixSettings.background`, Audio tab → Background Audio, 2026-10-08): one chosen audio file, kept as a
  security-scoped bookmark (`BackgroundImageLoader.bookmark(for:)`) with its name, volume (30% when added) and mute; replacing it
  keeps the volume. Looped (`CompositionBuilder.loopRanges`, in `CMTime` so the copies meet exactly) at output times from 0 to
  exactly the video's end, never longer, since the compositor draws black past the video's last frame. It runs through cuts (no
  cut fades) and fades in over 1 s and out over 2 s, each at most a quarter of the output (`backgroundFades`, picked by
  ear). Its own track above the click sounds' (`extraTrackID(2, …)`), so exports include it like the clicks. The file is opened
  once per bookmark (`EditorViewModel.backgroundAudio`, access kept on while the window is open and ended when it closes or
  the file is replaced); adding, removing or changing it makes a new player item (`needsNewAudioFiles`), volume and mute only
  the mix. An unreadable file shows `unreadableBackgroundAudio` and is left out. The Audio tab is always available (a silent
  recording can get music); the per-track section shows only when the recording has tracks. No music is bundled (licensing).
  `ponytail:` a file that doesn't loop cleanly clicks at the seam; a crossfade needs two alternating tracks.
- A track holds its asset weakly: inserting from a click file whose `AVURLAsset` was already released failed with -12780, so
  `CompositionBuilder` keeps it alive (`withExtendedLifetime`) until the insert is done.
- Projects saved before these settings decode with defaults (`init(from:)` in extensions, like `EditorProject`): the
  synthesised `Decodable` throws on a missing key.

### S1 — Editor, phase 6: canvas and export polish (`feat/editor-shell`, spec 0003)

The recording sits on a canvas: a shape (original, 16:9, 9:16, 1:1, 4:3), a gradient, color,
picture or transparent background, padding, rounded corners, a shadow and a border. The Background tab offers ten gradient
presets, the system's wallpapers and a blur for pictures. New projects get the styled default. Export picks a format (MP4, ProRes, GIF), size, frame rate and quality, and ProRes becomes 4444, which keeps a
transparent background; HDR recordings stay HDR in MP4 and ProRes. The Library (S7) lists
the recordings with pictures; a click opens one in the editor.

| File | Role |
|---|---|
| `Editor/Model/CanvasStyle.swift`, `GradientPreset.swift` | The inspector's canvas settings (gradient colors, picture blur, border); `plain` is the recording as it is; `init(from:)` in an extension reads projects saved before the blur and border. A preset is stored as its two colors, so `gradientPreset` finds which one the colors are (Slate, the default, first) |
| `Editor/Render/CanvasLayout.swift` | Output size, the video's frame and rounded mask, the backdrop (background with its blur, the border and the shadow) drawn once into an IOSurface, and the regions frames are drawn in |
| `Editor/Render/FrameRenderer.swift` | `draw(_:at:plan:into:context:)`: the frame region by region, for the compositor and the tests alike |
| `Editor/Render/RenderResources.swift`, `RenderTarget.swift` | What plans draw with from the system (key labels, arrow, background picture); what a plan is for (the preview, or an export's size and dynamic range) |
| `Editor/Render/HDREditorCompositor.swift`, `Editor/Model/DynamicRange.swift` | 10-bit or half-float frames in, half-float out; SDR, PQ or HLG from the track's transfer function |
| `Editor/Service/BackgroundImageLoader.swift` | Security-scoped bookmark to the chosen picture, read upright, in sRGB, at most 4096 px; returns the file it resolved to, so the inspector can ring the chosen wallpaper |
| `Editor/Service/SystemWallpaper.swift` | The 13 desktop pictures macOS has on disk, with their thumbnails, listed off the main actor; chosen like any picture, through `setBackgroundImage` |
| `Editor/View/SwatchGrid.swift`, `BackgroundFillControls.swift` | Five-column grid of 16:10 swatches with an accent ring on the chosen one (gradient presets, wallpapers); what each background kind is made of (presets and colors, color, wallpapers + Choose Image… + Blur) |
| `Editor/ViewModel/EditorViewModel+Background.swift` | `applyGradient` (both colors, one undo step), `updateBackgroundImage(for:)` (the one place the picture is read, for load and every rebuild), the wallpaper list |
| `Editor/Model/ExportSettings.swift`, `Editor/View/ExportOptions.swift` | Format, quality, size (a shorter side: 720, 1080, 2160, only those under the canvas's) and frame rate (15, 30, 60, not above the recording's; a GIF's at most 30: 60 fps delays are 1 or 2 cs, which browsers slow to 10 cs); the quality's estimated sizes |

Key facts:
- The canvas keeps the video's shorter side (9:16 from 4K is 2160×3840), and padding (8%), corner
  radius (1.5%), the shadow's blur (3%), the border (up to 2%) and the picture's blur (up to 3%) are shares of it. An export at another size is drawn at
  that size, not scaled afterwards. Zoom and canvas placement are one transform, so the video is
  resampled once; the cursor is drawn at its final scale.
- Exporting at the original size uses `CanvasLayout.nativeShorterSide`: a canvas just big enough that the
  unzoomed video keeps its own pixels inside the padding (the preview keeps the video's shorter side, for
  its frame budget). Exports shrink frames with `highQualityDownsample` (`RenderPlan.downsamplesSmoothly`);
  linear sampling blurred a Retina recording's text at 1080p. Its export cost isn't measured yet.
- Wallpapers (measured on macOS 27.0.1, M2): `/System/Library/Desktop Pictures` has 63 `.madesktop` plists, which are
  MobileAsset references downloaded on demand (`/System/Library/AssetsV2/com_apple_MobileAsset_DesktopPicture/` held only
  the catalog: none were on disk), 13 full-size `.heic` files of 6016×6016 px and 8.7–25 MB (iMac in 7 colors, Mac in 4,
  Radial Sky Blue, Sonoma) and `.thumbnails/` with 138 HEICs of 214×130 px. Only the 13 are offered: a thumbnail stretched
  to a 2160 px canvas would be 16.6× enlarged, so thumbnails are tiles only. Solid Colors (128×128 PNGs) duplicate the Color
  background, the aerials and Sonoma videos are video, and `.wallpapers/Sonoma Horizon.heic` (3840×2160) is skipped.
  A picked one is read once, off the main actor, at the 4096 px cap (`sips -Z 4096` took 0.49 s with re-encoding; 64 MB held).
  `ponytail:` downloaded `.madesktop` assets aren't offered.
- Blur (`CanvasStyle.backgroundBlur`, picture backgrounds only): sigma up to 3% of the frame's shorter side
  (`CanvasLayout.maximumBackgroundBlur`), applied after the picture is placed: clamped to its extent so the edges stay
  opaque, blurred, cropped to the frame. Part of the backdrop, so once per plan. Measured on an M2, Debug, load average 3–6,
  3840×2160 video with a 4096×4096 picture, 30 builds: backdrop 8.5 ms p50 / 8.9 p95 sharp (56 ms the first time), 15.2 / 15.7
  blurred (16 / 28 in a busier run). Slider drags rebuild the plan, so that is per drag step, never per frame.
- Border (`borderWidth` 0–2% of the shorter side, any opaque color): drawn outward from the video into the backdrop, a rounded
  rectangle of the video's frame grown by the width with radius = corner radius + width (concentric; square stays square),
  under the video, so its color shows around the rounded corners. The shadow is cast by video and border together. Width is
  whole pixels, capped by the gap to the canvas edge (`CanvasLayout.borderWidth(_:around:)`), so with no padding there is no
  border and the slider is disabled. Nothing per frame; the video's frame, transform and native size don't change. An inset
  border was left out: it looks like a border with less padding and would resample the video.
- With padding, Original grows by it (`CanvasLayout.paddedRatio`), so the padding is equal on every side; a
  fixed shape whose ratio differs from the video's puts the rest on one axis.
- Frames are drawn region by region (`CanvasLayout.regions`): the padding from the backdrop alone,
  the video in 8 bands, its rounded corners with the mask. Core Image evaluates every overlay
  across the whole region it renders; in bands it skips them where they aren't. Measured on an M1,
  Debug, 4K with a ring and a chip, load average 4–6: 3 ms p50 plain (7 drawn whole), 3.7–5 ms on
  the default canvas (9 whole), p95 under 7.5 ms. The backdrop takes 4 ms to draw (17 the first time).
- A transparent background keeps its alpha only in ProRes 4444 (the ProRes tab's 4444 when the canvas is transparent); other formats export it black.
- HDR frames are drawn without color management too: the plan draws its overlays once in the
  recording's encoding (`OverlayImages.encoded`), SDR white at 203 nits (BT.2408). Their
  semi-transparent parts (the chip's backing, the cursor's shadow, a fading ring) blend in PQ's
  encoding, so over HDR they look a little darker than in SDR. Measured on an M1, Debug, 4K with a
  ring and a chip, load average 2–3: 4–4.6 ms p50 and 5–8 ms p95, against 6.7–8.1 and 10–13 with
  a color-managed context; SDR took 3–3.5 in the same runs. Converting the backdrop costs 9–11 ms
  more per HDR plan (20 the first time), alongside the camera and cursor. The composition is
  tagged BT.2020 and the recording's PQ or HLG; GIF exports are SDR.

### S1 — Editor design (`feat/editor-shell`)

The editor, Library and Web Recording windows use the system's colors, so they follow the user's appearance (light
or dark) and accent color: the window background (80%) the desktop frosts through, text in the label
tones (ink, dim, faint), separators instead of boxes, and the accent
(`EditorTheme.accent`, `Color.accentColor`; the asset catalog's AccentColor is empty) for the Export button, the playhead,
the selection and the sliders' fill. No panel forces an appearance (a dark-only studio look was considered from the
Pinterest moodboard on 2026-10-05 and turned down). The preview sits on a faint dot grid; the inspector (toolbar toggle) holds every
setting on the right, and the transport (cut, zoom, ⌫; frame steps and play; the time) sits in the timeline's header,
without glass. A chip row under the preview in place of the inspector was tried on 2026-10-05 and turned down: the
settings stay visible in the column. Nothing else is colored: clicks, keys and zooms are greys, and the default canvas is a
slate gradient.

| File | Role |
|---|---|
| `Editor/View/EditorTheme.swift` | System colors by role, spacing on a 4-point grid, and the motion tokens: `motion` (spring, response 0.35, critically damped: every state change), `quickMotion` (0.15: hover, release), `momentumMotion` (damping 0.8: only after a flick), `fadeMotion` (Reduce Motion's cross-fade) and `release(velocity:distance:)` (a drag's release speed handed to a spring) |
| `Editor/View/View+EditorGlass.swift`, `EditorGlassGroup.swift` | Liquid Glass on macOS 26 (`glassEffect`, `GlassEffectContainer`), a material with a hairline before; `editorWindowBackground()`; `editorMotion(value:)` animates unless Reduce Motion is on (`nil` skips it); `withMotion { }` is the same for code with no environment; Increase Contrast adds a `dim` edge to every glass surface |
| `Editor/View/EditorBackdrop.swift`, `StageDotGrid.swift` | The frosted desktop behind the window; the dot grid behind the preview, fading out before the stage's edges |
| `Editor/View/EditorButtonStyle.swift` | The two text buttons, Liquid Glass capsules (`glassEffect(_:in: .capsule)`, interactive): `.editorPrimary`, glass tinted with the accent colour and white text, only for the one action a place leads to (Export…, export's Export and then Share…, Render, the card's Copy and Save); `.editorSecondary`, clear glass with accent text and its icon white on a 20 pt accent disc, for every other text button. Icons come from the button's `Label(_:image:)`: `Assets.xcassets/ButtonIcons`, Phosphor Bold (MIT) from Iconify as 14 pt template PNGs (`button-export`, `-share`, `-folder`, `-close`, `-retry`, `-agent`, `-settings`, `-render`). Solid with Reduce Transparency, a material before macOS 26, an edge with Increase Contrast; the press scales to 0.97 on the frame it lands, only hover and release ease |
| `View/PanelPresentation.swift`, `PanelPresence.swift` | `panelPresentation(isPresented:anchor:motion:blur:)`: a floating panel fades and, with `blur`, pops in where it is from that many points out of focus — no direction, where a scale has one, since the corner furthest from the anchor travels the most and the eye reads the panel as growing from that corner (the capture toolbar and its picker use `blur`; the card, pins, agent bar and countdown use the scale). Only opacity, blur and scale are animated, so a window resize in the same update isn't. Opacity only with Reduce Motion; `exitDelay` is how long its window stays; `PanelPresence` carries the flag for controllers whose view model can't |
| `View/MenuRowButtonStyle.swift` | `.menuRow` for the popover's rows, and `MenuRowHighlight`: Control Center's highlight (not on `MenuBarToggle` rows, whose switch is the only control), a 10 pt continuous rounded fill the row's full height, 6 pt in from the sides, 0.1 on hover, 0.16 the moment it's pressed, dimmed when disabled |
| `Model/GesturePhysics.swift` | Pure: `project` (momentum), `rubberband`/`rubberbanded` (resistance past a boundary), `relativeVelocity`, `velocityMatchedDuration`, `flickExit`, and `VelocityTracker` (the last 0.1 s of a drag) |
| `Editor/View/EditorWindowManager.swift` | `makeWindow`: content under a transparent title bar, centred, never larger than the screen less 40 pt; the editor and Web Recording open at 1533×943 (the size picked by hand on 2026-10-05) |
| `Editor/View/EditorStage.swift`, `TransportBar.swift`, `EditorIconButtonStyle.swift` | The preview in the canvas's shape with a checkerboard behind transparent canvases; the transport in the timeline's header |
| `Editor/View/TimelineRuler.swift`, `Playhead.swift`, `ZoomBlock.swift` | The ruler (the finest scale whose labels stay 72 pt apart; a line at each label, dots between; labels carry their units, "0.5s", "1m 30s", "1h", since a clock's "0:00.5" didn't say what it counted), the playhead's knob, the zoom blocks |
| `Editor/Model/InspectorTab.swift`, `Editor/View/InspectorTabBar.swift` | The inspector's tabs (2026-10-07): Background · Camera ‖ Audio ‖ Cursor · Keyboard ‖ Captions ‖ Motion, as icons on one capsule track with a line between groups and a sliding fill; only the chosen tab's sections show (Background's one untitled section: aspect, background, padding, corners, shadow, border; Audio; Cursor and Clicks; Keystrokes; Zoom). Camera and Captions stay disabled until the camera is its own track and a transcript exists (spec 0004, N19, N5); Audio is always available. The tab is `EditorView` state, so it survives export; selecting a zoom turns to Motion. Motion holds the zoom's and the cursor's movement (Mellow, Smooth, Fast; the cursor's also None) and Motion Blur (a slider, Off at 0): `ZoomMotion` sets the camera spring at 6, 10 or 16 rad/s (96% of a move in 0.83, 0.5 or 0.31 s), saved in the project as `zoomMotion`, blur as `motionBlur` |
| `Editor/View/Inspector*.swift`, `EditorInspectorSections.swift`, `TickSlider.swift`, `TilePicker.swift`, `CanvasInspectorSection.swift` | `EditorInspector` and its sections, which fold away under a dim title (Background's has none, so it never folds), `SwatchGrid` (preset and wallpaper tiles, the chosen one ringed in the accent colour), sliders with their values, switches, and tiles whose highlight slides. Every slider is a `TickSlider`: a track with ticks, accent fill up to a bar at the value, dragged 1:1 from the grab (a press away from the bar takes it there first), VoiceOver adjustable in 20 steps, without a focus ring |
| `Editor/View/ExportOptions.swift`, `ExportProgressBar.swift` | Export's inspector: format, size and frame rate as `SegmentedChoice` tabs (an option can be disabled), the quality as rows with their estimated sizes, Export and Copy to Clipboard (side by side, or stacked when the column is narrow) pinned under a line; progress |

Key facts:
- Glass only on controls over the stage, never on the timeline (content) or over the live video:
  each glass shape costs a sampling pass on the GPU the compositor also uses.
- **Glass animates itself unless told not to.** `glassEffect` grows its shape as it appears (Apple's
  own transition, `GlassEffectTransition` in SwiftUICore with `.matchedGeometry`, `.materialize` and
  `.identity`), so a surface with its own entrance gets a *second* motion on top — for the capture
  toolbar's pills that read as the controls sliding in diagonally, whatever the panel's own animation
  did. Every `captureToolbarPill` therefore sets `.glassEffectTransition(.identity)` and leaves the
  entrance to its caller (the bar's blur pop-in, the countdown disc's settle).
- The inspectors keep the system `.inspector`, which macOS 26 draws as glass, so it has no background.
- Text is ink by default, so it doesn't dim when disabled: `InspectorSection` fades disabled content.
- Editor windows take their minimum size from SwiftUI (`sizingOptions = .minSize`), so anything laid out in points of
  a measured width (filmstrip tiles, lane blocks) sits in a `frame(minWidth: 0, …)`: without it the timeline's last
  width became the window's minimum and every inspector toggle grew the window past the screen. The other way round,
  SwiftUI also fits the window down to the root's largest size as it lays out (`NSHostingView.updateAnimatedWindowSize`,
  even with `sizingOptions = []`): the editor's root, the "Opening…" spinner in a frame with only a minimum, had a
  largest size of 900×560, so every editor opened at 900×592. Roots fill the window (`maxWidth/maxHeight: .infinity`).
- **macOS's purple sharing pill** replaces a window's traffic lights while a stream targets it, and is drawn into the
  frames. Measured 2026-10-05 (macOS 27) by streaming a real window: `desktopIndependentWindow`, an app filter and
  `display(including: [window])` all show it; the whole display, or the display excluding every other window,
  doesn't. ScreenCaptureKit has no setting for it. Window recordings (`desktopIndependentWindow`) have it today.
- Avoid what reads as generated: no gradients or glows in the chrome, no second accent, no cards
  and badges where a native control works, no all-caps titles, hover as a fill step (no lifts or
  scaling).
- Two visual families, one motion system: the system-native popover and Settings, and this studio
  look (editor, Recordings, Web Recording, the agent bar and the floating capture panels: Quick Access card,
  pins, capture toolbar and its picker, countdown). These share the toolbar's dark glass and the system
  accent colour for what is chosen or the action; a take in progress is red.
- Motion follows the apple-design skill: respond on press, move 1:1 from the grab point, springs that start
  from the current value, bounce only after a flick, symmetric enter and exit from the source. Timeline
  clip and trim-handle drags resist past the ends (`rubberbanded`) and release into `release(velocity:distance:)`,
  so what the timeline refuses springs home from where it was shown; the zoom focus pad keeps the offset
  from where its outline was grabbed.
- Area selection fades its dim in over 0.12 s on the first drag (instant with Reduce Motion), and its
  Confirm and Cancel are system buttons (glass on macOS 26, Confirm tinted with the accent colour) with Return
  and Esc as key equivalents.
- Skipped on purpose: Settings, the menu bar label, the export sheet, momentum on timeline edits, rubber-banding
  area selection, pin flick, scrubbing.
- Clips in a lane (`TimelineLane`: zooms, web cursor and scroll clips) are window-coloured chips on a hairline and
  show their trim handles only when hovered, selected or dragged (`TrimHandle.isShown`): on a 1 s clip two
  always-on 8 pt handles hid the clip. The Web Recording timeline has no grey band behind it.
- Optional bindings use `Binding(unwrapping:)` (`View/Binding+Unwrapping.swift`), never `Binding($optional)`: views
  under an `if let` read the binding once more after a selected clip or zoom is deleted, and `Binding(_:)`'s
  force-unwrap crashed the app (three crashes on 2026-10-02, one mid agent run).
- `ImageRenderer` can't draw glass content, AppKit controls, `ScrollView`s or the player, and
  `screencapture`/`cacheDisplay` need permission or miss SwiftUI; check the look in the app.

### C1 — Screenshots

Menu bar **Capture Area / Capture Window / Capture Screen** and global shortcuts of the same names
(Settings → Shortcuts → Screenshots, ⌘1 / ⌘2 / ⌘3) and `reco://capture-area`, `capture-window`, `capture-screen` (N16); **Capture Previous Area** (N16, a shortcut with no default and `reco://capture-previous-area`) shoots the last area captured since launch again on its display, live and without selecting (Capture Area when there is none; `selectedDisplayDisconnected` when its display is gone). All four links take `?then=copy|save|pin` in place of the card (`ScreenshotFollowUp`, `QuickAccessController.follow`: a card showing stays; a failed copy or save opens the card; an area pins where it was taken, anything else in the card's corner; the shot becomes the one Restore Last Screenshot brings back). Defaults are ⌘1–⌘7: capture area, window, screen, select content, select area, toggle and pause recording (`KeyboardShortcutNames.swift`); global, so they take ⌘1–⌘7 from every app until changed. The popover shows each row's shortcut dimmed (`MenuBarActionButton.shortcut`). Both follow `canCapture(alongside:)`: idle only,
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
Captures at native pixels exactly what is on screen (Reco's windows and menus, wallpaper, Dock and menu bar included; the popover, `MenuBarExtraWindow`, too when the shortcut is used; left out only when the capture starts from it, so no wait for its fade) into memory (`Screenshot`: image, scale,
capture time) and hands it to `ScreenshotController.onDidCapture` (the Quick Access card, C2). Nothing is
written to the screenshot folder until the card's **Save**: `ScreenshotController.save(_:)` writes
`Reco_Screenshot_<capture time>.png` into `SettingsStore.screenshotDirectory`: the Desktop unless the user picks
another folder in **Settings → General → Output Location → Screenshots** (a plain path; unsandboxed, no bookmark).
macOS asks once for Desktop access the first time a screenshot is saved there.

**History** (spec 0012): every capture is also written, in the background (the card doesn't wait), to
`URL.recoSupport/Screenshots/` under the same name. Save deletes that copy (after awaiting its write, if still
running), so nothing is stored or listed twice; Copy, Pin, Recognize Text and Close leave it. **Settings → General →
Screenshot History**: Keep Screenshots Off / 1 Week / 1 Month (default) / 3 Months, and Clear History…. Expired
files (creation date older than the retention; Off expires all) are deleted with `removeItem`, not trashed, to free
space: at launch and after each history write, by `ScreenshotHistory.isExpired`, the one rule. The screenshot folder
is never pruned.

| File | Role |
|---|---|
| `Screenshot/Model/Screenshot.swift` | The captured `CGImage`, its scale and capture time; `filename`, `pointSize` |
| `Screenshot/ViewModel/ScreenshotController.swift` | Owned by `AppDelegate` (which registers the shortcuts); permission check, selection, `isCapturing`, `canCapture`, `onWillCapture`/`onDidCapture`, `save(_:)` with the failure notification |
| `Screenshot/Service/ScreenshotService.swift` | Display lookup, `SCScreenshotManager.captureImage`, save into the folder it's given, PNG via ImageIO (`@concurrent`) |
| `Screenshot/Service/WindowPicker.swift` | System `SCContentSharingPicker` in `.window` mode, observed only while picking |
| `Service/SCContentFilter+CaptureScale.swift` | Window-scale fix shared with recording (moved from `RecorderViewModel`) |
| `Screenshot/Service/ScreenshotHistory.swift` | `nonisolated` history folder, `isExpired` (pure), `prune`/`clear`/`remove` (`@concurrent`, folder as a parameter for tests) |
| `Model/ScreenshotHistoryRetention.swift`, `Model/SettingsStore+ScreenshotHistory.swift` | The setting (an extension: `SettingsStore.swift` is over the file length limit) |

Key facts:
- Shared with recording: `CaptureSizeCalculator.sourceRect` (area → display rect), `filter.captureScale`,
  `SettingsStore.filename(prefix:fileExtension:date:)`, `ContentFilterService.applySettings`.
- `SCContentSharingPicker.shared` reports results to every observer. `CaptureEngine.isPickingContent`
  makes the recording selection ignore picks it didn't ask for.
- Cursor follows `showCursor`, not `capturesCursor`: there's no editor to redraw it.
- Window shots use the window recording config: SCK fits window + shadow into the window's frame, so
  shadow padding is uneven (same as recordings).
- Verified on an M2 (1710×1112 pt, 2×): screen 3420×2224, window and area at 2×, sRGB, no Reco UI.

### S2 — Web recordings (`feat/web-recordings`, spec 0005)

**New Web Recording…** in the menu bar (and the Library's New) opens a window with a blank script (`startNew()`,
one undoable step, so ⌘Z brings the last back) and a live web page at a viewport preset, a
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
  hit-tested; the page sees `buttons: 0` and no press. Clicks are real mouse downs and ups. A move is
  sent only when the cursor moves, so what scrolls under a resting cursor (a sticky nav's menu) doesn't
  react (a nav menu opened mid-take on buildonto.dev); the preview's Play sends the same moves and presses.
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
- **Requests:** a frame waits off the clock for the page's `fetch`/`XMLHttpRequest` calls and the bodies it reads
  (`answerRequests` in `WebClockScript`), so a slow API's answer shows at once instead of the take running a step
  ahead; 5 s at most, then those are forgotten (long polls, streams). Websockets and server-sent events aren't
  counted. A 3 s apple.com take took 10.6–10.8 s with it, 10.3–10.9 s without.
- **Loading:** a frame waits up to 5 s for images in view and fonts; what misses that isn't waited
  for again (a hung image cost one frame 5 s, not every frame). The first load waits for the page's
  `didFinish`, so a subresource that hangs from the start fails the take after a minute.
- **Speed:** snapshots are painted on the CPU: 2880×1800 took 14 ms (simple page), 35 ms
  (apple.com) and 310 ms (linear.app; 64 ms at 1×). A 3 s apple.com take rendered in 8.5 s.
  Measured again 2026-10-06 (apple.com 2×, per frame): snapshot 11–14 ms, append 2 ms; the frame step
  waited 7 ms for a real animation frame (`settle`), now dropped since the snapshot forces a rendering
  update anyway, and frames came out pixel-identical. A first render also waits for the page's images
  (`loadInView`): 37 ms a frame cold against 1 ms warm.
- The take and the preview share the default website data store, so a cookie banner dismissed in
  the preview stays dismissed in the take.
- App Transport Security blocks plain `http://` pages (measured on neverssl.com); `http://localhost` loads.

### S3 — Agent Bridge (`feat/agent-bridge`, spec 0006)

Coding agents (Claude Code, Codex, OpenCode, Cursor, Gemini CLI, Claude Desktop, Grok Build) record a
web page from its address. **Settings → Agents** finds the installed ones and adds a server named `reco` to
each one's own settings, only when the user clicks Connect (it writes the bridge token there). The agent then calls three MCP tools: `inspect_page` (selectors and boxes of a
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

The agent is part of the one Web Recording window (**New Web Recording…**, and the Library's New): its **AI Agent** button
at the toolbar's leading edge opens the chat panel on the left. The shortcut **Record with AI Agent** (Settings → Shortcuts →
Web Recording, no default) and the failure notification's action open the same window with the panel open
(`EditorWindowManager.showAgentChat()`, S5); the menu bar and the Library have no row of their own. The Spotlight-style bar it used to open was removed on 2026-10-02. Reco runs the agent's command line headlessly with only its own
three MCP tools allowed; the agent records through the bridge (S3) and the editor opens. While it
runs the bar and the menu bar (a sparkle, "AI", then the render's percent) show it; **Cancel** stops
the command line. A failure shows its reason with **Retry** in the bar and in a notification.

| File | Role |
|---|---|
| `AgentRecording/Model/AgentRecordingRequest.swift`, `AgentInvocation.swift` | Pure: the prompt; every agent's exact arguments, environment and support files (`make(for:in:)`, the one place that knows the flags) |
| `AgentRecording/Model/AgentModelCatalog.swift`, `AgentRunOutcome.swift`, `OutputTail.swift`, `LoginEnvironment.swift` | Pure: model lists; process end + render → outcome; the last 16 KB and the reason shown; login shell environment parsing and `PATH` lookup |
| `AgentRecording/Service/AgentProcess.swift` | `Process` with pipes, time limit, cancel (SIGTERM, SIGKILL after 3 s); `loginEnvironment()` |
| `AgentRecording/ViewModel/AgentRecordingViewModel.swift` | Fields, remembered agent and model, `refreshAgents()`, `run`/`retry`/`cancel`, `menuBarText`; watches `AgentTools.job` |
| `AgentRecording/View/AgentRecordingFailure.swift` | The failure row, in the chat |
| `Service/ContainerMigration.swift`, `Service/URL+RecoPaths.swift` | One-time move from the old sandbox container; `userHome` and `recoSupport` |
| `Service/NotificationService.swift` | `AGENT_RECORDING_FAILED` category with Retry |
| `RecoApp.swift` (`MenuBarLabel`) | `fixedWidthImage(_:reference:symbol:)`, shared by the timer and the agent state |

Key facts:
- Commands run with the user's **login shell environment** (`$SHELL -l -i -c "printf marker; env -0"`, 10 s,
  read again each time the bar opens; 0.86 s here), never through a shell string; binaries are found on
  that `PATH`. Claude Desktop has no command line and isn't offered.
- Claude Code and Cursor get Reco's server with each run (`--mcp-config reco-mcp.json --strict-mcp-config`, and
  the workspace `.cursor/mcp.json`), so they record before Settings → Agents has connected them; the other agents
  need that setup first. Claude without it ran with no Reco tools and ended "without a render".
- The bar lists every agent whose command line is on the login shell's `PATH` (`refreshAgents`), ready when
  `AgentInvocation.bringsServer(for:)` or connected; otherwise it says which to connect. Antigravity (`agy`) is left
  out: its headless mode has no per-run tool allowlist, only `--dangerously-skip-permissions` (checked 2026-10-02).
- Only Reco's tools run: Claude `--tools WebSearch,WebFetch --allowedTools mcp__reco__* WebSearch WebFetch` (read-only web
  research, spec 0009), Codex `approve` mode and a
  read-only sandbox, OpenCode inline permission config, Gemini policy file, Grok `dontAsk` (its read-only
  built-ins remain), Cursor workspace `cli.json`. Codex wasn't run (not installed).
- The run's limit is **15 minutes** (a 30 s apple.com take at 2x is 1–2 minutes; linear.app needs 18 for 60 s).
  After the agent exits its render is waited for.
- Outcome rules (in order): cancelled; a new render `done` is a success even after a bad exit; time-out;
  launch failure; non-zero exit with the last output lines; zero exit with a failed render; zero exit
  without a render. The bridge token is replaced by "…" in any reason.
- "Set Up Agents…" sends `showSettingsWindow:` (`openSettings` belongs to a scene) after writing the
  Agents tab to the `settingsTab` default.
- The panel's motion follows the apple-design skill: one `isPresented` flag drives a bounce-free spring,
  so closing and reopening mid-animation retargets; Reduce Motion cross-fades, Reduce Transparency is solid.

### S5 — Agent chat (`feat/ui-polish`, spec 0008)

The Web Recording window is laid out like the editor: the **inspector** on the right (system `.inspector`, 340 pt,
`showsInspector`), and the **Agent** chat on the left (340 pt and a hairline, `showsAgent`, hidden by default), which the toolbar's
**AI Agent** button at the leading edge slides in and out from the leading edge: a chat with Claude Code or Cursor about the window's page. Their `stream-json`
output (`AgentStreamEvent`, measured formats) fills `AgentRecordingViewModel.transcript` with requests,
replies and tool steps; a follow-up resumes the conversation (`--resume`). Reco's tools report what the
agent inspects and plans (`AgentTools.onInspected`/`onPlanned`), so the preview highlights its elements,
and its plan becomes the timeline as one undoable step and plays once in real time. When the run succeeds
with its plan staged (`AgentRecordingViewModel.onPlanStaged`), the window renders it and the movie opens in the
editor; the clips stay for the user to change and render again. **Play** (Space) in the timeline header plays any script in the page: the playhead moves
in real time, and a page move is skipped while the last is still busy, so it never queues up. Render progress
sits in the timeline header, not over the page. The header is laid out like the editor's transport: icon buttons
that add a hover, click, typing or scroll (and delete the selected clip) on the left, Play in the middle, progress and
the time on the right; Render is the accent button, like Export. The stage has no dot grid, only an edge and a soft shadow. Details and file map: `docs/specs/0008-agent-chat.md`.

- **The chat's look** (iMessage-like): a header with the agent and model menus; the agent's words in light rounded
  bubbles on the left, the user's in accent bubbles on the right, consecutive tool steps as one activity card
  (`AgentTranscript.groups`), a typing indicator until the render starts and then a progress card, and a result card
  once a run has a movie (`AgentRecordingViewModel.lastMovie`: the agent's own render, or the window's from its
  staged plan) that opens it in the editor. The composer is a pill field with a round Send (Stop while running), under it
  a round New Chat button and suggestion chips that fill the field without sending. Bubbles enter with a spring from
  their own bottom corner (opacity only with Reduce Motion).
- **Tests and a running Reco:** the test host is Reco, so a test run takes the bridge's socket from the
  running app. An agent run going at the time loses Reco, and its `--mcp` client starts a second copy.
  Don't run tests during an agent run; relaunch Reco after testing. `AgentToolsTests` render into a
  temporary folder (they used to fill `~/Movies/Reco` with 1 s movies).
- `aPageThatCantBeLoadedFailsTheRenderWithAReason` and `aFailedRenderDoesntBlockTheNextOne` fail on this
  Mac (macOS 26.6) with or without the chat changes: rendering `http://localhost:1` succeeds instead of
  failing. Not yet looked into.

### S6 — Walkthrough editor (`feat/ui-polish`, `feat/walkthrough-show`, spec 0009)

Effects are properties of a web script's steps, previewed with Play and rendered by the editor.
- **Show:** `PointerClip.show` (`record_page` `steps[].show`) names what the video zooms on during a step,
  measured where the step starts and fitted by `WebCamera.fit` (≤ 3×, 80% of the view, none under 1.1×). Once
  any clip shows one, only show clips zoom, and the take always writes `<movie>.edit.json`. A zoom ends 0.3 s
  after the page scrolls or is replaced and isn't made when that comes within 0.5 s (`PageChanges`, also used
  by web takes' auto-zooms); zooms under 1 s apart pan across.
- **Takes:** before each cursor step Reco scrolls its element into view (≤ 1 s, 15% from the edge); scrolls to
  an element aim as they start; a page a click opens shows from its top (URLs compared without fragment) and
  is recorded in telemetry `navigations`. Each step is checked where it starts (`WebTakeIssues`): missing,
  outside the view, covered, a click left out, a shown element out of view; `record_page` returns them as
  `warnings`, and a run Reco started may call it twice (`AgentTools.maximumRecordings`).
- **Method:** the prompt makes the agent research the product (Claude Code runs get read-only `WebSearch` and
  `WebFetch`), plan four to six beats and give every cursor step a show. Defaults: first step at 1 s, 0.8 s
  apart, 1.5 s per hover or click, 2 s per scroll, scale 1.
- **Zoom per step:** `PointerClip.zoom`, the window's own (agents use show); `WebCamera` times it (in 0.4 s
  before, out 0.6 s after), `WebStage` previews it, and `renderTake` writes the exact zooms into
  `<movie>.edit.json` (none → the editor auto-zooms).
- **Type:** `PointerClip.Action.type` + `text` clicks a field and types into it (`typedText(at:)`,
  `WebTypingScript` in an isolated world: native setter + `input`), in the take and the preview.
- Agents get both through `record_page` (`show`, `type` + `text`). From the chat (`AgentRecordingRequest.rendersVideo`
  false, `AgentTools.stagesPlans`) `record_page` only puts the plan on the timeline (status `planned`); the window renders
  it when the run ends, and the user can change and render it again. Stages 3–6 (spotlight, captions,
  narration, browser frame, speed, 9:16) are planned in the spec.

### Menu bar popover

288 pt wide. First the ways in: **Screenshot** and **Record** (with their shortcuts, ⇧⌘1 / ⇧⌘2) open the capture
toolbar (below) for that kind (while a take is saved, Saving Recording… instead), then **Product Record** (the Web
Recording window) and **Library**, and Edit Last Recording and Restore Last Screenshot when there is one. Then Capture (system audio, microphone
and its device; camera), whose expanded rows sit on the popover itself, with no second background; then Settings… and
Quit. The take's own controls are only on the toolbar. Frame rate, codecs, container, alpha, HDR and the content filter
are in Settings → Video, the audio codec in Settings → Audio.

### Capture toolbar (`feat/ui-polish`)

Replaces the pre-record overlay and the popover's recording rows: a floating bar at the bottom centre of the
screen under the pointer, above the Dock, in the system Screenshot toolbar's order. Idle, its groups sit as
dark Liquid Glass pills. The screenshot toolbar: close and a settings menu (Show Cursor, Settings…) in one pill;
Capture Screen / Window / Area; and **Capture ↩**. The recording toolbar: close and settings; Record Screen /
Window / Area; the options (a countdown chip with its value, then system audio, microphone and camera as
switches); and **Record ↩**, its key in its label. Each
always opens on its area mode (`CaptureToolbarViewModel.open(records:)`, `CaptureToolbarMode.initial`), never the
one it was left on; a selection made elsewhere opens the recording one on its mode. **Take Screenshot…** and
**Record Screen…** open them, from the popover or their global shortcuts ⇧⌘1 / ⇧⌘2 (`showScreenshotToolbar`,
`showRecordingToolbar`, Settings → Shortcuts → Capture Toolbar; idle only, like the rows). What is live, chosen or on is the system accent colour (`CaptureToolbarView.live`): the action's
pill, the mode's highlight (sliding to the one chosen), switches that are on (filled, white icon); a switch that is
off keeps a faint fill so it still reads as one.

**Choosing what to record** opens the mode's own control straight away, whether from a mode icon
(`pick(_:)`) or from Record (`performAction()`), both through `chooseSource(for:)`: Reco's picker for a window
(not the system's full-screen one), the area overlay to drag on. Record Screen has nothing to choose: its icon
only switches mode, and Record takes the display the bar is on (`CaptureSourcePicker.pickDisplay(_:)`, through
`currentDisplayID`, the first display if that one is gone). A choice then starts the countdown. The picker is the
windows as thumbnails above the bar in one row, at most four tiles wide (`CaptureSourceGrid.maximumColumns`), the
rest scrolled to sideways under the frost's edges, each with its app icon, title and app name, on a light frost of its own
(`pickerBackdrop()`; solid with Reduce Transparency) and **nothing else** — no panel with a title, no button.
Each picture is the window at its own shape, fitted into the tile and sitting on its name, with the ring around
the picture itself (`CaptureSourcePicture`): a 16:10 box behind it left wide and tall windows small inside a
bigger frame. One highlight (`CaptureSourcePicker.highlighted`) is on the first tile when they land, and the
pointer and ← → move it (`CaptureSourceGrid.neighbour`, stopping at the ends, scrolled into view); Return or
Record records it (`performAction()` → `pickHighlighted()`). It sits `CaptureToolbarView.pickerGap` (10 pt) above the bar. Esc cancels the innermost thing open first
(`cancel()`: the picker or a half-drawn area, then the toolbar); the close control always closes everything
(`close()`). It waits until it has something to show (`hasSomethingToShow`, a spinner only
after `waitingDelay`), so a warm open lays out the finished tiles in one move. It slides up 16 pt out of the bar
on a spring with a little bounce (`CaptureSourcePickerView.motion`, response 0.38, damping 0.8) and its tiles follow
35 ms apart (`StaggeredEntrance`, from each tile's own appearance so tiles after a slow load still come in turn;
past the fifth they start together); closing slides it all back down, tiles 17.5 ms apart, and it is unmounted
after `CaptureSourcePickerView.exitDelay` (450 ms). Opacity and offset only, scoped (`.animation(_:body:)`), so the
window growing in the same update isn't animated. Reduce Motion fades it.

**It is drawn in the bar's own window**, above the bar (`CaptureToolbarView`), never one of its own: a second
window that took key would have macOS draw the bar's controls as inactive for as long as it was open. So the
panel is sized to the bar plus the picker while it is up (`onSizeChange` measures the window, `onBarSizeChange`
the bar, which is what placement works from —
`CaptureToolbarPlacement.barOrigin(inWindow:barSize:margin:)` and `windowOrigin(for:windowSize:barSize:margin:)`),
the frame is set rather than animated, and a click elsewhere closes the picker through the bar's own
`didResignKey`. It stays mounted until its exit has played, then the window shrinks back around the bar. The
content is held to the window's bottom (`.frame(…, alignment: .bottom)`): the window narrows only after the
change has played, and while it was taller than its content the hosting view centred the bar, which jumped up
by half the picker's height and back down on every close.

**The area selection Record opened has no
Confirm/Cancel buttons of its own** (`presentAreaSelection(showsActions: false)`, from the toolbar only;
the menu and shortcut paths keep them): the bar rises one level above the overlay
(`CaptureToolbarController.selectionLevel`, `.screenSaver + 1`) so it stays clickable, Record is disabled until
an area is drawn and then takes it (`AreaSelectionOverlay.isPresented`/`canConfirm`/`confirm()`), and
switching mode or closing the bar cancels the selection (`cancel()`). Return and Esc still work, on the
overlay's own key handling. During the take the bar
shows what it records (fixed until it ends) and the live pill: the time in red, on a red-tinted pill, dim while paused, pause,
and a white stop square, for any start (menu, shortcut, `reco://`); it goes once the file is saved, as the editor opens on it.

- **Motion:** dragged from anywhere between its controls, it follows the pointer 1:1 from where it was
  grabbed, resists past the screen's edges (`GesturePhysics.rubberbanded`) and, on release, comes to rest
  where its momentum carries it, at the release speed, or home when that lands within 64 pt. A drop is
  remembered per screen; the bar doesn't follow the pointer to another one. Reduce Motion places it without
  the release animation. Enter and exit run through `panelPresentation` with `blur`
  (`CaptureToolbarView.entranceBlur`, 8 pt, under the 12 pt `margin` so the blur isn't clipped): the bar pops in
  where it is, from out of focus to sharp with a fade, with no offset or scale and so no direction at all. The
  animation is scoped to opacity, blur and scale (`.animation(_:body:)`), so the window's resize and the
  content's re-centring in the same update are never animated; that move is what slid the bar in diagonally.
- **Key:** the panel takes key only while idle, so Return (action) and Esc (close) reach it without
  activating Reco; a take gives key back to the app in front (`orderOut`/`orderFrontRegardless`), and
  clicks still land through `acceptsFirstMouse`, so pause and stop never steal focus.
- **Icons:** Hugeicons stroke-rounded (MIT), generated as template PNGs in `Assets.xcassets/ToolbarIcons`
  (`toolbar-*`), drawn by `ToolbarIcon` at the text size; recording modes carry a record badge cut out of
  the picture under it (`CaptureModeIcon`).
- **Keys:** while the bar has key every control answers one, named dimmed after its tooltip's text
  (`CaptureToolbarShortcut`): esc close (one layer at a time), ⌘, settings, 1 / 2 / 3 screen, window, area,
  A / M / C system audio, mic, camera, ↩ the action. Plain keys, as in the system's Screenshot toolbar. A menu
  can't carry a key equivalent, so esc and ⌘, are invisible buttons behind the close control and the gear. During
  a take the bar isn't key, so pause and stop show the global shortcuts (Pause/Resume and Toggle Recording).
- **Tooltips:** every control says what it does in two words at most (`CaptureToolbarMode.shortTitle`, "Mute
  Mic" / "Record Mic"), in a Dock-style bubble in its own window (`CaptureTooltipPanel`,
  never key, `ignoresMouseEvents` so it never blocks anything): white medium text on translucent grey with a
  hairline edge, and a rounded tail pointing at the control — down at the bar from above, or up from below when
  the bar sits at the top of the screen (`pointsUp`). As the system's help tags: the first waits for the pointer
  to rest 300 ms, then while one is up or went under 500 ms ago the next shows at once; leaving a control waits
  80 ms before hiding, so crossing to its neighbour swaps the text and place without a fade. It only fades (in
  0.12 s, out 0.08 s), with Reduce Motion too, since nothing moves. While hovered the text follows what the
  control does (Pause ↔ Resume, On ↔ Off), swapped in place. The window is sized from the bubble measured for
  its text (`CaptureToolbarTooltipView.size(for:)`), and placed from the bar's own frame, not its window's
  (which reaches the 12 pt margin past it, and the picker), so the tail's tip is 6 pt clear of the glass. Dragging the bar keeps tooltips away until
  the pointer moves again, and a screenshot's instant hide takes the tooltip with it.

| File | Role |
|---|---|
| `CaptureToolbar/Model/CaptureToolbarMode.swift` | The six modes; each toolbar opens on its area mode (`initial(records:)`) |
| `CaptureToolbar/Model/CaptureToolbarPlacement.swift` | Pure: home (bottom centre, 48 pt above the Dock), drag resistance, where a release comes to rest, the snap-home distance, where a tooltip sits, and where the bar sits inside its window and the window around the bar |
| `CaptureToolbar/ViewModel/CaptureToolbarViewModel.swift` | Mode, `pick()`/`chooseSource()`/`performAction()`, `cancel()`/`close()`, `selectionDidChange()` (from `RecorderViewModel.onSelectionChange`), option toggles (permission asked when the mic/camera is turned on) |
| `CaptureToolbar/Model/CaptureSource.swift` | Pure: which windows are offered (layer 0, on screen, ≥ 64 pt, not Reco), an untitled window's name, the grid's size |
| `CaptureToolbar/Service/CaptureSourceLoader.swift` | `SCShareableContent` windows or displays with the filter that records each (`desktopIndependentWindow`, or the display), thumbnails at 2× a tile with `SCScreenshotManager` (displays without Reco's windows) |
| `CaptureToolbar/ViewModel/CaptureSourcePicker.swift`, `View/CaptureSourcePickerView.swift` | Open/pick/cancel, thumbnails filled in as each is drawn; `hasSomethingToShow`, the panel and its bare tiles. A pick goes through `RecorderViewModel.selectContent(_:)`, the same path as the system picker's |
| `CaptureToolbar/ViewModel/CaptureToolbarTooltips.swift` | The hovered control and its text: rest delay and warm period, hover, retext while hovered, unhover after a switch grace, suppressed while dragging, and `pointsUp` when the bar sits at the top of the screen |
| `CaptureToolbar/View/CaptureToolbarTooltip.swift` | The tooltip modifier every control takes (dwell delay, live text, mid-x in the bar's coordinate space), the Dock-style bubble with its tail, and its fade |
| `CaptureToolbar/View/CaptureToolbarController.swift` | Non-activating borderless panel, no shadow (glass draws its own), shown and hidden by the recorder's state, sized to the bar plus the picker while it is up (widened at once, narrowed after the exit), drag and momentum, the tooltip's window above the hovered control, and the picker's mount and exit |
| `CaptureToolbar/View/CaptureToolbarView.swift` | The picker above the bar, then idle / counting down (with Cancel) / recording / saving, all in the studio's dark scheme; reports the window's and the bar's own sizes |
| `CaptureToolbar/View/CaptureToolbarIdleControls.swift`, `CaptureToolbarLiveControls.swift` | The idle groups with the sliding mode highlight; the live indicators and pill |
| `CaptureToolbar/View/CaptureToolbarOptions.swift`, `CaptureToolbarMoreMenu.swift` | Countdown chip menu; system audio / mic / camera switches; Show Cursor and Settings… |
| `CaptureToolbar/View/CaptureToolbarShortcut.swift` | The keys the bar answers while it has key, and how tooltips write them |
| `CaptureToolbar/View/CaptureToolbarPill.swift`, `CaptureToolbarButtonStyle.swift`, `ToolbarIcon.swift`, `CaptureModeIcon.swift` | The glass pill (solid with Reduce Transparency, defined edge with Increase Contrast), the press/hover/isOn button styles, the icons |

- The bar is left out of display and area recordings because it is on screen when the filter is built and
  Show Reco is off by default (`ContentFilterRules`); with Show Reco on it is recorded. Screenshots hide it
  first, instantly.

### S7 — Library, the main window (`feat/ui-polish`, spec 0010)

**Library…** in the menu bar, and clicking Reco in the Dock (`applicationShouldHandleReopen`), open Reco's
main window, which stays open unlike the popover: a sidebar (All, Recordings, Web Recordings, Exports,
Screenshots, with counts), a grid of pictures, search, and **New** (Capture Area/Window/Screen, Record
Area…, Record Window or Display…, New Web Recording…). A click opens a movie in the
editor and a screenshot in Preview; the context menu shows in Finder, copies (a screenshot as PNG, a movie
as its file) or moves to the Trash with a recording's `.telemetry.json` and `.edit.json`. The grid is under date
headers, newest first: Today, Yesterday, Earlier This Week, Last Week, then a month each; Screenshots (and All) also
list the screenshot history folder (spec 0012). Down the right edge the dates repeat as a rail
(`LibraryDateRail`), adapted from Chánh Đại's Line Nav: only a short line per date, 10 pt apart, that lengthens
and brightens for the date at the top of the grid and for the one under the pointer, whose title shows to the
line's left, over the grid, in large text with no background; a click scrolls the grid to it. The grid reserves only the lines'
44 pt and hides the rail for a single date. The grid sits on the content colour (`controlBackgroundColor`): on the
window's own colour it matched the sidebar within a few levels (55 against 57 in dark mode). Tiles are 16:10
pictures that fill their frame (screenshots too, cropped), 10 pt continuous corners and a faint edge, with the
name and, dimmed, the kind's symbol and the date under them. Which date is current is
`LibraryDateGroup.active(in:headerTops:topLine:)`, fed by each header's own offset — a lazy grid measures
only the headers it has built, so an unmeasured date is one below the fold and is skipped.

| File | Role |
|---|---|
| `Library/Model/LibraryItem.swift` | Pure: kinds by name and type (`Reco_Web_` web, `-edited` export, `Reco_Screenshot_` PNG), companions, `LibrarySection` |
| `Library/Model/LibraryDateGroup.swift` | Pure: `groups(of:now:calendar:)`, the date headers, and `active(in:headerTops:topLine:)`, which date the rail marks |
| `Library/Service/LibraryStore.swift` | Lists the recordings, screenshot and history folders (a folder read once when two are the same; a history name also saved is listed from the screenshot folder), thumbnails (movie frame or `CGImageSource`), trash |
| `Library/Service/FolderWatcher.swift` | `DispatchSource` vnode writes on all three folders, 0.3 s settle, so new saves show at once (a folder that doesn't exist yet isn't watched until the window is reopened; the history folder is made at launch) |
| `Library/ViewModel/LibraryViewModel.swift`, `Library/View/` | Sections, search, intents; `Actions` wired in `AppDelegate`; window in `EditorWindowManager.showLibrary()` |
| `Library/View/LibraryDateRail.swift` | The dates down the right edge: a line per date, the current one marked, its title on hover, a click that scrolls to it |

- The screenshot folder is the Desktop by default, so only `Reco_Screenshot_*.png` there are listed; reading
  it is what asks for Desktop access the first time.
- Tests trash through an injected remover: an app can't list the Trash (it needs Full Disk Access) to clean up.

### S8 — Agent browsing (`feat/ui-polish`, spec 0011)

Before recording, the agent learns the site as Claude in Chrome does: `open_page`, `look`, `read_page`,
`hover`, `click` and `type` act on the Web Recording window's live preview and each returns JSON plus a JPEG
screenshot (MCP image content). The prompt (`AgentRecordingRequest.prompt`) asks it to explore every section first.
Browsing works only while a run Reco started is going (`AgentTools.hostsRun`, cleared with `stagesPlans` when it
ends or is cancelled): the preview shares the default website data store, so it has the user's logins. Element
text sent to the agent never includes a password's value.

| File | Role |
|---|---|
| `AgentBridge/Service/AgentTools.swift` | `browse()`: routes the six tools, returns `Reply` (text, image, isError); waits 600 ms and for navigation after an action |
| `AgentBridge/Model/BrowseRequest.swift`, `AgentToolCatalog.swift` | Arguments; tool schemas, `names`, instructions |
| `WebRecording/Service/WebPreviewController.swift`, `WebBrowseScript.swift` | `waitUntilLoaded`, `screenshot`, `hover`/`click` via `sendPointer`; locate, read, position scripts in the `RecoPick` world |
| `WebRecording/ViewModel/WebRecordingViewModel.swift` | `agentOpen`, `showAgentTarget` (refused while rendering) |
| `Editor/View/EditorWindowManager.swift` | `webRecordingForAgent()`: the window, ordered front without focus |

### S9 — Notch shelf (`feat/screenshot-history`, spec 0013)

A black shape over the notch of every screen (a 120×8 pt pill at the top centre where there is none). The pointer
on it makes it peek (+7.5 pt each side, +5 down, shadow); staying 300 ms opens it into a 560 pt panel with the
newest 20 screenshots (saved and history): click copies the PNG (tile says Copied for 1.2 s), drag drops the file.
Collapses 500 ms after the pointer leaves. **Settings → General → Screenshot History → Show Screenshots in the Notch** (default off).
Hidden while a take records or saves (`AppDelegate.hideNotchShelfWhileRecording`), so a display recording never shows it as a bar over the notch, Show Reco or not. Hover rings a tile in the accent; a press dims and shrinks it on the frame it lands and lets go after 4 pt, so the file drag still starts.

| File | Role |
|---|---|
| `NotchShelf/Model/NotchGeometry.swift` | Pure: notch (gap between `auxiliaryTopLeftArea`/`RightArea`, widths and height only) or pill; peek, open rects, the one fixed `window` (open panel + 24 pt to the sides and below); open height = notch height + 132 (164 pt on a 14" MBP) |
| `NotchShelf/Model/NotchMotion.swift` | Every spring, delay, radius, shadow and transition, in one place |
| `NotchShelf/ViewModel/NotchShelfViewModel.swift` | `isPeeking`/`isExpanded`; `pointerEntered()`/`pointerExited()` return their delay task (injectable sleep); `activeRect` (notch / peek / panel by state); reads on the pointer resting, not a timer, and draws the pictures before publishing (`reload()`); `copy(_:)` |
| `NotchShelf/View/NotchShelfController.swift` | `NSPanel` per screen (`.statusBar`, never key), one fixed-frame panel, `hitTest` and an `.activeAlways` tracking rect that follow `activeRect` (rebuilt on state change, then pointer vs view model re-synced), rebuilt on screen changes, `hide()`/`restore()` |
| `NotchShelf/View/NotchShelfView.swift`, `NotchShape.swift` | Strip and tiles; one `Shape` (quadratic curves) with animatable top and bottom radii |

Key facts:
- **The window never resizes** (a window chasing the shape clipped it, and its shadow, on every grow: it was resized a
  run-loop turn late). Click-through is transparency plus `hitTest` (nil outside `activeRect`); hover is a tracking
  area on `activeRect` (no global `NSEvent` monitor: Accessibility), rebuilt on each state change, then
  `NSEvent.mouseLocation` is compared with the view model since AppKit sends no enter/exit for a pointer an area
  already contains or misses.
- `reload()` draws the missing pictures side by side before publishing, during the 300 ms delay, so tiles aren't grey
  as the strip enters; the previous items and pictures stay until a read ends.
- Hidden in `ScreenshotController.onWillCapture`, restored in `onDidCapture` (`AppDelegate`), so it's never in a shot.
- **Motion matches notchi's measured feel** (numbers only; it is GPL-3.0, no code taken), user's request 2026-10-04, and
  **overshoots on purpose: the one exception to bounce-free motion.** Springs (response/damping): peek in 0.36/0.74,
  out 0.28/0.96; open 0.5/0.78; collapse 0.36/0.88. Shadows black, blur 6: 0.3 peeking, 0.7 open. Radii: top (inward
  ears) 6→19 pt, bottom 14→24 pt, clamped to the pill. Strip enters y −12 `easeOut(0.22)` +0.08 s, leaves y −6
  `easeIn(0.12)`; header enters y −8 `easeOut(0.2)` +0.12 s, leaves y −4 `easeIn(0.1)`. Reduce Motion: no spring, a fade.
- Tiles use `onTapGesture` + `onDrag`, not a `Button`, whose press tracking would swallow the drag.
- Not yet seen running on a notched Mac: hover while Reco is inactive, full-screen Spaces, several displays.

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
navigations:   [{ time, url }]                         // web takes: a page a click opened; missing → none
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
| S1 editor phase 6: canvas and export polish | Done; the canvas, gradient presets, wallpapers (and one after relaunch), picture blur, the border, a background picture after relaunch, HDR recordings (ProRes too, whose frames carry the tags) and transparent exports still need a check in the app |
| S1 editor design: system colors, glass transport, new timeline and inspector | Done; glass, hover and animations still need a look in the app on macOS 26 and 15 |
| C1 screenshots (area, window, screen) | Done, verified on real captures; each shot opens the Quick Access card and is saved only from it |
| S2 web recordings (spec 0005) | Done and tested; the window's view model was driven end to end on apple.com (pick, render, editor, export). The window itself (buttons, timeline dragging, pick banner) still needs clicking through by hand |
| S3 agent bridge (spec 0006): MCP server for coding agents | Done; tested over the real socket (token, `initialize`, `tools/list`, error calls), the `--mcp` process (`AgentBridgeClientTests`), config editors and plans. Not yet tried: real agents connected by hand, a real `record_page` render, Gatekeeper on another Mac |
| S7 Library (spec 0010): main window | Done and tested (`LibraryTests`); the window itself still needs a look in the app |
| S4 agent recording (spec 0007): Record with AI Agent bar, no App Sandbox | Done and tested with fakes and real `/bin/sh` processes; the login-shell environment was read on this Mac (0.86 s). Not yet tried: any real agent run, the panel in the app (focus, Esc, picker menus, Reduce Motion/Transparency), the update from the sandboxed release (migration), Codex |

What to build next, ranked from a September 2026 survey of competitors and Apple's on-device APIs:
`docs/specs/0004-next-features.md`.

Reference repos for later work: `syi0808/screenize` and `imbhargav5/open-recorder` are Apache-2.0
(portable with attribution). `lzhgus/Capso` (BSL, bans screen-capture use) and
`lihaoyun6/QuickRecorder` (AGPL) are **ideas only — never copy code**.

## Known open items

- Not yet verified on real recordings: area capture mapping, a window moved/resized mid-recording.
- `RecorderViewModel` is over SwiftLint's type size limit (pre-existing); split it before adding more.

## Verifying against real recordings

Recordings can be scripted: select content once in the menu, then drive the running build with
`open -g -a /tmp/bc-build/dd/Build/Products/Debug/Reco.app "reco://toggle"` (starts
when content is selected, stops when recording; no countdown), `reco://pause`, `reco://cancel`, `reco://restart` and
`reco://edit-last` (opens the editor). Use `-a` with the path:
a plain `open` may launch another copy (e.g. Xcode's DerivedData build). Play `afplay` ticks at
logged wall times, then check each tick lands where expected in the audio, shifted by the paused time.
Watch the app's logs with `/usr/bin/log stream --level info --predicate 'subsystem == "com.diip3sh.Reco"'`
(the full path matters: in zsh, `log` is a builtin).

Frame-level checks beat eyeballing. With `ffmpeg`/`ffprobe` (Homebrew):
- Stream lengths: `ffprobe -v error -show_entries stream=codec_type,duration,nb_frames -of compact <file>`
- Frame at a time: `ffmpeg -ss <t> -i <file> -frames:v 1 out.png`, crop around
  `InputTelemetry.videoPixel(...)` to check the cursor tip lands on the prediction.
