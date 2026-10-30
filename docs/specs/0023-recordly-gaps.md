# 0023: Five editor gaps against Recordly

Five features Recordly has and Orbit lacks, built in this order, each ending in one commit that builds, passes the
tests and adds no SwiftLint warning. Recordly is AGPL-3.0 and Orbit is MIT, so no Recordly code is copied.

Every edit is timed on the source, as `EditorProject` documents, so cuts, speeds and reordering never invalidate it.

## 1. Captions (spec 0004, N5)

**Shape.** `EditorProject.captions: CaptionTrack` holds `isEnabled`, `style: CaptionStyle` and `cues: [CaptionCue]`. A
cue has `id`, a source `range`, `text` and `words: [CaptionWord]`. A word has `text`, a source `range` and `confidence`.

**Build.**

- `Transcriber` uses `SpeechAnalyzer` and `SpeechTranscriber` on macOS 26, reading the voice track with
  `AVAssetReader`. Below macOS 26 the Captions tab stays unavailable, as N5 decided.
- `CaptionSegmenter` turns timed words into cues, a pure function.
- `RenderPlan` draws each cue's line once as an image, as `KeystrokeChip` does. `FrameRenderer` draws it over the
  video and doesn't zoom it.
- The Captions tab generates, edits text, deletes and styles. A Captions lane moves and resizes cues.
- `SubtitleFile` writes SRT and VTT in output time. Export can write them beside the movie.

**Verify.** Tests cover segmenting, subtitle timing across cuts and speeds, and a `say` recording whose word times fall
within 100 ms.

## 2. Camera track (spec 0004, N19, bubble only)

**Shape.** `EditorSource.camera: CameraFootage?` holds the URL, track and time offset. `EditorProject.camera:
CameraOverlayStyle` holds `isEnabled`, centre, size, roundness, mirror, shadow, crop, a user time offset and whether it
shrinks during zooms.

**Build.**

- `SettingsStore.cameraMode` chooses `.track` (the default) or `.presenterOverlay`, since one session can't do both.
- `CameraRecorder` writes `<name>.camera.mov`, pausing with the screen, and stores its offset from the screen's first
  frame in `<name>.camera.json`.
- `CompositionBuilder` inserts the footage as a second video track using the same pieces. `FrameRenderer` draws the
  bubble after the zoom.
- The Camera tab edits the style and can add or replace footage from a file, copied to `<name>.camera.mov`.
- Renaming and trashing a recording carry the camera files.

**Verify.** Tests render a generated camera file and check the bubble's pixels. Recording needs a real camera and its
permission prompt, so that part needs a person to check it.

## 3. Video overlays

**Shape.** `EditorProject.overlays: [VideoOverlay]`. An overlay has `id`, a source `range`, a `lane`, a `frame` in
fractions of the video frame and `kind`: `.text(TextOverlayStyle)`, `.image(bookmark:)` or `.arrow(ArrowOverlayStyle)`.
Overlays overlap in time only on different lanes, up to three.

**Build.** `RenderPlan` draws each overlay's image once. `FrameRenderer` draws them after the zoom with a short fade. The
stage drags and resizes the selected overlay. Each used lane appears on the timeline. The inspector edits the selected
overlay's content and style.

**Verify.** Tests cover lane placement, timing across cuts and rendered pixels for each kind.

## 4. Opening existing videos

**Decision.** Opening a file outside the recordings folder copies it in, so the `.edit.json` beside it always has a
writable home, the Library shows it, and the original stays untouched. `FileManager` clones on the same volume, so that
case costs nothing.

**Build.** `RecordingImporter` picks a free name and copies. The Library gets an import button and accepts dropped files.
`Info.plist` declares `public.movie` as a viewer, and `AppDelegate` opens those files.

**Verify.** Tests cover name collisions, a file already in the folder and a file without video.

## 5. Reordering clips

**Shape.** `EditorProject.sequence: [Range<Double>]` lists source ranges in playing order, empty meaning source order.
`TimeMap` reconciles it with the cuts: it intersects each range with what's kept, and places any kept part it doesn't
cover beside its source neighbour. So trims, cuts, splits and undo need no special cases.

**Decision.** The timeline stays laid out in source time, because every lane is timed on the source. A Clips strip above
it shows the segments in playing order, with drag to reorder. Moving a segment moves its zooms, masks, captions and
overlays with it, since those are on the source.

**Build.** `TimeMap` keeps `pieces` in output order and looks up source times through a sorted index. Audio fades move to
every boundary where neighbouring pieces aren't adjacent in the source. Every other `TimeMap` caller is checked against
the assumption that output time rises with source time, including `CameraPath` and `SubtitleFile`.

**Verify.** Tests cover mapping both ways, round trips, reconciliation after trims, cuts and splits, and fades. An export
of a reordered clip is compared against the expected frames.
