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
| A row of outlined pills (listeners, Invite, Leave) | 430×130 and 285×126, stroke 3, labels 54 px, across 70 % of the width |
| A chip inside a flood | 300×84, stroke 3, its label 40 px |
| Kinetic type | 150 px bold |
| An icon's disc | 110 px in its row, its glyph 56–60 px; panned in on at 2.4×, 260 px on screen |
| The pointer's hand | 8 % of the frame's height (Reco sizes it) |

## 1. A list that builds and scrolls

The rows are lifted, one asset per row:

```json
{"id": "row1", "url": "<page>", "viewport": [390, 844], "selector": "div:nth-of-type(1) > <row selector>", "bare": true}
```

Put rows 1 to 12 in a group, 215 px apart. It builds, scrolls so the last rows rest at the top, then leaves as the
next thing (recipe 2's dash) is already coming:

```json
{"id": "list", "content": {"group": [
   {"id": "r1", "content": {"ui": {"asset": "row1", "width": 1070}}, "transform": {"position": [0, 0, 0]}},
   {"id": "r2", "content": {"ui": {"asset": "row2", "width": 1070}}, "transform": {"position": [0, 215, 0]}}]},
 "transform": {"position": [960, 420, 0]},
 "moves": [{"move": "cascade", "start": 0.35}, {"move": "scroll", "start": 1.5, "to": [960, -1735]}, {"move": "exit", "start": 3.45, "direction": "up", "duration": 0.35}]}
```

Add the rest of the rows the same way. The header over it scrolls along with it:

```json
{"id": "header", "content": {"group": [
   {"id": "title", "content": {"text": {"text": "Queue", "size": 52}}, "transform": {"position": [-520, 0, 0], "anchor": [0, 0.5]}},
   {"id": "sub", "content": {"text": {"text": "Playing next", "size": 32, "weight": "regular", "color": "#a7a7a7"}}, "transform": {"position": [-520, 54, 0], "anchor": [0, 0.5]}}]},
 "transform": {"position": [960, 150, 0]}, "moves": [{"move": "fadeUp", "start": 0.1}, {"move": "scroll", "start": 1.5, "to": [960, -2005]}]}
```

## 2. The pill button: dash → pill → words → hover → letters → click → flood → iris

The dash pops under the list as it leaves, grows while it's still popping and rises before it's done growing. Its
words spring in as it arrives. On hover it lifts and grows 20 % with its label; the press brings both back. The chip
is there as soon as the flood fills, so the flood opens around it. Its bands are inside the flood and go with it in
the iris.

```json
{"id": "pill", "content": {"shape": {"size": [40, 14], "color": "#1ed760", "cornerRadius": 7}}, "transform": {"position": [960, 1000, 0]}, "moves": [{"move": "pop", "start": 3.3}, {"move": "morph", "start": 3.33, "size": [560, 184]}, {"move": "morph", "start": 3.55, "to": [960, 540]}, {"move": "morph", "start": 4.85, "size": [672, 221], "to": [960, 505], "duration": 0.12}, {"move": "click", "start": 5.2, "duration": 0.35}, {"move": "morph", "start": 5.1, "size": [560, 184], "to": [960, 540], "duration": 0.2}, {"move": "flood", "start": 5.72}, {"move": "ripple", "start": 6.3, "color": "#3bf07c", "stroke": 90}, {"move": "ripple", "start": 6.57, "color": "#14b24c", "stroke": 70}, {"move": "morph", "start": 7.05, "size": [430, 130], "duration": 0.3}], "shadow": {"opacity": 0.8, "radius": 40, "offset": 0, "color": "#1ed760"}},
{"id": "this", "content": {"text": {"text": "This is different", "size": 60, "color": "#000000", "weight": "semibold"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "letters", "start": 3.9}, {"move": "exit", "start": 4.6, "direction": "up", "duration": 0.2}]},
{"id": "start", "content": {"text": {"text": "Start a Jam", "size": 64, "color": "#000000", "weight": "bold"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "letters", "start": 4.85}, {"move": "morph", "start": 4.85, "to": [960, 505], "duration": 0.12}, {"move": "morph", "start": 5.1, "to": [960, 540], "duration": 0.2}, {"move": "exit", "start": 5.6, "duration": 0.2}]},
{"id": "chip", "content": {"group": [{"id": "chipRing", "content": {"shape": {"size": [300, 84], "color": "#0b6e30", "cornerRadius": 42, "stroke": 3}}, "transform": {"position": [0, 0, 0]}, "moves": []}, {"id": "starting", "content": {"text": {"text": "Starting", "size": 40, "color": "#0b6e30", "weight": "semibold"}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "letters", "start": 6.0}]}]}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "pop", "start": 5.93}, {"move": "exit", "start": 7.12, "duration": 0.15}]}
```

The scene is 7.38 s and cuts on the beat to the next with the pill there at 430×130.

## 3. A pill that drains, fills with listeners and splits

The next scene starts on that pill and drains it to an outline at once. The listeners slide into it from the right,
then the outline and its listeners move left as one group while Invite and Leave slide out of it to the right: each
starts where the outline was and travels to its place. The hover outline moves from Invite to Leave. Invite is
chosen: it fills, lifts while the others leave, then flies to where the next scene's text starts, shrinking to a
dot, and stretches into a caret.

```json
{"id": "fill2", "content": {"shape": {"size": [430, 130], "color": "#1ed760", "cornerRadius": 65}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "morph", "start": 0.1, "color": "#1ed76000", "size": [400, 110], "duration": 0.18}]},
{"id": "listening", "content": {"group": [{"id": "ring2", "content": {"shape": {"size": [430, 130], "color": "#1ed760", "cornerRadius": 65, "stroke": 3}}, "transform": {"position": [0, 0, 0]}, "moves": []}, {"id": "avatars", "content": {"group": [{"id": "a1", "content": {"ui": {"asset": "art1", "width": 87}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "slideIn", "start": 0.18, "direction": "left", "duration": 0.45}]}, {"id": "a2", "content": {"ui": {"asset": "art2", "width": 87}}, "transform": {"position": [66, 0, 0]}, "moves": [{"move": "slideIn", "start": 0.23, "direction": "left", "duration": 0.45}]}, {"id": "a3", "content": {"ui": {"asset": "art3", "width": 87}}, "transform": {"position": [132, 0, 0]}, "moves": [{"move": "slideIn", "start": 0.28, "direction": "left", "duration": 0.45}]}]}, "transform": {"position": [-146, 0, 0]}, "moves": []}, {"id": "count", "content": {"text": {"text": "3", "size": 51, "color": "#ffffff", "weight": "semibold"}}, "transform": {"position": [150, 0, 0]}, "moves": [{"move": "pop", "start": 0.42}]}]}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "morph", "start": 0.55, "to": [600, 540]}, {"move": "exit", "start": 2.0, "duration": 0.2}]},
{"id": "invite", "content": {"group": [{"id": "inviteRing", "content": {"shape": {"size": [285, 126], "color": "#ffffff70", "cornerRadius": 63, "stroke": 3}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "morph", "start": 1.0, "color": "#1ed760"}, {"move": "morph", "start": 1.33, "color": "#ffffff70"}, {"move": "morph", "start": 1.8, "stroke": 0, "color": "#1ed760", "duration": 0.12}, {"move": "morph", "start": 2.1, "size": [64, 64], "duration": 0.3}, {"move": "morph", "start": 2.42, "size": [16, 130], "radius": 5, "duration": 0.15}]}, {"id": "inviteLabel", "content": {"text": {"text": "Invite", "size": 54, "color": "#ffffff", "weight": "medium"}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "exit", "start": 1.84, "duration": 0.12}]}]}, "transform": {"position": [1400, 540, 0]}, "moves": [{"move": "pop", "start": 0.6}, {"move": "morph", "start": 0.6, "to": [1040, 540]}, {"move": "click", "start": 1.8, "duration": 0.2}, {"move": "morph", "start": 1.86, "to": [1040, 470], "duration": 0.2}, {"move": "morph", "start": 2.1, "to": [572, 540], "duration": 0.3}]},
{"id": "leave", "content": {"group": [{"id": "leaveRing", "content": {"shape": {"size": [285, 126], "color": "#ffffff70", "cornerRadius": 63, "stroke": 3}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "morph", "start": 1.33, "color": "#1ed760"}]}, {"id": "leaveLabel", "content": {"text": {"text": "Leave", "size": 54, "color": "#ffffff", "weight": "medium"}}, "transform": {"position": [0, 0, 0]}, "moves": []}]}, "transform": {"position": [1700, 540, 0]}, "moves": [{"move": "pop", "start": 0.78}, {"move": "morph", "start": 0.78, "to": [1360, 540]}, {"move": "exit", "start": 1.95, "duration": 0.2}]}
```

This scene is 2.62 s long. The caret ends where the next scene's text starts (its left edge, a little
in): the kinetic caret is there from the cut, so it holds still across it.

## 4. Kinetic type, clicked

```json
{"id": "type", "duration": 2.4, "seam": "cut", "camera": {"moves": [{"move": "push", "start": 1.2, "duration": 0.9, "intensity": 2}]}, "layers": [{"id": "title", "content": {"text": {"text": "Patient Zero", "size": 150, "color": "#ffffff", "weight": "bold"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "kinetic", "start": 0.1}, {"move": "click", "start": 1.45}, {"move": "exit", "start": 2.22, "duration": 0.15}]}]}
```

## 5. Added: in on the plus, a check in a burst, back out into the queue

One scene. The song's row pops in at its place at the top of the queue while the camera flies toward it, then pans
in on its plus, which spins in. A disc pops behind the plus, fills, bursts and pulses, and a check pops in. The camera
pans back out to the frame's middle: the check is the row's icon, and the queue builds under it, then scrolls until
its last rows rest at the top. The song's row is lifted with `region` [[0, 0], [300, 64]], leaving out its own
buttons.

```json
{"id": "add", "duration": 7.0, "seam": "cut", "camera": {"moves": [{"move": "pan", "start": 0.05, "to": [960, 330], "intensity": 1.6, "duration": 0.5}, {"move": "pan", "start": 0.55, "to": [1430, 330], "intensity": 2.4, "duration": 0.55}, {"move": "pan", "start": 2.05, "to": [960, 540], "intensity": 1, "duration": 0.8}]}, "layers": [
{"id": "added", "content": {"group": [{"id": "song2", "content": {"ui": {"asset": "song", "width": 840}}, "transform": {"position": [-120, 0, 0]}, "moves": [{"move": "pop", "start": 0.1, "intensity": 1.2}]}, {"id": "disc2", "content": {"shape": {"size": [110, 110], "color": "#ffffff26", "cornerRadius": 55}}, "transform": {"position": [470, 0, 0]}, "moves": [{"move": "pop", "start": 0.95}, {"move": "morph", "start": 1.2, "color": "#1ed760", "duration": 0.18}, {"move": "burst", "start": 1.32}, {"move": "ripple", "start": 1.36}]}, {"id": "plus2", "content": {"shape": {"size": [56, 56], "color": "#ffffff", "stroke": 5, "kind": "plus"}}, "transform": {"position": [470, 0, 0]}, "moves": [{"move": "pop", "start": 0.3}, {"move": "spin", "start": 0.3}, {"move": "exit", "start": 1.2, "duration": 0.1}]}, {"id": "check2", "content": {"shape": {"size": [60, 60], "color": "#000000", "stroke": 7, "kind": "check"}}, "transform": {"position": [470, 0, 0]}, "moves": [{"move": "pop", "start": 1.44}]}]}, "transform": {"position": [960, 330, 0]}, "moves": [{"move": "scroll", "start": 3.42, "to": [960, -1415]}]},
{"id": "header2", "content": {"group": [{"id": "queue2", "content": {"text": {"text": "Queue", "size": 52, "color": "#ffffff", "weight": "bold"}}, "transform": {"position": [-520, 0, 0], "anchor": [0, 0.5]}, "moves": []}, {"id": "next2", "content": {"text": {"text": "Playing next", "size": 32, "color": "#a7a7a7", "weight": "regular"}}, "transform": {"position": [-520, 54, 0], "anchor": [0, 0.5]}, "moves": []}]}, "transform": {"position": [960, 150, 0]}, "moves": [{"move": "fadeUp", "start": 2.3}, {"move": "scroll", "start": 3.3, "to": [960, -1595]}]},
{"id": "listeners", "content": {"group": [{"id": "l1", "content": {"ui": {"asset": "art1", "width": 58}}, "transform": {"position": [0, 0, 0]}, "moves": []}, {"id": "l2", "content": {"ui": {"asset": "art2", "width": 58}}, "transform": {"position": [44, 0, 0]}, "moves": []}, {"id": "l3", "content": {"ui": {"asset": "art3", "width": 58}}, "transform": {"position": [88, 0, 0]}, "moves": []}, {"id": "listening", "content": {"text": {"text": "3 listening", "size": 32, "color": "#a7a7a7", "weight": "regular"}}, "transform": {"position": [134, 0, 0], "anchor": [0, 0.5]}, "moves": []}]}, "transform": {"position": [1170, 150, 0]}, "moves": [{"move": "cascade", "start": 2.45}, {"move": "scroll", "start": 3.3, "to": [1170, -1595]}]},
{"id": "list2", "content": {"group": [{"id": "q2", "content": {"ui": {"asset": "row2", "width": 1070}}, "transform": {"position": [0, 0, 0]}, "moves": []}, {"id": "q3", "content": {"ui": {"asset": "row3", "width": 1070}}, "transform": {"position": [0, 215, 0]}, "moves": []}, {"id": "q4", "content": {"ui": {"asset": "row4", "width": 1070}}, "transform": {"position": [0, 430, 0]}, "moves": []}, {"id": "q5", "content": {"ui": {"asset": "row5", "width": 1070}}, "transform": {"position": [0, 645, 0]}, "moves": []}, {"id": "q6", "content": {"ui": {"asset": "row6", "width": 1070}}, "transform": {"position": [0, 860, 0]}, "moves": []}, {"id": "q7", "content": {"ui": {"asset": "row7", "width": 1070}}, "transform": {"position": [0, 1075, 0]}, "moves": []}, {"id": "q8", "content": {"ui": {"asset": "row8", "width": 1070}}, "transform": {"position": [0, 1290, 0]}, "moves": []}, {"id": "q9", "content": {"ui": {"asset": "row9", "width": 1070}}, "transform": {"position": [0, 1505, 0]}, "moves": []}, {"id": "q10", "content": {"ui": {"asset": "row10", "width": 1070}}, "transform": {"position": [0, 1720, 0]}, "moves": []}]}, "transform": {"position": [960, 545, 0]}, "moves": [{"move": "cascade", "start": 2.4, "duration": 1.4}, {"move": "scroll", "start": 3.54, "to": [960, -1200]}, {"move": "exit", "start": 5.75, "direction": "up", "duration": 0.35}]}]}
```

## 6. The end

Use one of these:

- **The logo under the list:** a lifted `svg` from the marketing site's header (`header svg`, `bare`), about 520 px
  wide, low in the frame where the scrolled list has left room. It sharpens in as the list rests and stays as the
  list leaves:

  ```json
  {"id": "logo", "content": {"ui": {"asset": "logo", "width": 520}}, "transform": {"position": [960, 820, 0]}, "moves": [{"move": "blurIn", "start": 5.4}, {"move": "exit", "start": 6.6, "duration": 0.3}]}
  ```

  A logo lifted with a box behind it shows the page's paint: Spotify's web player drew one; the same logo on
  www.spotify.com didn't. Try another page of the site.
- **The closing shot** (reco-launch-film's): the name in small mono caps with the product's words swapped beside
  it, then the logo. It's drawn on black.
