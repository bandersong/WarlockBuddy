-- WarlockBuddy / Options.lua
-- A no-frills options panel registered in the Interface > AddOns menu, plus
-- ns:OpenOptions() so /wb opens it. Toggle modules, lock frames, set announce.

local ADDON, ns = ...

local function makeCheck(parent, label, x, y, getf, setf)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(label)
    cb:SetScript("OnShow", function(self) self:SetChecked(getf()) end)
    cb:SetChecked(getf())
    cb:SetScript("OnClick", function(self) setf(self:GetChecked()) end)
    return cb
end

-- A labelled slider bound to a saved-var value. isPercent shows 0-100% and
-- stores a 0..1 fraction; otherwise it's an integer count.
local function makeSlider(parent, name, label, x, y, minv, maxv, step, isPercent, getf, setf)
    local slider = CreateFrame("Slider", "WarlockBuddyOpt" .. name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetWidth(180)
    slider:SetMinMaxValues(minv, maxv)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end

    -- OptionsSliderTemplate names its regions $parentLow / $parentHigh / $parentText
    local low  = _G["WarlockBuddyOpt" .. name .. "Low"]
    local high = _G["WarlockBuddyOpt" .. name .. "High"]
    local text = _G["WarlockBuddyOpt" .. name .. "Text"]
    if low then low:SetText("") end
    if high then high:SetText("") end

    local function fmt(v)
        if isPercent then return math.floor(v * 100 + 0.5) .. "%" end
        return tostring(math.floor(v + 0.5))
    end
    local function label_for(v) return label .. ": " .. fmt(v) end

    local cur = getf()
    slider:SetValue(cur)
    if text then text:SetText(label_for(cur)) end

    slider:SetScript("OnValueChanged", function(_, val)
        if not isPercent then val = math.floor(val + 0.5) end
        setf(val)
        if text then text:SetText(label_for(val)) end
    end)
    return slider
end

function ns:BuildOptions()
    if self.optionsPanel then return self.optionsPanel end

    local panel = CreateFrame("Frame", "WarlockBuddyOptions", UIParent)
    panel.name = "WarlockBuddy"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff9482c9WarlockBuddy|r")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("Everything a TBC warlock needs. /wb unlock to move frames.")

    local y = -64

    -- Lock frames
    makeCheck(panel, "Lock frames (hide drag handles)", 16, y,
        function() return ns.db.locked end,
        function(v) ns.db.locked = v and true or false; ns:SetMoversLocked(ns.db.locked) end)
    y = y - 30

    -- Module toggles
    local modHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    modHeader:SetPoint("TOPLEFT", 16, y)
    modHeader:SetText("Modules")
    y = y - 24

    local mods = {
        { "Shards",    "Soul shard / healthstone counter" },
        { "Dots",      "DoT & curse timers on target" },
        { "Procs",     "Shadow Trance / Backlash alerts" },
        { "Pet",       "Pet health, mana, Soul Link, Dark Pact" },
        { "Soulstone", "Soulstone tracker + announce" },
        { "Reminders", "Armor / weapon-stone nags" },
        { "CC",        "Banish / Fear / Seduce timers" },
        { "Execute",   "Drain Soul shard-on-kill alert" },
        { "PetCD",     "Pet ability cooldowns (Spell Lock / Seduce)" },
        { "Healthstone", "One-click Healthstone panic button" },
        { "LifeTap",   "Life Tap safety cue (mana low / HP safe)" },
    }
    for _, m in ipairs(mods) do
        local key = m[1]
        makeCheck(panel, m[2], 28, y,
            function() return ns.db.modules[key] ~= false end,
            function(v)
                ns.db.modules[key] = v and true or false
                ns:Print("module " .. key .. (v and " on" or " off") .. " - /reload to fully apply")
            end)
        y = y - 26
    end

    -- Procs sub-options
    y = y - 8
    local pHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pHeader:SetPoint("TOPLEFT", 16, y)
    pHeader:SetText("Proc alerts")
    y = y - 24
    makeCheck(panel, "Screen flash", 28, y,
        function() return ns.db.procs.flash end,
        function(v) ns.db.procs.flash = v and true or false end)
    y = y - 26
    makeCheck(panel, "Sound", 28, y,
        function() return ns.db.procs.sound end,
        function(v) ns.db.procs.sound = v and true or false end)
    y = y - 26

    -- Soulstone announce
    y = y - 8
    makeCheck(panel, "Announce soulstone in chat", 16, y,
        function() return ns.db.soulstone.announce end,
        function(v) ns.db.soulstone.announce = v and true or false end)

    -- Right column: tunable thresholds (sliders). Hardcoded cutoffs are wrong
    -- across the 1-70 leveling range, so let the player tune them in the UI.
    local rx, ry = 320, -64
    local thHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    thHeader:SetPoint("TOPLEFT", rx, ry)
    thHeader:SetText("Thresholds")
    ry = ry - 34

    makeSlider(panel, "ShardLow", "Shards: warn low at", rx, ry, 1, 12, 1, false,
        function() return ns.db.shards.warnLow end,
        function(v) ns.db.shards.warnLow = v; if ns.modules.Shards.Refresh then ns.modules.Shards:Refresh() end end)
    ry = ry - 54

    makeSlider(panel, "ShardHigh", "Shards: warn full at", rx, ry, 16, 32, 1, false,
        function() return ns.db.shards.warnHigh end,
        function(v) ns.db.shards.warnHigh = v; if ns.modules.Shards.Refresh then ns.modules.Shards:Refresh() end end)
    ry = ry - 54

    makeSlider(panel, "ExecutePct", "Drain Soul: target HP", rx, ry, 0.10, 0.40, 0.05, true,
        function() return ns.db.execute.threshold end,
        function(v) ns.db.execute.threshold = v end)
    ry = ry - 54

    makeSlider(panel, "TapMana", "Life Tap: mana below", rx, ry, 0.15, 0.50, 0.05, true,
        function() return ns.db.lifetap.manaBelow end,
        function(v) ns.db.lifetap.manaBelow = v end)
    ry = ry - 54

    makeSlider(panel, "SafeHP", "Life Tap: safe HP above", rx, ry, 0.25, 0.60, 0.05, true,
        function() return ns.db.lifetap.safeHpAbove end,
        function(v) ns.db.lifetap.safeHpAbove = v end)
    ry = ry - 54

    -- Register with the Interface options frame (TBC API).
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(cat)
        ns._settingsCategory = cat
    end

    self.optionsPanel = panel
    return panel
end

function ns:OpenOptions()
    ns:BuildOptions()
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel) -- twice: TBC quirk
    elseif Settings and Settings.OpenToCategory and ns._settingsCategory then
        Settings.OpenToCategory(ns._settingsCategory:GetID())
    end
end
