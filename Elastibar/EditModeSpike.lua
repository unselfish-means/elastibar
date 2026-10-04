-- Edit Mode spike: can Elastibar bars join Blizzard's Edit Mode on WoW: Forever?
--
-- Tests, using the same hooks LibEditMode uses on Retail:
--   1. Detect Edit Mode opening and closing.
--   2. Show Blizzard's selection overlay (EditModeSystemSelectionTemplate) on the bar.
--   3. Select the bar and drag it while Edit Mode is open.
--   4. Keep positions per Edit Mode layout.
--   5. Show a small settings dialog (scale) when the bar is selected, and hide it
--      when a Blizzard frame is selected instead.
--   6. Watch for taint: report any ADDON_ACTION_BLOCKED/FORBIDDEN events.
--
-- /eb editmode prints what this client offers.

local _, ns = ...

local SCALES = { 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2 }

local spike, selection, dialog
local editModeActive = false
local usedBlizzardOverlay = false

function ns.EditModeLayoutName()
    if not EditModeManagerFrame or not EditModeManagerFrame.GetActiveLayoutInfo then return nil end
    local ok, info = pcall(EditModeManagerFrame.GetActiveLayoutInfo, EditModeManagerFrame)
    return ok and type(info) == "table" and info.layoutName or nil
end

-- Selection overlay ---------------------------------------------------------

local function setHighlight(selected)
    if not selection then return end
    if usedBlizzardOverlay then
        local method = selected and selection.ShowSelected or selection.ShowHighlighted
        if method then pcall(method, selection) end
    else
        selection.fill:SetColorTexture(0.2, 0.6, 1, selected and 0.45 or 0.2)
    end
end

local function closeDialog()
    if dialog then dialog:Hide() end
    setHighlight(false)
end

local function scaleIndex()
    local current = spike.state().scale or 1
    for i, s in ipairs(SCALES) do
        if math.abs(s - current) < 0.001 then return i end
    end
    return 6
end

local function updateDialog()
    dialog.value:SetText(("%d%%"):format(math.floor((spike.state().scale or 1) * 100 + 0.5)))
end

local function stepScale(delta)
    if InCombatLockdown() then return end
    local i = math.max(1, math.min(#SCALES, scaleIndex() + delta))
    spike.state().scale = SCALES[i]
    -- Offsets are in the bar's own scale, so the bar drifts as it scales; fine for a spike.
    spike.applyScale()
    spike.applyPosition()
    updateDialog()
end

local function buildDialog()
    dialog = CreateFrame("Frame", "ElastibarEditModeDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(220, 90)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    dialog:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
    dialog:Hide()

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Elastibar spike bar")

    local label = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 14, -38)
    label:SetText("Scale")

    local minus = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    minus:SetSize(26, 22)
    minus:SetPoint("LEFT", label, "RIGHT", 40, 0)
    minus:SetText("-")
    minus:SetScript("OnClick", function() stepScale(-1) end)

    dialog.value = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dialog.value:SetPoint("LEFT", minus, "RIGHT", 8, 0)
    dialog.value:SetWidth(44)

    local plus = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    plus:SetSize(26, 22)
    plus:SetPoint("LEFT", dialog.value, "RIGHT", 8, 0)
    plus:SetText("+")
    plus:SetScript("OnClick", function() stepScale(1) end)

    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", closeDialog)
end

local function openDialog()
    if not dialog then buildDialog() end
    dialog:ClearAllPoints()
    dialog:SetPoint("BOTTOMLEFT", spike.bar, "TOPRIGHT", 8, 8)
    dialog:SetClampedToScreen(true)
    updateDialog()
    dialog:Show()
end

local function selectBar()
    ns.Log("Elastibar bar selected")
    -- Deselect Blizzard's frame so only one thing is selected at a time.
    if EditModeManagerFrame and EditModeManagerFrame.ClearSelectedSystem then
        local ok, err = pcall(EditModeManagerFrame.ClearSelectedSystem, EditModeManagerFrame)
        if not ok then ns.Print("|cffff8800ClearSelectedSystem failed:|r %s", tostring(err)) end
    end
    setHighlight(true)
    openDialog()
end

local function buildSelection()
    local ok, frame = pcall(CreateFrame, "Frame", nil, spike.bar, "EditModeSystemSelectionTemplate")
    if ok and frame then
        usedBlizzardOverlay = true
        selection = frame
        if selection.Label then selection.Label:SetText("Elastibar") end
    else
        selection = CreateFrame("Frame", nil, spike.bar)
        selection.fill = selection:CreateTexture(nil, "OVERLAY")
        selection.fill:SetAllPoints()
    end
    selection:SetAllPoints(spike.bar)
    selection:SetFrameLevel(spike.bar:GetFrameLevel() + 20)
    selection:EnableMouse(true)
    selection:RegisterForDrag("LeftButton")
    -- Replace Blizzard's scripts: they expect a Blizzard Edit Mode system (self.system), and
    -- error on hover without one.
    selection:SetScript("OnEnter", function(self)
        if self.MouseOverHighlight then self.MouseOverHighlight:Show() end
        -- Name tooltip, like Blizzard's frames show in Edit Mode.
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:SetText("Elastibar", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
        GameTooltip:Show()
    end)
    selection:SetScript("OnLeave", function(self)
        if self.MouseOverHighlight then self.MouseOverHighlight:Hide() end
        GameTooltip:Hide()
    end)
    selection:SetScript("OnMouseDown", selectBar)
    selection:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        selectBar()
        spike.bar:StartMoving()
    end)
    selection:SetScript("OnDragStop", function()
        spike.bar:StopMovingOrSizing()
        spike.savePosition()
    end)
    selection:Hide()
end

-- Edit Mode open/close ------------------------------------------------------

local function onEnter()
    if editModeActive or not spike then return end
    editModeActive = true
    ns.Log("Edit Mode opened")
    if not selection then buildSelection() end
    selection:Show()
    setHighlight(false)
    spike.handle:Hide() -- in Edit Mode, the overlay replaces the spike's drag tab
end

local function onExit()
    if not editModeActive then return end
    editModeActive = false
    ns.Log("Edit Mode closed")
    -- closeDialog resets the highlight, and Blizzard's ShowHighlighted also shows the
    -- overlay, so hide the overlay last.
    closeDialog()
    if selection then selection:Hide() end
    if spike then spike.handle:Show() end
end

local hookedVia
local function hookEditMode()
    if EventRegistry and EventRegistry.RegisterCallback then
        local ok = pcall(function()
            EventRegistry:RegisterCallback("EditMode.Enter", onEnter, ns)
            EventRegistry:RegisterCallback("EditMode.Exit", onExit, ns)
        end)
        if ok then hookedVia = "EventRegistry" end
    end
    if EditModeManagerFrame then
        -- Also hook the methods directly, in case the callbacks don't fire on this client.
        if EditModeManagerFrame.EnterEditMode then hooksecurefunc(EditModeManagerFrame, "EnterEditMode", onEnter) end
        if EditModeManagerFrame.ExitEditMode then hooksecurefunc(EditModeManagerFrame, "ExitEditMode", onExit) end
        -- When a Blizzard frame is selected, drop ours.
        if EditModeManagerFrame.SelectSystem then hooksecurefunc(EditModeManagerFrame, "SelectSystem", closeDialog) end
        hookedVia = hookedVia and (hookedVia .. " + hooksecurefunc") or "hooksecurefunc"
    end
end

ns.OnSpikeBuilt = function(built)
    spike = built
    hookEditMode()
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then onEnter() end
end

-- Switching Edit Mode layouts moves the bar to that layout's saved position.
ns.On("EDIT_MODE_LAYOUTS_UPDATED", function()
    if not spike then return end
    ns.RunOutOfCombat("spike-layout", spike.applyPosition)
end)

-- Taint watch -----------------------------------------------------------------

local function onBlocked(event, addon, func)
    ns.Print("|cffff4040%s|r addon=%s function=%s", event, tostring(addon), tostring(func))
end
ns.On("ADDON_ACTION_BLOCKED", onBlocked)
ns.On("ADDON_ACTION_FORBIDDEN", onBlocked)

-- Diagnostics -----------------------------------------------------------------

function ns.EditModeDiagnostics()
    local function has(v) return v and "yes" or "|cffff8800no|r" end
    ns.Print("Edit Mode diagnostics")
    ns.Print("  EditModeManagerFrame: %s", has(EditModeManagerFrame))
    ns.Print("  EventRegistry: %s; hooked via: %s", has(EventRegistry), tostring(hookedVia))
    ns.Print("  selection overlay: %s", selection and (usedBlizzardOverlay and "Blizzard template" or "fallback") or "not built yet (open Edit Mode)")
    ns.Print("  EditModeMagnetismManager (snapping): %s", has(EditModeMagnetismManager))
    ns.Print("  EditModeSystemSettingsDialog: %s", has(EditModeSystemSettingsDialog))
    ns.Print("  active layout: %s", tostring(ns.EditModeLayoutName()))
    ns.Print("  Edit Mode open: %s", tostring(editModeActive))
    ns.Print("  taintLog CVar: %s", tostring(GetCVar and GetCVar("taintLog")))
end

-- Secret values: which cooldown APIs avoid "secret values are only allowed during
-- untainted execution" in combat? List anything duration- or secret-related.
local function secretDiagnostics()
    ns.Print("Secret value diagnostics")
    ns.Print("  issecretvalue: %s", type(issecretvalue))
    for _, nsName in ipairs({ "C_Spell", "C_Item", "C_Container", "C_DurationUtil", "C_ActionBar", "C_Secrets" }) do
        local tbl = _G[nsName]
        if type(tbl) == "table" then
            local found = {}
            for key in pairs(tbl) do
                if key:find("Duration") or key:find("Secret") then found[#found + 1] = key end
            end
            table.sort(found)
            ns.Print("  %s: %s", nsName, #found > 0 and table.concat(found, ", ") or "(none)")
        else
            ns.Print("  %s: missing", nsName)
        end
    end
    local cooldown = CreateFrame("Cooldown", nil, UIParent, "CooldownFrameTemplate")
    local methods, index = {}, getmetatable(cooldown).__index
    for key in pairs(type(index) == "table" and index or {}) do
        if key:find("Duration") or key:find("Secret") then methods[#methods + 1] = key end
    end
    table.sort(methods)
    ns.Print("  Cooldown methods: %s", #methods > 0 and table.concat(methods, ", ") or "(none)")
    cooldown:Hide()
end

-- Record diagnostics once per session so they can be read without copying chat.
-- After /eb taintlog, turn the taintLog CVar on at every login (this client resets it on
-- reload). Opt-in only: chat errors appeared while it was on.
ns.On("PLAYER_ENTERING_WORLD", function()
    if ns.db and not ns.diagnosticsLogged then
        ns.diagnosticsLogged = true
        if ns.db.taintLog == true then pcall(SetCVar, "taintLog", "1") end
        C_Timer.After(2, function()
            ns.EditModeDiagnostics()
            secretDiagnostics()
        end)
    end
end)
