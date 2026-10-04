-- Reads the class's talent trees and each spec group's dominant tree.
--
-- On WoW: Forever the three talent columns are node groups inside one trait tree.
-- C_Traits.GetGroupDisplayInfoByTreeID names them; summing ranksPurchased of the
-- nodes in each group gives the points per tree.

local _, ns = ...

local SpecTrees = {}
ns.SpecTrees = SpecTrees

local function treeIDFor(configID)
    local ok, config = pcall(C_Traits.GetConfigInfo, configID)
    return ok and type(config) == "table" and config.treeIDs and config.treeIDs[1] or nil
end

-- Columns sorted by orderIndex: { { groupID, name, skillLineID }, ... }
local function columnsFor(treeID)
    local ok, info = pcall(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    if not ok or type(info) ~= "table" then return {} end
    local columns = {}
    for _, col in ipairs(info) do
        columns[#columns + 1] = { groupID = col.groupID, name = col.displayName, skillLineID = col.skillLineID, order = col.orderIndex or 0 }
    end
    table.sort(columns, function(a, b) return a.order < b.order end)
    return columns
end

local function ranksByGroup(configID, treeID)
    local ranks = {}
    local ok, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
    if not ok or type(nodeIDs) ~= "table" then return ranks end
    for _, nodeID in ipairs(nodeIDs) do
        local okNode, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if okNode and type(node) == "table" then
            for _, groupID in ipairs(node.groupIDs or {}) do
                ranks[groupID] = (ranks[groupID] or 0) + (node.ranksPurchased or 0)
            end
        end
    end
    return ranks
end

-- Returns the input Conditionals.Translate expects, plus per-group point totals for display:
-- { treeNames = { ... }, dominant = { [group] = treeIndex }, points = { [group] = { n, n, n } } }
-- A tie for most points, or no points at all, leaves that group without a dominant tree.
function SpecTrees.Get()
    local result = { treeNames = {}, dominant = {}, points = {} }
    local getConfig = C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup
    if not (getConfig and C_Traits) then return result end

    local columns
    for group = 1, 2 do
        local ok, configID = pcall(getConfig, group)
        local treeID = ok and configID and treeIDFor(configID)
        if treeID then
            columns = columns or columnsFor(treeID)
            local ranks = ranksByGroup(configID, treeID)
            local points, best, bestIndex, tied = {}, 0, nil, false
            for index, col in ipairs(columns) do
                local n = ranks[col.groupID] or 0
                points[index] = n
                if n > best then
                    best, bestIndex, tied = n, index, false
                elseif n == best and n > 0 then
                    tied = true
                end
            end
            result.points[group] = points
            result.dominant[group] = (not tied) and bestIndex or nil
        end
    end
    for index, col in ipairs(columns or {}) do result.treeNames[index] = col.name end
    return result
end
