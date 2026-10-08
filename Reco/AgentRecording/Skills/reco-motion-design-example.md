# A whole film

The document Reco's own look-dev made of the reference: 22.4 s, five scenes, each cut on a beat with the same
object carried across. Its rows and covers are lifted from Spotify's web player, signed out, at a phone's
viewport; everything else is shapes and type.

1. The queue builds and scrolls; the dot under it grows into the pill, which is clicked and floods the frame.
2. The pill drains to an outline, fills with listeners and splits into Invite and Leave. Invite is chosen and
   becomes a caret.
3. A song's name is typed big and clicked.
4. Its row, a plus, a check in a burst.
5. The closing.

The playlist's rows start at the list's first item; `div:nth-of-type(n) > [data-encore-id=listRow]` is the n-th
row on that page. Another product's rows need their own selector from inspect_page.

```json
{
 "version": 1,
 "canvas": {"size": [1920, 1080], "frameRate": 30, "field": "ember", "fieldStrength": 0.45, "background": "#000000", "pacing": "beats"},
 "style": {"text": "#ffffff", "dim": "#a7a7a7", "accent": "#1ed760", "face": "sans"},
 "assets": [
  {"id": "row1", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(1) > [data-encore-id=listRow]", "bare": true},
  {"id": "row2", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(2) > [data-encore-id=listRow]", "bare": true},
  {"id": "row3", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(3) > [data-encore-id=listRow]", "bare": true},
  {"id": "row4", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(4) > [data-encore-id=listRow]", "bare": true},
  {"id": "row5", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(5) > [data-encore-id=listRow]", "bare": true},
  {"id": "row6", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(6) > [data-encore-id=listRow]", "bare": true},
  {"id": "row7", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(7) > [data-encore-id=listRow]", "bare": true},
  {"id": "row8", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(8) > [data-encore-id=listRow]", "bare": true},
  {"id": "row9", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(9) > [data-encore-id=listRow]", "bare": true},
  {"id": "row10", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(10) > [data-encore-id=listRow]", "bare": true},
  {"id": "row11", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(11) > [data-encore-id=listRow]", "bare": true},
  {"id": "row12", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(12) > [data-encore-id=listRow]", "bare": true},
  {"id": "song", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(1) > [data-encore-id=listRow]", "bare": true, "region": [[0, 0], [300, 64]]},
  {"id": "art1", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(2) > [data-encore-id=listRow] img"},
  {"id": "art2", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(3) > [data-encore-id=listRow] img"},
  {"id": "art3", "url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "viewport": [390, 844], "selector": "div:nth-of-type(4) > [data-encore-id=listRow] img"}
 ],
 "scenes": [
  {"id": "jam", "duration": 7.3, "layers": [
   {"id": "header", "content": {"group": [{"id": "queue", "content": {"text": {"text": "Queue", "size": 52, "color": "#ffffff", "weight": "bold"}}, "transform": {"position": [-520, 0, 0], "anchor": [0, 0.5]}, "moves": []}, {"id": "next", "content": {"text": {"text": "Playing next", "size": 32, "color": "#a7a7a7", "weight": "regular"}}, "transform": {"position": [-520, 54, 0], "anchor": [0, 0.5]}, "moves": []}, {"id": "clear", "content": {"text": {"text": "Clear", "size": 40, "color": "#a7a7a7", "weight": "regular"}}, "transform": {"position": [520, 0, 0], "anchor": [1, 0.5]}, "moves": []}]}, "transform": {"position": [960, 150, 0]}, "moves": [{"move": "fadeUp", "start": 0.1}, {"move": "scroll", "start": 1.5, "to": [960, -2005]}]},
   {"id": "list", "content": {"group": [{"id": "r1", "content": {"ui": {"asset": "row1", "width": 1070}}, "transform": {"position": [0, 0, 0]}}, {"id": "r2", "content": {"ui": {"asset": "row2", "width": 1070}}, "transform": {"position": [0, 215, 0]}}, {"id": "r3", "content": {"ui": {"asset": "row3", "width": 1070}}, "transform": {"position": [0, 430, 0]}}, {"id": "r4", "content": {"ui": {"asset": "row4", "width": 1070}}, "transform": {"position": [0, 645, 0]}}, {"id": "r5", "content": {"ui": {"asset": "row5", "width": 1070}}, "transform": {"position": [0, 860, 0]}}, {"id": "r6", "content": {"ui": {"asset": "row6", "width": 1070}}, "transform": {"position": [0, 1075, 0]}}, {"id": "r7", "content": {"ui": {"asset": "row7", "width": 1070}}, "transform": {"position": [0, 1290, 0]}}, {"id": "r8", "content": {"ui": {"asset": "row8", "width": 1070}}, "transform": {"position": [0, 1505, 0]}}, {"id": "r9", "content": {"ui": {"asset": "row9", "width": 1070}}, "transform": {"position": [0, 1720, 0]}}, {"id": "r10", "content": {"ui": {"asset": "row10", "width": 1070}}, "transform": {"position": [0, 1935, 0]}}, {"id": "r11", "content": {"ui": {"asset": "row11", "width": 1070}}, "transform": {"position": [0, 2150, 0]}}, {"id": "r12", "content": {"ui": {"asset": "row12", "width": 1070}}, "transform": {"position": [0, 2365, 0]}}]}, "transform": {"position": [960, 420, 0]}, "moves": [{"move": "cascade", "start": 0.35}, {"move": "scroll", "start": 1.5, "to": [960, -1735]}, {"move": "exit", "start": 3.3, "direction": "up"}]},
   {"id": "pill", "content": {"shape": {"size": [40, 40], "cornerRadius": 20, "color": "#1ed760"}}, "transform": {"position": [960, 1000, 0]}, "moves": [{"move": "pop", "start": 3.3}, {"move": "morph", "start": 3.45, "size": [560, 184]}, {"move": "morph", "start": 3.8, "to": [960, 540]}, {"move": "morph", "start": 4.85, "size": [615, 202], "duration": 0.12}, {"move": "click", "start": 5.2, "duration": 0.4}, {"move": "morph", "start": 5.35, "size": [560, 184], "duration": 0.25}, {"move": "flood", "start": 5.75}, {"move": "ripple", "start": 6.35, "color": "#3bf07c", "stroke": 90, "intensity": 2.5}, {"move": "ripple", "start": 6.62, "color": "#14b24c", "stroke": 70, "intensity": 2.5}, {"move": "morph", "start": 6.95, "size": [560, 184], "duration": 0.35}], "shadow": {"opacity": 0.6, "radius": 34, "offset": 0, "color": "#1ed760"}},
   {"id": "this", "content": {"text": {"text": "This is different", "size": 60, "color": "#000000", "weight": "semibold"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "wordByWord", "start": 3.95}, {"move": "exit", "start": 4.55, "direction": "up"}]},
   {"id": "start", "content": {"text": {"text": "Start a Jam", "size": 64, "color": "#000000", "weight": "bold"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "letters", "start": 4.85}, {"move": "exit", "start": 5.6}]},
   {"id": "chip", "content": {"shape": {"size": [300, 84], "cornerRadius": 42, "color": "#0b6e30", "stroke": 3}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "pop", "start": 6.2}, {"move": "exit", "start": 6.9}]},
   {"id": "starting", "content": {"text": {"text": "Starting", "size": 40, "color": "#0b6e30", "weight": "semibold"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "letters", "start": 6.3}, {"move": "exit", "start": 6.85}]}
  ]},
  {"id": "invite", "duration": 2.7, "seam": "cut", "layers": [
   {"id": "ring2", "content": {"shape": {"size": [427, 116], "cornerRadius": 58, "color": "#1ed760", "stroke": 3}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "morph", "start": 0.7, "size": [300, 84], "to": [690, 540]}]},
   {"id": "fill2", "content": {"shape": {"size": [380, 92], "cornerRadius": 46, "color": "#1ed760"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "morph", "start": 0.12, "color": "#1ed76000", "size": [300, 70], "duration": 0.3}]},
   {"id": "avatars", "content": {"group": [{"id": "a1", "content": {"ui": {"asset": "art1", "width": 58}}, "transform": {"position": [0, 0, 0]}}, {"id": "a2", "content": {"ui": {"asset": "art2", "width": 58}}, "transform": {"position": [44, 0, 0]}}, {"id": "a3", "content": {"ui": {"asset": "art3", "width": 58}}, "transform": {"position": [88, 0, 0]}}]}, "transform": {"position": [620, 540, 0]}, "moves": [{"move": "cascade", "start": 0.75}, {"move": "exit", "start": 2.15}]},
   {"id": "count", "content": {"text": {"text": "3", "size": 34, "color": "#ffffff", "weight": "semibold"}}, "transform": {"position": [790, 540, 0]}, "moves": [{"move": "pop", "start": 1.0}, {"move": "exit", "start": 2.2}]},
   {"id": "invite", "content": {"group": [{"id": "inviteRing", "content": {"shape": {"size": [190, 84], "cornerRadius": 42, "color": "#ffffff70", "stroke": 3}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "morph", "start": 1.25, "color": "#1ed760"}, {"move": "morph", "start": 1.65, "color": "#ffffff70"}, {"move": "morph", "start": 2.05, "stroke": 0, "color": "#1ed760"}, {"move": "morph", "start": 2.36, "size": [56, 56]}, {"move": "morph", "start": 2.55, "size": [16, 130], "radius": 5, "duration": 0.15}]}, {"id": "inviteLabel", "content": {"text": {"text": "Invite", "size": 36, "color": "#ffffff", "weight": "medium"}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "exit", "start": 2.05, "duration": 0.15}]}]}, "transform": {"position": [985, 540, 0]}, "moves": [{"move": "pop", "start": 0.85}, {"move": "click", "start": 2.05, "duration": 0.2}, {"move": "morph", "start": 2.36, "to": [620, 540]}]},
   {"id": "leave", "content": {"group": [{"id": "leaveRing", "content": {"shape": {"size": [190, 84], "cornerRadius": 42, "color": "#ffffff70", "stroke": 3}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "morph", "start": 1.65, "color": "#1ed760"}]}, {"id": "leaveLabel", "content": {"text": {"text": "Leave", "size": 36, "color": "#ffffff", "weight": "medium"}}, "transform": {"position": [0, 0, 0]}, "moves": []}]}, "transform": {"position": [1205, 540, 0]}, "moves": [{"move": "pop", "start": 1.1}, {"move": "exit", "start": 2.25}]}
  ]},
  {"id": "type", "duration": 2.4, "seam": "cut", "camera": {"moves": [{"move": "push", "start": 1.2, "duration": 0.9, "intensity": 2}]}, "layers": [
   {"id": "title", "content": {"text": {"text": "Patient Zero", "size": 150, "color": "#ffffff", "weight": "bold"}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "kinetic", "start": 0.1}, {"move": "click", "start": 1.45}]}
  ]},
  {"id": "add", "duration": 3.0, "seam": "cut", "camera": {"moves": [{"move": "pan", "start": 0.45, "to": [1430, 540], "intensity": 1.8, "duration": 0.6}]}, "layers": [
   {"id": "song", "content": {"ui": {"asset": "song", "width": 840}}, "transform": {"position": [840, 540, 0]}, "moves": [{"move": "rise", "start": 0.1}]},
   {"id": "disc", "content": {"shape": {"size": [170, 170], "cornerRadius": 85, "color": "#ffffff26"}}, "transform": {"position": [1430, 540, 0]}, "moves": [{"move": "pop", "start": 0.95}, {"move": "morph", "start": 1.2, "color": "#1ed760", "duration": 0.18}, {"move": "burst", "start": 1.32}, {"move": "ripple", "start": 1.36}]},
   {"id": "plus", "content": {"shape": {"size": [90, 90], "cornerRadius": 0, "color": "#ffffff", "stroke": 6, "kind": "plus"}}, "transform": {"position": [1430, 540, 0]}, "moves": [{"move": "pop", "start": 0.2}, {"move": "exit", "start": 1.2, "duration": 0.1}]},
   {"id": "check", "content": {"shape": {"size": [100, 100], "cornerRadius": 0, "color": "#000000", "stroke": 11, "kind": "check"}}, "transform": {"position": [1430, 540, 0]}, "moves": [{"move": "pop", "start": 1.44}]}
  ]},
  {"id": "closing", "duration": 7.0, "seam": "cut", "shot": {"shot": "closing", "text": "Spotify", "items": [{"text": "Queue"}, {"text": "Jam"}, {"text": "Invite"}, {"text": "Together"}], "detail": "Listen together"}}
 ]
}
```
