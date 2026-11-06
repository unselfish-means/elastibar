-- PageEditor: the window that sets when one page shows, docked beside the bar settings
-- panel. It opens from a page's label in the Edit Mode stack (PageStack.lua).
--
-- The picker answers three questions (target, alive or dead, combat) and applies on each
-- click. Anything else is typed into the condition box and applied with Enter.

local _, ns = ...

local PageEditor = {}
ns.PageEditor = PageEditor

local WIDTH, INNER = 340, 312
local GREY, ORANGE = "|cff888888", "|cffff8800"

local frame, edit, status
local answerButtons = {} -- [questionKey] = { [answerKey] = button }
local current, currentIndex

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

local function page()
    return current and current.record and current.record.pages[currentIndex]
end

local function refresh(problems)
    local p = page()
    if not p then return end
    local pages = current.record.pages
    frame.title:SetText(("Page %d of %d: %s"):format(currentIndex, #pages, current.record.name))
    local condition = p.condition or ""
    if not edit:HasFocus() then edit:SetText(condition) end

    local answers = ns.Pages.ToPicker(condition)
    for questionKey, buttons in pairs(answerButtons) do
        for answerKey, button in pairs(buttons) do
            if answers and answers[questionKey] == answerKey then button:LockHighlight() else button:UnlockHighlight() end
            button:SetEnabled(not (questionKey == "state" and answers and answers.target == "none"))
        end
    end

    local lines = {}
    if not answers then lines[1] = GREY .. "Custom condition. Pick answers above to replace it.|r" end
    for _, problem in ipairs(problems or {}) do lines[#lines + 1] = ORANGE .. problem:gsub("^%l", string.upper) .. "|r" end
    local always = ns.Pages.FirstAlways(pages)
    if always and currentIndex > always then
        lines[#lines + 1] = ORANGE .. ("Never shown: page %d always matches. Give it a condition or move this page up."):format(always) .. "|r"
    elseif always == currentIndex and currentIndex < #pages then
        lines[#lines + 1] = ORANGE .. "This page always matches, so the pages below it never show.|r"
    end
    status:SetText(table.concat(lines, "\n"))
    frame.up:SetEnabled(currentIndex > 1)
    frame.down:SetEnabled(currentIndex < #pages)
    frame.delete:SetEnabled(#pages > 1)
    frame:SetHeight(frame.statusTop + math.max(status:GetStringHeight(), 1) + 52)
    if current.stack then ns.PageStack.Highlight(current) end
end

local function setCondition(condition)
    if not page() then return end
    local ok, problems = ns.Bars.SetPageCondition(current.record, currentIndex, condition)
    if ok then refresh(problems) end
end

local function pick(questionKey, answerKey)
    local answers = ns.Pages.ToPicker(page().condition) or { target = "any", state = "any", combat = "any" }
    answers[questionKey] = answerKey
    edit:ClearFocus()
    setCondition(ns.Pages.FromPicker(answers))
end

local function build()
    frame = CreateFrame("Frame", "ElastibarPageEditor", UIParent, "BackdropTemplate")
    frame:SetWidth(WIDTH)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    backdrop(frame, 0.05, 0.05, 0.08, 0.94)
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName())
    frame:SetScript("OnHide", function()
        local bar = current
        current, currentIndex = nil, nil
        if bar and bar.stack then ns.PageStack.Highlight(bar) end
    end)

    frame.title = label("", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 14, -12)
    frame.title:SetPoint("RIGHT", -30, 0)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetWordWrap(false)
    local hint = label("The first page that matches is shown. If none match, the bar is hidden.", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
    hint:SetWidth(INNER)
    hint:SetJustifyH("LEFT")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local y = -62
    for _, question in ipairs(ns.Pages.PICKER) do
        label(question.label, "GameFontHighlight"):SetPoint("TOPLEFT", 14, y - 3)
        answerButtons[question.key] = {}
        local x = 84
        for _, answer in ipairs(question.answers) do
            local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            button:SetText(answer.label)
            button:SetSize(button:GetFontString():GetStringWidth() + 18, 20)
            button:SetPoint("TOPLEFT", x, y)
            x = x + button:GetWidth() + 2
            button:SetScript("OnClick", function() pick(question.key, answer.key) end)
            answerButtons[question.key][answer.key] = button
        end
        y = y - 24
    end

    y = y - 8
    label("Condition"):SetPoint("TOPLEFT", 14, y)
    local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box:SetSize(INNER, 28)
    box:SetPoint("TOPLEFT", 14, y - 16)
    backdrop(box, 0, 0, 0, 1)
    edit = CreateFrame("EditBox", nil, box)
    edit:SetPoint("TOPLEFT", 8, -6)
    edit:SetPoint("BOTTOMRIGHT", -8, 6)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetMaxLetters(255)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        refresh() -- drop the unapplied text
    end)
    edit:SetScript("OnEnterPressed", function(self)
        local text = self:GetText():gsub("^%s+", ""):gsub("%s+$", "")
        local problems = ns.Pages.Check(text, ns.RuleEditing)
        if #problems > 0 then
            status:SetText(ORANGE .. "Not applied: " .. table.concat(problems, "; ") .. "|r")
            return
        end
        self:ClearFocus()
        setCondition(text)
    end)
    local enterHint = label("Press Enter to apply. Empty means always.", "GameFontDisableSmall")
    enterHint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -3)

    frame.statusTop = -(y - 16 - 28 - 20)
    status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetWidth(INNER)
    status:SetJustifyH("LEFT")
    status:SetSpacing(3)
    status:SetPoint("TOPLEFT", 14, -frame.statusTop)

    local function actionButton(text, onClick)
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(80, 22)
        button:SetText(text)
        button:SetScript("OnClick", function() if page() then onClick() end end)
        return button
    end
    frame.up = actionButton("Move up", function()
        currentIndex = ns.Bars.MovePage(current.record, currentIndex, -1)
        refresh()
    end)
    frame.up:SetPoint("BOTTOMLEFT", 12, 12)
    frame.down = actionButton("Move down", function()
        currentIndex = ns.Bars.MovePage(current.record, currentIndex, 1)
        refresh()
    end)
    frame.down:SetPoint("LEFT", frame.up, "RIGHT", 4, 0)
    frame.delete = actionButton("Delete page", function()
        if ns.Bars.DeletePage(current.record, currentIndex) then
            currentIndex = math.min(currentIndex, #current.record.pages)
            refresh()
        end
    end)
    frame.delete:SetPoint("BOTTOMRIGHT", -12, 12)
    frame.delete:GetFontString():SetTextColor(1, 0.35, 0.35)
end

-- Docks beside the settings panel: to its right if there's room, otherwise to its left.
function PageEditor.Dock()
    if not PageEditor.IsOpen() then return end
    local anchor = frame.anchor
    local roomRight = UIParent:GetWidth() - (anchor:GetRight() or 0)
    frame:ClearAllPoints()
    if roomRight >= WIDTH + 4 or roomRight >= (anchor:GetLeft() or 0) then
        frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    else
        frame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0)
    end
end

-- Opens the editor for one of a bar's pages, docked beside the settings panel.
function PageEditor.Open(bar, index)
    if not frame then build() end
    ns.VisibilityEditor.Close() -- they share the spot beside the panel
    current, currentIndex = bar, index
    local panel = ns.BarSettings.Panel()
    frame.anchor = panel and panel:IsShown() and panel or ns.PageStack.Anchor(bar) -- outside Edit Mode
    frame:Show()
    PageEditor.Dock()
    edit:ClearFocus()
    refresh()
end

-- The page index being edited on this bar, or nil.
function PageEditor.Editing(bar)
    if PageEditor.IsOpen() and current == bar then return currentIndex end
end

function PageEditor.IsOpen()
    return frame ~= nil and frame:IsShown()
end

function PageEditor.Close()
    if frame then frame:Hide() end
end
