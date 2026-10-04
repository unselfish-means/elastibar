# Buttons

Each button holds one spell, item, or macro.

## Placing things on buttons

- **Decided**: You can place spells, items, and macros by dragging them from the spellbook, your
  bags, or the macro window onto a button.
- **Decided**: Account bars accept only items and account macros (see [Bars](bars.md#character-and-account-bars)).
- **Decided**: Buttons can't be changed in combat.
- **Proposed**: Macros are stored by name, not by index, because macro indexes shift when macros
  are added or deleted. If a macro is deleted, its button shows as empty but remembers the name, so
  recreating the macro restores it.
- **Decided**: **Shift-drag** picks up what a button holds, which empties the button. Then:
  - dropping it on another Elastibar button moves it there;
  - dropping it on a Blizzard action bar places it there (the game handles this);
  - dropping it anywhere else deletes it.
- **Proposed**: Dropping onto a button that already holds something swaps the two, as Blizzard's
  bars do.
- **Decided**: Mounts, toys, and pets count as items: they can go on any bar, including account bars.
- **Open**: Equipment sets weren't discussed.

## What a button shows

- The icon. Macros show their own icon.
- A cooldown swipe. Macros show the cooldown of the spell they'd currently cast.
- The item count for stackable items.
- Dimmed when unusable, and tinted red when the target is out of range.

## Tooltips

- **Decided**: Hovering a spell or item shows its normal game tooltip.
- **Decided**: Macros can have a **custom tooltip** that you write. Button Forge doesn't offer this.
  Formatting and storage can wait until the next version if they're hard.
- **Proposed**: Keep **plain-text** custom tooltips in v1, stored per macro so the text follows the
  macro to any bar. This is cheap: a text field and a few lines in the hover handler. Formatting
  (title line, colors) moves to the next version.
- **Proposed**: A macro with no custom tooltip shows the tooltip of the spell or item it would
  currently use (as `#showtooltip` does), falling back to the macro's name.
