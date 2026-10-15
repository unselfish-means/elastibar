# Pages

A bar can hold several **pages** of buttons, each with a condition. One bar can then show heals on a
friendly target, a resurrection on a dead one, and attacks on a hostile one.

## Rules

- **Decided**: Each page has a condition and its own buttons. Pages are checked top to bottom, and the
  first page whose condition matches is shown.
- **Decided**: If no page matches, the bar shows nothing.
- **Decided**: A new bar has one page that always matches, so a bar that never uses pages works as
  before. Bars saved before pages existed get one such page holding their buttons.
- **Decided**: Every page shares the bar's size, position, scale, and layer. Only the buttons differ.
- **Decided**: The bar's [visibility rule](visibility.md) still decides whether the bar is shown at
  all. Pages decide what it shows.
- **Decided**: Pages switch in combat. The game picks the page with a state driver, and a secure
  snippet shows that page's buttons, the same way Blizzard's bars change pages.
- **Decided**: Account bars have pages too, with the same rules on what they can hold.

An example, a Priest's "Target" bar:

| Page | Condition | Holds |
|---|---|---|
| 1 | `[help,nodead]` Friendly, alive | Heals and buffs |
| 2 | `[help,dead]` Friendly, dead | Resurrection |
| 3 | `[harm,combat]` Hostile, in combat | Attacks |
| 4 | `[harm,nocombat]` Hostile, out of combat | Openers and crowd control |

The game receives `[help,nodead] 1; [help,dead] 2; [harm,combat] 3; [harm,nocombat] 4; hide`.
Spec names in conditions are translated as in visibility rules.

## Editing pages

- **Decided**: Selecting a bar in Edit Mode opens its pages: every page is shown, stacked below the
  bar, on a dark panel titled "Pages: <bar>". Each page has a label on its left saying when it shows,
  such as "2 · Friendly, dead".
- **Decided**: The game won't open the spellbook in Edit Mode, so pages can also be opened outside it:
  - **Use spellbook**, below the pages in Edit Mode, keeps that bar's pages open once Edit Mode
    closes;
  - `/eb pages <bar>` opens a bar's pages, or closes them if they're open.

  Outside Edit Mode the pages work the same way, and the page editor docks beside the panel. **Done**
  closes them, and so do entering combat and opening Edit Mode. Only one bar's pages are open at a
  time.
- **Decided**: Hidden empty slots are shown while a bar's pages are open, as in Edit Mode.
- **Decided**: You fill a page by dropping things on it, as on the bar itself. While something is on
  the cursor, the Edit Mode overlay lets drops through to the buttons.
- **Decided**: The label of the page showing right now has a gold border, so you can change target
  and see which page it picks.
- **Decided**: Below the pages, **Add page** adds an empty page and opens it in the page editor. A note
  says what happens when nothing matches ("Otherwise the bar is hidden").
- **Decided**: A page after one that always matches can never show. Its label is greyed and says
  "(never shown)", and the page editor explains why.

## The page editor

Clicking a page's label opens the page editor, docked beside the bar settings panel where the
visibility editor goes. Only one of the two is open at a time.

- **Decided**: A picker answers three questions, each applied with one click:

| Question | Answers | Writes |
|---|---|---|
| Target | Any, Friendly, Hostile, None | (nothing), `help`, `harm`, `noexists` |
| Target is | Any, Alive, Dead | (nothing), `nodead`, `dead` |
| You are | Any, In combat, Out of combat | (nothing), `combat`, `nocombat` |

  "Target is" is ignored when Target is None. All Any means the page always matches.
- **Decided**: Anything else is typed into the condition box as bracket conditions, such as
  `[help,mod:shift]` or `[harm][mod:alt]`, and applied with Enter. It's checked like a visibility
  rule; a condition with problems isn't applied. A condition the picker can't show is labelled custom,
  and picking an answer replaces it.
- **Decided**: Pages change as soon as you pick or press Enter. There's no draft or Apply, since every
  change is one click to undo.
- **Decided**: The editor also has **Move up**, **Move down**, and **Delete page**. Deleting a page is
  immediate, like deleting a bar. A bar always keeps at least one page.
- Like every bar change, editing pages is refused in combat.

## Open

- **Open**: Clicking a button on a page in Edit Mode, with nothing on the cursor, still uses it, as
  outside Edit Mode. Only the first page is under the selection overlay.
- **Open**: Pages have no names; the label is the condition's summary. Names may be worth adding if
  custom conditions turn out to be common.
