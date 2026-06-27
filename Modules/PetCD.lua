-- WarlockBuddy / Modules/PetCD.lua
-- Pet utility cooldown tracker. TBC gives no clean readout of pet ability
-- cooldowns, yet Spell Lock (interrupt), Seduction (CC), Devour Magic, Sacrifice
-- and Intercept are core to playing a warlock at any level. This shows a ready/
-- cooldown bar for whichever of those the CURRENT pet has on its action bar.
--
-- Design note: we scan the pet action bar and match abilities BY NAME, not by a
-- hardcoded slot number. Slot order isn't stable across pets/builds, so name
-- matching (against names resolved from spell ids in Data.lua) is the robust way.

local ADDON, ns = ...
local M = ns:NewModule("PetCD")

local SLOTS = NUM_PET_ACTION_SLOTS or 10
local POOL = 6   -- max bars (we never track more utility abilities than this)

function M:OnInit()
    local cfg = ns.db.petcd
    local mover = ns:MakeMover("PetCD", 170, POOL * 22, cfg.point)
    self.mover = mover
    mover:SetScale(cfg.scale or 1)

    self.bars = {}
    for i = 1, POOL do
        local bar = ns:MakeBar(mover, 150, 20)
        if i == 1 then
            bar:SetPoint("TOPLEFT", mover, "TOPLEFT", 24, 0)
        else
            bar:SetPoint("TOPLEFT", self.bars[i - 1], "BOTTOMLEFT", 0, -2)
        end
        self.bars[i] = bar
    end

    self.tracked = {}   -- list of { slot, name, icon }

    -- NB: we intentionally do NOT register PLAYER_PET_CHANGED. Codex flagged it
    -- as unreliable in 2.5.x (GLM disagreed); UNIT_PET + PET_BAR_UPDATE cover the
    -- summon/swap/dismiss cases and are both confirmed-present, so we sidestep the
    -- disagreement (and any "unknown event" risk) entirely.
    ns:RegisterEvent(self, "PET_BAR_UPDATE")
    ns:RegisterEvent(self, "PET_BAR_UPDATE_COOLDOWN")
    ns:RegisterEvent(self, "UNIT_PET")
    ns:RegisterEvent(self, "PLAYER_ENTERING_WORLD")

    -- smooth cooldown sweep
    mover.elapsed = 0
    mover:SetScript("OnUpdate", function(_, e)
        mover.elapsed = mover.elapsed + e
        if mover.elapsed >= 0.1 then mover.elapsed = 0; self:UpdateCooldowns() end
    end)

    self:Rebuild()
end

-- Resolve the displayable ability name + icon for a pet action slot.
-- isToken slots (Attack/Follow/Stay/Move) carry global string tokens; real
-- abilities (Spell Lock etc.) return their localized name directly.
-- Returns name, icon, isToken. Real castable abilities (Spell Lock, Seduction…)
-- come back with isToken == false; the generic Attack/Follow/Stay/Move buttons
-- are tokens and are skipped by the caller.
local function slotInfo(slot)
    local name, _, texture, isToken = GetPetActionInfo(slot)
    if not name then return nil end
    return name, texture, isToken
end

-- Rebuild the tracked list when the pet or its bar changes.
function M:Rebuild()
    wipe(self.tracked)
    if UnitExists("pet") and ns.petAbilityNameToKey then
        local seen = {}
        for slot = 1, SLOTS do
            local name, icon, isToken = slotInfo(slot)
            if name and not isToken and ns.petAbilityNameToKey[name] and not seen[name] then
                seen[name] = true
                self.tracked[#self.tracked + 1] = { slot = slot, name = name, icon = icon }
            end
        end
    end
    self:Layout()
    self:UpdateCooldowns()
end

function M:Layout()
    for i, bar in ipairs(self.bars) do
        local t = self.tracked[i]
        if t then
            bar.icon:SetTexture(t.icon)
            bar.nameText:SetText(t.name)
            bar:Show()
        else
            bar:Hide()
        end
    end
end

function M:UpdateCooldowns()
    if not self.tracked or #self.tracked == 0 then return end
    local now = GetTime()
    for i, t in ipairs(self.tracked) do
        local bar = self.bars[i]
        if bar and bar:IsShown() then
            local start, duration = GetPetActionCooldown(t.slot)
            if start and duration and duration > 1.5 and start > 0 then
                local rem = (start + duration) - now
                if rem > 0 then
                    bar:SetValue(rem / duration)
                    bar:SetStatusBarColor(0.8, 0.5, 0.2)   -- on cooldown: amber
                    bar.timeText:SetText(ns:FmtTime(rem))
                else
                    self:SetReady(bar)
                end
            else
                self:SetReady(bar)
            end
        end
    end
end

function M:SetReady(bar)
    bar:SetValue(1)
    bar:SetStatusBarColor(0.2, 0.8, 0.2)               -- ready: green
    bar.timeText:SetText("|cff66ff66READY|r")
end

function M:PET_BAR_UPDATE() self:Rebuild() end
function M:UNIT_PET(unit) if unit == "player" then self:Rebuild() end end
function M:PET_BAR_UPDATE_COOLDOWN() self:UpdateCooldowns() end
function M:PLAYER_ENTERING_WORLD() self:Rebuild() end
