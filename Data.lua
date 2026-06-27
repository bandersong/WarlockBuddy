-- WarlockBuddy / Data.lua
-- All TBC warlock spell/item ids in one place. Names are resolved at login via
-- GetSpellInfo(id) so the addon works in every locale (matching by localized
-- name, because UnitBuff/UnitDebuff in 2.5 do NOT reliably return spell ids).

local ADDON, ns = ...

-- Spell ids (one representative rank; GetSpellInfo gives the locale name, which
-- is identical across ranks, so name-matching catches every rank she casts).
ns.spellID = {
    -- DoTs / debuffs the warlock applies to a target
    Corruption          = 172,
    Immolate            = 348,
    SiphonLife          = 18265,
    UnstableAffliction  = 30108,   -- TBC
    SeedOfCorruption    = 27243,   -- TBC
    CurseOfAgony        = 980,
    CurseOfDoom         = 603,
    CurseOfTheElements  = 1490,
    CurseOfShadow       = 17862,
    CurseOfWeakness     = 702,
    CurseOfTongues      = 1714,
    CurseOfRecklessness = 704,
    CurseOfExhaustion   = 18223,

    -- Channels / execute
    DrainSoul           = 1120,    -- shard-on-kill execute

    -- Utility
    RitualOfSummoning   = 698,     -- group summon (costs 1 soul shard)

    -- Crowd control / utility (timed)
    Banish              = 710,
    EnslaveDemon        = 1098,
    Fear                = 5782,
    HowlOfTerror        = 5484,
    Seduction           = 6358,    -- succubus
    DeathCoil           = 6789,

    -- Player procs / buffs
    ShadowTrance        = 17941,   -- Nightfall proc (see shadowTranceIDs fallback)
    Backlash            = 34936,   -- Destruction proc
    AmplifyCurse        = 18288,

    -- Self armor buffs
    DemonSkin           = 687,
    DemonArmor          = 706,
    FelArmor            = 28189,   -- TBC

    -- Pet / sacrifice
    SoulLink            = 25228,   -- soul link buff
    FelDomination       = 18708,
    -- Demonic Sacrifice grants one of these depending on pet sacrificed:
    TouchOfShadow       = 18791,   -- succubus
    BurningWish         = 18789,   -- imp
    FelStamina          = 18790,   -- voidwalker
    FelEnergy           = 18792,   -- felhunter
}

-- Item ids
ns.itemID = {
    SoulShard = 6265,
    -- Healthstones: complete TBC id set (base ranks + Master + Improved-talent
    -- variants). A warlock can only hold ONE healthstone at a time, so we just
    -- need this list to be COMPLETE - the first id with count > 0 is the one she
    -- has, and ranking doesn't matter for finding it.
    Healthstones = {
        22105,                                            -- Master (TBC)
        9421, 5510, 5509, 5511, 5512,                     -- base ranks
        19004, 19005, 19006, 19007, 19008, 19009,         -- Improved-talent
        19010, 19011, 19012, 19013,                       -- variants
    },
    -- Soulstones (all TBC ranks)
    Soulstones   = { 5232, 16892, 16893, 16895, 16896, 22116 },
    -- Spellstones / Firestones (carried) - reminder if no weapon enchant
    Spellstones  = { 5522, 13602, 13603, 22128 },
    Firestones   = { 13699, 13700, 13701, 22127 },
}

-- Pet utility abilities worth a cooldown readout. We MATCH BY NAME against the
-- pet action bar (not by hardcoded slot - slot order isn't stable), so we only
-- need ids here to resolve the localized names once at login.
ns.petAbilityID = {
    SpellLock   = 19244,   -- Felhunter: interrupt + dispel-lock
    DevourMagic = 19505,   -- Felhunter: dispel + heal
    Seduction   = 6358,    -- Succubus: CC
    Sacrifice   = 7812,    -- Voidwalker: damage shield
    Intercept   = 30151,   -- Felguard (Demo): gap close + stun
    Suffering   = 17735,   -- Voidwalker: taunt (tank pet)
}
ns.petAbilityOrder = { "SpellLock", "Seduction", "DevourMagic", "Intercept", "Sacrifice", "Suffering" }

-- Buff names that mean "I currently have a soulstone resurrection up"
ns.soulstoneBuffID = 20707  -- Soulstone Resurrection

-- Resolved name caches (filled by BuildSpellNames)
ns.spellName = {}     -- key -> localized name
ns.nameToKey = {}     -- localized name -> key (reverse, for fast aura matching)

-- Shadow Trance proc id is disputed across builds (17941 vs 17942). We match
-- procs by localized NAME, so resolve from whichever candidate the client knows.
ns.shadowTranceIDs = { 17941, 17942 }

function ns:BuildSpellNames()
    for key, id in pairs(ns.spellID) do
        local n = GetSpellInfo(id)
        if n then
            ns.spellName[key] = n
            ns.nameToKey[n] = key
        end
    end

    -- Robust Shadow Trance name resolution.
    for _, id in ipairs(ns.shadowTranceIDs) do
        local n = GetSpellInfo(id)
        if n then
            ns.spellName.ShadowTrance = n
            ns.nameToKey[n] = "ShadowTrance"
            break
        end
    end

    local ssName = GetSpellInfo(ns.soulstoneBuffID)
    if ssName then ns.soulstoneBuffName = ssName end

    -- Resolve pet ability names -> key, for matching against the pet action bar.
    ns.petAbilityNameToKey = {}
    for key, id in pairs(ns.petAbilityID) do
        local n = GetSpellInfo(id)
        if n then ns.petAbilityNameToKey[n] = key end
    end
end

-- Ordered groups for the DoT tracker (so bars render in a sensible order).
ns.dotOrder = {
    "Immolate", "Corruption", "UnstableAffliction", "SiphonLife",
    "SeedOfCorruption", "CurseOfAgony", "CurseOfDoom",
}
ns.curseOrder = {
    "CurseOfTheElements", "CurseOfShadow", "CurseOfWeakness",
    "CurseOfTongues", "CurseOfRecklessness", "CurseOfExhaustion",
}
ns.ccOrder = {
    "Banish", "Fear", "Seduction", "EnslaveDemon", "HowlOfTerror", "DeathCoil",
}
