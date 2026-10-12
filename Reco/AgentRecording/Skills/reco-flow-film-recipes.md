# Recipes for a flow film

Every component here was rendered and checked frame by frame, in Vantae's and IrukaDark's reels rebuilt. Positions and
sizes are canvas pixels on 1920×1080; a group's layers are placed from the group's position; times are seconds into the
scene. Write `"weight"` on every text layer.

**The colours below are Vantae's** (ink `#0d1220`, blue `#0b5cf0`, rim `#d3e3f8`, dim `#8a93a6`). Replace them with your
product's: its text, its colour, a pale tint of it for rims.

**On every cut, something is there from the first frame** (the thing that carries on) or pops at 0. After a seam, the seam
is the entrance and the scene's moves may start under it.

**The camera moves in every scene:** a `push` over the whole scene at intensity 2–3 (1.25–1.35× closer), a `pullBack` on
the end card, or in a macro a `drift` or a `pan` along the control. A push at 0.5 read as still.

## The marks

The product's logo: its site's `img` or `svg`, lifted `bare`. A brand's mark from Simple Icons, as SVG, tinted:

```json
{"id": "claude", "url": "https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/claude.svg", "selector": "img", "bare": true, "viewport": [400, 400]}
```

```json
{"id": "mark", "content": {"ui": {"asset": "claude", "width": 110, "tint": "#d97757"}}, "transform": {"position": [-205, 0, 0]}, "moves": [{"move": "fly", "start": 0.5}]}
```

Without a mark that lifts sharp, the brand's colour as a rounded square 110–120 px, corners a third of it.

## The need, typed huge

```json
{"id": "idea", "duration": 2.0, "camera": {"moves": [{"move": "push", "start": 0, "duration": 2.0, "intensity": 2.5}]}, "layers": [
  {"id": "said", "content": {"text": {"text": "Have an idea?", "size": 190, "color": "#0d1220", "weight": "regular"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "voice", "start": 0.1, "duration": 0.9}]}
]}
```

The newest words come in `style.gradient`, behind a thin caret; a line wider than the frame slides along after its caret.

## A line that becomes the search

IrukaDark's question pops a word at a time; the bar then grows round it, so the question is the search. The text sits
40 px right of the bar's middle, clear of the glass:

```json
{"id": "ask", "duration": 2.6, "camera": {"moves": [{"move": "push", "start": 0, "duration": 2.6, "intensity": 2.5}]}, "layers": [
  {"id": "bar", "content": {"group": [
    {"id": "sfill", "content": {"shape": {"size": [1400, 130], "cornerRadius": 65, "color": "#ffffff"}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "pop", "start": 1.55, "intensity": 0.3}], "shadow": {"opacity": 0.16, "radius": 40, "offset": 14}},
    {"id": "srim", "content": {"shape": {"size": [1400, 130], "cornerRadius": 65, "color": "#efd9e8", "stroke": 2}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "pop", "start": 1.55, "intensity": 0.3}]},
    {"id": "sglass", "content": {"shape": {"size": [44, 44], "cornerRadius": 0, "color": "#111318", "stroke": 4, "kind": "search"}}, "transform": {"position": [-630, 0, 0]}, "moves": [{"move": "pop", "start": 1.65, "intensity": 0.3}]}
  ]}, "transform": {"position": [960, 540, 0]}},
  {"id": "q", "content": {"text": {"text": "Still switching tabs to find answers?", "size": 64, "color": "#111318", "weight": "regular"}}, "transform": {"position": [1000, 540, 0]}, "moves": [{"move": "wordByWord", "start": 0.1}]}
]}
```

The next scene can repeat the bar and its text with the camera at 1.8× (`z` 768) panning along it, while what the search
brings pops above it: chips of 310×64 (white, rim, a 20 px dot in the brand's colour, 30 px text), 0.12 s apart.

## The input bar

White, a soft shadow, a pale rim, the request typed in ink behind a caret in the brand's colour, the send disc filled:

```json
{"id": "bar", "content": {"group": [
  {"id": "pfill", "content": {"shape": {"size": [1240, 140], "cornerRadius": 70, "color": "#ffffff"}}, "transform": {"position": [0, 0, 0]}, "shadow": {"opacity": 0.16, "radius": 40, "offset": 14}},
  {"id": "prim", "content": {"shape": {"size": [1240, 140], "cornerRadius": 70, "color": "#d3e3f8", "stroke": 2}}, "transform": {"position": [0, 0, 0]}},
  {"id": "pline", "content": {"text": {"text": "Create a mood board for a 70s interior", "size": 52, "color": "#0d1220", "weight": "regular"}}, "transform": {"position": [-556, 0, 0], "anchor": [0, 0.5]}, "moves": [{"move": "kinetic", "start": 0.35, "color": "#0b5cf0"}]},
  {"id": "psend", "content": {"shape": {"size": [96, 96], "cornerRadius": 48, "color": "#0b5cf0"}}, "transform": {"position": [550, 0, 0]}},
  {"id": "parrow", "content": {"shape": {"size": [36, 36], "cornerRadius": 0, "color": "#ffffff", "stroke": 4, "kind": "arrow"}}, "transform": {"position": [550, 0, 0], "rotation": [0, 0, -90]}}
]}, "transform": {"position": [960, 560, 0]}, "moves": [{"move": "pop", "start": 0, "intensity": 0.4}]}
```

- Coming out of the opening line: `"seam": "melt"` on its scene. The push makes the bar grow toward the viewer as typed.
- An attachment: a picture or file chip at the bar's left (84×84, corners 14, popping at 0), the text 120 px further right.

## A macro on send, then a dive

Repeat the bar with the text already typed (no move on it), the camera at 3× on the send (`z = 1728 × (1 − 1/zoom)`:
3× is 1152), drifting; the click in the scene's last 0.5 s:

```json
{"id": "send", "duration": 1.4, "camera": {"position": [1510, 560, 1152], "moves": [{"move": "drift", "start": 0, "direction": "left"}]}, "layers": [
  the bar again, "psend" with {"move": "click", "start": 0.9, "duration": 0.35}
]}
```

The next scene is what it made, with `"seam": "dive"`: the camera tilts and flies through the disc into it. Its results
come in on the cut: a group of them with `scatter` (thrown out of its middle) and a slow `spin` (intensity 0.5 over the
scene), or tiles popping 0.07 s apart. Vantae's nine pictures turned in a ring 330×250 round the middle, 200×156 each,
corners 14, each turned up to 14°, with the shadow `{"opacity": 0.22, "radius": 24, "offset": 8}`.

## Picking one

The results again, the camera at 2–2.2× on one of them, drifting; the hand clicks it in the scene's last 0.5 s. A click
on one layer of a group is that layer's:

```json
{"id": "pick", "duration": 1.4, "camera": {"position": [1285, 497, 943], "moves": [{"move": "drift", "start": 0, "direction": "right"}]}, "layers": [
  the results group again, the picked one with {"move": "click", "start": 0.85, "duration": 0.35}
]}
```

The next scene opens out of it with `"seam": "expand"`: the next step (a second prompt with it attached, its detail).

## The answer grows out of the box

The scene after a send starts with the bar as it was (a shape the bar's size) and morphs it into the card; the attached
thumbnail travels to the middle and grows into the result:

```json
{"id": "result", "duration": 2.6, "camera": {"moves": [{"move": "push", "start": 0.3, "duration": 2.3, "intensity": 3}]}, "layers": [
  {"id": "card", "content": {"shape": {"size": [1240, 140], "cornerRadius": 70, "color": "#ffffff"}}, "transform": {"position": [960, 560, 0]}, "moves": [{"move": "morph", "start": 0.05, "size": [1000, 660], "radius": 40}], "shadow": {"opacity": 0.16, "radius": 40, "offset": 14}},
  {"id": "photo", "content": {"shape": {"size": [84, 84], "cornerRadius": 14, "color": "#b5562e"}}, "transform": {"position": [446, 560, 0]}, "moves": [{"move": "morph", "start": 0.15, "size": [880, 540], "radius": 20, "to": [960, 560]}]}
]}
```

A lifted picture (`ui`) can't morph its size: let it `pop` in the card at 0.3 instead, or morph a shape in its colour first.

## A key that opens

"One click [key] instant answer": the words pop, the key cap pops in the gap and is pressed in the scene's last 0.5 s; the
next scene opens out of it (`"seam": "expand"`):

```json
{"id": "key", "duration": 2.4, "camera": {"moves": [{"move": "push", "start": 0, "duration": 2.4, "intensity": 2.5}]}, "layers": [
  {"id": "one", "content": {"text": {"text": "One click", "size": 80, "color": "#111318", "weight": "regular"}}, "transform": {"position": [800, 540, 0], "anchor": [1, 0.5]}, "moves": [{"move": "wordByWord", "start": 0}]},
  {"id": "cap", "content": {"group": [
    {"id": "kf", "content": {"shape": {"size": [120, 120], "cornerRadius": 26, "color": "#ffffff"}}, "transform": {"position": [0, 0, 0]}, "shadow": {"opacity": 0.16, "radius": 40, "offset": 14}},
    {"id": "kr", "content": {"shape": {"size": [120, 120], "cornerRadius": 26, "color": "#e6e1ea", "stroke": 3}}, "transform": {"position": [0, 0, 0]}},
    {"id": "kb", "content": {"shape": {"size": [56, 8], "cornerRadius": 4, "color": "#111318"}}, "transform": {"position": [0, 22, 0]}}
  ]}, "transform": {"position": [880, 540, 0]}, "moves": [{"move": "pop", "start": 0.5}, {"move": "click", "start": 1.9, "duration": 0.3}]},
  {"id": "inst", "content": {"text": {"text": "instant answer", "size": 80, "color": "#111318", "weight": "regular"}}, "transform": {"position": [960, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "wordByWord", "start": 0.9}]}
]}
```

The key can be any control: a shortcut, a chip, an app icon. Put the words' anchors either side of it.

## A sentence selected and explained

The arrow drags a selection across the sentence (`select`, 60 characters a second, held after), then the answer comes over
it (`"seam": "stack"` on the next scene) and streams in (`reply`):

```json
{"id": "error", "duration": 2.2, "seam": "expand", "camera": {"moves": [{"move": "push", "start": 0, "duration": 2.2, "intensity": 2.5}]}, "layers": [
  {"id": "card", "content": {"shape": {"size": [1120, 600], "cornerRadius": 40, "color": "#ffffff"}}, "transform": {"position": [960, 540, 0]}, "shadow": {"opacity": 0.16, "radius": 40, "offset": 14}},
  {"id": "x", "content": {"shape": {"size": [96, 96], "cornerRadius": 0, "color": "#e5484d", "stroke": 5, "kind": "cross"}}, "transform": {"position": [960, 330, 0]}},
  {"id": "msg", "content": {"text": {"text": "Error 520\nSomething went wrong", "size": 84, "color": "#111318", "weight": "semibold", "width": 1000}}, "transform": {"position": [960, 530, 0]}, "moves": [{"move": "select", "start": 0.55}]},
  {"id": "note", "content": {"text": {"text": "Try again or contact support", "size": 38, "color": "#8b8796", "weight": "regular"}}, "transform": {"position": [960, 700, 0]}}
]},
{"id": "explain", "duration": 2.8, "seam": "stack", "camera": {"moves": [{"move": "push", "start": 0, "duration": 2.8, "intensity": 2}]}, "layers": [
  {"id": "panel", "content": {"group": [
    {"id": "pf", "content": {"shape": {"size": [1000, 640], "cornerRadius": 40, "color": "#16112b"}}, "transform": {"position": [0, 0, 0]}, "shadow": {"opacity": 0.3, "radius": 50, "offset": 18}},
    {"id": "ph", "content": {"text": {"text": "Selection explanation", "size": 36, "color": "#b9a8ff", "weight": "regular"}}, "transform": {"position": [-430, -250, 0], "anchor": [0, 0.5]}},
    {"id": "pl", "content": {"shape": {"size": [860, 3], "cornerRadius": 1.5, "color": "#e0218a"}}, "transform": {"position": [0, -205, 0]}},
    {"id": "pr", "content": {"text": {"text": "This is a gateway error: the server\nreached the site, but the site\ndidn't answer in time.", "size": 48, "color": "#ffffff", "weight": "regular", "width": 880}}, "transform": {"position": [-430, -170, 0], "anchor": [0, 0]}, "moves": [{"move": "reply", "start": 0.3}]}
  ]}, "transform": {"position": [960, 560, 0]}}
]}
```

`select` takes `color` for another highlight than the system's light blue. The panel is the product's own (IrukaDark's is
dark); a light product's is a white card.

## Contents cycling

IrukaDark's app shows every tab in turn, one every 0.5 s, in one panel that stays: each tab's contents a group, the first
`hide` at 0.5, the next `show` at 0.5 and `hide` at 1.0, and so on; the panel pops at 0 and the camera pushes. Give each
tab its own title (40 px `semibold`) and its own rows (40 px), or one big thing (a timer at 96 px).

## The end

`"seam": "melt"` from the last picture or answer, then the name and its mark:

```json
{"id": "end", "duration": 2.8, "seam": "melt", "camera": {"moves": [{"move": "pullBack", "start": 0, "duration": 2.8, "intensity": 0.6}]}, "layers": [
  {"id": "lock", "content": {"group": [
    {"id": "mark", "content": {"shape": {"size": [118, 118], "cornerRadius": 36, "color": "#0b5cf0"}}, "transform": {"position": [-205, 0, 0]}, "moves": [{"move": "fly", "start": 0.5}]},
    {"id": "name", "content": {"text": {"text": "Vantae", "size": 130, "color": "#0d1220", "weight": "semibold"}}, "transform": {"position": [-120, 0, 0], "anchor": [0, 0.5]}, "moves": [{"move": "letters", "start": 0.2}]}
  ]}, "transform": {"position": [960, 540, 0]}}
]}
```

- `fly` comes from the right and above by default (`"direction": "left"`, the way it travels); `"direction": "up"` comes
  from below and the left, as IrukaDark's closing mark does. It lands 0.9 s after its start.
- Put the group's position so the name and mark sit centred together: the name's width is about 0.55 of its size per
  character.
- A tagline under it: 56–64 px, dim, `wordByWord` from 1.2 s.
