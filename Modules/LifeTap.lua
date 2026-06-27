-- WarlockBuddy / Modules/LifeTap.lua
-- Life Tap safety cue. Warlocks trade health for mana with Life Tap, and a newer
-- player can easily tap themselves into a dangerous health range. This shows a
-- simple, honest two-state cue based purely on live health/mana fractions:
--   GREEN  "LIFE TAP"    - mana is low and your health is high enough to tap safely
--   RED    "HP LOW"      - mana is low but tapping now would drop you too far
-- Hidden when mana is fine.
--
-- Deliberately NO "expected mana returned" number: the per-rank values and any
-- spell-power scaling are disputed/ambiguous for 2.5 (one reviewer's data was
-- contaminated with WotLK ranks and the wrong talent tree), so showing a precise
-- figure would risk being wrong. A percentage-based safety cue needs none of that
-- and is locale- and patch-proof. (See docs/DECISIONS.md.)

local ADDON, ns = ...
local M = ns:NewModule("LifeTap")

function M:OnInit()
    local cfg = ns.db.lifetap
    local mover = ns:MakeMover("LifeTap", 130, 28, cfg.point)
    self.mover = mover
    mover:SetScale(cfg.scale or 1)

    local txt = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    txt:SetPoint("CENTER")
    self.txt = txt

    self.txt:SetText("")

    ns:RegisterEvent(self, "UNIT_HEALTH")
    ns:RegisterEvent(self, "UNIT_POWER_UPDATE")
    ns:RegisterEvent(self, "PLAYER_ENTERING_WORLD")

    self:Check()
end

function M:Check()
    if not self.txt then return end
    local cfg = ns.db.lifetap

    local maxMana = UnitPowerMax("player", 0) or 0
    if maxMana <= 0 then self.txt:SetText(""); return end
    local manaFrac = (UnitPower("player", 0) or 0) / maxMana

    if manaFrac >= (cfg.manaBelow or 0.30) then
        self.txt:SetText("")   -- mana fine, nothing to nag
        return
    end

    local maxHP = UnitHealthMax("player") or 0
    local hpFrac = maxHP > 0 and ((UnitHealth("player") or 0) / maxHP) or 0

    if hpFrac > (cfg.safeHpAbove or 0.40) then
        self.txt:SetText("|cff33ff33\226\151\143 LIFE TAP|r")           -- green dot + label
    else
        self.txt:SetText("|cffff3333\226\156\150 HP LOW - heal|r")      -- red x + warn
    end
end

function M:UNIT_HEALTH(unit) if unit == "player" then self:Check() end end
function M:UNIT_POWER_UPDATE(unit) if unit == "player" then self:Check() end end
function M:PLAYER_ENTERING_WORLD() self:Check() end
