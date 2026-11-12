-- Minimap icon and addon compartment entry, both driven by one LibDataBroker object
-- (docs/specs/options-and-minimap.md).
--   Left-click   toggle Edit Mode
--   Right-click  open the options
--   Drag         move the icon around the minimap

local addonName, ns = ...

local MinimapIcon = {}
ns.Minimap = MinimapIcon

MinimapIcon.ICON = "Interface\\Icons\\INV_Misc_Gear_01"

local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")

local function toggleEditMode()
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        if InCombatLockdown() then
            ns.Print("Can't close Edit Mode in combat.")
            return
        end
        HideUIPanel(EditModeManagerFrame)
    else
        ns.Options.EditBar(nil)
    end
end

local function barCountLine()
    local character, account = 0, 0
    for _, record in ipairs(ns.BarStore.List(ns.db, ns.charDB)) do
        if record.scope == "account" then account = account + 1 else character = character + 1 end
    end
    local total = character + account
    if total == 0 then return "No bars yet" end
    return ("%d %s (%d character, %d account)"):format(total, total == 1 and "bar" or "bars", character, account)
end

local broker = LDB:NewDataObject(addonName, {
    type = "launcher",
    label = "Elastibar",
    icon = MinimapIcon.ICON,
    OnClick = function(_, button)
        if button == "RightButton" then ns.Options.Open() else toggleEditMode() end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Elastibar")
        tooltip:AddLine(barCountLine(), 1, 1, 1)
        tooltip:AddLine(" ")
        tooltip:AddLine("Left-click: toggle Edit Mode", 0.6, 0.6, 0.6)
        tooltip:AddLine("Right-click: options", 0.6, 0.6, 0.6)
        tooltip:AddLine("Drag: move this icon", 0.6, 0.6, 0.6)
    end,
})

function MinimapIcon.IsShown()
    return not ns.db.minimap.hide
end

function MinimapIcon.SetShown(show)
    ns.db.minimap.hide = not show
    if show then DBIcon:Show(addonName) else DBIcon:Hide(addonName) end
end

function MinimapIcon.InCompartment()
    return ns.db.minimap.showInCompartment == true
end

-- LibDBIcon records the choice in ns.db.minimap.showInCompartment.
function MinimapIcon.SetInCompartment(show)
    if show then DBIcon:AddButtonToCompartment(addonName) else DBIcon:RemoveButtonFromCompartment(addonName) end
end

ns.On("PLAYER_LOGIN", function()
    -- New installs show both; after that, LibDBIcon keeps the position and choices here.
    ns.db.minimap = ns.db.minimap or { showInCompartment = true }
    DBIcon:Register(addonName, broker, ns.db.minimap)
end)
