-- WarlockBuddy / Modules/Dots.lua
-- Time-left bars for the warlock's own DoTs (and curses) on the current target.
-- Only shows auras the player/pet cast (TBC: those are the ones with real timers).

local ADDON, ns = ...
local M = ns:NewModule("Dots")

function M:OnInit()
    local cfg = ns.db.dots
    local mover = ns:MakeMover("DoTs", 200, (cfg.max or 8) * 20, cfg.point, "Your DoT & curse timers on the target")
    self.mover = mover
    mover:SetScale(cfg.scale or 1)

    self.bars = {}
    for i = 1, (cfg.max or 8) do
        local bar = ns:MakeBar(mover, 180, 18)
        if i == 1 then
            bar:SetPoint("TOPRIGHT", mover, "TOPRIGHT", 0, 0)
        else
            bar:SetPoint("TOPRIGHT", self.bars[i - 1], "BOTTOMRIGHT", 0, -2)
        end
        self.bars[i] = bar
    end

    ns:RegisterEvent(self, "PLAYER_TARGET_CHANGED")
    ns:RegisterEvent(self, "UNIT_AURA")

    -- light OnUpdate just to animate the time bars smoothly
    mover.elapsed = 0
    mover:SetScript("OnUpdate", function(_, e)
        mover.elapsed = mover.elapsed + e
        if mover.elapsed >= 0.1 then
            mover.elapsed = 0
            self:UpdateTimers()
        end
    end)

    self:Rebuild()
end

-- Build the active list when target or auras change.
function M:Rebuild()
    self.active = {}
    if not UnitExists("target") or not UnitCanAttack("player", "target") then
        self:Layout()
        return
    end

    local cfg = ns.db.dots
    local seen = {}

    local function consider(key)
        local name = ns.spellName[key]
        if not name or seen[name] then return end
        local count, expiration, duration, icon = ns:FindDebuff("target", name, true)
        if count and expiration and duration and duration > 0 then
            seen[name] = true
            self.active[#self.active + 1] = {
                name = name, icon = icon,
                expiration = expiration, duration = duration, count = count,
            }
        end
    end

    for _, key in ipairs(ns.dotOrder) do consider(key) end
    if cfg.showCurses then
        for _, key in ipairs(ns.curseOrder) do consider(key) end
    end

    self:Layout()
end

function M:Layout()
    local cfg = ns.db.dots
    for i, bar in ipairs(self.bars) do
        local a = self.active[i]
        if a and i <= (cfg.max or 8) then
            bar.icon:SetTexture(a.icon)
            local label = a.name
            if a.count and a.count > 1 then label = label .. " x" .. a.count end
            bar.nameText:SetText(label)
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
            local remaining = a.expiration - now
            if remaining <= 0 then
                self:Rebuild()
                return
            end
            local frac = remaining / a.duration
            bar:SetValue(frac)
            ns:ColorByRemaining(bar, frac)
            bar.timeText:SetText(ns:FmtTime(remaining))
        end
    end
end

function M:PLAYER_TARGET_CHANGED() self:Rebuild() end
function M:UNIT_AURA(unit)
    if unit == "target" then self:Rebuild() end
end
