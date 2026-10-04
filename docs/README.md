# Elastibar

Extra action bars for **WoW: Forever** (Blizzard's "Classic Plus" flavor, toc `16001`) that you can
stretch, place, and show on your own rules.

## Why

Inspired by Button Forge, which already does
custom bars but:

- is no longer maintained (it only runs on Forever with a hand-edited `.toc`);
- has no custom tooltips for macros;
- makes visibility rules painful: no guidance in the UI, and the dialog closes easily and loses edits;
- looks dated next to modern addons such as QuestMaster.

Elastibar is not a Button Forge clone. Its differentiators are the **visibility editor**, **modern
visuals**, **custom macro tooltips**, and **account-wide bars**.

## Specs

| Spec | Covers |
|---|---|
| [Bars](specs/bars.md) | Creating, deleting, character vs account bars |
| [Layout and edit mode](specs/layout-and-edit-mode.md) | Edge-drag resize, moving, grid snapping, layers, bar settings panel |
| [Buttons](specs/buttons.md) | Spells, items, macros; tooltips; custom macro tooltips |
| [Visibility](specs/visibility.md) | Visibility rules, presets, spec names, the rule editor |
| [Options and minimap](specs/options-and-minimap.md) | Options panel, minimap icon |
| [Platform](platform.md) | WoW: Forever API facts, combat lockdown, dev workflow |

Each requirement is tagged:

- **Decided**: agreed; build it this way.
- **Proposed**: a suggested default that hasn't been confirmed yet.
- **Open**: needs a decision.

## Not in v1

- **Keybinds**: next version.
- **Changing a bar's scope** (character ↔ account) after it's created.
- **Formatted custom macro tooltips**: plain text is proposed for v1.
- **Class spells and character macros on account bars**: rejected on drop for now.
- **Flyouts and stance buttons.** (Pet actions were added to v1.)
- **Masque skinning.**
- **Bar templates and profiles**: v1 has character and account bars only.
