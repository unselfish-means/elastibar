-- Standalone tests for Elastibar/RuleEditing.lua. Run from the repo root:
--   lua tests/ruleediting_test.lua

local ns = {}
assert(loadfile("Elastibar/RuleEditing.lua"))("Elastibar", ns)
local R = ns.RuleEditing

local failures, count = 0, 0
local function check(name, got, want)
    count = count + 1
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, tostring(got), tostring(want)))
    end
end

-- Inserts and returns the text with "|" marking the new cursor.
local function insert(text, cursor, snippet)
    local new, at = R.InsertSnippet(text, cursor, snippet)
    return new:sub(1, at) .. "|" .. new:sub(at + 1)
end

-- Presets
check("preset always", R.PresetFor("show"), "always")
check("preset combat", R.PresetFor("[combat] show; hide"), "combat")
check("preset ignores spacing and case", R.PresetFor("  [ Combat ]Show ;hide "), "combat")
check("preset nocombat", R.PresetFor("[nocombat] show; hide"), "nocombat")
check("preset spec2", R.PresetFor("[spec:2] show; hide"), "spec2")
check("custom rule", R.PresetFor("[combat,mod:shift] show; hide"), nil)
check("hide is custom", R.PresetFor("hide"), nil)

-- Snippets: always/never rules become a new rule
check("show becomes rule", insert("show", 4, "combat"), "[combat|] show; hide")
check("empty becomes rule", insert("", 0, "combat"), "[combat|] show; hide")
check("hide becomes rule", insert(" hide ", 0, "mod:shift"), "[mod:shift|] show; hide")

-- Snippets inside brackets join with a comma
check("join after condition", insert("[combat] show; hide", 7, "mod:shift"), "[combat,mod:shift|] show; hide")
check("join right after [", insert("[combat] show; hide", 1, "mod:shift"), "[mod:shift,|combat] show; hide")
check("join empty brackets", insert("[] show; hide", 1, "combat"), "[combat|] show; hide")
check("join after comma", insert("[combat,] show", 8, "pet"), "[combat,pet|] show")
check("chained clicks share brackets",
    insert(select(1, R.InsertSnippet("show", 4, "combat")), 7, "mod:shift"), "[combat,mod:shift|] show; hide")

-- Snippets outside brackets start a clause before the cursor's clause
check("new clause before fallback", insert("[combat] show; hide", 19, "mod:shift"),
    "[combat] show; [mod:shift|] show; hide")
check("new clause at start", insert("[combat] show; hide", 0, "pet"), "[pet|] show; [combat] show; hide")
check("new clause without space after ;", insert("[combat] show;hide", 18, "pet"),
    "[combat] show; [pet|] show; hide")
check("cursor in action word", insert("[combat] show; hide", 11, "pet"), "[pet|] show; [combat] show; hide")
check("cursor clamped", insert("[combat] show; hide", 99, "pet"), "[combat] show; [pet|] show; hide")

-- Checks
local function problems(rule) return table.concat(R.Check(rule), " | ") end
check("valid preset", problems("[combat] show; hide"), "")
check("valid always", problems("show"), "")
check("valid mixed", problems("[combat,spec:beast,mod:shift] show; [nopet,group:raid] hide; show"), "")
check("valid no prefix", problems("[nocombat,nomounted] show; hide"), "")
check("valid unit", problems("[@target,harm,nodead] show; hide"), "")
check("valid target=", problems("[target=focus,exists] show; hide"), "")
check("valid multiple brackets", problems("[combat][mod:alt] show; hide"), "")
check("unknown condition", problems("[comb] show; hide"), "unknown condition 'comb'")
check("unknown with no prefix", problems("[nocomb] show; hide"), "unknown condition 'nocomb'")
check("unclosed bracket", problems("[combat show; hide"), "a [ has no matching ]")
check("stray ]", problems("combat] show; hide"), "brackets don't match")
check("bad action", problems("[combat] shwo; hide"), "each clause must end in show or hide, not 'shwo'")
check("missing action", problems("[combat]; hide"), "a clause needs show or hide after its conditions")
check("trailing semicolon ok", problems("[combat] show; hide;"), "")

print(("%d checks, %d failed"):format(count, failures))
if failures > 0 then os.exit(1) end
