# 0015 — Annotate screenshots

> Arrows, shapes, text, steps, a highlighter, blur, pixelate, spotlight and crop on the Quick Access card. Spec 0004, N13.

Status: built 2026-10-08 (`testing`).

## Why

CleanShot X's value is the screenshot workflow, and marking a shot up is most of it: an arrow at the button,
a box around the field, a number on each step, a blur over the name. Today a shot leaves the card as it was
taken, and marking it up means another app.

## What

- The card's **Annotate** button (top-right, first) grows the card to the shot's size on screen (shrunk to fit the
  screen) with a tool strip above the shot. The tools: **Select, Arrow, Line, Rectangle, Ellipse, Text, Highlighter,
  Step, Blur, Pixelate, Spotlight, Crop**, a colour, a line width, Undo, Redo and Delete, and at its end **Copy** and **Save**, which close the card
  with the marked shot (2026-10-09, in place of Done).
- Drag to draw a shape, click to place text or a step, drag to paint a highlight. Select moves a mark; ⌫ deletes the
  selected one; ⌘Z and ⇧⌘Z undo and redo. Esc leaves the text being typed, or else goes back to the card.
- Esc shrinks the card back, showing the annotated shot. Copy, Save, Pin and drag-out use it, from the small card
  or the large one (⌘C and ⌘S work in both). The marks stay editable until the card closes: Annotate again shows them
  on the shot.
- Marks go on the shot before its background (N14), so they sit inside the frame, and after Hide Sensitive Info (N9),
  which pixelates the plain shot.

## Rules

- **Geometry.** Marks live in the shot's points from its top-left corner (`Annotation`, pure, `Sendable`), so one
  drawing routine serves the live canvas (SwiftUI `Canvas`, through its `CGContext`) and the flattened PNG
  (`AnnotationRenderer.draw(_:in:)` into a bitmap at the shot's pixels). The canvas scales its context by the
  display size over the point size; nothing is stored in screen points.
- **Effects.** Blur, pixelate and spotlight are pixels, not vectors: `AnnotationFlattener` runs them through
  `MaskRenderer` (N8's filters, the same sigma, cell and noise) on the shot before the vectors are drawn over it.
  The canvas shows them the same way: the shot with its effects, rendered off the main actor whenever an effect
  mark changes (`AnnotationEditor.base`), under the vectors. Several spotlights light several places: everything
  outside all of them dims once.
- **Steps** are numbered in the order they were added; deleting one renumbers the rest. The number's disc is
  sized by the line width.
- **Crop** is one rectangle, kept in the document and applied last, so the marks keep their places; the canvas
  dims what is outside. Crop is the one mark the Select tool can't move; the Crop tool draws it again.
- **Text** is typed in place: the Text tool's click puts a field where it clicked; Return or clicking elsewhere
  keeps it (empty text is dropped). Drawn with Core Text, bold system font sized by the line width, with a thin
  contrasting halo so it reads over any shot.
- **Styles.** Eight colours (red, orange, yellow, green, blue, purple, white, black; red first) and three widths
  (2, 4, 8 pt). The highlighter is the colour at 40% alpha, 6× the width, round caps. New marks take the strip's
  colour and width; selecting a mark and picking another colour or width changes it.
- **Undo** is a history of documents in `AnnotationEditor`; each finished gesture, placed text or step, and each
  deletion or style change is one step. Dragging a draft isn't a step until it ends.
- **Output.** `AnnotationFlattener.flatten(_:on:)` (`@concurrent`): effects (Core Image, colour management off),
  then a `CGContext` at the shot's pixels (sRGB, premultiplied) draws the shot and the vectors scaled by the shot's
  scale, then the crop cuts it. The HDR picture is dropped (a marked shot saves as PNG). An empty document returns
  the shot unchanged, so a card that was only opened and closed loses nothing.
- **Card.** `QuickAccessViewModel` keeps `plainScreenshot` (the shot as captured, or with sensitive text hidden),
  the `AnnotationEditor` and whether a background is on, and composes what the card shows from them
  (`compose()`: plain → flattened → framed). `QuickAccessController.annotationCardSize(for:in:)` sizes the large
  card: the shot fitted to the screen's visible frame less the strip, insets and margins; the refit keeps the
  corner the card grew from, moved on screen where it wouldn't fit.

## Known limits

- One crop, no rotation, no resize handles on marks (move and delete only); a wrong size is redrawn.
- Marks are not saved with the PNG; closing the card flattens them for good.
- The highlighter is a plain polyline stroke, not smoothed.

## Verify

- `AnnotationTests`: steps renumber, hit testing picks the top mark, moving keeps a mark's size, tools make
  the right shape from a drag and nothing from a tap, the crop stays inside the shot, effects group by kind.
- `AnnotationRendererTests`: a rectangle's stroke lands on its pixels and nowhere else; text and steps draw
  something; pixelate moves each cell only a little; a blur changes only its rectangle; a crop gives the cropped
  size; an empty document returns the same image.
- `AnnotationEditorTests`: a drag makes a mark and undo takes it back; a move is one step and ⌫ removes the
  selection; text is placed by a click and kept on commit unless blank; a colour restyles the selected mark; a crop
  drag sets the crop and a click doesn't.
- `QuickAccessViewModelTests`: annotating grows the card and Done shows the marked shot, which Save uses.
- By hand: draw each tool on a card, Done, Copy; paste in Preview and compare. Done 2026-10-09 for arrow, rectangle
  and steps through Save: the PNG shows them where they were drawn. Instant synthetic drags (cliclick's `dd`/`dm`/`du` in
  one burst) never get `onEnded` from SwiftUI, so the canvas keys a press on its `startLocation` rather than a flag; such
  a drag leaves no mark, and the next press starts clean.
