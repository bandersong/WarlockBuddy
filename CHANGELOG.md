# Changelog

## Unreleased (dev)
- **CI** (`.github/workflows/ci.yml`): every push/PR runs `luac -p` on all Lua +
  `lua tests/headless.lua`, on **Lua 5.1** (the version WoW uses) so the checks
  match the real target, not a newer local Lua. Regressions now fail the build
  automatically. README shows the CI badge.
- **In-game test checklist** (`docs/TESTING.md`): a plain-language, no-coding
  checklist a non-expert can follow on a real warlock to verify the things offline
  tests can't (in-combat Healthstone click, summon-on-party-member, group soulstone
  announce, live DoT timers, proc flash/sound, taint watch, frame/option
  persistence), plus how to report problems via `/wb status`. This is the last gate
  before calling it 1.0.
- **Headless test harness** (`tests/headless.lua`): stubs the WoW API and actually
  runs the addon offline. Two stages:
  - *Smoke* — loads every file in `.toc` order, runs every module's `OnInit`, and
    fires the main events + slash commands (catches load/runtime errors `luac -p`
    can't).
  - *Behavior* — drives module logic through a per-test mock state and asserts
    results: shard counter shows the held count; DoT tracker includes a
    player-cast Corruption **and ignores another player's**; execute alert
    shows/hides at the health threshold; Life Tap cue goes green (safe) vs warns
    (HP low); soulstone announce fires with the target name. 8 assertions, all
    passing.
  - Reusable gate for every future change. `.gitattributes` keeps dev files out
    of release zips. No change to the shipped addon.

## 0.9.7 — first downloadable release + packaging
- Cut the **first proper release**: a clean `WarlockBuddy-v0.9.7.zip` whose top
  folder is exactly `WarlockBuddy/`, so it extracts straight into
  `Interface/AddOns` with no renaming (GitHub's auto "Source code" zip nests the
  folder and breaks drag-drop for non-technical users).
- `.toc` metadata polish: colored title, `X-Website`, `X-Category: Class`,
  `X-License: MIT`. No behavior change.

## 0.9.6 — DoT-expiry refresh warning
- A tracked DoT/curse bar now **pulses** when it's about to fall off (default: the
  last 3 seconds), so you can refresh before losing uptime — the core of warlock
  damage. Optional **sound** too (off by default, so it never nags when you're
  letting a DoT drop on purpose).
- Both tunable in `/wb`: "DoT expiry warn (sec, 0=off)" slider + a sound checkbox.
- Conservative by design (warns "about to expire", ~2.5-4s is the recommended
  range), and only ever warns on YOUR dots (player-cast), auto-clearing when the
  target dies or the dot is refreshed.

## 0.9.5 — config-mode frame tooltips
- When you **unlock** frames (`/wb unlock`), hovering any WarlockBuddy frame now
  shows a tooltip naming it and explaining what it is ("DoTs — Your DoT & curse
  timers on the target", etc.) plus "Drag to move". Makes it obvious which box is
  which while you're arranging them.
- Tooltips are naturally limited to config mode — locked frames stay click-through
  (mouse off), so they never get in the way during play. The Healthstone button
  (always clickable) gates its own tooltip to the unlocked state.

## 0.9.4 — /wb status diagnostic
- **`/wb status`** prints the version and, per module, whether it's off / loaded ok
  / errored (with the error text). Each module's `OnInit` is already wrapped in a
  `pcall`, so a single broken module can't take down the rest — and now you can
  see exactly which one and why. Makes a user's first login a usable bug report
  (helpful since the author can't always test in-game).

## 0.9.3 — locale-proof soulstone announce
- The "Soulstone on X" chat announce now matches the cast by **spell id**
  (20707 / 20762-20765 / 27239) first, falling back to the localized name. Before,
  it matched the localized buff name only, which would silently fail on a
  non-English client. Captures `spellId` (12th CLEU return) + keeps the name
  fallback for safety.

## 0.9.2 — onboarding: welcome message + /wb help
- **One-time welcome** on first login: explains the minimap button, `/wb`, how to
  move frames, and `/wb resetpos` — so a new player isn't staring at a "weird icon"
  wondering what to do. Shown once (tracked by `welcomed` saved var).
- **`/wb help`** lists every command (the permanent reference after the welcome
  scrolls away).
- No features removed — everything stays enabled by default (as intended).

## 0.9.1 — secure/options hardening (re-audit)
Bug-fix pass from a second full-source audit of the newer code (GLM-5.2 + Codex):
- **Options checkboxes use their own label fontstring** instead of the template's
  `.Text` field, which isn't reliably present on unnamed frames in 2.5 — this could
  have thrown when the options panel opened (and the minimap button opens it).
- **Secure buttons (Healthstone, Summon) defer their setup if `OnInit` runs in
  combat** (e.g. a `/reload` mid-fight), instead of calling `SetAttribute`/`SetPoint`
  under combat lockdown. They build on the next `PLAYER_REGEN_ENABLED`.
- **Minimap right-click** lock/unlock now honors the same in-combat guard as `/wb
  lock`, and the drag math bails safely if `Minimap:GetCenter()` returns nil.
- **Healthstone cooldown** clears its sweep when you have no stone.
- Summon announce now matches the cast by spell id OR resolved name (robust to
  client arg differences).

## 0.9.0 — minimap button
- **New module: MinimapButton** — a self-contained button on the minimap (no
  LibDBIcon dependency). **Left-click** opens options, **right-click** locks/unlocks
  frames, **drag** moves it around the minimap ring (position persists). Tooltip
  explains all three. Discoverability for anyone who won't remember `/wb`.
- Disable it from the options list (then `/reload`).

## 0.8.0 — clean default layout + reset positions
- **Sane default layout.** The 12 frames now spread across the screen (left column
  shards/pet CDs/pet, right column soulstone/DoTs/summon, center alerts stacked,
  Healthstone near the action bars) instead of piling up near the middle on first
  load. First impression is a clean, readable screen, not a heap of boxes.
- **`/wb resetpos`** restores every frame to that default layout, and there's a
  **"Reset frame positions" button** in the options panel for anyone who doesn't
  know the slash command (or who dragged a frame off-screen).

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
