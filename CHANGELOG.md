# Changelog

## 0.7.0 — Ritual of Summoning helper
- **New module: Summon** — a clickable button per group member; click a name to
  start summoning that person (without changing your current target), and it
  auto-announces "Summoning X - click the portal!" to party/raid so the other two
  click. Names are class-colored; shows "+N more" if the group is bigger than the
  button row. Announce toggle in `/wb`.
- Built on the proven secure-button pattern (type="spell" + unit attribute,
  spellID 698); rebuilds out of combat only. Verified with GLM-5.2 + Codex
  (docs/TBC_API_NOTES.md 6f).

## 0.6.0 — tunable thresholds (options sliders)
- The options panel (`/wb`) now has a **Thresholds** column with sliders, so you
  can tune the numbers from the UI instead of editing saved vars:
  - Shards: warn-low count, warn-full count
  - Drain Soul: target-HP % that triggers the execute alert
  - Life Tap: mana-% that shows the cue, and the safe-HP-% for the green light
- Why: hardcoded cutoffs are wrong across the 1-70 leveling range (a 30%-mana
  warning that's fine at 70 is useless at 40). Shard sliders refresh the counter
  live as you drag.

## 0.5.1 — correctness hardening (audit fixes)
Bug-fix pass from a full-source audit (GLM-5.2 + Codex). The important one:
- **Healthstone button was unusable by default.** It's unlocked on a fresh install,
  and the old "secure child" logic disabled the button's mouse while unlocked — so
  the panic button couldn't be clicked until you ran `/wb lock`. The button is now
  ALWAYS clickable; dragging is handled by the button itself and only while
  unlocked (a plain click uses the stone, a press-drag moves it).
- `/wb lock` / `/wb unlock` now refuse to run **in combat** (you can't reconfigure a
  secure button mid-fight; it would silently leave the button in a bad state).
- Modules that are toggled **off** no longer run their `OnInit` (no frames / events /
  secure buttons created for disabled modules).
- Hardening: shard counter uses an explicit `SetFont` instead of relying on a
  "Huge" font template existing; `PetCD` clears its table by reassignment instead
  of `wipe()`; the slash handler is now a local (no global namespace leak).

## 0.5.0 — Life Tap safety cue
- **New module: LifeTap** — an honest two-state cue: green **"LIFE TAP"** when mana
  is low and your health is high enough to tap safely, red **"HP LOW - heal"** when
  mana is low but tapping would drop you too far. Hidden when mana is fine.
  Thresholds configurable (`lifetap.manaBelow` / `lifetap.safeHpAbove`).
- Built from live health/mana fractions only — **no "expected mana" number**,
  because the per-rank Life Tap values and any spell-power scaling are
  disputed/ambiguous for 2.5 (one reviewer's data was WotLK-contaminated). A
  percentage cue needs none of that and can't be wrong about game data.

## 0.4.0 — One-click Healthstone panic button
- **New module: Healthstone** — a real secure button you can click (or keybind via
  a `/click WarlockBuddyHealthstoneButton` macro) to use your healthstone **in
  combat**. Shows the stone's icon, dims with a red "0" when you're out of stones,
  and runs a cooldown sweep (healthstones share the 2-min potion cooldown).
- Auto-targets whichever healthstone rank/variant you're carrying (warlocks hold
  only one at a time); re-points itself out of combat on bag changes and on
  leaving combat, since secure attributes can't change mid-fight.
- Util: movers now support a `secureChild` so the panic button is draggable while
  unlocked and clickable while locked.
- Verified the whole secure-button approach with GLM-5.2 + Codex (95-99%
  confidence, no disagreement); documented in docs/TBC_API_NOTES.md (6d).

## 0.3.0 — Pet utility cooldown tracker
- **New module: PetCD** — ready/cooldown bars for the current pet's key utility
  abilities: **Spell Lock** (Felhunter interrupt), **Seduction** (Succubus CC),
  **Devour Magic**, **Sacrifice**, **Intercept** (Felguard), **Suffering**. Bars
  go green "READY" or count down amber while on cooldown. This was the #1 next
  feature in both AI reviews — TBC has no native pet-cooldown readout.
- Abilities are matched **by name** across the 10 pet action slots (not by
  hardcoded slot numbers, which aren't stable) and resolved from spell ids in
  Data.lua, so it's locale-safe and works regardless of bar arrangement.
- Uses confirmed-present events `PET_BAR_UPDATE` / `PET_BAR_UPDATE_COOLDOWN` /
  `UNIT_PET`; deliberately avoids `PLAYER_PET_CHANGED` (Codex flagged it
  unreliable in 2.5).

## 0.2.0 — Drain Soul execute alert
- **New module: Execute** — watches the target's health and throws a big
  "DRAIN SOUL" cue (icon + screen flash + sound) when it drops into shard-farming
  range (default 25%). Spec-agnostic; helps a newer warlock remember to bank a
  soul shard on the kill without thinking about it. Toggle in `/wb`, draggable,
  threshold configurable in saved vars (`execute.threshold`).
- Verified (GLM-5.2 ↔ Codex) that the Pet module's `UNIT_POWER_UPDATE` usage and
  `UnitPower("pet", 0)` are correct for 2.5; documented that the event's arg2 is
  the power **token string** ("MANA"), not an int (Codex correct, GLM wrong).
- Both reviewers ranked a **pet utility cooldown tracker** (Spell Lock / Seduce /
  Sacrifice) as the #1 next feature — deferred one iteration pending verification
  of the exact `GetPetActionInfo`/`GetPetActionCooldown` return signature in 2.5
  (see docs/DECISIONS.md) so we don't ship a broken module.

## 0.1.0 — initial scaffold
First playable build. Modular, spec-agnostic warlock companion for TBC Classic
(2.5.x / Anniversary).

Modules:
- **Shards** — soul shard counter with low/full color warnings + healthstone &
  soulstone counts.
- **DoTs** — player-cast DoT & curse time bars on target.
- **Procs** — Shadow Trance / Backlash alerts (icon + flash + sound).
- **Pet** — health/mana bars, Soul Link status, Dark Pact readiness, no-pet nag.
- **Soulstone** — party/raid soulstone tracker + chat announce.
- **Reminders** — armor & weapon-stone nags.
- **CC** — Banish/Fear/Seduction/Enslave/Howl/Death Coil countdown bars.

Foundations:
- No-dependency architecture (no Ace3); pure 2.5 API.
- Draggable movers with global lock/unlock.
- Options panel + `/wb` slash commands.
- All ids/names triangulated GLM-5.2 ↔ Codex (see docs/TBC_API_NOTES.md).
