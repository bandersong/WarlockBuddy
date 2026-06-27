-- WarlockBuddy / tests/headless.lua
-- Offline test harness. `luac -p` only checks syntax; this stubs the WoW API and
-- actually RUNS the addon, in two stages:
--   1. Smoke: load every file in .toc order, fire ADDON_LOADED + PLAYER_LOGIN
--      (runs every module's OnInit), fire a sample of events + slash commands.
--   2. Behavior: drive specific module logic through a per-test MockState and
--      assert the results (shard count, DoT tracking, execute/Life Tap cues,
--      soulstone announce). Catches logic bugs the smoke stage can't.
-- Run:  lua tests/headless.lua   (exit 0 = clean, 1 = problems)

local unpack = table.unpack or unpack
local ROOT = (arg and arg[0] or ""):gsub("tests/headless%.lua$", "")
if ROOT == "" then ROOT = "./" end

local problems = {}
local function fail(where, err) problems[#problems + 1] = where .. ": " .. tostring(err) end

-- ---------------------------------------------------------------------------
-- Per-test mock state. All value-returning stubs read from here so each test
-- can set up exactly the world it needs, then reset() wipes it (no leakage).
-- ---------------------------------------------------------------------------
local MS = {}
local function reset()
    MS.itemCounts = {}
    MS.exists = {}
    MS.dead = {}
    MS.canAttack = false
    MS.health = { player = { 100, 100 }, target = { 100, 100 }, pet = { 100, 100 } }
    MS.power = { player = { 100, 100 }, pet = { 100, 100 } }
    MS.guids = { player = "Player-1" }
    MS.targetDebuffs = {}
    MS.cleu = nil
    MS.inGroup = false
    MS.inRaid = false
    MS.chat = {}
end
reset()

-- ---------------------------------------------------------------------------
-- Mock frame/widget: real script/event/text/shown storage; every other method
-- is a chainable no-op. Numeric methods return sane numbers so addon arithmetic
-- survives.
-- ---------------------------------------------------------------------------
local function newWidget()
    local w = { _scripts = {}, _events = {} }
    function w:SetScript(n, f) self._scripts[n] = f end
    function w:GetScript(n) return self._scripts[n] end
    function w:HookScript(n, f)
        local o = self._scripts[n]
        self._scripts[n] = function(...) if o then o(...) end return f(...) end
    end
    function w:RegisterEvent(e) self._events[e] = true end
    function w:RegisterUnitEvent(e) self._events[e] = true end
    function w:UnregisterEvent(e) self._events[e] = nil end
    function w:UnregisterAllEvents() self._events = {} end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:Show() self._shown = true end
    function w:Hide() self._shown = false end
    function w:IsShown() return self._shown and true or false end
    function w:GetWidth() return 140 end
    function w:GetHeight() return 140 end
    function w:GetFrameLevel() return 1 end
    function w:GetEffectiveScale() return 1 end
    function w:GetScale() return 1 end
    function w:GetCenter() return 400, 300 end
    function w:GetPoint() return "CENTER", _G.UIParent, "CENTER", 0, 0 end
    function w:CreateTexture() return newWidget() end
    function w:CreateFontString() return newWidget() end
    function w:CreateAnimationGroup() return newWidget() end
    function w:GetName() return self._name end
    setmetatable(w, { __index = function(t, k)
        local f = function(...) return t end
        rawset(t, k, f); return f
    end })
    return w
end

-- ---------------------------------------------------------------------------
-- Global WoW API stubs
-- ---------------------------------------------------------------------------
function CreateFrame(_, name)
    local f = newWidget()
    if name then f._name = name; _G[name] = f end
    return f
end

UIParent = newWidget()
Minimap = newWidget()
GameTooltip = newWidget()
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
NUM_PET_ACTION_SLOTS = 10
SOUNDKIT = { RAID_WARNING = 8959 }
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })

function GetTime() return 1000 end
function GetSpellInfo(id) return "Spell" .. tostring(id), nil, "Interface\\Icons\\Temp" end
function GetItemCount(id) return MS.itemCounts[id] or 0 end
function GetItemIcon() return "Interface\\Icons\\Temp" end
function GetItemCooldown() return 0, 0, 1 end
function GetItemInfo() return "Item" end
function GetWeaponEnchantInfo() return false end
function UnitClass() return "Warlock", "WARLOCK" end
function UnitExists(u) return MS.exists[u] and true or false end
function UnitName() return "Test" end
function UnitGUID(u) return MS.guids[u] end
local function hp(u) return MS.health[u] or { 0, 1 } end
local function pw(u) return MS.power[u] or { 0, 1 } end
function UnitHealth(u) return hp(u)[1] end
function UnitHealthMax(u) return hp(u)[2] end
function UnitPower(u) return pw(u)[1] end
function UnitPowerMax(u) return pw(u)[2] end
function UnitIsDead(u) return MS.dead[u] and true or false end
function UnitIsUnit() return false end
function UnitCanAttack() return MS.canAttack end
function UnitDebuff(u, i)
    if u == "target" then
        local d = MS.targetDebuffs[i]
        if d then return d.name, d.rank, d.icon, d.count, d.dispelType, d.duration, d.expiration, d.caster end
    end
    return nil
end
function UnitBuff() return nil end
function InCombatLockdown() return false end
function IsInRaid() return MS.inRaid end
function IsInGroup() return MS.inGroup end
function IsInInstance() return false, "none" end
function GetNumGroupMembers() return 0 end
function GetPetActionInfo() return nil end
function GetPetActionCooldown() return 0, 0, 1 end
function PlaySound() end
function SendChatMessage(msg, chan) MS.chat[#MS.chat + 1] = { msg = msg, chan = chan } end
function GetAddOnMetadata(_, field) if field == "Version" then return "test" end return nil end
function CombatLogGetCurrentEventInfo()
    if MS.cleu then return unpack(MS.cleu) end
    return GetTime(), "SPELL_AURA_APPLIED"
end
function InterfaceOptions_AddCategory() end
function InterfaceOptionsFrame_OpenToCategory() end
Settings = nil

-- ---------------------------------------------------------------------------
-- Stage 1: load + lifecycle smoke
-- ---------------------------------------------------------------------------
local function tocFiles()
    local files = {}
    local fh = assert(io.open(ROOT .. "WarlockBuddy.toc", "r"))
    for raw in fh:lines() do
        local line = raw:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and line:sub(1, 1) ~= "#" and line:lower():match("%.lua$") then
            files[#files + 1] = line:gsub("\\", "/")
        end
    end
    fh:close()
    return files
end

local ADDON = "WarlockBuddy"
local ns = {}
for _, rel in ipairs(tocFiles()) do
    local chunk, lerr = loadfile(ROOT .. rel)
    if not chunk then
        fail("load " .. rel, lerr)
    else
        local ok, rerr = pcall(chunk, ADDON, ns)
        if not ok then fail("run " .. rel, rerr) end
    end
end

local frame = ns.frame
local onEvent = frame and frame:GetScript("OnEvent")
if not onEvent then
    fail("lifecycle", "ns.frame has no OnEvent handler")
else
    local function fire(...)
        local ok, e = pcall(onEvent, frame, ...)
        if not ok then fail("event " .. tostring((...)), e) end
    end
    fire("ADDON_LOADED", ADDON)
    fire("PLAYER_LOGIN")
    for _, ev in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UNIT_AURA",
        "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "GROUP_ROSTER_UPDATE",
        "PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED",
        "COMBAT_LOG_EVENT_UNFILTERED",
    }) do fire(ev, "player") end
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 698)
end

if ns.modules then
    for name, m in pairs(ns.modules) do
        if m._err then fail("OnInit " .. name, m._err) end
    end
end

local slash = SlashCmdList and SlashCmdList["WARLOCKBUDDY"]
if slash then
    for _, cmd in ipairs({ "", "help", "status", "resetpos", "unlock", "lock" }) do
        local ok, e = pcall(slash, cmd)
        if not ok then fail("slash '" .. cmd .. "'", e) end
    end
end

-- ---------------------------------------------------------------------------
-- Stage 2: behavior assertions (each resets MockState first)
-- ---------------------------------------------------------------------------
local function check(name, fn)
    reset()
    local ok, res = pcall(fn)
    if not ok then
        fail("behavior " .. name, res)
    elseif res == false then
        fail("behavior " .. name, "assertion was false")
    end
end
local mods = ns.modules or {}

check("shards shows held count", function()
    if not mods.Shards then return end
    MS.itemCounts[ns.itemID.SoulShard] = 5
    mods.Shards:Refresh()
    return tostring(mods.Shards.count._text) == "5"
end)

check("dots track player-cast Corruption on target", function()
    if not mods.Dots then return end
    MS.exists.target = true; MS.canAttack = true
    local cname = GetSpellInfo(ns.spellID.Corruption)
    MS.targetDebuffs = { { name = cname, icon = "i", count = 1,
        duration = 18, expiration = GetTime() + 18, caster = "player" } }
    mods.Dots:Rebuild()
    return #mods.Dots.active >= 1 and mods.Dots.active[1].name == cname
end)

check("dots ignore another player's DoT", function()
    if not mods.Dots then return end
    MS.exists.target = true; MS.canAttack = true
    local cname = GetSpellInfo(ns.spellID.Corruption)
    MS.targetDebuffs = { { name = cname, icon = "i", count = 1,
        duration = 18, expiration = GetTime() + 18, caster = "party1" } }
    mods.Dots:Rebuild()
    return #mods.Dots.active == 0
end)

check("execute shows when target low", function()
    if not mods.Execute then return end
    MS.exists.target = true; MS.canAttack = true
    MS.health.target = { 20, 100 }
    mods.Execute:Check()
    return mods.Execute.icon:IsShown() == true
end)

check("execute hidden when target healthy", function()
    if not mods.Execute then return end
    MS.exists.target = true; MS.canAttack = true
    MS.health.target = { 80, 100 }
    mods.Execute:Check()
    return mods.Execute.icon:IsShown() == false
end)

check("lifetap green when mana low + hp safe", function()
    if not mods.LifeTap then return end
    MS.power.player = { 10, 100 }; MS.health.player = { 90, 100 }
    mods.LifeTap:Check()
    return (mods.LifeTap.txt._text or ""):find("LIFE TAP") ~= nil
end)

check("lifetap warns when mana low + hp low", function()
    if not mods.LifeTap then return end
    MS.power.player = { 10, 100 }; MS.health.player = { 20, 100 }
    mods.LifeTap:Check()
    return (mods.LifeTap.txt._text or ""):find("HP LOW") ~= nil
end)

check("soulstone announce fires with target name", function()
    if not mods.Soulstone then return end
    MS.inGroup = true
    ns.db.soulstone.announce = true
    local sname = GetSpellInfo(20707)
    -- CLEU 2.5 shape: ts, sub, hideCaster, srcGUID, srcName, srcFlags,
    -- srcRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName
    MS.cleu = { GetTime(), "SPELL_AURA_APPLIED", false, "Player-1", "Me", 0, 0,
        "dstGUID", "Tank", 0, 0, 20707, sname }
    mods.Soulstone:COMBAT_LOG_EVENT_UNFILTERED()
    return #MS.chat >= 1 and MS.chat[1].msg:find("Tank") ~= nil
end)

-- ---------------------------------------------------------------------------
-- Report
-- ---------------------------------------------------------------------------
if #problems == 0 then
    local n = 0
    for _ in pairs(mods) do n = n + 1 end
    print(string.format("PASS - %d modules init; load + 8 behavior assertions clean.", n))
    os.exit(0)
else
    print("FAIL - " .. #problems .. " problem(s):")
    for _, p in ipairs(problems) do print("  - " .. p) end
    os.exit(1)
end
