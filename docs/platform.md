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
  - Blizzard's selection overlay (`EditModeSystemSelectionTemplate`) works on addon frames, but its
    default scripts assume a Blizzard Edit Mode system (`self.system`) and error on hover. Replace
    its `OnEnter`, `OnLeave`, `OnMouseDown`, and drag scripts.
- **`ActionButtonTemplate` buttons are natively 45px.** Lay bars out on a 45px grid with a 2px gap
  (the same values Button Forge uses) and size them with scale, not by resizing buttons.
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
- **Secret values (as in Retail 12.x).** In combat, cooldown APIs return "secret" values that addon
  code can't use: `Cooldown:SetCooldown` fails with "Secret values are only allowed during untainted
  execution". The secret-safe path exists on Forever:
  - `C_Spell.GetSpellCooldownDuration(spellID)` returns a duration object, which goes to
    `Cooldown:SetCooldownFromDurationObject`. `C_Spell.GetSpellChargeDuration` and
    `C_ActionBar.Get*Duration` also exist.
  - There's **no item equivalent** (`C_Item` has no `*Duration` functions). Whether item cooldowns are
    secret in combat is being checked; the spike logs it.
  - `issecretvalue`, `C_Secrets.Should*BeSecret`, and `C_DurationUtil.CreateDuration` exist.
- **`C_Item.IsItemInRange` is protected in combat.** Calling it is a blocked action ("Interface action
  failed because of an AddOn"), so item range can only be checked out of combat.
- **Hooking Blizzard Edit Mode doesn't taint**: `EventRegistry` callbacks, `hooksecurefunc` on
  `EditModeManagerFrame`, `ClearSelectedSystem`, and Blizzard's selection overlay on our frame produced
  no taint and no errors across an Edit Mode session, a layout save, and combat.
- **Taint debugging**:
  - The `taintLog` CVar resets on every reload on this client.
  - `/console` is broken in the beta's chat code. Set the CVar with `SetCVar("taintLog", "1")` after
    login (`/eb taintlog` in the spike); the log is written to `Logs\taint.log`.
  - **While `taintLog` is on, this beta throws unrelated Blizzard errors**: chat errors on XP
    messages, `BuffFrame` errors in combat and when closing Edit Mode, and possibly the Edit Mode
    `LootFrame` error on exit. All of them stopped once the spike stopped turning `taintLog` on, with
    every other addon (including MoveAny) enabled. Turn it on only while hunting taint.
  - The taint log also named MoveAny for secret-value reads in its own code. Those happened at the
    same moments as the `BuffFrame` errors, but the errors went away with MoveAny still enabled, so
    the taint logging itself was the cause.
- **Unrelated noise**: Details_RaidCheck errors on a missing library (`LibOpenRaid-1.0`); they stop
  when Details' raid plugin is disabled. Check `Logs\taint.log` for which addon is named before
  chasing an error.
- **Unknown macro conditionals are reported**: `SecureCmdOptionParse` prints "Unknown macro option:
  X" to chat for a conditional the client doesn't know, while still evaluating it as false (and its
  `no` form as true). None of the 29 conditionals the probe checks triggered it, so all are valid
  on Forever: `combat`, `spec`, `mod`, `group`, `mounted`, `flying`, `flyable`, `advflyable`,
  `swimming`, `indoors`, `outdoors`, `resting`, `stealth`, `form`, `stance`, `pet`, `dead`,
  `channeling`, `vehicleui`, `overridebar`, `possessbar`, `petbattle`, `bonusbar`, `actionbar`,
  `known`. The visibility editor can use the same message to flag typos.
- **Secure action buttons need `typerelease`.** With `pressAndHoldAction` set, the press runs `type`
  and the release runs `typerelease`. Elastibar (like Button Forge) drops presses so a mouse click
  acts once, on release, so both attributes must be set or clicks do nothing.
- **The cursor doesn't identify pet actions.** For `"petaction"`, `GetCursorInfo` returns spellbook
  positions (for example `2, 4` or `0, 15`), not pet bar slots. Watch the pickup calls with
  `hooksecurefunc` instead: `PickupPetAction(slot)` from the pet bar, and
  `C_SpellBook.PickupSpellBookItem(index, bank)` from the spellbook (then
  `C_SpellBook.GetSpellBookItemInfo` for the spell ID and name). Match pet commands such as Attack by
  name, since they have no spell ID.
- **`ActionButtonTemplate` is a CheckButton**, so clicks toggle its checked glow. Set it from
  `C_Spell.IsCurrentSpell` / `IsAutoRepeatSpell` after each click and on
  `CURRENT_SPELL_CAST_CHANGED`.

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
  lua tests/barstore_test.lua
  lua tests/grid_test.lua
  lua tests/ruleediting_test.lua
  ```

- **Probe**: `ElastibarProbe` records APIs, templates, conditionals, and talent data per build in
  `WTF\Account\<account>\SavedVariables\ElastibarProbe.lua`. Re-run it after beta patches and diff
  the results.
- **GitHub account**: the repo is `unselfish-means/elastibar`. Git pushes as unselfish-means through
  a repo-local credential helper in `.git/config`, so the active `gh` account doesn't matter for git.
  `gh` commands do need the token set first: `$env:GH_TOKEN = gh auth token -u puppysnuff`.
