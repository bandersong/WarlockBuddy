-- WarlockBuddy / Util.lua
-- Shared helpers: aura scanning, draggable anchors, status bars, flash & sound.

local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Aura scanning (TBC-safe)
-- UnitBuff/UnitDebuff(unit, i) ->
--   name, rank, icon, count, dispelType, duration, expirationTime,
--   unitCaster, isStealable, shouldConsolidate, spellId
-- GOTCHA (TBC 2.5): duration & expirationTime are only meaningful (>0) for auras
-- cast by the player or the player's pet. That's exactly what a personal DoT
-- tracker wants, so we filter on caster = player/pet.
-- ---------------------------------------------------------------------------

local PLAYER_CASTERS = { player = true, pet = true, vehicle = true }

-- Find a debuff by localized name on unit. Returns count, expirationTime, duration, icon.
function ns:FindDebuff(unit, name, mineOnly)
    if not unit or not UnitExists(unit) or not name then return nil end
    for i = 1, 40 do
        local n, _, icon, count, _, duration, expiration, caster = UnitDebuff(unit, i)
        if not n then break end
        if n == name then
            if mineOnly and not PLAYER_CASTERS[caster or ""] then
                -- keep scanning; another caster's version isn't ours
            else
                return (count and count > 0 and count or 1), expiration, duration, icon
            end
        end
    end
    return nil
end

-- Find a buff by localized name on unit. Returns count, expiration, duration, icon.
function ns:FindBuff(unit, name, mineOnly)
    if not unit or not UnitExists(unit) or not name then return nil end
    for i = 1, 40 do
        local n, _, icon, count, _, duration, expiration, caster = UnitBuff(unit, i)
        if not n then break end
        if n == name then
            if mineOnly and not PLAYER_CASTERS[caster or ""] then
            else
                return (count and count > 0 and count or 1), expiration, duration, icon
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Draggable anchor frames
-- Every visible widget is parented to a mover so the user can reposition it,
-- then lock everything with /wb lock.
-- ---------------------------------------------------------------------------
ns.movers = {}

function ns:MakeMover(name, w, h, savedPoint, desc)
    local mv = CreateFrame("Frame", "WarlockBuddyMover_" .. name, UIParent)
    mv:SetSize(w, h)
    mv:SetMovable(true)
    mv:SetClampedToScreen(true)
    mv.desc = desc

    -- restore position
    local p = savedPoint or { "CENTER", 0, 0 }
    mv:SetPoint(p[1], UIParent, p[1], p[2] or 0, p[3] or 0)

    -- drag visuals (only while unlocked)
    local bg = mv:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.58, 0.51, 0.79, 0.35) -- warlock purple, translucent
    mv.bg = bg

    local label = mv:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText(name)
    mv.label = label

    mv:RegisterForDrag("LeftButton")
    mv:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mv:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        if savedPoint then
            savedPoint[1], savedPoint[2], savedPoint[3] = point, x, y
        end
    end)

    -- Hover tooltip naming each frame. Only fires while UNLOCKED (movers are
    -- EnableMouse(false) when locked), so it's a config-mode "what's this?" helper.
    mv:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cff9482c9" .. name .. "|r")
        if self.desc then GameTooltip:AddLine(self.desc, 1, 1, 1, true) end
        GameTooltip:AddLine("Drag to move", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    mv:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ns.movers[name] = mv
    ns:LockMover(mv, ns.db.locked)
    return mv
end

function ns:LockMover(mv, locked)
    if locked then
        mv:EnableMouse(false)
        mv.bg:Hide()
        mv.label:Hide()
    else
        mv:EnableMouse(true)
        mv.bg:Show()
        mv.label:Show()
    end
    -- A secure click button (e.g. the Healthstone panic button) lives as a child
    -- of its mover and stays ALWAYS clickable - it manages its own drag (gated by
    -- lock) so it never becomes dead while unlocked. We only toggle the mover's
    -- own drag visuals here; the secure child handles itself.
end

function ns:SetMoversLocked(locked)
    for _, mv in pairs(ns.movers) do
        ns:LockMover(mv, locked)
    end
end

-- Restore every frame to its pristine default position. Mover names map to
-- saved-var keys by lowercasing ("DoTs" -> "dots", "PetCD" -> "petcd", etc.),
-- and ns.defaults still holds the untouched defaults, so we copy default -> db
-- and re-anchor the live frame.
function ns:ResetPositions()
    for name, mv in pairs(ns.movers) do
        local key = name:lower()
        local def = ns.defaults[key] and ns.defaults[key].point
        local live = ns.db[key] and ns.db[key].point
        if def and live then
            live[1], live[2], live[3] = def[1], def[2], def[3]
            mv:ClearAllPoints()
            mv:SetPoint(live[1], UIParent, live[1], live[2] or 0, live[3] or 0)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Status bar factory (icon + name + time-left bar) for DoT/CC trackers.
-- ---------------------------------------------------------------------------
function ns:MakeBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)

    local icon = bar:CreateTexture(nil, "ARTWORK")
    icon:SetSize(height, height)
    icon:SetPoint("RIGHT", bar, "LEFT", -2, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    bar.icon = icon

    local nameText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
    nameText:SetJustifyH("LEFT")
    bar.nameText = nameText

    local timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.timeText = timeText

    bar:Hide()
    return bar
end

-- Color a time bar green->yellow->red as it runs out.
function ns:ColorByRemaining(bar, frac)
    if frac > 0.5 then
        bar:SetStatusBarColor(0.2, 0.8, 0.2)
    elseif frac > 0.25 then
        bar:SetStatusBarColor(0.9, 0.8, 0.1)
    else
        bar:SetStatusBarColor(0.9, 0.2, 0.2)
    end
end

-- ---------------------------------------------------------------------------
-- Proc flash overlay (full-screen edge glow) + sound
-- ---------------------------------------------------------------------------
function ns:Flash(r, g, b)
    if not ns._flash then
        local fl = CreateFrame("Frame", nil, UIParent)
        fl:SetAllPoints(UIParent)
        fl:SetFrameStrata("FULLSCREEN_DIALOG")
        fl:Hide()
        local t = fl:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetTexture("Interface\\FullScreenTextures\\LowHealth")
        fl.tex = t
        fl.elapsed = 0
        fl:SetScript("OnUpdate", function(self, e)
            self.elapsed = self.elapsed + e
            local a = 1 - (self.elapsed / 0.8)
            if a <= 0 then self:Hide() else self:SetAlpha(a) end
        end)
        ns._flash = fl
    end
    ns._flash.tex:SetVertexColor(r or 0.6, g or 0.2, b or 0.8)
    ns._flash.elapsed = 0
    ns._flash:SetAlpha(1)
    ns._flash:Show()
end

function ns:PlayAlertSound()
    if PlaySound then
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    end
end

-- ---------------------------------------------------------------------------
-- Time format mm:ss / s
-- ---------------------------------------------------------------------------
function ns:FmtTime(t)
    if not t or t < 0 then t = 0 end
    if t >= 60 then
        return string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60))
    end
    return string.format("%.0f", t)
end
