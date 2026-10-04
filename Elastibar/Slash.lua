-- Slash commands. Stand-ins until the options panel and the visibility editor exist.
--
--   /eb list                       list bars with their numbers
--   /eb new [account] [name]       create a character bar (or an account bar)
--   /eb delete <bar>               delete a bar (no confirmation)
--   /eb rename <bar> <name>        rename a bar
--   /eb vis <bar> [rule]           set or show a bar's visibility rule
--   /eb taintlog [off]             turn the taintLog CVar on (re-applied each login) or off
--
-- <bar> is a number from /eb list, a bar id, or a one-word bar name.

local _, ns = ...

local function splitFirst(text)
    return (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
end

local function findBar(token)
    local record = ns.BarStore.Find(token, ns.db, ns.charDB)
    if not record then ns.Print("No bar '%s'. Use /eb list to see bar numbers.", token) end
    return record
end

local function list()
    local records = ns.BarStore.List(ns.db, ns.charDB)
    if #records == 0 then
        ns.Print("No bars yet. Create one with /eb new [account] [name].")
        return
    end
    for i, record in ipairs(records) do
        ns.Print("%d. %s (%s, %dx%d) visibility: %s", i, record.name, record.scope,
            record.cols, record.rows, record.visibility)
    end
end

local commands = {}

commands.list = list

function commands.new(rest)
    local first, remainder = splitFirst(rest)
    local scope, name = "character", rest
    if first:lower() == "account" or first:lower() == "character" then
        scope, name = first:lower(), remainder
    end
    ns.Bars.Create(scope, name)
end

function commands.delete(rest)
    local record = findBar(rest)
    if record then ns.Bars.Delete(record) end
end

function commands.rename(rest)
    local token, name = splitFirst(rest)
    local record = findBar(token)
    if record then ns.Bars.Rename(record, name) end
end

function commands.vis(rest)
    local token, rule = splitFirst(rest)
    local record = findBar(token)
    if not record then return end
    if rule == "" then
        ns.Bars.ReportVisibility(record)
    else
        ns.Bars.SetVisibility(record, rule)
    end
end

function commands.taintlog(rest)
    -- /console is broken in this beta's chat code, so set the CVar directly. Opt-in only:
    -- this beta throws unrelated Blizzard errors while it's on (docs/platform.md).
    local on = rest:lower() ~= "off"
    ns.db.taintLog = on
    local ok, err = pcall(SetCVar, "taintLog", on and "1" or "0")
    ns.Print("taintLog %s: %s", on and "on" or "off", ok and tostring(GetCVar("taintLog")) or tostring(err))
end

ns.On("PLAYER_ENTERING_WORLD", function()
    if ns.db and ns.db.taintLog then pcall(SetCVar, "taintLog", "1") end -- the client resets it on reload
end)

SLASH_ELASTIBAR1 = "/eb"
SLASH_ELASTIBAR2 = "/elastibar"
SlashCmdList.ELASTIBAR = function(msg)
    local cmd, rest = splitFirst(msg)
    local handler = commands[cmd:lower()]
    if handler then
        handler(rest)
    else
        ns.Print("/eb list, /eb new [account] [name], /eb delete <bar>, /eb rename <bar> <name>, /eb vis <bar> [rule]")
    end
end
