-- ElastibarProbe: records what this client supports so Elastibar can be built
-- against facts instead of guesses. Results land in ElastibarProbeDB, keyed by
-- build, as sorted line lists so two builds can be diffed as plain text.
--
-- Usage: /ebprobe          run the probe and print a summary
--        /ebprobe missing  list everything that was not found
-- Then /reload (or log out) to flush SavedVariables to disk.

-- APIs Elastibar may call, grouped by the feature that needs them.
-- Modern C_* names and legacy globals are both listed; the probe tells us which exist.
local APIS = {
    spells = {
        "C_Spell.GetSpellInfo", "C_Spell.GetSpellName", "C_Spell.GetSpellTexture",
        "C_Spell.GetSpellCooldown", "C_Spell.GetSpellCharges", "C_Spell.GetSpellCastCount",
        "C_Spell.IsSpellUsable", "C_Spell.IsSpellInRange", "C_Spell.IsCurrentSpell",
        "C_Spell.IsAutoRepeatSpell", "C_Spell.PickupSpell", "C_Spell.GetOverrideSpell",
        "C_Spell.GetSpellLink", "C_SpellBook.GetSpellBookItemInfo", "C_SpellBook.IsSpellKnown",
        "C_SpellBook.PickupSpellBookItem",
        "GetSpellInfo", "GetSpellTexture", "GetSpellCooldown", "IsUsableSpell",
        "IsSpellInRange", "IsSpellKnown", "IsPlayerSpell", "PickupSpell", "FindSpellOverrideByID",
    },
    items = {
        "C_Item.GetItemInfo", "C_Item.GetItemInfoInstant", "C_Item.GetItemIconByID",
        "C_Item.GetItemNameByID", "C_Item.GetItemCount", "C_Item.IsUsableItem",
        "C_Item.IsItemInRange", "C_Item.GetItemCooldown", "C_Item.IsConsumableItem",
        "C_Item.IsEquippedItem", "C_Item.RequestLoadItemDataByID", "C_Item.GetItemSpell",
        "C_Container.GetItemCooldown", "C_Container.GetContainerItemInfo",
        "C_ToyBox.GetToyInfo", "PlayerHasToy",
        "GetItemInfo", "GetItemInfoInstant", "GetItemCount", "GetItemCooldown",
        "IsUsableItem", "IsItemInRange", "PickupItem", "GetItemSpell",
    },
    macros = {
        "GetNumMacros", "GetMacroInfo", "GetMacroBody", "GetMacroIndexByName",
        "GetMacroSpell", "GetMacroItem", "PickupMacro",
    },
    cursor = {
        "GetCursorInfo", "ClearCursor", "CursorHasItem", "CursorHasSpell", "CursorHasMacro",
    },
    secure = {
        "InCombatLockdown", "RegisterStateDriver", "UnregisterStateDriver",
        "RegisterAttributeDriver", "UnregisterAttributeDriver", "SecureCmdOptionParse",
        "SecureHandlerWrapScript", "SecureHandlerSetFrameRef", "SecureHandlerExecute",
        "issecurevariable", "hooksecurefunc",
    },
    spec = {
        "GetSpecialization", "GetSpecializationInfo", "GetNumSpecializations",
        "C_SpecializationInfo.GetSpecialization", "C_SpecializationInfo.GetSpecializationInfo",
        "C_SpecializationInfo.GetActiveSpecGroup", "C_SpecializationInfo.GetNumSpecializationsForClassID",
        "GetActiveTalentGroup", "GetNumTalentGroups", "C_ClassTalents.GetActiveConfigID",
        "GetNumTalentTabs", "GetTalentTabInfo", "GetTalentInfo",
    },
    tooltip = {
        "GameTooltip", "GameTooltip.SetOwner", "GameTooltip.SetSpellByID",
        "GameTooltip.SetItemByID", "GameTooltip.SetHyperlink", "GameTooltip.AddLine",
        "GameTooltip_SetDefaultAnchor", "TooltipDataProcessor.AddTooltipPostCall",
        "C_TooltipInfo.GetSpellByID", "C_TooltipInfo.GetItemByID",
    },
    cooldown = {
        "CooldownFrame_Set", "CooldownFrame_Clear",
        "ActionButton_ShowOverlayGlow", "ActionButton_HideOverlayGlow",
        "ActionButtonSpellAlertManager", "C_ActionBar.IsCurrentAction",
    },
    ui = {
        "CreateFrame", "Mixin", "CreateFromMixins", "CreateFramePool", "CreateObjectPool",
        "C_Timer.After", "C_Timer.NewTimer", "C_AddOns.GetAddOnMetadata", "GetAddOnMetadata",
        "Settings.RegisterCanvasLayoutCategory", "Settings.RegisterAddOnCategory",
        "Settings.OpenToCategory", "InterfaceOptions_AddCategory",
        "MenuUtil.CreateContextMenu", "UIDropDownMenu_Initialize", "EasyMenu",
        "StaticPopup_Show", "EditModeManagerFrame", "C_EditMode.GetLayouts",
        "ColorPickerFrame", "ScrollUtil.RegisterScrollBoxWithScrollBar",
    },
    bindings = { -- vNext
        "SetBindingClick", "SetOverrideBindingClick", "ClearOverrideBindings", "GetBindingKey",
        "SaveBindings", "GetCurrentBindingSet",
    },
}

-- Templates the bar and config UI would build on. Each needs the right frame type.
local TEMPLATES = {
    { "Button", "SecureActionButtonTemplate" },
    { "CheckButton", "ActionButtonTemplate" },
    { "Frame", "SecureHandlerStateTemplate" },
    { "Frame", "SecureHandlerBaseTemplate" },
    { "Frame", "SecureHandlerAttributeTemplate" },
    { "Button", "SecureHandlerDragTemplate" },
    { "Frame", "SecureHandlerEnterLeaveTemplate" },
    { "Cooldown", "CooldownFrameTemplate" },
    { "Frame", "BackdropTemplate" },
    { "ScrollFrame", "InputScrollFrameTemplate" },
    { "Frame", "ScrollingEditBoxTemplate" },
    { "Button", "UIPanelButtonTemplate" },
    { "Button", "UIPanelCloseButton" },
    { "Frame", "DefaultPanelTemplate" },
    { "Frame", "ButtonFrameTemplate" },
    { "Frame", "PortraitFrameTemplate" },
}

-- Macro conditionals for bar visibility. A conditional is treated as supported
-- when [x] and [nox] disagree; an unknown conditional is false both ways.
local CONDITIONALS = {
    "combat", "spec:1", "spec:2", "mod:shift", "mod:ctrl", "mod:alt", "group", "group:raid",
    "mounted", "flying", "flyable", "swimming", "indoors", "outdoors", "resting", "stealth",
    "form:1", "stance:1", "pet", "dead", "channeling", "vehicleui", "overridebar",
    "possessbar", "petbattle", "bonusbar:1", "actionbar:1", "known:8690", "advflyable",
}

local STRATA = {
    "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP",
}

local CONSTANTS = {
    "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "WOW_PROJECT_CLASSIC",
    "LE_EXPANSION_LEVEL_CURRENT", "MAX_ACCOUNT_MACROS", "MAX_CHARACTER_MACROS",
    "NUM_ACTIONBAR_BUTTONS", "NUM_ACTIONBAR_PAGES",
}

-- Spec detection candidates; we record what each actually returns.
local SPEC_CALLS = {
    "GetSpecialization", "C_SpecializationInfo.GetSpecialization",
    "C_SpecializationInfo.GetActiveSpecGroup", "GetActiveTalentGroup", "GetNumTalentGroups",
    "GetNumSpecializations",
}

local function resolve(path)
    local value = _G
    for part in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return value
end

local function describe(...)
    local n = select("#", ...)
    if n == 0 then return "(none)" end
    local parts = {}
    for i = 1, n do parts[i] = tostring((select(i, ...))) end
    return table.concat(parts, ", ")
end

local function probeApis(lines, missing)
    for group, paths in pairs(APIS) do
        for _, path in ipairs(paths) do
            local kind = type(resolve(path))
            lines[#lines + 1] = ("api %s.%s %s"):format(group, path, kind)
            if kind == "nil" then missing[#missing + 1] = "api " .. path end
        end
    end
end

local function probeTemplates(lines, missing)
    for _, entry in ipairs(TEMPLATES) do
        local frameType, template = entry[1], entry[2]
        local ok, frame = pcall(CreateFrame, frameType, nil, UIParent, template)
        if ok and frame then frame:Hide() end
        lines[#lines + 1] = ("template %s %s"):format(template, ok and "ok" or "missing")
        if not ok then missing[#missing + 1] = "template " .. template end
    end
end

local function conditionalStatus(cond)
    local okYes, yes = pcall(SecureCmdOptionParse, ("[%s] y; n"):format(cond))
    local okNo, no = pcall(SecureCmdOptionParse, ("[no%s] y; n"):format(cond))
    if not (okYes and okNo) then return "error" end
    if yes ~= no then return "supported now=" .. tostring(yes) end
    return "unsupported"
end

local function probeConditionals(lines, missing)
    -- Control: a made-up conditional. If it also reads as "supported", the
    -- [x]/[nox] heuristic can't tell real conditionals from unknown ones here.
    local control = conditionalStatus("elastibarbogus")
    local conclusive = not control:find("^supported")
    lines[#lines + 1] = ("conditional _control %s%s"):format(control, conclusive and "" or " (heuristic inconclusive)")
    for _, cond in ipairs(CONDITIONALS) do
        local status = conditionalStatus(cond)
        if not conclusive then status = status:gsub("^supported", "indeterminate") end
        lines[#lines + 1] = ("conditional %s %s"):format(cond, status)
        if conclusive and not status:find("^supported") then
            missing[#missing + 1] = "conditional " .. cond
        end
    end
end

local function probeStrata(lines, missing)
    local frame = CreateFrame("Frame", nil, UIParent)
    for _, strata in ipairs(STRATA) do
        frame:SetFrameStrata(strata)
        local got = frame:GetFrameStrata()
        lines[#lines + 1] = ("strata %s %s"):format(strata, got == strata and "ok" or ("got=" .. tostring(got)))
        if got ~= strata then missing[#missing + 1] = "strata " .. strata end
    end
    frame:SetFrameLevel(10000)
    lines[#lines + 1] = ("strata maxFrameLevel=%s"):format(tostring(frame:GetFrameLevel()))
end

local function probeValues(lines)
    for _, name in ipairs(CONSTANTS) do
        lines[#lines + 1] = ("const %s=%s"):format(name, tostring(_G[name]))
    end
    for _, path in ipairs(SPEC_CALLS) do
        local fn = resolve(path)
        local result = "missing"
        if type(fn) == "function" then
            result = describe(pcall(fn))
        end
        lines[#lines + 1] = ("spec %s -> %s"):format(path, result)
    end
    lines[#lines + 1] = ("macros GetNumMacros -> %s"):format(describe(pcall(GetNumMacros)))
end

-- Talent trees per spec group: needed to translate [spec:<tree name>] into [spec:N].
local function probeTalentTrees(lines)
    local specInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
    for i = 1, 3 do
        lines[#lines + 1] = ("talent C_SpecializationInfo.GetSpecializationInfo(%d) -> %s")
            :format(i, specInfo and describe(pcall(specInfo, i)) or "missing")
    end
    if type(GetNumTalentTabs) ~= "function" or type(GetTalentTabInfo) ~= "function" then
        lines[#lines + 1] = "talent GetNumTalentTabs/GetTalentTabInfo missing"
        return
    end
    local ok, numTabs = pcall(GetNumTalentTabs)
    lines[#lines + 1] = ("talent GetNumTalentTabs -> %s"):format(describe(ok, numTabs))
    if not ok or type(numTabs) ~= "number" then return end
    for group = 1, 2 do
        for tab = 1, numTabs do
            lines[#lines + 1] = ("talent group%d tab%d -> %s")
                :format(group, tab, describe(pcall(GetTalentTabInfo, tab, false, false, group)))
        end
    end
end

local function run()
    if InCombatLockdown() then
        print("|cffff8800ElastibarProbe:|r in combat; will run when combat ends.")
        return false
    end

    local version, build, date, toc = GetBuildInfo()
    local key = ("%s.%s"):format(version, build)
    local lines, missing = {}, {}

    probeApis(lines, missing)
    probeTemplates(lines, missing)
    probeConditionals(lines, missing)
    probeStrata(lines, missing)
    probeValues(lines)
    probeTalentTrees(lines)
    table.sort(lines)
    table.sort(missing)

    ElastibarProbeDB = ElastibarProbeDB or {}
    ElastibarProbeDB[key] = {
        version = version, build = build, date = date, toc = toc,
        ranAt = time(),
        lines = lines,
        missing = missing,
    }
    ElastibarProbeDB.last = key

    print(("|cff33ccffElastibarProbe:|r build %s (toc %s): %d checks, %d missing. /ebprobe missing for details; /reload to save.")
        :format(key, tostring(toc), #lines, #missing))
    return true
end

local function printMissing()
    local entry = ElastibarProbeDB and ElastibarProbeDB[ElastibarProbeDB.last]
    if not entry then
        print("|cff33ccffElastibarProbe:|r no results yet. Run /ebprobe first.")
        return
    end
    for _, line in ipairs(entry.missing) do print("  " .. line) end
end

local pending = false
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        pending = not run()
    elseif pending then
        pending = not run()
    end
end)

SLASH_ELASTIBARPROBE1 = "/ebprobe"
SlashCmdList.ELASTIBARPROBE = function(msg)
    if msg and msg:lower():match("^%s*missing") then
        printMissing()
    else
        pending = not run()
    end
end
