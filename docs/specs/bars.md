# Bars

A bar is a grid of buttons with its own position, size, layer, and visibility rule.

## Creating and deleting

- **Decided**: You can create as many bars as you want. Bars are built from Elastibar's own secure
  buttons, not the game's numbered action slots, so the game's slot count doesn't cap them.
- **Decided**: You can delete any bar.
- **Decided**: You can't create, delete, or change bars in combat (see [Platform](../platform.md#combat-lockdown)).
- **Proposed**: A new bar is 1×4, appears at the center of the screen, and opens in edit mode.
- **Decided**: Deleting a bar happens immediately, with no confirmation.

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
- **Decided**: A bar's scope is set when it's created. Changing scope afterwards is not in v1.

## Templates

- **Decided**: You can save a bar's layout and contents as a template, then add it to other characters.
- **Decided**: Templates are **live links**. Editing a linked bar on any character updates the
  template and every bar linked to it.
- **Open**: Which properties follow the link? Contents and size probably should. Position and
  visibility rule may need to differ per character (a healer and a DPS character might put the same
  bar in different places).
- **Open**: How does a linked bar differ from an account bar? Both share layout and contents across
  characters. The difference is that a linked bar is added to chosen characters and may hold class
  spells (for example, one template for all your Hunters), while an account bar appears on every
  character and holds only items and account macros. Is that the intended split, or should the two
  concepts merge?
