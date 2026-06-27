-- WarlockBuddy / Modules/MinimapButton.lua
-- Self-contained minimap button (no LibDBIcon dependency). Left-click opens
-- options, drag it around the minimap ring, position persists. Discoverability:
-- a non-expert won't remember /wb, but they'll find a button on the minimap.
--
-- TBC note: WoW runs Lua 5.1, which has math.atan2(y, x). The 2-arg math.atan is
-- only Lua 5.3+, so we prefer atan2 and fall back. (GLM had this backwards; see
-- docs/TBC_API_NOTES.md 6g.)

local ADDON, ns = ...
local M = ns:NewModule("MinimapButton")

local function atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    return math.atan(y, x)   -- Lua 5.3+ 2-arg fallback
end

local function updatePos(btn)
    local angle = math.rad(ns.db.minimap.angle or 200)
    local r = (Minimap:GetWidth() / 2) + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function onDragUpdate(self)
    local mx, my = Minimap:GetCenter()
    if not mx or not my then return end   -- minimap hidden/replaced: bail safely
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    ns.db.minimap.angle = math.deg(atan2(cy - my, cx - mx))
    updatePos(self)
end

function M:OnInit()
    if ns.db.minimap.hide then return end

    local btn = CreateFrame("Button", "WarlockBuddyMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    btn:RegisterForClicks("AnyUp")
    btn:RegisterForDrag("LeftButton")
    self.btn = btn

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_DeathCoil")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:SetScript("OnClick", function(_, mouseBtn)
        if mouseBtn == "RightButton" then
            if InCombatLockdown() then
                ns:Print("|cffff5555can't lock/unlock in combat|r")
                return
            end
            ns.db.locked = not ns.db.locked
            ns:SetMoversLocked(ns.db.locked)
            ns:Print("movers " .. (ns.db.locked and "|cffff5555LOCKED|r" or "|cff55ff55UNLOCKED|r"))
        else
            ns:OpenOptions()
        end
    end)

    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", onDragUpdate)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff9482c9WarlockBuddy|r")
        GameTooltip:AddLine("Left-click: options", 1, 1, 1)
        GameTooltip:AddLine("Right-click: lock/unlock frames", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    updatePos(btn)
end
