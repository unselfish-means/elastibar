-- Text operations behind the visibility rule editor: presets, snippet insertion, and checks.
--
-- Pure Lua: no WoW API calls, so tests/ruleediting_test.lua can run it standalone.

local _, ns = ...
ns = ns or {}

local RuleEditing = {}
ns.RuleEditing = RuleEditing

RuleEditing.PRESETS = {
    { key = "always", label = "Always", rule = "show" },
    { key = "combat", label = "In combat", rule = "[combat] show; hide" },
    { key = "nocombat", label = "Out of combat", rule = "[nocombat] show; hide" },
    { key = "spec1", label = "Primary spec", rule = "[spec:1] show; hide" },
    { key = "spec2", label = "Secondary spec", rule = "[spec:2] show; hide" },
}

-- Conditions the game understands (each also works with a "no" prefix). The editor only
-- previews rules made of these, because the game prints "Unknown macro option" to chat for
-- anything else, including half-typed words.
local KNOWN = {}
for name in ([[actionbar bar bonusbar btn button canexitvehicle channel channeling combat cursor
    dead equipped worn exists extrabar flyable advflyable flying form stance group party raid harm
    help indoors outdoors mod modifier mounted overridebar pet petbattle possessbar resting
    shapeshift spec stealth swimming unithasvehicleui vehicleui known]]):gmatch("%S+") do
    KNOWN[name] = true
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Canonical spacing and case, so "[combat]show;hide" counts as the In combat preset.
local function canonical(rule)
    rule = trim(rule):lower():gsub("%s+", " ")
    rule = rule:gsub("%s*;%s*", "; "):gsub("%[%s*", "["):gsub("%s*%]%s*", "] "):gsub("%s*,%s*", ",")
    return trim(rule)
end

-- The preset key whose rule this is, or nil for a custom rule.
function RuleEditing.PresetFor(rule)
    local key = canonical(rule or "")
    for _, preset in ipairs(RuleEditing.PRESETS) do
        if canonical(preset.rule) == key then return preset.key end
    end
    return nil
end

-- Inserts a condition such as "combat" at the cursor (a 0-based character offset, as
-- EditBox:GetCursorPosition returns it). Inside [ ] it joins the conditions there with a
-- comma. Outside, it starts a new "[combat] show; " clause at the start of the cursor's
-- clause; an always/never rule becomes "[combat] show; hide". Returns the new text and the
-- new cursor, which sits just before the "]" so the next snippet joins the same brackets.
function RuleEditing.InsertSnippet(text, cursor, snippet)
    cursor = math.max(0, math.min(cursor or #text, #text))
    local before, after = text:sub(1, cursor), text:sub(cursor + 1)
    local open, close = before:match(".*()%["), before:match(".*()%]")
    if open and (not close or close < open) then
        local prev, nextChar = before:match("(%S?)%s*$"), after:match("^%s*(%S?)")
        local insert = snippet
        if prev ~= "[" and prev ~= "," then insert = "," .. insert end
        if nextChar ~= "]" and nextChar ~= "," and nextChar ~= "" then insert = insert .. "," end
        return before .. insert .. after, cursor + #insert
    end

    local bare = trim(text):lower()
    if bare == "" or bare == "show" or bare == "hide" then
        return "[" .. snippet .. "] show; hide", #snippet + 1
    end

    local pos = before:match(".*();") or 0
    while text:sub(pos + 1, pos + 1):match("%s") do pos = pos + 1 end
    local insert = "[" .. snippet .. "] show; "
    if text:sub(pos, pos) == ";" then insert = " " .. insert end
    return text:sub(1, pos) .. insert .. text:sub(pos + 1), pos + insert:find("]", 1, true) - 1
end

-- Checks a rule's syntax and condition names. Spec names are checked separately, by
-- Conditionals.Translate. Returns a list of problems; an empty list means it's safe to
-- hand the rule to the game for a preview.
function RuleEditing.Check(rule)
    local problems = {}
    for clause in (rule .. ";"):gmatch("([^;]*);") do
        local rest, broken = trim(clause), false
        while rest:sub(1, 1) == "[" do
            local body, after = rest:match("^%[([^%[%]]*)%]%s*(.*)$")
            if not body then
                problems[#problems + 1] = "a [ has no matching ]"
                broken = true
                break
            end
            for cond in (body .. ","):gmatch("([^,]*),") do
                cond = trim(cond)
                local name = cond:lower():match("^(%a+)")
                local isUnit = cond:sub(1, 1) == "@" or cond:lower():match("^target%s*=")
                if cond ~= "" and not isUnit then
                    local known = name and (KNOWN[name] or (name:sub(1, 2) == "no" and KNOWN[name:sub(3)]))
                    if not known then problems[#problems + 1] = ("unknown condition '%s'"):format(cond) end
                end
            end
            rest = after
        end
        local action = rest:lower()
        if broken or trim(clause) == "" then
            -- already reported, or an empty clause (a trailing ";")
        elseif rest:find("[%[%]]") then
            problems[#problems + 1] = "brackets don't match"
        elseif action == "" then
            problems[#problems + 1] = "a clause needs show or hide after its conditions"
        elseif action ~= "show" and action ~= "hide" then
            problems[#problems + 1] = ("each clause must end in show or hide, not '%s'"):format(rest)
        end
    end
    return problems
end

return RuleEditing
