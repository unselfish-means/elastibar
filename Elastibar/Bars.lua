-- Bars: the live set of bars for this character, and the operations on them.
-- Every operation that changes a bar refuses to run in combat.

local _, ns = ...

local Bars = {}
ns.Bars = Bars

local live = {} -- [record.id] = Bar
local loaded = false

local function refuseInCombat(what)
    if InCombatLockdown() then
        ns.Print("Can't %s in combat.", what)
        return true
    end
    return false
end

local function show(record, specInfo)
    local bar = ns.Bar.Acquire(record)
    bar:Apply(specInfo or ns.SpecTrees.Get())
    live[record.id] = bar
    if ns.EditMode then ns.EditMode.Attach(bar) end
    return bar
end

function Bars.Get(id)
    return live[id]
end

function Bars.Each()
    return pairs(live)
end

function Bars.Load()
    local migrated = ns.BarStore.MigrateSpike(ns.db, ns.charDB)
    if migrated then ns.Print("Your spike bar is now a character bar named '%s'.", migrated.name) end
    local specInfo = ns.SpecTrees.Get()
    for _, record in ipairs(ns.BarStore.List(ns.db, ns.charDB)) do show(record, specInfo) end
    loaded = true
end

function Bars.Create(scope, name)
    if refuseInCombat("create bars") then return end
    local record, err = ns.BarStore.Create(scope, name, ns.db, ns.charDB)
    if not record then
        ns.Print("Couldn't create the bar: %s.", err)
        return
    end
    show(record)
    ns.Print("Created %s bar '%s'.", record.scope, record.name)
    return record
end

-- Deletes immediately, with no confirmation (decided in docs/specs/bars.md).
function Bars.Delete(record)
    if refuseInCombat("delete bars") then return end
    local bar = live[record.id]
    if bar then
        if ns.EditMode then ns.EditMode.Detach(bar) end
        bar:Release()
        live[record.id] = nil
    end
    ns.BarStore.Delete(record.id, ns.db, ns.charDB)
    ns.Print("Deleted bar '%s'.", record.name)
end

function Bars.Rename(record, name)
    local renamed, err = ns.BarStore.Rename(record.id, name, ns.db, ns.charDB)
    if not renamed then
        ns.Print("Couldn't rename the bar: %s.", err)
        return
    end
    if ns.EditMode then ns.EditMode.Refresh(live[record.id]) end
    ns.Print("Renamed to '%s'.", renamed.name)
end

-- Sets a bar's visibility rule and reports the translation and the result right now.
function Bars.SetVisibility(record, rule)
    if refuseInCombat("change visibility") then return end
    record.visibility = rule
    Bars.ReportVisibility(record)
end

function Bars.ReportVisibility(record)
    local bar = live[record.id]
    if not bar then return end
    local translated, problems = bar:ApplyVisibility(ns.SpecTrees.Get())
    ns.Print("'%s' visibility: %s", record.name, record.visibility)
    if translated ~= record.visibility then ns.Print("  translated: %s", translated) end
    for _, problem in ipairs(problems) do ns.Print("  |cffff8800%s|r", problem) end
    ns.Print("  right now: %s", tostring(SecureCmdOptionParse(translated) or "no match (hidden)"))
end

-- Talent and spec changes can change what spec names translate to. They can't happen
-- in combat, but queue anyway in case an event arrives during it.
local function retranslateAll()
    ns.RunOutOfCombat("bars-visibility", function()
        local specInfo = ns.SpecTrees.Get()
        for _, bar in pairs(live) do
            local _, problems = bar:ApplyVisibility(specInfo)
            for _, problem in ipairs(problems) do ns.Print("'%s': |cffff8800%s|r", bar.record.name, problem) end
        end
    end)
end

for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED" }) do
    ns.On(event, function() if loaded then retranslateAll() end end)
end

for _, event in ipairs({ "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE",
    "BAG_UPDATE_DELAYED", "PLAYER_TARGET_CHANGED", "ACTIONBAR_UPDATE_COOLDOWN",
    "CURRENT_SPELL_CAST_CHANGED", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL" }) do
    ns.On(event, function()
        for _, bar in pairs(live) do bar:UpdateButtons() end
    end)
end

-- Macros can be renamed, added, or deleted: re-resolve indexes (secure, so out of combat).
ns.On("UPDATE_MACROS", function()
    if not loaded then return end
    ns.RunOutOfCombat("bars-macros", function()
        for _, bar in pairs(live) do
            for _, button in pairs(bar.buttons) do
                if button.widget:IsShown() then button:SetContent(button.content) end
            end
        end
    end)
end)

-- Switching Edit Mode layouts moves bars to that layout's saved positions.
ns.On("EDIT_MODE_LAYOUTS_UPDATED", function()
    if not loaded then return end
    ns.RunOutOfCombat("bars-layout", function()
        for _, bar in pairs(live) do bar:ApplyPosition() end
    end)
end)

-- Range has no event; poll a few times a second.
local rangeTicker = CreateFrame("Frame")
local sinceRange = 0
rangeTicker:SetScript("OnUpdate", function(_, elapsed)
    sinceRange = sinceRange + elapsed
    if sinceRange < 0.2 then return end
    sinceRange = 0
    for _, bar in pairs(live) do bar:UpdateUsable() end
end)

ns.On("PLAYER_LOGIN", Bars.Load)
