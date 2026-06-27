# Changelog

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
