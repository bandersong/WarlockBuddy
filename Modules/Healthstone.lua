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
    local cfg = ns.db.healthstone
    local mover = ns:MakeMover("Healthstone", 40, 40, cfg.point)
    self.mover = mover
    mover:SetScale(cfg.scale or 1)

    -- the secure button (our own frame; never parented under protected UI)
    local btn = CreateFrame("Button", "WarlockBuddyHealthstoneButton", mover,
        "SecureActionButtonTemplate")
    btn:SetAllPoints(mover)
    btn:RegisterForClicks("AnyUp")
    btn:SetAttribute("type", "macro")
    self.btn = btn
    mover.secureChild = btn

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
    end
end

M.BAG_UPDATE_DELAYED    = M.Update
M.PLAYER_REGEN_ENABLED  = M.Update
M.PLAYER_ENTERING_WORLD = M.Update
M.BAG_UPDATE_COOLDOWN   = M.RefreshCooldown
