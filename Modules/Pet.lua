-- WarlockBuddy / Modules/Pet.lua
-- Pet panel: name, health & mana bars, plus warlock-specific status flags:
--   * Soul Link active?  (mitigation talent buff)
--   * Dark Pact ready?   (pet has enough mana to drain)
--   * "No pet!" nag when unsummoned.

local ADDON, ns = ...
local M = ns:NewModule("Pet")

function M:OnInit()
    local cfg = ns.db.pet
    local mover = ns:MakeMover("Pet", 160, 54, cfg.point, "Pet health, mana, Soul Link, Dark Pact")
    self.mover = mover
    mover:SetScale(cfg.scale or 1)

    local name = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", mover, "TOPLEFT", 0, 0)
    self.name = name

    local hp = ns:MakeBar(mover, 160, 14)
    hp:ClearAllPoints()
    hp:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    hp.icon:Hide()
    hp:SetStatusBarColor(0.2, 0.8, 0.2)
    self.hp = hp

    local mana = ns:MakeBar(mover, 160, 10)
    mana:ClearAllPoints()
    mana:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -2)
    mana.icon:Hide()
    mana:SetStatusBarColor(0.2, 0.4, 0.9)
    self.mana = mana

    local status = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", mana, "BOTTOMLEFT", 0, -2)
    self.status = status

    ns:RegisterEvent(self, "UNIT_PET")
    ns:RegisterEvent(self, "UNIT_HEALTH")
    ns:RegisterEvent(self, "UNIT_POWER_UPDATE")
    ns:RegisterEvent(self, "UNIT_MAXHEALTH")
    ns:RegisterEvent(self, "PLAYER_ENTERING_WORLD")

    self:Refresh()
end

function M:Refresh()
    if not self.mover then return end
    local cfg = ns.db.pet

    if not UnitExists("pet") or UnitIsDead("pet") then
        self.name:SetText("|cffff5555No pet|r")
        self.hp:Hide(); self.mana:Hide()
        self.status:SetText("summon a demon")
        return
    end

    self.name:SetText(UnitName("pet") or "Pet")

    local h, hm = UnitHealth("pet"), UnitHealthMax("pet")
    if hm and hm > 0 then
        self.hp:Show(); self.hp:SetValue(h / hm)
        self.hp.timeText:SetText(math.floor(h / hm * 100) .. "%")
        self.hp.nameText:SetText("")
    end

    local p, pm = UnitPower("pet", 0), UnitPowerMax("pet", 0)
    if pm and pm > 0 then
        self.mana:Show()
        local frac = p / pm
        self.mana:SetValue(frac)
        self.mana.timeText:SetText(math.floor(frac * 100) .. "%")
        self.mana.nameText:SetText("")
        self._petManaFrac = frac
    else
        self.mana:Hide()
        self._petManaFrac = 0
    end

    -- status line: Soul Link + Dark Pact readiness
    local parts = {}
    local sl = ns.spellName.SoulLink
    if sl and ns:FindBuff("player", sl) then
        parts[#parts + 1] = "|cff55ff55SoulLink|r"
    end
    if (self._petManaFrac or 0) >= (cfg.darkPactWarn or 0.3) then
        parts[#parts + 1] = "|cff66aaffDarkPact ok|r"
    else
        parts[#parts + 1] = "|cffff8800DarkPact low|r"
    end
    self.status:SetText(table.concat(parts, "  "))
end

function M:UNIT_PET(unit) if unit == "player" then self:Refresh() end end
function M:UNIT_HEALTH(unit) if unit == "pet" then self:Refresh() end end
function M:UNIT_MAXHEALTH(unit) if unit == "pet" then self:Refresh() end end
function M:UNIT_POWER_UPDATE(unit) if unit == "pet" then self:Refresh() end end
function M:PLAYER_ENTERING_WORLD() self:Refresh() end
