# The film, measured

ElevenLabs' "Introducing ElevenAgents Architect" (67.15 s, 1920×1080, 60 fps), measured frame by frame. Paper `#f3f2f0`,
ink `#0a0c0d`, the dark beat's ground `#171717`. Every frame is sharp: a card growing 52 px a frame keeps a 1 px edge.

## Shot by shot

| Time | What happens |
|---|---|
| 0.0–1.7 | The "II" mark fades in and holds; its bars part and "Your agents" pops between them, then slides to centre |
| 1.7–2.0 | The bars close in from both ends and eat the line into a black square |
| 2.0–4.5 | The square becomes a picture and grows in steps, each a cut (+35 px every 8–27 frames, then ×1.1–1.3 every 3 frames); mono labels blink in round it, grey lines type and delete; at 4.45 it fills the frame |
| 4.55 | Cut to paper and rings: the mark's bars part, "IIEleven Agents" types out from them, the line slides left as "Architect" is wiped in, and settles to its size by 6.3 |
| 7.45–7.73 | A picture sweeps in from the right behind a front 1000–1500 px soft, the wordmark fading left to right under it |
| 7.73–8.4 | A card's outline appears; its white fill sweeps across from the right; the chip "Customer support agent" fades in; the camera settles back |
| 8.4–15.4 | The question typed; the card opens into floating panels |
| 15.4–17.9 | White: an icon tile framed by registration marks grows; icons stack into "Steps"; Reject / Approve |
| 19.1–22.6 | Picture grids, tinted |
| 22.65–22.85 | The ground darkens to `#171717` in 12 frames |
| 22.9–25.7 | Dark squares orbit and shrink into 12 white stars turning round "Scanning conversations…", whose slate letters are lit by a front, then whiten; marks at the box's corners |
| 25.73 | Back to paper in 7 frames; the line becomes a bar, the bar opens into a white card framed by marks |
| 29.85–32.6 | Cut to a mosaic of dark panels and pictures, pulling back; text types in the panels, rows tick to "PASSED 5/5"; tiles leave by an edge or a cut, top right first; the pink tile stays |
| 32.6–34.9 | The pink card turns into a circle (292 px at 33.3), shrinks to 78 among dots born round it in a wave; it slides left as the white "Ask Architect" pill opens beside it |
| 35.15–44.77 | The pill grows; cut to a rose card filling the frame, its margins easing to 23 px; the prompt bar on it, typed |
| 44.77–48.33 | White settings UI, a registration box |
| 48.5–50.6 | Ink: "to the standards you set", dim, lit word by word as it shrinks to its size |
| 50.6–54.18 | Paper, picture tiles, a grid pushing in |
| 54.18–57.3 | A golden card grows to fill the frame in 0.38 s: "Connect Architect to — Claude"; the name cuts every 0.667 s (Claude Code, Cursor, Grok Bot, ChatGPT), each on its own picture |
| 57.3–59.5 | The last picture is a circle bigger than the frame, shrinking; cut to paper as "Improve ● your agents" part round it |
| 59.52–61.5 | "Elevate your customer experiences": "Elevate your" dark, the rest dim, lit in turn; a globe of dotted letters drifts behind |
| 61.48–62.0 | The line is eaten from both ends into the mark |
| 62.0–67.15 | The wordmark opens again and holds; silence from 65.5 |

## The moves

- **The mark opening.** The bars part over 0.59 s on cubic-bezier(0.79, 0, 0.15, 1); the letters pop at full opacity,
  out from where the bars were, one every 2–3 frames; the line's middle slides 145 px over 0.74 s on cubic-bezier(0.92,
  0.17, 0.07, 0.91); it opens at 112.5 % and settles on a critically damped spring (ω ≈ 7.3 rad/s); the tagline, in slate,
  is wiped in left to right at about 1350 px/s behind a 180 px ramp, 0.93 s after the bars began.
- **Statements.** Dim from the cut (31 % of the way to white on ink, 24–28 % to black on paper); each word pops full in one
  frame, the first 0.22 s after the line starts shrinking, then 0.02 s plus 0.045 s a character of the word before; the line
  shrinks from 119 % on cubic-bezier(0.04, 0.46, 0, 1) over 1.28 s.
- **Labels.** 14 px mono caps after a black bar. They blink: bar and text on alternate frames for 3–6 frames, then the
  text eases 6–20 px from its bar over 0.25 s. Grey descriptions type at 110–120 characters a second with no caret and
  delete from the left, faster as they go.
- **Cards growing.** 1152×763 to past the frame in 0.38 s on cubic-bezier(0.20, 0.20, 0.03, 0.78), its corners 11.5 → 27 px;
  the rose card's margins ease from 88/57 px to 23/21 in 0.53 s.
- **The sphere.** The card (790×471, corners 32–36) shrinks with an ease-in as its corners grow, a circle at 0.4 s, then
  shrinks with an ease-out to 78 px over 1.1 s; a 2 px outline frame 14 % darker than paper shrinks round it; up to 44 black
  squares (14 → 9 px) on the rings' corners, born outwards 240 → 960 px in 0.34 s, gone from the inside out by 0.84 s,
  each flickering a frame at birth and death. It is a flat picture in a circle, not shaded.
- **The pill.** The sphere slides left on cubic-bezier(0.60, 0.17, 0.06, 0.99) over 0.65 s; the pill opens 78 → 628 px
  to its right on an out-expo over 0.8 s, its text uncovered as the sphere moves.
- **The mosaic.** An irregular grid: columns at x 0, 454, 648, 1144, 1266, 1920; rows at y 0, 96, 358, 721, 1080. It holds
  while its contents animate; tiles leave by an edge retracting or a cut, never a fade.
- **The dark beat.** 12 white stars 12 px across, 30° apart on a circle of 0.35–0.42 of the frame's height, turning
  clockwise at 132°/s slowing to 37 then 104; shrinking away as they spiral out. The line's slate letters are lit by a
  front at about 500 px/s, then the whole line whitens.
- **Registration marks.** Solid squares (12 → 8 px) where dotted hairlines (1–2 px, a dot every 6 px, a fifth of the way
  to black) cross; the lines run across the whole frame, about 42 px outside what they frame, and follow it. They are
  there whole on the scene's first frame.
- **Cuts.** Hard, about every 0.4–3 s; inside a scene, things step in cuts too (the square's growth, the names).

## The score

A film score in G♯, no drums or loop, −15.7 LUFS. An intro of pad and high ticks (10.2 kHz, gone in 4 ms); a sub (35–55 Hz)
under the body; booms a sixteenth after the section cuts; pads swelling into cuts; a breakdown of drone and pad
(35.4–44.8); the biggest boom on the return; a held chord with ticks under the montage; a lift of a thump echoing every
third of a beat, 5 dB softer each time; the peak in G♯ major, loudest; on the end card a burst (a thump falling 78 → 46 Hz)
on the mark and on the wordmark 0.8 s later, the tail gone by 65.5 s. 70 % of its energy is under 60 Hz. Reco's
`editorial` sound is made from your film's cuts the same way.
