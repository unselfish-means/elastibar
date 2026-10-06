-- VisibilityEditor: the rule editor window, docked beside the bar settings panel.
--
-- Edits are a draft until Apply. The draft is saved on the bar record with every keystroke,
-- so closing the window, pressing Escape, or reloading never loses it. The preview evaluates
-- the draft without applying it, and only once every condition in it is known: the game
-- prints "Unknown macro option" to chat for anything else, including half-typed words.

local _, ns = ...

local VisibilityEditor = {}
ns.VisibilityEditor = VisibilityEditor

local WIDTH, INNER = 380, 352
local GOLD, GREY, ORANGE, BLUE, GREEN = "|cffffd100", "|cff888888", "|cffff8800", "|cff9cc8ff", "|cff3fdc3f"

local SNIPPETS = {
    { label = "When", items = {
        { "combat", "In combat" }, { "nocombat", "Out of combat" }, { "mounted", "Mounted" },
        { "flying", "Flying" }, { "swimming", "Swimming" }, { "stealth", "Stealthed" },
        { "indoors", "Indoors" }, { "resting", "Resting in an inn or city" },
    } },
    { label = "Target", items = {
        { "exists", "You have a target" }, { "harm", "Your target is hostile" },
        { "help", "Your target is friendly" }, { "dead", "Your target is dead" },
        { "pet", "Your pet is out" }, { "group", "You're in a party or raid" }, { "group:raid", "You're in a raid" },
    } },
    { label = "Keys", items = {
        { "mod:shift", "Shift is held" }, { "mod:ctrl", "Ctrl is held" }, { "mod:alt", "Alt is held" },
    } },
}

local frame, edit, scroll, status, draftLabel
local presetButtons, rowLabels, chips = {}, {}, {}
local current, specInfo
local sinceUpdate = 0

local function backdrop(f, r, g, b, a)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(r, g, b, a)
end

local function label(text, template)
    local fs = frame:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetText(text)
    return fs
end

local function saveDraft()
    if not current then return end
    local text = edit:GetText()
    current.record.visibilityDraft = (text ~= (current.record.visibility or "show")) and text or nil
end

-- What the preview needs from the draft: problems, and the rule the game would receive.
local function analyse()
    local text = edit:GetText()
    local problems = ns.RuleEditing.Check(text)
    local translated, specProblems = ns.Conditionals.Translate(text, specInfo)
    if translated == "" then translated = "hide" end
    return text, problems, translated, specProblems
end

local function refreshStatus()
    if not current then return end
    local text, problems, translated, specProblems = analyse()
    local lines = {}
    if #problems > 0 then
        lines[1] = ORANGE .. "Can't preview: " .. table.concat(problems, "; ") .. "|r"
    else
        local shown = SecureCmdOptionParse(translated) == "show"
        lines[1] = "Right now: " .. (shown and (GREEN .. "shown|r") or (GREY .. "hidden|r"))
        if text:lower():find("spec:[^%],;]*%a") then -- spec names were translated
            lines[#lines + 1] = BLUE .. "The game receives: " .. translated .. "|r"
        end
    end
    for _, problem in ipairs(specProblems) do lines[#lines + 1] = ORANGE .. problem:gsub("^%l", string.upper) .. "|r" end
    if translated:find("spec:[%d/]*2") and not (specInfo.points and specInfo.points[2]) then
        lines[#lines + 1] = ORANGE .. "Secondary spec is locked, so spec:2 never matches yet.|r"
    end
    status:SetText(table.concat(lines, "\n"))

    local dirty = text ~= (current.record.visibility or "show")
    draftLabel:SetText(dirty and (GOLD .. "Unsaved draft|r") or (GREY .. "Applied|r"))
    local preset = ns.RuleEditing.PresetFor(text)
    for _, button in ipairs(presetButtons) do
        if button.key == preset or (button.key == nil and not preset) then button:LockHighlight() else button:UnlockHighlight() end
    end
    frame:SetHeight(frame.statusTop + status:GetStringHeight() + 52)
end

local function setText(text, cursor)
    edit:SetText(text)
    edit:SetCursorPosition(cursor or #text)
    saveDraft()
    refreshStatus()
end

local function makeChip(code, description)
    local chip = CreateFrame("Button", nil, frame, "BackdropTemplate")
    chip:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    chip:SetBackdropColor(0.08, 0.13, 0.17, 1)
    chip:SetBackdropBorderColor(0.18, 0.31, 0.44, 1)
    chip.text = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chip.text:SetPoint("CENTER")
    chip.text:SetTextColor(0.61, 0.78, 1)
    chip:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.82, 0)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.code)
        GameTooltip:AddLine(self.description, 1, 1, 1, true)
        GameTooltip:AddLine("Click to add it to the rule.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    chip:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.18, 0.31, 0.44, 1)
        GameTooltip:Hide()
    end)
    chip:SetScript("OnClick", function(self)
        setText(ns.RuleEditing.InsertSnippet(edit:GetText(), edit:GetCursorPosition(), self.code))
        edit:SetFocus()
    end)
    chip.code, chip.description = code, description
    chip.text:SetText(code)
    chip:SetSize(chip.text:GetStringWidth() + 14, 18)
    return chip
end

-- Lays out the snippet rows from y downwards, wrapping chips to the window width.
-- The Spec row depends on the character's talent trees, so it's rebuilt on every open.
local function layoutSnippets(y)
    for _, chip in ipairs(chips) do chip:Hide() end
    for _, fs in ipairs(rowLabels) do fs:Hide() end
    local rows = { unpack(SNIPPETS) }
    local spec = { label = "Spec", items = { { "spec:1", "Your Primary spec is active" }, { "spec:2", "Your Secondary spec is active" } } }
    for _, name in ipairs(specInfo.treeNames or {}) do
        spec.items[#spec.items + 1] = { "spec:" .. ns.Conditionals.Normalize(name),
            ("The active spec has the most points in %s"):format(name) }
    end
    rows[#rows + 1] = spec

    local used = 0
    for index, row in ipairs(rows) do
        local fs = rowLabels[index] or label("", "GameFontDisableSmall")
        rowLabels[index] = fs
        fs:SetText(row.label)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", 14, y - 3)
        fs:Show()
        local x = 62
        for _, item in ipairs(row.items) do
            used = used + 1
            local chip = chips[used]
            if chip then
                chip.code, chip.description = item[1], item[2]
                chip.text:SetText(item[1])
                chip:SetSize(chip.text:GetStringWidth() + 14, 18)
            else
                chip = makeChip(item[1], item[2])
                chips[used] = chip
            end
            if x + chip:GetWidth() > WIDTH - 14 then
                x, y = 62, y - 21
            end
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", x, y)
            chip:Show()
            x = x + chip:GetWidth() + 4
        end
        y = y - 24
    end
    return y
end

local function build()
    frame = CreateFrame("Frame", "ElastibarVisibilityEditor", UIParent, "BackdropTemplate")
    frame:SetWidth(WIDTH)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    backdrop(frame, 0.05, 0.05, 0.08, 0.94)
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName()) -- Escape closes it; the draft is already saved
    frame:SetScript("OnHide", function() current = nil end)

    frame.title = label("", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 14, -12)
    local hint = label("First matching clause wins. If none match, the bar is hidden.", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    label("Presets"):SetPoint("TOPLEFT", 14, -52)
    local x, y = 14, -68
    local presets = { unpack(ns.RuleEditing.PRESETS) }
    presets[#presets + 1] = { label = "Custom" }
    for _, preset in ipairs(presets) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetText(preset.label)
        button:SetSize(button:GetFontString():GetStringWidth() + 20, 20)
        if x + button:GetWidth() > WIDTH - 14 then x, y = 14, y - 22 end
        button:SetPoint("TOPLEFT", x, y)
        x = x + button:GetWidth() + 2
        button.key = preset.key
        button:SetScript("OnClick", function()
            if preset.rule then setText(preset.rule) end
            edit:SetFocus()
        end)
        presetButtons[#presetButtons + 1] = button
    end

    y = y - 30
    label("Rule"):SetPoint("TOPLEFT", 14, y)
    local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box:SetSize(INNER, 70)
    box:SetPoint("TOPLEFT", 14, y - 16)
    backdrop(box, 0, 0, 0, 1)
    scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -8, 8)
    edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(INNER - 16)
    edit:SetMaxLetters(1000)
    scroll:SetScrollChild(edit)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, edit:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 14)))
    end)
    edit:SetScript("OnCursorChanged", function(_, _, cursorY, _, height) -- keep the cursor in view
        local top, visible = -cursorY, scroll:GetHeight()
        if top < scroll:GetVerticalScroll() then
            scroll:SetVerticalScroll(top)
        elseif top + height > scroll:GetVerticalScroll() + visible then
            scroll:SetVerticalScroll(top + height - visible)
        end
    end)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnTextChanged", function(_, userInput)
        if userInput then
            saveDraft()
            refreshStatus()
        end
    end)

    frame.snippetsTop = y - 96
    label("Insert"):SetPoint("TOPLEFT", 14, frame.snippetsTop)

    status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetWidth(INNER)
    status:SetJustifyH("LEFT")
    status:SetSpacing(3)

    draftLabel = label("", "GameFontHighlightSmall")
    draftLabel:SetPoint("BOTTOMLEFT", 14, 18)
    local apply = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    apply:SetSize(76, 22)
    apply:SetPoint("BOTTOMRIGHT", -12, 12)
    apply:SetText("Apply")
    apply:SetScript("OnClick", function()
        if not current then return end
        local record = current.record
        if ns.Bars.SetVisibility(record, edit:GetText(), true) then
            record.visibilityDraft = nil
            edit:ClearFocus()
            refreshStatus()
        end
    end)
    local revert = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    revert:SetSize(76, 22)
    revert:SetPoint("RIGHT", apply, "LEFT", -4, 0)
    revert:SetText("Revert")
    revert:SetScript("OnClick", function()
        if current then setText(current.record.visibility or "show") end
    end)

    -- Combat, modifier keys, and targets change without the text changing.
    frame:SetScript("OnUpdate", function(_, elapsed)
        sinceUpdate = sinceUpdate + elapsed
        if sinceUpdate < 0.2 then return end
        sinceUpdate = 0
        refreshStatus()
    end)
end

-- Opens the editor for a bar, docked to the right of anchor (the settings panel).
function VisibilityEditor.Open(bar, anchor)
    if not frame then build() end
    current = bar
    specInfo = ns.SpecTrees.Get()
    local record = bar.record
    frame.title:SetText("Visibility: " .. record.name)
    frame.statusTop = -layoutSnippets(frame.snippetsTop - 18) + 4
    status:ClearAllPoints()
    status:SetPoint("TOPLEFT", 14, -frame.statusTop)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    frame:Show()
    local text = record.visibilityDraft or record.visibility or "show"
    edit:SetText(text)
    edit:SetCursorPosition(#text)
    refreshStatus()
end

function VisibilityEditor.IsOpen()
    return frame ~= nil and frame:IsShown()
end

function VisibilityEditor.Close()
    if frame then frame:Hide() end
end
