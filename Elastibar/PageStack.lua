-- PageStack: a bar with its pages open for editing. The bar is expanded (Bar:SetExpanded),
-- so every page is shown stacked below it, on a dark panel, with a label left of each page
-- saying when it shows and a footer with Add page. Clicking a label opens the page editor.
--
-- It opens in two ways:
--   - in Edit Mode, when a bar is selected;
--   - outside Edit Mode, where the spellbook can be opened (the game blocks it in Edit Mode):
--     from "Use spellbook" in Edit Mode, which keeps the pages open once Edit Mode closes,
--     or with /eb pages <bar>. Done closes it, and so does entering combat.
--
-- The page showing right now outside Edit Mode has a gold label, so you can try a target and
-- see which page it picks.

local _, ns = ...

local PageStack = {}
ns.PageStack = PageStack

local LABEL_WIDTH, LABEL_HEIGHT, LABEL_GAP, PAD = 170, 22, 8, 10
local LEFT = -(LABEL_WIDTH + LABEL_GAP) -- where the labels start, from the bar's left edge
local GOLD, GREY = "|cffffd100", "|cff888888"

local openBar -- the bar open outside Edit Mode
local pendingBar -- the bar to keep open once Edit Mode closes

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

    -- The dark panel is a texture on the bar itself, so it draws behind the page buttons.
    local panel = bar.frame:CreateTexture(nil, "BACKGROUND")
    panel:SetColorTexture(0.03, 0.03, 0.05, 0.88)
    panel:Hide()
    stack.panel = panel

    -- A child of the bar, so it follows the bar's scale and layer.
    local holder = CreateFrame("Frame", nil, bar.frame)
    holder:SetAllPoints(bar.frame)
    holder:SetFrameLevel(bar.frame:GetFrameLevel() + 30)
    holder:Hide()
    stack.holder = holder

    stack.title = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stack.title:SetPoint("BOTTOMLEFT", bar.frame, "TOPLEFT", LEFT, 8)
    stack.title:SetJustifyH("LEFT")

    local footer = CreateFrame("Frame", nil, holder)
    stack.footer = footer
    local add = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    add:SetSize(90, 22)
    add:SetPoint("TOPLEFT", 0, 0)
    add:SetText("Add page")
    add:SetScript("OnClick", function()
        local index = ns.Bars.AddPage(bar.record)
        if index then ns.PageEditor.Open(bar, index) end
    end)
    stack.second = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    stack.second:SetSize(110, 22)
    stack.second:SetPoint("LEFT", add, "RIGHT", 4, 0)
    stack.second:SetScript("OnClick", function()
        if stack.mode == "standalone" then
            PageStack.Close(bar)
        else
            pendingBar = bar
            PageStack.Refresh(bar)
        end
    end)
    stack.note = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    stack.note:SetPoint("TOPLEFT", add, "BOTTOMLEFT", 0, -6)
    stack.note:SetJustifyH("LEFT")

    panel:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", LEFT - PAD, 30)
    panel:SetPoint("RIGHT", bar.frame, "RIGHT", PAD, 0)
    panel:SetPoint("BOTTOM", stack.note, "BOTTOM", 0, -PAD)

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

-- The region the page editor docks beside when the bar settings panel isn't open.
function PageStack.Anchor(bar)
    return bar.stack and bar.stack.panel
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
    stack.title:SetText("Pages: " .. bar.record.name)
    for index, page in ipairs(pages) do
        local label = stack.labels[index] or makeLabel(stack)
        stack.labels[index] = label
        label.index, label.condition = index, page.condition or ""
        local text = ("%d · %s"):format(index, ns.Pages.Summary(label.condition))
        if always and index > always then text = GREY .. text .. " (never shown)|r" end
        label.text:SetText(text)
        label.text:SetTextColor(0.61, 0.78, 1)
        label:ClearAllPoints()
        label:SetPoint("RIGHT", bar.pages[index].frame, "LEFT", -LABEL_GAP, 0)
        label:Show()
    end
    for index = #pages + 1, #stack.labels do stack.labels[index]:Hide() end

    local width = -LEFT + bar.frame:GetWidth()
    stack.footer:SetSize(width, 22)
    stack.footer:ClearAllPoints()
    stack.footer:SetPoint("TOPLEFT", bar.pages[#pages].frame, "BOTTOMLEFT", LEFT, -PAD)
    stack.note:SetWidth(width)

    local lines = {}
    lines[1] = always and ("Page %d always matches."):format(always) or ("If no page matches, the bar is " .. GOLD .. "hidden|r.")
    if stack.mode == "standalone" then
        stack.second:SetText("Done")
        lines[2] = "Drag spells here from your spellbook, bags, or macros."
    else
        stack.second:SetText("Use spellbook")
        if pendingBar == bar then
            lines[2] = GOLD .. "Close Edit Mode and these pages stay open, so you can use your spellbook.|r"
        else
            lines[2] = "The spellbook can't open in Edit Mode. Use spellbook keeps these pages open after it."
        end
    end
    stack.note:SetText(table.concat(lines, "\n"))
    PageStack.Highlight(bar)
end

local function show(bar, mode)
    local stack = bar.stack or build(bar)
    stack.mode = mode
    bar:SetExpanded(true)
    PageStack.Refresh(bar)
    stack.panel:Show()
    stack.holder:Show()
end

local function hide(bar)
    if bar.stack then
        bar.stack.holder:Hide()
        bar.stack.panel:Hide()
    end
    if ns.PageEditor.Editing(bar) then ns.PageEditor.Close() end
    if not InCombatLockdown() then bar:SetExpanded(false) end
end

-- Edit Mode: shows the pages of the selected bar, and hides them when it's deselected.
function PageStack.Show(bar)
    if InCombatLockdown() then return end
    if openBar then PageStack.Close(openBar) end
    if pendingBar ~= bar then pendingBar = nil end -- Use spellbook was for another bar
    show(bar, "editmode")
end

function PageStack.Hide(bar)
    if openBar ~= bar then hide(bar) end
end

-- Outside Edit Mode: opens a bar's pages, closing any other bar's.
function PageStack.Open(bar)
    if not bar.record then return end -- deleted
    if InCombatLockdown() then
        ns.Print("Can't change pages in combat.")
        return
    end
    if openBar and openBar ~= bar then PageStack.Close(openBar) end
    openBar = bar
    show(bar, "standalone")
end

function PageStack.Close(bar)
    if openBar == bar then openBar = nil end
    hide(bar)
end

function PageStack.IsOpen(bar)
    return openBar == bar
end

-- Edit Mode is closing: returns the bar whose pages should stay open, if any.
function PageStack.TakePending()
    local bar = pendingBar
    pendingBar = nil
    return bar
end

-- Combat closes the pages. The lockdown starts after this event, so the bar can still collapse.
ns.On("PLAYER_REGEN_DISABLED", function()
    if openBar then PageStack.Close(openBar) end
end)
