-- Bar: the on-screen side of a bar record. A secure frame with a grid of Buttons.
--
-- Secure frames can't be destroyed, so released bars go back to a pool and are reused.
-- Everything here that touches secure frames must run out of combat; Bars.lua checks.

local _, ns = ...

local Bar = {}
Bar.__index = Bar
ns.Bar = Bar

-- ActionButtonTemplate is natively 45px on this client (Button Forge uses 45 with a 2px gap).
Bar.BUTTON_SIZE, Bar.BUTTON_GAP = 45, 2

local LAYERS = { behind = "LOW", normal = "MEDIUM", above = "HIGH", top = "DIALOG" }

local pool, sequence = {}, 0

function Bar.Acquire(record)
    local self = table.remove(pool)
    if not self then
        sequence = sequence + 1
        local frame = CreateFrame("Frame", "ElastibarBar" .. sequence, UIParent, "SecureHandlerStateTemplate")
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        self = setmetatable({ frame = frame, buttons = {} }, Bar)
    end
    self.record = record
    return self
end

function Bar:Release()
    UnregisterStateDriver(self.frame, "visibility")
    self.frame:Hide()
    for _, button in pairs(self.buttons) do
        button:SetContent(nil)
        button.widget:Hide()
    end
    self.record = nil
    table.insert(pool, self)
end

local function layoutKey()
    return ns.EditModeLayoutName and ns.EditModeLayoutName() or "default"
end

-- Builds or reuses one button per grid cell, hides buttons outside the grid, and
-- loads saved contents. Buttons are keyed "row,col" like the record.
function Bar:ApplyLayout()
    local record, size, gap = self.record, Bar.BUTTON_SIZE, Bar.BUTTON_GAP
    self.frame:SetSize(record.cols * size + (record.cols - 1) * gap, record.rows * size + (record.rows - 1) * gap)

    local inGrid = {}
    for row = 1, record.rows do
        for col = 1, record.cols do
            local key = ns.BarStore.ButtonKey(row, col)
            inGrid[key] = true
            local button = self.buttons[key]
            if not button then
                button = ns.Button.Create(self.frame, function(_, content)
                    if self.record then self.record.buttons[key] = content end
                    self:ApplyEmptySlots()
                end)
                self.buttons[key] = button
            end
            button.widget:ClearAllPoints()
            button.widget:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (col - 1) * (size + gap), -(row - 1) * (size + gap))
            button.widget:Show()
            button:SetContent(record.buttons[key])
        end
    end
    for key, button in pairs(self.buttons) do
        if not inGrid[key] then
            button:SetContent(nil)
            button.widget:Hide()
        end
    end
    self:ApplyEmptySlots()
end

-- "Hide empty slots" (per bar): empty buttons become invisible. Alpha isn't protected,
-- unlike Show/Hide on secure buttons, so this also works in combat, and invisible buttons
-- still accept drops. They reappear while something is on the cursor or Edit Mode is open.
function Bar:ApplyEmptySlots()
    if not self.record then return end
    local revealed = not self.record.hideEmpty or GetCursorInfo() ~= nil
        or (ns.EditMode and ns.EditMode.IsActive())
    for _, button in pairs(self.buttons) do
        button.widget:SetAlpha((button.content or revealed) and 1 or 0)
    end
end

function Bar:SetHideEmpty(hide)
    self.record.hideEmpty = hide
    self:ApplyEmptySlots()
end

function Bar:ApplyScale()
    self.frame:SetScale(self.record.scale or 1)
end

function Bar:ApplyLayer()
    self.frame:SetFrameStrata(LAYERS[self.record.layer] or LAYERS.normal)
end

function Bar:ApplyPosition()
    local frame, pos = self.frame, self.record.positions[layoutKey()]
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function Bar:SavePosition()
    local point, _, relativePoint, x, y = self.frame:GetPoint()
    self.record.positions[layoutKey()] = { point, relativePoint, x, y }
end

-- Changes scale while keeping the bar's center where it is on screen.
-- (Point offsets are in the frame's own scale, so the anchor is recomputed.)
function Bar:SetScaleKeepingCenter(scale)
    local frame = self.frame
    local cx, cy = frame:GetCenter()
    local screenX, screenY = cx * frame:GetEffectiveScale(), cy * frame:GetEffectiveScale()
    self.record.scale = scale
    self:ApplyScale()
    local effective = frame:GetEffectiveScale()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", screenX / effective, screenY / effective)
    self:SavePosition()
end

-- Re-anchors the bar by its top-left corner without moving it, so resizing grows it
-- right and down. Offsets are in the bar's own scale, like GetLeft/GetTop.
function Bar:AnchorTopLeft()
    local frame = self.frame
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (left and top) then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

-- Moves the bar's top-left corner to (left, top), in UIParent units.
function Bar:MoveTo(left, top)
    local scale = self.frame:GetScale()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale, top / scale)
end

-- Sets columns and rows (clamped to 1..12), keeping the top-left corner in place.
-- Buttons outside the new size are hidden but keep their saved contents.
-- Returns true if the size changed.
function Bar:SetGridSize(cols, rows)
    cols, rows = ns.BarStore.ClampSize(cols), ns.BarStore.ClampSize(rows)
    local record = self.record
    if cols == record.cols and rows == record.rows then return false end
    self:AnchorTopLeft()
    record.cols, record.rows = cols, rows
    self:ApplyLayout()
    self:SavePosition()
    return true
end

function Bar:SetLayer(layer)
    self.record.layer = layer
    self:ApplyLayer()
end

-- Translates the rule (spec names to [spec:N]) and hands it to the game.
-- Returns the translated rule and any problems (unknown or ambiguous spec names).
function Bar:ApplyVisibility(specInfo)
    local translated, problems = ns.Conditionals.Translate(self.record.visibility or "show", specInfo)
    if translated == "" then translated = "hide" end -- no clause can match
    UnregisterStateDriver(self.frame, "visibility")
    RegisterStateDriver(self.frame, "visibility", translated)
    self.translatedVisibility = translated
    return translated, problems
end

function Bar:Apply(specInfo)
    self:ApplyLayout()
    self:ApplyScale()
    self:ApplyLayer()
    self:ApplyPosition()
    self:ApplyVisibility(specInfo)
end

function Bar:UpdateButtons()
    for key, button in pairs(self.buttons) do
        if button.widget:IsShown() then button:Update() end
    end
end

function Bar:UpdateUsable()
    for _, button in pairs(self.buttons) do
        if button.widget:IsShown() then button:UpdateUsable() end
    end
end
