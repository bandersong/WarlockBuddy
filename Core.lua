-- WarlockBuddy / Core.lua
-- The spine: addon namespace, saved variables, event router, module registry.
-- Pure WoW API (no Ace3) so it ships as a single drop-in folder with zero deps.

local ADDON, ns = ...
ns.name = ADDON

-- ---------------------------------------------------------------------------
-- Module registry
-- Each module is a table registered with ns:NewModule("Name"). A module may
-- define :OnInit() (once, at PLAYER_LOGIN) and event handlers named after the
-- event (e.g. module:PLAYER_TARGET_CHANGED(...)). Core fans events out.
-- ---------------------------------------------------------------------------
ns.modules = {}
local moduleOrder = {}

function ns:NewModule(name)
    local m = ns.modules[name]
    if not m then
        m = { _name = name, _events = {} }
        ns.modules[name] = m
        moduleOrder[#moduleOrder + 1] = name
    end
    return m
end

-- Module asks Core to route an event to it.
function ns:RegisterEvent(module, event)
    module._events[event] = true
    ns.frame:RegisterEvent(event)
end

-- ---------------------------------------------------------------------------
-- Saved variables + defaults
-- ---------------------------------------------------------------------------
ns.defaults = {
    enabled = true,
    welcomed = false,          -- one-time first-run welcome shown?
    locked = false,            -- when true, all movers are click-through
    minimap = { hide = false, angle = 200 },
    modules = {                -- per-module on/off
        Shards = true,
        Dots = true,
        Procs = true,
        Pet = true,
        Soulstone = true,
        Reminders = true,
        CC = true,
        Execute = true,
        PetCD = true,
        Healthstone = true,
        LifeTap = true,
        Summon = true,
        MinimapButton = true,
    },
    -- Default frame positions form a deliberately SPREAD, non-overlapping layout
    -- so a first-time user sees a clean screen, not a pile of boxes. `/wb resetpos`
    -- restores exactly these. Rough map: left column = shards/petcd/pet,
    -- right column = soulstone/dots/summon, center column = procs/cc (top) and
    -- execute/reminders/lifetap (bottom), healthstone near the action bars.
    shards = {
        warnLow = 3,           -- turn red at/below this
        warnHigh = 28,         -- turn orange near a full bag (32 slots)
        scale = 1.0,
        point = { "CENTER", -260, 220 },     -- top-left
    },
    dots = {
        scale = 1.0,
        max = 8,
        point = { "CENTER", 280, 40 },       -- right
        showCurses = true,
    },
    procs = {
        flash = true,
        sound = true,
        point = { "CENTER", 0, 230 },        -- top-center alert
    },
    pet = {
        point = { "CENTER", -280, -180 },    -- bottom-left
        scale = 1.0,
        darkPactWarn = 0.30,   -- warn when pet mana below this fraction
    },
    soulstone = {
        announce = true,       -- chat announce when you SS someone
        channel = "SAY",
        point = { "CENTER", 260, 220 },      -- top-right
    },
    reminders = {
        armor = true,          -- nag if no Fel/Demon armor
        weaponStone = true,    -- nag if no Spell/Firestone enchant
        soulLink = false,      -- nag if Soul Link talented but inactive (off by default)
        point = { "CENTER", 0, -110 },       -- center-low
    },
    cc = {
        point = { "CENTER", 0, 150 },        -- under procs
        scale = 1.0,
    },
    execute = {
        threshold = 0.25,      -- alert when target at/below this health fraction
        flash = true,
        sound = true,
        scale = 1.0,
        point = { "CENTER", 0, -40 },        -- center alert
    },
    petcd = {
        scale = 1.0,
        point = { "CENTER", -280, 60 },      -- left
    },
    healthstone = {
        scale = 1.0,
        point = { "CENTER", 150, -210 },     -- near action bars
    },
    lifetap = {
        manaBelow = 0.30,      -- cue appears when mana fraction drops below this
        safeHpAbove = 0.40,    -- green only while health fraction is above this
        scale = 1.0,
        point = { "CENTER", 0, -165 },       -- center, below reminders
    },
    summon = {
        announce = true,       -- chat "Summoning X - click the portal!" on cast
        scale = 1.0,
        point = { "CENTER", 280, -120 },     -- right-lower
    },
}

-- Deep-merge defaults into the saved table without clobbering user choices.
local function applyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            applyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- ---------------------------------------------------------------------------
-- Event frame + dispatch
-- ---------------------------------------------------------------------------
ns.frame = CreateFrame("Frame", "WarlockBuddyFrame", UIParent)
local f = ns.frame
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local who = ...
        if who == ADDON then
            WarlockBuddyDB = WarlockBuddyDB or {}
            ns.db = applyDefaults(WarlockBuddyDB, ns.defaults)
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        ns:Init()
        return
    end

    -- Fan the event out to every module that asked for it.
    for _, name in ipairs(moduleOrder) do
        local m = ns.modules[name]
        if m._events[event] and ns.db.modules[name] ~= false then
            local fn = m[event]
            if fn then fn(m, ...) end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Init: gate on class, build modules
-- ---------------------------------------------------------------------------
function ns:Init()
    local _, class = UnitClass("player")
    ns.isWarlock = (class == "WARLOCK")

    if not ns.isWarlock then
        ns:Print("|cffff5555not on a warlock|r - addon idle. (Built for warlocks.)")
        return
    end

    ns:BuildSpellNames()   -- Data.lua: resolve localized names from ids

    for _, name in ipairs(moduleOrder) do
        local m = ns.modules[name]
        -- Only build modules the user has enabled - a disabled (or known-broken)
        -- module shouldn't create frames / register events / secure buttons.
        if ns:ModuleEnabled(name) and m.OnInit then
            local ok, err = pcall(m.OnInit, m)
            m._loaded = ok           -- recorded for /wb status
            if not ok then
                m._err = err
                ns:Print("|cffff5555module " .. name .. " failed:|r " .. tostring(err))
            end
        end
    end

    if not ns.db.welcomed then
        ns:ShowWelcome()
        ns.db.welcomed = true
    else
        ns:Print("loaded. |cffcc99ff/wb help|r for commands.")
    end
end

-- First-launch greeting for a new user: explain the minimap button + how to move
-- things. Shown once (then /wb help is the permanent reference).
function ns:ShowWelcome()
    ns:Print("|cff55ff55Welcome!|r All features are on and ready.")
    ns:Print("The purple |cffcc99ffWB|r button on your minimap opens settings (or type |cffcc99ff/wb|r).")
    ns:Print("Move frames: |cffcc99ff/wb unlock|r, drag them, then |cffcc99ff/wb lock|r.")
    ns:Print("Stuck? |cffcc99ff/wb resetpos|r restores the layout. Full list: |cffcc99ff/wb help|r.")
end

-- Load diagnostic. Since the addon can't always be tested by the author in-game,
-- /wb status turns a user's first login into a usable bug report: it shows the
-- version and, per module, whether it's off / loaded ok / errored (with the error).
-- (We don't show frame shown/hidden state: alert frames like Procs/Execute are
-- hidden by default, so "hidden" would read as broken when it's normal.)
function ns:ShowStatus()
    local ver = (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "?"
    ns:Print("status - |cffffffffv" .. ver .. "|r")
    for _, name in ipairs(moduleOrder) do
        local m = ns.modules[name]
        local line
        if not ns:ModuleEnabled(name) then
            line = "|cff888888" .. name .. ": off|r"
        elseif m._loaded then
            line = "|cff55ff55" .. name .. ": ok|r"
        elseif m._err then
            line = "|cffff5555" .. name .. ": ERROR|r " .. tostring(m._err)
        else
            line = "|cffffaa00" .. name .. ": not loaded|r"
        end
        ns:Print("  " .. line)
    end
end

-- Command reference (also the recovery path after the welcome scrolls away).
function ns:ShowHelp()
    ns:Print("commands:")
    ns:Print("  |cffcc99ff/wb|r - open options")
    ns:Print("  |cffcc99ff/wb unlock|r / |cffcc99fflock|r - move frames (drag while unlocked)")
    ns:Print("  |cffcc99ff/wb resetpos|r - restore the default frame layout")
    ns:Print("  |cffcc99ff/wb status|r - show version + which modules loaded")
    ns:Print("  |cffcc99ff/wb reset|r - reset ALL settings (then /reload)")
    ns:Print("  minimap button: |cffffffffleft|r=options |cffffffffright|r=lock/unlock |cffffffffdrag|r=move")
end

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------
function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff9482c9WarlockBuddy|r " .. tostring(msg))
end

function ns:ModuleEnabled(name)
    return ns.db and ns.db.modules[name] ~= false
end

-- ---------------------------------------------------------------------------
-- Slash command
-- ---------------------------------------------------------------------------
SLASH_WARLOCKBUDDY1 = "/wb"
SLASH_WARLOCKBUDDY2 = "/warlockbuddy"
local function SlashCmdHandler(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "unlock" or msg == "lock" then
        -- Secure (Healthstone) button drag setup must not be toggled mid-combat.
        if InCombatLockdown() then
            ns:Print("|cffff5555can't lock/unlock in combat|r - try again after.")
            return
        end
        local unlock = (msg == "unlock")
        ns.db.locked = not unlock
        ns:SetMoversLocked(ns.db.locked)
        if unlock then
            ns:Print("movers |cff55ff55UNLOCKED|r - drag frames, then |cffcc99ff/wb lock|r.")
        else
            ns:Print("movers |cffff5555LOCKED|r.")
        end
    elseif msg == "resetpos" then
        ns:ResetPositions()
        ns:Print("frame positions restored to the default layout.")
    elseif msg == "help" then
        ns:ShowHelp()
    elseif msg == "status" then
        ns:ShowStatus()
    elseif msg == "reset" then
        WarlockBuddyDB = {}
        ns:Print("settings reset. /reload to apply.")
    else
        ns:OpenOptions()
    end
end
SlashCmdList["WARLOCKBUDDY"] = SlashCmdHandler
