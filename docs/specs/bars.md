# Bars

A bar is a grid of buttons with its own position, size, layer, and visibility rule.

## Creating and deleting

- **Decided**: You can create as many bars as you want. Bars are built from Elastibar's own secure
  buttons, not the game's numbered action slots, so the game's slot count doesn't cap them.
- **Decided**: You can delete any bar.
- **Decided**: You can't create, delete, or change bars in combat (see [Platform](../platform.md#combat-lockdown)).
- **Proposed**: A new bar is 1×4, appears at the center of the screen, and opens in edit mode.
- **Open**: Should deleting a bar ask for confirmation, or offer undo?

## Character and account bars

Every bar has a scope, shown as a badge on its label in edit mode.

| | Character bar | Account bar |
|---|---|---|
| Visible on | The character that created it | Every character on the account |
| Layout (position, size, layer, visibility) | Per character | Shared |
| Contents | Spells, items, any macro | Items and account macros only |

- **Decided**: Account bars share both layout and contents.
- **Decided**: Dropping a class spell or a character macro on an account bar is rejected with a short
  message ("Account bars hold items and account macros"). There's no allowlist.
- **Why**: Account bars are for things every character has, such as a hearthstone, food, and shared
  macros. A Mage's Frostbolt makes no sense on a Warrior.
- **Open**: Can a bar change scope after it's created? Changing a character bar to an account bar
  would have to drop any spells and character macros it holds.

## Templates

- **Decided**: You can save a bar's layout and contents as a template, then stamp it onto another
  character as a new character bar.
- **Open**: Is a template a live link (edit once, update everywhere) or a one-time copy? A one-time
  copy is simpler and is the proposed default.
