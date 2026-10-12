# Paper Shaders: the four picked backgrounds

These are the source files for the four background fields chosen for spec 0012 (Q2 Look) on
2026-10-07: `ember`, `matrix`, `halo` and `sunlit`. They come from `@paper-design/shaders` 0.0.81,
under the Apache-2.0 licence (see `LICENSE` and `NOTICE`; the app's acknowledgements must carry
the NOTICE). This is the reference to port to Metal; it is not built into the app.

| File | What it is |
|---|---|
| `grain-gradient.frag` | GLSL ES 3.0 fragment shader, complete with its shared chunks. Used by `ember` and `sunlit` |
| `dithering.frag` | Fragment shader for `matrix` |
| `smoke-ring.frag` | Fragment shader for `halo` |
| `vertex.vert` | The shared vertex shader. It computes the UVs the fragments use from the sizing uniforms |
| `noise.png` | The 128×128 noise texture behind `u_noiseTexture`. Grain gradient and smoke ring sample it with repeat wrapping |
| `constants.json` | Enum values (shapes, dither types, fit) and the default sizing objects |
| `shader-mount.js`, `shader-sizing.js`, `get-shader-color-from-string.js` | How the library sets uniforms, time and resolution, and turns colours into vec4s |
| `gallery.html` | The page the looks were picked from (`claude.ai/artifact/BEUexQU89URCg9JgdrFd9u`), with all 12 candidates and their exact settings |

## Driving a frame

These come from `shader-mount.js`.

- **Time.**
  - `u_time = frame_ms × 1e-3`.
  - `frame_ms` advances by `dt_ms × speed` per frame.
  - For a deterministic export, use `u_time = t_seconds × speed`.
- **Resolution.** `u_resolution` is the canvas size in pixels. `u_pixelRatio` is the render scale.
  The shapes are sized in CSS pixels × `u_pixelRatio`, so set it to (output height / 1080) or so
  for video.
- **Sizing.** Every sizing uniform must be set. The values come from `defaultObjectSizing` or
  `defaultPatternSizing` in `constants.json`, overridden as noted below. Unset uniforms default to
  0, and `u_scale = 0` draws nothing.
  - `u_fit`
  - `u_scale`
  - `u_rotation`
  - `u_originX`, `u_originY`
  - `u_offsetX`, `u_offsetY`
  - `u_worldWidth`, `u_worldHeight`
- **Colours.**
  - Colours are RGBA in 0…1. `getShaderColorFromString` parses hex, rgb and hsl.
  - `u_colors` is an array of up to 7 (grain gradient) or 10 (smoke ring) vec4s, plus
    `u_colorsCount`.

## The four looks, exactly as picked

Hex values are the gallery's example palettes. In Reco they come from the brand.

### `ember`: bold brands, type in the dark gap

| Setting | Value |
|---|---|
| Shader | grain gradient, `u_shape = 4` (corners) |
| Sizing | defaultObjectSizing |
| `u_colorBack` | #050405 |
| `u_colors` | #FF3B2F, #8A1414, #2A0C12 |
| `u_softness` | 0.6 |
| `u_intensity` | 0.35 |
| `u_noise` | 0.3 |
| `u_noiseTexture` | noise.png |
| Speed | 0.4 |
| Overlay | vignette 20% |

### `matrix`: technical brands

| Setting | Value |
|---|---|
| Shader | dithering, `u_shape = 7` (sphere), `u_type = 3` (4×4 ordered) |
| Sizing | defaultPatternSizing with `u_scale = 0.6` |
| `u_colorBack` | #060907 |
| `u_colorFront` | #2F9E6C |
| `u_pxSize` | 2 |
| Speed | 0.35 |
| Overlay | vignette 50% |

### `halo`: the end card's logo moment

| Setting | Value |
|---|---|
| Shader | smoke ring |
| Sizing | defaultObjectSizing with `u_scale = 0.8` |
| `u_colorBack` | #000000 |
| `u_colors` | #FFFFFF, #3ECF8E |
| `u_noiseScale` | 3 |
| `u_noiseIterations` | 8 |
| `u_radius` | 0.3 |
| `u_thickness` | 0.65 |
| `u_innerShape` | 0.7 |
| `u_noiseTexture` | noise.png |
| Speed | 0.3 |
| Overlay | grain 5% |

The logo sits centred inside the ring and the wordmark sits below it, outside the smoke.

### `sunlit`: calm or playful title cards

| Setting | Value |
|---|---|
| Shader | grain gradient, `u_shape = 1` (wave) |
| Sizing | defaultPatternSizing |
| `u_colorBack` | #140C04 |
| `u_colors` | #C4730B, #BDAD5F, #D8CCC7 |
| `u_softness` | 0.7 |
| `u_intensity` | 0.15 |
| `u_noise` | 0.5 |
| `u_noiseTexture` | noise.png |
| Speed | 0.35 |
| Overlay | vignette 30% |

## Porting notes

- **Translating to Metal.** The fragments are WebGL2 GLSL (`#version 300 es`, `mediump`). Port
  each one to a Metal Core Image kernel (`CIKernel` from a `.metal` library), or to a small Metal
  render pass into the frame's texture.
  - Use `float` precision throughout.
  - `texture()` becomes `sample()`.
  - `mod` becomes `fmod`, but it differs for negative values: use `x - y * floor(x / y)`.
- **Validating the port.** Render the same `u_time` in `gallery.html` with `setFrame(ms)` and in
  Reco, then compare the pixels.
- **The gallery's overlays are CSS, not part of the shaders.** The grain is an animated SVG
  turbulence at 5–7% opacity, overlay blend, re-seeded at 12 steps a second. The vignette is a
  radial gradient. Reco does both in its own grain and vignette pass (spec 0012 Q2).
