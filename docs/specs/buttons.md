# Buttons

Each button holds one spell, item or toy, macro, pet action, mount, or battle pet.

## Placing things on buttons

- **Decided**: You can place spells, items, and macros by dragging them from the spellbook, your
  bags, or the macro window onto a button.
- **Decided**: You can place **pet actions** by dragging them from the pet bar or the pet spellbook.
  A pet action dragged from the spellbook must also be on the pet bar; otherwise Elastibar says
  to put it there first.
  - A pet action button **mirrors a pet bar slot**: it shows and uses whatever is in that slot,
    so it follows the pet you have out. This is the only way to include pet commands (Attack,
    Follow, Stay, stances), which aren't spells.
  - It shows the slot's icon, cooldown, usability, range, and active state (for example, the
    current stance), and the pet action's own tooltip.
  - **Decided**: With no pet summoned, the button still shows the last icon seen in that slot,
    greyed out, and its tooltip names the action and says the pet isn't summoned.
  - **Open**: Should right-clicking toggle autocast, as on Blizzard's pet bar? Right now
    right-click uses the action, and autocast isn't shown.
- **Decided**: Account bars accept only items (including toys), mounts, battle pets, and account macros (see [Bars](bars.md#character-and-account-bars)). Anything else is refused with a message and stays on the cursor.
  Pet actions are class-specific, so they're character-bar only, like spells.
- **Decided**: Buttons can't be changed in combat.
- **Proposed**: Macros are stored by name, not by index, because macro indexes shift when macros
  are added or deleted. If a macro is deleted, its button shows as empty but remembers the name, so
  recreating the macro restores it.
- **Decided**: **Shift-drag** picks up what a button holds, which empties the button. Then:
  - dropping it on another Elastibar button moves it there;
  - dropping it on a Blizzard action bar places it there (the game handles this);
  - dropping it anywhere else deletes it.
  - Shift-drag works outside Edit Mode, and is refused in combat.
- **Decided**: Dropping onto a button that already holds something swaps the two, as Blizzard's
  bars do: the old contents go onto the cursor.
- **Decided**: Clicking a button while holding something places it there (as on Blizzard's bars),
  without using the button's action. This is how you place what a swap left on the cursor.
  Out of combat only.
- **Decided**: Mounts, toys, and battle pets count as items: they can go on any bar, including account bars.
  - Mounts are cast by name (`/cast <mount>`), show the mount spell's icon, cooldown, and usability, and glow while you ride them. The mount journal's "Summon Random Favorite Mount" isn't supported yet.
  - Battle pets are summoned with `/summonpet` and glow while summoned.
  - Toys use the secure "toy" action, since they aren't in your bags.
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
