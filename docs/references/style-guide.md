# Style guide: the picked films, measured

The user picked three directions on 2026-10-07 (`launch-films.md`): **New Raycast**, **Nothing OS
5.0**, and **3D UI layers** (Nothing's exploded layers, Linear Agent's tilted plane, Meet Copilot's
glass slabs). The films are kept outside the repo in `~/Movies/Reco/references/` (YouTube copies,
for study only). Numbers below were measured from them: cuts from frame differences, camera speed by
phase correlation (480 px, 10 fps, so 2.1 %/s is one pixel step), levels from 640 px frames (0–255).

## What every one of them does

- **Holds, then moves fast.** The camera's median speed per shot is 0–5 % of the width a second;
  its peaks are 10–100× that (Raycast's emoji grid: median 19 %/s, peak 244 %/s; Nothing: peaks of
  160–340 %/s). Reco today moves everything at ~1 %/s and never fast.
- **One element at a time.** The frame is a tight crop of one control or one line of text, often
  cut off by the frame edge; the rest is dark, blurred or empty.
- **The real interface does the story:** typing with a caret, a menu opening, a result streaming
  in, a selection stepping through a grid. Nothing is redrawn.
- **Restrained tone.** Raycast and Linear are low key: black point 0, median 4–25, whites 43–190 (UI
  whites are rarely pure white), chroma ~0–4. Nothing is high key pastel: median 150–250.
- **Small, confident type.** Raycast's closing words are mono caps ~2.5 % of the height; Nothing's
  labels smaller still. Big type is rare and short.
- **Typing at a human pace:** 8 characters a second (Raycast), 11 (Linear), 15 (Copilot), with
  pauses at word ends.

## Raycast — "dark satin" (38.5 s, 30 fps)

- **Ground:** black satin fabric in soft folds, lit by one broad, slow key light; out of focus.
  Monochrome. Sometimes a bright diagonal edge of a glass or chrome plane crosses a corner.
- **UI:** dark translucent panels: the satin shows blurred through them, a 1 px light edge, soft
  shadow. Emoji and app icons are the only colour; a selection ring takes the colour of the emoji.
- **Shots:** 2.7, 1.6, 3.2, 5.1, 5.8, 2.2, 1.8, 2.0, 2.1 s, then a 10 s title section. A search
  pill bleeding off the right edge at ~3× macro; typing "clipboard"; results; a menu opening; a
  hotkey dialog filling in and turning green on Save; the emoji grid with a ring hopping between
  tiles and the camera whipping after it; a tile shrinking into an icon button, then into a voice
  pill with a waveform (one shape, morphing); an AI chat; a spinner.
- **Ending:** pure black, tiny mono caps: "NEW" and a feature name, swapped every 0.5 s (six of
  them); then "NEW" and "RAYCAST" slide together; "COMING 2026" in italic under it; the logo.

## Nothing OS 5.0 — "dot screen and callouts" (75 s, 25 fps)

- **Ground:** soft gradients (blue/pink, olive, iridescent green/lilac waves, amber to black) under
  a fixed screen of square dots: pitch 0.83 % of the width (32 px at 4K), dot 0.1 % (4 px),
  ~15 % lighter than the ground.
- **Type:** a dot-matrix face for titles ("NOTHING OS 5.0"), revealed by scrambling glyphs; mono caps
  labels; a closing lockup that is a line of text with icons and pills inline
  ("WED (26) AUG ☀ 11:00 / OPEN BETA STARTS →").
- **Callouts:** a thin leader line from a crosshair square on the UI to a mono caps label
  ("TRANSPARENT DETAIL", "ADAPTIVE COLOUR", "SMOOTHER SCROLLING"). Every callout points at a real
  part of the interface.
- **3D layers:** the home screen exploded isometrically into translucent layers (wallpaper,
  widgets, controls) that separate in depth and settle back, with callouts on the layers.
- **Rhythm:** a 3 s burst of hundreds of image tiles at the start, then calm sections of 4–15 s;
  widgets floating apart across a gradient; a white grid-paper section for the AI features.
- **Ending:** the feature list as two columns of tiny mono caps flanking the phone; the title over
  amber fading to black; the lockup typed in on black.

## Linear Agent — "one plane in the dark" (55 s, 60 fps)

- One UI plane tilted in 3D (seen from low and to the side), lit by a pool of light that falls off
  to black; heavy depth of field along the plane. No background at all.
- Long takes: 3.0, 8.2, 5.9, 4.8, 7.8, 5.3, 5.5, 4.5 s, end card 9.8 s. The camera slides 2–8 %/s.
- Text streams in line by line from a blur; typed prompts with a caret.
- Ending: the wordmark sharpens from a blur on black, then the tagline extends from it.

## Meet Copilot — "glass slabs" (102 s, 24 fps)

Full CGI (frosted glass with thickness, refraction, pastel 3D props); shots ~2 s. Beyond a 2.5D
renderer as a whole. Worth taking: UI planes at an angle with focus pulls, a caret typing large
words, letters dropping into place.

## Tells of a generated video, to avoid

Measured against the films above; each is a lint or a design check to have:

1. A centred headline over a gradient, alone, as a shot.
2. Everything fading in, and every move the same length and speed (the films hold, then whip).
3. Glows on UI chrome, particle bursts, lens flares, neon edges.
4. Pure white type at full contrast over a dark ground. The films keep pure white for the one
   thing being typed and its caret (Raycast: 253–254); placeholders and secondary text are grey
   (Raycast's placeholder 124), and other UI whites stop at 130–190.
5. Decorations that point at nothing: corner labels, frame borders, HUD lines (a callout must name
   and point at a real element).
6. Type set big by default, in the same face and weight everywhere.
7. Constant drifting with no holds; bouncy overshoot on type.
8. Typing at a machine-even rate with no pauses, or no caret.
9. A new technique in every shot (showreel sameness); the films keep one language throughout.
10. Clean digital gradients that band, or grain strong enough to see (the films show none at
    YouTube's bitrate: grain is for dithering, not a look).
11. A whoosh on every cut and generic synth music.
