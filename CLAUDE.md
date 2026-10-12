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

- Tests: same command with `test` instead of `build -quiet` (Swift Testing). `RecoTests` keeps no tests (all
  removed 2026-10-09): write the ones a change needs there, run them, then delete them.
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
  job (universal until 2026-10-09, arm64 only since). `FirstMouseHostingView` (capture toolbar) and `NotchHostingView` (notch shelf) are
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
| Core (`Model/`, pure helpers in `Service/`) | Value types and pure functions: time mapping, geometry, pauses, dedup, auto-zoom, smoothing, settings rules | `nonisolated`, `Sendable`, no side effects or singletons, so they're easy to unit test. E.g. `RecordingPauses`, `CursorShapeTracker`, `InputTelemetry.videoPixel` |
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
  checked by tests, and docs (this file, specs) match the code.
- Tests written to check a change are deleted once they pass, unless the user asks to keep them
  (2026-10-09): they are for checking the work, not to pile up in `RecoTests`.

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
| `View/CountdownOverlay.swift`, `View/CountdownView.swift` | Click-through, non-activating `.screenSaver` dark panel with the number on a solid 150 pt surface disc with the floating shadow (`editorSurface(in:floats:)`; the 200 pt panel leaves it room) that grows in from its centre (`panelPresentation`) and counts with `numericText`; Esc as a temporary global hotkey |
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
(`cardSize(for:)`: fitted in 260×220, never enlarged, at least 200×120) on an 8 pt solid edge. **Copy ⌘C** and
**Save ⌘S** (the shortcut shown dimmed in the button) always sit along its bottom edge; under the pointer the shot
dims and shows Close, **Add Background** (N14), **Hide Sensitive Info** (N9), **Recognize Text** and **Pin** as small icons in its corners. The card takes key when it appears, without
activating the app, so the shortcuts work until another window is clicked; typing goes to the card meanwhile.
It grows from the card's corner nearest the pointer (`QuickAccessController.anchor(for:pointer:)`, the
bottom-left without a region) and shrinks back there when closed, copied, saved or pinned; `hide()` and
`restore()` stay instant. Drag the card by its 8 pt edge: it follows the pointer 1:1 from where it
was grabbed (`PanelDragger`), and a flick that projects past the screen's edge (`GesturePhysics.flickExit`)
throws it off at the release speed and closes it; a slow drag stays where dropped, a flick inwards too. Drag the shot into
any app to drop the image. The card and the capture toolbar have no window shadow: it outlines
the rectangle around their rounded surface, and their panels have no room for a drawn one. Nothing is written until **Save**. The card stays until
closed, copied, saved, pinned, or replaced by the next screenshot. **Esc** closes it, like the Close button and
a flick: the panel is key while it shows, so `QuickAccessView` handles it (`.onExitCommand`), not the window.
`AppDelegate` wires `ScreenshotController.onWillCapture` to `hide()` so the card never lands in the next shot, and
`onDidCapture` to `show(_:)` for a new screenshot or `restore()` (same card, same place) when the capture is
cancelled or fails. The capture toolbar is hidden the same way but **isn't** brought back by a cancelled capture:
it was only the way in, so Esc on an area selection closes that state and leaves the screen as it was.

- **Copy** (C14): PNG data only; the button turns to ✓ Copied as the card starts closing, so it confirms during the
  fade. With **Settings → Screenshots → History → Save Copied Screenshots** on (`SettingsStore.savesCopiedScreenshots`,
  off by default; 2026-10-09) the copy is also saved, like Save, so it stays in the folder and the Library instead of
  expiring from the history: `ScreenshotController.didCopy(_:)`, which the card's Copy and `?then=copy` both call through
  `QuickAccessController`'s `didCopy`. A failed save sends Screenshot Failed; the copy stands. **Save**: writes to the screenshot folder, then the same with ✓ Saved; each button is as wide as its wider label; on failure the card stays and the Screenshot Failed
  notification is sent. **Recognize Text** (C7): the
  image's text to the clipboard, or, when it holds QR codes or barcodes, their payloads (N16: `TextRecognizer.codes`, Vision's
  `DetectBarcodesRequest` alongside the text request; Code Copied). **Hide Sensitive Info** (N9): pixelates emails, phone numbers,
  card numbers and API keys into the shot, which the card then shows and every other action uses. **Pin** (C8): the image in its
  own panel, then closes. Recognize Text and Hide Sensitive Info confirm on the card for 1.5 s.
- **Add Background** (N14, 2026-10-08; `hugeicons-background`, first of the top-right icons, the accent colour while on): puts
  the shot on the background from **Settings → Screenshots → Background** (`ScreenshotBackground`: a `CanvasStyle` whose shape is
  always the shot's own, plus Auto Balance; kept as JSON in `SettingsStore.screenshotBackground`), and a second click takes it
  off. Always off for a new card: a background is a choice per shot, not a default. `ScreenshotFramer` draws it off the main
  actor like `ScreenshotRedactor`: Auto Balance trims rows and columns within 2 per channel of the top-left pixel's colour
  (`UniformBorders`, pure; a window shot's desktop, a page's margins), then `CanvasLayout` at `nativeShorterSide`, so the shot
  keeps its own pixels inside the padding as an Original export does, and `FrameRenderer.framed` blends it over the backdrop
  through the rounded mask. The HDR copy is dropped, so a framed shot saves as PNG; a clear background keeps its alpha. The
  view model keeps the shot without the background (`plainScreenshot`): Hide Sensitive Info works on that and frames the result
  again, so the background goes over the hidden text and comes off without undoing it. The card refits to the new shape
  (`onReshape` → `QuickAccessController.refit()`, keeping the corner it grew from; `QuickAccessView` reads `cardSize` from the
  shot), and the preview is redrawn at the size the first one was (`previewPixelSize`). The Settings section reuses the editor's
  controls (`CanvasStyleControls`, `BackgroundFillControls`, now bound to a `CanvasStyle` rather than the editor's view model;
  `CanvasStyle.apply(_:)` and `setImage(_:)` make a preset or a picture one write, so one edit).
- **Annotate** (N13, spec 0015, 2026-10-08; `pencil.tip`, first of the top-right icons): grows the card into an editor at the
  shot's size fitted to the screen (`QuickAccessController.annotationCardSize(for:in:)`, the refit keeps the corner it grew
  from) with a tool strip (Select, Arrow, Line, Rectangle, Ellipse, Text, Highlighter, Step, Blur, Pixelate, Spotlight, Crop; V A L
  R O T H N B P S C; eight colours, three widths, undo/redo, delete) over the shot with Copy and Save at its end (2026-10-09, in place of Done
  and a row of them under the shot: they flatten the marks and close the card from the editor; the narrowest editor is 800 pt).
  Marks are vectors in
  the shot's points (`Annotation`, pure); `AnnotationRenderer` draws them with Core Graphics for the canvas (scaled by the view)
  and the output alike; blur, pixelate and spotlight are pixels through `MaskRenderer` (`AnnotationDocument.effects`), rendered
  into the editor's `base` when they change. `AnnotationEditor` (`@MainActor @Observable`) holds the document, a history of
  documents for undo, the tool, colour, width, the draft being dragged, the text being typed and the crop draft; the canvas
  keys a press on its `startLocation`, since a gesture SwiftUI cancels never ends (instant synthetic drags, measured with
  cliclick, left `onEnded` uncalled). Esc shrinks the card back showing the marked shot (`compose()`: plain → flattened →
  framed; `AnnotationFlattener.flatten` draws at the shot's pixels off the main actor, drops the HDR copy, cuts the crop) and the
  marks stay editable until the card closes; Copy, Save, Pin and drag-out flatten first (`flattenIfAnnotating`). Checked by hand
  2026-10-09: arrow, rectangle and two steps drawn on a card, back to the card, Save; the PNG shows them where they were drawn.

| File | Role |
|---|---|
| `Annotation/Model/Annotation.swift`, `AnnotationDocument.swift`, `AnnotationTool.swift` | A mark's shape, colour and width, hit testing and moving; the list with its crop, step numbers and effects; the tools, what a drag makes with each, the strip's colours and widths |
| `Annotation/Render/AnnotationRenderer.swift`, `AnnotationFlattener.swift` | Core Graphics drawing of marks, selection and the crop's dim; the shot with its effects, marks and crop as one `Screenshot` |
| `Annotation/ViewModel/AnnotationEditor.swift`, `Annotation/View/AnnotationCanvas.swift`, `AnnotationToolbar.swift` | Gestures, history, text entry and styles; the canvas and the strip |
| `QuickAccess/ViewModel/QuickAccessViewModel+Annotation.swift` | `annotate()`, `finishAnnotating()`, `compose()` |
| `QuickAccess/View/QuickAccessController.swift`, `QuickAccessPanel.swift` | Non-activating borderless `.floating` dark panel (key on appearing, `hidesOnDeactivate = false`), enter/exit through `panelPresentation` (`exitDelay` before ordering out; leaving panels are tracked so `hide()` clears them too), placement (`panelFrame`), owns the card's view model and the pins |
| `QuickAccess/ViewModel/QuickAccessViewModel.swift` | One screenshot's intents and feedback, the drag-out file; reports up through `onClose`/`onPin`/`onReshape` |
| `Screenshot/Model/ScreenshotBackground.swift`, `UniformBorders.swift`, `Screenshot/Service/ScreenshotFramer.swift`, `Model/SettingsStore+ScreenshotBackground.swift`, `View/ScreenshotSettingsView.swift` | The background setting and Auto Balance's trim (pure); the shot drawn on the canvas; the Settings → Screenshots tab (HDR, history, background) |
| `QuickAccess/View/QuickAccessView.swift`, `PanelDragger.swift` | Card layout on `editorSurface` (16 pt radius), hover scrim (the stage colour at 45%) and controls (Copy and Save over the shot are untinted system glass on macOS 26, `QuickAccessGlassButtonStyle`, as Safari's toolbar over a page: the shot shows through and the system picks the label's colour, where the accent's prominent glass read as a solid pill; captured 2026-10-09, macOS 27, white labels over a photo in both appearances and over a white page on glass the system darkens to grey, lower contrast there; the solid accent before macOS 26; in the annotation editor's strip, on a solid surface, they stay `.editorPrimary`, since secondary's accent text read as a disabled Copy; corner icons on the control fill), a solid toast; icons are 1.5 pt line
SVGs in `Assets.xcassets/LineIcons` as template vectors, drawn by `LineIcon` in `CornerButtonStyle`'s dark circles (both shared with pins): Hugeicons
stroke-rounded (MIT) cancel, checkmark circle, scan text and pin, as in the capture toolbar (the app's icons are SF Symbols and Hugeicons only); a `DragGesture` on the edge drives `PanelDragger` (screen coordinates, `VelocityTracker`, flick exit), `.onDrag` on the shot; in the editor, the strip, the canvas and the actions in one column |
| `QuickAccess/View/PinController.swift`, `PinView.swift` | One `.floating` panel per pin at the shot's point size fitted to the screen (`frame(for:at:in:)`), aspect-locked resize, drag anywhere, 8 pt rounded corners with a faint edge, the card's close button on hover; appears from and closes into its bottom-left corner (`panelPresentation`, a `PanelPresence` per pin); a right-click sets its opacity (100, 75, 50, 25%: the panel's `alphaValue`, shadow included) or makes it click-through (`ignoresMouseEvents`), and the menu bar's **Unlock Pins**, shown while any pin is click-through, takes clicks on all of them again |
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
| `Editor/Service/SpeedAudio.swift`, `OfflineAudioEffect.swift`, `EditorViewModel+Audio.swift` | Each audio track's (and the click sounds') part at another speed, run through `AVAudioUnitTimePitch` in an offline `AVAudioEngine` (`OfflineAudioEffect`, shared with `VoiceEnhancer`: a source node feeding one effect a chunk at a time, the latency and context dropped on the way out) with 0.25 s of context read on each side, to an Apple Lossless CAF in `temporaryDirectory/Reco Speed Audio/`; rendered once per part and rate (`fastPartAudio`), deleted when the window closes |
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
- **Enhance Voice** (N4, 2026-10-08; `AudioMixSettings.Track.enhancesVoice`, a switch on the microphone track's row, or the one
  track's, which may be it: `EditorSource.voiceTrackIndex`): the track with its voice isolated, played in its place. `VoiceEnhancer`
  runs the system's `AUSoundIsolation` (`kAUSoundIsolationSoundType_HighQualityVoice`; the plain Voice type takes more noise and
  more voice: noise alone went from RMS 0.0162 to 0.0038 with it against 0.0005, measured for spec 0004) over the whole track once,
  in the offline engine `SpeedAudio` uses (`OfflineAudioEffect`, one loop for both), to an Apple Lossless CAF in
  `temporaryDirectory/Reco Enhanced Voice/`, on the source timeline from 0 and exactly the track's length, so `CompositionBuilder`
  inserts the track's pieces from it (`ExtraAudio.enhanced`; `nil` inside for a track that couldn't be rendered, which plays as it
  is and isn't tried again on every edit) and a fast part of that track is sped up from it (`fastPartAudio` keeps the file each part
  was rendered from and replaces one rendered from another). Rendered once per track per window (`enhancedVoice`), deleted when
  the window closes; switching it makes a new player item (`needsNewAudioFiles`). Measured 2026-10-08 (macOS 27.0.1, M2, Debug):
  **the unit reports a latency of 0 but delays the audio by 92.5 ms in mono (4440 frames at 48 kHz, 4083 at 44.1) and 132.5 ms in
  stereo**, the same through a file and across runs, so `VoiceEnhancer.latency(channels:)` holds those and the test checks the
  speech lands within 15 ms. And **`AVAudioPlayerNode` is not deterministic in manual rendering**: its schedules reach the render
  through a queue, and in 3 of 9 runs the first render came before the first buffer, so the whole file was one render chunk late
  (exactly 4096, 1024 or 512 frames, whatever the chunk); the engine is fed by an `AVAudioSourceNode` reading a queue
  synchronously instead, which fixed it (lag 0 in 9 of 9) for the time-pitch too. 7 s of 48 kHz speech renders in 0.13 s,
  35 s in 0.57 s (about 60× real time), once. The test speaks with `/usr/bin/say` under white noise: the noise-only RMS falls to
  under a quarter, the voice keeps over half its RMS, the length is unchanged.
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
| `Editor/ViewModel/EditorViewModel+Background.swift` | `updateBackgroundImage(for:)` (the one place the picture is read, for load and every rebuild), the wallpaper list |
| `Editor/Model/StylePreset.swift`, `Editor/Service/StylePresetStore.swift`, `Editor/ViewModel/EditorViewModel+Styles.swift`, `Editor/View/StyleMenu.swift` | A saved look (S19): the preset and what it covers, its `.recostyle` files, the view model's apply/save/import/delete, the toolbar menu (an `.editorIcon` circle like the inspector's button, out of the toolbar's glass) |
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
- **Fill** (N12, 2026-10-08; the Background tab's Video: Fit / Fill, shown in any shape but the recording's;
  `CanvasStyle.fillsFrame`): the video covers the space inside the padding instead of fitting in it. `CanvasLayout.videoFrame`
  is that space (`filledFrame`) and `baseView` the largest part of the video in its shape, as fractions of the video (a 16:9
  recording in 9:16 shows 0.29 of its width); `CameraPath` takes the base view as what 1× shows: it follows the cursor
  with it between zooms with the zooms' dead zone (`RenderPlan.camera` places every cursor sample then, not only the
  followed zooms'), starts on the cursor instead of easing there from the centre, and clamps and scales zooms from it
  (`ZoomSegment.clamped(_:scale:in:)`, `CameraPath.following(_:from:scale:in:)`; the zoom focus pad outlines the base view
  at the zoom's scale). `FrameRenderer.transform(to:of:size:)` stretches the view to the video's size and `videoTransform`
  the video onto the frame, so the two scale evenly. Original export: `nativeShorterSide` sizes the canvas for the part
  shown, and since the canvas's even sides leave the padded space up to 10 px off that part's own size, `filledFrame` takes
  the part's size when within `ownPixelsSlack` (12 px) of the space and lets the padding absorb the difference, and
  `FrameRenderer.placement` moves a 1× video by whole pixels, so the export is the video's pixels panning. Automatic
  zooms are still made for the whole video, so one may not fit the base view; it's clamped into it. Measured 2026-10-08
  on an M2 (Mac14,2), Debug, load average 5–6 (noisy), a 3840×2160 frame on the 9:16 preview canvas (2160×3840), no
  overlays, the cursor crossing the frame so the view pans, 180 frames, three runs: fit 3.2–5.6 ms p50, fill 3.8–7.2 ms p50
  (a filling frame is always resampled, like a zoomed one; a fitted 1× frame isn't); p95 13–16 for both, load spikes.
- Frames are drawn region by region (`CanvasLayout.regions`): the padding from the backdrop alone,
  the video in 8 bands, its rounded corners with the mask. Core Image evaluates every overlay
  across the whole region it renders; in bands it skips them where they aren't. Measured on an M1,
  Debug, 4K with a ring and a chip, load average 4–6: 3 ms p50 plain (7 drawn whole), 3.7–5 ms on
  the default canvas (9 whole), p95 under 7.5 ms. The backdrop takes 4 ms to draw (17 the first time).
- A transparent background keeps its alpha only in ProRes 4444 (the ProRes tab's 4444 when the canvas is transparent); other formats export it black.
- **Crop** (N11, 2026-10-08; Background tab, `CropField` on a `RegionPad`: the frame at the playhead with the crop outlined, edges and
  corners dragged within 10 pt, inside moves it (`RegionDrag`, shared with masks), Reset): `EditorProject.crop`, fractions of the video from its top-left corner,
  at least 10% a side (`VideoCrop`). `VideoCrop.pixels(of:in:)` puts it on whole pixels with even sides (the whole video exactly
  when nothing is cropped), and from there **the crop is the video**: `RenderPlan.videoSize` is its size, so the canvas, export
  sizes and the stage's shape follow; the plan reads `InputTelemetry.cropped(to:)`, which moves every geometry entry's
  `contentRect` by the crop's origin and sets `capture.videoSize` to it, so clicks, the cursor, the camera's cursor points and
  automatic zooms (presses outside the crop are outside the video, which the generator already ignores) are all in the crop
  with no other change. `FrameRenderer` cuts the frame to `RenderPlan.crop` and moves it to the origin by whole pixels before
  anything is drawn, so nothing is resampled. Zoom focus is a fraction of the crop: when a crop drag ends, automatic zooms are
  generated again in the same undo step (not per drag step: ~34 ms for 10 minutes); manual fixed zooms keep their fractions,
  so they shift with a new crop. The filmstrip and the timeline show the whole frame.
- **Masks** (N8, 2026-10-08; **M** or the transport's Add Mask, a mask lane under the zoom lane once there is one, the Background
  tab's Mask section for the selected one: Blur, Pixelate or Spotlight, a `RegionPad` on the cropped frame where it starts with
  every rectangle outlined and the selected one's handles, Add Area and Remove Area): `EditorProject.masks` (`MaskSegment`:
  source range, one or more rectangles as fractions of the crop from its top-left, kind; 3 s and 30% of each side when added,
  at least 2% a side and 0.25 s), a `TimelineClip` list like the zooms, so masks are sorted and apart: **one mask at a time**,
  which is why a mask holds several rectangles (a frame often shows two things to hide at once). `RenderPlan.masks` holds
  them in the crop's Core Image pixels on whole pixels (`PlannedMask`); `FrameRenderer.masked(_:at:plan:)` applies the one
  showing at the frame's source time right after the crop, before zoom and overlays, so a mask stays on the content and the
  cursor and click rings stay over it; `MaskRenderer.apply(_:to:of:)` does the pixels, for the screenshot card too. Blur: the
  clamped frame blurred at sigma 1.2% of the shorter side, cut to each rectangle. Pixelate: `CIPixellate` cells of 2% of the
  shorter side (at least 4 px) from each rectangle's corner, each cell one pixel's colour (not an average: 8 px cells over 4 px
  strokes came out solid black) multiplied by a random grey of 0.94–1.06 (`CIRandomGenerator`, the same every frame), so cells
  can't be matched against rendered candidates. Spotlight: everything else at 40%. Measured 2026-10-08 on an M2 (Mac14,2),
  Debug, load average 5, a 3840×2160 frame on the default canvas, one rectangle, 180 frames: no mask 2.6 ms p50 / 3.2 p95,
  blur 3.7 / 4.0, pixelate 4.5 / 4.9, spotlight 3.0 / 3.1.
- **Find Sensitive Info** (N9, 2026-10-08; the Mask section's button, with progress and Cancel while it runs): reads a frame
  a second of the kept parts (`SensitiveInfoScanner`: `AVAssetImageGenerator` with half a second's tolerance, each sample at
  the frame's own time, cut to the crop), finds text with Vision (`SensitiveTextFinder`: `RecognizeTextRequest` `.fast` with
  `minimumTextHeightFraction` 0.008, since at the default `.fast` read nothing at 26 px on 4K, measured for spec 0004; about
  150 ms a 4K frame, so 10 minutes take ~90 s off the main actor) and what in it is private (`SensitiveText`, pure:
  `NSDataDetector` phone numbers and `mailto:` links, so plain links aren't masked; 13–19 digits passing Luhn for cards, which
  the detectors don't find; `sk-`, `sk_live_`, `gh*_`, `github_pat_`, `AKIA`, `xox*-` keys; `NSRegularExpression`, since Swift's
  `Regex` has no lookbehind and isn't `Sendable`). `RecognizedText.boundingBox(for:)` turns each match into a box, padded by a
  quarter of its height, at least a mask's minimum size. `SensitiveMasks.masks(from:interval:duration:)` (pure) joins a box
  with the overlapping one in the sample before into one rectangle covering everywhere it was, hidden from the sample before
  it was seen to the one after (text can come or go any time between), so only text showing under a second can be missed;
  rectangles overlapping in time share a mask. `merging(_:into:)` adds them to the project's masks in one undo step: a found
  mask overlapping one made by hand joins it, which keeps its id and kind and grows to cover both. Found masks are Pixelate.
  The footer says how many were masked and never that everything was found. On the **screenshot card**, Hide Sensitive Info
  (`hugeicons-view-off-slash`, first of the top-right icons) runs the same finder at `.accurate` (one still) and pixelates the
  boxes into the shot (`ScreenshotRedactor`, through `MaskRenderer`); the card then shows and copies, saves, pins and drags
  the hidden shot, and a toast says how many items were hidden. The HDR copy is dropped, so a hidden shot saves as PNG.
- HDR frames are drawn without color management too: the plan draws its overlays once in the
  recording's encoding (`OverlayImages.encoded`), SDR white at 203 nits (BT.2408). Their
  semi-transparent parts (the chip's backing, the cursor's shadow, a fading ring) blend in PQ's
  encoding, so over HDR they look a little darker than in SDR. Measured on an M1, Debug, 4K with a
  ring and a chip, load average 2–3: 4–4.6 ms p50 and 5–8 ms p95, against 6.7–8.1 and 10–13 with
  a color-managed context; SDR took 3–3.5 in the same runs. Converting the backdrop costs 9–11 ms
  more per HDR plan (20 the first time), alongside the camera and cursor. The composition is
  tagged BT.2020 and the recording's PQ or HLG; GIF exports are SDR.
- **Style presets** (S19, 2026-10-08; the toolbar's **Style** menu, before Export…): a `StylePreset` is a project's look
  without its content, the canvas, cursor, clicks, keystrokes, zoom motion and motion blur (cuts, speeds, zooms, masks,
  the crop and the audio mix belong to the recording and stay out), saved under a name as a `.recostyle` file (JSON, v1,
  `UnsupportedVersionError` for others, missing settings take their defaults) in `Application Support/com.diip3sh.Reco/Styles/`
  (`StylePresetStore`: one file per name, `/` and `:` replaced, listed by name). The menu ticks the style the project
  looks like (`currentStyle`, `matches`), applies one in one undo step ("Apply Style", `preset.applied(to:)`; a picture
  background's bookmark reloads through the normal rebuild), **Save Current Style…** (an alert with the name; the same
  name replaces), **Import Style…** (a file picker), **Share "name"…** (`ShareLink` with the store's file: AirDrop, Mail…)
  and **Delete Style**. The type `com.diip3sh.reco.style` is declared in `Info.plist`, so a `.recostyle` opened from Finder
  reaches `application(_:open:)` → `EditorWindowManager.importStyle(from:)`: applied in the key editor, or only kept with
  the saved styles when none is open; dropped on the editor (`dropDestination` for URLs) it's imported the same way.
  Each editor reads the list when it opens and after its own changes; another window's save shows up in the next editor.

### S1 — Editor design (`feat/editor-shell`, theme `feat/linear-theme`)

Since 2026-10-08 every window and floating panel wears design tokens extracted by Refero; dark mode's are herding.app's
(2026-10-09, in place of Linear's): warm olive-charcoal solid surfaces one step apart (page void `#1c1c1a` for window grounds,
graphite card `#232320` for panels and cards, ash step `#35352f` for what floats over them and for control fills, slate matte
`#2e2e2b` for lanes), text in three tones (off-white ink `#fffffe`, sand label `#a3a29c`, fog text `#7f7e77`), hairlines
instead of boxes (white at 8%, `#ffffff14`, since 2026-10-09: a light ring like the web's `box-shadow: 0 0 0 1px`, where
herding's bistre `#161615` drew a black outline; 6% vanished on page void and 12% read as a grey line, compared side by side;
the dot grid's dots and the divider fills use it too, so they are faint light marks now; `scripts/apply-theme.py` takes
`#rrggbbaa` for it), Inter for every label (herding's Styrene is a paid typeface) and JetBrains
Mono for shortcuts, file names and code, and spray wash `#3fe0a6` as the one accent, with page void on it. Pewter `#45453e`
and stone `#3e3e38` aren't used: sand label on them is 3.8:1 and 4.2:1. Light mode (2026-10-08) takes the light end of Default's tokens (default.com, also by
Refero): bone `#f2f2f2` for window grounds and control fills, snow `#ffffff` for panels and cards, chalk `#cececf`
hairlines, void `#0b0c0e` text, steel darkened to `#6b6b73` for dim text (steel `#71717a` is 4.3:1 on bone), fog
`#858687` for faint marks, and iris `#314ef0` as the accent and its fill, with white on it (Signal Blue `#3b82f6` was
turned down: white on it is 3.7:1). Every colour is a colour set in `Assets.xcassets/Theme` (and `AccentColor`) with a
dark, a light and an Increase Contrast variant of each, so the app still follows the user's appearance; no window forces
one (the notch shelf excepted: it is black under the notch). The menu bar popover stays native, as before the theme: the
system font, label colours and accent on `.ultraThinMaterial`. No Liquid Glass and no materials, except the primary
button (tinted glass, below), the capture toolbar's live controls (tinted glass, see Capture toolbar) and Raycast's see-through columns: the Library's sidebar and the editor's and Web Recording's inspectors show the desktop blurred
(`translucentColumn()`: an `NSVisualEffectView` behind the window, tinted with `panel` at 45%, not yet checked by eye), which
is why editor windows aren't opaque and have a clear background, and their content draws its own ground. Native controls (Settings' forms, switches, pickers, the shortcut
recorder) stay native and take the accent through `.tint`; AppKit controls follow the user's own accent instead when it isn't
Multicolor. This replaced the system colours and glass of 2026-09-28 to 2026-10-07. The preview sits on a dot grid; the inspector (toolbar toggle) holds every
setting on the right, and the transport (cut, zoom, ⌫; frame steps and play; the time) sits in the timeline's header,
without glass. A chip row under the preview in place of the inspector was tried on 2026-10-05 and turned down: the
settings stay visible in the column. Nothing else is colored: clicks, keys and zooms are greys, and the default canvas is a
slate gradient.

| File | Role |
|---|---|
| `Editor/View/EditorTheme.swift`, `Assets.xcassets/Theme` | Colours by role (`stage`, `panel`, `surface`, `raised`, `control`, `ink`, `dim`, `faint`, `hairline`, `softHairline`, `accent` for lines and text, `accentFill` with `onAccent` on it), radii (6 buttons and fields, 12 cards and panels, 16), spacing on a 4-point grid, and the motion tokens: `motion` (spring, response 0.35, critically damped: every state change), `quickMotion` (0.15: hover, release), `momentumMotion` (damping 0.8: only after a flick), `fadeMotion` (Reduce Motion's cross-fade) and `release(velocity:distance:)` (a drag's release speed handed to a spring) |
| `Editor/View/View+EditorSurface.swift` | `editorSurface(in:fill:floats:)`, a solid fill with a hairline edge (`floats`: the token's xl shadow, which needs 20 pt of room in its window); `themed()`, the accent and typeface every window root applies; `editorWindowBackground()`; `editorMotion(value:)` animates unless Reduce Motion is on (`nil` skips it); `withMotion { }` is the same for code with no environment |
| `Editor/View/Font+Theme.swift`, `Typeface.swift`, `Fonts/` | `Font.theme(_:weight:_:)` and `NSFont.theme`: a text style in Inter or JetBrains Mono, both variable fonts (SIL OFL 1.1, licences beside them) registered by `ATSApplicationFontsPath`. Sizes are macOS's own per style (so layouts keep their room) except title (20) and large title (24), from the token scale; medium and semibold are Linear's 510 and 590 on the `wght` axis. Rendered video overlays (keystroke chip) keep the system font |
| `Editor/View/StageDotGrid.swift` | The dot grid behind the preview, fading out before the stage's edges |
| `Editor/View/EditorButtonStyle.swift` | The two text buttons: `.editorPrimary` (`EditorPrimaryButtonStyle`), the system's `.glassProminent` capsule tinted with the accent fill, `onAccent` text, large control size (2026-10-09, after Parker Ortolani's "Tinted Liquid Glass"; a custom `.glassEffect(.regular.tint(…))` behind the label barely showed the tint, and none inside the toolbar's glass; the solid fill before macOS 26; the system style handles hover, press, Reduce Transparency and Increase Contrast; its contrast isn't tested, since glass takes in what's behind it), only for the one action a place leads to (Export…, export's Export and then Share…, Render, Copy and Save in the annotation editor's strip); `.editorSecondary`, the control fill with a 6 pt radius, a hairline edge and ink text, for every other text button. Icons come from the button's `Label(_:image:)`: `Assets.xcassets/ButtonIcons`, Phosphor Bold (MIT) from Iconify as 14 pt template PNGs (`button-export`, `-share`, `-folder`, `-close`, `-retry`, `-agent`, `-settings`, `-render`); the press scales to 0.97 on the frame it lands, only hover and release ease |
| `View/PanelPresentation.swift`, `PanelPresence.swift` | `panelPresentation(isPresented:anchor:motion:blur:)`: a floating panel fades and, with `blur`, pops in where it is from that many points out of focus — no direction, where a scale has one, since the corner furthest from the anchor travels the most and the eye reads the panel as growing from that corner (the capture toolbar and its picker use `blur`; the card, pins, agent bar and countdown use the scale). Only opacity, blur and scale are animated, so a window resize in the same update isn't. Opacity only with Reduce Motion; `exitDelay` is how long its window stays; `PanelPresence` carries the flag for controllers whose view model can't |
| `View/MenuRowButtonStyle.swift` | `.menuRow` for the popover's rows, and `MenuRowHighlight`: Control Center's highlight (not on `MenuBarToggle` rows, whose switch is the only control), a 10 pt continuous rounded fill the row's full height, 6 pt in from the sides, 0.1 on hover, 0.16 the moment it's pressed, dimmed when disabled |
| `Model/GesturePhysics.swift` | Pure: `project` (momentum), `rubberband`/`rubberbanded` (resistance past a boundary), `relativeVelocity`, `velocityMatchedDuration`, `flickExit`, and `VelocityTracker` (the last 0.1 s of a drag) |
| `Editor/View/EditorWindowManager.swift` | `makeWindow`: content under a transparent title bar, centred, never larger than the screen less 40 pt; the editor and Web Recording open at 1533×943 (the size picked by hand on 2026-10-05) |
| `Editor/View/EditorStage.swift`, `TransportBar.swift`, `EditorIconButtonStyle.swift` | The preview in the canvas's shape with a checkerboard behind transparent canvases; the transport in the timeline's header |
| `Editor/View/TimelineRuler.swift`, `Playhead.swift`, `ZoomBlock.swift` | The ruler (the finest scale whose labels stay 72 pt apart; a line at each label, dots between; labels carry their units, "0.5s", "1m 30s", "1h", since a clock's "0:00.5" didn't say what it counted), the playhead's knob, the zoom blocks |
| `Editor/Model/InspectorTab.swift`, `Editor/View/InspectorTabBar.swift` | The inspector's tabs (2026-10-07): Background · Camera ‖ Audio ‖ Cursor · Keyboard ‖ Captions ‖ Motion, as icons on one capsule track with a line between groups and a sliding fill; only the chosen tab's sections show (Background's one untitled section: aspect, background, padding, corners, shadow, border; Audio; Cursor and Clicks; Keystrokes; Zoom). Camera and Captions stay disabled until the camera is its own track and a transcript exists (spec 0004, N19, N5); Audio is always available. The tab is `EditorView` state, so it survives export; selecting a zoom turns to Motion. Motion holds the zoom's and the cursor's movement (Mellow, Smooth, Fast; the cursor's also None) and Motion Blur (a slider, Off at 0): `ZoomMotion` sets the camera spring at 6, 10 or 16 rad/s (96% of a move in 0.83, 0.5 or 0.31 s), saved in the project as `zoomMotion`, blur as `motionBlur` |
| `Editor/View/Inspector*.swift`, `EditorInspectorSections.swift`, `TickSlider.swift`, `TilePicker.swift`, `CanvasInspectorSection.swift` | `EditorInspector` and its sections, which fold away under a dim title (Background's has none, so it never folds), `SwatchGrid` (preset and wallpaper tiles, the chosen one ringed in the accent colour), sliders with their values, switches, colour wells on the right edge like a switch (`InspectorColorRow`; a gradient's Start and End share one Colors row), and tiles whose highlight slides. A section's full-width action button is `.editorSecondary`; small inline ones (Reset, Add Area, Cancel) stay borderless. Every slider is a `TickSlider`: a track with ticks, accent fill up to a bar at the value, dragged 1:1 from the grab (a press away from the bar takes it there first), VoiceOver adjustable in 20 steps, without a focus ring |
| `Editor/View/ExportOptions.swift`, `ExportProgressBar.swift` | Export's inspector: format, size and frame rate as `SegmentedChoice` tabs (an option can be disabled), the quality as rows with their estimated sizes, Export and Copy to Clipboard (side by side at one width when the column holds both at the wider one's width, else stacked: `EqualWidthRow`; a `ViewThatFits` measured each at its own width and cut Copy's label short at 380 pt) pinned under a line; progress |

**Changing the theme:** `theme/theme.tokens.json` is the source of every colour, in the W3C design-token format the
Linear tokens came in. Its `color` group is the dark palette as given (herding.app's since 2026-10-09, Linear's before), `lightColor` the light one (Default's); its `role` group gives each role above a dark `$value`
(a hex or an alias such as `{color.void}`) and, in `$extensions.com.reco.theme`, its `light`, `darkHighContrast` and
`lightHighContrast` values. Edit the file (or replace it with another theme's, keeping the `role` names), run
`scripts/apply-theme.py`, which rewrites every colour set in `Assets.xcassets/Theme` and `AccentColor`, then check the
colours' contrast against the rules below and that the radii (`radius`) and typefaces (`font`) still match the file:
no test checks them. Radii and typefaces are read by Swift, not generated: change
`EditorTheme`'s radii or `Typeface`'s families to match, and put a new font's file in `Reco/Fonts`.

| File | Role |
|---|---|
| `theme/theme.tokens.json`, `scripts/apply-theme.py` | The theme's tokens; the generator of the colour sets (aliases resolved, loops and bad values refused) |

Key facts:
- Contrast is measured with the WCAG formula, not eyeballed: in dark, light and both Increase Contrast variants, ink is at
  least 7:1 on every surface, dim 4.5:1, faint (structure marks only, never text) and the accent 3:1, and `onAccent` on the
  accent fill 4.5:1 (7:1 with Increase Contrast; white on iris is 6:1).
- Measure the colours from the token file, not through AppKit: the Increase Contrast variants are compiled into
  `Assets.car` (`assetutil` lists them), but `NSColor(named:)` resolved under `NSAppearance(named:
  .accessibilityHighContrastDarkAqua)` returns the normal value (2026-10-08, macOS 27), so a check through AppKit
  silently covers only dark and light.
- **Status colours** (2026-10-09) are roles too, outside herding's palette: `success` emerald, `warning` ember (orange),
  `danger` rose, Tailwind's 400 in dark and 700 in light (a step further with Increase Contrast), each at least 4.5:1 as
  text on every surface and the control fill (rose on dark control: 4.6:1).
- **An accent fill carries `onAccent`, never a fixed colour:** it is page void on spray wash in dark (white on it is 1.7:1) and white on iris in light. That includes system prominent buttons,
  which draw white titles: use `.editorPrimary` instead.
- **If glass comes back, it animates itself unless told not to.** `glassEffect` grows its shape as it appears (Apple's
  own transition, `GlassEffectTransition` in SwiftUICore with `.matchedGeometry`, `.materialize` and `.identity`), so a
  surface with its own entrance gets a *second* motion on top: the capture toolbar's glass pills read as the controls
  sliding in diagonally until they set `.glassEffectTransition(.identity)` (2026-10-05).
- The inspectors keep the system `.inspector`; their content and the Library's sidebar list (`scrollContentBackground(.hidden)`)
  take `translucentColumn()` (`Editor/View/BehindWindowBlur.swift`). The window's ground (`editorWindowBackground()`) is on the
  main content only, never the root: anything opaque under a column hides the desktop.
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
- One visual family, one motion system: every window and floating panel (editor, Library, Web Recording, the agent
  bar, Quick Access card, pins, capture toolbar and its picker, countdown, Settings) on the same surfaces, with
  the accent for what is chosen or the action; a take in progress is red, a status colour outside the tokens.
- Motion follows the apple-design skill: respond on press, move 1:1 from the grab point, springs that start
  from the current value, bounce only after a flick, symmetric enter and exit from the source. Timeline
  clip and trim-handle drags resist past the ends (`rubberbanded`) and release into `release(velocity:distance:)`,
  so what the timeline refuses springs home from where it was shown; the zoom focus pad keeps the offset
  from where its outline was grabbed.
- Area selection fades its dim in over 0.12 s on the first drag (instant with Reduce Motion), and its
  Confirm and Cancel are AppKit push buttons (Confirm's bezel the accent fill, its title `onAccent`) with Return
  and Esc as key equivalents. The dim, border and handles it draws over the screen stay black and white.
- Skipped on purpose: Settings, the menu bar label, the export sheet, momentum on timeline edits, rubber-banding
  area selection, pin flick, scrubbing.
- Clips in a lane (`TimelineLane`: zooms, web cursor and scroll clips) are window-coloured chips on a hairline and
  show their trim handles only when hovered, selected or dragged (`TrimHandle.isShown`): on a 1 s clip two
  always-on 8 pt handles hid the clip. The Web Recording timeline has no grey band behind it.
- Optional bindings use `Binding(unwrapping:)` (`View/Binding+Unwrapping.swift`), never `Binding($optional)`: views
  under an `if let` read the binding once more after a selected clip or zoom is deleted, and `Binding(_:)`'s
  force-unwrap crashed the app (three crashes on 2026-10-02, one mid agent run).
- `ImageRenderer` can't draw system glass (the inspector, the sidebar), AppKit controls, `ScrollView`s or the player, and
  `screencapture`/`cacheDisplay` need permission or miss SwiftUI; check the look in the app.

### C1 — Screenshots

Menu bar **Capture Area / Capture Window / Capture Screen** and global shortcuts of the same names
(Settings → Shortcuts → Screenshots, ⌘1 / ⌘2 / ⌘3) and `reco://capture-area`, `capture-window`, `capture-screen` (N16); **Capture Previous Area** (N16, a shortcut with no default and `reco://capture-previous-area`) shoots the last area captured since launch again on its display, live and without selecting (Capture Area when there is none; `selectedDisplayDisconnected` when its display is gone). All four links take `?then=copy|save|pin` in place of the card (`ScreenshotFollowUp`, `QuickAccessController.follow`: a card showing stays; a failed copy or save opens the card; an area pins where it was taken, anything else in the card's corner; the shot becomes the one Restore Last Screenshot brings back). The capture toolbar's **Self-Timer** (screenshot mode; Off, 3, 5, 10 s, `SettingsStore.screenshotTimer`, default Off) counts down with the countdown's disc on the pointer's screen before its capture starts (`ScreenshotController.afterSelfTimer`; Esc cancels and nothing is captured); shortcuts and links don't wait. Defaults are ⌘1–⌘7: capture area, window, screen, select content, select area, toggle and pause recording (`KeyboardShortcutNames.swift`); global, so they take ⌘1–⌘7 from every app until changed. The popover shows each row's shortcut dimmed (`MenuBarActionButton.shortcut`). Both follow `canCapture(alongside:)`: idle only,
so a shortcut pressed while recording, counting down or capturing is ignored and logged.
Capture Area freezes the screen first: every display is captured when it starts (`ScreenshotService.captureDisplays`),
the overlay shows that picture (`AreaSelectionView.frozenScreen`, `AreaSelectionPanel.show(_:)`), and the area is cut from it
(`Screenshot.cropped(to:)`), so hover states, tooltips and open menus the overlay takes away from the apps
under it are still in the shot. A **loupe** (N17; `LoupeView`, placed and fed by `LoupeGeometry`, pure) sits 20 pt below and
right of the pointer (the other side at the screen's edges), 120 pt square: the frozen screen's pixels around the
pointer at 4 pt each (30 across, drawn with no interpolation, a grid on their edges) with the pointer's pixel outlined
in white with a dark halo. It shows before anything is drawn, while drawing or resizing, and over a handle; not while
moving the selection or resting on it, where the buttons are (`AreaSelectionView.wantsLoupe(at:)`), and never over the
live screen (a recording's selection), which has no still pixels. Not yet seen in the app; the orientation is tested by
rendering the view. Capture Area shoots as soon as the drag ends (`AreaSelectionOverlay.present(confirmsOnRelease:)`); a click, a
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
running), so nothing is stored or listed twice; Copy, Pin, Recognize Text and Close leave it. **Settings → Screenshots →
History** (in General until N14 gave screenshots their own tab): Keep Screenshots Off / 1 Week / 1 Month (default) / 3 Months, and Clear History…. Expired
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
- **HDR screenshots** (N16; Settings → Screenshots → Capture → Capture HDR Screenshots, macOS 26 and later, off by default,
  `SettingsStore.capturesHDRScreenshots`): screen and area shots are taken with `SCScreenshotManager.captureScreenshot` and
  `dynamicRange = .hdr` (`ScreenshotService.hdrConfiguration`) and keep the picture as `Screenshot.hdrImage` (16-bit extended
  sRGB); `image` is drawn from it in 8-bit sRGB, highlights clipped (`standardRange(of:)`), for the card, pins, Copy (still a
  PNG) and Recognize Text. Files (Save, history, drag-out) go through `ScreenshotService.write`: an HDR shot is a `.heic`
  with an SDR base and an ISO gain map (`kCGImageDestinationEncodeToISOGainmap`), anything else a PNG; the Library and history
  pruning take both (`Screenshot.contentTypes`, `LibraryItem.isScreenshot`). Window shots stay SDR: the HDR configuration has
  no `scalesToFit`. Measured 2026-10-08 on macOS 27.0, M2: the HDR picture comes back as `sdrImage`, and `hdrImage` is nil
  even for `.bothSDRAndHDR`, hence one `.hdr` capture (and both images from the same frame); a 3420×2224 capture took
  100–126 ms, drawing its SDR picture 4–6 ms. Not yet checked with HDR content on screen.

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
each one's own settings, only when the user clicks Connect (it writes the bridge token there). Each row's status is coloured: Connected emerald (`EditorTheme.success`), Not connected and Out of date ember (`warning`), Not found dim; Disconnect is rose (`danger`). The agent then calls three MCP tools: `inspect_page` (selectors and boxes of a
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
- **An agent never takes focus** (2026-10-08): pages are inspected and rendered in an offscreen window, and a finished
  movie (the bridge's, and every Web Recording render, the chat's included) goes through
  `EditorWindowManager.openWhenReady(_:)`: in front while Reco is the active app, otherwise its editor is ordered behind
  every window (`orderBack`, no activation) and **Recording Ready** is posted (`sendRecordingReadyNotification`, Edit and
  Show in Finder; a click brings the editor forward). A recording the user stops still opens in front, as before.
- Windsurf is left out (config path unverifiable). `CODEX_HOME`, `GROK_HOME`, XDG and `OPENCODE_CONFIG`
  aren't followed (they could be now); `opencode.jsonc` isn't handled.
- Edited JSON keeps its content but its key order becomes sorted. Files with comments are refused.
- The test host is Reco, so its server takes `agent.sock` from a running Reco while tests run.
- A test of the `--mcp` client can have the test host start another copy of itself.
- Config files are written through a temporary file next to the target, then `rename(2)`.

### S4 — Agent recording (`feat/agent-bridge`, spec 0007)

The agent is part of the one Web Recording window (**New Web Recording…**, and the Library's New): its **AI Agent** button
at the toolbar's leading edge opens the chat panel on the left. The shortcut **Record with AI Agent** (Settings → Shortcuts →
Web Recording, no default) and the failure notification's action open the same window with the panel open
(`EditorWindowManager.showAgentChat()`, S5); the menu bar and the Library have no row of their own. The Spotlight-style bar it used to open was removed on 2026-10-02. Reco runs the agent's command line headlessly with only its own
three MCP tools allowed; the agent records through the bridge (S3) and the editor opens (behind the user's work, with a
notification, when Reco isn't in front). While it
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
  so closing and reopening mid-animation retargets; Reduce Motion cross-fades.

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
  Don't run tests during an agent run; relaunch Reco after testing. Tests that render write into a
  temporary folder, not `~/Movies/Reco`.
- Rendering `http://localhost:1` succeeded instead of failing on this Mac (macOS 26.6), so a page that can't load
  may not fail its render. Not yet looked into.

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
solid surface pills with a hairline edge. The screenshot toolbar: close and a settings menu (Show Cursor, Settings…) in one pill;
Capture Screen / Window / Area; and **Capture ↩**. The recording toolbar: close and settings; Record Screen /
Window / Area; the options (a countdown chip with its value, then system audio, microphone and camera as
switches); and **Record ↩**, its key in its label. Each
always opens on its area mode (`CaptureToolbarViewModel.open(records:)`, `CaptureToolbarMode.initial`), never the
one it was left on; a selection made elsewhere opens the recording one on its mode. **Take Screenshot…** and
**Record Screen…** open them, from the popover or their global shortcuts ⇧⌘1 / ⇧⌘2 (`showScreenshotToolbar`,
`showRecordingToolbar`, Settings → Shortcuts → Capture Toolbar; idle only, like the rows). What is live, chosen or on is the accent fill (`CaptureToolbarView.live`, with `onAccent` content): the action's
pill, the mode's highlight (sliding to the one chosen), switches that are on (filled, dark icon); a switch that is
off keeps a faint fill so it still reads as one. On macOS 26, while the bar is key, each of them is Liquid Glass
tinted with it at 70% and no fill under it, so the desktop shows through (`captureToolbarLive(_:in:isInteractive:)`,
2026-10-09; interactive on the action and the switches). The tint was picked from ScreenCaptureKit captures of the bar
in a key and a non-key panel (macOS 27): at 100% it read as a solid fill over a dark desktop (a fill under the glass
did too), at 50% the `onAccent` text sank into the dark behind it. Glass drops its tint while its window isn't key,
`.glassProminent` too, and setting `controlActiveState` doesn't bring it back; the bar loses key to the area overlay or
another app, so then (`controlActiveState` isn't `.key`) it is the solid fill instead, as with Reduce Transparency on and
before macOS 26, where a switch's fill steps down under the pointer and the press (`fillOpacity`). A record badge is cut out of its
mode's icon (`blendMode(.destinationOut)`), since no solid colour matches the glass under it.

**Choosing what to record** opens the mode's own control straight away, whether from a mode icon
(`pick(_:)`) or from Record (`performAction()`), both through `chooseSource(for:)`: Reco's picker for a window
(not the system's full-screen one), the area overlay to drag on. Record Screen has nothing to choose: its icon
only switches mode, and Record takes the display the bar is on (`CaptureSourcePicker.pickDisplay(_:)`, through
`currentDisplayID`, the first display if that one is gone). A choice then starts the countdown. The picker is the
windows as thumbnails above the bar in one row, at most four tiles wide (`CaptureSourceGrid.maximumColumns`), the
rest scrolled to sideways under the frost's edges, each with its app icon, title and app name, on a light frost of its own
(`pickerBackdrop()`, the raised surface) and **nothing else** — no panel with a title, no button.
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
an area is drawn, reading **Select an Area** in dim text on a plain pill without its key (`CaptureToolbarViewModel.actionTitle`;
a disabled action is never on the accent: a faded label there read as a broken button), and then takes it (`AreaSelectionOverlay.isPresented`/`canConfirm`/`confirm()`), and
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
  (which reaches the 12 pt margin past it, and the picker), so the tail's tip is 6 pt clear of the pill. Dragging the bar keeps tooltips away until
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
| `CaptureToolbar/View/CaptureToolbarController.swift` | Non-activating borderless panel, no shadow (the pills' hairline edges stand in for one), shown and hidden by the recorder's state, sized to the bar plus the picker while it is up (widened at once, narrowed after the exit), drag and momentum, the tooltip's window above the hovered control, and the picker's mount and exit |
| `CaptureToolbar/View/CaptureToolbarView.swift` | The picker above the bar, then idle / counting down (with Cancel) / recording / saving, all in the studio's dark scheme; reports the window's and the bar's own sizes |
| `CaptureToolbar/View/CaptureToolbarIdleControls.swift`, `CaptureToolbarLiveControls.swift` | The idle groups with the sliding mode highlight; the live indicators and pill |
| `CaptureToolbar/View/CaptureToolbarOptions.swift`, `CaptureToolbarMoreMenu.swift` | Countdown chip menu; system audio / mic / camera switches; Show Cursor and Settings… |
| `CaptureToolbar/View/CaptureToolbarShortcut.swift` | The keys the bar answers while it has key, and how tooltips write them |
| `CaptureToolbar/View/CaptureToolbarPill.swift`, `CaptureToolbarButtonStyle.swift`, `ToolbarIcon.swift`, `CaptureModeIcon.swift` | The pill (`editorSurface` in the surface colour, or a status tint), the press/hover/isOn button styles, the icons |

- The bar is left out of display and area recordings because it is on screen when the filter is built and
  Show Reco is off by default (`ContentFilterRules`); with Show Reco on it is recorded. Screenshots hide it
  first, instantly.

### S7 — Library, the main window (`feat/ui-polish`, spec 0010)

**Library…** in the menu bar, and clicking Reco in the Dock (`applicationShouldHandleReopen`), open Reco's
main window, which stays open unlike the popover, laid out like Eagle (2026-10-08): a see-through sidebar (All,
Recordings, Web Recordings, Exports, Screenshots, with counts), the title bar's "Library" and the shown count
(`navigationTitle`/`navigationSubtitle`, bridged with `sceneBridgingOptions = [.toolbars, .title]`), a masonry grid of
pictures, and in the toolbar search, **Filter** (Shape: Any, Landscape, Portrait, Square; Sort By: Newest First, Oldest
First, Name; its icon fills while a shape is chosen) and **New** (Capture Area/Window/Screen, Record
Area…, Record Window or Display…, New Web Recording…). With one of them open, a click on another toolbar item opens
it (`ToolbarMenuSwitcher`): AppKit's menu tracking keeps the press that closes a menu, so it took a second click; when
a menu closes with the button down over another of the window's toolbar items, the press is posted again. A click opens a movie in the
editor and a picture in Quick Look (`quickLookPreview`; the arrow keys go through the pictures shown); the context menu
opens it in Preview, shows in Finder, copies (a screenshot as PNG, a movie
as its file) or moves to the Trash with a recording's `.telemetry.json` and `.edit.json`. The grid is under date
headers, newest first (or oldest first; sorted by name it is one grid without headers): Today, Yesterday, Earlier This Week, Last Week, then a month each; Screenshots (and All) also
list the screenshot history folder (spec 0012). Down the right edge the dates repeat as a rail
(`LibraryDateRail`), adapted from Chánh Đại's Line Nav: only a short line per date, 10 pt apart, that lengthens
and brightens for the date at the top of the grid and for the one under the pointer, whose title shows to the
line's left, over the grid, in large text with no background; a click scrolls the grid to it. The grid reserves only the lines'
36 pt (12 pt lines, 20 pt marked) and hides the rail for a single date. The grid sits on the content colour (`controlBackgroundColor`): on the
window's own colour it matched the sidebar within a few levels (55 against 57 in dark mode). Tiles are pictures only,
at their own shape (`MasonryLayout`: columns at least 200 pt wide, each tile in the shortest column so far,
`MasonryPlacement`), 16:10 until the shape is read; a movie has a play badge, the name shows on hover, VoiceOver reads
name and date. Shapes are read once per item before the list shows (`LibraryStore.aspectRatios(of:)`: an image's header
with its EXIF orientation, a movie's video track with its transform), and thumbnails are drawn at that shape, 640 px
wide, up to 1280 tall. Square is within 5% (`LibraryOrientation`); with a shape chosen, an unreadable item is left out.
Which date is current is
`LibraryDateGroup.active(in:headerTops:topLine:)`, fed by each header's offset in the grid's content — a lazy grid
measures only the headers it has built, so an unmeasured date is one below the fold and is skipped — against the
scroll offset (`onScrollGeometryChange`), so state changes only when another date reaches the top. Measured
2026-10-09 (M2, Release, 266 screenshots, a scripted 15 s scroll): the headers' offsets in the scroll view, written
to state every frame, ran the grid's body (filter, sort, grouping) as often, 10–13 s of CPU. Each tile holds its own
thumbnail (the view model's cache isn't observed, so one arriving redraws one tile) and builds its ••• menu only
while hovered. The first scroll through decodes every thumbnail (a 3420×2224 PNG each), most of the CPU then.

| File | Role |
|---|---|
| `Library/Model/LibraryItem.swift` | Pure: kinds by name and type (`Reco_Web_` web, `-edited` export, `Reco_Screenshot_` PNG), companions, `LibrarySection` |
| `Library/Model/LibraryDateGroup.swift` | Pure: `groups(of:now:calendar:)`, the date headers, and `active(in:headerTops:topLine:)`, which date the rail marks |
| `Library/Model/LibraryOrientation.swift`, `LibrarySort.swift`, `MasonryPlacement.swift`, `Library/View/MasonryLayout.swift` | Pure: the Filter's shapes and orders, the grid's columns and slots; the SwiftUI `Layout` on them |
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
Collapses 500 ms after the pointer leaves. **Settings → Screenshots → History → Show Screenshots in the Notch** (default off).
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
| `AgentRecording/Model/AgentRecordingRequest.swift` | `mode`, `motion` (bundle, selection), the launch and motion-change playbooks, 30 min limit (spec 0020) |
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

### S12 — Editorial films (`remotion`, spec 0017)

A fifth kind of launch film, after ElevenLabs' "Introducing ElevenAgents Architect" (`~/Movies/Reco/references/elevenlabs-launch.mp4`):
type and print on warm paper with hairline rings, pictures far out of focus, one dark beat, hard cuts, every frame sharp, under
a film score. It ships as the `reco-editorial-film` skill, chosen when the user names ElevenLabs or asks for an editorial,
typographic or minimal film.

| File | Role |
|---|---|
| `Motion/Model/MotionField.swift`, `Render/LatticeSetup.swift`, `FieldKernels.metal.txt` (`latticeField`, `lensField`) | `paper` and `ink` (the lattice's rings, magnified in the middle, a setup a shot) and `lens` (a picture far out of focus), the `editorial` family |
| `Motion/Model/LensPicture.swift`, `Render/LensPicture+Setup.swift` | Ten pictures fitted to the film's frames; a scene's `picture`, a rectangle's `picture` (`MotionFrameRenderer.pictured`) |
| `Motion/Grammar/MoveExpansion+Editorial.swift`, `TextReveal.swift` | `sweep`, `brighten` (per-word `offsets`), `blink`, every number measured |
| `Motion/Render/ShapeMorph.swift` | `grow`: a rectangle out past the frame, its corners to 27 px |
| `Motion/Grammar/DocumentExpansion+Editorial.swift` | `unfold`: a mark, its name and a tagline opening as the film's wordmark |
| `Motion/Grammar/BurstExpansion+Editorial.swift` | `orbit` (the dark beat's stars) and `dots` (born round the sphere) as keyframed layers |
| `Motion/Render/MotionFrameRenderer+Editorial.swift`, `MotionPlan.Marks` | `marks`: registration marks under the layer they frame |
| `Motion/Model/MotionSeam.swift`, `Render/MotionFrameRenderer+Seams.swift` | `wipe`: the next scene from the right behind a soft front |
| `Motion/Sound/SoundCueSheet+Editorial.swift`, `SoundRules+Editorial.swift`, `SoundVoices+Editorial.swift` | The `editorial` score: sections, wide pads, booms, ticks, the end card's bursts |
| `AgentRecording/Skills/reco-editorial-film*.md` | The skill, the film measured, recipes, the film rebuilt as the example |

Key facts:
- **The reference, measured.** 67 s at 60 fps; no motion blur (1 px edges at 52 px a frame), so editorial films draw sharp
  (`MotionPlan.isEditorial`). Statements are dim from the cut and lit a word a frame (0.02 s + 0.045 s a character of the word
  before) as they shrink from 1.19×; labels blink on alternate frames; a card grows to the frame in 0.38 s; the picture wipe's
  front is 1000–1500 px soft and speeds up (fitted, 14 px rms); 12 stars turn at 132 → 37 → 104°/s. Its music is a G♯ film score
  without drums, −15.7 LUFS, 70 % of its energy under 60 Hz.
- **Rebuilt in the engine** (`~/Movies/Reco/quality/editorial/Architect.motion`, the skill's example, 41 s): the brighten matches
  the film frame for frame, the wordmark from its letters on, the grow's box and the stars too; lint clean; 1080p60 export 10.7 s (18.4 with motion blur).
- A filled rectangle changing its shape drew a ring part of the way (its half-side outlines mixed); two fills stay a fill.
- Marks go under the layer they frame and over what's before it: drawn on the ground, a full-frame dark shape hid them.
- In an editorial film the lint reads mono text as texture (size, contrast, hold), lets grey lines type at 115 a second and
  first moves land on their cut, and keeps the look across cuts between its grounds and plain paper.
- **From the app** (Claude Code, instalanding.ai, "an editorial launch film in the style of ElevenLabs'"): 5.5 min, a 41.3 s
  4K60 film (`~/Movies/Reco/InstaLanding 3-edited.mp4`) with every editorial move, in its own words; it kept the example's
  arc and timings scene for scene.

### S13 — The film director (`remotion`, spec 0018)

Launch films copied the films their skills learned from (InstaLanding kept ElevenLabs' 14 scenes and timings). Every Claude
Code launch run now loads `reco-director` first: a brief from the brand and the user's few words, one look, one of six story
shapes (the app sends a random `Variation`, 1–6, so a product gets a different film each run), moves from any skill, and a
bridge at every cut; it names the technique skill to write with. The engine learned what made ElevenLabs' film smooth.

| File | Role |
|---|---|
| `AgentRecording/Skills/reco-director.md`, `Model/AgentSkill.swift` | The director skill, installed with the others; the technique skills' story steps defer to it |
| `AgentRecording/Model/AgentRecordingRequest.swift` | `skillChoice` loads the director; `variation`, set at random by `AgentRecordingViewModel.submit()` |
| `Motion/Grammar/MoveExpansion+Editorial.swift`, `Render/MotionFrameRenderer+Editorial.swift` (`eaten`), `MotionPlan.Eat` | `eat`: text eaten by two bars from its ends into a block, by default into its scene's cut |
| `MoveExpansion.breath(over:)`, `MotionPlan+Grammar.swift` (`breathe`) | An editorial scene without a camera of its own but the last settles in, creeps and leaves faster |
| `Motion/Grammar/SeamExpansion.swift` (`darkenDuration`, `Transition.easing`) | A fade in an editorial film is the ground darkening in 0.18 s |

Key facts:
- **The rebuild against the film:** frozen (no pixel changing by over 6 levels) in 26.4 % of its frames before the end card
  against the film's 5.9 %, the longest freeze 1.73 s against 0.57, and 6 of its 10 cuts from a frozen frame against none.
  With eats and breathing: 14.7 %, 0.82 s.
- **Measured on the film:** after a cut a move is half done in 0.12–0.23 s; held shots creep about 2 % a second; before a cut
  things accelerate (5 % in 0.4 s); lines are eaten into the mark in 0.18–0.28 s, ease-in; the ground darkens in 11 frames; no
  dissolves.
- The editorial skill lists the scenes its look does well instead of ElevenLabs' arc, and its example says its story and
  words are ElevenLabs'.

### S14 — The brand's taste and graphic transitions (`remotion`, spec 0019)

Films looked like the films Reco learned from and changed scenes in two or three ways. A film now takes its design from the
product's website: `inspect_page` reads its font files, palette, gradients, corner radii and how its heading is set, and the
document sets text in the brand's own face (`fonts`, `style.font`). The director picks a motion personality from the brand and
the transitions it speaks in, and the engine has thirteen graphic transitions any look may use, in the brand's colours.

| File | Role |
|---|---|
| `Motion/Model/MotionSeam.swift` (`graphic`), `Grammar/SeamExpansion.swift` (`graphicDurations`, `Transition.colors`, `variant`) | `iris`, `bars`, `slats`, `tiles`, `split`, `spin`, `glitch`, `pixelate`, `liquid`, `flip`, `cube`, `flash`, `stretch` |
| `Motion/Render/TransitionRenderer.swift`, `+Space.swift`, `TransitionKernels.metal.txt` | Masks and blobs by kernel; split, flip, cube, flash, stretch with Core Image |
| `Motion/Model/StyleTokens.swift` (`seamColors`, `font`) | The accent and a second brand colour; the brand's family for every text |
| `Motion/Model/MotionFont.swift`, `Render/BrandFonts.swift`, `Service/FontCapture.swift` | Font files fetched into `assets/fonts`, read by Core Text, found by family and weight |
| `WebRecording/Service/WebInspectScript.swift`, `Model/PageInspection.swift` | `brand.fonts`, `heading`, `palette`, `gradients`, `radius` |
| `Motion/Sound/SoundCueList+Graphic.swift`, `SoundRules+Graphic.swift` | A sound each |
| `AgentRecording/Skills/reco-director.md` | The design system from the site, five motion personalities, the variation picking story, ground and signature seam |

Key facts:
- Seam colours: the accent, then the gradient's other end, or the accent 0.25 lighter or darker (OKLCH). Two seams of a
  kind go different ways (`variant`, the scene's index). Most ease on in-out quart, their parts one after another.
- Seams that cut inside themselves (pixels, glitch, dither, spin, stretch, flash) are drawn at the frame's own time:
  averaged across the shutter, a stretch's cut drew both scenes grey. Masks add their edges' travel to motion blur.
- Core Text reads WOFF2 and WOFF from data (`CTFontManagerCreateFontDescriptorsFromData`), so web fonts need no conversion;
  a variable face is set on its `wght` axis. Fonts load when a plan is captured and after each `edit_motion`.
- A font's `@font-face` is read from the page's stylesheets, fetched again when cross-origin; the Latin file of the closest
  weight; next/font's `__Inter_d65c78` is named Inter.
- Seam colours stand out from the grounds they join (≥ 0.15 apart in OKLab, else the text's or the background): a liquid in
  the accent over a scene on the accent didn't show. A split dims what's behind 0.15 on a light ground, not 0.5.
- Every film's scenes without a camera or shot of their own breathe now, not only editorial ones; a camera `hold` keeps one
  still (the golden fixtures' scenes hold). The first LemonLime film of this spec was frozen in 24.6 % of its frames.

### S15 — The After Effects bar: depth, light, flow (`remotion`, spec 0020)

Films took their brand's taste but still read as generated: a small flat card in a black void, grey bars for content, an
effect over every cut. The camera now sees a scene at an angle and arcs round it with depth of field; a dark film is lit by
a pool of light that falls on the UI too; a `flow` carries a layer into the next scene while the rest hands off in offsets;
a `swing` turns one scene away and the next in; the director holds films to the bar measured on Linear's, Raycast's,
Nothing's and Copilot's films.

| File | Role |
|---|---|
| `Motion/Model/MotionCamera.swift` (`angle`, `angledAperture`), `Render/CameraProjection.swift` (`order(of:)`) | The scene turned about where the camera looks; layers ordered by their depth before the turn |
| `Motion/Grammar/MoveExpansion+Arc.swift`, `SeamExpansion.swift` (`swingOut`, `swingIn`, `flowDuration`) | `arc` (camera move), `swing` (seam) |
| `Motion/Render/MotionPlan+Handoff.swift`, `MotionFrameRenderer+Handoff.swift` | `flow`: leaving and arriving layers' tracks, the carried layer drawn between its places, its blur |
| `Motion/Render/FieldRenderer+Pool.swift`, `FieldPalette` (`poolLift`) | `pool`: one soft light in the brand's hue, the frame falling off round it |
| `Motion/Service/DesignCheck+Craft.swift` | `smallContent` in `preview_motion`'s findings (`flatFilm` was removed by spec 0021) |
| `AgentRecording/Skills/reco-director.md` | Lit grounds, content-driven transitions, the frame and the motion (section 9) |

Key facts:
- The reference films cut and hold (8–31 cuts a film, 55–72 % of frames barely moving), change scene inside the shot, show UI
  at 4–8× cropped by the frame, light it with one pool (Linear: edges 0 of 255, middle 10–36) and keep a band 15–25 % of the
  frame in focus; none uses an iris, bars or a generic wipe. The graphic seams are now at most one a film.
- Ordered after the camera's turn, the far side of a card lying back was farther than its middle and the card hid what was on
  it; placements are ordered by depth before the turn.
- A camera at an angle has depth of field (aperture 3) unless keyed.
- Flow's layers leave from 0.12 s before the cut: leaving from it, the scene before stood whole under the next's first
  layers for a fifth of a second. A layer with the same id in both scenes travels between its places; a plain rectangle
  changes size, corners and colour on the way.
- The whip finder counts the camera's turn as a pan, so a swing sounds as a whip.

### S16 — Films are actions (`remotion`, spec 0021)

Cardboard 5 (spec 0020) was static: UI on tilted cards, its parts rising in, then sitting there under a slow push. The films the
user liked (Cal.com's story film, the Spotify Jam film, ElevenLabs') change their picture all the time because every scene does
something. The director has the agent write the film as actions first and frames UI facing the viewer; `preview_motion` names
every stretch in which the picture stands still.

| File | Role |
|---|---|
| `Motion/Service/DesignCheck+Change.swift`, `ContactSheet.levels(of:)` | `stillPictures`: the plan read 10 times a second at 32 × 18; a film still over 25 % of the time, a scene still over 1 s |
| `AgentRecording/Skills/reco-director.md` | Sections 7–10: the film as actions, transitions with a reason, UI facing the viewer, the check |

Key facts:
- Pixel change and the lint's idle stretches don't separate liked films from static ones: Cardboard 5's staggered entrances
  kept every scene changing somewhere. The picture at 32 × 18, half a second apart (mean luma change under 2 of 255 is still)
  does: Cal.com's story film is still 11 % of the time, Spotify Jam 19 %; Cardboard 5 40 %, Cardboard 2 64 %.
- Through the engine at 270 px, Calcom 3 has no finding and Cardboard 5 five scenes; about 5 s more a preview (M5, Debug).
- `flatFilm` is gone: it asked for UI at an angle, which the user found looks bad.

### S17 — Transitions that read (`remotion`, spec 0022)

Cardboard 6's expand and stacks read as dim fades on its dark ground. Expand is now a container transform (the clicked control
grows in its own shape in a rectangle of its colour, which turns to the next scene's as that comes up in it), a stack's sheet has
a lit edge and pushes the scene before up, and both have a light edge on dark. Seams are sized by the frame. The lint names a
stack, expand or dive whose scene is mostly not there yet (`carried`), and the director never cuts onto an empty ground.

| File | Role |
|---|---|
| `Motion/Render/MotionFrameRenderer+Seams.swift` | `expanded` (container transform), `stacked` (lit edge, lift), `edgeLight`; both frames cut to the frame in `transitioned` |
| `Motion/Grammar/MotionLint.swift` (`carriedFindings`) | Half a carried scene's parts missing by its seam's middle is named |
| `AgentRecording/Skills/reco-director.md` | Section 8: no cut onto an empty ground, match cuts, carried scenes whole |

Key facts:
- A scene's image can be larger than the frame (layers past it); stack and expand sized from it drew the next scene at two
  thirds of its rectangle.
- The control grows at most 2.5× (further, its pixels blur), is gone by 0.35 of the way; the colour turns 0.1–0.55, the next
  scene comes up 0.25–0.7. A control shorter than an eighth of the frame starts round; a card keeps 0.3 of its shorter side.

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
| S1 editor phase 6: canvas and export polish | Done; the canvas, gradient presets, wallpapers (and one after relaunch), picture blur, the border, a background picture after relaunch, HDR recordings (ProRes too, whose frames carry the tags) and transparent exports still need a check in the app |
| S1 editor design: system colors, glass transport, new timeline and inspector | Done; replaced by the Linear theme |
| Linear theme (`feat/linear-theme`): tokens, light mode from Default's tokens, Inter + JetBrains Mono, solid surfaces app-wide | Done 2026-10-08; built, 982 tests; colours from `theme/theme.tokens.json`; needs a look in the app in light, dark and Increase Contrast |
| C1 screenshots (area, window, screen) | Done, verified on real captures; each shot opens the Quick Access card and is saved only from it |
| S2 web recordings (spec 0005) | Done and tested; the window's view model was driven end to end on apple.com (pick, render, editor, export). The window itself (buttons, timeline dragging, pick banner) still needs clicking through by hand |
| S3 agent bridge (spec 0006): MCP server for coding agents | Done; tested over the real socket (token, `initialize`, `tools/list`, error calls), the `--mcp` process, config editors and plans. Not yet tried: real agents connected by hand, a real `record_page` render, Gatekeeper on another Mac |
| S7 Library (spec 0010): main window | Done and tested; the window itself still needs a look in the app |
| S4 agent recording (spec 0007): Record with AI Agent bar, no App Sandbox | Done and tested with fakes and real `/bin/sh` processes; the login-shell environment was read on this Mac (0.86 s). Not yet tried: any real agent run, the panel in the app (focus, Esc, picker menus, Reduce Motion/Transparency), the update from the sandboxed release (migration), Codex |
| S5 agent chat and reliable web takes (spec 0008) | Done and tested: real Claude Code runs from the prompt and from the chat in the app (sent through accessibility), 60 s apple.com takes checked frame by frame. Not yet tried: Retry and Cancel by hand, VoiceOver, Reduce Motion, other agents |

| Spec 0009 batch 1: cursor loop/hold/tilt, motion blur, GIF, copy frame, `export_recording`, type steps, shown elements, playbook | Done and tested; a real web take was exported as GIF and HEVC and its frames checked (zoom blur, cursor trail, tilt, loop); linear.app walkthroughs run from the app through `reco://record-agent`. Not yet tried: the new controls in the app, a GIF of a long recording, typing on real sites (React forms, search boxes), `export_recording` from a real agent |
| S6 motion editor (spec 0011): launch videos as motion design from the real UI | Phases 0 and 1 done: benchmark, spikes, document, renderer, preview and export. Phase 2 done: lifts, live layers, media on the take's clock, `hide`, sign-in, `brand`. Phase 3 done: moves, seams, shots, lint, scenes lane and inspector; the benchmark rebuilt in 10 lines and three sites rendered, awaiting the user's side-by-side. Phase 4 done: agent tools, Launch Video mode, chat with selection; three sites run from their address with clean lint and design check, three chat edits change only their targets; cost recorded for one run. The window seen in a window capture; editing by hand not yet tried |
| S7 motion quality (spec 0012) | Motion reel picked. Q2.1 fields ported, then rejected by the user as pasted behind the old video; directions picked from launch films (Raycast, Nothing OS 5.0, 3D layers). L1a–c built (satin, coverage mattes, typing cursor rules, parallax, motion blur), but the user found the test shot "really bad" next to Raycast. L0: still frames matched to Raycast's (glass for lifted UI, hero scale, a better ground), then a 24 s Supabase docs film in that look rendered as a look-dev pass outside the engine. The user approved the film; its port into the engine has begun: phases 1 (satin, grain), 2 (glass, sharp macro) and 3 (typing, caret, results) done, matching the film at 47–64 dB; phase 4 captures UI behind a click and typing states live (Supabase's search, matching the film's lifts); phase 5 the selection, the camera following it, the whip's blur; phase 6 the `closing` shot; the whole film now made by the app from one document, matching the approved one where the site is the same. L4/Q4: the film's grammar named (`macro` views, `whip` move and seam, mockup typing) and its method shipped as the `reco-launch-film` skill; Launch Video runs on linear.app from the address make macro films on glass over satin. Looks: light and dither grounds (Paper's other shapes) and seams in their language (`glow`, `dither`, `ring`), the agent choosing the look from the brand. Next: the user's verdict on them |
| S8 motion sound (spec 0013) | S1–S4 done: cue sheet from the plan, voices, room, finish, loudness, cache, preview and export, `set_sound`, the Sound section; the Supabase film's sheet matches the hand-made score. Next: the user's listening round (S5) |
| S9 motion design (spec 0014) | D1–D5 done: morphs, floods, pops, clicks, bursts, ripples, letters, kinetic type, scrolls; their sounds; the `reco-motion-design` skill with references read on demand; look-dev matching the Spotify Jam reference. D6: a Spotify film made from the app (9 min, 30 s 4K, every named movement). D7: smoother after the user's review (letters, flood, bands, sharp particles, pointer, spin, chained pans, stillness lint, skill and example rebuilt). Next: the user's verdict |
| S10 story films and score styles (spec 0015) | Reference measured (picture and music; the Spotify Jam's music too); `aurora`, the brand gradient, voice, reply, shimmer, wash, scatter, show/hide, UI glyphs, the hand in macro; `groove` and `house` scores fitted to the cuts; the `reco-story-film` skill; the reference rebuilt in the engine and checked frame by frame; `beats` lint. Orca ADE made from the app twice; the user found it "really bad". Rebuilt by hand to Lovable's bar (stills checked), and the engine (elongated aurora lights, SVG marks with `tint`, text-off-frame check) and skill (answers as coloured things, Lovable's type sizes) changed to match. A third run from the app follows the new recipes. The user found it short still: the look now comes from the product's theme over Reco's shader looks (Orca: `warp` dither, its seams, the halo), Lovable giving only the motion; the shutter swap fix, the opening's arrival, and the overlapping-text check. Then glass cards, a corner wash, 60 fps and a wider groove after the user's notes; then a sound for each transition instead of a beat. Next: the user's verdict, a listening round |
| S11 flow films (spec 0016) | Both reels measured; `haze`, `dive`, `melt`, `fly`, `select` and their sounds; the `reco-flow-film` skill with Vantae's reel rebuilt as its example and IrukaDark's pieces checked; the default for light products. Next: films from the app, the user's verdict |
| S12 editorial films (spec 0017) | ElevenLabs' film measured (picture and score); `paper`, `ink`, `lens` and pictures in shapes; `wipe`; `sweep`, `brighten`, `blink`, `grow`, `marks`, `orbit`, `dots`, `unfold`; the `editorial` score; the film rebuilt and checked against its frames; the `reco-editorial-film` skill; a film made from the app (InstaLanding, 5.5 min, 41 s 4K). Next: the user's verdict, a listening round |
| S13 film director (spec 0018) | The director skill, the variation, `eat`, breathing, the darkening; the rebuild's frozen frames 26 → 15 %. A LemonLime (YC S26) film from the app; the user found it ElevenLabs' again (spec 0019) |
| S14 brand taste and graphic transitions (spec 0019) | Thirteen graphic seams in the brand's colours, the brand's fonts, palette, gradients and radii scraped and its type drawn in its own face, the director's personalities and variation. Next: films from the app, the user's verdict |
| S15 the After Effects bar (spec 0020) | Camera angle, arc and depth of field, `swing`, `flow` (shared element and layered handoff), the `pool` ground, small and flat checks, the director's craft section, after the user found Cardboard 2 basic. Next: Cardboard from the app, the user's verdict |
| S16 films are actions (spec 0021) | The picture-still check in `preview_motion`, the director rewritten around actions and UI facing the viewer, after the user found Cardboard 5 static. Next: Cardboard from the app, the user's verdict |
| S17 transitions that read (spec 0022) | Expand as a container transform, a lit stack, seams sized by the frame, the `carried` lint and the director's cut rules, after the user asked for better transitions on Cardboard 6. Next: the user's verdict on `Cardboard 6 carried`, a new film from the app |

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
