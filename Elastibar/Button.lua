-- Button: a secure action button that holds a spell, an item or toy, a macro, a pet action,
-- a mount, or a battle pet.
--
-- Content is stored as { kind = "spell", id = spellID }, { kind = "item", id = itemID },
-- { kind = "macro", name = macroName }, { kind = "petaction", slot = petBarSlot },
-- { kind = "mount", id = mountID, spellID = ... }, or { kind = "battlepet", guid = petGUID }.
-- Macros are stored by name because macro indexes shift when macros are added or deleted.
-- Toys are items; they're used with the secure "toy" action since they aren't in your bags.

local _, ns = ...

local Button = {}
Button.__index = Button
ns.Button = Button

local RANDOM_FAVORITE_MOUNT_ID = 268435455 -- the mount journal's "Summon Random Favorite Mount"

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

-- accepts(content, macroIndex) decides what the button's bar may hold (account bars refuse
-- some kinds); nil accepts everything.
function Button.Create(parent, onContentChanged, accepts)
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
        accepts = accepts,
    }, Button)

    -- With pressAndHoldAction, the press runs "type" and the release runs "typerelease".
    -- The wrapper drops presses, so mouse clicks act on release via "typerelease".
    -- (Same setup as Button Forge on this client.)
    widget:SetAttribute("pressAndHoldAction", true)
    widget:RegisterForClicks("AnyUp", "AnyDown")
    widget:RegisterForDrag("LeftButton")
    clickWrapper:WrapScript(widget, "OnClick", [[ if down then return false end ]])
    -- Clicking a button while holding something places it (as on Blizzard's bars), e.g. the
    -- contents a swap put on the cursor. Before the click, switch the button's action off so
    -- the click doesn't also use it; after, place the cursor contents. Out of combat only:
    -- attributes can't change in combat. (Button Forge does the same on this client.)
    widget:SetScript("PreClick", function(_, _, down)
        if down or InCombatLockdown() or not GetCursorInfo() then return end
        self.placing = true
        widget:SetAttribute("type", nil)
        widget:SetAttribute("typerelease", nil)
    end)
    widget:SetScript("PostClick", function()
        if self.placing then
            self.placing = false
            -- Nothing placed (refused, or this release was already handled as a drop):
            -- restore the button's own action, which PreClick switched off.
            if not self:ReceiveCursor() then self:SetContent(self.content) end
        end
        -- CheckButtons toggle their checked glow on click; show "is this active" instead.
        self:UpdateChecked()
    end)
    if self.hotkey then self.hotkey:SetText("") end

    widget:SetScript("OnReceiveDrag", function() self:ReceiveCursor() end)
    -- Shift-drag picks the contents up off the button (decided in docs/specs/buttons.md).
    widget:SetScript("OnDragStart", function()
        if IsShiftKeyDown() then self:PickUp() end
    end)
    widget:SetScript("OnEnter", function() self:ShowTooltip() end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return self
end

-- Pet action buttons mirror a pet bar slot, so what they show changes with the pet.
-- Tokens (Attack, Follow, Stay, ...) return global string names instead of a name and texture.
local function petInfo(slot)
    local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID, checksRange, inRange =
        GetPetActionInfo(slot)
    if not name then return nil end
    return {
        name = isToken and _G[name] or name,
        texture = isToken and _G[texture] or texture,
        isActive = isActive,
        autoCastEnabled = autoCastEnabled,
        spellID = spellID,
        inRange = checksRange and inRange or nil,
    }
end

-- What was last picked up, from the pet bar or the spellbook. The cursor's own values for
-- a pet action are spellbook positions on this client, not pet bar slots, so watch the
-- pickup calls instead (hooksecurefunc is taint-safe):
--   - the pet bar calls PickupPetAction(slot)
--   - the spellbook calls C_SpellBook.PickupSpellBookItem(index, bank)
local picked
hooksecurefunc("PickupPetAction", function(slot) picked = { slot = slot } end)
if C_SpellBook and C_SpellBook.PickupSpellBookItem then
    hooksecurefunc(C_SpellBook, "PickupSpellBookItem", function(index, bank)
        local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, index, bank)
        picked = ok and type(info) == "table" and { spellID = info.spellID, name = info.name } or nil
    end)
end

-- The pet bar slot for a pet action on the cursor: the picked-up pet bar slot, else the
-- slot holding the picked-up spellbook entry (by spell ID, or by name for commands such
-- as Attack), else a slot whose spell matches a cursor value. Never guess from a small
-- cursor value: those are spellbook positions, which put the wrong action on the button.
local function petSlotFromCursor(...)
    local slots = NUM_PET_ACTION_SLOTS or 10
    if picked and picked.slot then return picked.slot end
    if picked then
        for slot = 1, slots do
            local info = petInfo(slot)
            if info and ((picked.spellID and info.spellID == picked.spellID) or (picked.name and info.name == picked.name)) then
                return slot
            end
        end
    end
    local values = { ... }
    for slot = 1, slots do
        local info = petInfo(slot)
        for _, value in ipairs(values) do
            if info and info.spellID and value == info.spellID then return slot end
        end
    end
end

-- Remembers what a pet action looks like, so the button still shows it (greyed out)
-- when no pet is summoned.
local function rememberPet(content, info)
    if info then
        content.name, content.texture, content.spellID = info.name, info.texture, info.spellID
    end
end

-- Content from the cursor (spellbook, bags, macro frame, pet bar).
local function contentFromCursor()
    local kind, a, b, c = GetCursorInfo()
    if kind == "spell" then
        return { kind = "spell", id = c } -- "spell", slotIndex, bookType, spellID
    elseif kind == "item" then
        return { kind = "item", id = a }
    elseif kind == "macro" then
        local name = GetMacroInfo(a)
        return name and { kind = "macro", name = name }, a
    elseif kind == "petaction" then
        local slot = petSlotFromCursor(a, b, c)
        ns.Log(("petaction cursor values: %s, %s, %s; picked slot=%s spell=%s name=%s -> slot %s"):format(
            tostring(a), tostring(b), tostring(c), tostring(picked and picked.slot),
            tostring(picked and picked.spellID), tostring(picked and picked.name), tostring(slot)))
        picked = nil
        if not slot then return nil, "petaction-not-on-bar" end
        local content = { kind = "petaction", slot = slot }
        rememberPet(content, petInfo(slot))
        return content
    elseif kind == "mount" then
        -- "mount", mountID. The "random favorite" entry has no single mount to cast.
        if a == RANDOM_FAVORITE_MOUNT_ID then return nil, "the random favorite mount" end
        local name, spellID = C_MountJournal.GetMountInfoByID(a)
        return spellID and { kind = "mount", id = a, spellID = spellID, name = name }, nil
    elseif kind == "battlepet" then
        return { kind = "battlepet", guid = a } -- "battlepet", petGUID
    end
    return nil, kind
end

local function isToy(itemID)
    return PlayerHasToy and PlayerHasToy(itemID) or false
end

-- A mount's position in the mount journal, which C_MountJournal.Pickup needs.
local function mountJournalIndex(mountID)
    for i = 1, C_MountJournal.GetNumDisplayedMounts() do
        if select(12, C_MountJournal.GetDisplayedMountInfo(i)) == mountID then return i end
    end
end

-- Puts saved contents on the game cursor. If the client can't pick it up, the cursor stays
-- empty, which still clears it from the button as intended.
local function putOnCursor(content)
    local ok = true
    if content.kind == "spell" then
        ok = pcall(C_Spell.PickupSpell, content.id)
    elseif content.kind == "item" and isToy(content.id) and C_ToyBox and C_ToyBox.PickupToyBoxItem then
        ok = pcall(C_ToyBox.PickupToyBoxItem, content.id)
    elseif content.kind == "item" then
        ok = pcall(C_Item.PickupItem or PickupItem, content.id)
    elseif content.kind == "mount" then
        local index = mountJournalIndex(content.id) -- not found if the journal filters hide it
        if index then ok = pcall(C_MountJournal.Pickup, index) else ok = pcall(C_Spell.PickupSpell, content.spellID) end
    elseif content.kind == "battlepet" then
        ok = pcall(C_PetJournal.PickupPet, content.guid)
    elseif content.kind == "macro" then
        local index = GetMacroIndexByName(content.name)
        if index and index > 0 then ok = pcall(PickupMacro, index) end
    elseif content.kind == "petaction" then
        ok = pcall(PickupPetAction, content.slot) -- the pickup hook records the slot for the drop
    end
    if not ok then ns.Log("couldn't put " .. content.kind .. " on the cursor") end
end

-- Places the cursor contents on this button. Returns true if something was placed.
function Button:ReceiveCursor()
    if InCombatLockdown() then
        ns.Print("Can't change buttons in combat.")
        return false
    end
    -- A drag release can arrive as both a drop and a click; handle it once per frame, or the
    -- second would put the swapped-out contents straight back.
    local now = GetTime()
    if self.receivedAt == now then return false end
    self.receivedAt = now
    local content, detail = contentFromCursor()
    if not content then
        if detail == "petaction-not-on-bar" then
            ns.Print("Put that on your pet bar first: Elastibar pet buttons mirror pet bar slots.")
        else
            ns.Print("Can't place '%s' on an Elastibar button yet.", tostring(detail))
        end
        return false
    end
    -- detail is the macro index for macros (account bars only take account macros).
    if self.accepts and not self.accepts(content, detail) then
        ns.Print(ns.BarStore.ACCOUNT_REFUSAL)
        return false -- leaves it on the cursor
    end
    ClearCursor()
    local previous = self.content
    self:SetContent(content)
    if self.onContentChanged then self.onContentChanged(self, content) end
    -- Swap, like Blizzard's bars: what was here goes onto the cursor instead of being lost.
    if previous then putOnCursor(previous) end
    return true
end

-- Shift-drag: put the contents on the cursor and empty the button. Dropping them on another
-- Elastibar button moves them, on a Blizzard bar places them there, anywhere else clears them.
function Button:PickUp()
    if not self.content then return end
    if InCombatLockdown() then
        ns.Print("Can't change buttons in combat.")
        return
    end
    local content = self.content
    self:SetContent(nil)
    if self.onContentChanged then self.onContentChanged(self, nil) end
    putOnCursor(content)
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
    w:SetAttribute("macrotext", nil)
    w:SetAttribute("action", nil)
    w:SetAttribute("toy", nil)
    if content and content.kind == "spell" then
        setType("spell")
        w:SetAttribute("spell", content.id)
    elseif content and content.kind == "item" and isToy(content.id) then
        setType("toy")
        w:SetAttribute("toy", content.id)
    elseif content and content.kind == "item" then
        setType("item")
        w:SetAttribute("item", "item:" .. content.id)
    elseif content and content.kind == "mount" then
        -- Cast by name, as Button Forge does on this client.
        setType("macro")
        w:SetAttribute("macrotext", "/cast " .. (C_Spell.GetSpellName(content.spellID) or content.name or ""))
    elseif content and content.kind == "battlepet" then
        setType("macro")
        w:SetAttribute("macrotext", "/summonpet " .. content.guid)
    elseif content and content.kind == "macro" then
        local index = GetMacroIndexByName(content.name)
        if index and index > 0 then
            setType("macro")
            w:SetAttribute("macro", index)
        end
    elseif content and content.kind == "petaction" then
        -- The secure "pet" action runs CastPetAction on the pet bar slot.
        setType("pet")
        w:SetAttribute("action", content.slot)
    end
    self:Update()
end

-- The spell whose cooldown/usability a button should show (macros show their current spell).
function Button:DisplaySpell()
    local c = self.content
    if not c then return nil end
    if c.kind == "spell" then return c.id end
    if c.kind == "mount" then return c.spellID end
    if c.kind == "macro" then
        local index = GetMacroIndexByName(c.name)
        return index and index > 0 and GetMacroSpell(index) or nil
    end
end

-- The unit a macro's spell would land on right now, from its first /cast or /use line whose
-- conditions match, such as [mod:alt,@player]. Nil means the usual target.
local function macroUnit(name)
    local index = GetMacroIndexByName(name)
    local body = index and index > 0 and select(3, GetMacroInfo(index))
    for line in (body or ""):gmatch("[^\r\n]+") do
        local command, args = line:match("^%s*/(%a+)%s+(.+)$")
        command = command and command:lower()
        if command == "cast" or command == "use" then
            local result, unit = SecureCmdOptionParse(args)
            if result and result ~= "" then return unit end
        end
    end
end

function Button:UpdateIcon()
    local c, texture, greyed = self.content, nil, false
    if c and c.kind == "spell" then
        texture = C_Spell.GetSpellTexture(c.id)
    elseif c and c.kind == "mount" then
        texture = C_Spell.GetSpellTexture(c.spellID)
    elseif c and c.kind == "battlepet" then
        texture = select(9, C_PetJournal.GetPetInfoByPetID(c.guid))
    elseif c and c.kind == "item" then
        texture = C_Item.GetItemIconByID(c.id)
    elseif c and c.kind == "macro" then
        local index = GetMacroIndexByName(c.name)
        if index and index > 0 then texture = select(2, GetMacroInfo(index)) end
    elseif c and c.kind == "petaction" then
        local info = petInfo(c.slot)
        rememberPet(c, info) -- c is the saved record, so this keeps the remembered look current
        texture, greyed = c.texture, info == nil
    end
    self.icon:SetTexture(texture)
    self.icon:SetDesaturated(greyed)
    self.icon:SetShown(texture ~= nil)
end

-- In combat, cooldown numbers are "secret": addon code can't pass them to SetCooldown.
-- Spells use a duration object instead, which the cooldown frame accepts as-is.
local itemSecretLogged, petSecretLogged = false, false

function Button:UpdateCooldown()
    local c, spellID = self.content, self:DisplaySpell()
    if c and c.kind == "petaction" then
        local start, duration, enable = GetPetActionCooldown(c.slot)
        if issecretvalue and issecretvalue(start) then
            -- Fall back to the pet spell's duration object, if the slot is a spell.
            local info = petInfo(c.slot)
            local object = info and info.spellID and C_Spell.GetSpellCooldownDuration(info.spellID)
            if object then self.cooldown:SetCooldownFromDurationObject(object) end
            if not petSecretLogged then
                petSecretLogged = true
                ns.Log("pet action cooldown values are secret in combat; using the spell duration object")
            end
        elseif enable and enable ~= 0 then
            self.cooldown:SetCooldown(start, duration)
        else
            self.cooldown:Clear()
        end
    elseif spellID then
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
        -- Range is checked against whoever the spell would land on, as Blizzard's bars do.
        local unit = c.kind == "macro" and macroUnit(c.name) or "target"
        if unit ~= "player" then inRange = C_Spell.IsSpellInRange(spellID, unit) end
    elseif c and c.kind == "item" and isToy(c.id) then
        usable = not C_ToyBox.IsToyUsable or C_ToyBox.IsToyUsable(c.id) -- toys aren't in bags
    elseif c and c.kind == "item" then
        usable = C_Item.IsUsableItem(c.id)
        -- IsItemInRange is protected in combat on this client (calling it is a blocked action).
        if not InCombatLockdown() then inRange = C_Item.IsItemInRange(c.id, "target") end
    elseif c and c.kind == "petaction" then
        local info = petInfo(c.slot)
        usable = info ~= nil and GetPetActionSlotUsable(c.slot)
        inRange = info and info.inRange
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
    local c, active = self.content, nil
    if c and c.kind == "petaction" then
        local info = petInfo(c.slot)
        active = info and info.isActive -- e.g. the current stance (Defensive) or Follow
    elseif c and c.kind == "mount" then
        active = select(4, C_MountJournal.GetMountInfoByID(c.id)) -- currently mounted on it
    elseif c and c.kind == "battlepet" then
        active = C_PetJournal.GetSummonedPetGUID() == c.guid
    else
        local spellID = self:DisplaySpell()
        active = spellID and (C_Spell.IsCurrentSpell(spellID) or C_Spell.IsAutoRepeatSpell(spellID))
    end
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
    if not c or not ns.Options.ButtonTooltipsShown() then return end
    GameTooltip:SetOwner(self.widget, "ANCHOR_RIGHT")
    if c.kind == "spell" then
        GameTooltip:SetSpellByID(c.id)
    elseif c.kind == "item" and isToy(c.id) and GameTooltip.SetToyByItemID then
        GameTooltip:SetToyByItemID(c.id)
    elseif c.kind == "item" then
        GameTooltip:SetItemByID(c.id)
    elseif c.kind == "mount" then
        if not (GameTooltip.SetMountBySpellID and pcall(GameTooltip.SetMountBySpellID, GameTooltip, c.spellID)) then
            GameTooltip:SetSpellByID(c.spellID)
        end
    elseif c.kind == "battlepet" then
        local _, customName, level, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(c.guid)
        GameTooltip:SetText(customName or name or "Battle pet")
        if level then GameTooltip:AddLine(("Level %d battle pet"):format(level), 0.7, 0.7, 0.7) end
    elseif c.kind == "petaction" then
        if petInfo(c.slot) then
            GameTooltip:SetPetAction(c.slot)
        else
            GameTooltip:SetText(c.name or ("Pet bar slot %d"):format(c.slot))
            GameTooltip:AddLine("Your pet isn't summoned.", 0.7, 0.7, 0.7, true)
        end
    else
        -- What the macro would use right now, as #showtooltip does, falling back to the
        -- macro's name. Any custom text goes underneath, as on Blizzard's bars.
        local index = GetMacroIndexByName(c.name)
        local spell = index and index > 0 and GetMacroSpell(index)
        local itemLink = not spell and index and index > 0 and GetMacroItem and select(2, GetMacroItem(index))
        if spell then
            GameTooltip:SetSpellByID(spell)
        elseif itemLink then
            GameTooltip:SetHyperlink(itemLink)
        else
            GameTooltip:SetText(c.name)
            GameTooltip:AddLine("Macro", 0.7, 0.7, 0.7)
        end
        ns.MacroTooltips.AddTo(GameTooltip, c.name)
    end
    GameTooltip:Show()
end
