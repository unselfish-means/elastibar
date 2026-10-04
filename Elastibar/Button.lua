-- Button: a secure action button that holds a spell, an item, or a macro.
--
-- Content is stored as { kind = "spell", id = spellID }, { kind = "item", id = itemID },
-- or { kind = "macro", name = macroName }. Macros are stored by name because macro
-- indexes shift when macros are added or deleted.

local _, ns = ...

local Button = {}
Button.__index = Button
ns.Button = Button

-- Drop the mouse-down half of each click so a mouse click fires once, on release.
-- (Registering both halves matches what Button Forge does on this client; key-down
-- handling for keybinds comes later.)
local clickWrapper = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")

-- Report each kind of update error once, so API surprises surface without spamming.
local reported = {}
local function guard(tag, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not reported[tag] then
        reported[tag] = true
        ns.Print("|cffff8800%s update failed:|r %s", tag, tostring(err))
    end
end

local sequence = 0

function Button.Create(parent, onContentChanged)
    sequence = sequence + 1
    local name = "ElastibarButton" .. sequence
    local widget = CreateFrame("CheckButton", name, parent, "ActionButtonTemplate, SecureActionButtonTemplate")
    if widget.TextOverlayContainer then widget.TextOverlayContainer:SetFrameLevel(widget:GetFrameLevel() + 1) end
    widget.action = 10000 -- keep ActionButtonTemplate code away from real action slots

    local self = setmetatable({
        widget = widget,
        icon = _G[name .. "Icon"] or widget.icon,
        cooldown = _G[name .. "Cooldown"] or widget.cooldown,
        count = _G[name .. "Count"] or widget.Count,
        hotkey = _G[name .. "HotKey"] or widget.HotKey,
        onContentChanged = onContentChanged,
    }, Button)

    -- With pressAndHoldAction, the press runs "type" and the release runs "typerelease".
    -- The wrapper drops presses, so mouse clicks act on release via "typerelease".
    -- (Same setup as Button Forge on this client.)
    widget:SetAttribute("pressAndHoldAction", true)
    widget:RegisterForClicks("AnyUp", "AnyDown")
    widget:RegisterForDrag("LeftButton")
    clickWrapper:WrapScript(widget, "OnClick", [[ if down then return false end ]])
    -- CheckButtons toggle their checked glow on click; show "is this active" instead.
    widget:SetScript("PostClick", function() self:UpdateChecked() end)
    if self.hotkey then self.hotkey:SetText("") end

    widget:SetScript("OnReceiveDrag", function() self:ReceiveCursor() end)
    widget:SetScript("OnEnter", function() self:ShowTooltip() end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return self
end

-- Content from the cursor (spellbook, bags, macro frame).
local function contentFromCursor()
    local kind, a, b, c = GetCursorInfo()
    if kind == "spell" then
        return { kind = "spell", id = c } -- "spell", slotIndex, bookType, spellID
    elseif kind == "item" then
        return { kind = "item", id = a }
    elseif kind == "macro" then
        local name = GetMacroInfo(a)
        return name and { kind = "macro", name = name }, a
    end
    return nil, kind
end

function Button:ReceiveCursor()
    if InCombatLockdown() then
        ns.Print("Can't change buttons in combat.")
        return
    end
    local content, detail = contentFromCursor()
    if not content then
        ns.Print("Can't place '%s' on an Elastibar button yet.", tostring(detail))
        return
    end
    ClearCursor()
    self:SetContent(content)
    if self.onContentChanged then self.onContentChanged(self, content) end
end

-- Must run out of combat: it changes secure attributes.
function Button:SetContent(content)
    self.content = content
    local w = self.widget
    local function setType(kind)
        w:SetAttribute("type", kind)
        w:SetAttribute("typerelease", kind)
    end
    setType(nil)
    w:SetAttribute("spell", nil)
    w:SetAttribute("item", nil)
    w:SetAttribute("macro", nil)
    if content and content.kind == "spell" then
        setType("spell")
        w:SetAttribute("spell", content.id)
    elseif content and content.kind == "item" then
        setType("item")
        w:SetAttribute("item", "item:" .. content.id)
    elseif content and content.kind == "macro" then
        local index = GetMacroIndexByName(content.name)
        if index and index > 0 then
            setType("macro")
            w:SetAttribute("macro", index)
        end
    end
    self:Update()
end

-- The spell whose cooldown/usability a button should show (macros show their current spell).
function Button:DisplaySpell()
    local c = self.content
    if not c then return nil end
    if c.kind == "spell" then return c.id end
    if c.kind == "macro" then
        local index = GetMacroIndexByName(c.name)
        return index and index > 0 and GetMacroSpell(index) or nil
    end
end

function Button:UpdateIcon()
    local c, texture = self.content, nil
    if c and c.kind == "spell" then
        texture = C_Spell.GetSpellTexture(c.id)
    elseif c and c.kind == "item" then
        texture = C_Item.GetItemIconByID(c.id)
    elseif c and c.kind == "macro" then
        local index = GetMacroIndexByName(c.name)
        if index and index > 0 then texture = select(2, GetMacroInfo(index)) end
    end
    self.icon:SetTexture(texture)
    self.icon:SetShown(texture ~= nil)
end

-- In combat, cooldown numbers are "secret": addon code can't pass them to SetCooldown.
-- Spells use a duration object instead, which the cooldown frame accepts as-is.
local itemSecretLogged = false

function Button:UpdateCooldown()
    local c, spellID = self.content, self:DisplaySpell()
    if spellID then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then
            self.cooldown:SetCooldownFromDurationObject(duration)
        else
            self.cooldown:Clear()
        end
    elseif c and c.kind == "item" then
        local start, duration, enable = C_Item.GetItemCooldown(c.id)
        if issecretvalue and issecretvalue(start) then
            -- No item duration API on this client; record what we see and leave the swipe as is.
            if not itemSecretLogged then
                itemSecretLogged = true
                ns.Log("item cooldown values are secret in combat; swipe left unchanged")
            end
            return
        end
        if enable then
            self.cooldown:SetCooldown(start, duration)
        else
            self.cooldown:Clear()
        end
    else
        self.cooldown:Clear()
    end
end

function Button:UpdateCount()
    local c = self.content
    local text = ""
    if c and c.kind == "item" then
        local n = C_Item.GetItemCount(c.id)
        if n and n > 1 then text = tostring(n) end
    end
    if self.count then self.count:SetText(text) end
end

-- Dim unusable buttons and tint out-of-range ones red.
function Button:UpdateUsable()
    local c, usable, inRange = self.content, true, nil
    local spellID = self:DisplaySpell()
    if spellID then
        usable = C_Spell.IsSpellUsable(spellID)
        inRange = C_Spell.IsSpellInRange(spellID, "target")
    elseif c and c.kind == "item" then
        usable = C_Item.IsUsableItem(c.id)
        -- IsItemInRange is protected in combat on this client (calling it is a blocked action).
        if not InCombatLockdown() then inRange = C_Item.IsItemInRange(c.id, "target") end
    end
    if inRange == false then
        self.icon:SetVertexColor(0.8, 0.1, 0.1)
    elseif usable then
        self.icon:SetVertexColor(1, 1, 1)
    else
        self.icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

function Button:UpdateChecked()
    local spellID = self:DisplaySpell()
    local active = spellID and (C_Spell.IsCurrentSpell(spellID) or C_Spell.IsAutoRepeatSpell(spellID))
    self.widget:SetChecked(active and true or false)
end

function Button:Update()
    guard("checked", self.UpdateChecked, self)
    guard("icon", self.UpdateIcon, self)
    guard("cooldown", self.UpdateCooldown, self)
    guard("count", self.UpdateCount, self)
    guard("usable", self.UpdateUsable, self)
end

function Button:ShowTooltip()
    local c = self.content
    if not c then return end
    GameTooltip:SetOwner(self.widget, "ANCHOR_RIGHT")
    if c.kind == "spell" then
        GameTooltip:SetSpellByID(c.id)
    elseif c.kind == "item" then
        GameTooltip:SetItemByID(c.id)
    else
        -- Custom macro tooltips come later; for now show the macro's name.
        GameTooltip:SetText(c.name)
        GameTooltip:AddLine("Macro", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end
