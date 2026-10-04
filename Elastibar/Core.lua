-- Core: namespace, saved variables, event dispatch, and the out-of-combat queue.

local ADDON, ns = ...

ns.name = ADDON

function ns.Print(fmt, ...)
    print(("|cff33ccffElastibar:|r " .. fmt):format(...))
end

-- Event dispatch. Unknown events are skipped instead of erroring, since this
-- client mixes Classic and Retail event sets.
local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
    if not handlers[event] then
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return false end
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do fn(event, ...) end
end)

-- Protected work (secure attributes, state drivers, moving secure frames) can't
-- happen in combat. Queue it and run it once combat ends.
local queued = {}

function ns.RunOutOfCombat(key, fn)
    if InCombatLockdown() then
        queued[key] = fn
        return false
    end
    fn()
    return true
end

ns.On("PLAYER_REGEN_ENABLED", function()
    for key, fn in pairs(queued) do
        queued[key] = nil
        fn()
    end
end)

-- Saved variables: ElastibarDB is account-wide, ElastibarCharDB is per character.
ns.On("ADDON_LOADED", function(_, loaded)
    if loaded ~= ADDON then return end
    ElastibarDB = ElastibarDB or {}
    ElastibarCharDB = ElastibarCharDB or {}
    ns.db, ns.charDB = ElastibarDB, ElastibarCharDB
    if ns.OnLoaded then ns.OnLoaded() end
end)
