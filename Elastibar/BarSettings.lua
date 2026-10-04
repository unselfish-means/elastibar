-- BarSettings: the panel that opens when a bar is selected in Edit Mode.
-- It replaces the right-click menu from the original spec, matching how Blizzard's own
-- frames work in Edit Mode: Scale, Columns, Rows, Layer, then Visibility, Rename, Delete.

local _, ns = ...

local BarSettings = {}
ns.BarSettings = BarSettings

local LAYER_LABELS = { behind = "Behind", normal = "Normal", above = "Above UI", top = "Top" }

local panel, current
local refreshing = false -- set while syncing controls to the bar, so their callbacks don't write back

local function makeSlider(label, minValue, maxValue, step, format, onChange)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(240, 24)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", 0, 0)
    text:SetText(label)

    local slider = CreateFrame("Slider", nil, row, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(120, 16)
    slider:SetPoint("LEFT", 70, 0)
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    value:SetWidth(42)
    value:SetJustifyH("RIGHT")

    slider:SetScript("OnValueChanged", function(_, v)
        value:SetText(format(v))
        if not refreshing and current and not InCombatLockdown() then onChange(current, v) end
    end)
    row.Set = function(_, v)
        slider:SetValue(v)
        value:SetText(format(v))
    end
    return row
end

-- Rename and visibility use Blizzard's popup with an edit box. The visibility box is a
-- stand-in until the rule editor (build step 5).
local function popupEditBox(popup)
    return popup.editBox or popup.EditBox
end

StaticPopupDialogs.ELASTIBAR_RENAME = {
    text = "Rename bar",
    button1 = ACCEPT, button2 = CANCEL,
    hasEditBox = true,
    OnShow = function(self) popupEditBox(self):SetText(self.data.name); popupEditBox(self):HighlightText() end,
    OnAccept = function(self) ns.Bars.Rename(self.data, popupEditBox(self):GetText()) end,
    EditBoxOnEnterPressed = function(box) local p = box:GetParent(); ns.Bars.Rename(p.data, box:GetText()); p:Hide() end,
    EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs.ELASTIBAR_VISIBILITY = {
    text = "Visibility rule for %s\n(for example: [combat] show; hide)",
    button1 = ACCEPT, button2 = CANCEL,
    hasEditBox = true, editBoxWidth = 350,
    OnShow = function(self) popupEditBox(self):SetText(self.data.visibility or "show") end,
    OnAccept = function(self) ns.Bars.SetVisibility(self.data, popupEditBox(self):GetText()) end,
    EditBoxOnEnterPressed = function(box) local p = box:GetParent(); ns.Bars.SetVisibility(p.data, box:GetText()); p:Hide() end,
    EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local function setLayer(bar, layer)
    if InCombatLockdown() then return end
    bar:SetLayer(layer)
    BarSettings.Refresh(bar)
end

-- Layer choice uses Blizzard's menu if available, otherwise each click cycles the layers.
local function openLayerMenu(button)
    local bar = current
    if not bar then return end
    local ok = MenuUtil and MenuUtil.CreateContextMenu and pcall(MenuUtil.CreateContextMenu, button, function(_, root)
        for _, layer in ipairs(ns.BarStore.LAYERS) do
            root:CreateRadio(LAYER_LABELS[layer],
                function() return bar.record.layer == layer end,
                function() setLayer(bar, layer) end)
        end
    end)
    if not ok then
        local layers, index = ns.BarStore.LAYERS, 1
        for i, layer in ipairs(layers) do
            if layer == bar.record.layer then index = i end
        end
        setLayer(bar, layers[index % #layers + 1])
    end
end

local function build()
    panel = CreateFrame("Frame", "ElastibarBarSettings", UIParent, "BackdropTemplate")
    panel:SetSize(264, 236)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.08, 0.94)
    panel:Hide()

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 14, -12)
    panel.scope = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.scope:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -3)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() ns.EditMode.Deselect() end)

    panel.scale = makeSlider("Scale", 50, 200, 10, function(v) return ("%d%%"):format(v) end,
        function(bar, v) bar:SetScaleKeepingCenter(v / 100) end)
    panel.scale:SetPoint("TOPLEFT", 14, -54)
    panel.cols = makeSlider("Columns", 1, ns.BarStore.MAX_SIZE, 1, function(v) return ("%d"):format(v) end,
        function(bar, v) bar:SetGridSize(v, bar.record.rows) end)
    panel.cols:SetPoint("TOPLEFT", panel.scale, "BOTTOMLEFT", 0, -8)
    panel.rows = makeSlider("Rows", 1, ns.BarStore.MAX_SIZE, 1, function(v) return ("%d"):format(v) end,
        function(bar, v) bar:SetGridSize(bar.record.cols, v) end)
    panel.rows:SetPoint("TOPLEFT", panel.cols, "BOTTOMLEFT", 0, -8)

    local layerLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    layerLabel:SetPoint("TOPLEFT", panel.rows, "BOTTOMLEFT", 0, -14)
    layerLabel:SetText("Layer")
    panel.layer = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.layer:SetSize(120, 22)
    panel.layer:SetPoint("LEFT", layerLabel, "LEFT", 70, 0)
    panel.layer:SetScript("OnClick", openLayerMenu)

    local function actionButton(text, x, onClick)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(76, 22)
        button:SetPoint("BOTTOMLEFT", x, 12)
        button:SetText(text)
        button:SetScript("OnClick", function() if current then onClick(current) end end)
        return button
    end
    actionButton("Visibility", 12, function(bar)
        StaticPopup_Show("ELASTIBAR_VISIBILITY", bar.record.name, nil, bar.record)
    end)
    actionButton("Rename", 94, function(bar)
        StaticPopup_Show("ELASTIBAR_RENAME", nil, nil, bar.record)
    end)
    local delete = actionButton("Delete", 176, function(bar) ns.Bars.Delete(bar.record) end)
    delete:GetFontString():SetTextColor(1, 0.35, 0.35)
end

function BarSettings.Refresh(bar)
    if not panel or bar ~= current then return end
    local record = bar.record
    refreshing = true
    panel.title:SetText(record.name)
    panel.scope:SetText(record.scope == "account" and "Account bar" or "Character bar")
    panel.scale:Set(math.floor((record.scale or 1) * 100 + 0.5))
    panel.cols:Set(record.cols)
    panel.rows:Set(record.rows)
    panel.layer:SetText(LAYER_LABELS[record.layer] or LAYER_LABELS.normal)
    refreshing = false
end

function BarSettings.Open(bar)
    if not panel then build() end
    current = bar
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT", bar.frame, "TOPRIGHT", 8, 8)
    BarSettings.Refresh(bar)
    panel:Show()
end

function BarSettings.Close()
    current = nil
    if panel then panel:Hide() end
end
