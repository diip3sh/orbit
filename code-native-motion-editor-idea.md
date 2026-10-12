# Code-Native Motion Video Editor

> **The plan is `docs/specs/0011-motion-editor.md`.** It keeps this idea (structured scene graph,
> motion grammar, agent edits properties, never regenerates) but not the stack: Reco renders
> natively (WebKit draws layers, Core Image moves them), with no Remotion, React or GSAP.

## Core Idea

Build a **code-native motion design editor** that can create product launch videos and motion graphics at a quality level comparable to work made in Adobe After Effects.

The product should keep the benefits of code-driven video generation:

- deterministic output
- reusable components
- programmatic animation
- easy automation
- AI-assisted generation
- versionable projects

But the final video should **not look AI-generated**.

The goal is not:

> Prompt → generic AI video

The goal is:

> Prompt → structured motion design → visually editable timeline → polished launch video

A good positioning direction:

> **Make Linear / Raycast-quality product launch videos without knowing motion design.**

Another useful framing:

> **AI doesn't generate the video. It writes the motion design.**

---

# What “After Effects Quality” Means

## What is Adobe After Effects?

Adobe After Effects is professional software used for:

- motion graphics
- animated typography
- product launch videos
- UI animation
- compositing
- visual effects
- logo animation
- title sequences
- camera movement
- masking and reveals

You can think of it as:

> **Figma / Photoshop + a timeline + animation + effects**

Almost every property can change over time:

- position
- scale
- rotation
- opacity
- blur
- masks
- shadows
- gradients
- 3D transforms
- camera position
- text properties
- easing

Designers animate these using **keyframes** on a timeline.

---

# What “After Effects Quality” Means for This Product

The product does **not** need to literally use After Effects.

“After Effects quality” means the resulting video feels like it was intentionally designed by a skilled motion designer.

Important characteristics:

- smooth intentional motion
- strong typography
- coordinated timing
- good easing
- masks and reveals
- depth
- camera movement
- velocity continuity
- controlled blur
- staggered animation
- motion hierarchy
- transitions that connect scenes
- animation synchronized with music / sound
- real product UI rather than random generated imagery

The video should feel like **motion design**, not a slideshow.

---

# Reference Quality Bar

## Raycast

This is one of the strongest references for the direction.

**Raycast-style launch video**

https://www.youtube.com/watch?v=czz9Tbf8VaE

What makes this style good:

- aggressive UI crops
- large typography
- fast but controlled cuts
- real product interface
- camera punch-ins
- dark backgrounds
- highlighted product interactions
- transitions synced with sound
- very little unnecessary decoration

A major lesson from Raycast:

> You don't need insane VFX. Great timing + typography + UI choreography can already look premium.

---

## Linear

**Introducing Linear for Agents**

https://www.youtube.com/watch?v=sbwOQV5zY34

Useful characteristics:

- real interface
- minimal visuals
- controlled camera movement
- strong typography
- very few elements at once
- carefully timed transitions
- polished product storytelling

Linear is a particularly useful benchmark because its videos are sophisticated without depending on huge amounts of cinematic VFX.

---

## Brex

**Brex Spring Release**

https://www.youtube.com/watch?v=9SVB4aTHQcs

Useful mainly for studying:

- product UI animation
- animated feature explanations
- typography
- interaction between live action and motion graphics

For the MVP, focus on the animated UI sections rather than live-action production.

---

# The Difference Between Basic AI Video and Motion Design

Imagine announcing:

> AI Agents can now fix issues automatically.

A generic AI/template video might be:

```text
Black screen

"Introducing AI Agents"
        ↓
fade

Screenshot slides in
        ↓
zoom

"Resolve issues automatically"
        ↓
fade

Logo
```

It technically communicates the feature, but feels like a template.

A stronger motion-designed version:

```text
0:00

Almost-black background.

Huge typography:

BUILD LESS.
SHIP MORE.

Letters reveal with:
- masks
- slight blur
- stagger


0:02

Text collapses.

Product UI appears from underneath.


0:04

Camera pushes into one issue.

Cursor moves.

Delegate → Agent


0:06

Issue card separates from the interface.

Three agent steps appear:

READ
 ↓
CODE
 ↓
PR


0:10

Cards accelerate upward.

Camera pulls back.


0:12

Entire product UI snaps back into frame.

Issue:
✓ Completed


0:14

Cut on beat.


YOUR BACKLOG
CAN NOW
WORK ITSELF.


0:17

Logo.
```

Most of this can be created without generative video.

It is primarily:

- text
- UI screenshots
- SVG
- transforms
- masks
- easing
- blur
- timing
- cursor animation
- sound

That is why **Remotion** is a strong underlying technology.

---

# Product Direction

Instead of building:

> AI video generator

Build:

> **Figma × After Effects × Claude Code for product motion**

The editor remains visual, but the underlying source is structured and programmable.

---

# Ideal Workflow

```text
Website / screenshots / screen recording
                +
              prompt
                ↓
          AI planner
                ↓
        motion scene graph
                ↓
         visual editor
                ↓
        timeline + canvas
                ↓
        prompt-based edits
                ↓
          Remotion render
                ↓
       polished launch video
```

Example prompt:

> Create a 15-second launch video for this dashboard. Start close on the AI button, show the user delegating an issue, zoom out into three feature cards, then end with the logo.

---

# Scene Graph

Instead of the LLM directly generating arbitrary React code, the system should generate a structured scene.

Example:

```text
Scene
├── Camera
├── ProductWindow
│   ├── Screenshot
│   ├── Cursor
│   └── Highlight
├── Headline
├── FeatureCard
├── FeatureCard
├── FeatureCard
└── Background
```

Every object remains selectable and editable.

---

# Motion AST / Intermediate Representation

A strong architecture would be:

```text
Natural language
      ↓
Motion AST / Scene Graph
      ↓
Validated motion primitives
      ↓
React / Remotion
      ↓
Interactive editor
      ↓
Renderer
```

Avoid making this the primary architecture:

```text
LLM
 ↓
arbitrary JSX
 ↓
hope it looks good
```

Instead:

```text
LLM
 ↓
structured motion specification
 ↓
motion engine
 ↓
deterministic render
```

Example:

```json
{
  "type": "text",
  "content": "Ship faster.",
  "animation": {
    "preset": "word-mask-rise",
    "duration": 18,
    "stagger": 3,
    "easing": "expoOut"
  }
}
```

Advanced users can still drop down to code when necessary.

---

# Why It Shouldn't Look AI Generated

The AI should **not invent every animation independently**.

Build a motion system underneath it.

The AI selects and combines high-quality motion primitives.

Example motion grammar:

```text
ENTRANCES
├── reveal-mask
├── blur-rise
├── overshoot
├── scale-in
├── slide-clip
└── camera-reveal

TRANSITIONS
├── match-cut
├── whip
├── zoom-through
├── morph
├── depth-push
└── hard-cut-on-beat

TYPOGRAPHY
├── word-mask
├── stagger
├── kinetic
├── tracking-reveal
├── blur-reveal
└── character-stagger

UI
├── cursor-click
├── focus-highlight
├── panel-expand
├── modal-open
├── card-detach
└── browser-zoom
```

The real IP could eventually become this **motion grammar + quality system**.

---

# Motion Design Rules

The rendering engine should understand principles such as:

## Easing

Objects should rarely move linearly.

Use good easing curves such as:

- expo out
- quart out
- cubic bezier
- spring
- overshoot

---

## Anticipation

A movement can briefly go in the opposite direction before accelerating.

This makes animation feel intentional.

---

## Overshoot

An object can slightly pass its target and return.

Useful for:

- UI cards
- buttons
- scale animations
- text reveals

---

## Stagger

Elements should often enter a few frames apart rather than simultaneously.

Example:

```text
Card 1 → frame 20
Card 2 → frame 23
Card 3 → frame 26
```

---

## Motion Hierarchy

Not everything should animate with equal intensity.

Primary object:
- strongest motion

Supporting elements:
- smaller motion

Background:
- subtle motion

---

## Velocity Continuity

If an object exits quickly to the right, the next scene should often continue that directional energy.

This prevents transitions from feeling disconnected.

---

## Camera Movement

Instead of moving every element independently, sometimes move the camera.

Useful effects:

- push in
- pull out
- pan
- parallax
- zoom through UI
- focus shift

---

# Suggested Tech Stack

Core rendering:

- **Remotion**
- React
- TypeScript

Visual layers:

- CSS
- SVG
- Canvas
- WebGL
- Three.js where needed

Editor:

- React
- timeline
- scene graph
- property inspector
- canvas
- selection system

AI:

- prompt → scene planning
- scene edits
- motion preset selection
- copy generation
- timing adjustment

Rendering:

- Remotion renderer
- FFmpeg where necessary

---

# Why Remotion Over Manim

## Manim

Best for:

- mathematics
- educational explainers
- diagrams
- equations
- algorithm visualizations

Manim is excellent, but it is optimized around mathematical/technical animation.

## Remotion

Better suited for:

- SaaS launch videos
- UI animation
- product videos
- browser mockups
- marketing motion graphics
- text-heavy videos
- React components
- programmatic video generation

For this project, **Remotion should probably be the primary engine**.

Manim could potentially be supported later for technical/educational scenes.

---

# Editor UX

A simplified editor could look like:

```text
┌─────────────────────────────────────────────┐
│                                             │
│                  CANVAS                     │
│                                             │
│              [ PRODUCT UI ]                 │
│                     ↑                       │
│                  cursor                     │
│                                             │
├─────────────────────────────────────────────┤
│ Text       ███████                          │
│ UI            █████████████                 │
│ Cursor            █████                     │
│ Glow              ████████                  │
│ Music      █████████████████████████        │
│            0s    2s    4s    6s    8s      │
└─────────────────────────────────────────────┘
```

Clicking an element could show:

```text
POSITION
X: 420
Y: 190

SCALE
100% → 135%

ANIMATION
Smooth Zoom

EASING
Expo Out

BLUR
12px → 0px

DURATION
0.6s
```

---

# AI Editing

This is where the product gets interesting.

Instead of manually modifying the timeline, the user can select an element and type:

> Make this entrance faster.

Or:

> Make this reveal more dramatic.

Or:

> Zoom into this button before the next scene.

Or:

> Make these three cards appear one after another.

Or:

> Make the entire video feel more like a premium developer-tool launch.

The AI modifies actual timeline properties.

It does not regenerate the entire video.

---

# MVP

Do **not** try to recreate all of After Effects.

A small subset can already produce extremely good SaaS launch videos.

## MVP Features

### 1. Scene Graph

Objects:

- text
- image
- video
- SVG
- shape
- product window
- cursor
- highlight
- background

---

### 2. Timeline

Support:

- object duration
- start/end
- keyframes
- trimming
- layering

---

### 3. Core Animation Properties

- position
- scale
- rotation
- opacity
- blur
- masks
- border radius
- shadows
- transforms

---

### 4. Motion Presets

Start with roughly **20–30 excellent presets**, not hundreds of mediocre ones.

---

### 5. Typography Animation

High priority.

Support:

- character stagger
- word stagger
- mask reveals
- blur reveals
- scale
- tracking
- line transitions

Typography is a huge part of the Linear/Raycast visual style.

---

### 6. UI Animation

Support:

- browser window
- cursor
- mouse clicks
- focus states
- zoom into UI
- element highlights
- floating cards
- callouts

---

### 7. Camera

Support:

- zoom
- pan
- follow
- push
- pullback

---

### 8. Prompt → Scene

Example:

> Create a 12-second launch animation. Start zoomed into the dashboard, highlight the AI button, show the cursor clicking it, reveal three features, then end on our logo.

---

### 9. Prompt-Based Editing

Select a layer and say:

> Make this more dramatic.

The agent changes the actual motion properties.

---

### 10. Remotion Export

Export:

- MP4
- WebM
- GIF later
- different aspect ratios

---

# Recommended Initial Wedge

Do not initially market this as:

> A replacement for After Effects.

That is too broad.

Start with:

> **AI motion editor for software launch videos.**

Inputs:

- website URL
- screenshots
- screen recording
- logo
- product copy
- prompt

Output:

> polished 15–45 second product launch video

Target users:

- SaaS founders
- indie hackers
- developer-tool companies
- product marketers
- designers
- agencies
- startups launching new features

---

# Ideal Example

User provides:

```text
https://myproduct.com
```

Then says:

> Make a 20-second launch video for our new AI agent.

The system:

1. captures relevant product visuals
2. understands the site's visual language
3. creates a storyboard
4. selects motion primitives
5. creates typography
6. animates screenshots/UI
7. adds cursor interactions
8. creates transitions
9. generates a timeline
10. opens everything inside the editor

The user can then manually or conversationally modify every part.

---

# Quality Benchmark

The main evaluation should **not** be:

> Did the AI follow the prompt?

It should be:

> **Would someone believe a motion designer spent a few hours making this?**

Another benchmark:

> Could this video plausibly appear on the launch page of Linear, Raycast, Vercel, Stripe, Framer, or another high-quality software company?

---

# What Could Become the Moat

The moat probably isn't Remotion itself.

Possible defensibility:

## 1. Motion Grammar

High-quality reusable motion behaviors.

## 2. Motion Taste

Knowing which animation should be used where.

## 3. Scene Planning

Turning a product feature into a good visual story.

## 4. UI Understanding

Understanding product screenshots and interaction flows.

## 5. Editable AI Output

Generated content remains structured rather than becoming a flat video.

## 6. Design-System Awareness

Matching:

- typography
- colors
- spacing
- radius
- animation style
- branding

## 7. Motion Quality Evaluation

Potentially build an evaluator that detects:

- awkward timing
- excessive simultaneous motion
- poor easing
- text appearing too quickly
- inconsistent animation
- weak hierarchy
- dead time

---

# Longer-Term Direction

Eventually the system could understand:

```text
Product
 ↓
brand
 ↓
visual language
 ↓
story
 ↓
scenes
 ↓
motion
 ↓
sound
 ↓
finished launch video
```

It could become less like a traditional video editor and more like:

> **an IDE for motion design**

Where the source of truth is structured, editable, programmable motion.

---


# Sharper Product Positioning

The strongest articulation of the product is:

> **After-Effects-like editable motion system + code as source of truth + agent-native editing + high-end product-launch taste.**

This is the key differentiation.

The goal is not just to generate a launch video once.

The product should:

> **Generate something genuinely good, but then every camera move, text reveal, UI crop, mask, easing curve, timing, and layer is still editable visually or by talking to the agent.**

That means the user can make very precise follow-up changes without regenerating or breaking the rest of the composition.

Example agent edit:

> **Keep everything else identical. Make this camera push slower, reveal the heading word-by-word, and move the UI transition 8 frames earlier.**

The agent should understand this as a structured edit to the existing timeline / scene graph rather than a request to regenerate the video.

A concise product framing:

> **Cursor for motion design — generate and edit premium product launch videos as structured code.**

This framing captures the four most important parts of the product:

- professional motion quality
- structured / code-native output
- direct visual editing
- precise agent-native editing

The product should feel less like an AI video generator and more like a **motion-design environment where the agent can understand and manipulate the entire composition**.

---

# Core Product Thesis

The strongest version of the idea is:

> **Code-native motion design with a visual editor and an AI agent that understands motion.**

Not:

> AI generates a video.

And the initial product wedge should be:

> **Generate and edit premium software launch videos that look like they were made by a professional motion designer.**

## Main reference

Raycast-style launch video:

https://www.youtube.com/watch?v=czz9Tbf8VaE
