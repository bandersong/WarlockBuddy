-- WarlockBuddy / Modules/Shards.lua
-- Soul shard counter + healthstone / soulstone inventory readout.
-- Big readable number, color-coded: red when low, orange when bag nearly full.

local ADDON, ns = ...
local M = ns:NewModule("Shards")

function M:OnInit()
    local cfg = ns.db.shards
    local mover = ns:MakeMover("Shards", 120, 56, cfg.point, "Soul shards + healthstone/soulstone counts")
    self.mover = mover

    -- Use an explicit SetFont rather than relying on a "Huge" font template
    -- existing in 2.5 - this guarantees a big, readable shard number on every
    -- client. Inherit GameFontNormal first so we keep sane defaults, then resize.
    local count = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    count:SetFont(STANDARD_TEXT_FONT, 26, "OUTLINE")
    count:SetPoint("CENTER", mover, "CENTER", 0, 6)
    self.count = count

    local label = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOP", count, "BOTTOM", 0, -2)
    self.label = label

    mover:SetScale(cfg.scale or 1)

    ns:RegisterEvent(self, "BAG_UPDATE_DELAYED")
    ns:RegisterEvent(self, "PLAYER_ENTERING_WORLD")
    self:Refresh()
end

local function totalOf(ids)
    local n = 0
    for _, id in ipairs(ids) do n = n + (GetItemCount(id) or 0) end
    return n
end

function M:Refresh()
    if not self.count then return end
    local cfg = ns.db.shards
    local shards = GetItemCount(ns.itemID.SoulShard) or 0

    -- color: red low, orange near-full, purple normal
    local r, g, b = 0.78, 0.65, 1.0
    if shards <= (cfg.warnLow or 3) then
        r, g, b = 1, 0.2, 0.2
    elseif shards >= (cfg.warnHigh or 28) then
        r, g, b = 1, 0.6, 0.1
    end
    self.count:SetText(shards)
    self.count:SetTextColor(r, g, b)

    local hs = totalOf(ns.itemID.Healthstones)
    local ss = totalOf(ns.itemID.Soulstones)
    self.label:SetText(string.format("shards  |cffffffffHS|r %d  |cffffffffSS|r %d", hs, ss))
end

M.BAG_UPDATE_DELAYED   = M.Refresh
M.PLAYER_ENTERING_WORLD = M.Refresh
