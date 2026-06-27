# In-game test checklist

The offline tests (`tests/headless.lua`) prove the addon loads and its logic is
right, but some things can only be checked on a real warlock in WoW — secure
buttons in combat, taint, sounds, and how the frames actually look. This is a
plain-language checklist for doing that. **No coding needed** — just play and tick
boxes.

## How to report a problem
1. Type `/wb status` in chat — it prints the version and which modules loaded.
2. If you see any **red error text** in chat, copy it (or screenshot it).
3. Note what you were doing when it happened.
Send those to whoever maintains the addon. That's it.

> Tip: turn on Blizzard's Lua errors first so problems are visible —
> Esc → Options → System → Advanced → check **"Display Lua Errors"** (or type
> `/console scriptErrors 1`).

---

## 1. First load
- [ ] Log in on a **warlock**. Chat shows a purple `WarlockBuddy` welcome + `Loaded`.
- [ ] A purple **WB button** is on the minimap edge.
- [ ] `/wb status` lists ~13 modules, all green **ok** (none red **ERROR**).
- [ ] `/wb help` prints the command list.
- [ ] Log in on a **non-warlock** → addon says it's idle, shows nothing. (optional)

## 2. Moving & saving frames
- [ ] `/wb unlock` → purple drag boxes appear; hovering a frame shows a tooltip
      naming it.
- [ ] Drag a couple of frames somewhere obvious. `/wb lock` → boxes disappear.
- [ ] **Reload** (`/reload`) → frames are exactly where you left them.
- [ ] Fully **log out and back in** → frames still there.
- [ ] `/wb resetpos` → all frames jump back to the tidy default layout.
- [ ] Open `/wb`, drag the **Drain Soul** and **Life Tap** sliders → reload → the
      slider values stuck.

## 3. Shards & stones
- [ ] The shard number matches your actual soul shard count; it updates when you
      gain/spend one. Goes **red** when low, **orange** when your bag is nearly
      full.
- [ ] `HS` / `SS` counts match your healthstone / soulstone.

## 4. Healthstone panic button (⚠ in combat)
- [ ] Make a Healthstone. Its icon shows on the Healthstone frame; **0**/dimmed
      when you have none.
- [ ] Out of combat, click it → uses the stone.
- [ ] **In combat**, click it → it uses the stone with **no red "action blocked"
      error**. (This is the most important check.)
- [ ] After using one, the button shows the cooldown sweep.

## 5. DoTs & expiry warning
- [ ] Target a mob, apply your DoTs/curses → a bar appears per dot with a
      shrinking timer that matches Blizzard's debuff timer.
- [ ] Let a dot get to its last ~3 seconds → its bar **pulses** (warning).
- [ ] Have **another player** dot the same mob → only **your** dots show (theirs
      are ignored).

## 6. Procs
- [ ] When **Shadow Trance (Nightfall)** or **Backlash** procs → a big icon +
      screen flash appears (and a sound if you enabled it). It clears when the
      proc is used/expires.

## 7. Drain Soul execute
- [ ] Fight a mob down past **~25%** health → the **DRAIN SOUL** cue appears
      (so you swap to Drain Soul for a shard on the kill). Gone above the
      threshold and on a fresh target.

## 8. Pet
- [ ] With a pet out: name + health/mana bars are correct; "No pet!" when
      unsummoned.
- [ ] With Soul Link active it shows; Dark Pact status reflects pet mana.
- [ ] **PetCD**: on a Felhunter/Succubus, Spell Lock / Seduction show **READY**,
      then count down after you use them.

## 9. Life Tap cue
- [ ] Drop your mana low while health is high → green **LIFE TAP**.
- [ ] Mana low **and** health low → red **HP LOW — heal** instead.

## 10. Soulstone (in a group)
- [ ] In a party, cast a Soulstone on someone → chat announces
      "Soulstone on <name>…" to party.
- [ ] The Soulstone frame lists who in the group currently has a soulstone, with
      time left.

## 11. Ritual of Summoning (in a group)
- [ ] In a party, the Summon frame shows a button per member (class-colored).
- [ ] Click a member's button → you start summoning **them** without losing your
      current target; chat announces "Summoning <name> — click the portal!".

## 12. Reminders
- [ ] With no Fel/Demon Armor up → "No Armor!" reminder. Buff it → reminder clears.
- [ ] With no Spellstone/Firestone weapon enchant → reminder shows; apply one →
      clears.

## 13. Minimap button
- [ ] Left-click → opens options. Right-click → toggles frame lock. Drag → it
      moves around the minimap ring and stays after reload.

## 14. Taint watch (whole session)
- [ ] After a normal play session (combat, summoning, reloading), there are **no**
      repeating red Blizzard error popups or "Interface action failed because of an
      AddOn" messages.
- [ ] Run `/wb status` **after a fight** too (not just at login) → still all green,
      no errors. (Catches anything that only sets up after combat ends.)

---

When everything above checks out, it's genuinely 1.0-ready. Anything that fails →
report it per the top section.
