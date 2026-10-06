-- MacroTooltipEditor: a box docked to Blizzard's macro window for writing the selected macro's
-- custom tooltip. It's saved with every keystroke, like the visibility editor's draft.
--
-- The macro window (Blizzard_MacroUI) loads on demand. The editor reads the selected macro's
-- name from the window rather than hooking its selection code, which differs between clients.

local _, ns = ...

local WIDTH = 260
local GREY = "|cff888888"

local panel, edit, owner
local macroName -- the macro being edited, or nil

local function selectedName()
    local fs = _G.MacroFrameSelectedMacroName or (MacroFrame and MacroFrame.SelectedMacroName)
    local name = fs and fs:GetText()
    if name and name ~= "" and GetMacroIndexByName(name) > 0 then return name end
    return nil
end

local function load(name)
    macroName = name
    edit:ClearFocus()
    if not name then
        edit:SetText("")
        edit:Disable()
        owner:SetText(GREY .. "Select a macro to write its tooltip.|r")
        return
    end
    edit:Enable()
    edit:SetText(ns.MacroTooltips.Get(name) or "")
    local account = GetMacroIndexByName(name) <= MAX_ACCOUNT_MACROS
    owner:SetText(account and "|cffffd100Account macro: every character sees this tooltip.|r"
        or (GREY .. "Character macro: only this character sees it.|r"))
end

local function build()
    panel = CreateFrame("Frame", "ElastibarMacroTooltipEditor", MacroFrame, "BackdropTemplate")
    panel:SetSize(WIDTH, 232)
    panel:SetPoint("TOPLEFT", MacroFrame, "TOPRIGHT", 4, 0)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.08, 0.94)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("Elastibar tooltip")
    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    sub:SetWidth(WIDTH - 28)
    sub:SetJustifyH("LEFT")
    sub:SetText("Shown when you hover this macro on an Elastibar bar.")

    local box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 14, -54)
    box:SetSize(WIDTH - 28, 100)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0, 0, 0, 1)
    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -8, 8)
    edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlight)
    edit:SetWidth(WIDTH - 44)
    edit:SetMaxLetters(ns.MacroTooltips.MAX_LENGTH)
    scroll:SetScrollChild(edit)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() if macroName then edit:SetFocus() end end)
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
    edit:SetScript("OnTextChanged", function(self, userInput)
        if not (userInput and macroName) then return end
        local index = GetMacroIndexByName(macroName)
        if index > 0 then
            ns.MacroTooltips.Set(ns.MacroTooltips.StoreFor(index, ns.db, ns.charDB, MAX_ACCOUNT_MACROS),
                macroName, self:GetText())
        end
    end)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)
    hint:SetWidth(WIDTH - 28)
    hint:SetJustifyH("LEFT")
    hint:SetText("Saved as you type. Leave it empty to show the spell or item the macro uses.")
    owner = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    owner:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -6)
    owner:SetWidth(WIDTH - 28)
    owner:SetJustifyH("LEFT")

    -- Follow the macro window's selection, including new, renamed, and deleted macros.
    local since = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if since < 0.2 then return end
        since = 0
        local name = selectedName()
        if name ~= macroName then load(name) end
    end)
    panel:SetScript("OnShow", function() load(selectedName()) end)
    load(selectedName())
end

local function attach()
    if panel or not MacroFrame then return end
    local ok, err = pcall(build)
    if not ok then ns.Log("macro tooltip editor failed: " .. tostring(err)) end
end

ns.On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_MacroUI" then attach() end
end)
ns.On("PLAYER_LOGIN", attach) -- in case another addon loaded the macro window first
