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
        "C_ClassTalents.GetConfigIDsBySpecID", "C_Traits.GetConfigInfo", "C_Traits.GetTreeInfo",
        "C_Traits.GetTreeNodes", "C_Traits.GetNodeInfo", "C_Traits.GetSubTreeInfo",
        "C_Traits.GetTreeCurrencyInfo",
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

-- Forever's three-tree talent UI may sit on the Retail trait system. Walk the
-- active config and total points per tree and per sub-tree, with any names found.
local function probeTraits(lines)
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits) then
        lines[#lines + 1] = "traits C_ClassTalents/C_Traits missing"
        return
    end
    local _, specID = pcall(C_SpecializationInfo.GetSpecializationInfo, 1)
    if C_ClassTalents.GetConfigIDsBySpecID then
        local ok, ids = pcall(C_ClassTalents.GetConfigIDsBySpecID, specID)
        lines[#lines + 1] = ("traits GetConfigIDsBySpecID(%s) -> %s")
            :format(tostring(specID), ok and type(ids) == "table" and describe(unpack(ids)) or describe(ok, ids))
    end

    local okId, configID = pcall(C_ClassTalents.GetActiveConfigID)
    lines[#lines + 1] = ("traits activeConfigID -> %s"):format(describe(okId, configID))
    if not okId or not configID then return end

    local okCfg, config = pcall(C_Traits.GetConfigInfo, configID)
    if not okCfg or type(config) ~= "table" then
        lines[#lines + 1] = ("traits GetConfigInfo -> %s"):format(describe(okCfg, config))
        return
    end
    lines[#lines + 1] = ("traits config name=%s type=%s treeIDs=%s")
        :format(tostring(config.name), tostring(config.type), describe(unpack(config.treeIDs or {})))

    for _, treeID in ipairs(config.treeIDs or {}) do
        local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
        if not okNodes or type(nodeIDs) ~= "table" then
            lines[#lines + 1] = ("traits tree%s GetTreeNodes -> %s"):format(treeID, describe(okNodes, nodeIDs))
        else
            local bySub, total = {}, 0
            for _, nodeID in ipairs(nodeIDs) do
                local okNode, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                if okNode and type(node) == "table" then
                    local key = node.subTreeID or "none"
                    local agg = bySub[key] or { nodes = 0, ranks = 0, minX = math.huge, maxX = -math.huge }
                    agg.nodes = agg.nodes + 1
                    agg.ranks = agg.ranks + (node.ranksPurchased or 0)
                    if node.posX then
                        agg.minX = math.min(agg.minX, node.posX)
                        agg.maxX = math.max(agg.maxX, node.posX)
                    end
                    bySub[key] = agg
                    total = total + (node.ranksPurchased or 0)
                end
            end
            lines[#lines + 1] = ("traits tree%s nodes=%d ranksPurchased=%d"):format(treeID, #nodeIDs, total)
            for subID, agg in pairs(bySub) do
                local name = "n/a"
                if subID ~= "none" and C_Traits.GetSubTreeInfo then
                    local okSub, sub = pcall(C_Traits.GetSubTreeInfo, configID, subID)
                    name = okSub and type(sub) == "table" and tostring(sub.name) or describe(okSub, sub)
                end
                lines[#lines + 1] = ("traits tree%s subTree=%s name=%s nodes=%d ranks=%d posX=%s..%s")
                    :format(treeID, tostring(subID), name, agg.nodes, agg.ranks, tostring(agg.minX), tostring(agg.maxX))
            end
        end
    end
end

local function dumpTable(t)
    local parts = {}
    for k, v in pairs(t) do
        local shown = type(v) == "table" and ("{%d}"):format(#v) or tostring(v)
        parts[#parts + 1] = ("%s=%s"):format(tostring(k), shown)
    end
    table.sort(parts)
    return table.concat(parts, " ")
end

-- The talent UI names its columns somehow. List every talent-ish function the
-- client exposes, and show how purchased ranks spread across node positions.
local function probeTalentDiscovery(lines)
    for ns, tbl in pairs(_G) do
        if type(ns) == "string" and type(tbl) == "table" and ns:find("^C_")
            and (ns:find("Talent") or ns:find("Trait") or ns:find("Spec")) then
            for fn, v in pairs(tbl) do
                if type(v) == "function" then lines[#lines + 1] = ("discover %s.%s"):format(ns, fn) end
            end
        elseif type(ns) == "string" and type(tbl) == "function" and ns:find("Talent") then
            lines[#lines + 1] = ("discover global %s"):format(ns)
        elseif type(ns) == "string" and type(tbl) == "table" and ns:find("Talent") and ns:find("Frame$") then
            lines[#lines + 1] = ("discover frame %s"):format(ns)
        end
    end

    if not (C_ClassTalents and C_Traits) then return end
    local okId, configID = pcall(C_ClassTalents.GetActiveConfigID)
    local okCfg, config = pcall(C_Traits.GetConfigInfo, configID)
    if not (okId and okCfg and type(config) == "table" and config.treeIDs) then return end
    local treeID = config.treeIDs[1]

    local okTree, tree = pcall(C_Traits.GetTreeInfo, configID, treeID)
    lines[#lines + 1] = ("discover GetTreeInfo -> %s"):format(okTree and type(tree) == "table" and dumpTable(tree) or describe(okTree, tree))
    local okCur, currencies = pcall(C_Traits.GetTreeCurrencyInfo, configID, treeID, false)
    if okCur and type(currencies) == "table" then
        for i, c in ipairs(currencies) do
            lines[#lines + 1] = ("discover currency%d %s"):format(i, type(c) == "table" and dumpTable(c) or tostring(c))
        end
    else
        lines[#lines + 1] = ("discover GetTreeCurrencyInfo -> %s"):format(describe(okCur, currencies))
    end

    local byX, dumped = {}, false
    local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
    for _, nodeID in ipairs(okNodes and type(nodeIDs) == "table" and nodeIDs or {}) do
        local ok, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if ok and type(node) == "table" then
            if not dumped and (node.ranksPurchased or 0) > 0 then
                lines[#lines + 1] = ("discover node %s"):format(dumpTable(node))
                dumped = true
            end
            local x = node.posX or -1
            local agg = byX[x] or { nodes = 0, ranks = 0 }
            agg.nodes = agg.nodes + 1
            agg.ranks = agg.ranks + (node.ranksPurchased or 0)
            byX[x] = agg
        end
    end
    for x, agg in pairs(byX) do
        lines[#lines + 1] = ("discover posX %06d nodes=%d ranks=%d"):format(x, agg.nodes, agg.ranks)
    end
end

-- Nodes carry groupIDs; the talent UI likely labels its columns from group
-- display info. Also try the class's spec IDs in case they map to trees.
local function probeTalentGroups(lines)
    if not (C_ClassTalents and C_Traits) then return end
    local okId, configID = pcall(C_ClassTalents.GetActiveConfigID)
    local okCfg, config = pcall(C_Traits.GetConfigInfo, configID)
    if not (okId and okCfg and type(config) == "table" and config.treeIDs) then return end
    local treeID = config.treeIDs[1]

    local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
    local byGroup = {}
    for _, nodeID in ipairs(okNodes and type(nodeIDs) == "table" and nodeIDs or {}) do
        local ok, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if ok and type(node) == "table" then
            for _, groupID in ipairs(node.groupIDs or {}) do
                local agg = byGroup[groupID] or { nodes = 0, ranks = 0, minX = math.huge, maxX = -math.huge }
                agg.nodes = agg.nodes + 1
                agg.ranks = agg.ranks + (node.ranksPurchased or 0)
                agg.minX = math.min(agg.minX, node.posX or 0)
                agg.maxX = math.max(agg.maxX, node.posX or 0)
                byGroup[groupID] = agg
            end
        end
    end
    for groupID, agg in pairs(byGroup) do
        lines[#lines + 1] = ("groups group%s nodes=%d ranks=%d posX=%s..%s")
            :format(tostring(groupID), agg.nodes, agg.ranks, tostring(agg.minX), tostring(agg.maxX))
        if C_Traits.GetGroupCurrencyInfo then
            local ok, infos = pcall(C_Traits.GetGroupCurrencyInfo, configID, { groupID })
            local first = ok and type(infos) == "table" and infos[1]
            lines[#lines + 1] = ("groups group%s GetGroupCurrencyInfo -> %s")
                :format(tostring(groupID), type(first) == "table" and dumpTable(first) or describe(ok, infos))
        end
    end

    if C_Traits.GetGroupDisplayInfoByTreeID then
        local ok, info = pcall(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
        if ok and type(info) == "table" then
            lines[#lines + 1] = ("groups display top %s"):format(dumpTable(info))
            for k, v in pairs(info) do
                if type(v) == "table" then
                    lines[#lines + 1] = ("groups display [%s] %s"):format(tostring(k), dumpTable(v))
                end
            end
        else
            lines[#lines + 1] = ("groups GetGroupDisplayInfoByTreeID -> %s"):format(describe(ok, info))
        end
    end

    local _, _, classID = UnitClass("player")
    local specInfo = C_SpecializationInfo
    if specInfo and specInfo.GetSpecIDs then
        local ok, ids = pcall(specInfo.GetSpecIDs, classID)
        lines[#lines + 1] = ("groups GetSpecIDs(%s) -> %s")
            :format(tostring(classID), ok and type(ids) == "table" and describe(unpack(ids)) or describe(ok, ids))
        if ok and type(ids) == "table" and type(GetSpecializationInfoByID) == "function" then
            for _, id in ipairs(ids) do
                lines[#lines + 1] = ("groups GetSpecializationInfoByID(%s) -> %s")
                    :format(tostring(id), describe(pcall(GetSpecializationInfoByID, id)))
            end
        end
    end
end

-- Prototype of the lookup Elastibar needs: for each spec group, total ranks
-- per named talent column (from group display info) and pick the dominant one.
local function probeSpecTrees(lines)
    local getConfig = C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup
    if not (getConfig and C_Traits and C_Traits.GetGroupDisplayInfoByTreeID) then
        lines[#lines + 1] = "spectree prerequisites missing"
        return
    end
    for specGroup = 1, 2 do
        local okCfgID, configID = pcall(getConfig, specGroup)
        lines[#lines + 1] = ("spectree group%d configID -> %s"):format(specGroup, describe(okCfgID, configID))
        local okCfg, config = pcall(C_Traits.GetConfigInfo, configID)
        if okCfgID and configID and okCfg and type(config) == "table" and config.treeIDs then
            local treeID = config.treeIDs[1]
            local okDisp, columns = pcall(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
            local ranks = {}
            local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
            for _, nodeID in ipairs(okNodes and type(nodeIDs) == "table" and nodeIDs or {}) do
                local ok, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                if ok and type(node) == "table" then
                    for _, groupID in ipairs(node.groupIDs or {}) do
                        ranks[groupID] = (ranks[groupID] or 0) + (node.ranksPurchased or 0)
                    end
                end
            end
            for _, col in ipairs(okDisp and type(columns) == "table" and columns or {}) do
                lines[#lines + 1] = ("spectree group%d column%s %s skillLine=%s ranks=%d")
                    :format(specGroup, tostring(col.orderIndex), tostring(col.displayName),
                        tostring(col.skillLineID), ranks[col.groupID] or 0)
            end
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
    probeTraits(lines)
    probeTalentDiscovery(lines)
    probeTalentGroups(lines)
    probeSpecTrees(lines)
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

-- Runs only on /ebprobe: the conditional check prints "Unknown macro option" for its
-- made-up control conditional, which is noise at every login.
local pending = false
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if pending then pending = not run() end
end)

SLASH_ELASTIBARPROBE1 = "/ebprobe"
SlashCmdList.ELASTIBARPROBE = function(msg)
    if msg and msg:lower():match("^%s*missing") then
        printMissing()
    else
        pending = not run()
    end
end
