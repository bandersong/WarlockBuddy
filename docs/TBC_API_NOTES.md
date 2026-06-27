# TBC 2.5 API notes & design decisions

This file is the "why" behind the code. TBC Classic (2.5.x, the 20th Anniversary
client) is **not** retail and **not** Wrath — its API has sharp edges. Every
decision below was triangulated against two independent AI reviews (GLM-5.2 and
OpenAI Codex) plus known community knowledge, then red-teamed. Confidence levels
are noted where the sources disagreed.

## 1. Aura scanning: match by NAME, not id

We read auras with `UnitBuff(unit, i)` / `UnitDebuff(unit, i)` (slots 1–40).
The 2.5 return order is:

```
name, rank, icon, count, dispelType, duration, expirationTime,
unitCaster, isStealable, shouldConsolidate, spellId
```

`spellId` *is* present at position 11 in 2.5 (confirmed by Codex), **but** it's
historically unreliable across builds, so we match on the **localized name**
resolved from `GetSpellInfo(id)` at login. That also makes the addon locale-safe:
a German client returns German names and we still match, because we resolved our
expected names from the same client.

`UnitAura(unit, i, filter)` also exists in 2.5, but `UnitBuff`/`UnitDebuff` are
the simplest, most-stable surface, so we use those exclusively.

## 2. The player-cast duration quirk (the big one)

In TBC, `duration` and `expirationTime` are only **meaningful (non-zero)** for
auras cast by **you or your pet**. Another warlock's Corruption on the same mob
returns no usable timer.

For a *personal* DoT tracker this is exactly what we want, so `FindDebuff` /
`FindBuff` take a `mineOnly` flag and filter on `unitCaster ∈ {player, pet,
vehicle}`. We also guard with `duration > 0` so a 0/nil never divides into a bar.

> If we ever want to show *other* players' DoTs, we'd need **LibClassicDurations**
> to reconstruct timers from the combat log. Out of scope for v0.1.

## 3. Shadow Trance (Nightfall) id is disputed

The Nightfall talent's free-instant proc is the **Shadow Trance** buff. Its spell
id is reported as **17941** in most references, but Codex flagged **17942** as the
aura id with medium-high confidence. Sources disagree.

Because we match by name, we don't have to pick: `BuildSpellNames` tries
`{17941, 17942}` in order and stores whichever the client resolves to a name.
Bulletproof against the ambiguity. (`Data.lua` → `ns.shadowTranceIDs`.)

## 4. Verified ids (high confidence, both sources)

| Thing | id |
| --- | --- |
| Soul Shard (item) | 6265 |
| Soulstone (item, rank 1) | 5232 |
| Backlash (proc buff) | 34936 |
| Soul Link (buff) | 25228 |
| Soulstone Resurrection (buff) | 20707 |
| Fel Armor | 28189 |
| Unstable Affliction | 30108 |
| Seed of Corruption | 27243 |

DoT/curse/CC ids are in `Data.lua`. We only store one representative rank per
spell — the localized **name** is identical across ranks, so name-matching catches
every rank automatically.

## 5. Timers: C_Timer is available

`C_Timer.After` and `C_Timer.NewTicker` **do** exist in 2.5 (confirmed by both
sources). We still drive the time-bar animations with lightweight throttled
`OnUpdate` handlers (0.1s) because that's the natural fit for smoothly shrinking
bars; `C_Timer` is fine to use elsewhere.

## 6. Weapon stones

`GetWeaponEnchantInfo()` exists and returns `hasMainHandEnchant, ...`. We use it
to detect a missing Spellstone/Firestone weapon enchant (the Reminders module).
There's no event for the enchant timer, so we poll once a second.

## 6b. Pet power events (verified)

For a pet mana bar in 2.5, register **`UNIT_POWER_UPDATE`** (it exists; do *not*
use `UNIT_MANA`, and `UNIT_POWER` is the older/less-correct form). `UnitPower("pet",
0)` / `UnitPowerMax("pet", 0)` (powerType `0` = mana) work. The event payload is
`(unit, powerToken)` where `powerToken` is the **string** `"MANA"` (not an
integer) — so an optional efficiency filter is `if powerToken ~= "MANA" then
return end`. Our Pet module just filters `unit == "pet"`, which is correct
regardless. (Triangulated: Codex correct on the string token; GLM had said int.)

## 7. APIs we deliberately AVOID (retail/Wrath traps)

- `C_UnitAuras.*` / `AuraUtil.*` — retail only, **do not exist** in 2.5.
- `GetSpecialization()` — does not exist. We can't ask the client her spec, which
  is exactly why every module is independently toggleable and spec-agnostic.
- `C_NamePlate.GetNamePlateUnitUnit()` — not available.

## 8. .toc Interface version

`## Interface: 20504` for the TBC Anniversary / 2.5.x client (both sources,
medium-high confidence). After a content patch this may need bumping; players can
tick *"Load out of date AddOns"* meanwhile. If a patch changes it, update the one
number at the top of `WarlockBuddy.toc`.

---

### Triangulation log

- **GLM-5.2** — full feature list + API gotchas (UnitBuff scanning, player-cast
  duration quirk, item ids, C_Timer availability, retail traps).
- **Codex (OpenAI)** — independent id verification; corrected return-order detail
  (spellId at 11), flagged Shadow Trance id ambiguity, confirmed
  `GetWeaponEnchantInfo` and Interface number.
- **Disagreements resolved:** GLM claimed "no UnitAura in TBC" — not strictly
  true (it exists), but moot since we use UnitBuff/UnitDebuff. Shadow Trance id
  handled via candidate-list name resolution rather than committing to one id.
