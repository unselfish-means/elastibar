-- Standalone tests for the storage parts of Elastibar/MacroTooltips.lua. Run from the repo root:
--   lua tests/macrotooltips_test.lua

local ns = {}
assert(loadfile("Elastibar/MacroTooltips.lua"))("Elastibar", ns)
local M = ns.MacroTooltips

local failures, count = 0, 0
local function check(name, got, want)
    count = count + 1
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, tostring(got), tostring(want)))
    end
end

check("account macro without the global", M.IsAccountMacro(120), true)
check("character macro without the global", M.IsAccountMacro(121), false)
check("explicit limit", M.IsAccountMacro(37, 36), false)

local db, charDB = {}, {}
local account = M.StoreFor(5, db, charDB, 120)
local char = M.StoreFor(121, db, charDB, 120)
check("account macro uses the account db", account, db.macroTooltips)
check("character macro uses the character db", char, charDB.macroTooltips)
check("last account index", M.StoreFor(120, db, charDB, 120), db.macroTooltips)
check("default account limit", M.StoreFor(121, db, charDB), charDB.macroTooltips)
check("store is reused", M.StoreFor(7, db, charDB, 120), account)

M.Set(account, "- Explosives", "  Explosive Trap.\nHold Shift for Frost Trap.\n\n ")
check("text trimmed", account["- Explosives"], "Explosive Trap.\nHold Shift for Frost Trap.")
M.Set(account, "- Explosives", "   \n ")
check("blank text removes it", account["- Explosives"], nil)
M.Set(account, "Long", ("x"):rep(600))
check("text capped", #account["Long"], M.MAX_LENGTH)
M.Set(char, "Mine", "hello")
check("character text stays per character", char["Mine"] == "hello" and account["Mine"] == nil, true)

print(("%d checks, %d failed"):format(count, failures))
if failures > 0 then os.exit(1) end
