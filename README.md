# Elastibar

**Extra action bars you can stretch, place, and show on your own rules.** Make as many bars as you
need, size them by dragging their edges in Blizzard's Edit Mode, and decide exactly when each one
appears, without having to learn macro syntax.

Built for **WoW: Forever (Classic Plus)**. Elastibar is in **beta**: it works, but expect changes
between versions, and please report anything that misbehaves.

## What it does

- **As many bars as you want.** Each bar is a grid of up to 12 × 12 buttons. Bars use their own
  buttons, so they don't take up the game's action slots.
- **Character bars and account bars.** A character bar belongs to the character that made it. An
  account bar appears on every character, with the same layout and contents: good for your
  hearthstone, food, mounts, toys, and account-wide macros.
- **Lives in Edit Mode.** Open Blizzard's Edit Mode and your bars unlock alongside Blizzard's own
  frames. Drag a bar to move it, and drag its right edge, bottom edge, or corner to add or remove
  buttons. Bars snap to a grid; hold **Shift** while dragging to place one freely.
- **Bar settings.** Select a bar in Edit Mode to set its scale (50–200%), columns, rows, and layer
  (behind other UI, normal, above it, or on top). You can also hide empty slots, rename the bar,
  or delete it.
- **Holds anything you'd put on an action bar.** Spells, items, toys, macros, mounts, battle pets,
  and pet actions such as Attack and Follow. Drag them on from your spellbook, bags, macro window, or
  pet bar. Shift-drag a button to pick its contents up. Buttons show cooldowns, item counts, and
  range, just like Blizzard's. A macro's range follows whoever it would cast on, so
  `[mod:alt,@player]` isn't shown out of range while you hold Alt.

## Show bars only when you need them

Every bar has a **visibility rule**, and the rule editor makes it painless:

- **One-click presets**: Always, In combat only, Out of combat only, Primary spec only, and
  Secondary spec only.
- **Clickable snippets** for combat, mounted, stealth, your target, modifier keys, and your specs,
  each with a tooltip explaining what it does. Click a few and the editor writes the rule for you,
  for example `[combat,mod:shift] show; hide`.
- **A live preview** that tells you whether the bar would be shown right now, before you apply
  anything.
- **Never lose an edit.** Your draft is kept when you close the editor, press Escape, or reload
  your UI. Nothing changes until you press **Apply**, and **Revert** goes back to the rule you had.
- **Spec names.** Write `[spec:beast]` instead of remembering which spec number is which. Elastibar
  works out which of your specs uses that talent tree.

Rules use WoW's own macro conditions, so the game shows and hides your bars in combat without any
errors.

## Your own macro tooltips

Write a tooltip for any macro, such as "Hold Shift for Frost Trap", in the **Elastibar tooltip**
box that opens beside Blizzard's macro window (`/macro`).

- It shows when you hover the macro on an Elastibar bar **and** on Blizzard's own action bars,
  together with the tooltip of the spell or item the macro would use.
- Choose whether your text goes **above** (the default) or **below** the game's tooltip. A thin
  green line separates the two.
- An account macro's tooltip is shared by all your characters, and a character macro's belongs to
  that character. Your text is saved as you type.

## Options

Open **Options › AddOns › Elastibar**, or type `/eb`. One page holds:

- **Button tooltips**: always, out of combat only, or never.
- **Macro tooltip text**: above or below the game's tooltip.
- **Snapping grid** size for moving bars in Edit Mode.
- **Your bars**: every bar this character sees, with buttons to edit (opens Edit Mode with that
  bar selected) or delete it, and to create a new character or account bar.

## Commands

`/eb` and `/elastibar` do the same thing.

| Command | What it does |
|---|---|
| `/eb` | Open the options |
| `/eb list` | List your bars with their numbers |
| `/eb new [account] [name]` | Create a character bar, or an account bar |
| `/eb rename <bar> <name>` | Rename a bar |
| `/eb delete <bar>` | Delete a bar (there's no confirmation) |
| `/eb vis <bar> [rule]` | Show or set a bar's visibility rule |
| `/eb grid [px]` | Show or set the snapping grid size |

For `<bar>`, use its number from `/eb list` or a one-word bar name.

## Good to know

- Bars can't be created, changed, or deleted in combat. That's a game rule for action buttons.
- Deleting a bar is immediate. Its buttons and settings are gone.
- A macro's tooltip is tied to the macro's name, so renaming the macro leaves the tooltip behind.
