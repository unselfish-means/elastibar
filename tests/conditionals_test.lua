-- Standalone tests for Elastibar/Conditionals.lua. Run from the repo root with any
-- Lua 5.1-compatible interpreter (WoW uses 5.1):  lua tests/conditionals_test.lua

local ns = {}
assert(loadfile("Elastibar/Conditionals.lua"))("Elastibar", ns)
local C = ns.Conditionals

local failures, count = 0, 0

local function check(name, got, want)
    count = count + 1
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, tostring(got), tostring(want)))
    end
end

local HUNTER = { "Beast Mastery", "Marksmanship", "Survival" }
local function info(dominant) return { treeNames = HUNTER, dominant = dominant } end
local BM_PRIMARY = info({ [1] = 1 })            -- Primary is Beast Mastery, Secondary locked
local BM_BOTH = info({ [1] = 1, [2] = 1 })
local BM_MM = info({ [1] = 1, [2] = 2 })
local TIED = info({})                           -- tie or no points: no dominant tree

local function translate(rule, specInfo)
    local out, problems = C.Translate(rule, specInfo)
    return out, table.concat(problems, " | ")
end

-- Name resolution
check("full name", C.ResolveTreeName("beastmastery", HUNTER), 1)
check("prefix", C.ResolveTreeName("beastmaster", HUNTER), 1)
check("short prefix", C.ResolveTreeName("surv", HUNTER), 3)
check("case and spaces", C.ResolveTreeName("Beast Mastery", HUNTER), 1)
check("unknown", select(2, C.ResolveTreeName("holy", HUNTER)), "unknown")
local MAGE = { "Arcane", "Fire", "Frost" }
check("ambiguous", select(2, C.ResolveTreeName("f", MAGE)), "ambiguous")
check("disambiguated", C.ResolveTreeName("fr", MAGE), 3)
check("exact beats prefix", C.ResolveTreeName("holy", { "Holy Light", "Holy" }), 2)

-- Translation
check("name to group", translate("[spec:beast] show; hide", BM_PRIMARY), "[spec:1] show; hide")
check("numeric untouched", translate("[spec:2, combat] show; hide", BM_PRIMARY), "[spec:2, combat] show; hide")
check("non-spec untouched", translate("[combat][mod:shift] show; hide", BM_PRIMARY), "[combat][mod:shift] show; hide")
check("keeps other conditions", translate("[combat,spec:beast] show; hide", BM_PRIMARY), "[combat,spec:1] show; hide")
check("mixed number and name", translate("[spec:2/beast] show; hide", BM_PRIMARY), "[spec:1/2] show; hide")
check("both groups", translate("[spec:beast] show; hide", BM_BOTH), "[spec:1/2] show; hide")
check("second group", translate("[spec:marks] show; hide", BM_MM), "[spec:2] show; hide")
check("no match drops clause", translate("[spec:marks] show; hide", BM_PRIMARY), "hide")
check("tie drops clause", translate("[spec:beast] show; hide", TIED), "hide")
check("no match drops one bracket", translate("[spec:marks][mod:shift] show; hide", BM_PRIMARY), "[mod:shift] show; hide")
check("negated", translate("[nospec:beast] show; hide", BM_PRIMARY), "[spec:2] show; hide")
check("negated always true", translate("[combat,nospec:marks] show; hide", BM_PRIMARY), "[combat] show; hide")
check("negated never true", translate("[nospec:beast] show; hide", BM_BOTH), "hide")
check("empty bracket stays valid", translate("[nospec:marks] show; hide", BM_PRIMARY), "[] show; hide")
check("all clauses dropped", translate("[spec:surv] show", BM_PRIMARY), "")
check("unknown reported", select(2, translate("[spec:holy] show; hide", BM_PRIMARY)), "unknown spec name 'holy'")
check("unknown drops clause", translate("[spec:holy] show; hide", BM_PRIMARY), "hide")
check("target kept", translate("[@focus,spec:beast] show; hide", BM_PRIMARY), "[@focus,spec:1] show; hide")

print(("%d checks, %d failed"):format(count, failures))
if failures > 0 then os.exit(1) end
