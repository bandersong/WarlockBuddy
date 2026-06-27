# Decisions & next-pick queue

Running log of what the iterative improvement loop decided and why. Each loop run
triangulates GLM-5.2 + Codex, picks ONE scoped change, and records the reasoning
here so the next run has continuity.

## Next pick (queued)

Candidates surfaced by reviewers, not yet built (pick + re-triangulate next run):
- **First-run "Beginner" preset** (Codex #3) — start with fewer modules on + plain
  tooltips to cut overwhelm.
- **Drain channel helper** (Codex #2 earlier) — tick/clip timer for Drain Life/Soul.
- **Soulstone announce: match by spell id, not name** — codex (0.92) says use the
  rank ids {20707,20762,20763,20764,20765,27239} instead of the localized name in
  the CLEU match (name only as fallback). Small robustness fix; tracker itself is
  already correct (see log).
- **Curse assignment / raid curse monitor** — raid-niche; lower priority for a
  general/leveling player.
- **Ritual of Souls / Summoning helper** — secure button (same pattern as the
  Healthstone button now proven) for Ritual of Souls / Summon out of combat.
- **Soulstone emergency button** — secure `/use` button for the soulstone item,
  mirroring the Healthstone module.

## Log

### 2026-06-27 — v0.9.0: self-contained minimap button
- **Triangulation:** both confirmed the ring math, frame setup, drag (cursor /
  UIParent:GetEffectiveScale, atan2 vs Minimap center), parent-to-Minimap.
- **Caught a GLM error on ground truth:** GLM said to use 2-arg `math.atan(y,x)`
  and NOT `math.atan2`. That's backwards for Lua 5.1 (WoW): 5.1 HAS `math.atan2`;
  2-arg `math.atan` is 5.3+. Codex confirmed `math.atan2`. Shipped with an
  atan2-preferring helper (2-arg atan fallback) so it's correct either way.
  Also fixed GLM's one-shot drag (it only set the angle on OnDragStart) to a
  proper OnUpdate-while-dragging loop.
- **Shipped:** Modules/MinimapButton.lua — left-click options, right-click
  lock/unlock, drag around ring, tooltip, position persists. No LibDBIcon.

### 2026-06-27 — v0.8.0: clean default layout + /wb resetpos
- **Triangulation: rare strong agreement.** With 12 modules now, I flagged frame
  clutter as the real risk for a non-expert and asked both to rank feature vs
  usability. Both independently put "sane non-overlapping default layout + resetpos"
  #1 (GLM 9.5/10, Codex 95%) and "minimap button" #2. Combat optimizations (drain
  helper) and the soulstone id hardening were explicitly deprioritized for a new
  player. Built #1.
- **Shipped:** spread default positions for all 12 frames; `ns:ResetPositions()`
  (maps mover name->saved-var key by lowercasing, copies pristine ns.defaults ->
  db, re-anchors live); `/wb resetpos` + a "Reset frame positions" button in the
  options panel. Minimap button is now the queued #1.

### 2026-06-27 — v0.7.0: Ritual of Summoning helper
- **Triangulation:** strong consensus. Both confirmed spellID 698, 1-shard cost,
  the cast-on-summonee + 2-clickers mechanic, the out-of-combat secure-attribute
  rule, and that the success event lacks the target name (cache it from the clicked
  button). Codex preferred `type="spell"`+`unit` attribute over a `[@unit]` macro;
  used that.
- **Caught a GLM error:** GLM's announce code used `C_ChatInfo.SendChatMessage`
  (retail). Used the global `SendChatMessage` instead (already proven in Soulstone).
- **Shipped:** Modules/Summon.lua — per-member secure summon buttons, class-colored,
  "+N more" overflow note (no silent cap), auto party/raid announce on success.

### 2026-06-27 — v0.6.0: options sliders for thresholds
- **Q1 (next pick) — reviewers split:** GLM ranked options sliders #1 (leveling
  thresholds matter); Codex ranked Ritual of Summoning #1 and sliders #3 ("useful
  polish" but less of a warlock feature). Both agreed sliders are useful and both
  ranked Demonic Sacrifice last. Chose sliders this round: zero game-fact risk,
  genuinely useful across the 1-70 range, and complete-able cleanly. Ritual of
  Summoning is now the queued #1 (Codex's top).
- **Q2 — GLM hallucination, caught by triangulation + ground truth.** GLM claimed
  the soulstone buff on a LIVING player is named after the item ("Master
  Soulstone"), which would mean our Soulstone TRACKER (matches "Soulstone
  Resurrection") was broken. Codex, citing Wowhead TBC (spell 20707/27239),
  confirmed the applied buff IS "Soulstone Resurrection" — so the tracker is
  correct and GLM was wrong. No change made to the tracker. Codex did flag a real
  minor upgrade: match the announce by spell id, not localized name — queued.
- **Shipped:** Options.lua sliders (shard low/full, execute %, life-tap mana %,
  safe-HP %), with a reusable makeSlider helper. Shard sliders refresh live.

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
