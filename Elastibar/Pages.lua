-- Pages: a bar can hold several pages of buttons, each with a condition. The first page whose
-- condition matches is shown; if none match, the bar shows nothing.
--
-- A condition is bracket text such as "[help,nodead]" or "[harm][mod:shift]", or "" for a page
-- that always matches. The picker covers the common cases (target, alive or dead, combat) and
-- writes conditions for them; anything else is a custom condition typed as text.
--
-- Pure Lua: no WoW API calls, so tests/pages_test.lua can run it standalone.

local _, ns = ...
ns = ns or {}

local Pages = {}
ns.Pages = Pages

-- The picker's questions, each with its answers and the condition each answer writes.
-- The first answer of each is "Any", which writes nothing.
Pages.PICKER = {
    { key = "target", label = "Target", answers = {
        { key = "any", label = "Any" },
        { key = "friendly", label = "Friendly", cond = "help" },
        { key = "hostile", label = "Hostile", cond = "harm" },
        { key = "none", label = "None", cond = "noexists" },
    } },
    { key = "state", label = "Target is", answers = {
        { key = "any", label = "Any" },
        { key = "alive", label = "Alive", cond = "nodead" },
        { key = "dead", label = "Dead", cond = "dead" },
    } },
    { key = "combat", label = "You are", answers = {
        { key = "any", label = "Any" },
        { key = "combat", label = "In combat", cond = "combat" },
        { key = "nocombat", label = "Out of combat", cond = "nocombat" },
    } },
}

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Writes the condition for picker answers, e.g. { target = "friendly", state = "alive" }
-- gives "[help,nodead]". All "any" gives "" (always matches). With no target there's nothing
-- to be alive or dead, so "None" ignores the second question.
function Pages.FromPicker(answers)
    local conds = {}
    for _, question in ipairs(Pages.PICKER) do
        local chosen = answers[question.key]
        if not (question.key == "state" and answers.target == "none") then
            for _, answer in ipairs(question.answers) do
                if answer.key == chosen and answer.cond then conds[#conds + 1] = answer.cond end
            end
        end
    end
    if #conds == 0 then return "" end
    return "[" .. table.concat(conds, ",") .. "]"
end

-- Reads a condition back into picker answers, or returns nil if the picker can't show it
-- (custom conditions: other conditions, several brackets, or a question answered twice).
function Pages.ToPicker(condition)
    local answers = { target = "any", state = "any", combat = "any" }
    local text = trim(condition or "")
    if text == "" then return answers end
    local body = text:match("^%[([^%[%]]*)%]$")
    if not body then return nil end
    for cond in (body .. ","):gmatch("([^,]*),") do
        cond = trim(cond):lower()
        if cond ~= "" then
            local found
            for _, question in ipairs(Pages.PICKER) do
                for _, answer in ipairs(question.answers) do
                    if answer.cond == cond then found = { question.key, answer.key } end
                end
            end
            if not found or answers[found[1]] ~= "any" then return nil end
            answers[found[1]] = found[2]
        end
    end
    if answers.target == "none" and answers.state ~= "any" then return nil end
    return answers
end

-- A short name for a condition, for the page labels: "Friendly, alive", "Always", or the
-- condition text itself when it's custom.
function Pages.Summary(condition)
    local answers = Pages.ToPicker(condition)
    if not answers then return trim(condition) end
    local parts = {}
    for _, question in ipairs(Pages.PICKER) do
        for _, answer in ipairs(question.answers) do
            if answer.cond and answers[question.key] == answer.key then
                parts[#parts + 1] = #parts == 0 and answer.label or answer.label:lower()
            end
        end
    end
    if #parts == 0 then return "Always" end
    return table.concat(parts, ", ")
end

-- Checks a typed condition: it must be bracket conditions only, with no show or hide after
-- them. Uses RuleEditing.Check for the conditions themselves. Returns a list of problems.
function Pages.Check(condition, ruleEditing)
    local text = trim(condition or "")
    if text == "" then return {} end
    if text:find(";") then return { "a page condition is one set of conditions, without ;" } end
    if not text:match("^%[.*%]$") then return { "write conditions in brackets, such as [combat]" } end
    return ruleEditing.Check(text .. " show")
end

-- The state driver rule that picks a page: "[help,nodead] 1; [help,dead] 2; hide".
-- An "always" page ends the rule, since nothing after it can be reached.
function Pages.Rule(pages)
    local clauses = {}
    for index, page in ipairs(pages) do
        local condition = trim(page.condition or "")
        if condition == "" then
            clauses[#clauses + 1] = tostring(index)
            return table.concat(clauses, "; ")
        end
        clauses[#clauses + 1] = condition .. " " .. index
    end
    clauses[#clauses + 1] = "hide"
    return table.concat(clauses, "; ")
end

-- The first page that always matches; pages after it are never shown. Nil if none does.
function Pages.FirstAlways(pages)
    for index, page in ipairs(pages) do
        if trim(page.condition or "") == "" then return index end
    end
end

return Pages
