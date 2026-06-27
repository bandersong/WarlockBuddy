-- WarlockBuddy / Modules/Procs.lua
-- Watches the player for instant-cast procs and screams about them:
--   * Shadow Trance (Nightfall talent) -> free instant Shadow Bolt
--   * Backlash (Destruction talent)     -> free instant Shadow Bolt / Incinerate
-- Big center icon + screen flash + sound on gain.

local ADDON, ns = ...
local M = ns:NewModule("Procs")

local WATCH = { "ShadowTrance", "Backlash" }

function M:OnInit()
    local cfg = ns.db.procs
    local mover = ns:MakeMover("Procs", 64, 64, cfg.point, "Shadow Trance / Backlash proc alert")
    self.mover = mover

    local icon = mover:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    self.icon = icon

    local glow = mover:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("CENTER")
    glow:SetSize(96, 96)
    glow:SetTexture("Interface\\Cooldown\\star4")
    glow:SetBlendMode("ADD")
    self.glow = glow

    local txt = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    txt:SetPoint("TOP", mover, "BOTTOM", 0, -2)
    self.txt = txt

    self:HideProc()

    self.up = {}   -- name -> true while active, to detect rising edge
    ns:RegisterEvent(self, "UNIT_AURA")
    ns:RegisterEvent(self, "PLAYER_ENTERING_WORLD")

    -- spin the glow a touch
    mover.t = 0
    mover:SetScript("OnUpdate", function(_, e)
        if not self.icon:IsShown() then return end
        mover.t = mover.t + e
        local s = 0.95 + 0.1 * math.sin(mover.t * 6)
        self.glow:SetScale(s)
    end)
end

function M:ShowProc(name, icon)
    self.icon:SetTexture(icon or "Interface\\Icons\\Spell_Shadow_Twilight")
    self.icon:Show()
    self.glow:Show()
    self.txt:SetText(name)
    if ns.db.procs.flash then ns:Flash(0.6, 0.2, 0.9) end
    if ns.db.procs.sound then ns:PlayAlertSound() end
end

function M:HideProc()
    self.icon:Hide()
    self.glow:Hide()
    self.txt:SetText("")
end

function M:Scan()
    local anyUp, curName, curIcon
    for _, key in ipairs(WATCH) do
        local name = ns.spellName[key]
        if name then
            local count, _, _, icon = ns:FindBuff("player", name)
            local isUp = count ~= nil
            if isUp and not self.up[name] then
                -- rising edge -> alert
                self:ShowProc(name, icon)
            end
            self.up[name] = isUp
            if isUp then anyUp, curName, curIcon = true, name, icon end
        end
    end
    if not anyUp then self:HideProc() end
end

function M:UNIT_AURA(unit)
    if unit == "player" then self:Scan() end
end
function M:PLAYER_ENTERING_WORLD() self:Scan() end
