-- PageStack: what the selected bar shows in Edit Mode. The bar is expanded (Bar:SetExpanded),
-- so every page is shown stacked below it, and this draws a label left of each page saying
-- when it shows, plus a footer with Add page. Clicking a label opens the page editor.
--
-- The page showing right now outside Edit Mode has a gold label, so you can try a target and
-- see which page it picks.

local _, ns = ...

local PageStack = {}
ns.PageStack = PageStack

local LABEL_WIDTH, LABEL_HEIGHT = 170, 22
local GOLD, GREY = "|cffffd100", "|cff888888"

local function backdrop(f)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
end

local function makeLabel(stack)
    local label = CreateFrame("Button", nil, stack.holder, "BackdropTemplate")
    label:SetSize(LABEL_WIDTH, LABEL_HEIGHT)
    backdrop(label)
    label.text = label:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label.text:SetPoint("LEFT", 7, 0)
    label.text:SetPoint("RIGHT", -7, 0)
    label.text:SetJustifyH("LEFT")
    label.text:SetWordWrap(false)
    label:SetScript("OnClick", function(self) ns.PageEditor.Open(stack.bar, self.index) end)
    label:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(("Page %d"):format(self.index))
        GameTooltip:AddLine(self.condition == "" and "Always matches" or self.condition, 0.61, 0.78, 1, true)
        GameTooltip:AddLine("Click to change when this page shows.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    label:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return label
end

local function build(bar)
    local stack = { bar = bar, labels = {} }
    -- A child of the bar, so it follows the bar's scale and layer.
    local holder = CreateFrame("Frame", nil, bar.frame)
    holder:SetAllPoints(bar.frame)
    holder:SetFrameLevel(bar.frame:GetFrameLevel() + 30)
    holder:Hide()
    stack.holder = holder

    local footer = CreateFrame("Frame", nil, holder)
    footer:SetSize(300, 24)
    stack.footer = footer
    local add = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    add:SetSize(90, 22)
    add:SetPoint("LEFT", 0, 0)
    add:SetText("Add page")
    add:SetScript("OnClick", function()
        local index = ns.Bars.AddPage(bar.record)
        if index then ns.PageEditor.Open(bar, index) end
    end)
    stack.note = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    stack.note:SetPoint("LEFT", add, "RIGHT", 8, 0)

    -- The current page changes with targets and combat, which have no single event.
    local since = 0
    holder:SetScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if since < 0.2 then return end
        since = 0
        PageStack.Highlight(bar)
    end)
    bar.stack = stack
    return stack
end

-- Gold border on the page showing right now, and a brighter fill on the page being edited.
function PageStack.Highlight(bar)
    local stack = bar.stack
    if not stack or not bar.record then return end
    local current, editing = bar:CurrentPage(), ns.PageEditor.Editing(bar)
    for index, label in ipairs(stack.labels) do
        if label:IsShown() then
            if index == current then label:SetBackdropBorderColor(1, 0.82, 0, 1) else label:SetBackdropBorderColor(0.18, 0.31, 0.44, 1) end
            if index == editing then label:SetBackdropColor(0.16, 0.26, 0.36, 1) else label:SetBackdropColor(0.08, 0.13, 0.17, 1) end
        end
    end
end

-- Rebuilds the labels and footer from the bar's pages.
function PageStack.Refresh(bar)
    local stack = bar.stack
    if not stack or not bar.record then return end
    local pages = bar.record.pages
    local always = ns.Pages.FirstAlways(pages)
    for index, page in ipairs(pages) do
        local label = stack.labels[index] or makeLabel(stack)
        stack.labels[index] = label
        label.index, label.condition = index, page.condition or ""
        local text = ("%d · %s"):format(index, ns.Pages.Summary(label.condition))
        if always and index > always then text = GREY .. text .. " (never shown)|r" end
        label.text:SetText(text)
        label.text:SetTextColor(0.61, 0.78, 1)
        label:ClearAllPoints()
        label:SetPoint("RIGHT", bar.pages[index].frame, "LEFT", -8, 0)
        label:Show()
    end
    for index = #pages + 1, #stack.labels do stack.labels[index]:Hide() end

    stack.footer:ClearAllPoints()
    stack.footer:SetPoint("TOPLEFT", bar.pages[#pages].frame, "BOTTOMLEFT", 0, -8)
    if always then
        stack.note:SetText(("Page %d always matches."):format(always))
    else
        stack.note:SetText("Otherwise the bar is " .. GOLD .. "hidden|r.")
    end
    PageStack.Highlight(bar)
end

-- Expands the bar and shows the stack. Edit Mode calls this when a bar is selected.
function PageStack.Show(bar)
    if InCombatLockdown() then return end
    local stack = bar.stack or build(bar)
    bar:SetExpanded(true)
    PageStack.Refresh(bar)
    stack.holder:Show()
end

function PageStack.Hide(bar)
    if bar.stack then bar.stack.holder:Hide() end
    if not InCombatLockdown() then bar:SetExpanded(false) end
end
