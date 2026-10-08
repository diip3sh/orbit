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
        "#rrggbb"; face sans|serif|mono; alignment leading|center} from inspect_page's brand, assets, scenes. Pacing \
        driftAndCut: 3–5 s shots, the camera drifting at constant speed, hard cuts (Linear). beats: 1–2 s beats, eased \
        camera moves (Raycast). Field, what scenes are drawn over, one look a film: plain (the background colour, the default: \
        the product's UI crisp on its own ground, as Linear's films); satin (black satin out of focus, lit afresh for each \
        scene, a slab of matte glass across a wide one's corner, monochrome: dark UI in macro, as Raycast's); the light \
        look's grainy light in the accent's hue: ember (two corners), sunlit (a wave from below), bloom (a blob in the \
        middle), orb (a lit sphere), ripple (rings from the middle); the dither look's ordered dots in the accent: matrix \
        (a lit sphere), warp (liquid streaks), swirl (arms turning), tide (a wave from below); halo (a ring of smoke). Light, \
        dither and halo go under a macro's glass, never under type.

        Asset: {id, url, selector, viewport [w,h] (default [1440,900]), hide [selectors], glass}: an element of a real page, \
        lifted alone with its rounded corners: a product screenshot, an app mockup, a card, a logo; never a whole section. \
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
        cutOnMotion (carries the camera's speed on), zoomThrough, blurCut, push, fade (rare); in a look's language, over \
        the whole frame: glow (light: a front of grainy light out of the next scene's field's shape, 0.9 s), dither \
        (dither: the frame turned to the accent's dots from its edges in, then into the next scene, 0.8 s), ring (a ring \
        of smoke opening from the middle, the next scene inside it, 1 s: into a closing).
        Moves {move, start, duration, intensity, direction, words, region, to}: text fadeUp, blurIn, blurWipe (letters sharpen \
        left to right), lineMask (lines rise out of a mask), wordByWord (words fade up one after another), type, roll (words: \
        the last word replaced in turn), exit; any layer rise, tilt, focus (region), detach, stateChange; a group cascade; \
        the camera hold, push, pan (to [x,y] on the canvas, intensity the zoom it ends at; pans chain, so a pan back out \
        follows a pan in), whip (to [x,y], intensity how much \
        closer, 0.35 s), pullBack, drift (direction left, right, up, down). intensity 1 is the grammar's own amount.
        Motion design (the reco-motion-design skill has recipes): shape layers {size, cornerRadius, color, stroke (an \
        outline that wide), kind rectangle|triangle|plus|check|cross|arrow|search|play|pause}; a shadow {opacity, radius, \
        offset 0, color} is a glow; canvas fieldStrength 0–1 tones the field down. Moves: morph {size, radius, color, \
        stroke (0 fills), to [x,y]} from where the last left it; flood (a rectangle out past the frame); pop; press; spin (a \
        quarter turn into place); click (a pointer comes in and presses it, a group too); burst {color} (particles); ripple \
        {color, stroke for soft bands inside a rectangle}; \
        letters and kinetic (text: springing in; typed behind an accent caret); scroll {to} (with cascade, rows build as \
        they come into view).

        Sound: every video gets a score and quiet effects made from its own timing: a chord a shot, a hit as the first UI \
        cuts in, keys as text is typed, a whoosh on a whip, Raycast's closing; mastered to -16 LUFS. Write nothing about \
        sound unless asked: set_sound {sound: {score, effects, scoreLevel, effectsLevel}} turns either off or moves its \
        level (dB, -24 to 6), e.g. "no typing sounds" effects false, "quieter music" scoreLevel -6.
        Operations: set_canvas {canvas}; set_style {style}; set_sound {sound}; set_asset {asset} (adds, or replaces the same id); add_scene \
        {scene, index}; set_scene {id, duration, seam, shot, field} (shot replaces the shot); set_layer {id, layer} (a layer of the \
        scene's own: {id, content: {"text": {text, size, face, weight, color}} or {"ui": {asset, width, typingStart, presses \
        [{key down|up, time}]: the selection moving through the results, the camera following}}, transform {position \
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
        "duration":{"type":"number"},"seam":{"type":"string","enum":["cut","whip","cutOnMotion","zoomThrough","blurCut","push","fade","glow","dither","ring"]},
        "shot":{"type":"object","description":"{shot: macro|hook|title|uiHero|uiFocus|uiCascade|featureSequence|endCard|closing, text, detail, ui, items, region, view}"},
        "field":{"type":"string","enum":["satin","plain","ember","sunlit","bloom","orb","ripple","matrix","warp","swirl","tide","halo"]},
        "moves":{"type":"array","items":{"type":"object"}}},
        "required":["op"],"additionalProperties":false}}},
        "required":["operations"],"additionalProperties":false}
        """#
}
