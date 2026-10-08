# 0014 — Speed per part, and speeding up typing

> Each part of a recording plays at 1× to 8×; Speed Up Typing speeds up the typing for you. Spec 0004, N7.

Status: built 2026-10-08 (`testing`).

## Why

Screen Studio's signature edit: typing, loading and long drags are boring at 1× but must stay in the
video. Cutting them loses what happened; speeding them up keeps it and saves the viewer's time.

## What

- Select a part on the timeline (the parts between splits and cuts), then pick its speed in the
  transport's **Speed** menu: 1×, 1.5×, 2×, 3×, 4×, 8×. One undo step. The timeline labels every part
  that isn't 1× with its speed.
- **Motion → Speed → Speed Up Typing** speeds up every stretch of typing (2× under 6 s, 3× under 12 s,
  4× longer) in one undo step, and says how many it found. Parts already given a speed are left as
  they are. Each stretch becomes a part (split at its ends), so it can be changed or reset alone.
- Audio in a fast part plays sped up with its pitch kept.
- Click rings, keystroke chips and zoom transitions keep their on-screen length at any speed. The
  cursor moves with the content, so at 4× it moves 4× as fast, as it did on screen.

## Rules

- **Time.** The project keeps speeds as source ranges with a rate (`EditorProject.speeds`,
  `SpeedRange`), snapped to frames like cuts. `TimeMap` stays the only converter: kept ranges are
  divided into pieces at speed edges, and a piece of source length `d` at rate `r` lasts `d / r` in the
  output. A piece's rate applies only where it is kept; cutting a sped part leaves its speed in the
  project, so restoring the cut brings it back.
- **Overlays on output time.** The plan stores click markers and keystroke chips at their output time
  (presses inside cuts are dropped) and builds the camera over output time from the zooms' and the
  cursor samples' output times. So a ring lasts its duration on screen, and the camera's spring eases
  across a cut instead of jumping to wherever it would have been. The cursor, its click easing, press
  shrink and idle fade stay on source time: they belong to the content. The cursor loop glides over
  the last second of output.
- **Motion blur.** The shutter is open `motionBlur / frame rate` output seconds. Camera samples are at
  output times; the cursor at the source times they show, so a fast part blurs the cursor more, as a
  camera would.
- **Composition.** Each piece is inserted at its output length. Video is scaled with `scaleTimeRange`.
  Audio is not: `AVAssetReaderAudioMixOutput`, which the export reads the mix through, applies a scaled
  edit's rate change late, so a 0.7 s output mixed to 0.709–0.808 s (2026-10-08). Instead `SpeedAudio`
  renders each fast part of the recording's audio and the click sounds through `AVAudioUnitTimePitch`
  (pitch kept) in an offline `AVAudioEngine`, once per part and rate, and the composition inserts those
  files as they are. The background music fills the output as before. A 1× project builds exactly the
  same composition as before.
- **Frames.** A fast part shows the source frame under each output frame (every 4th at 4×), without
  blending.
- **Typing stretches** (`TypingStretches`, pure): key presses that aren't auto-repeats, joined while
  the gaps are under 1 s, kept when at least 3 s from first to last press. A shortcut (⌃, ⌥ or ⌘)
  ends a stretch, so what it does plays at 1×; ⇧ is typing.

## Known limits

- `ponytail:` click sounds are on the source timeline, so a fast part time-stretches them too.
  Writing them on the output timeline would mean a new file on every cut and speed change.
- Cut fades stay at cuts only; a speed change inside kept content has no fade (the content is
  continuous).

## Verify

- `TimeMap`: output length is the sum of each piece's length over its rate; round trips; cuts and
  speeds together.
- An export's length matches `TimeMap.outputDuration`, and its audio has the expected length.
- A ring and a chip last their duration in output time inside a 4× part.
- In the app: a 4× part plays smoothly, voice keeps its pitch, zooms ease in and out at their usual
  pace.
