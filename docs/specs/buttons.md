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
- **Open**: How do you remove something from a button? Options: drag it off (like Blizzard's bars),
  Shift-drag, or a right-click menu in edit mode.
- **Open**: Do mounts, toys, pets, and equipment sets count as items in v1?

## What a button shows

- The icon. Macros show their own icon.
- A cooldown swipe. Macros show the cooldown of the spell they'd currently cast.
- The item count for stackable items.
- Dimmed when unusable, and tinted red when the target is out of range.

## Tooltips

- **Decided**: Hovering a spell or item shows its normal game tooltip.
- **Decided**: Macros can have a **custom tooltip** that you write. Button Forge doesn't offer this.
- **Proposed**: A macro with no custom tooltip shows the tooltip of the spell or item it would
  currently use (as `#showtooltip` does), falling back to the macro's name.
- **Open**: Is a custom tooltip plain text, or does it support colors and a title line? Is it stored
  per macro (it follows the macro to any bar) or per button?
