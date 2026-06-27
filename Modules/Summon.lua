-- WarlockBuddy / Modules/Summon.lua
-- Ritual of Summoning helper. One secure button per group member - click a name
-- to start summoning that person (without changing your current target), and the
-- addon auto-announces "Summoning X - click the portal!" so the other two know to
-- click. Cuts the usual dungeon friction of typing it out every time.
--
-- Verified via GLM-5.2 + Codex: Ritual of Summoning is spellID 698 (costs 1 soul
-- shard); a secure button with type="spell" + spell + unit attributes casts on a
-- specific unit; secure attributes can only change out of combat (summoning is an
-- out-of-combat action anyway). The success event doesn't carry the target name,
-- so we cache it from the clicked button. See docs/TBC_API_NOTES.md (6f).

local ADDON, ns = ...
local M = ns:NewModule("Summon")

local MAXBTN = 8   -- show up to this many members; note the rest (no silent cap)

-- Shared drag: a secure button tiles its mover, so dragging any button moves the
-- panel (only while unlocked + out of combat). Plain click still summons.
local function attachDrag(btn, mover)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function()
        if not ns.db.locked and not InCombatLockdown() then mover:StartMoving() end
    end)
    btn:SetScript("OnDragStop", function()
        mover:StopMovingOrSizing()
        local point, _, _, x, y = mover:GetPoint()
        ns.db.summon.point[1], ns.db.summon.point[2], ns.db.summon.point[3] = point, x, y
    end)
end

function M:OnInit()
    local cfg = ns.db.summon
    self.ritualName = GetSpellInfo(ns.spellID.RitualOfSummoning)

    local mover = ns:MakeMover("Summon", 130, 24, cfg.point)
    self.mover = mover
    mover:SetScale(cfg.scale or 1)

    local header = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("BOTTOMLEFT", mover, "TOPLEFT", 0, 2)
    self.header = header

    self.buttons = {}
    for i = 1, MAXBTN do
        local btn = CreateFrame("Button", "WarlockBuddySummonBtn" .. i, mover,
            "SecureActionButtonTemplate")
        btn:SetSize(124, 20)
        btn:EnableMouse(true)
        btn:RegisterForClicks("AnyUp")
        btn:SetAttribute("type", "spell")
        if self.ritualName then btn:SetAttribute("spell", self.ritualName) end

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.5)

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", 4, 0)
        btn.label = label

        if i == 1 then
            btn:SetPoint("TOPLEFT", mover, "TOPLEFT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", self.buttons[i - 1], "BOTTOMLEFT", 0, -2)
        end

        btn:SetScript("PostClick", function(self) M.pending = self.summonName end)
        attachDrag(btn, mover)

        btn:Hide()
        self.buttons[i] = btn
    end

    self.dirty = false
    ns:RegisterEvent(self, "GROUP_ROSTER_UPDATE")
    ns:RegisterEvent(self, "PLAYER_REGEN_ENABLED")
    ns:RegisterEvent(self, "PLAYER_ENTERING_WORLD")
    ns:RegisterEvent(self, "UNIT_SPELLCAST_SUCCEEDED")

    self:Rebuild()
end

local function rosterUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, 40 do
            local u = "raid" .. i
            if UnitExists(u) and not UnitIsUnit(u, "player") then units[#units + 1] = u end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then units[#units + 1] = u end
        end
    end
    return units
end

function M:Rebuild()
    if not self.buttons or not self.ritualName then return end
    -- Secure attribute writes are forbidden in combat; defer until we leave it.
    if InCombatLockdown() then self.dirty = true; return end

    local units = rosterUnits()
    for i, btn in ipairs(self.buttons) do
        local u = units[i]
        if u then
            btn.summonName = UnitName(u)
            btn:SetAttribute("unit", u)
            btn.label:SetText(btn.summonName or u)
            local _, class = UnitClass(u)
            local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            if c then btn.label:SetTextColor(c.r, c.g, c.b) else btn.label:SetTextColor(1, 1, 1) end
            btn:Show()
        else
            btn:Hide()
        end
    end

    if #units == 0 then
        self.header:SetText("")
    elseif #units > MAXBTN then
        self.header:SetText(string.format("|cff9482c9Summon|r (+%d more)", #units - MAXBTN))
    else
        self.header:SetText("|cff9482c9Summon|r")
    end
end

function M:UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID)
    if unit ~= "player" then return end
    if spellID ~= ns.spellID.RitualOfSummoning then return end
    if self.pending and ns.db.summon.announce and IsInGroup() then
        local chan = IsInRaid() and "RAID" or "PARTY"
        SendChatMessage("Summoning " .. self.pending .. " - click the portal!", chan)
    end
    self.pending = nil
end

function M:PLAYER_REGEN_ENABLED()
    if self.dirty then self.dirty = false; self:Rebuild() end
end
function M:GROUP_ROSTER_UPDATE() self:Rebuild() end
function M:PLAYER_ENTERING_WORLD() self:Rebuild() end
