# Options panel and minimap icon

## Options panel

- **Decided**: Elastibar has an options panel.
- **Decided**: It's registered with Blizzard's settings window (Options › AddOns › Elastibar)
  through the `Settings` API, which exists on Forever. `/eb` with no arguments opens it.
- **Decided** contents:
  - **General**
    - Show minimap icon.
    - Show in addon compartment.
    - (Showing or hiding empty slots is a per-bar setting in Edit Mode; see the layout spec.)
    - Show macro tooltip text: always, out of combat only, or never. This is Elastibar's custom
      text only, on Elastibar and Blizzard bars; the game's own tooltip always shows.
      - Changed after in-game testing: it was "Button tooltips", which hid the whole tooltip.
    - Macro tooltip text goes above (default) or below the game's tooltip. The same setting as
      in the tooltip box beside the macro window (see the buttons spec).
    - Grid size for snapping.
  - **Bars**: a list of every bar this character sees, showing name, scope badge, size, and visibility
    preset.
    - "Character bar" and "Account bar" buttons to create new bars.
    - Per bar: edit (opens edit mode focused on that bar) and delete.
  - **Open edit mode** button.
- **Decided**: Per-bar settings (visibility, layer, scale, size, rename) stay in Edit Mode's bar settings
  panel rather than being duplicated in the options panel.
- **Decided**: It's **one page**: General, then Bars. The bar list scrolls when it's long.
  - Settings are saved as soon as they change; there's no Okay or Apply.
  - The bar list shows each bar's name, a Character or Account badge, columns × rows, and its
    visibility preset name (or Custom).
  - **Edit** closes the settings window, opens Edit Mode, and selects that bar, so its settings
    panel opens. **Open Edit Mode** does the same with nothing selected. Neither works in combat.
  - **Delete** is immediate, with no confirmation, as everywhere else.
  - **New character bar** and **New account bar** create a bar with the next free name.
- **Decided**: The minimap icon and addon compartment checkboxes are added with the icon itself
  (the next build step), not before.

## Minimap icon

- **Decided**: Elastibar has a minimap icon.
- **Decided**: Built with the standard LibDataBroker + LibDBIcon libraries, so it also works with
  minimap-button collectors and broker displays.
- **Decided** behavior:
  - Left-click toggles edit mode.
  - Right-click opens the options panel.
  - Dragging moves the icon around the minimap.
  - The hover tooltip shows the bar count and these hints.
- **Decided**: The icon can be hidden from the options panel (see the addon compartment below).

## Addon compartment

Forever has Blizzard's addon compartment: the "AddOns" dropdown under the calendar icon by the minimap.

- **Decided**: Elastibar is listed in the addon compartment, with the same clicks as the minimap icon.
- **Decided**: It's registered through LibDBIcon's compartment support, so one LibDataBroker object
  drives both the minimap icon and the compartment entry. Two ways are confirmed to work on this
  client:
  - the `.toc` field `## AddonCompartmentFunc` (used by Baganator and Platynator);
  - LibDBIcon's compartment support (used by SimpleAddonManager). This is the one Elastibar uses.
- **Decided**: The minimap icon and the compartment entry can each be hidden separately in the
  options panel, so people who keep a clean minimap can rely on the compartment alone.
