# Decisions & next-pick queue

Running log of what the iterative improvement loop decided and why. Each loop run
triangulates GLM-5.2 + Codex, picks ONE scoped change, and records the reasoning
here so the next run has continuity.

## Next pick (queued)

Candidates surfaced by reviewers, not yet built (pick + re-triangulate next run):
- **Curse assignment / raid curse monitor** (Codex #2) — show your assigned curse,
  warn if it drops or conflicts with another lock's.
- **Ritual of Souls / Summoning helper** — secure button (same pattern as the
  Healthstone button now proven) for Ritual of Souls / Summon out of combat.
- **Soulstone emergency button** — secure `/use` button for the soulstone item,
  mirroring the Healthstone module.

## Log

### 2026-06-27 — v0.5.0: Life Tap safety cue
- **Triangulation caught contaminated data — the whole point of this rule.** GLM
  claimed a rank table with "Rank 8 @ level 74" (TBC caps at 70) and put Improved
  Life Tap in the Destruction tree (it's Affliction). Codex gave the correct max
  (rank 7, spellID 27222) and tree. BUT the two **disagreed on the rank base
  values** (rank 1 = 15 vs 30, etc.), and both agreed Life Tap scales with spell
  damage in TBC (rank 3+, ~80% bonus shadow) — so it's not a flat constant anyway.
- **Decision:** ship a percentage-based safety cue (green "LIFE TAP" / red "HP LOW")
  from live health/mana fractions, and DO NOT show an expected-mana number we can't
  verify. A number we can't trust is worse than no number. Recorded the full
  finding in docs/TBC_API_NOTES.md (6e).
- **Shipped:** Modules/LifeTap.lua. Thresholds configurable. No secure frames, no
  hardcoded game-data guesses.

### 2026-06-27 — v0.4.0: Healthstone panic button
- **Triangulation:** verified the secure-button path before building. GLM-5.2 +
  Codex agreed at 95-99% on every point, NO disagreement: SecureActionButtonTemplate
  works in 2.5; `type=macro`/`macrotext=/use item:<id>` uses the item in combat;
  attributes must be set out of combat; `GetItemCooldown` = start/duration/enable;
  zero taint when self-contained. Both stressed: scan for the held stone, don't
  hardcode one id.
- **Insight that simplified it:** a warlock can only carry ONE healthstone, so no
  potency ranking needed — just a complete id list, first-held wins.
- **Shipped:** Modules/Healthstone.lua (secure button + cooldown + out-of-stones
  state) and a Util `secureChild` hook so the button drags while unlocked and
  clicks while locked. Keybind via `/click WarlockBuddyHealthstoneButton`.

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
