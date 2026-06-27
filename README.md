# WarlockBuddy

**The all-in-one warlock companion for World of Warcraft: The Burning Crusade Classic (20th Anniversary realms, 2.5.x client).**

Built to cover every warlock spec — Affliction, Demonology, Destruction — out of the box. Drop it in, log on a warlock, and it just works. No Ace3, no dependencies, one folder.

![spec: all](https://img.shields.io/badge/spec-Affliction%20%7C%20Demo%20%7C%20Destro-9482c9)
![client](https://img.shields.io/badge/client-TBC%20Classic%202.5.x-blue)
[![CI](https://github.com/bandersong/WarlockBuddy/actions/workflows/ci.yml/badge.svg)](https://github.com/bandersong/WarlockBuddy/actions/workflows/ci.yml)

---

## What it does

| Module | What you get |
| --- | --- |
| **Shards** | Big soul-shard counter. Turns **red** when low, **orange** when your bag is nearly full. Also shows healthstone & soulstone counts. |
| **DoTs** | Time-left bars for *your own* DoTs on the target — Immolate, Corruption, Unstable Affliction, Siphon Life, Seed, Curse of Agony/Doom (+ all the utility curses). Green→yellow→red as they expire. |
| **Procs** | Big center icon + screen flash + sound when **Shadow Trance (Nightfall)** or **Backlash** procs, so you never miss a free instant. |
| **Pet** | Pet health & mana bars, **Soul Link** status, **Dark Pact** readiness (warns when pet mana is too low to drain), and a "No pet!" nag. |
| **Soulstone** | Tracks the Soulstone Resurrection buff across your whole party/raid with time left, and can announce in chat when *you* soulstone someone. |
| **Reminders** | Nags when you have **no Fel/Demon Armor** up or **no Spellstone/Firestone** weapon enchant. |
| **CC** | Countdown bars for your **Banish / Fear / Seduction / Enslave / Howl of Terror / Death Coil** on the target — recast before it breaks. |
| **PetCD** | Ready / cooldown bars for the current pet's utility abilities — **Spell Lock**, **Seduction**, **Devour Magic**, **Sacrifice**, **Intercept**, **Suffering**. |
| **Execute** | Big **DRAIN SOUL** flash when the target drops to ~25% so you bank a soul shard on the kill. |
| **Healthstone** | One-click **Healthstone panic button** that works in combat — click it or keybind it. Shows cooldown and dims when you're out. |
| **LifeTap** | Safety cue — green **LIFE TAP** when mana's low and HP is safe, red **HP LOW** when tapping would drop you too far. |
| **Summon** | **Ritual of Summoning** buttons (one per group member) + auto party announce so the other two click the portal. |

Everything is a **draggable frame** and every module can be **toggled independently**.

## Commands

| Command | Action |
| --- | --- |
| `/wb` | Open the options panel |
| `/wb help` | List all commands |
| `/wb status` | Show version + which modules loaded (for bug reports) |
| `/wb unlock` | Show drag handles — move frames anywhere |
| `/wb lock` | Lock frames in place |
| `/wb resetpos` | Restore all frames to the default layout |
| minimap button | Left-click: options · Right-click: lock/unlock · Drag: move |
| `/wb reset` | Reset all settings (then `/reload`) |

**Keybind the Healthstone button:** make a macro with the text
`/click WarlockBuddyHealthstoneButton` and bind it — it'll use your healthstone in
combat from a keypress.

## Install

See [INSTALL.md](INSTALL.md). Short version: copy the `WarlockBuddy` folder into
`World of Warcraft/_classic_/Interface/AddOns/`, then `/reload` or restart.

## Notes for tinkerers

This addon is written against the **TBC 2.5 API**, which is *not* the same as
retail or Wrath. The design decisions and API gotchas (why we match auras by
name, the player-cast duration quirk, the disputed Shadow Trance id, etc.) are
documented in [docs/TBC_API_NOTES.md](docs/TBC_API_NOTES.md).

## Development

Two checks gate every change (no WoW needed):

```sh
for f in *.lua Modules/*.lua; do luac -p "$f"; done   # syntax
lua tests/headless.lua                                  # load/init smoke test
```

`tests/headless.lua` stubs the WoW API, loads every file in `.toc` order, fires
`ADDON_LOADED`/`PLAYER_LOGIN` (running every module's `OnInit`), and exercises the
events, slash commands, and 8 behavior assertions — catching runtime + logic
errors that a syntax check can't. Exit 0 = clean. (Dev-only; excluded from release
zips via `.gitattributes`.)

Both checks also run in **GitHub Actions on every push/PR** (`.github/workflows/ci.yml`)
against **Lua 5.1** — the version WoW uses — so a regression can't slip in unnoticed.

For things only a real client can verify (secure buttons in combat, taint, proc
visuals), follow the in-game checklist in [docs/TESTING.md](docs/TESTING.md).

## License

MIT — see [LICENSE](LICENSE).
