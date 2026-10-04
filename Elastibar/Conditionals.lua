-- Translates Elastibar's extended macro conditionals into native ones.
--
-- The game only understands [spec:N] (N = talent group: 1 Primary, 2 Secondary).
-- Elastibar also accepts talent tree names, e.g. [spec:beastmastery] or [spec:beast],
-- and rewrites them to the spec groups whose dominant tree matches.
--
-- Pure Lua: no WoW API calls, so tests/conditionals_test.lua can run it standalone.

local _, ns = ...
ns = ns or {}

local Conditionals = {}
ns.Conditionals = Conditionals

local SPEC_GROUPS = { 1, 2 }

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Lowercase and drop spaces/punctuation. Non-ASCII bytes are kept so localized names still match.
function Conditionals.Normalize(s)
    return (s:lower():gsub("[%s%p]", ""))
end

-- Resolves a typed tree name against the client's tree names.
-- An exact (normalized) match wins; otherwise the token must be a prefix of exactly one name.
-- Returns treeIndex, or nil plus "unknown" or "ambiguous".
function Conditionals.ResolveTreeName(token, treeNames)
    local key = Conditionals.Normalize(token)
    if key == "" then return nil, "unknown" end
    local found
    for index, name in ipairs(treeNames) do
        local normalized = Conditionals.Normalize(name)
        if normalized == key then return index end
        if normalized:sub(1, #key) == key then
            if found then return nil, "ambiguous" end
            found = index
        end
    end
    if found then return found end
    return nil, "unknown"
end

-- Spec groups (subset of {1, 2}) that one spec argument list ("1/beast") selects.
local function groupsFor(args, specInfo, problems)
    local selected = {}
    for arg in args:gmatch("[^/]+") do
        arg = trim(arg)
        local n = tonumber(arg)
        if n then
            selected[n] = true
        else
            local tree, err = Conditionals.ResolveTreeName(arg, specInfo.treeNames or {})
            if tree then
                for _, group in ipairs(SPEC_GROUPS) do
                    if specInfo.dominant and specInfo.dominant[group] == tree then selected[group] = true end
                end
            else
                problems[#problems + 1] = ("%s spec name '%s'"):format(err, arg)
            end
        end
    end
    return selected
end

local function joinGroups(set)
    local list = {}
    for _, group in ipairs(SPEC_GROUPS) do
        if set[group] then list[#list + 1] = tostring(group) end
    end
    return table.concat(list, "/")
end

-- Rewrites one bracket's conditions. Returns the new bracket text (nil if it can never be
-- true) and whether anything was rewritten. Brackets without spec names are returned as-is.
local function translateBracket(body, specInfo, problems)
    local out, rewritten = {}, false
    for cond in (body .. ","):gmatch("([^,]*),") do
        local trimmed = trim(cond)
        local negated, args = trimmed:lower():match("^(n?o?)spec:(.+)$")
        local isSpec = args and (negated == "" or negated == "no")
        local hasName = isSpec and args:find("[^%d/%s]")
        if hasName then
            rewritten = true
            local selected = groupsFor(trimmed:match(":(.+)$"), specInfo, problems)
            if negated == "no" then
                local remaining = {}
                for _, group in ipairs(SPEC_GROUPS) do
                    if not selected[group] then remaining[group] = true end
                end
                selected = remaining
                local all = true
                for _, group in ipairs(SPEC_GROUPS) do all = all and selected[group] == true end
                if all then trimmed = nil end -- always true: drop the condition
            end
            if trimmed then
                local groups = joinGroups(selected)
                if groups == "" then return nil, true end -- never true: drop the bracket
                trimmed = "spec:" .. groups
            end
        end
        if trimmed and trimmed ~= "" then out[#out + 1] = trimmed end
    end
    if not rewritten then return "[" .. body .. "]", false end
    return "[" .. table.concat(out, ",") .. "]", true
end

-- Translates a full rule such as "[combat,spec:beast] show; hide".
-- specInfo = { treeNames = { "Beast Mastery", ... }, dominant = { [1] = treeIndex or nil, [2] = ... } }
-- Returns the native rule and a list of problems (unknown/ambiguous names).
function Conditionals.Translate(rule, specInfo)
    local problems, clauses = {}, {}
    for clause in (rule .. ";"):gmatch("([^;]*);") do
        local rest = trim(clause)
        local kept, changed = {}, false
        while true do
            local body, after = rest:match("^%[([^%]]*)%]%s*(.*)$")
            if not body then break end
            local translated, rewritten = translateBracket(body, specInfo, problems)
            changed = changed or rewritten
            if translated then kept[#kept + 1] = translated end
            rest = after
        end
        if not changed then
            if rest ~= "" or #kept > 0 then clauses[#clauses + 1] = trim(clause) end
        elseif #kept > 0 then
            clauses[#clauses + 1] = table.concat(kept) .. " " .. rest
        end
        -- else: every bracket was impossible, so the whole clause can never match.
    end
    return table.concat(clauses, "; "), problems
end

return Conditionals
