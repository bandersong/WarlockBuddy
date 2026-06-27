# Decisions & next-pick queue

Running log of what the iterative improvement loop decided and why. Each loop run
triangulates GLM-5.2 + Codex, picks ONE scoped change, and records the reasoning
here so the next run has continuity.

## Next pick (queued)

Candidates surfaced by reviewers, not yet built (pick + re-triangulate next run):
- **Curse assignment / raid curse monitor** (Codex #2) — show your assigned curse,
  warn if it drops or conflicts with another lock's.
- **Soulstone announce is brittle** (both reviewers) — the CLEU match may miss real
  soulstone applications. Verify the exact 2.5 subevent/payload for a soulstone
  apply against ground truth, then key off it (or off the item spell id).
- **Ritual of Souls / Summoning helper** — secure button (same pattern as the
  Healthstone button now proven) for Ritual of Souls / Summon out of combat.
- **Soulstone emergency button** — secure `/use` button for the soulstone item,
  mirroring the Healthstone module.

## Log

### 2026-06-27 — v0.5.1: correctness hardening (audit triage)
- Ran a full-source bug audit through GLM-5.2 + Codex (the addon has never run
  in-game yet). **This was a textbook triage win.** GLM returned 8 "critical" bugs;
  cross-checking against Codex + known TBC truth, most were FALSE:
  - "event dispatch is nil / `function M:EVENT()` doesn't set the key" — wrong;
    Codex confirmed the `fn(m, ...)` shape is correct.
  - "`wipe` doesn't exist / it's Ace3-only" — wrong, it's a WoW global.
  - "`GetWeaponEnchantInfo` misused" — wrong, the code already matched GLM's own fix.
  - "`OpenOptions` undefined" — artifact: Options.lua wasn't in the audited blob.
  - "`CombatLogGetCurrentEventInfo` returns 12 not 13" — Codex: the unpack matches
    the modern Classic-style return shape. Kept as-is.
- **Codex caught a real one GLM missed:** the Healthstone secure button was dead by
  default (unlocked install + mouse disabled while unlocked). Fixed: button always
  clickable, self-managed drag gated by lock. Also added a combat guard on
  lock/unlock and stopped disabled modules from running OnInit.
- **Genuinely-real items shipped:** Healthstone-dead-by-default, lock/unlock combat
  guard, disabled-module OnInit gate, + safe hardening (explicit SetFont, table
  reassign vs wipe, local slash fn). Lesson reaffirmed: a "bug audit" over-reports —
  re-triage every claim against a second model + ground truth before touching code.

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
