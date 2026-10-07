-- Custom macro tooltips: plain text you write for a macro, shown when you hover it on a bar.
--
-- Stored by macro name, where the macro lives: account macros in ElastibarDB, character macros
-- in ElastibarCharDB. Like Elastibar's macro buttons, a tooltip follows the macro's name, so
-- renaming a macro leaves its tooltip behind.
--
-- The storage functions are pure Lua, so tests/macrotooltips_test.lua can run them standalone.

local _, ns = ...
ns = ns or {}

local MacroTooltips = {}
ns.MacroTooltips = MacroTooltips

MacroTooltips.MAX_LENGTH = 500

-- Account macros come first, then character macros. MAX_ACCOUNT_MACROS isn't defined on
-- WoW: Forever; its macro list uses 120 account slots, like Retail.
function MacroTooltips.IsAccountMacro(index, maxAccountMacros)
    return index <= (maxAccountMacros or MAX_ACCOUNT_MACROS or 120)
end

-- The table a macro's tooltip lives in, by macro index.
function MacroTooltips.StoreFor(index, db, charDB, maxAccountMacros)
    local owner = MacroTooltips.IsAccountMacro(index, maxAccountMacros) and db or charDB
    owner.macroTooltips = owner.macroTooltips or {}
    return owner.macroTooltips
end

-- Saves text for a macro. Surrounding blank lines and spaces are dropped; empty text removes it.
function MacroTooltips.Set(store, name, text)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    store[name] = text ~= "" and text:sub(1, MacroTooltips.MAX_LENGTH) or nil
end

-- The tooltip text for a macro name, or nil. Uses the game's macro list.
function MacroTooltips.Get(name)
    local index = name and GetMacroIndexByName(name)
    if not index or index == 0 then return nil end
    return MacroTooltips.StoreFor(index, ns.db, ns.charDB)[name]
end

-- Adds a macro's text under whatever the tooltip already shows, after a blank line.
function MacroTooltips.AddTo(tooltip, name)
    local text = MacroTooltips.Get(name)
    if not text then return end
    tooltip:AddLine(" ")
    tooltip:AddLine(text, 0.61, 1, 0.69, true)
    tooltip:Show()
end

-- Blizzard's action bars show a macro with GameTooltip:SetAction. A post-hook adds the text
-- there too, without touching the secure buttons.
if GameTooltip and hooksecurefunc then
    hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
        if GetActionInfo(slot) == "macro" then MacroTooltips.AddTo(tooltip, GetActionText(slot)) end
    end)
end

return MacroTooltips
