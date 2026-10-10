//
//  AgentToolCatalog+Motion.swift
//  Reco
//

/// `edit_motion`: what an agent knows of the grammar (spec 0011) is what this says.
nonisolated extension AgentToolCatalog {

    static let editMotionDescription = """
        Creates or changes a motion video: a launch video built from the product's real UI, in shots, moves and seams that \
        Reco lays out, times and eases. You write no animation: name what happens, set only what you mean, and the grammar's \
        defaults do the rest. Without bundle it starts a new video in the user's output folder (give it a name); with \
        bundle it edits that one; with bundle and no operations it only describes it. Operations apply in order, all or none, \
        and the result is checked. The reply describes the \
        video: each scene's start and duration, its layers with their ids (a shot's own too, from_shot), every move with \
        when it starts and ends in seconds into its scene, and the rules' findings to fix. Nothing renders here: then call \
        capture_ui and preview_motion.

        Video: canvas {size [1920,1080], frameRate 60, background "#rrggbb", field, fieldStrength, pacing}, style {text, dim, accent: \
        "#rrggbb"; gradient ["#rrggbb", 2–5 colours: the brand's gradient, cool end first]; face sans|serif|mono; alignment \
        leading|center} from inspect_page's brand, assets, scenes. Pacing \
        driftAndCut: 3–5 s shots, the camera drifting at constant speed, hard cuts (Linear). beats: 1–2 s beats, eased \
        camera moves (Raycast). Field, what scenes are drawn over, one look a film: plain (the background colour, the default: \
        the product's UI crisp on its own ground, as Linear's films); satin (black satin out of focus, lit afresh for each \
        scene, a slab of matte glass across a wide one's corner, monochrome: dark UI in macro, as Raycast's); the light \
        look's grainy light in the accent's hue: ember (two corners), sunlit (a wave from below), bloom (a blob in the \
        middle), orb (a lit sphere), ripple (rings from the middle); the dither look's ordered dots in the accent: matrix \
        (a lit sphere), warp (liquid streaks), swirl (arms turning), tide (a wave from below); halo (a ring of smoke); \
        aurora (black with soft lights in the brand's gradient from a corner or two, in a new place every scene, the last \
        ringing a dark middle and going out before the end: Lovable's; under type and rebuilt UI alike); haze (white with \
        style.gradient as soft light, pale to its last colour at a strong light's heart, drifting: a pastel orb behind type, \
        a deep blob sweeping in from a corner, faint corners under UI, a new setup every scene: light UI). Light, dither and \
        halo go under a macro's glass, or under type toned down (fieldStrength 0.45).

        Asset: {id, url, selector, viewport [w,h] (default [1440,900]), hide [selectors], glass}: an element of a real page, \
        lifted alone with its rounded corners: a product screenshot, an app mockup, a card, a logo; never a whole section. \
        A url to an image (.svg, .png, .jpg, .webp) is lifted with selector img: a brand's mark from \
        https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/<slug>.svg with bare true, sharp at any size. \
        With steps (record_page's hover, click, type, scroll; selectors on that page) and duration it is live: a take of the \
        element playing from its scene's start. glass true (stills): lifted without its own fill, border and shadow, on a \
        panel of dark glass with a rim of light, lit as its shot is: a control in macro over satin. bare true (stills): its \
        content alone, nothing behind it, set on the ground (a docs page's text). region [[x,y],[w,h]] (stills): only that \
        part of the element, CSS pixels from its top-left. typing {field (a \
        selector inside the element), text, select (how many results under the first to lift selected)} (stills): the \
        field typed into as a person types, results showing as each word \
        settles, a blinking caret; a ui layer's typingStart (seconds into its scene) starts it, else the field waits empty. \
        before [{action click|type, selector, text}] (stills): done on the page first, for what only exists after a click \
        (a search dialog: before clicks its button, selector names the dialog).

        Scene: {id, duration, seam, shot, field (else the canvas's), layers, camera}. Shots and their slots (ui is an asset id):
        - macro: ui and view, or items [{ui, view}] for several stops: one control so close the frame cuts it off (New \
        Raycast; glass assets over satin). view [[x,y],[w,h]] is what the frame shows, in CSS px from the element's top-left \
        corner (capture_ui gives sizes), roughly 16:9; smaller is closer, type 10–20% of the frame's height looks best; it may \
        reach past the element. The camera frames each stop, creeps closer, and whips 0.35 s to the next; the video's first \
        scene opens on 1 s of ground. A typing asset is typed 0.65 s after it shows (shown typed if an earlier macro typed \
        it); one with select steps through its results and back, the camera following.
        - hook: text (6 words at most) over ui, the product dimmed.
        - title: text, detail (a line under it), items [{text}]: once the headline is in, its last word rolls through the \
        items' text, about 0.5 s each; each must complete the headline as its own phrase \
        ("Agents for DevOps" → "Triage" → "Planning").
        - uiHero: ui flat and as large as the frame allows, the camera pulling back onto it.
        - uiFocus: ui flat and close, region [[x,y],[w,h]] in fractions of it: the view frames that part, the rest dims.
        - uiCascade: items [{ui}], two or more, rising one after another, side by side when they're tall.
        - featureSequence: items [{text, ui}], one feature at a time, each its slice of the scene.
        - endCard: text (the name; at a headline's size without a logo) or ui (the logo), detail (the address or a call to \
        action, in the accent). Still: give it about 3.5 s.
        - closing: text (the name), items [{text}] (the product's words, the last joining the name), detail (a line under \
        them), ui (the logo, shown alone last): New Raycast's ending in small mono caps, a word cut in every 0.42 s. Give it \
        0.42 s a word plus 4.5 s, 1.6 s more with ui; it's drawn on black.
        Seams, how a scene begins: cut (most), whip (the camera streaks out sideways and into the next scene, blurred), \
        cutOnMotion (carries the camera's speed on), zoomThrough, blurCut, push, fade (rare), stack (the next scene rises \
        from below on a card over this one, which sinks back and dims, 0.7 s), expand (the next scene opens out of what this \
        one clicked last, or its middle, as an app opens from its icon, 0.65 s), dive (the camera tilts and flies through \
        what this one clicked last, or its middle, into the next scene seen through it, 0.8 s), melt (this scene dissolves \
        into the next by its own light, darks first, in grain, its front in the brand's colours, 0.75 s: an image into the \
        ground, the ground into a picture); in a look's language, over \
        the whole frame: glow (light: a front of grainy light out of the next scene's field's shape, 0.9 s), dither \
        (dither: the frame turned to the accent's dots from its edges in, then into the next scene, 0.8 s), ring (a ring \
        of smoke opening from the middle, the next scene inside it, 1 s: into a closing). Glow or dither on the first scene, \
        in its look: the ground swells in from black and the scene arrives in the seam by 1.4 s.
        Moves {move, start, duration, intensity, direction, words, region, to}: text fadeUp, blurIn, blurWipe (letters sharpen \
        left to right), lineMask (lines rise out of a mask), wordByWord (words fade up one after another), type, roll (words: \
        the last word replaced in turn), exit; any layer rise, tilt, focus (region), detach, stateChange; a group cascade; \
        the camera hold, push, pan (to [x,y] on the canvas, intensity the zoom it ends at; pans chain, so a pan back out \
        follows a pan in), whip (to [x,y], intensity how much \
        closer, 0.35 s), pullBack, drift (direction left, right, up, down). intensity 1 is the grammar's own amount.
        Motion design (the reco-motion-design skill has recipes): shape layers {size, cornerRadius, color, stroke (an \
        outline that wide), kind rectangle|triangle|plus|check|cross|arrow|search|play|pause, glass (a filled rectangle as a \
        pane of glass over the field, its color a veil such as #ffffff0d)}; a shadow {opacity, radius, \
        offset 0, color} is a glow; canvas fieldStrength 0–1 tones the field down. Moves: morph {size, radius, color, \
        stroke (0 fills), to [x,y]} from where the last left it; flood (a rectangle out past the frame); pop; press; spin (a \
        quarter turn into place); click (a pointer comes in and presses it, a group too); burst {color} (particles); ripple \
        {color, stroke for soft bands inside a rectangle}; \
        letters and kinetic (text: springing in; typed behind an accent caret); scroll {to} (with cascade, rows build as \
        they come into view).
        Story films (the reco-story-film skill has recipes): glyph kinds chevron, mic, terminal, branch too; voice (text: \
        what someone says, typed big at 13 characters a second, the newest words in style.gradient behind a thin caret, \
        centred as it grows and then following its caret at 70 % of the width, with its group if it has one); reply (text: \
        words arriving 0.15 s apart, each in the gradient, then white); shimmer (the gradient running through a layer's \
        pixels from start for duration, the scene's rest by default); wash (the gradient sweeping across a layer or a \
        group's layers, 1.2 s: a prompt sent); scatter (a group: its layers thrown out of a stack in its middle to their \
        places); show and hide (there from, gone from, start: contents swapping on a beat). A camera {position [x, y, z]} \
        starts a scene close: z = 1728 × (1 − 1/zoom) at 1080p (3.5× is 1234). A click within 0.6 s of its scene's start \
        has the pointer there from the cut; in a close scene the pointer is as large as the camera shows it.
        Flow films (the reco-flow-film skill has recipes): fly (a mark or icon flies in on an arc onto its place, banking, \
        0.9 s; direction the way it travels, left by default: in from the right); select {color} (text: selected part by part \
        as the arrow drags across it, 60 characters a second, held after).

        Sound: every video gets a score and quiet effects made from its own timing. sound.style picks the score: ambient \
        (the default: a chord a shot, a hit as the first UI cuts in, Raycast's closing), groove (170 BPM drum and bass, \
        Lovable's: an intro without drums, a drop at the first cut two bars in, a break under a scene of big type alone, \
        drums out under the end words) or house (125 BPM, the Spotify Jam's, from the first frame). A beat fits its tempo \
        to the cuts: put cuts on beats (groove 0.353 s, house 0.48 s). Write nothing else about sound unless asked: \
        set_sound {sound: {style, score, effects, scoreLevel, effectsLevel}} picks the style, turns either part off or \
        moves its level (dB, -24 to 6), e.g. "no typing sounds" effects false, "quieter music" scoreLevel -6.
        Operations: set_canvas {canvas}; set_style {style}; set_sound {sound}; set_asset {asset} (adds, or replaces the same id); add_scene \
        {scene, index}; set_scene {id, duration, seam, shot, field} (shot replaces the shot); set_layer {id, layer} (a layer of the \
        scene's own: {id, content: {"text": {text, size, face, weight, color}} or {"ui": {asset, width, tint, typingStart, \
        presses [{key down|up, time}]: the selection moving through the results, the camera following}} (tint: the lift in \
        that one colour, a black mark made white), transform {position \
        [x,y,z]}, moves}); set_moves {id, target, moves} (target a layer id from the reply, or camera: replaces \
        all its moves, a shot's layer keeping its place; copy the moves you keep from the reply); move_scene {id, index}; \
        remove {id, target} (a scene, an asset, or a scene's layer; a shot's layer goes back to the shot's moves). Times are \
        seconds: 8 frames at 60 fps are 0.133 s.
        """

    static let editMotionSchema = #"""
        {"type":"object","properties":{
        "bundle":{"type":"string","description":"Path of the .motion bundle from an earlier edit_motion; leave out to start a new video"},
        "name":{"type":"string","description":"A new video's name, e.g. the product's"},
        "operations":{"type":"array","items":{"type":"object","properties":{
        "op":{"type":"string","enum":["set_canvas","set_style","set_sound","set_asset","add_scene","set_scene","set_layer","set_moves","move_scene","remove"]},
        "id":{"type":"string","description":"The scene (or for remove, the scene or asset)"},
        "target":{"type":"string","description":"set_moves, remove: a layer id from the reply, or camera"},
        "index":{"type":"integer","description":"add_scene, move_scene: position from 0"},
        "canvas":{"type":"object"},"style":{"type":"object"},"sound":{"type":"object"},"asset":{"type":"object"},"scene":{"type":"object"},"layer":{"type":"object"},
        "duration":{"type":"number"},
        "seam":{"type":"string","enum":["cut","whip","cutOnMotion","zoomThrough","blurCut","push","fade","stack","expand","dive","melt","glow","dither","ring"]},
        "shot":{"type":"object","description":"{shot: macro|hook|title|uiHero|uiFocus|uiCascade|featureSequence|endCard|closing, text, detail, ui, items, region, view}"},
        "field":{"type":"string","enum":["satin","plain","ember","sunlit","bloom","orb","ripple","matrix","warp","swirl","tide","halo","aurora","haze"]},
        "moves":{"type":"array","items":{"type":"object"}}},
        "required":["op"],"additionalProperties":false}}},
        "required":["operations"],"additionalProperties":false}
        """#
}
