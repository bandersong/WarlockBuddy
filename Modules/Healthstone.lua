-- WarlockBuddy / Modules/Healthstone.lua
-- One-click HEALTHSTONE panic button that works IN COMBAT.
--
-- In-combat item use is a protected action: an addon can't just /use an item, it
-- needs a hardware click on a SecureActionButton. So this is a real secure button
-- the player clicks (or keybinds via a /click macro - see README).
--
-- A warlock can only hold one healthstone at a time, and its item id varies by
-- rank/talent, so we find whichever one she's carrying and point the button at it
-- with `/use item:<id>`. SecureActionButton attributes can't be changed in combat,
-- so we (re)point it OUT of combat (bag changes + on leaving combat) and the value
-- persists through the next fight. Verified safe + correct via GLM-5.2 + Codex
-- (both 95-99% confidence); see docs/TBC_API_NOTES.md (6d).

local ADDON, ns = ...
local M = ns:NewModule("Healthstone")

local FALLBACK_ICON = "Interface\\Icons\\INV_Stone_04"

function M:OnInit()
    -- Secure-button setup (SetAttribute/SetPoint/RegisterForClicks) is forbidden in
    -- combat. OnInit normally runs at login (out of combat), but a /reload mid-fight
    -- would land here in combat - defer the build to when combat ends.
    if InCombatLockdown() then
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        waiter:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents(); self:SetScript("OnEvent", nil); M:Build()
        end)
        return
    end
    self:Build()
end

function M:Build()
    local cfg = ns.db.healthstone
    local mover = ns:MakeMover("Healthstone", 40, 40, cfg.point, "One-click healthstone (panic heal)")
    self.mover = mover
    mover:SetScale(cfg.scale or 1)

    -- the secure button (our own frame; never parented under protected UI).
    -- It is ALWAYS mouse-enabled so the panic click works regardless of lock
    -- state. Dragging is handled by the button itself and only when unlocked, so
    -- a plain click always uses the stone and a press-drag (while unlocked) moves
    -- it. This avoids the "button dead until locked" trap.
    local btn = CreateFrame("Button", "WarlockBuddyHealthstoneButton", mover,
        "SecureActionButtonTemplate")
    btn:SetAllPoints(mover)
    btn:EnableMouse(true)
    btn:RegisterForClicks("AnyUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetAttribute("type", "macro")
    self.btn = btn
    mover.secureChild = btn

    -- drag moves the parent mover, but only while unlocked and out of combat
    btn:SetScript("OnDragStart", function()
        if not ns.db.locked and not InCombatLockdown() then mover:StartMoving() end
    end)
    btn:SetScript("OnDragStop", function()
        mover:StopMovingOrSizing()
        local point, _, _, x, y = mover:GetPoint()
        cfg.point[1], cfg.point[2], cfg.point[3] = point, x, y
    end)

    -- The secure button is always mouse-on (for clicking), so gate its tooltip to
    -- config mode by hand to match the other frames.
    btn:SetScript("OnEnter", function(self)
        if ns.db.locked then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cff9482c9Healthstone|r")
        GameTooltip:AddLine("One-click healthstone (panic heal)", 1, 1, 1, true)
        GameTooltip:AddLine("Click = use · Drag = move", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetTexture(FALLBACK_ICON)
    self.icon = icon

    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetAllPoints(icon)
    self.cd = cd

    local countText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    countText:SetPoint("BOTTOMRIGHT", -2, 2)
    self.countText = countText

    -- re-sync the secure child's mouse state now that it exists
    ns:LockMover(mover, ns.db.locked)

    ns:RegisterEvent(self, "BAG_UPDATE_DELAYED")
    ns:RegisterEvent(self, "BAG_UPDATE_COOLDOWN")
    ns:RegisterEvent(self, "PLAYER_REGEN_ENABLED")   -- left combat: apply deferred re-point
    ns:RegisterEvent(self, "PLAYER_ENTERING_WORLD")

    self:Update()
end

-- Find the id of the healthstone currently carried (first present in the list).
local function heldHealthstone()
    for _, id in ipairs(ns.itemID.Healthstones) do
        if (GetItemCount(id) or 0) > 0 then return id end
    end
    return nil
end

-- Re-point the button + refresh visuals. Attribute writes are skipped in combat
-- (they'd taint); we re-run on PLAYER_REGEN_ENABLED so it self-heals after a fight.
function M:Update()
    if not self.btn then return end
    local id = heldHealthstone()

    if not InCombatLockdown() then
        if id then
            self.btn:SetAttribute("macrotext", "/use item:" .. id)
            self.icon:SetTexture(GetItemIcon(id) or FALLBACK_ICON)
            self.icon:SetVertexColor(1, 1, 1)
            self.countText:SetText("")
            self.currentID = id
        else
            self.btn:SetAttribute("macrotext", "")
            self.icon:SetTexture(FALLBACK_ICON)
            self.icon:SetVertexColor(0.4, 0.4, 0.4)   -- dim = none in bags
            self.countText:SetText("|cffff5555 0|r")
            self.currentID = nil
        end
    end

    self:RefreshCooldown()
end

function M:RefreshCooldown()
    if not self.cd then return end
    local id = self.currentID
    if id then
        local start, duration = GetItemCooldown(id)
        if start and duration and duration > 0 then
            self.cd:SetCooldown(start, duration)
        else
            self.cd:SetCooldown(0, 0)   -- clear (Cooldown:Clear isn't in 2.5)
        end
    else
        self.cd:SetCooldown(0, 0)       -- no stone held: clear any stale sweep
    end
end

M.BAG_UPDATE_DELAYED    = M.Update
M.PLAYER_REGEN_ENABLED  = M.Update
M.PLAYER_ENTERING_WORLD = M.Update
M.BAG_UPDATE_COOLDOWN   = M.RefreshCooldown
