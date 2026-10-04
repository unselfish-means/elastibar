-- EditMode: Elastibar bars inside Blizzard's Edit Mode.
--
-- Blizzard doesn't officially support addon frames in Edit Mode; this uses the same hooks
-- LibEditMode uses on Retail, confirmed taint-free on Forever (docs/platform.md):
--   - EventRegistry "EditMode.Enter"/"EditMode.Exit" callbacks (+ hooksecurefunc fallback)
--   - Blizzard's selection overlay (EditModeSystemSelectionTemplate) on each bar, with its
--     scripts replaced because they expect a Blizzard Edit Mode system (self.system)
--   - EditModeManagerFrame:ClearSelectedSystem() so only one thing is selected at a time
--
-- While Edit Mode is open, each bar can be:
--   - dragged, snapping its top-left corner to Elastibar's grid (hold Shift to skip snapping);
--   - resized by dragging its right edge (columns), bottom edge (rows), or corner (both);
--   - selected, which opens the bar settings panel (BarSettings.lua).

local _, ns = ...

local EditMode = {}
ns.EditMode = EditMode

local active = false
local attached = {} -- [Bar] = true
local selected

function ns.EditModeLayoutName()
    if not EditModeManagerFrame or not EditModeManagerFrame.GetActiveLayoutInfo then return nil end
    local ok, info = pcall(EditModeManagerFrame.GetActiveLayoutInfo, EditModeManagerFrame)
    return ok and type(info) == "table" and info.layoutName or nil
end

function EditMode.IsActive()
    return active
end

function EditMode.Selected()
    return selected
end

-- Highlight -------------------------------------------------------------------

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
    ns.BarSettings.Close()
    if selected then setHighlight(selected, false) end
    selected = nil
end
EditMode.Deselect = deselect

local function selectBar(bar)
    if selected and selected ~= bar then setHighlight(selected, false) end
    selected = bar
    -- Deselect Blizzard's frame so only one thing is selected at a time.
    if EditModeManagerFrame and EditModeManagerFrame.ClearSelectedSystem then
        pcall(EditModeManagerFrame.ClearSelectedSystem, EditModeManagerFrame)
    end
    setHighlight(bar, true)
    ns.BarSettings.Open(bar)
end

-- Dragging: moving and resizing ------------------------------------------------
-- One driver frame runs whichever drag is in progress. Positions are in UIParent units.

local driver = CreateFrame("Frame")
driver:Hide()
local drag -- { bar, mode = "move" | "cols" | "rows" | "both", offsetX, offsetY }

local function cursor()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return x / scale, y / scale
end

-- The bar's top-left corner in UIParent units.
local function topLeft(bar)
    local frame, scale = bar.frame, bar.frame:GetScale()
    return frame:GetLeft() * scale, frame:GetTop() * scale
end

driver:SetScript("OnUpdate", function()
    if not drag or InCombatLockdown() then return end
    local bar, cx, cy = drag.bar, cursor()
    if drag.mode == "move" then
        local left, top = cx - drag.offsetX, cy - drag.offsetY
        if not IsShiftKeyDown() then
            local size = ns.Grid.Size()
            left, top = ns.Grid.Snap(left, size), ns.Grid.Snap(top, size)
        end
        bar:MoveTo(left, top)
    else
        -- n buttons span n * cell - gap, so n = (distance + gap) / cell, rounded.
        local scale = bar.frame:GetScale()
        local cell, gap = (ns.Bar.BUTTON_SIZE + ns.Bar.BUTTON_GAP) * scale, ns.Bar.BUTTON_GAP * scale
        local left, top = topLeft(bar)
        local cols, rows = bar.record.cols, bar.record.rows
        if drag.mode ~= "rows" then cols = (cx - left + gap) / cell end
        if drag.mode ~= "cols" then rows = (top - cy + gap) / cell end
        if bar:SetGridSize(cols, rows) then ns.BarSettings.Refresh(bar) end
    end
end)

local function startDrag(bar, mode)
    if InCombatLockdown() then return end
    selectBar(bar)
    local left, top = topLeft(bar)
    local cx, cy = cursor()
    drag = { bar = bar, mode = mode, offsetX = cx - left, offsetY = cy - top }
    if mode == "move" then ns.Grid.ShowLines() end
    driver:Show()
end

local function stopDrag()
    if not drag then return end
    drag.bar:SavePosition()
    drag = nil
    driver:Hide()
    ns.Grid.HideLines()
end

-- Overlay and resize handles -------------------------------------------------

local HANDLES = {
    { mode = "cols", point = "LEFT", relativePoint = "RIGHT", x = 2, y = 0, w = 8, h = 26 },
    { mode = "rows", point = "TOP", relativePoint = "BOTTOM", x = 0, y = -2, w = 26, h = 8 },
    { mode = "both", point = "TOPLEFT", relativePoint = "BOTTOMRIGHT", x = 0, y = 0, w = 12, h = 12 },
}

local function buildHandle(bar, overlay, spec)
    local handle = CreateFrame("Frame", nil, overlay)
    handle:SetSize(spec.w, spec.h)
    handle:SetPoint(spec.point, overlay, spec.relativePoint, spec.x, spec.y)
    handle:SetFrameLevel(overlay:GetFrameLevel() + 2)
    local texture = handle:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetColorTexture(0.3, 0.7, 1, 0.9)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() startDrag(bar, spec.mode) end)
    handle:SetScript("OnDragStop", stopDrag)
    handle:SetScript("OnEnter", function()
        texture:SetColorTexture(0.5, 0.85, 1, 1)
        GameTooltip:SetOwner(handle, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:SetText(spec.mode == "cols" and "Drag to add or remove columns"
            or spec.mode == "rows" and "Drag to add or remove rows" or "Drag to resize")
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function()
        texture:SetColorTexture(0.3, 0.7, 1, 0.9)
        GameTooltip:Hide()
    end)
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
        GameTooltip:AddLine("Drag to move. Hold Shift to move without snapping.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    overlay:SetScript("OnLeave", function(self)
        if self.MouseOverHighlight then self.MouseOverHighlight:Hide() end
        GameTooltip:Hide()
    end)
    overlay:SetScript("OnMouseDown", function() selectBar(bar) end)
    overlay:SetScript("OnDragStart", function() startDrag(bar, "move") end)
    overlay:SetScript("OnDragStop", stopDrag)
    for _, spec in ipairs(HANDLES) do buildHandle(bar, overlay, spec) end
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
    if drag and drag.bar == bar then stopDrag() end
    if selected == bar then deselect() end
    if bar.overlay then bar.overlay:Hide() end
end

-- Call after a bar's name or settings change outside the panel.
function EditMode.Refresh(bar)
    if bar and bar == selected then ns.BarSettings.Refresh(bar) end
end

-- Edit Mode open/close -------------------------------------------------------

local function onEnter()
    if active then return end
    active = true
    for bar in pairs(attached) do
        bar.overlay:Show()
        setHighlight(bar, false)
        bar:ApplyEmptySlots() -- hidden empty slots show while editing
    end
end

local function onExit()
    if not active then return end
    active = false
    stopDrag()
    deselect()
    -- Blizzard's ShowHighlighted also shows the overlay, so hide overlays after deselecting.
    for bar in pairs(attached) do
        bar.overlay:Hide()
        bar:ApplyEmptySlots()
    end
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

-- Combat ends any drag (secure frames can't move in combat).
ns.On("PLAYER_REGEN_DISABLED", stopDrag)

ns.On("PLAYER_LOGIN", function()
    hook()
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then onEnter() end
end)
