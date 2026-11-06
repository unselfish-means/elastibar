-- Standalone tests for Elastibar/Pages.lua. Run from the repo root:
--   lua tests/pages_test.lua

local ns = {}
assert(loadfile("Elastibar/RuleEditing.lua"))("Elastibar", ns)
assert(loadfile("Elastibar/Conditionals.lua"))("Elastibar", ns)
assert(loadfile("Elastibar/Pages.lua"))("Elastibar", ns)
local P = ns.Pages

local failures, count = 0, 0
local function check(name, got, want)
    count = count + 1
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, tostring(got), tostring(want)))
    end
end

local function picker(answers)
    if not answers then return "custom" end
    return answers.target .. "/" .. answers.state .. "/" .. answers.combat
end

-- Picker to condition
check("all any", P.FromPicker({ target = "any", state = "any", combat = "any" }), "")
check("friendly alive", P.FromPicker({ target = "friendly", state = "alive", combat = "any" }), "[help,nodead]")
check("friendly dead", P.FromPicker({ target = "friendly", state = "dead" }), "[help,dead]")
check("hostile in combat", P.FromPicker({ target = "hostile", combat = "combat" }), "[harm,combat]")
check("hostile out of combat", P.FromPicker({ target = "hostile", state = "any", combat = "nocombat" }), "[harm,nocombat]")
check("no target ignores alive", P.FromPicker({ target = "none", state = "dead", combat = "combat" }), "[noexists,combat]")

-- Condition to picker
check("empty is all any", picker(P.ToPicker("")), "any/any/any")
check("reads friendly alive", picker(P.ToPicker("[help,nodead]")), "friendly/alive/any")
check("reads any order and case", picker(P.ToPicker(" [ Combat , HARM ] ")), "hostile/any/combat")
check("other condition is custom", picker(P.ToPicker("[help,mod:shift]")), "custom")
check("two brackets are custom", picker(P.ToPicker("[help][harm]")), "custom")
check("question answered twice is custom", picker(P.ToPicker("[help,harm]")), "custom")
check("no target and dead is custom", picker(P.ToPicker("[noexists,dead]")), "custom")
check("text after brackets is custom", picker(P.ToPicker("[help] show")), "custom")

-- Round trip for every picker combination
for _, t in ipairs(P.PICKER[1].answers) do
    for _, s in ipairs(P.PICKER[2].answers) do
        for _, c in ipairs(P.PICKER[3].answers) do
            local answers = { target = t.key, state = t.key == "none" and "any" or s.key, combat = c.key }
            check("round trip " .. picker(answers), picker(P.ToPicker(P.FromPicker(answers))), picker(answers))
        end
    end
end

-- Summaries
check("summary always", P.Summary(""), "Always")
check("summary friendly alive", P.Summary("[help,nodead]"), "Friendly, alive")
check("summary hostile in combat", P.Summary("[harm,combat]"), "Hostile, in combat")
check("summary combat only", P.Summary("[nocombat]"), "Out of combat")
check("summary custom", P.Summary(" [mod:shift] "), "[mod:shift]")

-- Checks
check("check empty", #P.Check("", ns.RuleEditing), 0)
check("check good", #P.Check("[help,mod:shift]", ns.RuleEditing), 0)
check("check two brackets", #P.Check("[help][harm]", ns.RuleEditing), 0)
check("check unknown condition", P.Check("[hlep]", ns.RuleEditing)[1], "unknown condition 'hlep'")
check("check no brackets", P.Check("combat", ns.RuleEditing)[1], "write conditions in brackets, such as [combat]")
check("check action", P.Check("[combat] show; hide", ns.RuleEditing)[1], "a page condition is one set of conditions, without ;")

-- Rules
local target = {
    { condition = "[help,nodead]" }, { condition = "[help,dead]" },
    { condition = "[harm,combat]" }, { condition = "[harm,nocombat]" },
}
check("rule", P.Rule(target), "[help,nodead] 1; [help,dead] 2; [harm,combat] 3; [harm,nocombat] 4; hide")
check("one always page", P.Rule({ { condition = "" } }), "1")
check("always ends the rule", P.Rule({ { condition = "[harm]" }, { condition = "" }, { condition = "[help]" } }), "[harm] 1; 2")
check("first always", P.FirstAlways({ { condition = "[harm]" }, { condition = " " } }), 2)
check("no always", P.FirstAlways(target), nil)

-- Spec names translate in page rules like in visibility rules
local specInfo = { treeNames = { "Discipline", "Holy", "Shadow" }, dominant = { [1] = 3, [2] = 2 } }
check("spec names", ns.Conditionals.Translate(P.Rule({ { condition = "[spec:shadow,harm]" }, { condition = "[help]" } }), specInfo),
    "[spec:1,harm] 1; [help] 2; hide")
check("impossible page dropped", ns.Conditionals.Translate(P.Rule({ { condition = "[spec:disc]" }, { condition = "[help]" } }), specInfo),
    "[help] 2; hide")

print(("%d checks, %d failures"):format(count, failures))
if failures > 0 then os.exit(1) end
