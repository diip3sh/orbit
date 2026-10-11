# Recipes for an editorial film

Every component here was rendered and checked frame by frame against ElevenLabs' film, rebuilt. Positions and sizes are
canvas pixels on 1920×1080, y down; a group's layers are placed from the group's position; times are seconds into the
scene. Write `"weight"` and `"face"` on every text layer. Replace the words, the mark and the pictures with your product's.

**Moves land on the cut.** The card grows from its first frame; the statement is there, dim, from it. Things change in
cuts inside a scene too: the square's steps, the names cycling.

**Every frame is sharp and the camera stays still,** but for a `pullBack` onto the request card and the mosaic.

## The wordmark opening out of its mark

A group at the line's middle: the mark first, the name (here a bold word and a regular one), the tagline last in the
accent. Lay the line out as it ends; `unfold` does the rest: the mark alone in the middle at 1.125×, the name typed out of
it as the mark moves to its place, the line sliding to its place as the tagline is swept in, settling to its size by 2.1 s.

```json
{"id": "lockup", "content": {"group": [
  {"id": "mark", "content": {"text": {"text": "II", "size": 63, "color": "#000000", "weight": "bold", "face": "sans"}}, "transform": {"position": [-339, 0, 0], "anchor": [0, 0.5]}},
  {"id": "eleven", "content": {"text": {"text": "Eleven", "size": 63, "color": "#000000", "weight": "bold", "face": "sans"}}, "transform": {"position": [-306, 0, 0], "anchor": [0, 0.5]}},
  {"id": "agents", "content": {"text": {"text": "Agents", "size": 63, "color": "#000000", "weight": "regular", "face": "sans"}}, "transform": {"position": [-108, 0, 0], "anchor": [0, 0.5]}},
  {"id": "architect", "content": {"text": {"text": "Architect", "size": 63, "color": "#5e658c", "weight": "regular", "face": "sans"}}, "transform": {"position": [112, 0, 0], "anchor": [0, 0.5]}}
]}, "transform": {"position": [951, 542, 0]}, "moves": [{"move": "unfold", "start": 0.1}]}
```

On a `paper` scene of 3 s, and again as the end card of 5–5.5 s (`unfold` at 0.3). The opening uses the same move with two
layers, the mark and a short line ("Your agents", 68 px), on a 2 s scene. A logo that isn't letters is a `ui` layer
(lifted `bare`) in the mark's place, its `width` the cap height × 1.2.

## Mono labels and grey lines

A label is a group of its bar and its text, blinking a frame apart; groups at least 0.1 s apart. Grey lines type at 115
characters a second. Left column at x 258, right at 1394.

```json
{"id": "r1", "content": {"group": [
  {"id": "r1-bar", "content": {"shape": {"size": [5, 12], "cornerRadius": 0, "color": "#1a1918"}}, "transform": {"position": [3, 0, 0]}, "moves": [{"move": "blink", "start": 0.1}]},
  {"id": "r1-text", "content": {"text": {"text": "ANALYZING CONVERSATIONS", "size": 14, "color": "#11100f", "weight": "regular", "face": "mono"}}, "transform": {"position": [20, 0, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.1167}]}
]}, "transform": {"position": [1394, 228, 0]}},
{"id": "g0", "content": {"text": {"text": "GOOD MORNING JOHN! OF COURSE,", "size": 14, "color": "#858483", "weight": "regular", "face": "mono"}}, "transform": {"position": [254, 248, 0], "anchor": [0, 0.5]}, "moves": [{"move": "type", "start": 0.16, "duration": 0.2522}]}
```

## A picture square stepping larger, then filling the frame

Each step is a frame-long `morph` (a cut), a little larger each time and closer together; then `grow` fills the frame with
its picture. Its scene is `plain`, about 2.4 s, the labels round it; cut to the wordmark as it fills.

```json
{"id": "square", "content": {"shape": {"size": [352, 330], "cornerRadius": 9, "color": "#c1ccce", "picture": "sky"}}, "transform": {"position": [960, 539, 0]}, "moves": [
  {"move": "morph", "start": 0.45, "duration": 0.0167, "size": [388, 364], "radius": 9}, {"move": "morph", "start": 0.9, "duration": 0.0167, "size": [424, 396], "radius": 10},
  {"move": "morph", "start": 1.28, "duration": 0.0167, "size": [459, 430], "radius": 11}, {"move": "morph", "start": 1.48, "duration": 0.0167, "size": [494, 462], "radius": 12},
  {"move": "morph", "start": 1.64, "duration": 0.0167, "size": [528, 496], "radius": 13}, {"move": "morph", "start": 1.77, "duration": 0.0167, "size": [564, 529], "radius": 13},
  {"move": "morph", "start": 1.88, "duration": 0.0167, "size": [626, 586], "radius": 14}, {"move": "morph", "start": 1.95, "duration": 0.0167, "size": [691, 648], "radius": 16},
  {"move": "grow", "start": 2.02}]}
```

## The request card on a picture

`"seam": "wipe"` into a `lens` scene. An outline blinks in, the white fill sweeps across from the right (a 120 px wide card
anchored at its right edge, `morph`ed to its width), the chip blinks in, the request is typed; the camera settles back.

```json
{"id": "question", "duration": 3.4, "field": "lens", "seam": "wipe", "picture": "mist", "camera": {"moves": [{"move": "pullBack", "start": 0.28, "duration": 0.9, "intensity": 1.1}]}, "layers": [
  {"id": "outline", "content": {"shape": {"size": [1500, 700], "cornerRadius": 40, "color": "#ffffffcc", "stroke": 2}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "blink", "start": 0.28}, {"move": "hide", "start": 0.6}]},
  {"id": "card", "content": {"shape": {"size": [120, 700], "cornerRadius": 40, "color": "#ffffff"}}, "transform": {"position": [1710, 540, 0], "anchor": [1, 0.5]}, "moves": [{"move": "morph", "start": 0.36, "duration": 0.24, "size": [1500, 700]}]},
  {"id": "chipGroup", "content": {"group": [
    {"id": "chip", "content": {"shape": {"size": [520, 66], "cornerRadius": 14, "color": "#e4e4e4", "stroke": 1.5}}, "transform": {"position": [510, 262, 0]}},
    {"id": "avatar", "content": {"shape": {"size": [26, 26], "cornerRadius": 13, "color": "#6b6b6b"}}, "transform": {"position": [284, 262, 0]}},
    {"id": "chipText", "content": {"text": {"text": "Customer support agent", "size": 40, "color": "#1d1d1d", "weight": "medium", "face": "sans"}}, "transform": {"position": [310, 262, 0], "anchor": [0, 0.5]}}
  ]}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "blink", "start": 0.62}]},
  {"id": "typed", "content": {"text": {"text": "Why do customers ask to talk to a human?", "size": 58, "color": "#2a2a2a", "weight": "regular", "face": "sans"}}, "transform": {"position": [252, 440, 0], "anchor": [0, 0.5]}, "moves": [{"move": "type", "start": 0.9, "duration": 1.6}]},
  {"id": "tools", "content": {"group": [
    {"id": "at", "content": {"text": {"text": "@", "size": 64, "color": "#1d1d1d", "weight": "medium", "face": "sans"}}, "transform": {"position": [256, 804, 0], "anchor": [0, 0.5]}},
    {"id": "send", "content": {"shape": {"size": [112, 112], "cornerRadius": 56, "color": "#0b0b0b"}}, "transform": {"position": [1622, 804, 0]}}
  ]}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "rise", "start": 0.74}]}
]}
```

The card starts at least 120 px wide: its corners stay corners as it grows.

## Registration marks

`marks` on the layer or group they frame, from the scene's start. Here icon tiles pop in a column on plain paper; the marks
follow the column's box, 42 px out. On a dark ground give them `"color": "#ffffff"`.

```json
{"id": "icons", "content": {"group": [
  {"id": "i0", "content": {"shape": {"size": [124, 124], "cornerRadius": 28, "color": "#111111"}}, "transform": {"position": [0, -150, 0]}, "moves": [{"move": "pop", "start": 0.1}]},
  {"id": "g0", "content": {"shape": {"size": [48, 48], "cornerRadius": 0, "color": "#ffffff", "kind": "search", "stroke": 5}}, "transform": {"position": [0, -150, 0]}, "moves": [{"move": "pop", "start": 0.12}]},
  {"id": "i1", "content": {"shape": {"size": [124, 124], "cornerRadius": 28, "color": "#3d4466"}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "pop", "start": 0.3}]},
  {"id": "g1", "content": {"shape": {"size": [44, 44], "cornerRadius": 0, "color": "#ffffff", "kind": "check", "stroke": 5}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "pop", "start": 0.32}]}
]}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "marks"}]}
```

## The dark beat

`"seam": "fade"` into a `plain` scene whose first layer is a full-frame `#171717` rectangle; `fade` out of it too. The box
widens, stars turn round it, the line blinks in grey and is lit white by a slow sweep. 3.2 s.

```json
{"id": "scan", "duration": 3.2, "field": "plain", "seam": "fade", "layers": [
  {"id": "ground", "content": {"shape": {"size": [1920, 1080], "cornerRadius": 0, "color": "#171717"}}, "transform": {"position": [960, 540, 0]}},
  {"id": "scanBox", "content": {"shape": {"size": [180, 75], "cornerRadius": 14, "color": "#1f2433"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "morph", "start": 0.08, "duration": 0.3, "size": [520, 84]}, {"move": "orbit", "start": 0.25}, {"move": "marks", "color": "#ffffff"}]},
  {"id": "scanLit", "content": {"text": {"text": "Scanning conversations…", "size": 40, "color": "#828894", "weight": "regular", "face": "sans"}}, "transform": {"position": [960, 540, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "blink", "start": 0.4}]},
  {"id": "scanWhite", "content": {"text": {"text": "Scanning conversations…", "size": 40, "color": "#f0f2f4", "weight": "regular", "face": "sans"}}, "transform": {"position": [960, 540, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "sweep", "start": 0.75, "duration": 0.9}]}
]}
```

## The mosaic

Tiles on the grid's columns (x 0, 454, 648, 1144, 1266, 1920) and rows (y 0, 96, 358, 721, 1080), 3 px gutters, corners 6:
dark panels (`#151617`) with mono text, pictures, paper tiles (`#e9e7e3`). A panel and its text are one group. The camera
pulls back from the cut (`pullBack`, intensity 0.5, 1.3 s). From about 1.85 s tiles leave, top right first, each its own
way: a `morph` to a 1 px side anchored at the edge it retracts to, a `hide`, an `exit` to the left; the card that stays
`morph`s `to` the middle at 790×471, corners 34, and the next scene opens on it.

```json
{"id": "pattern", "content": {"shape": {"size": [770, 352], "cornerRadius": 6, "color": "#1d1e21"}}, "transform": {"position": [1917, 3, 0], "anchor": [1, 0]}, "moves": [{"move": "morph", "start": 1.85, "duration": 0.07, "size": [1, 352]}, {"move": "hide", "start": 1.93}]},
{"id": "evalPanel", "content": {"group": [
  {"id": "eval", "content": {"shape": {"size": [490, 256], "cornerRadius": 6, "color": "#151617"}}, "transform": {"position": [896, 227, 0]}},
  {"id": "evalText", "content": {"text": {"text": "EVALUATION SUCCEEDED", "size": 16, "color": "#f2f2f2", "weight": "regular", "face": "mono"}}, "transform": {"position": [676, 326, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.4}]}
]}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "hide", "start": 2.1}]},
{"id": "pink", "content": {"shape": {"size": [612, 357], "cornerRadius": 6, "color": "#ae7a97", "picture": "petal"}}, "transform": {"position": [957, 539.5, 0]}, "moves": [{"move": "morph", "start": 2.32, "duration": 0.45, "size": [790, 471], "radius": 34, "to": [957, 538]}]}
```

Keep text 96 px from the frame's edges, and no more than two things starting within 0.1 s.

## The sphere and the pill

A `paper` scene opening on the card the mosaic kept, in the same picture. It turns into a circle and shrinks while its
outline frame shrinks round it and dots are born round it; then it slides left as the white pill opens beside it, its
text swept in.

```json
{"id": "frame", "content": {"shape": {"size": [1130, 790], "cornerRadius": 40, "color": "#d0cfcc", "stroke": 2}}, "transform": {"position": [957, 538, 0]}, "moves": [{"move": "morph", "start": 0.2, "duration": 0.4, "size": [439, 436], "radius": 60}, {"move": "morph", "start": 0.6, "duration": 0.3, "size": [397, 394]}, {"move": "hide", "start": 0.95}]},
{"id": "pill", "content": {"shape": {"size": [78, 101], "cornerRadius": 50.5, "color": "#ffffff"}}, "transform": {"position": [646, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "show", "start": 1.62}, {"move": "morph", "start": 1.62, "duration": 0.8, "size": [628, 101]}]},
{"id": "ask", "content": {"text": {"text": "Ask Architect", "size": 34, "color": "#1b1a19", "weight": "regular", "face": "sans"}}, "transform": {"position": [770, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "sweep", "start": 1.72, "duration": 0.3}]},
{"id": "card", "content": {"shape": {"size": [790, 471], "cornerRadius": 34, "color": "#ae7a97", "picture": "petal"}}, "transform": {"position": [957, 538, 0]}, "moves": [
  {"move": "morph", "start": 0.2, "duration": 0.4, "size": [292, 292], "radius": 146}, {"move": "morph", "start": 0.62, "duration": 0.85, "size": [78, 78]},
  {"move": "dots", "start": 0.75}, {"move": "morph", "start": 1.5, "duration": 0.65, "to": [696, 540], "size": [72, 72]}]}
```

The card is last, over the pill.

## The input on a picture card

A `plain` scene: a picture card nearly filling the frame eases out to 23 px margins, the white bar on it grows a little,
the placeholder is swept in, then swapped for the request typed.

```json
{"id": "roseCard", "content": {"shape": {"size": [1744, 966], "cornerRadius": 18, "color": "#96617f", "picture": "rose"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "morph", "start": 0.0, "duration": 0.53, "size": [1874, 1039]}]},
{"id": "bar", "content": {"shape": {"size": [1025, 163], "cornerRadius": 40, "color": "#ffffff"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "morph", "start": 0.0, "duration": 0.53, "size": [1080, 205]}]},
{"id": "placeholder", "content": {"text": {"text": "Ask Architect to improve your agent", "size": 40, "color": "#888888", "weight": "regular", "face": "sans"}}, "transform": {"position": [470, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "sweep", "start": 0.45, "duration": 0.4}, {"move": "hide", "start": 1.2}]},
{"id": "request", "content": {"text": {"text": "Make it calmer with upset callers", "size": 40, "color": "#1b1a19", "weight": "regular", "face": "sans"}}, "transform": {"position": [470, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "show", "start": 1.2}, {"move": "type", "start": 1.2, "duration": 1.1}]}
```

## A statement lit word by word

On `ink` at 92 px white, or on paper at 68 px ink. Give it 2.5–3 s.

```json
{"id": "standards", "content": {"text": {"text": "to the standards you set", "size": 92, "color": "#f9fafb", "weight": "regular", "face": "sans"}}, "transform": {"position": [960, 530, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "brighten", "start": 0.09}]}
```

## A card growing into the frame, the names cutting by

One group in a `plain` scene: the card grows from the cut with its words already on it; full-frame picture rectangles
`show` every 0.667 s under the words, and the tool's name swaps with them. Its picture must take white type.

```json
{"id": "connectLine", "content": {"group": [
  {"id": "card", "content": {"shape": {"size": [1152, 763], "cornerRadius": 11.5, "color": "#868d9e", "picture": "dusk"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "grow", "start": 0.0}]},
  {"id": "picture1", "content": {"shape": {"size": [1980, 1110], "cornerRadius": 0, "color": "#96617f", "picture": "rose"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "show", "start": 1.267}]},
  {"id": "connect", "content": {"text": {"text": "Connect Architect to", "size": 68, "color": "#ffffff", "weight": "regular", "face": "sans"}}, "transform": {"position": [436, 536, 0], "anchor": [0, 0.5]}},
  {"id": "dash", "content": {"shape": {"size": [68, 2], "cornerRadius": 0, "color": "#ffffffb3"}}, "transform": {"position": [1062, 538, 0]}},
  {"id": "name0", "content": {"text": {"text": "Claude", "size": 68, "color": "#ffffff", "weight": "regular", "face": "sans"}}, "transform": {"position": [1136, 536, 0], "anchor": [0, 0.5]}, "moves": [{"move": "hide", "start": 1.267}]},
  {"id": "name1", "content": {"text": {"text": "Cursor", "size": 68, "color": "#ffffff", "weight": "regular", "face": "sans"}}, "transform": {"position": [1136, 536, 0], "anchor": [0, 0.5]}, "moves": [{"move": "show", "start": 1.267}]}
]}, "transform": {"position": [0, 0, 0]}}
```

## Words parting round a sphere

A picture sphere shrinking as the two words either side of it move apart, then closing again before the cut. The words are
one group.

```json
{"id": "sphere", "content": {"shape": {"size": [655, 655], "cornerRadius": 327.5, "color": "#7283a9", "picture": "indigo"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "morph", "start": 0.0, "duration": 1.0, "size": [414, 414]}, {"move": "morph", "start": 1.45, "duration": 0.25, "size": [546, 546]}]},
{"id": "words", "content": {"group": [
  {"id": "improve", "content": {"text": {"text": "Improve", "size": 68, "color": "#1b1a19", "weight": "regular", "face": "sans"}}, "transform": {"position": [492, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "morph", "start": 0.0, "duration": 0.3, "to": [476, 540]}, {"move": "morph", "start": 1.45, "duration": 0.25, "to": [504, 540]}]},
  {"id": "yours", "content": {"text": {"text": "your agents", "size": 68, "color": "#1b1a19", "weight": "regular", "face": "sans"}}, "transform": {"position": [1162, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "morph", "start": 0.03, "duration": 0.6, "to": [1213, 540]}, {"move": "morph", "start": 1.45, "duration": 0.25, "to": [1150, 540]}]}
]}, "transform": {"position": [0, 0, 0]}}
```
