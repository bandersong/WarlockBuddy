-- WarlockBuddy / tests/headless.lua
-- Offline smoke test. The addon can't always be run in WoW, and `luac -p` only
-- checks syntax. This stubs enough of the WoW API to LOAD every file in .toc
-- order, fire ADDON_LOADED + PLAYER_LOGIN (which runs every module's OnInit), and
-- exercise the slash commands + a sample of events - catching runtime errors
-- (nil calls, bad globals, vararg mistakes, handler explosions) that syntax
-- checking misses. Run:  lua tests/headless.lua   (exit 0 = clean, 1 = problems)

local unpack = table.unpack or unpack
local ROOT = (arg and arg[0] or ""):gsub("tests/headless%.lua$", "")
if ROOT == "" then ROOT = "./" end

local problems = {}
local function fail(where, err) problems[#problems + 1] = where .. ": " .. tostring(err) end

-- ---------------------------------------------------------------------------
-- Mock frame/widget: real script + event storage; every other method is a
-- chainable no-op. Value-returning methods return sane numbers/strings so the
-- addon's arithmetic and string ops don't blow up on a mock.
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
    function w:GetWidth() return 140 end
    function w:GetHeight() return 140 end
    function w:GetFrameLevel() return 1 end
    function w:GetEffectiveScale() return 1 end
    function w:GetScale() return 1 end
    function w:IsShown() return true end
    function w:GetCenter() return 400, 300 end
    function w:GetPoint() return "CENTER", _G.UIParent, "CENTER", 0, 0 end
    function w:CreateTexture() return newWidget() end
    function w:CreateFontString() return newWidget() end
    function w:CreateAnimationGroup() return newWidget() end
    function w:GetName() return self._name end
    setmetatable(w, { __index = function(t, k)
        local f = function(...) return t end   -- chainable no-op, returns self
        rawset(t, k, f); return f
    end })
    return w
end

-- ---------------------------------------------------------------------------
-- Global WoW API stubs
-- ---------------------------------------------------------------------------
function CreateFrame(_, name, _, _)
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
function GetItemCount() return 0 end
function GetItemIcon() return "Interface\\Icons\\Temp" end
function GetItemCooldown() return 0, 0, 1 end
function GetItemInfo() return "Item" end
function GetWeaponEnchantInfo() return false end
function GetInventoryItemLink() return nil end
function UnitClass() return "Warlock", "WARLOCK" end
function UnitExists() return false end
function UnitName() return "Test" end
function UnitGUID() return "Player-0000-00000001" end
function UnitHealth() return 100 end
function UnitHealthMax() return 100 end
function UnitPower() return 100 end
function UnitPowerMax() return 100 end
function UnitIsDead() return false end
function UnitIsUnit() return false end
function UnitCanAttack() return false end
function InCombatLockdown() return false end
function IsInRaid() return false end
function IsInGroup() return false end
function IsInInstance() return false, "none" end
function GetNumGroupMembers() return 0 end
function GetPetActionInfo() return nil end
function GetPetActionCooldown() return 0, 0, 1 end
function PlaySound() end
function SendChatMessage() end
function GetAddOnMetadata(_, field) if field == "Version" then return "test" end return nil end
function CombatLogGetCurrentEventInfo() return GetTime(), "SPELL_AURA_APPLIED" end
function InterfaceOptions_AddCategory() end
function InterfaceOptionsFrame_OpenToCategory() end
Settings = nil

-- ---------------------------------------------------------------------------
-- Parse the .toc for the ordered .lua file list
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

-- ---------------------------------------------------------------------------
-- Load every file with the shared (ADDON, ns) vararg, like WoW does
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Fire the lifecycle through the addon's real event frame
-- ---------------------------------------------------------------------------
local frame = ns.frame
local onEvent = frame and frame:GetScript("OnEvent")
if not onEvent then
    fail("lifecycle", "ns.frame has no OnEvent handler")
else
    local function fire(...) local ok, e = pcall(onEvent, frame, ...) if not ok then fail("event " .. tostring((...)), e) end end
    fire("ADDON_LOADED", ADDON)
    fire("PLAYER_LOGIN")
    -- a representative sample of gameplay events, to exercise module handlers
    for _, ev in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UNIT_AURA",
        "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "GROUP_ROSTER_UPDATE",
        "PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED",
        "COMBAT_LOG_EVENT_UNFILTERED",
    }) do fire(ev, "player") end
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 698)
end

-- Modules whose OnInit errored are caught by Core's pcall and recorded as _err.
if ns.modules then
    for name, m in pairs(ns.modules) do
        if m._err then fail("OnInit " .. name, m._err) end
    end
end

-- Exercise the slash commands
local slash = SlashCmdList and SlashCmdList["WARLOCKBUDDY"]
if slash then
    for _, cmd in ipairs({ "", "help", "status", "resetpos", "unlock", "lock" }) do
        local ok, e = pcall(slash, cmd)
        if not ok then fail("slash '" .. cmd .. "'", e) end
    end
end

-- ---------------------------------------------------------------------------
-- Report
-- ---------------------------------------------------------------------------
if #problems == 0 then
    local n = 0
    if ns.modules then for _ in pairs(ns.modules) do n = n + 1 end end
    print(string.format("PASS - addon loaded, %d modules initialized, events + slash commands ran clean.", n))
    os.exit(0)
else
    print("FAIL - " .. #problems .. " problem(s):")
    for _, p in ipairs(problems) do print("  - " .. p) end
    os.exit(1)
end
