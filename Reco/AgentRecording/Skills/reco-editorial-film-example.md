# A whole editorial film: ElevenLabs' rebuilt

ElevenLabs' launch film rebuilt in 41 s and checked against its frames: the wordmark opening, the statements lit word by
word, the stars, the card growing and the wipe matched it frame for frame. Take its structure, its moves and its pace; your
words, mark, labels and pictures from your product:

| Scene | Seconds | What it shows | How it comes in |
|---|---|---|---|
| open | 2.0 | The mark opens into "Your agents" | the first frame |
| labels | 2.42 | Mono labels blink in round a picture square stepping larger, which grows to fill the frame | cut |
| wordmark | 3.0 | The wordmark opens out of its mark; the tagline is swept in | cut |
| question | 3.4 | The request card: outline, fill sweeping in, chip, the request typed | wipe |
| steps | 2.4 | Icon tiles pop in a column framed by registration marks | cut |
| scan | 3.2 | The dark beat: "Scanning conversations…" lit, stars turning round it | fade |
| mosaic | 2.8 | Dark panels and pictures; tiles leave by their edges, one card stays | fade out of the dark beat |
| sphere | 2.8 | The card turns into a sphere among dots; the pill opens beside it | cut |
| prompt | 3.0 | The input on a picture card, a request typed | cut |
| standards | 2.9 | A statement on ink, lit word by word | cut |
| connect | 3.57 | A card grows into the frame: "Connect Architect to — Claude", the tools cutting by | cut |
| improve | 1.75 | "Improve ● your agents", the sphere shrinking as the words part | cut |
| elevate | 2.5 | A last statement lit on paper | cut |
| end | 5.3 | The wordmark opens again and holds | cut |

```json
{
  "version": 1, "canvas": {"size": [1920, 1080], "frameRate": 60, "background": "#f3f2f0", "field": "plain", "pacing": "beats"}, "style": {"text": "#1b1a19", "accent": "#5e658c"}, "sound": {"style": "editorial"},
  "scenes": [
    {"id": "open", "duration": 2.0, "field": "paper", "seam": "cut", "layers": [
      {"id": "line", "content": {"group": [
        {"id": "mark", "content": {"text": {"text": "II", "size": 68, "color": "#000000", "weight": "bold", "face": "sans"}}, "transform": {"position": [-205, 0, 0], "anchor": [0, 0.5]}},
        {"id": "words", "content": {"text": {"text": "Your agents", "size": 68, "color": "#1b1a19", "weight": "regular", "face": "sans"}}, "transform": {"position": [-158, 0, 0], "anchor": [0, 0.5]}}
      ]}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "unfold", "start": 0.25}]}
    ]},
    {"id": "labels", "duration": 2.42, "field": "plain", "seam": "cut", "layers": [
      {"id": "square", "content": {"shape": {"size": [352, 330], "cornerRadius": 9, "color": "#c1ccce", "picture": "sky"}}, "transform": {"position": [960, 539, 0]}, "moves": [{"move": "morph", "start": 0.45, "duration": 0.0167, "size": [388, 364], "radius": 9}, {"move": "morph", "start": 0.9, "duration": 0.0167, "size": [424, 396], "radius": 10}, {"move": "morph", "start": 1.28, "duration": 0.0167, "size": [459, 430], "radius": 11}, {"move": "morph", "start": 1.48, "duration": 0.0167, "size": [494, 462], "radius": 12}, {"move": "morph", "start": 1.64, "duration": 0.0167, "size": [528, 496], "radius": 13}, {"move": "morph", "start": 1.77, "duration": 0.0167, "size": [564, 529], "radius": 13}, {"move": "morph", "start": 1.88, "duration": 0.0167, "size": [626, 586], "radius": 14}, {"move": "morph", "start": 1.95, "duration": 0.0167, "size": [691, 648], "radius": 16}, {"move": "grow", "start": 2.02}]},
      {"id": "r1", "content": {"group": [
        {"id": "r1-bar", "content": {"shape": {"size": [5, 12], "cornerRadius": 0, "color": "#1a1918"}}, "transform": {"position": [3, 0, 0]}, "moves": [{"move": "blink", "start": 0.1}]},
        {"id": "r1-text", "content": {"text": {"text": "ANALYZING CONVERSATIONS", "size": 14, "color": "#11100f", "weight": "regular", "face": "mono"}}, "transform": {"position": [20, 0, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.1167}]}
      ]}, "transform": {"position": [1394, 228, 0]}},
      {"id": "l2", "content": {"group": [
        {"id": "l2-bar", "content": {"shape": {"size": [5, 12], "cornerRadius": 0, "color": "#1a1918"}}, "transform": {"position": [3, 0, 0]}, "moves": [{"move": "blink", "start": 0.26}]},
        {"id": "l2-text", "content": {"text": {"text": "INVESTIGATING TRANSFERS", "size": 14, "color": "#11100f", "weight": "regular", "face": "mono"}}, "transform": {"position": [20, 0, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.2767}]}
      ]}, "transform": {"position": [258, 704, 0]}},
      {"id": "r2", "content": {"group": [
        {"id": "r2-bar", "content": {"shape": {"size": [5, 12], "cornerRadius": 0, "color": "#1a1918"}}, "transform": {"position": [3, 0, 0]}, "moves": [{"move": "blink", "start": 0.32}]},
        {"id": "r2-text", "content": {"text": {"text": "WRITING FIX", "size": 14, "color": "#11100f", "weight": "regular", "face": "mono"}}, "transform": {"position": [20, 0, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.3367}]}
      ]}, "transform": {"position": [1394, 362, 0]}},
      {"id": "l1", "content": {"group": [
        {"id": "l1-bar", "content": {"shape": {"size": [5, 12], "cornerRadius": 0, "color": "#1a1918"}}, "transform": {"position": [3, 0, 0]}, "moves": [{"move": "blink", "start": 0.42}]},
        {"id": "l1-text", "content": {"text": {"text": "REVIEWING RESPONSES", "size": 14, "color": "#11100f", "weight": "regular", "face": "mono"}}, "transform": {"position": [20, 0, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.4367}]}
      ]}, "transform": {"position": [258, 326, 0]}},
      {"id": "r3", "content": {"group": [
        {"id": "r3-text", "content": {"text": {"text": "RUNNING SIMULATIONS", "size": 14, "color": "#11100f", "weight": "regular", "face": "mono"}}, "transform": {"position": [0, 0, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.6567}]}
      ]}, "transform": {"position": [1414, 408, 0]}},
      {"id": "r5", "content": {"group": [
        {"id": "r5-bar", "content": {"shape": {"size": [5, 12], "cornerRadius": 0, "color": "#1a1918"}}, "transform": {"position": [3, 0, 0]}, "moves": [{"move": "blink", "start": 0.8}]},
        {"id": "r5-text", "content": {"text": {"text": "PROPOSING CHANGE", "size": 14, "color": "#11100f", "weight": "regular", "face": "mono"}}, "transform": {"position": [20, 0, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.8167}]}
      ]}, "transform": {"position": [1394, 636, 0]}},
      {"id": "g0", "content": {"text": {"text": "GOOD MORNING JOHN! OF COURSE,", "size": 14, "color": "#858483", "weight": "regular", "face": "mono"}}, "transform": {"position": [254, 248, 0], "anchor": [0, 0.5]}, "moves": [{"move": "type", "start": 0.16, "duration": 0.2522}]},
      {"id": "g1", "content": {"text": {"text": "LET ME PULL UP THE PRICING", "size": 14, "color": "#858483", "weight": "regular", "face": "mono"}}, "transform": {"position": [254, 266, 0], "anchor": [0, 0.5]}, "moves": [{"move": "type", "start": 0.58, "duration": 0.2261}]},
      {"id": "g2", "content": {"text": {"text": "DETAILS FOR YOU.", "size": 14, "color": "#858483", "weight": "regular", "face": "mono"}}, "transform": {"position": [254, 284, 0], "anchor": [0, 0.5]}, "moves": [{"move": "type", "start": 0.96, "duration": 0.1391}]},
      {"id": "g3", "content": {"text": {"text": "NEW PROCEDURE ADDED", "size": 14, "color": "#858483", "weight": "regular", "face": "mono"}}, "transform": {"position": [1394, 608, 0], "anchor": [0, 0.5]}, "moves": [{"move": "type", "start": 0.74, "duration": 0.1652}]}
    ]},
    {"id": "wordmark", "duration": 3.0, "field": "paper", "seam": "cut", "layers": [
      {"id": "lockup", "content": {"group": [
        {"id": "mark", "content": {"text": {"text": "II", "size": 63, "color": "#000000", "weight": "bold", "face": "sans"}}, "transform": {"position": [-339, 0, 0], "anchor": [0, 0.5]}},
        {"id": "eleven", "content": {"text": {"text": "Eleven", "size": 63, "color": "#000000", "weight": "bold", "face": "sans"}}, "transform": {"position": [-306, 0, 0], "anchor": [0, 0.5]}},
        {"id": "agents", "content": {"text": {"text": "Agents", "size": 63, "color": "#000000", "weight": "regular", "face": "sans"}}, "transform": {"position": [-108, 0, 0], "anchor": [0, 0.5]}},
        {"id": "architect", "content": {"text": {"text": "Architect", "size": 63, "color": "#5e658c", "weight": "regular", "face": "sans"}}, "transform": {"position": [112, 0, 0], "anchor": [0, 0.5]}}
      ]}, "transform": {"position": [951, 542, 0]}, "moves": [{"move": "unfold", "start": 0.1}]}
    ]},
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
    ]},
    {"id": "steps", "duration": 2.4, "field": "plain", "seam": "cut", "layers": [
      {"id": "icons", "content": {"group": [
        {"id": "i0", "content": {"shape": {"size": [124, 124], "cornerRadius": 28, "color": "#111111"}}, "transform": {"position": [0, -150, 0]}, "moves": [{"move": "pop", "start": 0.1}]},
        {"id": "g0", "content": {"shape": {"size": [48, 48], "cornerRadius": 0, "color": "#ffffff", "kind": "search", "stroke": 5}}, "transform": {"position": [0, -150, 0]}, "moves": [{"move": "pop", "start": 0.12}]},
        {"id": "i1", "content": {"shape": {"size": [124, 124], "cornerRadius": 28, "color": "#3d4466"}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "pop", "start": 0.3}]},
        {"id": "g1", "content": {"shape": {"size": [44, 44], "cornerRadius": 0, "color": "#ffffff", "kind": "check", "stroke": 5}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "pop", "start": 0.32}]},
        {"id": "i2", "content": {"shape": {"size": [124, 124], "cornerRadius": 28, "color": "#c47ca0"}}, "transform": {"position": [0, 150, 0]}, "moves": [{"move": "pop", "start": 0.5}]},
        {"id": "g2", "content": {"shape": {"size": [44, 44], "cornerRadius": 0, "color": "#ffffff", "kind": "play"}}, "transform": {"position": [0, 150, 0]}, "moves": [{"move": "pop", "start": 0.52}]}
      ]}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "marks"}]},
      {"id": "stepsLabel", "content": {"text": {"text": "STEPS", "size": 14, "color": "#11100f", "weight": "regular", "face": "mono"}}, "transform": {"position": [1084, 390, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.7}]},
      {"id": "stepsNote", "content": {"text": {"text": "ANALYZE  ·  PROPOSE  ·  TEST", "size": 14, "color": "#858483", "weight": "regular", "face": "mono"}}, "transform": {"position": [1084, 412, 0], "anchor": [0, 0.5]}, "moves": [{"move": "type", "start": 0.8, "duration": 0.2435}]}
    ]},
    {"id": "scan", "duration": 3.2, "field": "plain", "seam": "fade", "layers": [
      {"id": "ground", "content": {"shape": {"size": [1920, 1080], "cornerRadius": 0, "color": "#171717"}}, "transform": {"position": [960, 540, 0]}},
      {"id": "scanBox", "content": {"shape": {"size": [180, 75], "cornerRadius": 14, "color": "#1f2433"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "morph", "start": 0.08, "duration": 0.3, "size": [520, 84]}, {"move": "orbit", "start": 0.25}, {"move": "marks", "color": "#ffffff"}]},
      {"id": "scanLit", "content": {"text": {"text": "Scanning conversations…", "size": 40, "color": "#828894", "weight": "regular", "face": "sans"}}, "transform": {"position": [960, 540, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "blink", "start": 0.4}]},
      {"id": "scanWhite", "content": {"text": {"text": "Scanning conversations…", "size": 40, "color": "#f0f2f4", "weight": "regular", "face": "sans"}}, "transform": {"position": [960, 540, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "sweep", "start": 0.75, "duration": 0.9}]}
    ]},
    {"id": "mosaic", "duration": 2.8, "field": "plain", "seam": "fade", "camera": {"moves": [{"move": "pullBack", "start": 0, "duration": 1.3, "intensity": 0.5}]}, "layers": [
      {"id": "chatPanel", "content": {"group": [
        {"id": "chat", "content": {"shape": {"size": [448, 352], "cornerRadius": 6, "color": "#151617"}}, "transform": {"position": [227.0, 179.0, 0], "anchor": [0.5, 0.5]}},
        {"id": "chatLine", "content": {"text": {"text": "[sympathetic] I am so sorry", "size": 18, "color": "#e8e8e8", "weight": "regular", "face": "mono"}}, "transform": {"position": [110, 250, 0], "anchor": [0, 0.5]}, "moves": [{"move": "type", "start": 0.6, "duration": 0.3}]},
        {"id": "chatLine2", "content": {"text": {"text": "you're dealing with that.", "size": 18, "color": "#e8e8e8", "weight": "regular", "face": "mono"}}, "transform": {"position": [110, 278, 0], "anchor": [0, 0.5]}, "moves": [{"move": "type", "start": 0.95, "duration": 0.25}]}
      ]}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "exit", "start": 2.08, "duration": 0.22, "direction": "left"}]},
      {"id": "sky", "content": {"shape": {"size": [188, 352], "cornerRadius": 6, "color": "#9fb6c6", "picture": "sky"}}, "transform": {"position": [551.0, 179.0, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "hide", "start": 2.25}]},
      {"id": "evalTop", "content": {"shape": {"size": [490, 90], "cornerRadius": 6, "color": "#e9e7e3"}}, "transform": {"position": [896.0, 48.0, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "hide", "start": 2.1}]},
      {"id": "evalPanel", "content": {"group": [
        {"id": "eval", "content": {"shape": {"size": [490, 256], "cornerRadius": 6, "color": "#151617"}}, "transform": {"position": [896.0, 227.0, 0], "anchor": [0.5, 0.5]}},
        {"id": "evalText", "content": {"text": {"text": "EVALUATION SUCCEEDED", "size": 16, "color": "#f2f2f2", "weight": "regular", "face": "mono"}}, "transform": {"position": [676, 326, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.4}]}
      ]}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "hide", "start": 2.1}]},
      {"id": "pattern", "content": {"shape": {"size": [770, 352], "cornerRadius": 6, "color": "#1d1e21"}}, "transform": {"position": [1917, 3, 0], "anchor": [1, 0]}, "moves": [{"move": "morph", "start": 1.85, "duration": 0.07, "size": [1, 352]}, {"move": "hide", "start": 1.93}]},
      {"id": "paperA", "content": {"shape": {"size": [448, 357], "cornerRadius": 6, "color": "#e9e7e3"}}, "transform": {"position": [227.0, 539.5, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "hide", "start": 2.25}]},
      {"id": "blue", "content": {"shape": {"size": [188, 357], "cornerRadius": 6, "color": "#7283a9", "picture": "indigo"}}, "transform": {"position": [551.0, 361, 0], "anchor": [0.5, 0]}, "moves": [{"move": "morph", "start": 2.38, "duration": 0.12, "size": [188, 1]}]},
      {"id": "pink", "content": {"shape": {"size": [612, 357], "cornerRadius": 6, "color": "#ae7a97", "picture": "petal"}}, "transform": {"position": [957.0, 539.5, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "morph", "start": 2.32, "duration": 0.45, "size": [790, 471], "radius": 34, "to": [957, 538]}]},
      {"id": "passedPanel", "content": {"group": [
        {"id": "passed", "content": {"shape": {"size": [648, 357], "cornerRadius": 6, "color": "#151617"}}, "transform": {"position": [1917, 539.5, 0], "anchor": [1, 0.5]}, "moves": [{"move": "morph", "start": 2.2, "duration": 0.08, "size": [1, 357]}]},
        {"id": "passedText", "content": {"text": {"text": "PASSED 5/5", "size": 16, "color": "#f2f2f2", "weight": "regular", "face": "mono"}}, "transform": {"position": [1300, 400, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.7}, {"move": "hide", "start": 2.2}]},
        {"id": "check0", "content": {"text": {"text": "✓  TEST 1", "size": 16, "color": "#9fd3a8", "weight": "regular", "face": "mono"}}, "transform": {"position": [1300, 450, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.8}, {"move": "hide", "start": 2.2}]},
        {"id": "check1", "content": {"text": {"text": "✓  TEST 2", "size": 16, "color": "#9fd3a8", "weight": "regular", "face": "mono"}}, "transform": {"position": [1300, 490, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 0.92}, {"move": "hide", "start": 2.2}]},
        {"id": "check2", "content": {"text": {"text": "✓  TEST 3", "size": 16, "color": "#9fd3a8", "weight": "regular", "face": "mono"}}, "transform": {"position": [1300, 530, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 1.04}, {"move": "hide", "start": 2.2}]},
        {"id": "check3", "content": {"text": {"text": "✓  TEST 4", "size": 16, "color": "#9fd3a8", "weight": "regular", "face": "mono"}}, "transform": {"position": [1300, 570, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 1.16}, {"move": "hide", "start": 2.2}]},
        {"id": "check4", "content": {"text": {"text": "✓  TEST 5", "size": 16, "color": "#9fd3a8", "weight": "regular", "face": "mono"}}, "transform": {"position": [1300, 610, 0], "anchor": [0, 0.5]}, "moves": [{"move": "blink", "start": 1.28}, {"move": "hide", "start": 2.2}]}
      ]}, "transform": {"position": [0, 0, 0]}},
      {"id": "green", "content": {"shape": {"size": [642, 353], "cornerRadius": 6, "color": "#b59e7d", "picture": "sand"}}, "transform": {"position": [3, 900.5, 0], "anchor": [0, 0.5]}, "moves": [{"move": "morph", "start": 2.16, "duration": 0.12, "size": [1, 353]}]},
      {"id": "improvePill", "content": {"group": [
        {"id": "pillShape", "content": {"shape": {"size": [340, 72], "cornerRadius": 36, "color": "#ffffff"}}, "transform": {"position": [0, 0, 0]}},
        {"id": "improveText", "content": {"text": {"text": "Improve response", "size": 32, "color": "#1b1a19", "weight": "regular", "face": "sans"}}, "transform": {"position": [0, 0, 0], "anchor": [0.5, 0.5]}}
      ]}, "transform": {"position": [324, 900, 0]}, "moves": [{"move": "blink", "start": 1.2}, {"move": "hide", "start": 2.16}]},
      {"id": "deep", "content": {"shape": {"size": [1266, 353], "cornerRadius": 6, "color": "#96617f", "picture": "bloom"}}, "transform": {"position": [1284.0, 1077, 0], "anchor": [0.5, 1]}, "moves": [{"move": "morph", "start": 1.96, "duration": 0.16, "size": [1266, 1]}]}
    ]},
    {"id": "sphere", "duration": 2.8, "field": "paper", "seam": "cut", "layers": [
      {"id": "frame", "content": {"shape": {"size": [1130, 790], "cornerRadius": 40, "color": "#d0cfcc", "stroke": 2}}, "transform": {"position": [957, 538, 0]}, "moves": [{"move": "morph", "start": 0.2, "duration": 0.4, "size": [439, 436], "radius": 60}, {"move": "morph", "start": 0.6, "duration": 0.3, "size": [397, 394]}, {"move": "hide", "start": 0.95}]},
      {"id": "pill", "content": {"shape": {"size": [78, 101], "cornerRadius": 50.5, "color": "#ffffff"}}, "transform": {"position": [646, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "show", "start": 1.62}, {"move": "morph", "start": 1.62, "duration": 0.8, "size": [628, 101]}]},
      {"id": "ask", "content": {"text": {"text": "Ask Architect", "size": 34, "color": "#1b1a19", "weight": "regular", "face": "sans"}}, "transform": {"position": [770, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "sweep", "start": 1.72, "duration": 0.3}]},
      {"id": "card", "content": {"shape": {"size": [790, 471], "cornerRadius": 34, "color": "#ae7a97", "picture": "petal"}}, "transform": {"position": [957, 538, 0]}, "moves": [{"move": "morph", "start": 0.2, "duration": 0.4, "size": [292, 292], "radius": 146}, {"move": "morph", "start": 0.62, "duration": 0.85, "size": [78, 78]}, {"move": "dots", "start": 0.75}, {"move": "morph", "start": 1.5, "duration": 0.65, "to": [696, 540], "size": [72, 72]}]}
    ]},
    {"id": "prompt", "duration": 3.0, "field": "plain", "seam": "cut", "layers": [
      {"id": "roseCard", "content": {"shape": {"size": [1744, 966], "cornerRadius": 18, "color": "#96617f", "picture": "rose"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "morph", "start": 0.0, "duration": 0.53, "size": [1874, 1039]}]},
      {"id": "bar", "content": {"shape": {"size": [1025, 163], "cornerRadius": 40, "color": "#ffffff"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "morph", "start": 0.0, "duration": 0.53, "size": [1080, 205]}]},
      {"id": "placeholder", "content": {"text": {"text": "Ask Architect to improve your agent", "size": 40, "color": "#888888", "weight": "regular", "face": "sans"}}, "transform": {"position": [470, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "sweep", "start": 0.45, "duration": 0.4}, {"move": "hide", "start": 1.2}]},
      {"id": "request", "content": {"text": {"text": "Make it calmer with upset callers", "size": 40, "color": "#1b1a19", "weight": "regular", "face": "sans"}}, "transform": {"position": [470, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "show", "start": 1.2}, {"move": "type", "start": 1.2, "duration": 1.1}]}
    ]},
    {"id": "standards", "duration": 2.9, "field": "ink", "seam": "cut", "layers": [
      {"id": "standards", "content": {"text": {"text": "to the standards you set", "size": 92, "color": "#f9fafb", "weight": "regular", "face": "sans"}}, "transform": {"position": [960, 530, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "brighten", "start": 0.09}]}
    ]},
    {"id": "connect", "duration": 3.568, "field": "plain", "seam": "cut", "layers": [
      {"id": "connectLine", "content": {"group": [
        {"id": "card", "content": {"shape": {"size": [1152, 763], "cornerRadius": 11.5, "color": "#868d9e", "picture": "dusk"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "grow", "start": 0.0}]},
        {"id": "picture1", "content": {"shape": {"size": [1980, 1110], "cornerRadius": 0, "color": "#96617f", "picture": "rose"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "show", "start": 1.267}]},
        {"id": "picture2", "content": {"shape": {"size": [1980, 1110], "cornerRadius": 0, "color": "#96617f", "picture": "indigo"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "show", "start": 1.934}]},
        {"id": "picture3", "content": {"shape": {"size": [1980, 1110], "cornerRadius": 0, "color": "#96617f", "picture": "mist"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "show", "start": 2.601}]},
        {"id": "connect", "content": {"text": {"text": "Connect Architect to", "size": 68, "color": "#ffffff", "weight": "regular", "face": "sans"}}, "transform": {"position": [436, 536, 0], "anchor": [0, 0.5]}},
        {"id": "dash", "content": {"shape": {"size": [68, 2], "cornerRadius": 0, "color": "#ffffffb3"}}, "transform": {"position": [1062, 538, 0]}},
        {"id": "name0", "content": {"text": {"text": "Claude", "size": 68, "color": "#ffffff", "weight": "regular", "face": "sans"}}, "transform": {"position": [1136, 536, 0], "anchor": [0, 0.5]}, "moves": [{"move": "hide", "start": 1.267}]},
        {"id": "name1", "content": {"text": {"text": "Cursor", "size": 68, "color": "#ffffff", "weight": "regular", "face": "sans"}}, "transform": {"position": [1136, 536, 0], "anchor": [0, 0.5]}, "moves": [{"move": "show", "start": 1.267}, {"move": "hide", "start": 1.934}]},
        {"id": "name2", "content": {"text": {"text": "Grok Bot", "size": 68, "color": "#ffffff", "weight": "regular", "face": "sans"}}, "transform": {"position": [1136, 536, 0], "anchor": [0, 0.5]}, "moves": [{"move": "show", "start": 1.934}, {"move": "hide", "start": 2.601}]},
        {"id": "name3", "content": {"text": {"text": "ChatGPT", "size": 68, "color": "#ffffff", "weight": "regular", "face": "sans"}}, "transform": {"position": [1136, 536, 0], "anchor": [0, 0.5]}, "moves": [{"move": "show", "start": 2.601}]}
      ]}, "transform": {"position": [0, 0, 0]}}
    ]},
    {"id": "improve", "duration": 1.75, "field": "plain", "seam": "cut", "layers": [
      {"id": "sphere", "content": {"shape": {"size": [655, 655], "cornerRadius": 327.5, "color": "#7283a9", "picture": "indigo"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "morph", "start": 0.0, "duration": 1.0, "size": [414, 414]}, {"move": "morph", "start": 1.45, "duration": 0.25, "size": [546, 546]}]},
      {"id": "words", "content": {"group": [
        {"id": "improve", "content": {"text": {"text": "Improve", "size": 68, "color": "#1b1a19", "weight": "regular", "face": "sans"}}, "transform": {"position": [492, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "morph", "start": 0.0, "duration": 0.3, "to": [476, 540]}, {"move": "morph", "start": 1.45, "duration": 0.25, "to": [504, 540]}]},
        {"id": "yours", "content": {"text": {"text": "your agents", "size": 68, "color": "#1b1a19", "weight": "regular", "face": "sans"}}, "transform": {"position": [1162, 540, 0], "anchor": [0, 0.5]}, "moves": [{"move": "morph", "start": 0.03, "duration": 0.6, "to": [1213, 540]}, {"move": "morph", "start": 1.45, "duration": 0.25, "to": [1150, 540]}]}
      ]}, "transform": {"position": [0, 0, 0]}}
    ]},
    {"id": "elevate", "duration": 2.5, "field": "plain", "seam": "cut", "layers": [
      {"id": "elevate", "content": {"text": {"text": "Elevate your customer experiences", "size": 68, "color": "#1b1a19", "weight": "regular", "face": "sans"}}, "transform": {"position": [960, 540, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "brighten", "start": 0.02}]}
    ]},
    {"id": "end", "duration": 5.3, "field": "paper", "seam": "cut", "layers": [
      {"id": "lockup", "content": {"group": [
        {"id": "mark", "content": {"text": {"text": "II", "size": 63, "color": "#000000", "weight": "bold", "face": "sans"}}, "transform": {"position": [-339, 0, 0], "anchor": [0, 0.5]}},
        {"id": "eleven", "content": {"text": {"text": "Eleven", "size": 63, "color": "#000000", "weight": "bold", "face": "sans"}}, "transform": {"position": [-306, 0, 0], "anchor": [0, 0.5]}},
        {"id": "agents", "content": {"text": {"text": "Agents", "size": 63, "color": "#000000", "weight": "regular", "face": "sans"}}, "transform": {"position": [-108, 0, 0], "anchor": [0, 0.5]}},
        {"id": "architect", "content": {"text": {"text": "Architect", "size": 63, "color": "#5e658c", "weight": "regular", "face": "sans"}}, "transform": {"position": [112, 0, 0], "anchor": [0, 0.5]}}
      ]}, "transform": {"position": [951, 542, 0]}, "moves": [{"move": "unfold", "start": 0.3}]}
    ]}
  ]
}
```
