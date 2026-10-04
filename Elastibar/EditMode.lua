-- EditMode: Elastibar bars inside Blizzard's Edit Mode.
--
-- Blizzard doesn't officially support addon frames in Edit Mode; this uses the same hooks
-- LibEditMode uses on Retail, confirmed taint-free on Forever (docs/platform.md):
--   - EventRegistry "EditMode.Enter"/"EditMode.Exit" callbacks (+ hooksecurefunc fallback)
--   - Blizzard's selection overlay (EditModeSystemSelectionTemplate) on each bar, with its
--     scripts replaced because they expect a Blizzard Edit Mode system (self.system)
--   - EditModeManagerFrame:ClearSelectedSystem() so only one thing is selected at a time

local _, ns = ...

local EditMode = {}
ns.EditMode = EditMode

local SCALES = { 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2 }

local active = false
local attached = {} -- [Bar] = true
local selected, dialog

function ns.EditModeLayoutName()
    if not EditModeManagerFrame or not EditModeManagerFrame.GetActiveLayoutInfo then return nil end
    local ok, info = pcall(EditModeManagerFrame.GetActiveLayoutInfo, EditModeManagerFrame)
    return ok and type(info) == "table" and info.layoutName or nil
end

function EditMode.IsActive()
    return active
end

-- Overlay ---------------------------------------------------------------------

local function setHighlight(bar, isSelected)
    local overlay = bar.overlay
    if not overlay then return end
    if overlay.isBlizzard then
        local method = isSelected and overlay.ShowSelected or overlay.ShowHighlighted
        if method then pcall(method, overlay) end
    else
        overlay.fill:SetColorTexture(0.2, 0.6, 1, isSelected and 0.45 or 0.2)
    end
end

local function deselect()
    if dialog then dialog:Hide() end
    if selected then setHighlight(selected, false) end
    selected = nil
end

local function scaleIndex(scale)
    for i, s in ipairs(SCALES) do
        if math.abs(s - scale) < 0.001 then return i end
    end
    return 6
end

local function updateDialog()
    if not (dialog and selected) then return end
    local record = selected.record
    dialog.title:SetText(record.name)
    dialog.scope:SetText(record.scope == "account" and "Account bar" or "Character bar")
    dialog.value:SetText(("%d%%"):format(math.floor((record.scale or 1) * 100 + 0.5)))
end

local function stepScale(delta)
    if InCombatLockdown() or not selected then return end
    local i = math.max(1, math.min(#SCALES, scaleIndex(selected.record.scale or 1) + delta))
    selected:SetScaleKeepingCenter(SCALES[i])
    updateDialog()
end

local function buildDialog()
    dialog = CreateFrame("Frame", "ElastibarEditModeDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(230, 100)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetClampedToScreen(true)
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    dialog:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
    dialog:Hide()

    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dialog.title:SetPoint("TOP", 0, -10)
    dialog.scope = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dialog.scope:SetPoint("TOP", dialog.title, "BOTTOM", 0, -2)

    local label = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 14, -52)
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
    close:SetScript("OnClick", deselect)
end

local function selectBar(bar)
    if selected and selected ~= bar then setHighlight(selected, false) end
    selected = bar
    -- Deselect Blizzard's frame so only one thing is selected at a time.
    if EditModeManagerFrame and EditModeManagerFrame.ClearSelectedSystem then
        pcall(EditModeManagerFrame.ClearSelectedSystem, EditModeManagerFrame)
    end
    setHighlight(bar, true)
    if not dialog then buildDialog() end
    dialog:ClearAllPoints()
    dialog:SetPoint("BOTTOMLEFT", bar.frame, "TOPRIGHT", 8, 8)
    updateDialog()
    dialog:Show()
end

local function buildOverlay(bar)
    local ok, overlay = pcall(CreateFrame, "Frame", nil, bar.frame, "EditModeSystemSelectionTemplate")
    if ok and overlay then
        overlay.isBlizzard = true
    else
        overlay = CreateFrame("Frame", nil, bar.frame)
        overlay.fill = overlay:CreateTexture(nil, "OVERLAY")
        overlay.fill:SetAllPoints()
    end
    overlay:SetAllPoints(bar.frame)
    overlay:SetFrameLevel(bar.frame:GetFrameLevel() + 20)
    overlay:EnableMouse(true)
    overlay:RegisterForDrag("LeftButton")
    overlay:SetScript("OnEnter", function(self)
        if self.MouseOverHighlight then self.MouseOverHighlight:Show() end
        -- Name tooltip, like Blizzard's frames show in Edit Mode.
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:SetText(bar.record and bar.record.name or "Elastibar", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
        GameTooltip:Show()
    end)
    overlay:SetScript("OnLeave", function(self)
        if self.MouseOverHighlight then self.MouseOverHighlight:Hide() end
        GameTooltip:Hide()
    end)
    overlay:SetScript("OnMouseDown", function() selectBar(bar) end)
    overlay:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        selectBar(bar)
        bar.frame:StartMoving()
    end)
    overlay:SetScript("OnDragStop", function()
        bar.frame:StopMovingOrSizing()
        bar:SavePosition()
    end)
    overlay:Hide()
    bar.overlay = overlay
end

-- Bars ------------------------------------------------------------------------

function EditMode.Attach(bar)
    attached[bar] = true
    if not bar.overlay then buildOverlay(bar) end
    if active then
        bar.overlay:Show()
        setHighlight(bar, false)
    end
end

function EditMode.Detach(bar)
    attached[bar] = nil
    if selected == bar then deselect() end
    if bar.overlay then bar.overlay:Hide() end
end

-- Call after a bar's name or settings change outside the dialog.
function EditMode.Refresh(bar)
    if bar and bar == selected then updateDialog() end
end

-- Edit Mode open/close -------------------------------------------------------

local function onEnter()
    if active then return end
    active = true
    for bar in pairs(attached) do
        bar.overlay:Show()
        setHighlight(bar, false)
    end
end

local function onExit()
    if not active then return end
    active = false
    deselect()
    -- Blizzard's ShowHighlighted also shows the overlay, so hide overlays after deselecting.
    for bar in pairs(attached) do bar.overlay:Hide() end
end

local function hook()
    if EventRegistry and EventRegistry.RegisterCallback then
        pcall(function()
            EventRegistry:RegisterCallback("EditMode.Enter", onEnter, EditMode)
            EventRegistry:RegisterCallback("EditMode.Exit", onExit, EditMode)
        end)
    end
    if EditModeManagerFrame then
        -- Also hook the methods directly, in case the callbacks don't fire on this client.
        if EditModeManagerFrame.EnterEditMode then hooksecurefunc(EditModeManagerFrame, "EnterEditMode", onEnter) end
        if EditModeManagerFrame.ExitEditMode then hooksecurefunc(EditModeManagerFrame, "ExitEditMode", onExit) end
        -- When a Blizzard frame is selected, drop ours.
        if EditModeManagerFrame.SelectSystem then hooksecurefunc(EditModeManagerFrame, "SelectSystem", deselect) end
    end
end

ns.On("PLAYER_LOGIN", function()
    hook()
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then onEnter() end
end)
