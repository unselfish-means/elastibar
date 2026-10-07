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

-- Where custom text goes relative to the game's tooltip: "above" (the default) or "below".
-- One setting for every macro, account-wide.
function MacroTooltips.Position()
    return ns.db and ns.db.macroTooltipPosition or "above"
end

function MacroTooltips.SetPosition(position)
    ns.db.macroTooltipPosition = position
end

local R, G, B = 0.61, 1, 0.69 -- the custom text and its separator bar

-- A 1px bar in the custom text's color, drawn across a blank line. Hidden again, and the line
-- fonts put back, whenever the tooltip is cleared.
local function separator(tooltip)
    if not tooltip.ElastibarSeparator then
        local bar = tooltip:CreateTexture(nil, "ARTWORK")
        bar:SetColorTexture(R, G, B, 0.8)
        bar:SetHeight(1)
        tooltip.ElastibarSeparator = bar
        tooltip:HookScript("OnTooltipCleared", function(self)
            self.ElastibarSeparator:Hide()
            if self.ElastibarTitleLine then
                local name = self:GetName()
                _G[name .. "TextLeft1"]:SetFontObject(GameTooltipHeaderText)
                _G[name .. "TextLeft" .. self.ElastibarTitleLine]:SetFontObject(GameTooltipText)
                self.ElastibarTitleLine = nil
            end
        end)
    end
    return tooltip.ElastibarSeparator
end

-- Draws the bar across blank line n. Runs after Show, once the tooltip's width is known.
local function placeSeparator(tooltip, n)
    local bar = separator(tooltip)
    bar:ClearAllPoints()
    bar:SetPoint("LEFT", _G[tooltip:GetName() .. "TextLeft" .. n], "LEFT", 0, 0)
    bar:SetWidth(tooltip:GetWidth() - 20)
    bar:Show()
end

-- The tooltip's lines as { left, leftColor, right, rightColor }, or nil if any text is secret
-- (in combat), which can't be read back.
local function snapshot(tooltip)
    local name, lines = tooltip:GetName(), {}
    for i = 1, tooltip:NumLines() do
        local left, right = _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
        local l = left:GetText()
        local r = right and right:IsShown() and right:GetText() or nil
        if issecretvalue and (issecretvalue(l) or issecretvalue(r)) then return nil end
        lines[i] = { l or " ", { left:GetTextColor() }, r, r and { right:GetTextColor() } }
    end
    return lines
end

-- Adds a macro's text to whatever the tooltip shows, above or below it, with a bar between.
-- A tooltip can only grow at the bottom, so "above" reads the lines back, clears the tooltip,
-- and adds them again after the text. If they can't be read, the text goes below.
function MacroTooltips.AddTo(tooltip, name)
    local text = MacroTooltips.Get(name)
    if not text then return end
    local lines = MacroTooltips.Position() == "above" and snapshot(tooltip)
    if not lines then
        tooltip:AddLine(" ")
        local gap = tooltip:NumLines()
        tooltip:AddLine(text, R, G, B, true)
        tooltip:Show()
        placeSeparator(tooltip, gap)
        return
    end

    tooltip:ClearLines()
    tooltip:AddLine(text, R, G, B, true)
    tooltip:AddLine(" ")
    local gap = tooltip:NumLines()
    for _, line in ipairs(lines) do
        local lc, rc = line[2], line[4]
        if line[3] then
            tooltip:AddDoubleLine(line[1], line[3], lc[1], lc[2], lc[3], rc[1], rc[2], rc[3])
        else
            tooltip:AddLine(line[1], lc[1], lc[2], lc[3], true)
        end
    end
    -- The first line always gets the title font: give it back to the game's own title.
    local tooltipName = tooltip:GetName()
    _G[tooltipName .. "TextLeft1"]:SetFontObject(GameTooltipText)
    _G[tooltipName .. "TextLeft" .. (gap + 1)]:SetFontObject(GameTooltipHeaderText)
    tooltip.ElastibarTitleLine = gap + 1
    tooltip:Show()
    placeSeparator(tooltip, gap)
end

-- Blizzard's action bars show a macro with GameTooltip:SetAction. A post-hook adds the text
-- there too, without touching the secure buttons.
if GameTooltip and hooksecurefunc then
    hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
        if GetActionInfo(slot) == "macro" then MacroTooltips.AddTo(tooltip, GetActionText(slot)) end
    end)
end

return MacroTooltips
