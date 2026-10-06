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

-- The table a macro's tooltip lives in, by macro index. Account macros come first.
function MacroTooltips.StoreFor(index, db, charDB, maxAccountMacros)
    local owner = index <= (maxAccountMacros or 120) and db or charDB
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
    return MacroTooltips.StoreFor(index, ns.db, ns.charDB, MAX_ACCOUNT_MACROS)[name]
end

return MacroTooltips
