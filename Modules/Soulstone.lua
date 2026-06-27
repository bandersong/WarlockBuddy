-- WarlockBuddy / Modules/Soulstone.lua
-- Tracks the Soulstone Resurrection buff across the party/raid + self, shows who
-- is protected and time left, and (optionally) announces in chat when YOU apply
-- a soulstone so the group knows they have a battle-rez.

local ADDON, ns = ...
local M = ns:NewModule("Soulstone")

function M:OnInit()
    local cfg = ns.db.soulstone
    local mover = ns:MakeMover("Soulstone", 170, 40, cfg.point)
    self.mover = mover

    local title = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT")
    title:SetText("|cff9482c9Soulstone|r")
    self.title = title

    local who = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    who:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    self.who = who

    ns:RegisterEvent(self, "UNIT_AURA")
    ns:RegisterEvent(self, "GROUP_ROSTER_UPDATE")
    ns:RegisterEvent(self, "PLAYER_ENTERING_WORLD")
    ns:RegisterEvent(self, "COMBAT_LOG_EVENT_UNFILTERED")

    mover.elapsed = 0
    mover:SetScript("OnUpdate", function(_, e)
        mover.elapsed = mover.elapsed + e
        if mover.elapsed >= 0.5 then mover.elapsed = 0; self:Refresh() end
    end)

    self:Refresh()
end

-- Build the list of group units to check (self + party/raid).
local function rosterUnits()
    local units = { "player" }
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do units[#units + 1] = "raid" .. i end
    else
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    return units
end

function M:Refresh()
    if not self.mover or not ns.soulstoneBuffName then return end
    local now = GetTime()
    local found = {}
    for _, unit in ipairs(rosterUnits()) do
        if UnitExists(unit) then
            local _, expiration = ns:FindBuff(unit, ns.soulstoneBuffName)
            if expiration then
                local rem = expiration - now
                found[#found + 1] = string.format("%s |cffaaaaaa%s|r",
                    UnitName(unit) or "?", rem > 0 and ns:FmtTime(rem) or "")
            end
        end
    end

    if #found == 0 then
        self.who:SetText("|cff888888nobody stoned|r")
    else
        self.who:SetText(table.concat(found, "\n"))
    end
end

-- Announce when the player successfully casts Create/Soulstone resurrection.
function M:COMBAT_LOG_EVENT_UNFILTERED()
    if not ns.db.soulstone.announce then return end
    local _, subevent, _, srcGUID, _, _, _, _, dstName, _, _, _, spellName =
        CombatLogGetCurrentEventInfo()
    if subevent == "SPELL_RESURRECT" or subevent == "SPELL_AURA_APPLIED" then
        if srcGUID == UnitGUID("player") and spellName == ns.soulstoneBuffName and dstName then
            local chan = ns.db.soulstone.channel or "SAY"
            if chan == "SAY" and IsInGroup and IsInGroup() then chan = "PARTY" end
            SendChatMessage("Soulstone on " .. dstName .. " (battle rez ready)", chan)
        end
    end
end

function M:UNIT_AURA() self:Refresh() end
function M:GROUP_ROSTER_UPDATE() self:Refresh() end
function M:PLAYER_ENTERING_WORLD() self:Refresh() end
