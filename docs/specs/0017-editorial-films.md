# Editorial films

> A fifth kind of launch film, after ElevenLabs' "Introducing ElevenAgents Architect": type and print on warm paper with
> hairline rings, pictures far out of focus, one dark beat, hard cuts, every frame sharp, under a film score. It ships as
> the `reco-editorial-film` skill. With it the engine gets three grounds (`paper`, `ink`, `lens`), pictures in shapes, a
> `wipe` seam, eight moves (`sweep`, `brighten`, `blink`, `grow`, `marks`, `orbit`, `dots`, `unfold`) and the `editorial`
> score.

## Why

On 2026-10-10 the user shared ElevenLabs' launch (`https://x.com/ElevenLabs/status/2107503346504634463`, copy at
`~/Movies/Reco/references/elevenlabs-launch.mp4`) and asked for "a skill for making video like this of this much of
quality", music only. Stills of its grounds were matched first; then: "Build it properly: the reference's own moves (the
mark opening into the wordmark, a card growing to fill the frame, the sphere, the mosaic, the dark "scanning" beat), its
score, and the reco-editorial-film skill."

## The reference, measured

Shot by shot in the skill's `reference/film.md`. In short: 67.15 s, 1920×1080, 60 fps. Paper `#f3f2f0` with rings stepping
out from the middle, magnified there as through a lens; ink `#0a0c0d`; the scanning beat flat `#171717`. Hard cuts every
0.4–3 s; inside scenes things also step in cuts (the picture square, the names). No motion blur: a card growing 52 px a
frame and the wordmark sliding 24 px a frame keep 1 px edges. Its music is a film score in G♯ without drums, −15.7 LUFS,
70 % of its energy under 60 Hz.

## The engine

| Part | What | Files |
|---|---|---|
| `paper`, `ink` fields | The lattice: each axis read through a lens into steps and the staircases summed, lines where the sum is half way between whole numbers (a 128 px step past a middle magnified about 2.4×); a setup a shot (the opening zooming in, the dark beat settling from 1.54×, the end card holding then settling); lines 21.5 % to black on paper, 17 % to white on ink, split into colours while the lattice zooms | `LatticeSetup`, `latticeField`, `FieldRenderer` |
| `lens` field, `picture` | Ten pictures (`sky` … `mist`): four soft lights read through a ramp of four colours, each fitted to one of the film's frames in OKLab with its type and UI masked out (0.003–0.018 mean error), grained and streaked as it was; a scene's `picture`, else the next in turn; a rectangle's `picture` shows the frame's picture in its shape, covering what of it is in the frame | `LensPicture`, `LensPicture+Setup`, `lensField`, `MotionFrameRenderer.pictured` |
| `wipe` seam | The next scene from the right behind a front 0.78 of the frame wide, its middle from 0.69 of the width to the left edge in 0.27 s on cubic-bezier(0.41, 0, 1, 1) (fitted to the film's 1324 → 0 px, 14 px rms) | `SeamExpansion`, `MotionFrameRenderer+Seams` |
| `sweep` | Characters fading in on a straight ramp, 0.02 s apart, each over 0.13 s ("Architect": its front at 1350 px/s on a 180 px ramp) | `MoveExpansion+Editorial`, `TextReveal` |
| `brighten` | Words dim (0.28) from the cut, each lit in one frame, the first 0.22 s in, then 0.02 s plus 0.045 s a character of the word before; the line from 1.19× on cubic-bezier(0.04, 0.46, 0, 1) over 1.28 s | `TextReveal.offsets`, `MoveContext.wordLengths`, `MotionFrameRenderer+Reveal` |
| `blink` | On and off a frame at a time at 60 fps for four frames, then 12 px along over 0.25 s | `MoveExpansion+Editorial` |
| `grow` | A rectangle to the size that covers the frame from its middle, 1.03× past, its corners to 27 px, 0.4 s on cubic-bezier(0.20, 0.20, 0.03, 0.78) | `ShapeMorph` |
| `marks` | Dotted hairlines (1.5 px, a dash every 6 px, at 0.3) across the frame along the box 42 px outside the layer and its group, a 10 px square where they cross; under the layer, over what's before it; ink on a light ground, white on a dark one, or `color` | `MotionFrameRenderer+Editorial`, `MotionPlan.Marks` |
| `orbit` | 12 dots 12 px across, 30° apart round the layer, turning clockwise at the film's speeds (132 → 37 → 104°/s) on a circle of 0.363 → 0.35 → 0.418 of the frame's height, popping in over 0.25 s, shrinking away over the last 0.4 s; 1.4 s | `BurstExpansion+Editorial` |
| `dots` | Squares 14 → 9 px on a 128 px grid round the layer, a quarter of the corners 240–960 px out, born outwards (240 px at 0, 960 at 0.34 s), gone from the inside out by 0.84 s, flickering a frame at birth and death | `BurstExpansion+Editorial` |
| `unfold` | A group of a mark, a name and a tagline laid out as it ends: the mark alone where the line's middle ends at 1.125×; it parts to its place over 0.59 s on cubic-bezier(0.79, 0, 0.15, 1) as the name is typed out of it (done in 0.21 s); the line slides to its place from 0.58 s over 0.74 s on cubic-bezier(0.92, 0.17, 0.07, 0.91); the tagline swept in at 0.93 s; settling to its size on a spring (ω ≈ 7.3) from 0.72 s | `DocumentExpansion+Editorial` |
| `editorial` score | Sections at cuts at least 2.5 s apart: an opening pad, the body's chords walking, a breakdown near the middle, the return's louder boom, a lift's echoing thump, the peak in G♯ major, the end card's bursts on the mark and the name over a 3.5 s tail; wide decorrelated pads; a sub boom and thump a sixteenth after each section's cut; a 10.2 kHz tick on the cuts between, on what types, on clicks and blinks; air rising into a grow; −16 LUFS, ≤ −1 dBTP | `SoundCueSheet+Editorial`, `SoundRules+Editorial`, `SoundVoices+Editorial` |

Other changes:

- **Sharp.** An editorial film is drawn without motion blur (`MotionPlan.isEditorial`), as the reference is.
- **A fill stays a fill.** A filled rectangle changing its shape mixed its half-side "outlines" and drew a ring part of the
  way (a card's fill sweeping across from 120 to 1500 px wide); `ShapeMorph` keeps two fills a fill.
- **The lint.** One look a film includes the editorial family, and cuts between its grounds and plain paper keep it; text
  is read against its ground (ink, a picture's mean) and against a picture card's mean; in an editorial film mono text is
  texture (no size, contrast or hold rule), its grey lines may type at 115 characters a second, and a scene's first move
  may land on its cut; marks, orbits and dots aren't entrances.
- `Placement` moved to `MotionPlan+Placement.swift` and the lattice's line colour to `LatticeSetup.line(on:of:)`, keeping
  their files under SwiftLint's lengths.

## Measured

- **Look-dev:** the reference rebuilt in the engine as one document (`~/Movies/Reco/quality/editorial/Architect.motion`,
  generated by `scratchpad/el/film.py`; the skill's example), 14 scenes, 41 s at 60 fps, lint clean. Against the film at the
  same offsets: the brighten matches frame for frame (dim words, pops, the shrink); the wordmark's line matches from its
  letters on (size, place, slide, the tagline's sweep), its first 0.4 s differ (the film's bars part into the E and the A;
  the engine's mark slides); the grow's box matches; the stars' count, circle and turn match; the wipe was refitted after
  the first comparison (a third of the frame soft, from past the right edge, was too hard and too slow).
- **Speed:** the rebuild (41 s) exports at 1080p60 in 10.7 s drawn sharp; with motion blur's samples it took 18.4 s (M5, Debug).
- **Sound:** the rebuild's score (110 cues, made in 0.45 s) finishes at −16.0 LUFS, −1.5 dBTP, its power 69.4 / 22.2 / 6.6
  / 1.5 % at 20–60 / 60–150 / 150–400 / 400–1000 Hz against the film's music's 69.5 / 19.6 / 6.3 / 2.8. The first mix had
  48.7 % at 150–400 Hz (the pads 13 dB too loud); booms only an octave down left 7 % at 60–150 (the film's sat on G♯1–C♯2),
  so the chord's own bass sounds 8 dB under each.

- **From the app:** Claude Code on instalanding.ai, asked for "an editorial launch film in the style of ElevenLabs'",
  made a 41.3 s 4K60 film in 5.5 min (`~/Movies/Reco/InstaLanding 3-edited.mp4`): the mark opening into "Your next page",
  labels round a stepping picture, the wordmark, the request card, the dark beat, the mosaic, the sphere and pill, two
  statements lit word by word, "One-shot it with — Claude Code" cycling, the end card. It kept the example's 14 scenes and
  their timings, its own words in them.

## The skill

`reco-editorial-film`, with `reference/film.md` (the film shot by shot and its moves and score measured), `recipes.md`
(every component rendered and checked: the wordmark opening, labels and grey lines, the stepping square, the request card
on a picture, registration marks, the dark beat, the mosaic, the sphere and pill, the input on a picture card, a statement
lit word by word, the growing card and its names, words parting round a sphere) and `example.md` (the film rebuilt). The
prompt's skill choice: the editorial film when the user names ElevenLabs or asks for an editorial, typographic,
print-like or minimal film.

## Open

- The film's bars parting into the name's first letters, the words eaten from both ends into the mark, the grey lines
  deleted from the left, and the dotted globe of letters have no moves.
- The wordmark is laid out by the agent from estimated letter widths; a layout the engine measures would be surer.
- The agent copies the example's arc scene for scene; the skill could offer more than one arc.
- Nobody has listened to the score.
