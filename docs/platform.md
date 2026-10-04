# Platform

Facts about WoW: Forever that shape Elastibar, and how to develop against it.

## WoW: Forever API

Measured with the `ElastibarProbe` dev addon on beta build **1.60.1.70205** (`WOW_PROJECT_ID` 18,
toc `16001`):

- **The client exposes the modern Retail API.** Legacy globals such as `GetSpellInfo`, `GetItemInfo`,
  `PickupSpell`, `GetSpecialization`, `EasyMenu`, and `InterfaceOptions_AddCategory` are **gone**.
  Use `C_Spell`, `C_Item`, `C_Container`, `Settings`, and `MenuUtil`.
- **All the templates Elastibar needs work**: `SecureActionButtonTemplate`, `ActionButtonTemplate`, the
  `SecureHandler*` templates, `CooldownFrameTemplate`, `BackdropTemplate`, and `ScrollingEditBoxTemplate`.
- **All eight frame stratas work**, and frame levels go up to 10000.
- **Blizzard Edit Mode exists**: `EditModeManagerFrame` and `C_EditMode`.
- **Spell overlay glow** uses `ActionButtonSpellAlertManager`; `ActionButton_ShowOverlayGlow` is gone.
- **Macros**: `MAX_ACCOUNT_MACROS` is nil at login (it's defined by the load-on-demand macro UI).
  Account macros are indexes 1–120 and character macros are 121 and up; the spike confirmed this.
- **Specs**: `C_SpecializationInfo.GetSpecializationInfo(1)` returns the *class* ("Hunter", ID 1485),
  not a talent tree. `GetTalentTabInfo` is gone. Talent trees come from the trait system:
  - `C_SpecializationInfo.GetCombatConfigIDForSpecGroup(n)` gives the talent config for spec `n`
    (nil when that spec is locked).
  - `C_Traits.GetGroupDisplayInfoByTreeID(treeID)` names the three columns (`displayName`, `groupID`,
    `orderIndex`, and a language-independent `skillLineID`).
  - Each node lists its `groupIDs`; summing `ranksPurchased` by group gives points per tree.
- **Macro conditionals can't be detected statically.** An unknown conditional reads as false, and its
  `no` form as true, so they have to be tested in play.

Verified by the 2×2 spike (2026-10-03), with no errors including in combat:

- custom secure buttons for spells, items, and macros (drag and drop, clicks, tooltips);
- cooldown, item count, usability, and range display;
- moving a bar and saving its position;
- spec-name translation and visibility rules applied through `RegisterStateDriver`.

Not yet verified:

- whether `[spec:2]` turns true after switching to an unlocked Secondary spec;
- whether a Secondary spec's talent config is readable while Primary is active.

## Combat lockdown

The game blocks addons from changing secure frames in combat. In combat, Elastibar can't:

- create, delete, move, or resize bars;
- change what a button holds;
- change a visibility rule.

What still works in combat: buttons can be clicked, cooldowns and range update, and visibility rules
show and hide bars, because the game applies them. Changes requested in combat are refused with a
message. Internal updates, such as re-translating a rule, are queued until combat ends.

## Development

- **Deploy**: `scripts/deploy.ps1` links every addon folder (a folder containing a matching `.toc`)
  into the beta client's `Interface\AddOns`. Edits are live after `/reload`.
- **Tests**: pure-Lua logic has standalone tests. Run them with any Lua 5.1-compatible interpreter
  from the repo root:

  ```
  lua tests/conditionals_test.lua
  ```

- **Probe**: `ElastibarProbe` records APIs, templates, conditionals, and talent data per build in
  `WTF\Account\<account>\SavedVariables\ElastibarProbe.lua`. Re-run it after beta patches and diff
  the results.
