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
