# Recipes

Components of the reference, rebuilt and checked against its frames at 1920×1080. Copy them and change the
words, colours and assets. `#1ed760` stands for the brand's colour.

## Scale

What reads on 1920×1080, from the reference:

| Thing | Size |
|---|---|
| A list row | 1070 px wide; cover art 135 px; rows 215 px apart; 3–4 in view |
| A header | 52 px bold, the line under it 32 px regular in `#a7a7a7` |
| A pill button | 560×184, its label 60–64 px, black on the brand colour |
| An outlined chip or small button | 190×84, stroke 3, its label 36 px |
| Kinetic type | 150 px bold |
| An icon's disc | 170 px, its glyph 90–100 px |
| The pointer's hand | 8 % of the frame's height (Reco sizes it) |

## 1. A list that builds and scrolls

The rows are lifted, one asset per row:

```json
{"id": "row1", "url": "<page>", "viewport": [390, 844], "selector": "div:nth-of-type(1) > <row selector>", "bare": true}
```

Put rows 1 to 12 in a group, 215 px apart. It builds, scrolls so the last rows rest at the top, then leaves:

```json
{"id": "list", "content": {"group": [
   {"id": "r1", "content": {"ui": {"asset": "row1", "width": 1070}}, "transform": {"position": [0, 0, 0]}},
   {"id": "r2", "content": {"ui": {"asset": "row2", "width": 1070}}, "transform": {"position": [0, 215, 0]}}]},
 "transform": {"position": [960, 420, 0]},
 "moves": [{"move": "cascade", "start": 0.35}, {"move": "scroll", "start": 1.5, "to": [960, -1735]}, {"move": "exit", "start": 3.3, "direction": "up"}]}
```

Add the rest of the rows the same way. The header over it scrolls along with it:

```json
{"id": "header", "content": {"group": [
   {"id": "title", "content": {"text": {"text": "Queue", "size": 52}}, "transform": {"position": [-520, 0, 0], "anchor": [0, 0.5]}},
   {"id": "sub", "content": {"text": {"text": "Playing next", "size": 32, "weight": "regular", "color": "#a7a7a7"}}, "transform": {"position": [-520, 54, 0], "anchor": [0, 0.5]}}]},
 "transform": {"position": [960, 150, 0]}, "moves": [{"move": "fadeUp", "start": 0.1}, {"move": "scroll", "start": 1.5, "to": [960, -2005]}]}
```

## 2. The pill button: dot → pill → words → hover → letters → click → flood → iris

```json
{"id": "pill", "content": {"shape": {"size": [40, 40], "cornerRadius": 20, "color": "#1ed760"}}, "transform": {"position": [960, 1000, 0]},
 "shadow": {"opacity": 0.6, "radius": 34, "offset": 0, "color": "#1ed760"},
 "moves": [{"move": "pop", "start": 3.3}, {"move": "morph", "start": 3.45, "size": [560, 184]}, {"move": "morph", "start": 3.8, "to": [960, 540]},
   {"move": "morph", "start": 4.85, "size": [615, 202], "duration": 0.12}, {"move": "click", "start": 5.2, "duration": 0.4},
   {"move": "morph", "start": 5.35, "size": [560, 184], "duration": 0.25}, {"move": "flood", "start": 5.75},
   {"move": "ripple", "start": 6.35, "color": "#3bf07c", "stroke": 90, "intensity": 2.5},
   {"move": "ripple", "start": 6.62, "color": "#14b24c", "stroke": 70, "intensity": 2.5},
   {"move": "morph", "start": 6.95, "size": [560, 184], "duration": 0.35}]},
{"id": "line1", "content": {"text": {"text": "This is different", "size": 60, "weight": "semibold", "color": "#000000"}}, "transform": {"position": [960, 540, 0]},
 "moves": [{"move": "wordByWord", "start": 3.95}, {"move": "exit", "start": 4.55, "direction": "up"}]},
{"id": "line2", "content": {"text": {"text": "Start a Jam", "size": 64, "color": "#000000"}}, "transform": {"position": [960, 540, 0]},
 "moves": [{"move": "letters", "start": 4.85}, {"move": "exit", "start": 5.6}]},
{"id": "chip", "content": {"shape": {"size": [300, 84], "cornerRadius": 42, "color": "#0b6e30", "stroke": 3}}, "transform": {"position": [960, 540, 0]},
 "moves": [{"move": "pop", "start": 6.2}, {"move": "exit", "start": 6.9}]},
{"id": "chipLabel", "content": {"text": {"text": "Starting", "size": 40, "weight": "semibold", "color": "#0b6e30"}}, "transform": {"position": [960, 540, 0]},
 "moves": [{"move": "letters", "start": 6.3}, {"move": "exit", "start": 6.85}]}
```

The scene is 7.3 s and cuts on the beat to the next with the pill there at 560×184 or smaller.

## 3. A pill that drains and splits into buttons

The next scene starts on the pill and drains it to an outline. The outline moves left, avatars and a count fill it,
and two outlined buttons pop out beside it. The hover outline moves from the first to the second. The first is
chosen: it fills, shrinks to a dot and stretches into a caret for the next scene's type.

```json
{"id": "outline", "content": {"shape": {"size": [427, 116], "cornerRadius": 58, "color": "#1ed760", "stroke": 3}}, "transform": {"position": [960, 540, 0]},
 "moves": [{"move": "morph", "start": 0.7, "size": [300, 84], "to": [690, 540]}]},
{"id": "fill", "content": {"shape": {"size": [380, 92], "cornerRadius": 46, "color": "#1ed760"}}, "transform": {"position": [960, 540, 0]},
 "moves": [{"move": "morph", "start": 0.12, "color": "#1ed76000", "size": [300, 70], "duration": 0.3}]},
{"id": "avatars", "content": {"group": [
   {"id": "a1", "content": {"ui": {"asset": "art1", "width": 58}}, "transform": {"position": [0, 0, 0]}},
   {"id": "a2", "content": {"ui": {"asset": "art2", "width": 58}}, "transform": {"position": [44, 0, 0]}},
   {"id": "a3", "content": {"ui": {"asset": "art3", "width": 58}}, "transform": {"position": [88, 0, 0]}}]},
 "transform": {"position": [620, 540, 0]}, "moves": [{"move": "cascade", "start": 0.75}, {"move": "exit", "start": 2.15}]},
{"id": "count", "content": {"text": {"text": "3", "size": 34, "weight": "semibold"}}, "transform": {"position": [790, 540, 0]},
 "moves": [{"move": "pop", "start": 1.0}, {"move": "exit", "start": 2.2}]},
{"id": "invite", "content": {"group": [
   {"id": "inviteRing", "content": {"shape": {"size": [190, 84], "cornerRadius": 42, "color": "#ffffff70", "stroke": 3}},
    "moves": [{"move": "morph", "start": 1.25, "color": "#1ed760"}, {"move": "morph", "start": 1.65, "color": "#ffffff70"},
      {"move": "morph", "start": 2.05, "stroke": 0, "color": "#1ed760"}, {"move": "morph", "start": 2.36, "size": [56, 56]},
      {"move": "morph", "start": 2.55, "size": [16, 130], "radius": 5, "duration": 0.15}]},
   {"id": "inviteLabel", "content": {"text": {"text": "Invite", "size": 36, "weight": "medium"}}, "moves": [{"move": "exit", "start": 2.05, "duration": 0.15}]}]},
 "transform": {"position": [985, 540, 0]},
 "moves": [{"move": "pop", "start": 0.85}, {"move": "click", "start": 2.05, "duration": 0.2}, {"move": "morph", "start": 2.36, "to": [620, 540]}]},
{"id": "leave", "content": {"group": [
   {"id": "leaveRing", "content": {"shape": {"size": [190, 84], "cornerRadius": 42, "color": "#ffffff70", "stroke": 3}}, "moves": [{"move": "morph", "start": 1.65, "color": "#1ed760"}]},
   {"id": "leaveLabel", "content": {"text": {"text": "Leave", "size": 36, "weight": "medium"}}}]},
 "transform": {"position": [1205, 540, 0]}, "moves": [{"move": "pop", "start": 1.1}, {"move": "exit", "start": 2.25}]}
```

This scene is 2.7 s long.

## 4. Kinetic type, clicked

```json
{"id": "type", "duration": 2.4, "seam": "cut", "camera": {"moves": [{"move": "push", "start": 1.2, "duration": 0.9, "intensity": 2}]},
 "layers": [{"id": "title", "content": {"text": {"text": "Patient Zero", "size": 150}}, "transform": {"position": [960, 540, 0]},
   "moves": [{"move": "kinetic", "start": 0.1}, {"move": "click", "start": 1.45}]}]}
```

## 5. Added: a plus becomes a check in a burst

The song's row is lifted with `region` [[0, 0], [300, 64]], leaving out its own buttons. The camera pans to the
plus at its end.

```json
{"id": "add", "duration": 3.0, "seam": "cut", "camera": {"moves": [{"move": "pan", "start": 0.45, "to": [1430, 540], "intensity": 1.8, "duration": 0.6}]},
 "layers": [
  {"id": "song", "content": {"ui": {"asset": "song", "width": 840}}, "transform": {"position": [840, 540, 0]}, "moves": [{"move": "rise", "start": 0.1}]},
  {"id": "disc", "content": {"shape": {"size": [170, 170], "cornerRadius": 85, "color": "#ffffff26"}}, "transform": {"position": [1430, 540, 0]},
   "moves": [{"move": "pop", "start": 0.95}, {"move": "morph", "start": 1.2, "color": "#1ed760", "duration": 0.18}, {"move": "burst", "start": 1.32}, {"move": "ripple", "start": 1.36}]},
  {"id": "plus", "content": {"shape": {"kind": "plus", "size": [90, 90], "color": "#ffffff", "stroke": 6}}, "transform": {"position": [1430, 540, 0]},
   "moves": [{"move": "pop", "start": 0.2}, {"move": "exit", "start": 1.2, "duration": 0.1}]},
  {"id": "check", "content": {"shape": {"kind": "check", "size": [100, 100], "color": "#000000", "stroke": 11}}, "transform": {"position": [1430, 540, 0]},
   "moves": [{"move": "pop", "start": 1.44}]}]}
```

## 6. The end

Use one of these:

- **The closing shot** (reco-launch-film's): the name in small mono caps with the product's words swapped beside
  it, then the logo. It's drawn on black.
- **The logo alone:** a lifted `svg` or `img` from the navigation, `bare`, about 520 px wide, `blurIn` at 0.15
  and `exit` 0.6 s before the end. A logo lifted with a box behind it shows the page's paint: try the same logo
  on another page of the site.
