-- BarStore: the saved data behind every bar. Pure Lua (no WoW API calls), so
-- tests/barstore_test.lua can run it standalone.
--
-- Account bars live in ElastibarDB.bars and character bars in ElastibarCharDB.bars,
-- keyed by id ("a1", "c3"). A bar record:
--
--   { id, name, scope = "account" | "character", cols, rows, scale, layer, visibility,
--     positions = { [editModeLayoutName] = { point, relativePoint, x, y } },
--     buttons = { ["row,col"] = content } }
--
-- Buttons are keyed by row and column, so resizing a bar later keeps their contents.

local _, ns = ...
ns = ns or {}

local BarStore = {}
ns.BarStore = BarStore

BarStore.DEFAULTS = { cols = 4, rows = 1, scale = 1, layer = "normal", visibility = "show", hideEmpty = false }
BarStore.MAX_SIZE = 12 -- rows and columns are each 1..12
BarStore.LAYERS = { "behind", "normal", "above", "top" }

-- Rounds and clamps a row or column count to 1..MAX_SIZE.
function BarStore.ClampSize(n)
    n = math.floor((tonumber(n) or 1) + 0.5)
    return math.max(1, math.min(BarStore.MAX_SIZE, n))
end

local PREFIX = { account = "a", character = "c" }

local function storeFor(scope, db, charDB)
    local root = scope == "account" and db or charDB
    root.bars = root.bars or {}
    root.nextBarId = root.nextBarId or 1
    return root
end

function BarStore.ButtonKey(row, col)
    return row .. "," .. col
end

-- All records this character sees: account bars first, then character bars, each by creation order.
function BarStore.List(db, charDB)
    local list = {}
    for _, scope in ipairs({ "account", "character" }) do
        local root = storeFor(scope, db, charDB)
        local scoped = {}
        for _, record in pairs(root.bars) do scoped[#scoped + 1] = record end
        table.sort(scoped, function(a, b) return tonumber(a.id:sub(2)) < tonumber(b.id:sub(2)) end)
        for _, record in ipairs(scoped) do list[#list + 1] = record end
    end
    return list
end

local function nameTaken(name, db, charDB)
    local key = name:lower()
    for _, record in ipairs(BarStore.List(db, charDB)) do
        if record.name:lower() == key then return true end
    end
    return false
end

-- "Bar 1", "Bar 2", ... skipping names already in use.
local function defaultName(db, charDB)
    local n = 1
    while nameTaken("Bar " .. n, db, charDB) do n = n + 1 end
    return "Bar " .. n
end

-- Creates and stores a new record. Returns the record, or nil and an error message.
function BarStore.Create(scope, name, db, charDB)
    if not PREFIX[scope] then return nil, "unknown scope '" .. tostring(scope) .. "'" end
    name = name and name:match("^%s*(.-)%s*$") or ""
    if name == "" then name = defaultName(db, charDB) end
    if nameTaken(name, db, charDB) then return nil, ("a bar named '%s' already exists"):format(name) end

    local root = storeFor(scope, db, charDB)
    local id = PREFIX[scope] .. root.nextBarId
    root.nextBarId = root.nextBarId + 1
    local record = { id = id, name = name, scope = scope, positions = {}, buttons = {} }
    for key, value in pairs(BarStore.DEFAULTS) do record[key] = value end
    root.bars[id] = record
    return record
end

function BarStore.Get(id, db, charDB)
    for _, scope in ipairs({ "account", "character" }) do
        local record = storeFor(scope, db, charDB).bars[id]
        if record then return record end
    end
end

function BarStore.Delete(id, db, charDB)
    for _, scope in ipairs({ "account", "character" }) do
        local root = storeFor(scope, db, charDB)
        if root.bars[id] then
            root.bars[id] = nil
            return true
        end
    end
    return false
end

function BarStore.Rename(id, name, db, charDB)
    local record = BarStore.Get(id, db, charDB)
    if not record then return nil, "no such bar" end
    name = name and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return nil, "enter a name" end
    if name:lower() ~= record.name:lower() and nameTaken(name, db, charDB) then
        return nil, ("a bar named '%s' already exists"):format(name)
    end
    record.name = name
    return record
end

-- Finds a bar by its number in BarStore.List, its id, or its name (case-insensitive).
function BarStore.Find(token, db, charDB)
    token = token and token:match("^%s*(.-)%s*$") or ""
    local list = BarStore.List(db, charDB)
    local n = tonumber(token)
    if n then return list[n] end
    local key = token:lower()
    for _, record in ipairs(list) do
        if record.id == key or record.name:lower() == key then return record end
    end
end

-- One-time move of the 2x2 spike bar (ElastibarCharDB.spike) into a character bar.
function BarStore.MigrateSpike(db, charDB)
    local spike = charDB.spike
    if not spike then return nil end
    local record = BarStore.Create("character", "Spike", db, charDB) or BarStore.Create("character", nil, db, charDB)
    record.cols, record.rows = 2, 2
    record.scale = spike.scale or 1
    record.visibility = spike.visibility or "show"
    for layout, pos in pairs(spike.positions or {}) do record.positions[layout] = pos end
    for i = 1, 4 do
        local content = spike.buttons and spike.buttons[i]
        if content then record.buttons[BarStore.ButtonKey(math.floor((i - 1) / 2) + 1, (i - 1) % 2 + 1)] = content end
    end
    charDB.spike = nil
    return record
end

return BarStore
