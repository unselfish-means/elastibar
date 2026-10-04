-- Grid: Elastibar's own snapping grid (separate from Blizzard's Edit Mode grid, by decision).
-- Bars snap their top-left corner to it while dragged in Edit Mode; holding Shift skips
-- snapping. The lines are drawn only while one of our bars is being dragged.

local _, ns = ...

local Grid = {}
ns.Grid = Grid

Grid.DEFAULT_SIZE = 20

function Grid.Size()
    return (ns.db and ns.db.gridSize) or Grid.DEFAULT_SIZE
end

-- Nearest multiple of size (pure; also used for top edges measured up from the bottom).
function Grid.Snap(value, size)
    return math.floor(value / size + 0.5) * size
end

local overlay, lines = nil, {}

local function line(index)
    local texture = lines[index]
    if not texture then
        texture = overlay:CreateTexture(nil, "BACKGROUND")
        texture:SetColorTexture(0.2, 0.6, 1, 0.18)
        lines[index] = texture
    end
    texture:Show()
    return texture
end

function Grid.ShowLines()
    if not overlay then
        overlay = CreateFrame("Frame", nil, UIParent)
        overlay:SetAllPoints(UIParent)
        overlay:SetFrameStrata("BACKGROUND")
    end
    local size, width, height = Grid.Size(), UIParent:GetWidth(), UIParent:GetHeight()
    local n = 0
    for x = size, width, size do
        n = n + 1
        local t = line(n)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, height)
        t:SetSize(1, height)
    end
    for y = size, height, size do
        n = n + 1
        local t = line(n)
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y)
        t:SetSize(width, 1)
    end
    for i = n + 1, #lines do lines[i]:Hide() end
    overlay:Show()
end

function Grid.HideLines()
    if overlay then overlay:Hide() end
end
