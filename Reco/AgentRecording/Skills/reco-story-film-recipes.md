# Recipes for a story film

Every component here was rendered and checked frame by frame. Positions and sizes are canvas pixels on 1920×1080. A
group's layers are placed from the group's position. Times are seconds into the scene and sit on the 0.353 s beat.
Write `"weight"` on every text layer.

**The colours below are a black and white developer tool's** (Orca: ground `#08090a`, dim text `#8a8f98`, green
`#3ddc84`, diff green `#0ac864` and red `#e5484d`). Replace every one with your product's own theme: its ground, text,
button and status colours.

**Every surface is glass:** the box, a menu, every tile and card, the result read close, the finish's bar. A surface is a
filled rectangle with `"glass": true` and a light veil for its colour (`#ffffff0d`), with no shadow and no edge of its
own: the look's ground shows blurred through it, its rim is lit and it casts its own shadow. Pills and chips on glass are
`#ffffff14`. A flat, opaque card over a shader's ground reads as a cut-out.

On every cut, something is on screen from the first frame: the thing that carries on from the scene before, still
(the box, the thread, a pane), or the first new thing popping at 0. Don't hold anything back 0.1 s; the cut is the
transition. After one of the look's seams, the seam is the entrance: start the scene's pops at 2 beats (0.706 s).

Every answer is framed whole: centred, 60–80 % of the frame's width, nothing cut by the frame's edge. Only a macro (the
camera 2× or closer on one control) crops, and then only the box round its control. preview_motion names text that runs
off the frame.

## The marks

Lift brand marks (the product's, its integrations', the agents' or models' it runs) from Simple Icons, as SVG, so they're
sharp at any size, and tint each in its own colour, as the product's site shows them:

```json
{"id": "claude", "url": "https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/claude.svg", "selector": "img", "bare": true, "viewport": [400, 400]}
```

```json
{"id": "aClaudeL", "content": {"ui": {"asset": "claude", "width": 96, "tint": "#d97757"}}, "transform": {"position": [-120, -42, 0]}}
```

- The slug is the brand's name in lower case without spaces or dots (`openai`, `googlegemini`, `githubcopilot`, `cursor`,
  `linear`, `github`, `vercel`, `supabase`, `figma`, `slack`, `notion`, `stripe`). Check it with WebFetch when you can.
- Colours: Claude `#d97757`, Gemini `#5b8cff`, Linear `#8b93ff`; OpenAI, Cursor, GitHub, Copilot and Vercel white on a
  dark tile; otherwise the brand's own. On a light tile, a mark is the tile's dark.
- The product's own logo: its site's `img` or `svg` element, lifted `bare`, tinted its text colour (or dark on its
  inverted tile).
- Never lift a mark from a sprite or a small raster: at 4K it's soft.

## The prompt box

A group in the frame's middle, 62 % of the width. Rebuild it rather than lift it: it must be pressed, washed and
dissolved. Use the product's own placeholder, control names and colours. Its type is Lovable's size: the hint 50 px, the
pills 84 tall with 42 px labels, the send disc 88.

```json
{"id": "box", "content": {"group": [
  {"id": "boxFill", "content": {"shape": {"size": [1190, 370], "cornerRadius": 44, "color": "#ffffff0d", "glass": true}}, "transform": {"position": [0, 0, 0]}},
  {"id": "hint", "content": {"text": {"text": "Describe a task for your agents…", "size": 50, "weight": "regular", "color": "#6e7178"}},
   "transform": {"position": [-548, -112, 0], "anchor": [0, 0.5]}},
  {"id": "plus", "content": {"shape": {"kind": "plus", "size": [38, 38], "color": "#c8cad0", "stroke": 3.5}}, "transform": {"position": [-530, 115, 0]}},
  {"id": "ctx", "content": {"shape": {"size": [190, 84], "cornerRadius": 42, "color": "#ffffff14"}}, "transform": {"position": [-380, 115, 0]}},
  {"id": "ctxGlyph", "content": {"shape": {"kind": "branch", "size": [30, 30], "color": "#a9acb3", "stroke": 2.6}}, "transform": {"position": [-436, 115, 0]}},
  {"id": "ctxLabel", "content": {"text": {"text": "main", "size": 38, "weight": "regular", "color": "#d4d6db", "face": "mono"}},
   "transform": {"position": [-410, 115, 0], "anchor": [0, 0.5]}},
  {"id": "pill", "content": {"shape": {"size": [330, 84], "cornerRadius": 42, "color": "#ffffff14"}}, "transform": {"position": [300, 115, 0]}},
  {"id": "pillLabel", "content": {"text": {"text": "Claude Code", "size": 42, "weight": "regular"}}, "transform": {"position": [163, 115, 0], "anchor": [0, 0.5]}},
  {"id": "chevron", "content": {"shape": {"kind": "chevron", "size": [24, 24], "color": "#ffffff", "stroke": 2.8}}, "transform": {"position": [425, 117, 0]}},
  {"id": "send", "content": {"shape": {"size": [88, 88], "cornerRadius": 44, "color": "#f4f4f5"}}, "transform": {"position": [520, 115, 0]}},
  {"id": "sendArrow", "content": {"shape": {"kind": "arrow", "size": [36, 36], "color": "#08090a", "stroke": 4}},
   "transform": {"position": [520, 115, 0], "rotation": [0, 0, -90]}}
]}, "transform": {"position": [960, 540, 0]}}
```

- In the first scene the box arrives in the look's seam (named on the scene), so it has no entrance of its own. In the
  aurora or satin, give it `{"move": "rise", "start": 0}`.
- Change the hint, the pills' labels and colours to the product's. A pill's width is its label's (about 0.5 × 42 px a
  character) plus 120. Glyphs: `plus`, `arrow` (turned −90 points up), `chevron` (points down; 180 for up), `mic`,
  `terminal`, `branch`, `check`, `search`.
- The request in the box: a text layer in the hint's place, 46 px, `width` 1080.
- **Attachments** (tickets, photos, files): three cards 160×116 in a tilted stack under the request at [-440, 8], 62 apart,
  turned −8°, 5° and −2°, popping 0.1 s apart from 0.12 (`pop`, intensity 0.5). Each is a card in a raised surface with
  its source's mark (30) in its corner and two bars as shapes for its lines. No text on them: in a stack, labels overlap.

```json
{"id": "tk0", "content": {"group": [
  {"id": "tk0F", "content": {"shape": {"size": [160, 116], "cornerRadius": 16, "color": "#202126"}}, "transform": {"position": [0, 0, 0]},
   "shadow": {"opacity": 0.6, "radius": 14, "offset": 5}},
  {"id": "tk0E", "content": {"shape": {"size": [160, 116], "cornerRadius": 16, "color": "#ffffff24", "stroke": 1.5}}, "transform": {"position": [0, 0, 0]}},
  {"id": "tk0L", "content": {"ui": {"asset": "linear", "width": 30, "tint": "#8b93ff"}}, "transform": {"position": [-50, -28, 0]}},
  {"id": "tk0A", "content": {"shape": {"size": [120, 10], "cornerRadius": 5, "color": "#5b5e66"}}, "transform": {"position": [0, 12, 0]}},
  {"id": "tk0B", "content": {"shape": {"size": [84, 10], "cornerRadius": 5, "color": "#3a3c42"}}, "transform": {"position": [-18, 34, 0]}}
]}, "transform": {"position": [-440, 8, 0], "rotation": [0, 0, -8]}, "moves": [{"move": "pop", "start": 0.12, "intensity": 0.5}]}
```

## A macro on a control

The next scene repeats the box, with the camera close on the control. Come in with z: `z = 1728 × (1 − 1 / zoom)` at
1080p; 3.6× is 1248, 1.5× is 576. Frame the control a third of the way across, with the send disc and the box's corner
in view: at 3.6× the frame is 533×300 canvas pixels, so put the camera 100 right of the control and 4 below it.

```json
{"id": "pick", "duration": 1.059, "camera": {"position": [1364, 659, 1248],
  "moves": [{"move": "pan", "start": 0, "duration": 1.059, "to": [1330, 659], "intensity": 1.05}]},
 "layers": [ the box group again, its pill with {"move": "click", "start": 0.55, "duration": 0.4} ]}
```

- A click within 0.6 s of its scene's start has the hand there from the cut.
- The hand is drawn as large as the camera shows the canvas, so in macro it's as big as the pill.
- A press that changes the control:
  - the pill `{"move": "morph", "start": 0.7, "color": "<the new colour>", "duration": 0.12}`;
  - the old label `{"move": "hide", "start": 0.7}`;
  - a second label in the same place `{"move": "show", "start": 0.7}`. Both swap on the same frame.
- **The finish** (merge, ship, build, deploy): a 1190×240 bar of glass with the work's title (46, `medium`) and a note (34,
  dim), its button 300×96 at [390, 0] in the product's primary style (a light one: `#f4f4f5`, its label the ground's
  dark). The camera at 2–2.5× on the button (`[1330, 540, 1040]`, panning to `[1350, 540]`), the click at 0.5, a morph to
  the done colour (green `#3ddc84`) at 0.7, and in place of "Merge all" its done state shown on the same frame: "Merged"
  (dark, 42) anchored at its left `[0, 0.5]` at [330, 0], and a dark `check` 30 px at [300, 0], clear of the label's first
  letter. Centred labels of different lengths can't be placed this way: anchor the label, then put the glyph before it.

## A menu

The product's own choices, as a group popping from its button, with a highlight that follows the hand.

```json
{"id": "menu", "content": {"group": [
  {"id": "menuFill", "content": {"shape": {"size": [780, 580], "cornerRadius": 36, "color": "#ffffff0d", "glass": true}}, "transform": {"position": [0, 0, 0]}},
  {"id": "hover", "content": {"shape": {"size": [740, 160], "cornerRadius": 26, "color": "#ffffff14"}}, "transform": {"position": [0, -175, 0]},
   "moves": [{"move": "morph", "start": 0.71, "to": [0, 0], "duration": 0.18}, {"move": "click", "start": 1.06, "duration": 0.3}]},
  {"id": "row1mark", "content": {"ui": {"asset": "claude", "width": 64, "tint": "#d97757"}}, "transform": {"position": [-300, -175, 0]}},
  {"id": "row1", "content": {"text": {"text": "Claude Code", "size": 46, "weight": "regular"}}, "transform": {"position": [-245, -201, 0], "anchor": [0, 0.5]}},
  {"id": "row1note", "content": {"text": {"text": "Anthropic", "size": 34, "weight": "regular", "color": "#8a8f98"}},
   "transform": {"position": [-245, -149, 0], "anchor": [0, 0.5]}},
  {"id": "row1check", "content": {"shape": {"kind": "check", "size": [34, 34], "color": "#ffffff", "stroke": 3.5}}, "transform": {"position": [310, -175, 0]}}
]}, "transform": {"position": [1150, 470, 0]}, "moves": [{"move": "pop", "start": 0, "intensity": 0.4}]}
```

- Rows are 175 apart, each with its mark (64), a title (46) and a note (34, dim). A check pops on the row the hand picks,
  0.04 s after its press.
- Give the scene a camera at 1.5× on the menu: `{"position": [1150, 470, 576]}`.

## The voice

What the person says, typed big. Give it its own scene, 6–8 beats.

```json
{"id": "ask", "duration": 2.471, "layers": [
  {"id": "said", "content": {"text": {"text": "I've got five bugs and one evening", "size": 140, "weight": "regular"}},
   "transform": {"position": [960, 540, 0]}, "moves": [{"move": "voice", "start": 0, "duration": 2.1}]}
]}
```

- One line, at most about 40 characters, 130–140 px. Set `duration` so it runs 13–18 characters a second, and leave a
  beat or two after it.
- Anchored at its middle, it's centred as it grows. Once its caret reaches 70 % of the width it holds there while the
  line runs off to the left, as the reference's does.
- A statement with the logo: put the logo and the line in a group, the line anchored at its left `[0, 0.5]`, 120–130 px,
  the group at x 360 so the logo stays in the frame. The group follows the caret, so they move as one.

```json
{"id": "statement", "content": {"group": [
  {"id": "mark", "content": {"ui": {"asset": "logo", "width": 130, "tint": "#ffffff"}}, "transform": {"position": [-100, 0, 0]}, "moves": [{"move": "pop", "start": 0}]},
  {"id": "line", "content": {"text": {"text": "Ready to ship it?", "size": 130, "weight": "regular"}}, "transform": {"position": [0, 0, 0], "anchor": [0, 0.5]},
   "moves": [{"move": "voice", "start": 0, "duration": 1.2}]}
]}, "transform": {"position": [360, 540, 0]}}
```

## Send, then the thread

The box with the request and its attachments. The hand presses send on a beat and the box washes. On the next beat the
thread comes up over it on a card (`"seam": "stack"` on the thread's scene): the request (54 px) at the top, its
attachments under it, then the product's mark and "Thinking…", then its reply, two lines at 66 px.

```json
"box group moves": [{"move": "wash", "start": 1.35}],
"send": {"move": "click", "start": 1.25, "duration": 0.3}
```

```json
{"id": "thread", "content": {"group": [
  {"id": "asked", "content": {"text": {"text": "I've got five bugs and one evening.\nCan you take them?", "size": 54, "weight": "regular", "width": 1100}},
   "transform": {"position": [-500, -250, 0], "anchor": [0, 0.5]}},
  the attachments' stack again, in a group at [-430, -80],
  {"id": "mark", "content": {"ui": {"asset": "logo", "width": 66, "tint": "#ffffff"}}, "transform": {"position": [-470, 90, 0]}},
  {"id": "thinking", "content": {"text": {"text": "Thinking…", "size": 58, "weight": "regular"}}, "transform": {"position": [-420, 90, 0], "anchor": [0, 0.5]},
   "moves": [{"move": "fadeUp", "start": 0.2}, {"move": "shimmer", "start": 0.2, "duration": 1.1}, {"move": "hide", "start": 1.3}]},
  {"id": "answer", "content": {"text": {"text": "On it: five worktrees,\none agent on each.", "size": 66, "weight": "regular", "width": 1100}},
   "transform": {"position": [-420, 90, 0], "anchor": [0, 0.22]}, "moves": [{"move": "reply", "start": 1.35}]}
]}, "transform": {"position": [960, 560, 0]}, "moves": [{"move": "scroll", "start": 1.0, "to": [960, 470], "duration": 0.6}]}
```

## Answers as things

Rebuild what the product gives back as tiles and cards in its theme, never as lifted panes. The colour is in what they
show: marks, status, diffs, pictures.

### A bento of the product's actors

The agents it runs, the models, the people, the integrations. Tiles of glass, each one's
mark big in its colour, its name and what it's doing (in mono if that's a branch, task id or path), a status chip. The
product's own tile in the middle, inverted: its light colour, its logo and the project's name in its dark.

Layout: the middle tile 510×510 at [0, 0]; four tiles 400×245 at [±475, ±132.5]; two tiles 680×160 at [±350, 355]; the
group at [960, 450], 1350 wide. They pop 0.07 s apart from the middle out with a small spin (alternate its sign), from
0.706 after the look's seam (from 0 after a cut), and on a later beat every tile's status swaps at once (`hide` the old
chip, `show` the new, the same moment). The scene's camera `{"move": "push", "start": 0, "intensity": 0.6}`.

```json
{"id": "aClaude", "content": {"group": [
  {"id": "aClaudeF", "content": {"shape": {"size": [400, 245], "cornerRadius": 34, "color": "#ffffff0d", "glass": true}}, "transform": {"position": [0, 0, 0]}},
  {"id": "aClaudeL", "content": {"ui": {"asset": "claude", "width": 96, "tint": "#d97757"}}, "transform": {"position": [-120, -42, 0]}},
  {"id": "aClaudeN", "content": {"text": {"text": "Claude Code", "size": 44, "color": "#ffffff", "weight": "semibold"}}, "transform": {"position": [-166, 38, 0], "anchor": [0, 0.5]}},
  {"id": "aClaudeT", "content": {"text": {"text": "login-race", "size": 34, "color": "#8a8f98", "weight": "regular", "face": "mono"}}, "transform": {"position": [-166, 84, 0], "anchor": [0, 0.5]}},
  {"id": "aClaudeRunF", "content": {"shape": {"size": [170, 56], "cornerRadius": 28, "color": "#ffffff14"}}, "transform": {"position": [85, -62, 0]}, "moves": [{"move": "hide", "start": 2.118}]},
  {"id": "aClaudeRunL", "content": {"text": {"text": "Running", "size": 32, "color": "#c9ccd2", "weight": "medium"}}, "transform": {"position": [85, -62, 0]}, "moves": [{"move": "hide", "start": 2.118}]},
  {"id": "aClaudeDoneF", "content": {"shape": {"size": [170, 56], "cornerRadius": 28, "color": "#3ddc8426"}}, "transform": {"position": [85, -62, 0]}, "moves": [{"move": "show", "start": 2.118}]},
  {"id": "aClaudeDoneL", "content": {"text": {"text": "Passed", "size": 32, "color": "#3ddc84", "weight": "medium"}}, "transform": {"position": [85, -62, 0]}, "moves": [{"move": "show", "start": 2.118}]}
]}, "transform": {"position": [-475, -132, 0]}, "moves": [{"move": "pop", "start": 0.776, "intensity": 1.1}, {"move": "spin", "start": 0.776, "intensity": -0.1}]}
```

```json
{"id": "aOrca", "content": {"group": [
  {"id": "aOrcaF", "content": {"shape": {"size": [510, 510], "cornerRadius": 40, "color": "#f4f4f5"}}, "transform": {"position": [0, 0, 0]},
   "shadow": {"opacity": 0.6, "radius": 30, "offset": 10}},
  {"id": "aOrcaL", "content": {"ui": {"asset": "logo", "width": 250, "tint": "#08090a"}}, "transform": {"position": [0, -30, 0]}},
  {"id": "aOrcaN", "content": {"text": {"text": "acme-web", "size": 56, "color": "#08090a", "weight": "semibold", "face": "mono"}}, "transform": {"position": [0, 140, 0]}}
]}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "pop", "start": 0.706, "intensity": 1.1}]}
```

A wide 680×160 tile: its mark (70) at [-260, 0], its name (44) and task (34) anchored left at x −200, 22 above and 26
below the middle, its status chip at [210, 0]. Or a summary: "5 worktrees" (46) over "off main · 1 evening" (34, dim).

### A collage of its outputs

Files, pull requests, tickets, pages, designs: eight cards 420×250 round the frame's edges, at about (±640, ±300),
(±200, ±370), each turned −11° to 11°, each a card of glass. Each has its maker's mark (54) at
[-160, -72], an id in mono (34, dim) beside it, its name in mono (34) at [-176, 4], and what changed at [-176, 74]: `+12` in
green and `−3` in red, 34 px mono `semibold`, with a green `check` at [160, 74]. Keep the middle clear for one line (a
`reply`, 64–72 px, from 0.7). The group takes `{"move": "scatter", "start": 0}`, so the stack is there on the cut and
thrown at once, and the scene a camera
`{"move": "push", "start": 0.3, "intensity": 0.5}`.

```json
{"id": "d0", "content": {"group": [
  {"id": "d0F", "content": {"shape": {"size": [420, 250], "cornerRadius": 28, "color": "#ffffff0d", "glass": true}}, "transform": {"position": [0, 0, 0]}},
  {"id": "d0L", "content": {"ui": {"asset": "claude", "width": 54, "tint": "#d97757"}}, "transform": {"position": [-160, -72, 0]}},
  {"id": "d0N", "content": {"text": {"text": "#2491", "size": 34, "color": "#8a8f98", "weight": "medium", "face": "mono"}}, "transform": {"position": [-118, -72, 0], "anchor": [0, 0.5]}},
  {"id": "d0B", "content": {"text": {"text": "fix/login-race", "size": 34, "color": "#ffffff", "weight": "medium", "face": "mono"}}, "transform": {"position": [-176, 4, 0], "anchor": [0, 0.5]}},
  {"id": "d0A", "content": {"text": {"text": "+12", "size": 34, "color": "#0ac864", "weight": "semibold", "face": "mono"}}, "transform": {"position": [-176, 74, 0], "anchor": [0, 0.5]}},
  {"id": "d0R", "content": {"text": {"text": "−3", "size": 34, "color": "#e5484d", "weight": "semibold", "face": "mono"}}, "transform": {"position": [-86, 74, 0], "anchor": [0, 0.5]}},
  {"id": "d0Ok", "content": {"shape": {"kind": "check", "size": [34, 34], "color": "#3ddc84", "stroke": 3.5}}, "transform": {"position": [160, 74, 0]}}
]}, "transform": {"position": [-640, -300, 0], "rotation": [0, 0, -10]}}
```

### One output read close

A diff, a log, a reply, a result: rebuilt as a card of glass 1540×640, its source at the top
(mark 46 at [-700, -255], a mono name 36 beside it, `+6` and `−2` at the right), a rule under it, then five lines of mono at
34 px 70 apart from y −140, their numbers dim at x −680, the text at x −610. A removed line on a red band (`#e5484d24`, text
`#ff9b9b`, sign `−`), an added one on a green band (`#0ac86424`, text `#8be9b0`, sign `+`), each band 1460×62. A comment
pill (620×92, `#1b1c1f`, 38 px, `type` from 0.45, a send disc 64) pops on it at [330, 245] and is sent with a
click and a wash on a beat. The card's group takes `{"move": "rise", "start": 0}`.

### Opening one of them

To read one of the answers close, click it: in the bento's or the collage's last beat, a `click` on that tile's group
pressed 0.35 s before the scene ends, and `"seam": "expand"` on the next scene. The next scene opens out of the tile.

```json
"the tile's group moves": [{"move": "pop", "start": 0.776}, {"move": "click", "start": 2.47}]
```

### A bento that swaps

Images, designs, variants: tiles 20 px apart, the same pop from the middle out, and a second layer in each tile's place,
`hide` the first and `show` the second on the same beat.

### A list that fills

Rows of the product's own (tasks, agents, files) in a group with `cascade` from 0, a row every 0.075 s, then a chip on each
row popping on the beats after. 46 px titles. Never spin a row.

Never lift as an answer:
- a terminal, transcript, log or docs page: it's a wall of small text, and framed close enough to read, it's cut off;
- an app mockup the site animates (tabs, tasks, a fleet view): the lift catches it mid-animation, with grey loading bars and
  rows on top of each other;
- an `img` screenshot from docs or a blog: its pixels are fixed, so it's blurred at 4K.

## The end words

Three to five short scenes, then the logo:

- **Tagline.** One line, 150–170 px `bold`, with `shimmer` from 0 and a soft glow
  (`"shadow": {"color": "#ffffff", "opacity": 0.35, "radius": 36, "offset": 0}`; in the brand's colour for a coloured
  brand). In the dither and light looks it arrives in the look's seam (`"seam": "dither"` on its scene), so no entrance of
  its own; in the aurora or satin, add `reply` from 0.
- **One word a scene.** Two or three beats each: `{"text": "parallel", "size": 260, "weight": "bold"}` with
  `{"move": "shimmer", "start": 0}`, the same glow, and no entrance: each word is there on its cut.
- **The logo lockup.** The logo lifted `bare` (150 wide, its text colour) beside its name (120, `bold`), in a group at
  [960, 540] (the mark at [-130, 0], the name anchored left at [-30, 0]), there with no entrance, for 8 beats (2.824 s).
  - Dither and light looks: the scene takes `"seam": "ring", "field": "halo"`: a ring of smoke opens from the middle and
    leaves the logo in a halo.
  - Aurora: a cut; its light goes out over the video's last two seconds, leaving the logo on black. Satin: a cut.
