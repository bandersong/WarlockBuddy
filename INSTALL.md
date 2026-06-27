# Installing WarlockBuddy

## 1. Get the files

**Easiest:** grab the latest **`WarlockBuddy-vX.Y.Z.zip`** from the
[Releases page](https://github.com/bandersong/WarlockBuddy/releases) — it unzips
straight to a `WarlockBuddy` folder, ready to drop in (step 3).

(Alternatively, the green **Code → Download ZIP** button works too, but it names
the folder `WarlockBuddy-main` — you'll need to rename it to `WarlockBuddy`.)

## 2. Find your AddOns folder

For **TBC Classic / Anniversary** the WoW client lives in a `_classic_` folder:

- **Windows:** `C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\`
- **macOS:** `/Applications/World of Warcraft/_classic_/Interface/AddOns/`

> If you only see `_retail_`, you have retail installed — make sure TBC/Wrath
> Classic is installed from the Battle.net launcher (it creates `_classic_`).

## 3. Copy the folder

Put the **`WarlockBuddy`** folder (the one that contains `WarlockBuddy.toc`)
directly inside `AddOns`. The final path should look like:

```
.../Interface/AddOns/WarlockBuddy/WarlockBuddy.toc
```

If you downloaded a ZIP from GitHub it may unzip as `WarlockBuddy-main` — rename
it to just `WarlockBuddy`, and make sure the `.toc` is at the top level (not
nested in a second folder).

## 4. Enable it

1. Launch the game.
2. At the character-select screen click **AddOns** (bottom-left) and make sure
   **WarlockBuddy** is checked, with **"Load out of date AddOns"** ticked just in
   case.
3. Log in on your warlock. You'll see `WarlockBuddy loaded.` in chat.

## 5. Arrange your frames

Type `/wb unlock`, drag the purple boxes wherever you want them, then `/wb lock`.
Open `/wb` any time to turn modules on/off.

## Troubleshooting

- **Nothing shows up:** you must be on a **warlock**. It's idle on other classes.
- **"out of date":** tick *Load out of date AddOns* at the character screen. The
  `.toc` `Interface` number may need bumping after a patch — see the API notes.
- **An error popped up:** copy the red text and open an issue on GitHub.
