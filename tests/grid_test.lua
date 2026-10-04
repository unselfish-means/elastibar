-- Standalone tests for the pure parts of Elastibar/Grid.lua. Run from the repo root:
--   lua tests/grid_test.lua

local ns = {}
assert(loadfile("Elastibar/Grid.lua"))("Elastibar", ns)
local G = ns.Grid

local failures, count = 0, 0
local function check(name, got, want)
    count = count + 1
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, tostring(got), tostring(want)))
    end
end

check("snap down", G.Snap(29, 20), 20)
check("snap up", G.Snap(31, 20), 40)
check("snap half rounds up", G.Snap(30, 20), 40)
check("snap exact", G.Snap(60, 20), 60)
check("snap zero", G.Snap(4, 20), 0)
check("snap other size", G.Snap(37, 25), 25)
check("default size without db", G.Size(), 20)
ns.db = { gridSize = 32 }
check("size from db", G.Size(), 32)

print(("%d checks, %d failed"):format(count, failures))
if failures > 0 then os.exit(1) end
