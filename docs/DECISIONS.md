# Decisions & next-pick queue

Running log of what the iterative improvement loop decided and why. Each loop run
triangulates GLM-5.2 + Codex, picks ONE scoped change, and records the reasoning
here so the next run has continuity.

## Next pick (queued)

Candidates surfaced by reviewers, not yet built (pick + re-triangulate next run):
- **Curse assignment / raid curse monitor** (Codex #2) — show your assigned curse,
  warn if it drops or conflicts with another lock's.
- **Life Tap safety helper** (Codex #3) — cue to tap when mana low *and* health is
  safe, so she doesn't tap herself to death.
- **Healthstone emergency button** — secure action button (`/use Healthstone`);
  verify SecureActionButtonTemplate + macrotext taint rules in 2.5 first.
- **Ritual of Souls / Summoning helper** — one-click summon assist out of combat.

## Log

### 2026-06-27 — v0.3.0: Pet utility cooldown tracker (the queued #1)
- **Triangulation:** verified the pet-action API before building (as the prior
  note demanded). Both AIs confirmed `GetPetActionInfo` return order,
  `GetPetActionCooldown` = start/duration/enable, `NUM_PET_ACTION_SLOTS = 10`, and
  that Spell Lock/Seduction live on the pet bar (no combat log needed).
  - **Disagreement:** GLM hardcoded ability→slot maps and used
    `PLAYER_PET_CHANGED`; Codex said slot order isn't reliable to assume and to
    avoid `PLAYER_PET_CHANGED` in 2.5. Resolved toward Codex: match **by name**
    across all 10 slots, and use `PET_BAR_UPDATE`/`PET_BAR_UPDATE_COOLDOWN`/
    `UNIT_PET` only. Robust to both views + dodges the unknown-event risk.
- **Shipped:** Modules/PetCD.lua — green READY / amber countdown bars for the
  current pet's utility abilities. Matched by name, locale-safe, spec-agnostic.

### 2026-06-27 — v0.2.0: Drain Soul execute alert
- **Triangulation:** asked GLM + Codex to (1) verify Pet module event correctness
  and (2) rank the next feature.
  - Both confirmed `UNIT_POWER_UPDATE` is correct for pet mana in 2.5 and
    `UnitPower("pet",0)` works. **Disagreement:** GLM said `UNIT_POWER_UPDATE`
    arg2 is an integer powerType; Codex said it's the `"MANA"` string token —
    Codex is right (matches known modern API). Moot for us: the Pet handler only
    filters on `unit == "pet"` and ignores arg2.
  - Both ranked pet-CD tracker #1 (see queued above).
- **Chosen instead:** Drain Soul execute alert. Lower on the AI ranking but
  *bulletproof* (needs only UnitHealth, zero exotic API), genuinely high-value for
  the actual user (a newer warlock — auto-reminds to bank shards on kills), and an
  explicit example in the loop brief. Rule applied: a correct small change beats a
  half-verified big one. Pet-CD tracker deferred one round to verify its API first.
