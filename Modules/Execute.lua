-- WarlockBuddy / Modules/Execute.lua
-- Drain Soul shard-on-kill helper. When the current target drops into execute
-- range (default 25% health), flash a big "DRAIN SOUL" cue + sound so she swaps
-- to Drain Soul and banks a soul shard on the kill. Spec-agnostic: every
-- warlock wants shards, and a brand-new warlock especially won't remember to do
-- this mid-fight.

local ADDON, ns = ...
local M = ns:NewModule("Execute")

function M:OnInit()
    local cfg = ns.db.execute
    local mover = ns:MakeMover("Execute", 64, 64, cfg.point)
    self.mover = mover
    mover:SetScale(cfg.scale or 1)

    local icon = mover:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local _, _, tex = GetSpellInfo(ns.spellID.DrainSoul)
    icon:SetTexture(tex or "Interface\\Icons\\Spell_Shadow_HForcomph")
    self.icon = icon

    local glow = mover:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("CENTER")
    glow:SetSize(96, 96)
    glow:SetTexture("Interface\\Cooldown\\star4")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.6, 0.2, 0.9)
    self.glow = glow

    local txt = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    txt:SetPoint("TOP", mover, "BOTTOM", 0, -2)
    txt:SetText("DRAIN SOUL")
    self.txt = txt

    self:Hide()

    self.armed = false   -- rising-edge guard so we alert once per entry
    ns:RegisterEvent(self, "PLAYER_TARGET_CHANGED")
    ns:RegisterEvent(self, "UNIT_HEALTH")
    ns:RegisterEvent(self, "UNIT_MAXHEALTH")
    ns:RegisterEvent(self, "PLAYER_ENTERING_WORLD")

    mover.t = 0
    mover:SetScript("OnUpdate", function(_, e)
        if not self.icon:IsShown() then return end
        mover.t = mover.t + e
        self.glow:SetScale(0.9 + 0.15 * math.sin(mover.t * 7))
    end)

    self:Check()
end

function M:Hide()
    self.icon:Hide(); self.glow:Hide(); self.txt:Hide()
end

function M:Show()
    self.icon:Show(); self.glow:Show(); self.txt:Show()
end

function M:Check()
    if not self.icon then return end
    local cfg = ns.db.execute

    if not UnitExists("target") or UnitIsDead("target")
        or not UnitCanAttack("player", "target") then
        self:Hide(); self.armed = false
        return
    end

    local h, hm = UnitHealth("target"), UnitHealthMax("target")
    if not hm or hm <= 0 then self:Hide(); self.armed = false; return end
    local frac = h / hm

    if frac > 0 and frac <= (cfg.threshold or 0.25) then
        self.txt:SetText(string.format("DRAIN SOUL  |cffffffff%d%%|r", math.floor(frac * 100)))
        self:Show()
        if not self.armed then
            self.armed = true
            if cfg.flash then ns:Flash(0.6, 0.2, 0.9) end
            if cfg.sound then ns:PlayAlertSound() end
        end
    else
        self:Hide(); self.armed = false
    end
end

function M:PLAYER_TARGET_CHANGED() self.armed = false; self:Check() end
function M:UNIT_HEALTH(unit) if unit == "target" then self:Check() end end
function M:UNIT_MAXHEALTH(unit) if unit == "target" then self:Check() end end
function M:PLAYER_ENTERING_WORLD() self:Check() end
