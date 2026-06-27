# Changelog

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
