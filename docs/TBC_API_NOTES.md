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

## 6c. Pet action bar (cooldown tracker) — verified

For pet ability cooldowns (Spell Lock, Seduction, Devour Magic, Sacrifice,
Intercept), use the **pet action bar**, not the combat log — those abilities sit
on the bar and expose cooldowns directly (both reviewers, high confidence).

- `NUM_PET_ACTION_SLOTS == 10`. Scan slots 1–10.
- `GetPetActionInfo(slot)` →
  `name, subtext, texture, isToken, isActive, autoCastAllowed, autoCastEnabled`.
  Real castable abilities have `isToken == false`; the generic Attack / Follow /
  Stay / Move buttons are tokens (skip them). `name == nil` ⇒ empty slot.
- `GetPetActionCooldown(slot)` → `start, duration, enable`. On cooldown when
  `start > 0 and duration > 1.5` (the `>1.5` filters the GCD).
- **Match abilities by NAME, not slot index.** Slot order isn't stable across
  pets/builds; we resolve our target names from spell ids (`ns.petAbilityID`) and
  match the live bar against them.
- Events: `PET_BAR_UPDATE` (rebuild names/icons) and `PET_BAR_UPDATE_COOLDOWN`
  (refresh timers) both exist and are reliable. `UNIT_PET` (arg1 `"player"`)
  catches summon/dismiss. **`PLAYER_PET_CHANGED` — avoid**: Codex flagged it
  unreliable in 2.5 (GLM disagreed); we don't register it, so the disagreement is
  moot and there's no "unknown event" risk.

## 6d. In-combat Healthstone use — secure button (verified)

Using an item in combat is a **protected action**: a plain addon cannot `/use` an
item or call `UseItemByName` in combat — it requires a hardware event through a
`SecureActionButton`. Both reviewers confirmed at 95-99% (no disagreement):

- `CreateFrame("Button", name, parent, "SecureActionButtonTemplate")` exists in
  2.5. Set `type = "macro"` and `macrotext = "/use item:<id>"`; a real click then
  uses the item, in combat included.
- **Secure attributes can't be changed while `InCombatLockdown()`** is true.
  So set the macrotext OUT of combat (we use `BAG_UPDATE_DELAYED` +
  `PLAYER_REGEN_ENABLED` + `PLAYER_ENTERING_WORLD`); the value persists into the
  fight. Guard every `SetAttribute` with `if not InCombatLockdown()`.
- `GetItemCooldown(id)` → `start, duration, enable`. Healthstones share the 2-min
  potion cooldown category. `GetItemIcon(id)` gives the icon without a tooltip
  scan. Clear a Cooldown with `SetCooldown(0, 0)` (`Cooldown:Clear` isn't in 2.5).
- **Taint:** none, as long as the button is our own frame, never parented under a
  protected Blizzard frame, and only sets attributes on itself out of combat.
- A warlock holds only ONE healthstone at a time, so we don't rank by potency — we
  just scan the full id list and use the first one held.
- Keybind: bind a macro `/click WarlockBuddyHealthstoneButton` (the `/click` from a
  keypress is itself a hardware event, so it works in combat).

## 6e. Life Tap — why we show a cue, not a number

The LifeTap module shows a percentage-based safety cue and **no "expected mana"
figure**, on purpose. What we verified:

- Life Tap **does** scale with spell damage in TBC (both reviewers): rank 3+ adds
  ~80% of bonus shadow damage to the health-lost/mana-gained value. So it is *not*
  a flat per-rank constant.
- Improved Life Tap (Affliction tree — *not* Destruction, GLM had that wrong)
  increases **mana gained only** by 10/20%; health lost is unchanged.
- There is **no clean API** for the computed value: Life Tap has no normal spell
  cost (`GetSpellPowerCost` is useless here — the health→mana is a spell *effect*),
  and `GetSpellInfo` returns identity/metadata only. You'd have to hardcode rank
  bases + the coefficient, or parse the localized tooltip.
- The two reviewers **disagreed on the rank base values** (e.g. rank 1 = 15 vs 30;
  full tables differ) and one table was WotLK-contaminated (listed a rank 8 at
  "level 74" — TBC caps at 70, max rank is 7, spellID 27222, base 582). Since we
  can't reconcile the numbers against ground truth, we don't display one.
- Live stats are solid: `UnitHealth/UnitHealthMax/UnitPower("player",0)/
  UnitPowerMax` all work; drive with `UNIT_HEALTH` + `UNIT_POWER_UPDATE`
  (arg1 unit; arg2 of the latter is the `"MANA"` token). Sane safety margin is
  ~25-40% of max health remaining after the tap.

If we ever want a mana-return prediction, first nail the rank base table against
an authoritative TBC source (or in-game tooltip parse) — don't trust a single
model's numbers.

## 6f. Ritual of Summoning helper (verified)

- Ritual of Summoning is **spellID 698**, costs **1 soul shard**, is cast on the
  summonee, and needs **2 other** group members to click the resulting portal.
- A secure button casts on a specific unit without changing your target via
  `type="spell"`, `spell=<name>`, `unit="party2"` (both reviewers; Codex prefers
  this over a `/cast [@party2] ...` macro, though `[@unit]` conditionals do work in
  2.5). Same out-of-combat attribute rule as the Healthstone button — rebuild the
  per-member buttons on `GROUP_ROSTER_UPDATE`, deferring to `PLAYER_REGEN_ENABLED`
  if `InCombatLockdown()`.
- **Announce:** `UNIT_SPELLCAST_SUCCEEDED` with `unit=="player"` and `spellID==698`
  is the clean "my summon started" signal. It does **not** carry the target name,
  so cache the name from the clicked button (PostClick) and announce that. Use the
  global `SendChatMessage(msg, "PARTY"/"RAID")` — NOT `C_ChatInfo.SendChatMessage`
  (that's the retail form; GLM suggested it, it's wrong for 2.5).

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
