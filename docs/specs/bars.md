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

## Templates (not in v1)

- **Decided**: v1 has only character bars and account bars. Templates are a possible future feature.
- **Why**: Live-linked templates overlapped with account bars, since both share a bar across
  characters, and raised unresolved questions (which properties follow the link, and whether the two
  concepts should merge). Revisit them if character and account bars turn out not to be enough.
