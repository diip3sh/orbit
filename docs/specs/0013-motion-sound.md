# Motion sound

> Every motion video gets a score and quiet sound effects made for its own picture: generated on device from
> the plan's event times, mixed the way Raycast's film is, with no samples to license. This replaces spec 0012
> Q5 (a bundled CC0 effects set) and spec 0011 phase 5's defaults.

## Why

Motion exports are silent. On 2026-10-07/08, sound was made by hand for the approved Supabase docs film
(`~/Desktop/supabase-docs-film.mp4`): a Python pass outside the engine, through six rounds with the user. The
first round was called "amazing". Its closing then took five more rounds, because it was designed from taste
instead of from the reference whose look it copies. This spec builds what worked into the engine, so every
video gets it from the first export, and records what failed so it isn't tried again.

## Research

### Raycast's soundtrack, measured

"New Raycast. Coming 2026", 38.5 s: the YouTube download in `~/Movies/Reco/references/`, Opus, 48 kHz stereo.
Cut times come from frame differences. Chords are estimated from pitch-class energy, so treat them as
approximate.

- **Music only.**
  - No key sounds while "clipboard" is typed (2.2–3.6 s): above 2.5 kHz the level stays flat at −49 dB.
  - No whoosh on the two whips (10.6–11.7 s, 15.3–16.3 s): the highs rise 6 dB at most, with no swept noise.
  - No whoosh on any cut: the high band never peaks at one.
- **Hits mark a few cuts, after a breath.**
  - Cuts at 0.97, 3.67, 8.90, 24.20 and 28.27 s (the cut to black) get a low hit within 0.15 s of the cut,
    with the sub at −8 to −12 dB.
  - Before 3.67 the sub is silent from 0.6 to 0.15 s before the cut; before 8.90, 24.20 and 28.27 it dips.
  - The other cuts (5.67, 14.00, 20.23, 22.47, 26.17 s) pass under the music with no event.
- **Dynamics.**
  - The hits reach −11.5 to −12.5 LUFS momentary, then decay to −25 to −29 in the holds.
  - The whole film averages about −17.6 LUFS (ungated K-weighted mean); peak 0.4 dBFS.
- **Harmony.**
  - Diatonic C major / A minor throughout: C, Em, C, Am, Am7, C, C, Em through the body.
  - The chord changes on cuts.
- **Pulse.** None clear in the body: tempo estimates wander from 76 to 88 BPM.
- **Spectrum: dark and sub-led.**

  | Band | Share of energy |
  |---|---|
  | Under 120 Hz | 79 % |
  | 120–500 Hz | 16 % |
  | 500 Hz–2 kHz | 4.7 % |
  | Above 2 kHz | 0.1 % |

  The spectral centroid is 128 Hz. The side channel sits 3.5 dB under the mid.
- **The closing** (28.27–38.5 s: black, then "NEW" and a feature name swapped every 0.4 s, the slide, "COMING
  2026", the logo):
  - **The cut to black is louder than the shot before it,** a hit with the bass held.
  - **No sound marks a word.** Under the words runs a fast arpeggio (onsets 0.05–0.08 s apart) holding one
    chord, F: the IV of C.
  - **A new chord at each later step:** C (I) at the slide, Am7 (vi) at the tagline, G (V) at the logo.
  - **It fades all the way, and the logo is the quietest moment:**

    | Section | Level against the last shot |
    |---|---|
    | Black | +6.4 dB |
    | Words | −2.0 dB |
    | Slide | −9.3 dB |
    | Tagline | −14.3 dB |
    | Logo | −18.4 dB |

### The Supabase film's sound, round by round

| Round | What it was | Verdict |
|---|---|---|
| 1 | Synthesized score: a pad chord per shot, changing on cuts, cut dead at the black. Quiet effects: keys, result pops, presses, the whip's whoosh and landing, a swish and thump on cuts. A kick and a rising pluck under the closing words. A large hit on the logo. | "amazing"; one change asked: the closing's word changes need "an aesthetic changing sound like clock switching" |
| 2 | A synthesized split-flap flip on each word | "not the correct sound" |
| 3 | Recorded effects from Mixkit: page flip, pop-whoosh, swipe | "very subtle and aesthetic, not like this… too much noise" |
| 4 | Recorded clock tick and wooden tick-tock, quiet | "decrease… not harsh at all, very low" |
| 5 | The same, 10 dB lower | "all are not suiting the overall video… weird" |
| 6 | Raycast's closing: a hit on black, a felt arpeggio holding IV, a chord per step, fading to the logo | The user moved on to this plan |

What it taught:

1. **Measure the reference's sound before designing any.** The look came from Raycast; the closing's sound
   didn't, and that cost rounds 2–5.
2. **A word change is felt through the music, not through a sound of its own.** The arpeggio's first note lands
   on the word's frame. A click, tick, flip or whoosh on each word read as noise at every level tried.
3. **Recorded effects don't fit.** Library recordings brought noise and a character that matched nothing else in
   the mix. Shipping recordings in the app needs a licence that allows it: Apple Loops and Pixabay don't
   (spec 0010). So everything is generated: nothing to license, nothing recorded to clash.
4. **The end fades.** The logo is the quietest moment, not a hit.
5. **Exact timing is free, and it matters.**
   - Every cue comes from the plan's own times.
   - A word shows from the first frame at or after its time, up to 30 ms after it.
   - The hand-made film's cues landed within 1 ms of their intended times in the exported file (read with
     ffmpeg).
6. **The body's quiet effects were liked, though Raycast has none.** They stay, quiet, and can be turned off.

### The reference: `~/Movies/Reco/quality/audio/score.py`

The film's sound as it stands after round 6. It uses numpy and scipy, 48 kHz stereo, seeded noise. `score-v1.py`
is round 1, `supabase-docs-score.wav` is its output, and `arc.py <ours.wav> <raycast.wav>` compares closings.
Its numbers are where the engine starts.

#### Harmony

- D major, a chord per shot changing 0.04 s before each cut: Dmaj9, Bm11, Gmaj9, Asus, then Dmaj9 again from
  the whip's landing.
- The closing: Gmaj9 (IV) under the words, D (I) at the slide, Bm (vi) at the dimmed line, Asus2 (V) at the
  logo.

#### Voices

- **pad:** three saws per note, detuned −7, 0 and +7 cents and spread left, centre and right. Harmonic k is
  scaled by e^(−k·f/fc)/k, with fc 1.1–2.1 kHz rising through the film. It carries a slow 0.12 % vibrato, is
  levelled by RMS, and has a bass sine at 35 % of the chord's RMS.
- **air:** noise band-passed 160–2400 Hz at −46 dB, under the shots only.
- **felt:** partials 1, 2, 3 and 4.02 at amplitudes 1, 0.28, 0.08 and 0.03. Each decays over 0.32, 0.16, 0.09
  and 0.06 of the note's length, after a 4 ms attack: no click.
- **glass:** partials 1, 2, 3.01, 4.23 and 5.41, the high ones dying first.
- **thump:** a sine sliding from f0 down to f1, with its 2nd harmonic.
- **key:**
  - a click of noise at 2.5–8.5 kHz over 2.8 ms;
  - a tick at 1.25–1.7 kHz;
  - a body at 195–245 Hz, pitched 30 % high and falling over 7 ms (128 Hz for space);
  - a release click 75–100 ms later.
- **blip:** a tone sliding up 10 % into its note.
- **whoosh:** noise through a band-pass swept 320 → 3200 → 900 Hz, loudest where the camera moves fastest.
- **riser:** noise through a band-pass swept upward, rising to the cut.

#### Levels (peak dB; pads as RMS dB)

| Event | Sound |
|---|---|
| First UI cuts in | Glass A5 at −15 and D6 at −18, thump at −15, swish at −26 into it |
| Each cut | Swish at −24 into it, thump at −19 |
| Typed key | −14 (space −12) |
| Results settle | Blips F#5, A5, D6 at −17 |
| Press | Key at −14, blip A6 at −27 0.06 s later |
| Enter | −11 |
| Whip | Riser at −26, whoosh at −9, landing thump at −8, glass D6 at −19 |
| Last shot into black | Riser at −14 over 1.6 s, cut dead with the picture |
| Cut to black | Thump 66 → 36 Hz over 1.8 s at −7 |
| Under the words | Gmaj9 pad at −25, falling 11 dB by the slide |
| Arpeggio | Four felt notes a word: −19 on the word's frame, −24 between. It fades 3 dB by the last word, then to −12 by the slide's end. |
| Dimmed line | Felt chord at −30 |
| Logo | Felt chord at −37, pad at −44 |

#### Room and master

- **Room:**
  - a synthetic stereo impulse, 2.4 s long, with an 18 ms predelay;
  - RT 2.2 s under 900 Hz, 1.6 s from 0.9 to 4 kHz, 0.8 s above;
  - 0.32 wet;
  - before the cut to black, the reverb is gated off within 6 ms of the cut.
- **Master:**
  - a 32 Hz high-pass;
  - a soft clip (tanh at 1.2 drive) to −1 dBFS;
  - normalized to −16 LUFS integrated, −1.5 dBTP;
  - a 0.7 s fade at the end;
  - AAC 256 kbps at 48 kHz.

#### The result against Raycast

- **Closing levels:** 3–6 dB shallower than Raycast's from the slide on.

  | Section | Ours | Raycast |
  |---|---|---|
  | Black | +5.1 dB | +6.4 dB |
  | Words | −0.2 dB | −2.0 dB |
  | Slide | −6.0 dB | −9.3 dB |
  | Dimmed line | −10.8 dB | −14.3 dB |
  | Logo | −12.6 dB | −18.4 dB |
- **Spectrum:** much brighter than Raycast's. The centroid is 411 Hz against 128 Hz, and 34 % of the energy is
  under 120 Hz against 79 %.

### Where it plugs into the engine (read from the code, 2026-10-08)

- **No audio today.**
  - `MotionCompositionBuilder.composition(for:)` builds a placeholder video track, one video track per live
    layer, and an empty `AVMutableAudioMix`.
  - The app has no AVAudioEngine, AVAudioFile, ExtAudioFile or AudioToolbox code, and ships no audio files.
- **One composition feeds the preview and every export.**
  - HEVC and H.264 presets write AAC, and `ExportService` already sets `session.audioMix`.
  - ProRes presets are the LPCM ones.
  - `GIFWriter` reads video tracks only.
  - The preview is rebuilt 150 ms after each edit (`MotionEditorViewModel+Editing.swift`), so the score must be
    cached or fast to make.
  - An audio track must be trimmed to `duration(of: plan)`: the single `MotionInstruction` covers exactly that
    range.
- **Event times are already exposed, pure and nonisolated.**

  | Event | Where its time comes from |
  |---|---|
  | Scene start and seam | `MotionPlan.Scene.start`, `.transition`, `.overlap` |
  | Seam spans | `SeamExpansion.effect(of:…)` |
  | Key times | `HumanTyping.keyTimes(for:from:)` |
  | Result settles | `HumanTyping.settledLengths(of:)` plus `settleDelay` (0.22 s) |
  | Presses, with their key | `UIContent.presses` |
  | Moves | `MoveExpansion.timing(of:in:)` |
  | Camera speed, for a whip's peak | `MotionPlan.Scene.cameraValue`, as `velocity(atEndOf:)` samples it |
  | Closing | `ShotLayout.ClosingTimes(words:)`: `slide`, `settled`, `underline`, `logo` |

  A closing's word times (`closingSwaps + 0.42·i`) aren't a function yet.
- **Where the setting goes.**
  - `MotionDocument` takes an optional field without a version bump: `decodeIfPresent ?? defaults`, checked in
    `validate()`.
  - Agents reach it through a `MotionEdit` operation, `AgentToolCatalog+Motion` and `MotionSummary`.
- **What to reuse.** `CompositionBuilder.audioMix` and `audioFades` already make 25 ms fades at cuts, a measured
  value.

## Expected outcome

- **Every export has sound by default.**
  - HEVC, H.264 and ProRes exports of a motion video get a stereo score and quiet effects; GIFs stay silent.
  - The preview plays the same sound.
- **One rule decides every sound.** The same document always gives the same sound, sample for sample. An agent
  writes nothing about sound unless asked.
- **Measured, not judged by ear alone:**
  - every cue within 1 ms of its frame in the exported file, read through AVFoundation;
  - −16 ± 0.5 LUFS integrated, true peak at or under −1.5 dBTP;
  - no effect at all between a closing's first word and its logo;
  - the closing's levels within 1 dB of the rule (below).
- **Fast:** the Supabase film's score made in under 1 s, a 60 s film in under 2 s (M5, Debug), and cached in the
  bundle.
- **Easy to change.**
  - The chat handles "no sound", "no typing sounds" and "quieter music" as one edit.
  - The window's side panel has Sound controls.

## Approach

### The rules (`SoundRules`, one place each)

1. **The score follows the edit.**
   - A chord a scene, changing 0.04 s before its cut, from a loop of diatonic progressions in one key (D major
     until open question 3 is settled).
   - A film with scenes shorter than 2 s changes chord on every second cut instead.
2. **Hits open acts.** A hit marks the first scene with UI and the cut into a closing, each after a 0.3–0.5 s
   breath where the score drops out, as Raycast's do. Other cuts get round 1's swish and thump, quiet under the
   music.
3. **Effects only for what the viewer sees happen:**
   - typed keys;
   - results settling;
   - presses, with Enter when a press's key is Enter;
   - a whip: a fast pan, its whoosh peaking at the camera's speed peak, the landing on the settle;
   - the first UI appearing.

   Never a whoosh on a plain cut.
4. **The closing is Raycast's.**
   - The last shot rises into the cut to black, which gets the hit; the room stops with the picture.
   - Under the words, the IV chord and an arpeggio in sixteenths, its first note on each word's frame.
   - I at the slide, vi at the dimmed line, V at the logo.
   - The levels follow the round 6 table, the logo the quietest.
   - Effects are refused inside a closing: the rule, not a default.
5. **Times come from the plan and land on frames.** An event at time t sounds at ⌈t·fps⌉/fps, the frame that
   first shows it.
6. **Deterministic.** Noise and variation are seeded from the document, so an export is the same every time.
7. **The mix.**
   - The score sits under the effects.
   - Normalized to −16 LUFS integrated with a −1.5 dBTP ceiling.
   - A 0.7 s fade at the end.

### Files

| File | Role |
|---|---|
| `Motion/Model/MotionSound.swift` | The document's `sound`: `score` and `effects` on or off, and a level for each in dB (defaults: on, on, 0, 0) |
| `Motion/Sound/SoundCue.swift`, `SoundCueSheet.swift` | A cue (voice, part, the frame it marks, offset, level, pan, send, seed); the sheet (chords, air, cues, the room's stop) |
| `Motion/Sound/SoundCueSheet+Plan.swift`, `+Score.swift`, `SoundCueList.swift` | Pure: the plan's events through `SoundRules` into the sheet; whips from the camera's speed; the body's chords; the closing (`ClosingCues`) |
| `Motion/Sound/SoundRules.swift` | The numbers above, each in one place |
| `Motion/Sound/SoundSignal.swift` | Seeded noise (SplitMix64, Box–Muller), Butterworth sections (`vDSP.Biquad`), swept band-pass, oscillators, `StereoSound` |
| `Motion/Sound/SoundVoices.swift`, `+Score.swift` | Glass, felt, blip, thump, key, swish, whoosh and riser; pads read from one band-limited wavetable per note (`vDSP_vtabi`) and the air |
| `Motion/Sound/SoundRoom.swift`, `SoundFinish.swift` | The seeded impulse convolved by DFT overlap-add, stopped at the cut to black; the high-pass, fade, soft clip, loudness and ceiling |
| `Motion/Sound/Loudness.swift`, `ScoreRenderer.swift` | BS.1770-4 (K-weighting, gated integrated loudness, true peak at 4×); the sheet placed dry and sent, roomed and finished |
| `Motion/Service/SoundCache.swift` | `assets/sound/<cue-sheet hash>.caf`, 24-bit Apple Lossless, keyed with a `soundVersion`, the three most recent kept |
| `Motion/Render/MotionCompositionBuilder.swift` | The audio track at `.zero`, trimmed to the plan's duration |
| `Motion/View/MotionSoundSection.swift` | The side panel's Sound section |

### Phases

| Phase | Size | Status |
|---|---|---|
| S1 - Rules and cue sheet | S | Done |
| S2 - Voices, room, master, loudness | M | Done |
| S3 - Preview and export | S | Done |
| S4 - Document, agent, inspector | S | Done |
| S5 - Listening round | S | Next: the user's |
| S6 - The user's own music | M | Later (spec 0011 phase 5) |

#### S1 - Rules and cue sheet (S)

- `SoundCueSheet.make(plan:document:)`, pure.
- A word-time function next to `ClosingTimes`, so the closing's swap times exist in one place.
- **Done when:**
  - The Supabase film's document (the engine port, `~/Movies/Reco/quality/port/`) gives every cue the reference
    places, each within 1 ms of the reference's time.
  - No cue at all falls between its closing's first word and its logo except the score's.
  - Every cue sits on a frame.

#### S2 - Voices, room, master, loudness (M)

- The voices, room and master in Swift.
- **Done when:**
  - The Supabase cue sheet renders deterministically.
  - It measures −16 ± 0.5 LUFS.
  - Its closing levels are within 1 dB of the reference's, and its band shares within 3 points.
  - `Loudness` agrees with ffmpeg's `ebur128` to 0.1 LU on the reference WAV and on Raycast's.
  - The time limits above are met.

#### S3 - Preview and export (S)

- The audio track in the composition and the cache in the bundle.
- The preview keeps playing the last score while a new one is made off the main actor.
- **Done when:**
  - In the exported Supabase film, read through AVFoundation (`AVAssetReader`), every onset is within 1 ms of
    its frame, AAC priming included.
  - ProRes carries PCM.
  - GIF is unchanged.

#### S4 - Document, agent, inspector (S)

- `sound` on `MotionDocument`, a `set_sound` operation, the catalog's description and `MotionSummary`.
- `preview_motion` reports the sound's loudness and cue count.
- A Sound section in the side panel's Style: Score and Effects switches, two sliders.
- **Done when:**
  - A launch run from an address exports with sound and no extra tool calls.
  - The chat's "no typing sounds" changes only `effects`, in one edit.

#### S5 - Listening round (S)

- Export the Supabase, Linear 6 and Cardboard films and have the user listen.
- Settle open questions 1, 2 and 4 by ear.
- Frames and audio are kept in `~/Movies/Reco/quality/sound/`.

#### S6 - The user's own music (M, later)

- A file the user drops in, beat tracking (spec 0011 phase 5), the score off, the effects ducked under it.

## Risks

- **Synthesized pads can sound cheap.** Round 1 kept them low and warm, and was liked. If they wear thin across
  films, the S5 round decides whether to spend on better voices: physical-model felt, sampled-free FM.
- **Long films** (Linear 6: 23 scenes in 56.7 s) change chords every 2.5 s. Rule 1's every-second-cut fallback
  is untested by ear.
- **Debug-build DSP speed.** Swift loops are slow without optimization; everything per sample goes through
  vDSP, or the score is cached and made once.

## Open questions

1. **Brightness.** Darker, like Raycast (centroid 128 Hz, 79 % under 120 Hz), or ours as the user heard and
   liked it (411 Hz, 34 %)?
2. **Cut accents.** Keep the body's quiet swish and thump (round 1, liked), or go music-only like Raycast?
3. **Key.** Fixed D major, or chosen per brand (from its hue or name, deterministically)?
4. **Loudness.** −16 LUFS (what the user heard) or −14 (YouTube and Spotify)?

## Progress

### 2026-10-08: S1–S4 built

Open questions 1–4 are left as the user heard round 6 until the listening round: its brightness, the quiet
accents on cuts, D major, −16 LUFS.

- **The renderer against `score.py`.** `score.py`'s own events, as a cue sheet, rendered by the Swift voices
  (M5, Debug):

  | | Swift | `score.py` |
  |---|---|---|
  | Made in | 0.41 s | 2.6 s (numpy) |
  | Integrated | −16.0 LUFS (ffmpeg agrees: −16.0) | −15.4 LUFS |
  | True peak | −2.6 dBTP (ffmpeg: −2.6) | −1.2 dBTP |
  | Centroid | 397 Hz | 411 Hz |
  | Bands (<120, <500, <2k, above) | 35.0, 40.3, 23.4, 1.3 % | 34.4, 40.0, 24.1, 1.5 % |
  | Closing: black, words, slide, line, logo | +5.5, −0.2, −5.1, −10.3, −12.2 dB | +5.1, −0.2, −6.0, −10.8, −12.6 dB |

  A band from `low` to `high` is a high-pass then a low-pass, not scipy's 4th-order band-pass; the closing
  and the bands still land within 1 dB and 1 point.
- **The cue sheet from the plan.** The Supabase docs film's document (captured live, 1080p plan) gives the same
  105 cues and 9 chords as `score.py`, at its levels, on its frames, with three differences:
  - **Keys and results follow the engine's own typing** (`HumanTyping`), not the hand-made film's key times.
  - **The whoosh peaks at the camera's measured speed peak**, 11.903 s (36 frame widths a second), where the
    hand-made film guessed 11.97.
  - **Every cue's moment is the frame that shows it** (rule 5): a key at 4.0669 s sounds at 4.1, the frame its
    letter first shows. Notes inside a bar or a rolled chord keep their offset from that frame. The opening's
    second glass no longer comes 12 ms after the first.
- **Whips are found from the camera, not its moves.** Its speed across the frame is sampled at 240 Hz; a whip
  is faster than 5 frame widths a second, and starts and lands where it's down to 1 % of its peak. So keyed
  cameras, whip moves and whip seams all count. At 2 widths a second, the camera following a selection (about
  3) counted too.
- **Chords.** A whip's landing inside a scene changes the chord, unless it's within 1.5 s of another change
  (the film's held 1.94 s). Only scenes shorter than 2 s halve the changes; counted with the landings, the
  film's 1.94 s chord had halved them all.
- **Enter.** A scene whose field had a selection ends on Enter 0.14 s before it cuts to what it opens; the
  engine's presses have only arrows.
- **Results blip only where results show.** A field blips as each word settles only if it grows to 1.5× its
  empty height. In the first app run, bolt.new's chat prompt, which never grows, popped on all seven of its words.
- **Speed (M5, Debug).** The Supabase film's plan built in 0.10 s with its sheet; its sound was made in
  0.34–0.40 s. The preview waits for it: a timing edit makes it again, any other edit reads the cache.
- **Export.** In a test export, a key cue in AAC landed within 1 ms of where it was made (read through
  `AVAssetReader`, so the priming is applied). ProRes carries PCM; GIFs make no sound.
- **From the app.**
  - `Bolt 6`: a bolt.new launch run (Claude Code, no instructions about sound) exported 26.3 s at 4K with AAC at
    −16.0 LUFS and −2.5 dBTP. Its audio is the cue sheet's sound sample for sample: 0 samples of lag at the
    opening hit, a cut, a result, the whip and the closing. The first letter shows on the frame its key sounds
    (4.867 s).
  - The approved Supabase docs film, exported by the app's `export_recording` (51 s), against the hand-made film
    with sound (`~/Desktop/supabase-docs-film-audio-new-ending.mp4`):

    | | Engine | Hand-made |
    |---|---|---|
    | Integrated | −16.0 LUFS | −16.0 LUFS |
    | True peak | −2.5 dBTP | −1.9 dBTP |
    | Bands | 34.6, 39.1, 24.8, 1.6 % | 33.8, 40.9, 23.7, 1.5 % |
    | Closing: black, words, slide, line, logo | +5.4, 0.0, −6.0, −10.7, −12.7 dB | +4.8, −0.6, −6.0, −9.6, −11.3 dB |

    The hand-made MP4 differs from `score.py`'s own render by up to 1.3 dB at the logo; the engine is within
    0.3 dB of `score.py`.

