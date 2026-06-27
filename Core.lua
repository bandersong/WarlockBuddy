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
    },
    shards = {
        warnLow = 3,           -- turn red at/below this
        warnHigh = 28,         -- turn orange near a full bag (32 slots)
        scale = 1.0,
        point = { "CENTER", -220, 120 },
    },
    dots = {
        scale = 1.0,
        max = 8,
        point = { "CENTER", 260, 60 },
        showCurses = true,
    },
    procs = {
        flash = true,
        sound = true,
        point = { "CENTER", 0, 160 },
    },
    pet = {
        point = { "CENTER", -260, -160 },
        scale = 1.0,
        darkPactWarn = 0.30,   -- warn when pet mana below this fraction
    },
    soulstone = {
        announce = true,       -- chat announce when you SS someone
        channel = "SAY",
        point = { "CENTER", 220, -160 },
    },
    reminders = {
        armor = true,          -- nag if no Fel/Demon armor
        weaponStone = true,    -- nag if no Spell/Firestone enchant
        soulLink = false,      -- nag if Soul Link talented but inactive (off by default)
        point = { "CENTER", 0, -200 },
    },
    cc = {
        point = { "CENTER", 0, 240 },
        scale = 1.0,
    },
    execute = {
        threshold = 0.25,      -- alert when target at/below this health fraction
        flash = true,
        sound = true,
        scale = 1.0,
        point = { "CENTER", 0, -120 },
    },
    petcd = {
        scale = 1.0,
        point = { "CENTER", -260, -220 },
    },
    healthstone = {
        scale = 1.0,
        point = { "CENTER", 120, -260 },
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
        if m.OnInit then
            local ok, err = pcall(m.OnInit, m)
            if not ok then
                ns:Print("|cffff5555module " .. name .. " failed:|r " .. tostring(err))
            end
        end
    end

    ns:Print("loaded. |cffcc99ff/wb|r for options. drag with |cffcc99ff/wb unlock|r.")
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
SlashCmdHandler = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "unlock" then
        ns.db.locked = false
        ns:SetMoversLocked(false)
        ns:Print("movers |cff55ff55UNLOCKED|r - drag frames, then |cffcc99ff/wb lock|r.")
    elseif msg == "lock" then
        ns.db.locked = true
        ns:SetMoversLocked(true)
        ns:Print("movers |cffff5555LOCKED|r.")
    elseif msg == "reset" then
        WarlockBuddyDB = {}
        ns:Print("settings reset. /reload to apply.")
    else
        ns:OpenOptions()
    end
end
SlashCmdList["WARLOCKBUDDY"] = SlashCmdHandler
