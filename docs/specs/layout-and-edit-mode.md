# Layout and edit mode

Bars are arranged in **Blizzard's Edit Mode**, where they can be moved, resized, and configured.
Outside Edit Mode, bars are just buttons.

## Edit Mode

- **Decided**: Elastibar hooks into Blizzard's own Edit Mode (`EditModeManagerFrame`). Opening Edit
  Mode also unlocks Elastibar bars.
  - **Confirmed feasible** (Edit Mode spike, 2026-10-04): with no taint and no errors, Elastibar can
    - detect Edit Mode opening and closing;
    - show Blizzard's selection overlay on its bars, with a name tooltip on hover;
    - select a bar (deselecting Blizzard's frame) and drag it;
    - open its own settings panel.
  - Blizzard doesn't officially support addon frames in Edit Mode, so this relies on the same hooks
    the community library LibEditMode uses on Retail. Elastibar uses its own small hook rather than
    vendoring the library.
- **Decided**: Each bar shows its name in a tooltip on hover, with a hint about dragging.
- **Decided**: Selecting a bar opens its **settings panel** (below). This replaces the right-click
  menu from the original spec, matching how Blizzard's own frames work in Edit Mode.
- **Proposed**: Bar positions are saved per Blizzard Edit Mode layout, like Blizzard's own frames.
  Switching between layouts is not a priority to test, since a single layout is the common case.

## Resizing

- **Decided**: You resize a bar by dragging its edges. Dragging adds or removes buttons, so a bar can
  grow freely from 1×1 to 1×12, 12×1, 12×12, or anything in between. Buttons stay square; their
  count changes, not their shape.
  - Dragging the right edge adds or removes columns.
  - Dragging the bottom edge adds or removes rows.
  - Dragging the corner does both.
  - The bar's top-left corner stays in place, so it grows right and down.
  - The change is live: buttons appear and disappear as you drag.
- **Decided**: The settings panel also has **Columns** and **Rows** sliders, for precise sizes.
- **Decided**: Bars are capped at **12 × 12**.
- **Decided**: Shrinking a bar over buttons that hold something hides them but keeps their contents,
  so growing it back restores them.
- **Decided**: Scale is set **per bar** with a slider, 50% to 200% in 10% steps (matching Blizzard's
  action bar "Icon Size"). The bar's center stays in place while scaling.

## Moving

- **Decided**: You can move a bar anywhere on screen by dragging it in Edit Mode.
- **Decided**: Bars snap to **Elastibar's own grid**, not Blizzard's Edit Mode grid. Its size is the
  "Grid size" setting in the [options panel](options-and-minimap.md) (default 20px; `/eb grid <px>`
  until the panel exists).
  - The bar's top-left corner snaps to the grid.
  - Grid lines show only while one of Elastibar's bars is being dragged.
  - **Decided**: Holding **Shift** while dragging moves the bar without snapping.

## Layers

- **Decided**: Each bar has a layer that controls whether it covers other UI or is covered by it.
  Internally this is the frame strata. You choose from four layers in the settings panel:

| Layer | Strata |
|---|---|
| Behind | `LOW` |
| Normal | `MEDIUM` |
| Above UI | `HIGH` |
| Top | `DIALOG` |

All eight stratas work on Forever, with frame levels up to 10000 (see [Platform](../platform.md)).

## Settings panel

Opens next to the selected bar in Edit Mode:

- the bar's name and scope (character or account);
- **Scale**, **Columns**, and **Rows** sliders;
- **Layer** (Behind, Normal, Above UI, Top);
- **Hide empty slots** (per bar, off for new bars). Hidden slots are made invisible rather than
  hidden, so they still accept drops and the setting works in combat. They reappear while
  something is on the cursor and while Edit Mode is open;
- **Visibility**, which opens the [rule editor](visibility.md#the-rule-editor) (a simple text box
  until build step 5);
- **Rename**;
- **Delete** (immediate, no confirmation).

Everything is locked in combat; Edit Mode itself can't be opened in combat.
