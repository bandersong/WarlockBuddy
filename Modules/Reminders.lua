-- WarlockBuddy / Modules/Reminders.lua
-- Gentle "you forgot something" nags:
--   * No Fel/Demon Armor up
--   * No weapon stone (Spellstone/Firestone) enchant on main hand
-- Shows a small stacked list of missing buffs; hides itself when all good.

local ADDON, ns = ...
local M = ns:NewModule("Reminders")

function M:OnInit()
    local cfg = ns.db.reminders
    local mover = ns:MakeMover("Reminders", 200, 40, cfg.point, "Armor / weapon-stone reminders")
    self.mover = mover

    local txt = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetPoint("TOP")
    txt:SetJustifyH("CENTER")
    self.txt = txt

    ns:RegisterEvent(self, "UNIT_AURA")
    ns:RegisterEvent(self, "PLAYER_ENTERING_WORLD")
    ns:RegisterEvent(self, "PLAYER_EQUIPMENT_CHANGED")

    -- slow ticker for the weapon-enchant timer which has no event
    mover.elapsed = 0
    mover:SetScript("OnUpdate", function(_, e)
        mover.elapsed = mover.elapsed + e
        if mover.elapsed >= 1.0 then mover.elapsed = 0; self:Check() end
    end)

    self:Check()
end

function M:Check()
    if not self.txt then return end
    local cfg = ns.db.reminders
    local missing = {}

    -- Armor: any of Fel/Demon/Demon Skin up?
    if cfg.armor then
        local hasArmor =
            (ns.spellName.FelArmor   and ns:FindBuff("player", ns.spellName.FelArmor)) or
            (ns.spellName.DemonArmor and ns:FindBuff("player", ns.spellName.DemonArmor)) or
            (ns.spellName.DemonSkin  and ns:FindBuff("player", ns.spellName.DemonSkin))
        if not hasArmor then missing[#missing + 1] = "|cffff5555No Armor!|r" end
    end

    -- Weapon stone enchant
    if cfg.weaponStone then
        local hasMain = GetWeaponEnchantInfo()
        if not hasMain then missing[#missing + 1] = "|cffffaa00No Spell/Firestone|r" end
    end

    -- Soul Link (optional, off by default)
    if cfg.soulLink and ns.spellName.SoulLink and UnitExists("pet") then
        if not ns:FindBuff("player", ns.spellName.SoulLink) then
            missing[#missing + 1] = "|cffff88ffSoul Link off|r"
        end
    end

    if #missing == 0 then
        self.txt:SetText("")
    else
        self.txt:SetText(table.concat(missing, "   "))
    end
end

function M:UNIT_AURA(unit) if unit == "player" then self:Check() end end
function M:PLAYER_ENTERING_WORLD() self:Check() end
function M:PLAYER_EQUIPMENT_CHANGED() self:Check() end
