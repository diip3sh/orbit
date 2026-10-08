# Layers and moves for motion design

Every number here is measured on the reference unless it says otherwise. Positions and sizes are canvas pixels on
1920×1080. A layer's `transform.position` is where its anchor sits, which is its middle unless `anchor` says
otherwise (`[0, 0.5]` is its left edge's middle, for type that starts at a margin). Times are seconds into the
scene.

## Layers

**Shape:**

```json
{"id": "pill", "content": {"shape": {"size": [w, h], "cornerRadius": r, "color": "#rrggbb", "stroke": 3, "kind": "rectangle"}},
 "transform": {"position": [x, y, 0]}, "shadow": {"opacity": 0.7, "radius": 34, "offset": 0, "color": "#1ed760"}, "moves": []}
```

- `cornerRadius` half the height makes a pill. A pill stays a pill through every morph unless a morph sets
  `radius`.
- `stroke` draws the outline that wide instead of the fill. Colours take `#rrggbbaa`, so `#ffffff70` is
  translucent white.
- `kind`:
  - `rectangle` is the default: the only kind that morphs.
  - `triangle` is a filled triangle.
  - The glyphs `plus`, `check`, `cross`, `arrow`, `search`, `play` and `pause` are stroked in `color`, `stroke`
    wide (a tenth of the size without one). Turn them with `transform.rotation` [0, 0, degrees].
- `shadow` with `offset` 0 and a `color` is a glow in that colour. A morphing shape's glow follows its shape.

**Text:**

```json
{"id": "label", "content": {"text": {"text": "Start a Jam", "size": 64, "weight": "bold", "color": "#000000"}}, "transform": {"position": [x, y, 0]}}
```

- `weight` is regular, medium, semibold or bold.
- One line unless `width` is set.

**Lifted UI:**

```json
{"id": "r1", "content": {"ui": {"asset": "row1", "width": 1070}}, "transform": {"position": [x, y, 0]}}
```

- `width` in canvas pixels sets its size; its height follows.
- An asset that is a part of the page uses `bare: true` (no fill behind it) and a viewport such as `[390, 844]`
  for a phone layout.

**Group:**

```json
{"id": "list", "content": {"group": [layers]}, "transform": {"position": [x, y, 0]}}
```

- Its layers' positions are measured from the group's position.
- It moves, fades and scales them together.
- A `click` on a group presses where its layers are, and so does a pop on a button made of a pill and its label.

## Moves

`{"move": "<kind>", "start": s, "duration": d, …}`. Leave `duration` out for the measured default.

| Move | On | Fields | What it does | Default length |
|---|---|---|---|---|
| `morph` | Any layer; size, radius, colour and outline only on a rectangle | `size` [w, h], `radius`, `color`, `stroke` (0 fills it), `to` [x, y] | Changes the shape from where the morph before left it, and moves its anchor to `to`. Slow off, fast, long settle. Chain as many as you like. | 0.43 s (0.1–0.15 s for a hover) |
| `flood` | Rectangle | | A dip to 0.6 of its size, then out past the frame's corners, filled. A `morph` to a size after it is the iris back. | 0.57 s |
| `pop` | Any | `intensity` (1: from 0.6 of its size) | Appears, growing past its size and settling. | 0.4 s |
| `press` | Any | `intensity` | Dips to 0.92 and springs back past it. | 0.4 s |
| `click` | Any, a group too | | A pointer rises in from below over 0.5 s, lands 0.15 s before `start`, turns to a hand, presses the layer at `start` (as `press`), and fades after `duration`. Put it where the state changes. | 0.8 s after the press |
| `burst` | Any | `color`, `intensity` (how far) | About 36 triangles thrown out from its middle to most of the frame's height in 0.3 s, spinning and drifting, gone by 1.2 s. Behind it. | 1.2 s |
| `ripple` | Any; a rectangle's own shape | `color`, `stroke` (soft bands that wide), `intensity` (how far) | Two rings, 0.12 s apart, opening from its edge and fading, over it. Thin by default (a pulse round a check); with `stroke` 70–90, soft bands (the flood's). | 0.9 s |
| `letters` | Text | | Each letter springs up into place, 0.036 s apart, overshooting. | 0.036 s a letter + 0.32 s |
| `kinetic` | Text | `color` (the accent by default) | Typed at 13 characters a second behind a caret block. The newest letters are in the colour, fading to the text's over 0.25 s. The caret goes 0.6 s after the last letter. | Characters / 13 |
| `scroll` | Any, usually a group | `to` [x, y] | A long travel, slow off and slow in, blurred in its middle. A group that also has `cascade` builds each row as it comes into view. | From the distance, about 1.8 frame heights a second at the fastest |
| `cascade` | Group | | Its layers rise one after another; with a `scroll`, as they come into view. | |
| `exit` | Any | `direction` up, down, left or right | Leaves, blurring, the way it's told. | 0.25 s |
| `wordByWord` | Text | | Words fade up one after another. | |
| `blurIn`, `fadeUp`, `rise` | Any | | Comes in, sharpening, rising. | |

Camera moves sit on the scene: `"camera": {"moves": [...]}`.

- `push`: `intensity` 2 is 24 % closer.
- `pan`: `to` [x, y] is the point it looks at; `intensity` is how much closer it ends.
- `whip`, `pullBack`.

## Canvas

- `fieldStrength`, 0–1: how strongly the field shows. 0.45 tones a light look down to a glow.
- `frameRate` 30, as the reference.

## Scenes and seams

- Cut between scenes, on a beat, where the same object continues. End one scene on a pill of a size and place,
  and start the next with a pill of that size and place.
- Give each scene enough time for its moves: the last move's end plus about 0.3 s.
- A scene whose first layer must be there on its first frame shouldn't wait for an entrance. Lifted UI `rise`s
  from 0.

## Morphs, worked through

A pill that grows out of a dot, rises, grows on hover, is clicked and floods:

```json
"moves": [
  {"move": "pop", "start": 3.3},
  {"move": "morph", "start": 3.45, "size": [560, 184]},
  {"move": "morph", "start": 3.8, "to": [960, 540]},
  {"move": "morph", "start": 4.85, "size": [615, 202], "duration": 0.12},
  {"move": "click", "start": 5.2, "duration": 0.4},
  {"move": "morph", "start": 5.35, "size": [560, 184], "duration": 0.25},
  {"move": "flood", "start": 5.75},
  {"move": "ripple", "start": 6.35, "color": "#3bf07c", "stroke": 90, "intensity": 2.5},
  {"move": "morph", "start": 6.95, "size": [560, 184], "duration": 0.35}
]
```

An outlined button whose outline turns green on hover and which then fills, shrinks to a dot and stretches into
a caret:

```json
"moves": [
  {"move": "morph", "start": 1.25, "color": "#1ed760"},
  {"move": "morph", "start": 2.05, "stroke": 0},
  {"move": "morph", "start": 2.36, "size": [56, 56]},
  {"move": "morph", "start": 2.55, "size": [16, 130], "radius": 5, "duration": 0.15}
]
```
