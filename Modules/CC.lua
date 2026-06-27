-- WarlockBuddy / Modules/CC.lua
-- Crowd-control timers: when YOU have Banish/Fear/Seduction/Enslave/Howl/Death
-- Coil on your target, show a bar counting down so you re-cast before it breaks.
-- (Detects on target; works for the unit you currently have selected.)

local ADDON, ns = ...
local M = ns:NewModule("CC")

function M:OnInit()
    local cfg = ns.db.cc
    local mover = ns:MakeMover("CC", 200, #ns.ccOrder * 22, cfg.point, "Your Banish / Fear / Seduce timers")
    self.mover = mover
    mover:SetScale(cfg.scale or 1)

    self.bars = {}
    for i = 1, #ns.ccOrder do
        local bar = ns:MakeBar(mover, 180, 20)
        if i == 1 then
            bar:SetPoint("TOPLEFT", mover, "TOPLEFT", 24, 0)
        else
            bar:SetPoint("TOPLEFT", self.bars[i - 1], "BOTTOMLEFT", 0, -2)
        end
        self.bars[i] = bar
    end

    ns:RegisterEvent(self, "PLAYER_TARGET_CHANGED")
    ns:RegisterEvent(self, "UNIT_AURA")

    mover.elapsed = 0
    mover:SetScript("OnUpdate", function(_, e)
        mover.elapsed = mover.elapsed + e
        if mover.elapsed >= 0.1 then mover.elapsed = 0; self:UpdateTimers() end
    end)

    self:Rebuild()
end

function M:Rebuild()
    self.active = {}
    if UnitExists("target") then
        for _, key in ipairs(ns.ccOrder) do
            local name = ns.spellName[key]
            if name then
                local count, expiration, duration, icon = ns:FindDebuff("target", name, true)
                if expiration and duration and duration > 0 then
                    self.active[#self.active + 1] = {
                        name = name, icon = icon,
                        expiration = expiration, duration = duration,
                    }
                end
            end
        end
    end
    self:Layout()
end

function M:Layout()
    for i, bar in ipairs(self.bars) do
        local a = self.active[i]
        if a then
            bar.icon:SetTexture(a.icon)
            bar.nameText:SetText(a.name)
            bar:SetStatusBarColor(0.6, 0.3, 0.8)
            bar:Show()
        else
            bar:Hide()
        end
    end
end

function M:UpdateTimers()
    if not self.active or #self.active == 0 then return end
    local now = GetTime()
    for i, a in ipairs(self.active) do
        local bar = self.bars[i]
        if bar and bar:IsShown() then
            local rem = a.expiration - now
            if rem <= 0 then self:Rebuild(); return end
            bar:SetValue(rem / a.duration)
            bar.timeText:SetText(ns:FmtTime(rem))
        end
    end
end

function M:PLAYER_TARGET_CHANGED() self:Rebuild() end
function M:UNIT_AURA(unit) if unit == "target" then self:Rebuild() end end
