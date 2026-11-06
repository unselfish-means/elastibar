-- SpellbookTab: a toggle on the edge of the spellbook that opens your bars' pages for editing
-- (PageStack.lua), so you can drag spells onto them straight from the book. It opens the bar
-- you edited last; the arrows in the pages' heading move to other bars.
--
-- The tab is parented to UIParent and only anchored to the spellbook, and shown and hidden
-- with HookScript, so Blizzard's frame isn't touched. Forever may use the classic
-- SpellBookFrame or Retail's load-on-demand PlayerSpellsFrame; it attaches to whichever loads.

local _, ns = ...

local SpellbookTab = {}
ns.SpellbookTab = SpellbookTab

local tab, book

local function refresh()
    if not tab then return end
    local open = ns.PageStack.AnyOpen()
    tab:SetText(open and "Close pages" or "Elastibar pages")
    if open then tab:LockHighlight() else tab:UnlockHighlight() end
end

local function attach()
    local frame = PlayerSpellsFrame or SpellBookFrame
    if tab or not frame then return end
    book = frame
    tab = CreateFrame("Button", "ElastibarSpellbookTab", UIParent, "UIPanelButtonTemplate")
    tab:SetSize(120, 24)
    tab:SetFrameStrata("HIGH")
    tab:SetPoint("BOTTOMLEFT", book, "BOTTOMRIGHT", 2, 40)
    tab:SetScript("OnClick", function()
        if InCombatLockdown() then
            ns.Print("Can't change pages in combat.")
        elseif not ns.PageStack.Toggle() then
            ns.Print("You have no bars yet. Create one with /eb new [account] [name].")
        end
    end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Elastibar pages")
        GameTooltip:AddLine("Opens your bar's pages so you can drag spells onto them. The arrows beside the bar's name switch bars.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tab:SetShown(book:IsShown())
    book:HookScript("OnShow", function() tab:Show() end)
    book:HookScript("OnHide", function() tab:Hide() end)
    refresh()
end

ns.PageStack.OnChange = refresh

ns.On("PLAYER_LOGIN", attach)
ns.On("ADDON_LOADED", attach) -- PlayerSpellsFrame loads on demand
