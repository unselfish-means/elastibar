-- Bar: the on-screen side of a bar record. A secure frame with one page frame per page, each
-- holding a grid of Buttons. A "page" state driver picks the page to show (Pages.Rule), and a
-- secure snippet shows that page and hides the others, so pages switch in combat too.
--
-- In Edit Mode the selected bar is "expanded": every page is shown, stacked below the bar,
-- so each can be filled by dropping things on it (PageStack.lua draws the labels).
--
-- Secure frames can't be destroyed, so released bars go back to a pool and are reused.
-- Everything here that touches secure frames must run out of combat; Bars.lua checks.

local _, ns = ...

local Bar = {}
Bar.__index = Bar
ns.Bar = Bar

-- ActionButtonTemplate is natively 45px on this client (Button Forge uses 45 with a 2px gap).
Bar.BUTTON_SIZE, Bar.BUTTON_GAP = 45, 2
Bar.PAGE_GAP = 12 -- between pages stacked in Edit Mode

local LAYERS = { behind = "LOW", normal = "MEDIUM", above = "HIGH", top = "DIALOG" }

-- Runs in the restricted environment whenever the page state changes.
local ON_PAGE = [[
    local expanded = self:GetAttribute("expanded")
    for i = 1, self:GetAttribute("pagecount") or 0 do
        local page = self:GetFrameRef("page" .. i)
        if expanded or tostring(i) == tostring(newstate) then page:Show() else page:Hide() end
    end
]]

local pool, sequence = {}, 0

function Bar.Acquire(record)
    local self = table.remove(pool)
    if not self then
        sequence = sequence + 1
        local frame = CreateFrame("Frame", "ElastibarBar" .. sequence, UIParent, "SecureHandlerStateTemplate")
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:SetAttribute("_onstate-page", ON_PAGE)
        self = setmetatable({ frame = frame, pages = {} }, Bar)
    end
    self.record = record
    return self
end

-- Calls fn(button, pageIndex) for every button in use.
function Bar:EachButton(fn)
    for index, page in ipairs(self.pages) do
        if page.inUse then
            for _, button in pairs(page.buttons) do
                if button.widget:IsShown() then fn(button, index) end
            end
        end
    end
end

function Bar:Release()
    UnregisterStateDriver(self.frame, "visibility")
    UnregisterStateDriver(self.frame, "page")
    self:SetExpanded(false)
    self.frame:Hide()
    for _, page in ipairs(self.pages) do
        page.inUse = false
        page.frame:Hide()
        for _, button in pairs(page.buttons) do
            button:SetContent(nil)
            button.widget:Hide()
        end
    end
    self.record = nil
    table.insert(pool, self)
end

-- A page's frame and buttons, built on first use. Page frames are protected, so the
-- secure snippet can show and hide them in combat.
function Bar:Page(index)
    local page = self.pages[index]
    if page then return page end
    local frame = CreateFrame("Frame", nil, self.frame, "SecureHandlerBaseTemplate")
    self.frame:SetFrameRef("page" .. index, frame)
    page = { frame = frame, buttons = {} }
    -- Buttons on hidden pages miss updates; catch up when the page appears.
    frame:HookScript("OnShow", function()
        for _, button in pairs(page.buttons) do
            if button.widget:IsShown() then button:Update() end
        end
    end)
    self.pages[index] = page
    return page
end

-- Where the pages sit: all on the bar normally, stacked below it while expanded.
function Bar:AnchorPages()
    local width, height = self.frame:GetSize()
    for index, page in ipairs(self.pages) do
        page.frame:ClearAllPoints()
        page.frame:SetSize(width, height)
        if self.expanded and index > 1 then
            page.frame:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 0, -Bar.PAGE_GAP - (index - 2) * (height + Bar.PAGE_GAP))
        else
            page.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        end
    end
end

-- Shows the pages the current state calls for. The snippet does the same in combat.
function Bar:ShowPages()
    local state = tostring(self.frame:GetAttribute("state-page"))
    for index, page in ipairs(self.pages) do
        page.frame:SetShown(page.inUse and (self.expanded or tostring(index) == state))
    end
end

-- The page shown right now outside Edit Mode, or nil when no page matches.
function Bar:CurrentPage()
    return tonumber(self.frame:GetAttribute("state-page"))
end

-- While expanded the bar is shown whatever its visibility rule says, so a bar shown only
-- in combat can still be edited; collapsing hands the rule back to the game.
function Bar:SetExpanded(expanded)
    local was = self.expanded
    self.expanded = expanded and true or false
    if self.expanded and not was then
        UnregisterStateDriver(self.frame, "visibility")
        self.frame:Show()
    elseif was and not self.expanded and self.record then
        self:ApplyVisibility(ns.SpecTrees.Get())
    end
    self.frame:SetAttribute("expanded", expanded and true or nil)
    self:AnchorPages()
    self:ShowPages()
    self:ApplyEmptySlots()
end

local function layoutKey()
    return ns.EditModeLayoutName and ns.EditModeLayoutName() or "default"
end

-- Builds or reuses one button per grid cell on each page, hides buttons outside the grid
-- and pages past the last, and loads saved contents. Buttons are keyed "row,col" like the
-- record. Page frames follow record.pages by position, so after pages are reordered or
-- deleted this reloads each one with what its record page now holds.
function Bar:ApplyLayout()
    local record, size, gap = self.record, Bar.BUTTON_SIZE, Bar.BUTTON_GAP
    self.frame:SetSize(record.cols * size + (record.cols - 1) * gap, record.rows * size + (record.rows - 1) * gap)

    for index = 1, math.max(#record.pages, #self.pages) do
        local page, saved = self:Page(index), record.pages[index]
        page.inUse = saved ~= nil
        local inGrid = {}
        if saved then
            for row = 1, record.rows do
                for col = 1, record.cols do
                    local key = ns.BarStore.ButtonKey(row, col)
                    inGrid[key] = true
                    local button = page.buttons[key]
                    if not button then
                        button = ns.Button.Create(page.frame, function(_, content)
                            if self.record then self.record.pages[index].buttons[key] = content end
                            self:ApplyEmptySlots()
                        end, function(content, macroIndex)
                            if not self.record or self.record.scope ~= "account" then return true end
                            return ns.BarStore.AccountAllows(content, macroIndex, MAX_ACCOUNT_MACROS)
                        end)
                        page.buttons[key] = button
                    end
                    button.widget:ClearAllPoints()
                    button.widget:SetPoint("TOPLEFT", page.frame, "TOPLEFT", (col - 1) * (size + gap), -(row - 1) * (size + gap))
                    button.widget:Show()
                    button:SetContent(saved.buttons[key])
                end
            end
        end
        for key, button in pairs(page.buttons) do
            if not inGrid[key] then
                button:SetContent(nil)
                button.widget:Hide()
            end
        end
    end
    self.frame:SetAttribute("pagecount", #record.pages)
    self:AnchorPages()
    self:ShowPages()
    self:ApplyEmptySlots()
end

-- "Hide empty slots" (per bar): empty buttons become invisible. Alpha isn't protected,
-- unlike Show/Hide on secure buttons, so this also works in combat, and invisible buttons
-- still accept drops. They reappear while something is on the cursor, Edit Mode is open, or
-- the bar's pages are open for editing.
function Bar:ApplyEmptySlots()
    if not self.record then return end
    local revealed = not self.record.hideEmpty or GetCursorInfo() ~= nil or self.expanded
        or (ns.EditMode and ns.EditMode.IsActive())
    self:EachButton(function(button)
        button.widget:SetAlpha((button.content or revealed) and 1 or 0)
    end)
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

-- Hands the game the rule that picks a page, with spec names translated as for visibility.
-- Returns the translated rule and any problems.
function Bar:ApplyPages(specInfo)
    local translated, problems = ns.Conditionals.Translate(ns.Pages.Rule(self.record.pages), specInfo)
    if translated == "" then translated = "hide" end
    UnregisterStateDriver(self.frame, "page")
    RegisterStateDriver(self.frame, "page", translated)
    self.translatedPages = translated
    self:ShowPages()
    return translated, problems
end

function Bar:Apply(specInfo)
    self:ApplyLayout()
    self:ApplyScale()
    self:ApplyLayer()
    self:ApplyPosition()
    self:ApplyVisibility(specInfo)
    self:ApplyPages(specInfo)
end

-- Buttons on hidden pages are skipped; their page's OnShow catches them up.
function Bar:UpdateButtons()
    self:EachButton(function(button, index)
        if self.pages[index].frame:IsShown() then button:Update() end
    end)
end

function Bar:UpdateUsable()
    self:EachButton(function(button, index)
        if self.pages[index].frame:IsShown() then button:UpdateUsable() end
    end)
end
