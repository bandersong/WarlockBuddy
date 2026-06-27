# Decisions & next-pick queue

Running log of what the iterative improvement loop decided and why. Each loop run
triangulates GLM-5.2 + Codex, picks ONE scoped change, and records the reasoning
here so the next run has continuity.

## Next pick (queued)

**The feature set is complete. Both reviewers now say the #1 remaining gap is an
IN-GAME TEST PASS, not more features** — and that can't be done from this machine
(no WoW install). Until someone loads it on a real TBC warlock:
- Remaining buildable items are polish only (consistent fonts/bar textures), with
  real diminishing returns. Don't add gameplay modules just to keep the loop busy.
- When in-game testing is possible: load on a warlock, run `/wb status`, fix any
  reported module errors, then verify each module's behavior and call it 1.0.
- Lower-value optional features if ever wanted: Demonic Sacrifice tracker (deep
  Demo only), Soulstone self-use button.
  When possible, load it on a real warlock and fix what actually breaks before
  calling it 1.0.
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

### 2026-06-27 — investigated RegisterUnitEvent; deliberately NOT doing it
- GLM's auto-consult flagged that registering UNIT_AURA globally (filtering unit in
  the handler) spams events in raids, suggesting `RegisterUnitEvent`. Investigated.
- **Decision: no change.** Existence of `RegisterUnitEvent` in 2.5 is unconfirmed
  (GLM says absent, but via the false "Classic = 2.4.3 API" premise; can't verify
  here), the perf gain is negligible for the actual user (5-man/leveling, not
  25-man), and a shared dispatch frame would need the unit-union and re-filter in
  Lua anyway — eroding the gain. Documented in TBC_API_NOTES 7b so it isn't
  re-investigated every loop.
- **Meta:** this confirms the loop is in churn territory. The addon is
  feature-complete, audited, tested, CI-gated on 5.1, and auto-releasing; the only
  real remaining work is the human in-game pass (docs/TESTING.md). Recommend
  converting the cron loop to on-demand to stop spending tokens on marginal runs.

### 2026-06-27 — v0.9.8: automated releases + cleaner zips
- Added `.github/workflows/release.yml`: a `v*` tag push auto-builds the clean
  zip (git archive --prefix=WarlockBuddy/) and publishes the Release. Fits his
  set-and-forget preference — future releases are just a tag.
- **Red-team catch:** `.gitattributes` only export-ignored `tests/`, so release
  zips would have leaked `.github/` and `docs/`. Added both (+ kept README/LICENSE/
  INSTALL/CHANGELOG in the zip).
- **Triangulation:** GLM-5.2 + Codex agreed on the workflow (export-ignore honored
  by git archive, `permissions: contents: write`, softprops/action-gh-release@v2).
  They split on `fetch-depth`: GLM said 0 is mandatory (archiving the tag); Codex
  said unneeded if archiving `github.sha`. Used `fetch-depth: 0` + archive the tag
  ref — robust, covers both. Verified by an actual tagged run (like CI before it).
- **Honest note:** this is the last substantive offline automation. The addon is
  feature-complete, audited, tested, CI-gated, and now auto-releasing. Remaining
  work is the human in-game pass (docs/TESTING.md). Further loop runs are churn —
  recommend converting the cron loop to on-demand.

### 2026-06-27 — CI on Lua 5.1 (dev)
- Capstone on the test work: GitHub Actions runs `luac -p` (all .lua) +
  `lua tests/headless.lua` on every push/PR, so the suite I built actually guards
  every future change instead of relying on me to run it.
- **Triangulation:** GLM-5.2 + Codex both ranked CI the highest-value next step
  (high confidence) over a niche feature, and both stressed the key point: **run CI
  on Lua 5.1, not a newer Lua** — WoW uses 5.1, and a newer local Lua can accept
  things that break in-game (math.atan2 removed after 5.2, table.unpack vs unpack,
  goto/integer ops in 5.3+). So CI is now a *better* check than my local 5.5.
  - Install method split: GLM = `leafo/gh-actions-lua` (pins version, ships luac);
    Codex = apt `lua5.1`. Chose leafo — provides `lua`+`luac` unversioned and
    sidesteps Codex's own doubt about whether apt's lua5.1 ships luac5.1.
- Pre-checked the code for 5.1 incompatibilities (no `//`/`goto`/`<const>`;
  `unpack` and `math.atan2` are 5.1-native) so the first CI run should be green.

### 2026-06-27 — in-game test checklist (docs/TESTING.md)
- Wrote the human in-game checklist (codex's long-queued "B"). Logic is now
  offline-tested; this covers what only a real 2.5.x client can show: secure
  Healthstone click IN COMBAT (no "action blocked"), summon-on-party-member without
  losing target, group soulstone announce, live DoT timer sync + expiry pulse, proc
  flash/sound, minimap drag, frame/option persistence across reload+relog, and a
  whole-session taint watch. Non-expert friendly (no coding), with a "/wb status +
  copy red errors" report path.
- **Triangulation:** GLM-5.2 + Codex both confirmed it's the right next artifact
  and produced near-identical high-risk check lists; every codex item maps to a
  section. Added codex's nuance: run `/wb status` AFTER a fight too (catches
  deferred secure setup). Linked from README.
- **This is the last gate before 1.0.** The loop has done all it can offline:
  feature-complete, twice-audited, release-packaged, offline-tested (smoke + 8
  behavior asserts), and now with a clear in-game acceptance checklist. Real 1.0
  needs a human to run that checklist on a warlock.

### 2026-06-27 — behavior assertions in the test harness (dev)
- Upgraded the smoke harness from "doesn't crash" to "logic is correct" — codex
  had flagged smoke as weak at catching real bugs. Added a per-test MockState the
  stubs read from (reset between tests, no leakage) and 8 behavior assertions.
- **Triangulation:** GLM-5.2 + Codex both ranked this A > B(TESTING.md) > C(feature)
  and named the SAME 5 behaviors to assert; both flagged the key risk = positional
  WoW API return shapes (UnitDebuff, CombatLogGetCurrentEventInfo) — a wrong shape
  makes tests pass against fiction. I pinned the CLEU mock to the verified 2.5
  layout (spellId 12th) that Soulstone.lua actually reads, and matched UnitDebuff's
  return order. Both warned "don't overbuild a fake WoW" — kept the mock minimal.
- **Result: PASS (8/8).** Now verified offline (not just assumed): shard count
  mapping; DoT tracker includes player-cast + EXCLUDES another player's dot (the
  mineOnly filter); execute threshold boundary; Life Tap green/warn; soulstone
  announce via spell-id match. No bugs found, but these were previously unproven.
- A human TESTING.md (codex's B) remains queued for true in-game behavior.

### 2026-06-27 — headless smoke-test harness (dev)
- The addon's one real remaining risk is "never run in-game." Rather than churn
  features, built the closest offline substitute: `tests/headless.lua` stubs the
  WoW API (mock frames with real script/event storage + a metatable no-op for
  everything else; numeric methods return sane numbers so arithmetic survives),
  loads all files with the shared `(ADDON, ns)` vararg, fires the lifecycle through
  the addon's real event frame, and checks each module's recorded `_err`.
- **Result: PASS** — 13 modules init, 11 events + 6 slash commands run with zero
  errors. No bugs found, but the load/init/event path is now verified offline.
- **Triangulation:** GLM-5.2 + Codex both endorsed this as the highest-value
  offline step (high confidence it catches startup/nil/vararg/handler crashes;
  low confidence on deep gameplay-correctness — that still needs in-game). Codex
  suggested pairing with a TESTING.md behavior checklist (queued).
- Gotchas they flagged and I applied: Lua 5.1 `unpack` (local fallback to
  table.unpack since I run under 5.5); feed each file the same `ns`; metatable
  no-op returning self for chaining; pcall each file/event, report all not first.

### 2026-06-27 — v0.9.7: first downloadable release + packaging
- Feature set is complete, so this round shipped DELIVERY, not churn: cut the first
  GitHub release (tag v0.9.7) with a hand-built `WarlockBuddy-v0.9.7.zip` whose top
  folder is exactly `WarlockBuddy/` (verified via `unzip -l`: toc present, no
  double-nest, no .git dir). Built with `git archive --prefix=WarlockBuddy/`.
  Polished .toc metadata (colored title, X-Website/Category/License). INSTALL.md
  points at Releases first.
- **Triangulation:** GLM-5.2 + Codex both confirmed the zip structure, that `X-`
  toc fields are safely ignored if unknown in 2.5, colored `## Title` works, and
  `.pkgmeta` is irrelevant to a manual zip — codex even gave the `unzip -l`
  verification step, which I ran.
- Still NOT 1.0: the in-game test on a real warlock remains the gate (needs a WoW
  install). The release just makes that test trivial to set up.

### 2026-06-27 — v0.9.6: DoT-expiry refresh warning (last feature)
- **Triangulation: both said we're at diminishing returns.** #1 pick from both =
  "it's done, the real gap is in-game testing" (can't do here). #2 from both = A,
  the DoT-expiry warning, the strongest remaining buildable gameplay win (warlock
  DPS = DoT uptime). Built A with their shared guidance: warn ~2.5-4s out (default
  3, slider), player-cast only (already), suppress on dead/expired (already), sound
  conservative/off-by-default (avoid nagging intentional Immolate drops).
- **Shipped:** Dots bars pulse + optional sound when a tracked dot is within
  warnAt seconds of expiring; keyed by spell name so it fires once per cycle and
  survives rebuilds; slider + sound checkbox in options.
- **Calling the feature set complete.** Further loop runs should be polish or stop
  until in-game testing is possible — noted in Next pick.

### 2026-06-27 — v0.9.5: config-mode frame tooltips
- **Triangulation: clean agreement.** Both confirmed GameTooltip
  (SetOwner/AddLine/Show) is valid in 2.5, that EnableMouse(false) on locked movers
  naturally limits tooltips to config mode (no extra state checks), and that the
  secure-covered frames (Healthstone/Summon) need the tooltip on the button itself.
  Both ranked tooltips above a fonts pass for 1.0 value. Codex extras applied:
  SetOwner before lines, Hide on OnLeave.
- **Shipped:** centralized OnEnter/OnLeave tooltip in MakeMover (+ desc param);
  added a per-frame description to all 12 MakeMover calls; Healthstone button gets
  its own unlocked-gated tooltip. Summon's buttons already show member names, so no
  extra tooltip there.

### 2026-06-27 — v0.9.4: /wb status diagnostic
- **Triangulation:** Codex (high) ranked /wb status the highest-value low-risk
  step; GLM flip-flopped to "tooltips first" (it ranked status higher last round).
  Picked status: most pragmatic given the author can't test in-game — it turns a
  user's first login into a usable bug report. Both gave the same chat gotcha
  (per-line AddMessage, balance |r; local AddMessage isn't chat-throttled).
- **Split resolved:** Codex wanted per-frame shown/hidden in the output; GLM said
  skip. Sided with GLM — alert frames (Procs/Execute) are hidden by default, so
  "hidden" would read as broken. Status shows only off / ok / ERROR per module.
- Also disregarded GLM's recurring (wrong) blind-spot claims this round ("no
  C_Timer in TBC", "TBC uses CHAT_MSG_COMBAT string parsing not CLEU") - those are
  original-2007-TBC facts; TBC *Classic* 2.5 has both, confirmed earlier by Codex.
- **Shipped:** ns:ShowStatus + `/wb status` (+ help entry); Init records
  m._loaded/m._err per module.

### 2026-06-27 — v0.9.3: locale-proof soulstone announce
- **Triangulation: clean agreement.** Both ranked this #1 of the code-verifiable
  options (GLM B#1; Codex B>C>A>D). Both independently confirmed the exact rank ids
  (20707, 20762-20765, 27239) and that CLEU `spellId` is the 12th return in 2.5 —
  two independent sources agreeing = solid ground truth (not trusting GLM's "100%"
  alone, given the Life Tap contamination history). Codex even described the exact
  edit I'd make.
- **Shipped:** announce matches `ns.soulstoneIDset[spellId]` first, name fallback
  second. Non-regressive (name path preserved), now works on any-locale client.
- Tooltips deferred: both said only do them in unlocked/config mode (locked frames
  must stay click-through). Queued.

### 2026-06-27 — v0.9.2: onboarding (welcome + /wb help)
- **Triangulation:** strong consensus — both ranked the first-run welcome and
  `/wb help` as the top two low-risk wins (Codex A then D, GLM D then A); both
  said keep all features on, both deprioritized the Drain channel helper near 1.0.
- GLM's Q2 "API traps" (C_Timer.After wrapping, debuff-limit, rank-in-names) don't
  apply to this code: no C_Timer use (OnUpdate instead), aura `name` field is
  already rank-less, icons are dynamic via GetSpellInfo. Codex's Q2 (saved-var
  nil-safety) is already covered by the recursive applyDefaults deep-merge.
- **Shipped:** one-time welcome (welcomed saved var) + ns:ShowHelp / `/wb help`.
- **Stayed at 0.9.x, NOT 1.0:** the addon has never run in WoW. 1.0 should mean
  in-game-verified, not just feature-complete. In-game test is the queued gate.

### 2026-06-27 — v0.9.1: secure/options hardening (re-audit #2)
- Audited everything added since the v0.5.1 audit (sliders, Summon, MinimapButton,
  ResetPositions, Healthstone drag) with GLM-5.2 + Codex toward a trustworthy 1.0.
- **GLM over-reported again — all 9 of its "findings" were false or cosmetic:**
  claimed `M.BAG_UPDATE_DELAYED = M.Update` is a syntax error (it isn't; luac
  passes), claimed secure buttons can't be parented to addon frames (they can —
  universal pattern), claimed ResetPositions lowercase mapping fails (it doesn't),
  claimed the slider region lookups and UNIT_SPELLCAST_SUCCEEDED args were wrong
  (both fine). Codex explicitly confirmed all of these are correct.
- **Codex found the real issues GLM missed:** (1) `makeCheck` used `cb.Text` which
  isn't reliably present on unnamed 2.5 frames — would throw on opening options;
  (2) secure-button OnInit had no combat guard (fails on /reload mid-fight);
  (3) minimap right-click lock lacked the combat guard; (4) Healthstone cooldown
  not cleared when no stone. Fixed all four. Also hardened the Summon announce
  match (id OR name) - harmless even though codex said the args were already right.
- Lesson reaffirmed (again): GLM's audit "criticals" need full re-triage; Codex is
  the more reliable auditor here, but cross-checking both still caught more than
  either alone.

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
