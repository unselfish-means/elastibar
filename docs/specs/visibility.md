# Visibility

Each bar has one **visibility rule** that decides when it's shown. This one mechanism covers
"show in combat", "show on a spec", and any custom rule.

## Rules

- **Decided**: A rule uses WoW's macro-conditional syntax. The first matching clause wins:

  ```
  [combat] show; hide
  [spec:2,mod:shift] show; hide
  ```

- **Decided**: There are no separate toggles for combat or spec. Presets write the rule for you, so you
  never need to learn the syntax:

| Preset | Rule |
|---|---|
| Always | `show` |
| In combat only | `[combat] show; hide` |
| Out of combat only | `[nocombat] show; hide` |
| Primary spec only | `[spec:1] show; hide` |
| Secondary spec only | `[spec:2] show; hide` |
| Custom | You write the rule |

- **Decided**: The game applies the rule, so bars show and hide in combat without breaking combat
  lockdown.
- **Decided**: If no clause matches, the bar is hidden.

## Specs on WoW: Forever

Forever uses classic three-tree talents with dual spec: **Primary** and **Secondary** tabs, each with
its own talent build. Secondary can be locked.

- `[spec:1]` means Primary and `[spec:2]` means Secondary. This is the game's own meaning.
- A bar set to "Secondary spec only" stays hidden until Secondary is unlocked. The editor says so.

## Spec names

- **Decided**: Besides numbers, you can name a talent tree: `[spec:beastmastery]`.
- **Decided**: Names and numbers can be mixed, and names work with `nospec`:
  `[spec:1/marksmanship]`, `[nospec:survival]`.
- **Decided**: A spec's tree is the tree with the most points in it.
- **Decided**: If two trees tie for the most points, or no points are spent, no named tree matches
  that spec. `[spec:1]` and `[spec:2]` still work.
- **Decided**: Names match on any unambiguous prefix, ignoring case, spaces, and punctuation.
  `beastmastery`, `beastmaster`, `beast`, and `Beast Mastery` all match Beast Mastery. An exact match
  wins over a prefix. A prefix that matches more than one tree (`f` for Fire and Frost) is flagged as
  ambiguous.
- **Decided**: Names are the ones the client shows, so a non-English client uses its own tree names.

### How it works

The game only understands `[spec:N]`, so Elastibar translates names before handing the rule to the
game:

1. **Read the trees.** For each spec, read the talent trees' names and points.
2. **Find each spec's tree.** Work out which tree has the most points.
3. **Rewrite the names.** Replace each name with the specs whose tree matches. On a Hunter whose
   Primary spec is Beast Mastery:

| You write | The game receives |
|---|---|
| `[combat,spec:beast] show; hide` | `[combat,spec:1] show; hide` |
| `[spec:marks] show; hide` | `hide` (no spec is Marksmanship) |
| `[nospec:beast] show; hide` | `[spec:2] show; hide` |
| `[spec:2/beast] show; hide` | `[spec:1/2] show; hide` |

4. **Translate again on change.** The rule is translated again whenever talents or specs change. That
   can't happen in combat, so it's always safe.

Spec names only work in bar visibility rules. A `[spec:beastmastery]` typed into an ordinary macro
goes straight to the game and won't work.

## The rule editor

This is a headline feature, because Button Forge's editor is the main thing users complain about.

- **Decided**: Guidance in the editor itself: preset buttons, and clickable snippets for common
  conditionals, so nobody has to look up the syntax.
- **Decided**: The editor never loses your work. Closing it, clicking outside it, or pressing Escape
  keeps a draft.
- **Proposed**: A live preview, updated as you type: "Right now: shown".
- **Proposed**: When spec names are translated, the editor shows the translation, e.g.
  `spec:beast → spec:1`, so a hidden bar is never a mystery.
- **Proposed**: Unknown or ambiguous spec names are flagged in the editor.
- **Proposed**: A multi-line editor (`ScrollingEditBoxTemplate`, which works on Forever).
