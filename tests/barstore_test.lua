-- Standalone tests for Elastibar/BarStore.lua. Run from the repo root:  lua tests/barstore_test.lua

local ns = {}
assert(loadfile("Elastibar/BarStore.lua"))("Elastibar", ns)
local S = ns.BarStore

local failures, count = 0, 0
local function check(name, got, want)
    count = count + 1
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, tostring(got), tostring(want)))
    end
end

local db, charDB = {}, {}

-- Create
local a = S.Create("account", "Utility", db, charDB)
check("account id", a.id, "a1")
check("account scope", a.scope, "account")
check("defaults cols", a.cols, 4)
check("defaults rows", a.rows, 1)
check("defaults visibility", a.visibility, "show")
check("stored in account db", db.bars.a1, a)

local c = S.Create("character", nil, db, charDB)
check("character id", c.id, "c1")
check("default name", c.name, "Bar 1")
check("stored in char db", charDB.bars.c1, c)
check("second default name", S.Create("character", "", db, charDB).name, "Bar 2")

check("duplicate name rejected", select(2, S.Create("character", "utility", db, charDB)), "a bar named 'utility' already exists")
check("unknown scope", select(2, S.Create("guild", "x", db, charDB)), "unknown scope 'guild'")

-- List order: account first, then character, by creation
local list = S.List(db, charDB)
check("list size", #list, 3)
check("list first", list[1].id, "a1")
check("list second", list[2].id, "c1")
check("list third", list[3].id, "c2")

-- Find
check("find by number", S.Find("2", db, charDB), c)
check("find by name", S.Find("UTILITY", db, charDB), a)
check("find by id", S.Find("c2", db, charDB).name, "Bar 2")
check("find missing", S.Find("nope", db, charDB), nil)

-- Rename
check("rename", S.Rename("c1", "Burst", db, charDB).name, "Burst")
check("rename same name other case", S.Rename("c1", "burst", db, charDB).name, "burst")
check("rename taken", select(2, S.Rename("c1", "Utility", db, charDB)), "a bar named 'Utility' already exists")
check("rename empty", select(2, S.Rename("c1", "  ", db, charDB)), "enter a name")

-- Delete; ids are not reused
check("delete", S.Delete("c1", db, charDB), true)
check("deleted gone", S.Get("c1", db, charDB), nil)
check("delete missing", S.Delete("c1", db, charDB), false)
check("ids not reused", S.Create("character", nil, db, charDB).id, "c3")

-- Account bars are shared: another character sees them, not the first character's bars
local otherChar = {}
local otherList = S.List(db, otherChar)
check("other character sees account bar", otherList[1], a)
check("other character sees only account bars", #otherList, 1)

-- Spike migration
local mdb, mchar = {}, { spike = {
    visibility = "[combat] show; hide",
    scale = 1.2,
    positions = { ["My Layout"] = { "CENTER", "CENTER", 10, 20 } },
    buttons = { { kind = "spell", id = 5149 }, { kind = "macro", name = "- Explosives" }, nil, { kind = "item", id = 6948 } },
} }
local m = S.MigrateSpike(mdb, mchar)
check("migrated name", m.name, "Spike")
check("migrated size", m.cols .. "x" .. m.rows, "2x2")
check("migrated scale", m.scale, 1.2)
check("migrated visibility", m.visibility, "[combat] show; hide")
check("migrated position", m.positions["My Layout"][3], 10)
check("migrated button 1,1", m.buttons["1,1"].id, 5149)
check("migrated button 1,2", m.buttons["1,2"].name, "- Explosives")
check("migrated empty 2,1", m.buttons["2,1"], nil)
check("migrated button 2,2", m.buttons["2,2"].id, 6948)
check("spike data removed", mchar.spike, nil)
check("migration runs once", S.MigrateSpike(mdb, mchar), nil)

print(("%d checks, %d failed"):format(count, failures))
if failures > 0 then os.exit(1) end
