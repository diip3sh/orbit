# Reco: Feature Audit, Gap Analysis, and Roadmap vs Screen Studio and CleanShot X

Scope: local checkout at `/Users/dip3sh/Documents/BetterCapture` (fork of `jsattler/BetterCapture`, MIT).
Compared against: Screen Studio ($29/mo or $108/yr) and CleanShot X ($35 one-time Basic, $10/user/mo Pro).
Reference repos checked against the live GitHub API: `syi0808/screenize`, `imbhargav5/open-recorder`, `lzhgus/Capso`, `lihaoyun6/QuickRecorder`.

---

## 0. TL;DR

- Reco today is a **very solid capture core** (ScreenCaptureKit + AVAssetWriter): pro codecs (ProRes 422/4444, HEVC alpha), HDR10, constant-frame-rate writer, separate audio tracks, area selection, Presenter Overlay, global shortcuts, URL scheme. It has **zero post-processing**: no editor, no zoom, no cursor effects, no screenshots, no annotation.
- Screen Studio's value is the **automatic editor** (auto-zoom, cursor smoothing, backgrounds). CleanShot X's value is the **screenshot workflow** (quick-access overlay, annotate, scrolling capture, OCR, cloud links). Neither exists here yet.
- The single biggest change is architectural: move from "record straight to a finished .mov" to **"record a project (raw video + cursor/click/key telemetry + audio tracks) then render"**. Every Screen Studio feature depends on this.
- Count of work: **8 foundation changes, 19 Screen Studio parity features, 14 CleanShot X parity features, 8 differentiators = 49 items**. Rough estimate for one experienced Swift dev: **26 to 34 engineer-weeks** for everything, **~10 to 12 weeks** for a credible "free Screen Studio" MVP.
- Two hard constraints shape everything:
  1. **The app is sandboxed** (for Mac App Store). None of the reference apps are. Keystroke capture, Accessibility-based smart zoom, and auto-scrolling capture are restricted in the sandbox.
  2. **Licenses**: Screenize and open-recorder are Apache-2.0 (code can be ported with attribution). Capso is **BSL 1.1 with a clause forbidding use in a "Screen Capture Service"**, so it is **read-for-ideas only, never copy**. QuickRecorder is **AGPL-3.0**, also ideas only.
- Upstream maintainer stance: GIF export (#188) was closed as "not planned" because the vision is "a small and stable core" with plugins. So this roadmap is a **fork direction**, not something upstream will merge.

---

## 1. Codebase snapshot

| Item | Value |
| --- | --- |
| Language / UI | Swift, SwiftUI + AppKit panels, `@Observable` MVVM |
| Deployment target | macOS 15.2 |
| Swift language mode in `project.pbxproj` | `SWIFT_VERSION = 5.0` (AGENTS.md says Swift 6.2 strict concurrency, so this is out of sync) |
| Size | 34 Swift source files, ~7.5k lines app code, 11 test files, 144 tests |
| Dependencies | Sparkle 2.7+ (updates), sindresorhus/KeyboardShortcuts 3.0.1+ |
| Distribution | Sandboxed app (`com.apple.security.app-sandbox`), Homebrew, Sparkle appcast |
| Entitlements | sandbox, user-selected files r/w, Movies r/w, audio-input, camera, network.client |
| App type | Menu bar agent (`LSUIElement = true`) |
| README.md | Empty (1 byte) in this checkout |

Architecture (from `docs/architecture/OVERVIEW.md`):

```
MenuBarView / SettingsView
        |
RecorderViewModel  <->  SettingsStore
        |
CaptureEngine (SCStream) --samples--> AssetWriter (AVAssetWriter) --> .mov/.mp4
   |  ContentFilterService, SystemAudioStream
PreviewService, AudioDeviceService, CameraDeviceService/CameraSession,
PermissionService, NotificationService, UpdaterService
```

Key point: `CaptureEngine` pushes `CMSampleBuffer`s straight into `AssetWriter`, which writes the final file. There is no intermediate project, no metadata sidecar, and no render step.

---

## 2. Features present today

### 2.1 Capture sources

| Feature | Where | Notes |
| --- | --- | --- |
| Display / window / app picking via system `SCContentSharingPicker` | `Service/CaptureEngine.swift` (`setupPicker`, `presentPicker`) | Excludes own bundle ID |
| Custom area selection with drag, resize handles, confirm/cancel | `View/AreaSelectionOverlay.swift` (774 lines), spec `docs/specs/0001-area-selection.md` | Min 24x24 pt, even-pixel snapping, uses `SCStreamConfiguration.sourceRect` |
| Multi-display aware area selection | `RecorderViewModel.presentAreaSelection()` | Picks display under cursor, flips coordinates |
| Selection border frame during recording | `View/SelectionBorderFrame.swift` | |
| Pre-record overlay (preview + Start/Dismiss) | `View/RecordingOverlayPanel.swift`, `RecordingOverlayView.swift` | |
| Live preview thumbnail in menu bar | `Service/PreviewService.swift`, `View/PreviewThumbnailView.swift` | |
| Correct scale for windows on non-primary displays | `CaptureSizeCalculator.windowScale`, `RecorderViewModel.pointPixelScale` | Fixes SCK misreport |
| Native (Retina) vs logical resolution | `SettingsStore.captureNativeResolution` | |

### 2.2 Content filtering

| Feature | Where |
| --- | --- |
| Show/hide cursor, wallpaper, menu bar, Dock, window shadows, Reco itself | `Service/ContentFilterService.swift`, `Service/ContentFilterRules.swift`, `MenuBarSettingsView` |
| Display-disconnect detection before start | `ContentFilterService.isSelectedDisplayConnected` |

Not covered: hiding **desktop icons** (Finder desktop windows are not filtered, only the Dock-owned wallpaper window).

### 2.3 Audio

| Feature | Where |
| --- | --- |
| System audio capture | `CaptureEngine` (`capturesAudio`) |
| Dedicated full-display audio stream when recording a window/app (so you hear all apps, not only the selected one) | `Service/SystemAudioStream.swift` |
| Microphone with device picker | `Service/AudioDeviceService.swift`, `SettingsStore.selectedMicrophoneID` |
| System audio and mic written as **separate tracks** | `AssetWriter.appendAudioSample` / `appendMicrophoneSample` |
| AAC or PCM | `AudioCodec` in `SettingsStore` |
| Head-of-track silence padding for A/V alignment | `Service/SilentAudioBuffer.swift`, `AssetWriter.padWithSilence` |
| Notification when system audio fails mid-recording | `NotificationService.sendSystemAudioFailedNotification` |

### 2.4 Video / encoding (the strongest part of the codebase)

| Feature | Where |
| --- | --- |
| H.264, HEVC, ProRes 422, ProRes 4444 | `VideoCodec` in `SettingsStore` |
| MOV and MP4 with automatic compatibility fixing | `SettingsStore` setters, `docs/architecture/OUTPUT.md` |
| Alpha channel (HEVC with alpha, ProRes 4444) | `captureAlphaChannel` |
| HDR10 (BT.2020 + PQ), macOS 26 preset and macOS 15 manual path, per-frame tagging for ProRes | `HDRPreset`, `AssetWriter`, `docs/screen-capture-kit/HDR.md` |
| Quality presets via bits-per-pixel | `VideoQuality` |
| Frame rate native / 24 / 30 / 60 | `FrameRate` |
| **True constant-frame-rate track** (grid snapping + frame duplication, stall cap 10 s) | `AssetWriter.drainVideo`, `capFillIfStalled` |
| BT.709 tagging for SDR | `AssetWriterSettings` |

### 2.5 Camera

| Feature | Where |
| --- | --- |
| Presenter Overlay (system-composited camera) + camera picker | `Service/CameraSession.swift`, `CameraDeviceService.swift`, spec `docs/specs/0002-presenter-overlay.md` |

Limitation: the camera is **baked into the screen frames by macOS**. There is no separate camera track, so it cannot be moved, resized, or restyled after recording.

### 2.6 Workflow, automation, reliability

| Feature | Where |
| --- | --- |
| Global shortcuts: Toggle Recording, Select Content, Select Area (no defaults) | `AppDelegate.registerKeyboardShortcuts`, ADR `docs/decisions/0001` |
| Smart toggle (opens picker/area if nothing selected) | `RecorderViewModel.toggleRecording` |
| URL scheme: `reco://toggle`, `toggle-copy`, `open-recordings` | `AppDelegate.handle(_:)` |
| Copy finished file to clipboard | `RecorderViewModel.copyFileToClipboard` |
| Custom output folder (security-scoped bookmark) | `SettingsStore.setCustomOutputDirectory` |
| Notifications with "open folder" action, audio-only warning | `Service/NotificationService.swift` |
| Graceful save when user clicks system "Stop Sharing" | `captureEngine(_:didStopWithError:)` |
| Permissions UI (screen, mic, camera) | `Service/PermissionService.swift`, `MenuBarView` |
| Auto updates | `Service/UpdaterService.swift` (Sparkle) |
| Unit tests for codec/container/HDR rules, size calc, filter rules, writer | `RecoTests/` |

---

## 3. Gap matrix vs Screen Studio and CleanShot X

Legend: **Yes** = present, **Partial** = something exists but not at parity, **No** = missing.

| Capability | Screen Studio | CleanShot X | Reco |
| --- | --- | --- | --- |
| Display / window / area recording | Yes | Yes | **Yes** |
| System audio + mic | Yes | Yes | **Yes** (separate tracks) |
| ProRes / HDR / alpha capture | No transparent export | No | **Yes (better than both)** |
| Pause / resume | Yes | Yes | No (issue #174) |
| Countdown before recording | Yes | Yes | No |
| Webcam overlay | Yes (editable) | Yes (bubble) | Partial (Presenter Overlay only, baked in) |
| iPhone / iPad recording over USB with device frame | Yes | No | No |
| Auto-zoom on clicks / actions | Yes | Yes ("smart zooms") | No |
| Manual zoom segments on timeline | Yes | Yes (Studio Mode) | No |
| Cursor smoothing, resize after recording, hide idle cursor, loop | Yes | No | No |
| High-res cursor replacement | Yes | No | No |
| Click highlight | Yes | Yes (live) | No |
| Keystroke overlay | Yes | Yes (live) | No |
| Motion blur | Yes | No | No |
| Background, padding, rounded corners, shadow, inset | Yes | Yes (screenshots) | No |
| Trim / cut / speed up | Yes | Yes | No |
| Vertical / aspect-ratio export | Yes | No | No |
| Noise removal / volume normalization | Yes | No | No |
| Transcript / subtitles | Yes | Yes (Cloud) | No |
| GIF export | Yes | Yes | No (upstream said not planned) |
| Export presets (web, social, editing) | Yes | Partial | Partial (codec/quality presets only) |
| Shareable link | Yes | Yes (Cloud, custom domain, SSO) | No |
| Shareable style presets | Yes | Yes (background presets) | No |
| Screenshots (area/window/fullscreen) | No | Yes | No |
| Quick Access overlay (floating thumbnail, drag out) | No | Yes | No |
| Annotation (arrows, text, shapes, steps, highlight, spotlight) | No | Yes | No |
| Redact / pixelate / blur | No | Yes | No |
| Scrolling capture | No | Yes | No |
| OCR / QR reading | No | Yes | No |
| Pin screenshot on top | No | Yes | No |
| Capture history | No | Yes | No |
| Hide desktop icons | Yes | Yes | No |
| URL scheme / automation | Partial | Yes | **Yes (small)** |
| Global shortcuts | Yes | Yes | **Yes** |
| Price | $108/yr | $35 + $19/yr updates | **Free, MIT** |

---

## 4. Required foundation changes (do these first)

These are not user-visible "features" on their own, but every Screen Studio feature depends on them.

### F1. Cursor, click, and input telemetry recording (sidecar file)
- **What**: While recording, sample cursor position at the capture frame rate and record clicks (and later keys, scrolls) with timestamps aligned to the video timeline. Save as `cursor.json` next to the video.
- **Why**: Auto-zoom, cursor smoothing, cursor resize, click highlights all come from this data, not from pixels.
- **Reference logic**:
  - `imbhargav5/open-recorder` `apps/macos/Sources/OpenRecorderMac/CursorTelemetryRecorder.swift` (Apache-2.0, **portable**). Cleanest fit: `CursorTelemetrySample`, `CursorTelemetryClick`, `CursorTelemetryPayload`, `telemetryURL(for: videoURL)` writes a sidecar, `alignStart(to:)` aligns to media start, `NSEvent` click monitors.
  - `syi0808/screenize` `Screenize/Core/Recording/MouseDataRecorder.swift` (Apache-2.0): `NSEvent.mouseLocation` polled by a timer at `min(captureFrameRate, 120)` Hz, plus `pauseRecording()` / `resumeRecording()`. Event handlers in `Core/Recording/EventHandlers/` (Click, Drag, Keyboard, Scroll), `Core/EventMonitoring/EventMonitorManager.swift` wraps `NSEvent.addGlobalMonitorForEvents`.
- **Fit into Reco**: new `Service/CursorTelemetryRecorder.swift`, started/stopped from `RecorderViewModel.startRecording()` / `stopRecording()`. Align using the `AssetWriter.sessionAnchor` (first sample PTS) so telemetry and video share time zero.
- **Sandbox**: cursor polling is fine. Global **mouse** monitors do not need Accessibility per Apple docs (only key events do), but **verify inside the sandbox**. See section 7.
- **Effort**: S-M (3 to 5 days).

### F2. Record cursor-less video plus cursor sprites
- **What**: When the editor is enabled, force `SCStreamConfiguration.showsCursor = false` and store the cursor image (`NSCursor.currentSystem`) changes in telemetry, so the cursor can be re-rendered bigger/smoother/hidden later.
- **Reference**: `screenize/Screenize/Render/CursorImageProvider.swift` and `CursorImageProvider+HandCursors.swift` (Apache-2.0), `open-recorder/.../CursorPresetRenderer.swift`, `CursorOverlayGeometry.swift`.
- **Fit**: `CaptureEngine.createStreamConfiguration` already sets `config.showsCursor = settings.showCursor`; add an "editable cursor" mode that overrides it.
- **Effort**: S (2 to 3 days).

### F3. Project bundle format
- **What**: A `.reco` package directory: `screen.mov` (raw), `camera.mov` (optional), `system.m4a` / `mic.m4a` (or keep tracks in the mov), `cursor.json`, `events.json`, `project.json` (edits: trims, zooms, style). Keep "Quick record" mode that still writes a plain .mov directly, so the current fast path is not lost.
- **Reference**: `screenize/Screenize/Project/` (`PackageManager.swift`, `ScreenizeProject.swift`, `ProjectManager.swift`, `MediaAsset.swift`, `RenderSettings.swift`), `open-recorder/.../ProjectAutosave.swift`, `ProjectsViews.swift` (project library). Capso `Packages/EditorKit/Sources/EditorKit/RecordingProject.swift` for ideas only.
- **Fit**: new `Model/Project/` folder; `SettingsStore.generateOutputURL()` becomes project-aware; register the UTType in Info.plist.
- **Effort**: M (1 week).

### F4. Pause / resume (open issue #174)
- **What**: Pause stops appending samples; on resume, subtract paused duration from every track's PTS.
- **Reference**: Screenize `MouseDataRecorder.pauseRecording/resumeRecording` (telemetry side). Reco's `AssetWriter.rebase(_:)` already rebases against `sessionAnchor`, so extend it with an accumulated `pausedDuration` offset and keep the CFR grid index continuous.
- **Effort**: S-M (3 to 4 days, mostly tests for A/V sync).

### F5. Countdown before recording
- **Reference**: `screenize/Screenize/Views/Recording/CountdownPanel.swift`, `open-recorder/.../RecordingCountdownOverlay.swift`.
- **Effort**: S (1 day).

### F6. Audio robustness from open issues
- Mic device hot-swap mid-recording (#208), mic gain / auto level (#209), live level meters (#153).
- **Reference**: `open-recorder/.../CaptureAudioFeedback.swift`; for levels, compute RMS from the mic `CMSampleBuffer` in `AssetWriter.appendMicrophoneSample` and publish to the UI.
- **Effort**: M (1 week).

### F7. Remember content selection between sessions (#172)
- Persist the last display ID / window ID / area rect in `SettingsStore`, re-resolve via `SCShareableContent` on launch.
- **Effort**: S (1 to 2 days).

### F8. Swift 6 language mode + feature-folder layout
- `project.pbxproj` has `SWIFT_VERSION = 5.0` while AGENTS.md mandates Swift 6.2 strict concurrency. Flip it before adding a large editor, otherwise new concurrency code will pile up warnings later.
- New large features should live in feature folders or local SPM packages (`Editor/`, `Telemetry/`, `Screenshot/`, `Annotation/`), per AGENTS.md "folder layout determined by app features". Current code is layer-based (`Model/Service/View/ViewModel`); leave existing files as they are.
- **Effort**: S-M (2 to 5 days depending on warnings).

**Foundation subtotal: 8 changes, ~3 to 4 weeks.**

---

## 5. Missing features for Screen Studio parity

Recommended render architecture (one code path for preview and export, avoids "preview looks different from export" bugs): an `AVVideoCompositing` custom compositor using a Metal-backed `CIContext`. Attach the same compositor to an `AVPlayerItem` for preview and to `AVAssetExportSession` / `AVAssetReader+AVAssetWriter` for export. Screenize uses a Metal pipeline (`Render/RenderPipelineFactory.swift`, `Views/MetalPreviewView.swift`) if more control is needed later.

| # | Feature | Reference logic to check out | License | Effort |
| --- | --- | --- | --- | --- |
| S1 | **Editor window with preview player** | Screenize `Render/PreviewEngine*.swift`, `Views/EditorMainView.swift`, `Views/PreviewView.swift`; open-recorder `SceneVideoPreview.swift`, `EditorViews.swift` | Apache | L (2 wks) |
| S2 | **Timeline: trim, cut, speed segments** | Screenize `Timeline/` (`Timeline.swift`, `Track.swift`, `Segments.swift`, `Keyframe.swift`, `EasingCurve.swift`) + `Views/Timeline/` (`TrimHandleView.swift`, `PlayheadView.swift`); open-recorder `TimelineEditing.swift`, `TimelineViews.swift`, `TimelineAudioWaveform.swift` | Apache | L (2 wks) |
| S3 | **Auto-zoom generation** | Start simple with open-recorder `AutoZoomGenerator.swift`: click + dwell heuristics with clear constants (`leadInSeconds = 0.6`, `holdAfterClickSeconds = 1.4`, `mergeThresholdSeconds = 1.5`, `minimumDurationSeconds = 2.0`, `exitSeconds = 0.7`, `defaultDepth = 2.0`). Upgrade later to Screenize's pipeline: `Generators/SmartGeneration/Analysis/IntentClassifier.swift` (typing/navigating/idle spans), `Planning/ShotPlanner.swift`, `ContinuousCamera/SpringDamperSimulator.swift` (60 Hz spring camera), `DeadZoneTarget.swift` (camera only moves when cursor leaves a safe zone, with hysteresis) | Apache | L (1.5 to 2 wks) |
| S4 | **Manual zoom segments** (drag on timeline, set depth and easing) | Screenize `Generators/SegmentCamera/`, `ViewModels/EditorViewModel+SegmentOperations.swift`, `Views/Inspector/InspectorView+CameraSection.swift`; open-recorder `TimelineZoomTransition.swift`, `TimelineZoomAnimationPreset.swift` | Apache | M (1 wk) |
| S5 | **Cursor smoothing, resize after recording, hide when idle, loop to start** | Screenize `Render/SpringCursorSimulator.swift` (analytic damped harmonic oscillator, `damping`, `response`, adaptive response for fast moves), `Render/MousePositionInterpolator.swift`, `Generators/SmartGeneration/SmoothedMouseDataSource.swift`; open-recorder `CursorTelemetryTrack.normalizedPoint(at:loops:smoothing:)` | Apache | M (1 wk) |
| S6 | **High-res system cursor replacement** | Screenize `Render/CursorImageProvider*.swift`; open-recorder `CursorPresetRenderer.swift` | Apache | S |
| S7 | **Click highlight / ripple** | Screenize `Render/FrameEvaluator+ClickState.swift` | Apache | S |
| S8 | **Keystroke overlay** | Screenize `Render/FrameEvaluator+Keystroke.swift`, `Generators/SmartGeneration/Emission/KeystrokeTrackEmitter.swift`, `Core/Recording/EventHandlers/KeyboardEventHandler.swift` | Apache | M (sandbox risk, see section 7) |
| S9 | **Motion blur on zoom/pan** | Screenize `Render/MotionBlurSettings.swift`, `Render/EffectCompositor.swift` (CIMotionBlur scaled by camera velocity) | Apache | M |
| S10 | **Background, padding, inset, rounded corners, shadow** | Screenize `Render/BackgroundRenderer.swift`, `WindowEffectApplicator.swift`, `WindowModeRenderer.swift`; open-recorder `VideoBackgroundCompositor.swift`, `BackgroundPresets.swift`, `VideoRoundedMaskCache.swift`, `VideoStaticBackgroundCache.swift` | Apache | M (1 wk) |
| S11 | **Aspect ratio / vertical export with auto reframing** | open-recorder `VideoCropSelection.swift`, `VideoCropDialog.swift`; Screenize `Project/RenderSettings.swift` | Apache | M |
| S12 | **Editable webcam bubble on its own track** (keep Presenter Overlay as an option) | open-recorder `FacecamRecorder.swift`, `CameraLayout.swift`, `CameraLayoutMotion.swift`, `CameraLayoutTransition.swift`, `CameraFaceFraming.swift` (Vision face framing), `CameraBubbleViews.swift`. Add an `AVCaptureVideoDataOutput` to the existing `CameraSession` and write `camera.mov` | Apache | M-L |
| S13 | **Noise removal + loudness normalization** | No direct reference. Use `AVAudioEngine` voice processing (`inputNode.setVoiceProcessingEnabled(true)`) at record time, or offline: measure loudness then apply gain in export via `AVAudioMix` / `AVMutableAudioMixInputParameters`. Screenize `Render/AudioMixer.swift` for track mixing | Apache (mixer) | M |
| S14 | **Transcript + subtitles (on-device)** | open-recorder `Captions.swift`, `CaptionServices.swift`, `CaptionRenderer.swift`, `CaptionInspector.swift`. Engine: Apple `SpeechAnalyzer` (macOS 26) with `SFSpeechRecognizer` on-device fallback. Needs `NSSpeechRecognitionUsageDescription` | Apache | M-L |
| S15 | **GIF export** | Screenize `Render/GIFEncoder.swift`, `ExportEngine+GIFExport.swift` (ImageIO `CGImageDestination`) | Apache | S |
| S16 | **Export presets (Web, Social, Edit, 4K60)** | Screenize `Render/ExportEngine*.swift`, `Views/ExportView+Settings.swift`; open-recorder `VideoExportOptions.swift`, `VideoExportStateMachines.swift`, `ExportFileSafety.swift`. Reuse Reco's existing `AssetWriterSettings` + codec rules for output | Apache | M |
| S17 | **iPhone/iPad over USB with device frames** | Enable CoreMediaIO screen devices (`kCMIOHardwarePropertyAllowScreenCaptureDevices`), then capture as an `AVCaptureDevice` (external, muxed). QuickRecorder `ViewModel/iDeviceSelector.swift` shows the approach (**AGPL, ideas only**). Device frame PNGs must be sourced separately (Apple Design Resources terms apply) | Ideas only | M-L |
| S18 | **Undo / redo** | Screenize `ViewModels/UndoStack.swift`; open-recorder `EditorHistory.swift` | Apache | S |
| S19 | **Shareable style presets** | Screenize `Project/PresetManager.swift`, `RenderSettingsPreset.swift`, `Views/Inspector/PresetPickerView.swift` | Apache | S |

Also small: **hide desktop icons** during capture (exclude Finder desktop-level windows in `ContentFilterRules`), S, half a day.

**Screen Studio parity subtotal: 19 features, ~12 to 16 weeks.** MVP subset (S1, S2, S3, S5, S10, S15, S16, S18) is ~6 to 8 weeks on top of the foundation.

---

## 6. Missing features for CleanShot X parity

Note: no Apache-licensed reference covers most of this well. Capso does, but its **BSL 1.1 license forbids using it for a "Screen Capture Service"**, so use it only to understand the approach and write your own code. open-recorder has a screenshot flow and editor (Apache) that can be ported for the basics.

| # | Feature | Reference logic to check out | License | Effort |
| --- | --- | --- | --- | --- |
| C1 | **Screenshots: area / window / fullscreen** | Use `SCScreenshotManager.captureImage(contentFilter:configuration:)` and reuse Reco's existing `AreaSelectionOverlay` + picker. Port from open-recorder `ScreenSelectionOverlay.swift`, `ScreenshotEditorState.swift`. Capso `Packages/CaptureKit/.../ScreenCaptureManager.swift` (ideas only) | Apache / ideas | M |
| C2 | **Quick Access overlay** (floating thumbnail: copy, save, annotate, drag out, dismiss) | Capso `App/Sources/QuickAccess/` (`QuickAccessWindow.swift`, `QuickAccessDragSourceView.swift`) and `SharedKit/Utilities/QuickAccessStackGeometry.swift` (ideas only). Write with an `NSPanel` + `NSDraggingSource` using `NSFilePromiseProvider` | Ideas only | M |
| C3 | **Annotation editor**: arrow, line, rectangle, ellipse, text, numbered steps, freehand, highlight, spotlight | Capso `Packages/AnnotationKit/` (`AnnotationDocument`, `AnnotationObject`, `Objects/ArrowObject`, `CounterObject`, `PixelateObject`, `Helpers/BezierSmoothing`) shows a clean object model (ideas only). open-recorder `ScreenshotEditorViews.swift` (Apache) for the basics. Build as a `Canvas`/Core Graphics document model with Codable objects | Ideas / Apache | L (2 wks) |
| C4 | **Redact: pixelate / blur regions** | Capso `Objects/PixelateObject.swift` (ideas). Implement with `CIPixellate` / `CIGaussianBlur` masked to rect. Reuse in video editor as a blur track (Capso `Editor/BlurRegionOverlay.swift`, ideas) | Ideas | S-M |
| C5 | **Background tool for screenshots** | Port open-recorder `ScreenshotExportRenderer.swift`, `BackgroundPresets.swift` (Apache). Shares code with S10 | Apache | S (after S10) |
| C6 | **Scrolling capture** | Capso `Packages/CaptureKit/Sources/CaptureKit/Scrolling/` (`ScrollStitcher.swift`, `HeaderDetector.swift` for sticky headers, `ScrollbarDetector.swift`, `ScrollCaptureController.swift`) (ideas only). Algorithm: capture frames while the user scrolls, find vertical overlap by row-hash matching, exclude sticky header/footer regions, stitch. **Sandbox**: auto-scrolling requires posting events (Accessibility), so make it user-driven scroll | Ideas | L (1.5 to 2 wks) |
| C7 | **OCR + QR reading** | Apple Vision: `RecognizeTextRequest` (Swift API, macOS 15) or `VNRecognizeTextRequest`; `DetectBarcodesRequest` for QR. Capso `Packages/OCRKit/TextRecognizer.swift`, `App/Sources/OCR/` (ideas) | Apple API | S-M |
| C8 | **Pin screenshot on top of all windows** | Capso `App/Sources/Capture/PinnedScreenshot*.swift` (ideas). `NSPanel` with `.floating` level, resizable, opacity control | Ideas | S |
| C9 | **Capture history** (restore any past capture) | Capso `Packages/HistoryKit/` (`HistoryStore`, `HistoryCleanup`, `ThumbnailGenerator`) (ideas). Use SwiftData per AGENTS.md | Ideas | M |
| C10 | **Self-timer + crosshair magnifier + pixel dimensions** | Capso `Capture/SelfTimerHUD.swift` (ideas); QuickRecorder `ViewModel/ScreenMagnifier.swift` (AGPL, ideas). Reco's area overlay already shows sizes, extend it | Ideas | S |
| C11 | **Live click highlight + keystroke display during recording** (CleanShot does it live, Screen Studio in post) | Capso `Packages/EffectsKit/` (`ClickHighlightWindow`, `ClickMonitor`, `KeyPressMonitor`, `KeystrokeFormatter`) (ideas). Once F1 exists, you can also burn these in at export instead | Ideas | S-M |
| C12 | **Cloud share link** (bring-your-own S3 / R2 bucket, custom domain) | Capso `Packages/ShareKit/` (`S3Destination`, `R2Destination`, `ShareSigning` SigV4) (ideas). Write with `URLSession` + SigV4; store keys in Keychain. `network.client` entitlement already exists | Ideas | M |
| C13 | **Record directly to GIF** (short captures for Slack/GitHub) | Reuse S15 encoder on the quick-record path | Apache | S |
| C14 | **Copy screenshot / recording to clipboard, drag into any app** | Reco already copies file URLs (`copyFileToClipboard`); add image data for screenshots and a "copy after capture" setting | Existing | S |

**CleanShot X parity subtotal: 14 features, ~8 to 10 weeks.**

---

## 7. Sandbox constraints (the biggest porting risk)

Reco is sandboxed and the ADR says it must stay that way. Screenize, open-recorder, and Capso are **all non-sandboxed**, so their input-monitoring code may not work unchanged.

| Capability | Needed for | Sandboxed status | Recommendation |
| --- | --- | --- | --- |
| `NSEvent.mouseLocation` polling | F1, S3, S5 | Works | Use it |
| Global **mouse** click monitor (`NSEvent.addGlobalMonitorForEvents`) | F1, S3, S7 | Apple only requires Accessibility for **key** events. Expected to work, **verify in sandbox** | Prototype day 1 |
| Global **key** events | S8, C11, Screenize-style typing detection | Needs Accessibility (NSEvent) or Input Monitoring (listen-only `CGEventTap` + `CGRequestListenEventAccess`). Listen-only taps with Input Monitoring are reported to work in sandboxed apps, **verify** | Spike before committing to S8 |
| Accessibility element inspection (Screenize `Core/Tracking/AccessibilityInspector.swift` for smarter zoom targets) | S3 advanced | Not available to sandboxed apps | Skip; use click + dwell heuristics |
| Posting synthetic scroll events | C6 auto-scroll | Needs Accessibility, not sandbox friendly | User-driven scroll capture |
| CoreMediaIO iOS device capture | S17 | Camera entitlement already present, should work | Spike |
| Speech recognition | S14 | Works with usage description | Fine |
| Network upload | C12 | `network.client` already present | Fine |

Decision to make early: either stay 100% sandboxed (Mac App Store eligible, some features weaker), or ship **two build flavors** (sandboxed App Store build + non-sandboxed Homebrew/direct build with full keystroke and Accessibility features). Two flavors is what makes full Screen Studio parity realistic.

---

## 8. License rules for the reference repos

| Repo | License | What you can do in an MIT project |
| --- | --- | --- |
| `syi0808/screenize` | Apache-2.0 | Port code. Keep the Apache license text and a NOTICE / attribution for ported files, mark modified files |
| `imbhargav5/open-recorder` | Apache-2.0 | Same as above. Note its export path uses a Rust service; port only the Swift parts |
| `lzhgus/Capso` | **BSL 1.1**, Additional Use Grant **excludes any "Screen Capture Service"** | **Do not copy code.** Read to understand architecture, then write your own implementation |
| `lihaoyun6/QuickRecorder` | AGPL-3.0 | **Do not copy code** into the MIT project. Ideas only |

Practical tip: add a `THIRD_PARTY_NOTICES.md` at the start, and add a line per ported file as you go.

---

## 9. What would make it clearly better than both (differentiators)

The research on Reddit and X showed the top complaints are: subscription pricing (both), Screen Studio has no transparent export / no device frames / no iOS Simulator frames / Mac-only lock-in, CleanShot X gets bloated and uses 400MB+ memory, and neither pastes directly into AI tools. Reco can win on exactly those.

| # | Differentiator | Why it wins | Builds on |
| --- | --- | --- | --- |
| D1 | **Free, MIT, no subscription, no lifetime-license rug pull** | Top complaint for both apps | Already true |
| D2 | **Transparent-background export of edited videos** (ProRes 4444 / HEVC alpha from the compositor) | Screen Studio cannot do this; reviewers flagged it | Existing alpha pipeline + S10 |
| D3 | **Pro formats end to end** (HDR10, ProRes, CFR output that editors love) | Neither competitor goes this far | Existing `AssetWriter` |
| D4 | **iOS Simulator + Mac window device frames** | Screen Studio gap called out by reviewers | S10 + frame assets |
| D5 | **Open project format + automation**: document `.reco` bundles, extend the URL scheme, add App Intents (Shortcuts app) and a small CLI | Scriptable pipelines for docs teams and CI demo videos | F3 + existing URL scheme |
| D6 | **AI-native sharing**: "copy for AI" (auto-paste screenshot/OCR text/transcript into Claude, ChatGPT, Cursor), on-device transcripts | Explicit Reddit complaint about CleanShot X | C7, S14 |
| D7 | **Local-first privacy + bring-your-own storage** for share links (S3/R2), zero telemetry | Paid tools push their cloud | C12 |
| D8 | **Lightweight and modular**: keep the capture core small (maintainer's vision), ship editor/screenshot suites as optional modules or local SPM packages, keep memory low | CleanShot X bloat complaints; also keeps door open to upstream plugins | F8 |

**Differentiator subtotal: 8 items (1 already done), ~3 to 4 weeks for the remaining ones.**

---

## 10. How many changes, and in what order

| Phase | Items | Count | Rough effort (1 senior Swift dev) | Outcome |
| --- | --- | --- | --- | --- |
| 0. Foundation | F1 to F8 | 8 | 3 to 4 weeks | Telemetry, project bundles, pause, countdown, audio fixes, Swift 6 |
| 1. Screen Studio MVP | S1, S2, S3, S5, S10, S15, S16, S18 | 8 | 6 to 8 weeks | "Free Screen Studio": auto-zoom, smooth cursor, backgrounds, trim, export, GIF |
| 2. Screen Studio polish | S4, S6, S7, S8, S9, S11, S12, S13, S14, S17, S19 + hide desktop icons | 12 | 6 to 8 weeks | Full parity: manual zooms, click/keys, motion blur, vertical, webcam track, captions, iPhone |
| 3. CleanShot X suite | C1 to C14 | 14 | 8 to 10 weeks | Screenshots, quick access, annotate, scrolling capture, OCR, pin, history, share |
| 4. Differentiators | D2 to D8 | 7 | 3 to 4 weeks | Things neither competitor offers |
| **Total** | | **49** | **26 to 34 weeks** | |

Estimates are rough and assume porting Apache code where available (Screenize, open-recorder) rather than writing everything from scratch. Parallelizing with a second developer (one on editor, one on screenshots) roughly halves calendar time since Phase 1-2 and Phase 3 barely overlap in code.

### Suggested first 2 weeks (highest leverage)
1. Sandbox spike: global mouse monitor + listen-only key tap inside the current sandboxed build. Decide one vs two build flavors.
2. F1 telemetry sidecar (port open-recorder `CursorTelemetryRecorder`), aligned to `AssetWriter.sessionAnchor`.
3. F2 cursor-less capture mode.
4. Throwaway prototype: play the raw .mov in an `AVPlayer` with a custom `AVVideoCompositing` that applies a zoom from open-recorder's `AutoZoomGenerator` constants and draws a smoothed cursor. If this looks good, the rest of Phase 1 is incremental.

### Files in Reco that will change most
- `ViewModel/RecorderViewModel.swift`: start/stop telemetry, pause/resume, countdown, project creation.
- `Service/AssetWriter.swift`: pause offset, expose `sessionAnchor`, optional camera track.
- `Service/CaptureEngine.swift`: editable-cursor mode (`showsCursor`), screenshot entry point.
- `Service/CameraSession.swift`: add video data output for a separate camera track.
- `Model/SettingsStore.swift`: editor, telemetry, export, screenshot settings.
- `Service/ContentFilterRules.swift`: desktop icons filter.
- `AppDelegate.swift`: new URL scheme hosts, new shortcuts (screenshot, pause).
- New: `Telemetry/`, `Project/`, `Editor/` (preview, timeline, compositor, export), `Screenshot/`, `Annotation/`, `THIRD_PARTY_NOTICES.md`.
