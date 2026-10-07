-- Options: Elastibar's page in Blizzard's settings window (Options > AddOns > Elastibar).
-- One page: general settings, then the bars this character sees. Per-bar settings stay in
-- Edit Mode's bar settings panel (docs/specs/options-and-minimap.md).

local _, ns = ...

local Options = {}
ns.Options = Options

local POSITIONS = { { "above", "Above the game's tooltip" }, { "below", "Below the game's tooltip" } }
local GRID_MIN, GRID_MAX = 4, 100
local ROW_HEIGHT, LIST_HEIGHT = 26, 234

local page, category, list, content, empty
local rows = {}
local refreshers = {}

local function heading(text, anchor, y)
    local fs = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
    fs:SetText(text)
    local line = page:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.15)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -4)
    line:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    return fs
end

local function label(text, anchor, y)
    local fs = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
    fs:SetText(text)
    return fs
end

-- A button showing the current choice; clicking opens a menu of choices (or cycles them if
-- Blizzard's menu isn't available).
local function choice(anchor, choices, get, set)
    local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    button:SetSize(190, 22)
    button:SetPoint("LEFT", anchor, "LEFT", 180, 0)
    local function refresh()
        for _, c in ipairs(choices) do
            if c[1] == get() then button:SetText(c[2]) end
        end
    end
    button:SetScript("OnClick", function(self)
        local ok = MenuUtil and MenuUtil.CreateContextMenu and pcall(MenuUtil.CreateContextMenu, self, function(_, root)
            for _, c in ipairs(choices) do
                root:CreateRadio(c[2], function() return get() == c[1] end, function() set(c[1]); refresh() end)
            end
        end)
        if not ok then
            for i, c in ipairs(choices) do
                if c[1] == get() then set(choices[i % #choices + 1][1]); break end
            end
            refresh()
        end
    end)
    refreshers[#refreshers + 1] = refresh
end

local function slider(anchor)
    local s = CreateFrame("Slider", nil, page, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(150, 16)
    s:SetPoint("LEFT", anchor, "LEFT", 180, 0)
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(GRID_MIN, GRID_MAX)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    local value = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("LEFT", s, "RIGHT", 10, 0)
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        ns.db.gridSize = v
        value:SetText(("%d px"):format(v))
    end)
    refreshers[#refreshers + 1] = function()
        s:SetValue(ns.Grid.Size())
        value:SetText(("%d px"):format(ns.Grid.Size()))
    end
end

local function visibilityLabel(record)
    local key = ns.RuleEditing.PresetFor(record.visibility or "show")
    for _, preset in ipairs(ns.RuleEditing.PRESETS) do
        if preset.key == key then return preset.label end
    end
    return "Custom"
end

local function rowButton(row, text, x, onClick)
    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    button:SetSize(64, 20)
    button:SetPoint("RIGHT", row, "RIGHT", x, 0)
    button:SetText(text)
    button:SetScript("OnClick", function() if row.record then onClick(row.record) end end)
    return button
end

local function makeRow(index)
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.04 or 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", 6, 0)
    row.name:SetWidth(170)
    row.name:SetJustifyH("LEFT")
    row.scope = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.scope:SetPoint("LEFT", 180, 0)
    row.size = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.size:SetPoint("LEFT", 260, 0)
    row.visibility = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.visibility:SetPoint("LEFT", 310, 0)

    local delete = rowButton(row, "Delete", -4, function(record)
        ns.Bars.Delete(record)
        Options.Refresh()
    end)
    delete:GetFontString():SetTextColor(1, 0.35, 0.35)
    rowButton(row, "Edit", -72, function(record) Options.EditBar(record) end)
    rows[index] = row
    return row
end

local function refreshList()
    local records = ns.BarStore.List(ns.db, ns.charDB)
    for index, record in ipairs(records) do
        local row = rows[index] or makeRow(index)
        row.record = record
        row.name:SetText(record.name)
        if record.scope == "account" then
            row.scope:SetText("Account")
            row.scope:SetTextColor(0.61, 0.78, 1)
        else
            row.scope:SetText("Character")
            row.scope:SetTextColor(1, 0.82, 0)
        end
        row.size:SetText(("%d x %d"):format(record.cols, record.rows))
        row.visibility:SetText(visibilityLabel(record))
        row:Show()
    end
    for index = #records + 1, #rows do
        rows[index].record = nil
        rows[index]:Hide()
    end
    content:SetHeight(math.max(1, #records * ROW_HEIGHT))
    empty:SetShown(#records == 0)
end

local function build()
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Elastibar")
    local version = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, 0)
    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    version:SetText(getMetadata and getMetadata("Elastibar", "Version") or "")

    local general = heading("General", title, -18)
    local tooltips = label("Show macro tooltip text", general, -18)
    choice(tooltips, ns.MacroTooltips.SHOWN_MODES,
        function() return ns.db.macroTooltipShown or "always" end,
        function(mode) ns.db.macroTooltipShown = mode end)
    local position = label("Macro tooltip text goes", tooltips, -16)
    choice(position, POSITIONS, ns.MacroTooltips.Position, ns.MacroTooltips.SetPosition)
    local grid = label("Snapping grid", position, -16)
    slider(grid)
    local gridHint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    gridHint:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 180, -8)
    gridHint:SetText("Hold Shift while dragging a bar to place it freely.")

    local bars = heading("Bars", grid, -40)
    local sub = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("LEFT", bars, "RIGHT", 8, 0)
    sub:SetText("this character sees. Size, layer, and visibility are set in Edit Mode.")

    list = CreateFrame("ScrollFrame", nil, page)
    list:SetPoint("TOPLEFT", bars, "BOTTOMLEFT", 0, -12)
    list:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    list:SetHeight(LIST_HEIGHT)
    content = CreateFrame("Frame", nil, list)
    content:SetSize(1, 1)
    list:SetScrollChild(content)
    list:SetScript("OnSizeChanged", function(self) content:SetWidth(self:GetWidth()) end)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * ROW_HEIGHT)))
    end)
    empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -6)
    empty:SetText("No bars yet. Create one below.")

    local function bottomButton(text, width, onClick)
        local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        button:SetSize(width, 22)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        return button
    end
    local newCharacter = bottomButton("New character bar", 140, function()
        ns.Bars.Create("character")
        Options.Refresh()
    end)
    newCharacter:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -10)
    local newAccount = bottomButton("New account bar", 140, function()
        ns.Bars.Create("account")
        Options.Refresh()
    end)
    newAccount:SetPoint("LEFT", newCharacter, "RIGHT", 6, 0)
    local openEditMode = bottomButton("Open Edit Mode", 130, function() Options.EditBar(nil) end)
    openEditMode:SetPoint("TOP", newCharacter, "TOP", 0, 0)
    openEditMode:SetPoint("RIGHT", list, "RIGHT", 0, 0)
end

function Options.Refresh()
    if not (page and content) then return end
    for _, refresh in ipairs(refreshers) do refresh() end
    refreshList()
end

-- Closes the settings window and opens Edit Mode, with the bar selected if one is given.
function Options.EditBar(record)
    if InCombatLockdown() then
        ns.Print("Can't open Edit Mode in combat.")
        return
    end
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    ns.EditMode.Open(record and ns.Bars.Get(record.id))
end

function Options.Open()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    end
end

page = CreateFrame("Frame", "ElastibarOptions")
page:Hide()
page:SetScript("OnShow", function()
    if not content then build() end
    Options.Refresh()
end)
if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    category = Settings.RegisterCanvasLayoutCategory(page, "Elastibar")
    Settings.RegisterAddOnCategory(category)
end
