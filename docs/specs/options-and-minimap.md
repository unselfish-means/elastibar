# Options panel and minimap icon

## Options panel

- **Decided**: Elastibar has an options panel.
- **Proposed**: It's registered with Blizzard's settings window (Options › AddOns › Elastibar)
  through the `Settings` API, which exists on Forever. `/eb` with no arguments opens it.
- **Proposed** contents:
  - **General**
    - Show minimap icon.
    - Show empty buttons outside edit mode.
    - Button tooltips: always, out of combat only, or never.
    - Grid size for snapping.
  - **Bars**: a list of every bar this character sees, showing name, scope badge, size, and visibility
    preset.
    - "Character bar" and "Account bar" buttons to create new bars.
    - Per bar: edit (opens edit mode focused on that bar) and delete.
  - **Open edit mode** button.
- **Proposed**: Per-bar settings (visibility, layer, scale, rename) stay in edit mode's right-click
  menu rather than being duplicated in the panel.

## Minimap icon

- **Decided**: Elastibar has a minimap icon.
- **Proposed**: Built with the standard LibDataBroker + LibDBIcon libraries, so it also works with
  minimap-button collectors and broker displays.
- **Proposed** behavior:
  - Left-click toggles edit mode.
  - Right-click opens the options panel.
  - Dragging moves the icon around the minimap.
  - The hover tooltip shows the bar count and these hints.
- **Proposed**: The icon can be hidden from the options panel.
## Addon compartment

Forever has Blizzard's addon compartment: the "AddOns" dropdown under the calendar icon by the minimap.

- **Decided**: Elastibar is listed in the addon compartment, with the same clicks as the minimap icon.
- **Proposed**: Register it through LibDBIcon's compartment support so one LibDataBroker object drives
  both the minimap icon and the compartment entry. Two ways are confirmed to work on this client:
  - the `.toc` field `## AddonCompartmentFunc` (used by Baganator and Platynator);
  - LibDBIcon's compartment support (used by SimpleAddonManager).
- **Proposed**: The minimap icon and the compartment entry can each be hidden separately, so people
  who keep a clean minimap can rely on the compartment alone.
