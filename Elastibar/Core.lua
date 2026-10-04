-- Core: namespace, saved variables, event dispatch, and the out-of-combat queue.

local ADDON, ns = ...

ns.name = ADDON

-- Everything printed is also kept in ElastibarDB.log (last 300 lines) so it can be read
-- from SavedVariables after a /reload.
local LOG_LIMIT = 300

function ns.Log(text)
    if not ns.db then return end
    ns.db.log = ns.db.log or {}
    local log = ns.db.log
    log[#log + 1] = date("%m-%d %H:%M:%S") .. (InCombatLockdown() and " [combat] " or " ") .. text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    while #log > LOG_LIMIT do table.remove(log, 1) end
end

function ns.Print(fmt, ...)
    local text = fmt:format(...)
    print("|cff33ccffElastibar:|r " .. text)
    ns.Log(text)
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
