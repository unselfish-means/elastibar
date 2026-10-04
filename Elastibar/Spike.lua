-- Spike: one 2x2 character bar to prove custom secure buttons, drag-and-drop,
-- and translated visibility rules on WoW: Forever. Replaced by real bars later.
--
--   Drag a spell, item, or macro onto a button.
--   Drag the "Elastibar" tab to move the bar (out of combat).
--   /eb vis <rule>   set the visibility rule, e.g. /eb vis [combat] show; hide
--   /eb vis          show the rule, its translation, and the current result
--   /eb specs        show talent trees and points per spec
--   /eb reset        move the bar back to the center

local _, ns = ...

local SIZE, GAP, COLS, ROWS = 36, 4, 2, 2

local bar, buttons = nil, {}

local function state()
    ns.charDB.spike = ns.charDB.spike or { visibility = "show", buttons = {} }
    return ns.charDB.spike
end

local function savePosition()
    local point, _, relativePoint, x, y = bar:GetPoint()
    state().position = { point, relativePoint, x, y }
end

local function applyPosition()
    bar:ClearAllPoints()
    local pos = state().position
    if pos then
        bar:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    end
end

-- Translate the stored rule and hand it to the game. Re-run whenever talents or specs change.
local function applyVisibility(verbose)
    ns.RunOutOfCombat("spike-visibility", function()
        local rule = state().visibility
        local translated, problems = ns.Conditionals.Translate(rule, ns.SpecTrees.Get())
        if translated == "" then translated = "hide" end -- no clause can match
        UnregisterStateDriver(bar, "visibility")
        RegisterStateDriver(bar, "visibility", translated)
        if verbose or #problems > 0 or translated ~= state().lastTranslated then
            ns.Print("Visibility: %s", rule)
            if translated ~= rule then ns.Print("  translated: %s", translated) end
            for _, problem in ipairs(problems) do ns.Print("  |cffff8800%s|r", problem) end
            ns.Print("  right now: %s", tostring(SecureCmdOptionParse(translated) or "no match (hidden)"))
        end
        state().lastTranslated = translated
    end)
end

local function updateButtons()
    for _, button in ipairs(buttons) do button:Update() end
end

local function build()
    bar = CreateFrame("Frame", "ElastibarSpikeBar", UIParent, "SecureHandlerStateTemplate")
    bar:SetSize(COLS * SIZE + (COLS - 1) * GAP, ROWS * SIZE + (ROWS - 1) * GAP)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    applyPosition()

    local handle = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    handle:SetSize(70, 14)
    handle:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 2)
    handle:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    handle:SetBackdropColor(0.1, 0.4, 0.7, 0.8)
    local label = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetText("Elastibar")
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if not InCombatLockdown() then bar:StartMoving() end
    end)
    handle:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        savePosition()
    end)

    local saved = state().buttons
    for i = 1, COLS * ROWS do
        local button = ns.Button.Create(bar, function(_, content) saved[i] = content end)
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        button.widget:SetPoint("TOPLEFT", bar, "TOPLEFT", col * (SIZE + GAP), -row * (SIZE + GAP))
        button:SetContent(saved[i])
        buttons[i] = button
    end

    -- Range has no event; poll it a few times a second.
    local elapsedSince = 0
    bar:SetScript("OnUpdate", function(_, elapsed)
        elapsedSince = elapsedSince + elapsed
        if elapsedSince < 0.2 then return end
        elapsedSince = 0
        for _, button in ipairs(buttons) do button:UpdateUsable() end
    end)

    applyVisibility(false)
end

ns.OnLoaded = function()
    ns.On("PLAYER_LOGIN", build)
end

for _, event in ipairs({ "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE",
    "BAG_UPDATE_DELAYED", "PLAYER_TARGET_CHANGED", "ACTIONBAR_UPDATE_COOLDOWN" }) do
    ns.On(event, function() if bar then updateButtons() end end)
end

-- Macros can be renamed, added, or deleted: re-resolve indexes (secure, so out of combat).
ns.On("UPDATE_MACROS", function()
    if not bar then return end
    ns.RunOutOfCombat("spike-macros", function()
        for _, button in ipairs(buttons) do button:SetContent(button.content) end
    end)
end)

for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ENTERING_WORLD" }) do
    ns.On(event, function() if bar then applyVisibility(false) end end)
end

local function printSpecs()
    local info = ns.SpecTrees.Get()
    for group = 1, 2 do
        local points = info.points[group]
        if points then
            local parts = {}
            for i, name in ipairs(info.treeNames) do parts[i] = ("%s %d"):format(name, points[i] or 0) end
            local dominant = info.dominant[group] and info.treeNames[info.dominant[group]] or "none (tie or no points)"
            ns.Print("Spec %d: %s -> %s", group, table.concat(parts, ", "), dominant)
        else
            ns.Print("Spec %d: not available (locked?)", group)
        end
    end
end

SLASH_ELASTIBAR1 = "/eb"
SLASH_ELASTIBAR2 = "/elastibar"
SlashCmdList.ELASTIBAR = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "vis" then
        if rest ~= "" then
            if InCombatLockdown() then
                ns.Print("Can't change visibility in combat.")
                return
            end
            state().visibility = rest
        end
        applyVisibility(true)
    elseif cmd == "specs" then
        printSpecs()
    elseif cmd == "reset" then
        if InCombatLockdown() then
            ns.Print("Can't move bars in combat.")
            return
        end
        state().position = nil
        applyPosition()
    else
        ns.Print("/eb vis <rule>, /eb vis, /eb specs, /eb reset")
    end
end
