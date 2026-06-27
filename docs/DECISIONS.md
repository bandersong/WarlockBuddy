# Decisions & next-pick queue

Running log of what the iterative improvement loop decided and why. Each loop run
triangulates GLM-5.2 + Codex, picks ONE scoped change, and records the reasoning
here so the next run has continuity.

## Next pick (queued)

**Pet utility cooldown tracker.** Both GLM-5.2 and Codex independently ranked this
#1 (Spell Lock / Seduction / Sacrifice / Devour Magic / Intercept availability).
High value across PvE *and* PvP — TBC has no clean native display of pet ability
cooldowns.

> BEFORE building it, verify in 2.5: the exact return signature of
> `GetPetActionInfo(slot)` (name/subtext/texture/isToken/isActive/autoCast... —
> order has shifted between builds) and `GetPetActionCooldown(slot)` (start,
> duration, enable). Scan `NUM_PET_ACTION_SLOTS` (10) slots; resolve token names
> via `_G[name]` when `isToken`. Don't assume — confirm with a targeted
> glm-ask + codex pass first, then build.

## Log

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
