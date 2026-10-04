# Layout and edit mode

Bars are arranged in **edit mode**, an overlay where bars can be moved, resized, and configured.
Outside edit mode, bars are just buttons.

## Resizing by dragging an edge

- **Decided**: You resize a bar by dragging its edges. Dragging adds or removes buttons, so a bar can
  grow freely from 1×1 to 1×10, 10×1, 10×10, or anything in between. Buttons stay square; their
  count changes, not their shape.
  - Dragging the right edge adds or removes columns.
  - Dragging the bottom edge adds or removes rows.
  - Dragging the corner does both.
- **Decided**: There's no hard-coded 10×10 limit; 10 was only an example.
- **Proposed**: A soft cap of 12×12 for performance, which can be raised if it turns out not to matter.
- **Proposed**: Shrinking a bar over buttons that hold something keeps their contents, so growing it
  back restores them.
- **Decided**: Scale is set **per bar**. Its options match the scale options Blizzard's own action
  bars offer. On Retail this is Edit Mode's "Icon Size", 50% to 200% in 10% steps. Check what
  Forever's Edit Mode offers and copy it.

## Moving

- **Decided**: You can move a bar anywhere on screen by dragging it in edit mode.
- **Decided**: There's a grid, and bars snap to it.
- **Proposed**: Snapping can be turned off, or bypassed by holding a key while dragging.

## Layers

- **Decided**: Each bar has a layer that controls whether it covers other UI or is covered by it.
  Internally this is the frame strata plus the frame level.
- **Proposed**: You choose from four simple layers instead of seeing strata names:

| Layer | Strata |
|---|---|
| Behind | `BACKGROUND` / `LOW` |
| Normal | `MEDIUM` |
| Above UI | `HIGH` |
| Top | `DIALOG` |

All eight stratas work on Forever, with frame levels up to 10000 (see [Platform](../platform.md)).

## Edit mode chrome

- **Decided**: Each bar shows a label in edit mode, with its name and a scope badge (character or account).
- **Decided**: Right-clicking a bar in edit mode opens a menu:
  - Scope
  - Visibility (opens the [rule editor](visibility.md#the-rule-editor))
  - Layer
  - Scale
  - Rename
  - Delete bar
- **Decided**: Edit mode is locked in combat; the menu shows why.
- **Decided**: Hook into Blizzard's own Edit Mode (`EditModeManagerFrame` exists on Forever) if
  possible. Opening Edit Mode would then also unlock Elastibar bars, with Elastibar's settings
  alongside Blizzard's.
  - Blizzard doesn't officially support addon frames in Edit Mode. On Retail, the community library
    LibEditMode does this. Next step: check whether it, or the same approach, works on Forever.
  - If it doesn't, Elastibar has its own edit mode with the same look and behavior.
