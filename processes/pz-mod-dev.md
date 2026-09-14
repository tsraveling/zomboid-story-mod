# CDCLastHope Dev Loop

How to run and iterate on the mod locally in Project Zomboid Build 42. Mod source is `CDCLastHope/` in this repo, symlinked into the game's mods folder so edits are live on next lua reload.

1. Symlink once: `ln -sfn "$PWD/CDCLastHope" ~/Zomboid/mods/CDCLastHope`; B42 reads `CDCLastHope/42/mod.info`, the root `mod.info` is Workshop-only
2. In Steam, set Project Zomboid launch options to `-debug`
3. Launch game, Mods menu, enable "CDC Last Hope"
4. Pick a test mode
  - singleplayer -> Singleplayer
  - multiplayer -> Host MP
5. After editing lua, press F11 for the Lua debugger, open the "Lua Files" pane, select the changed file, click Reload; one file at a time
6. Edits to `items_cdc.txt`, `sandbox-options.txt`, translations, or textures need a full game restart
7. Read `~/Zomboid/console.txt` for `[CDCLastHope]` log lines and lua errors
8. Right-click world, CDC Debug, "Force active" to bypass the day-25 gate

## Singleplayer

1. New game, Sandbox, set CDC Last Hope page options (enable debug menu)
2. Debug menu, Items, spawn `Base.HamRadio1`, place it, add battery, turn on
3. CDC Debug, "Tune nearest ham radio to CDC"
4. Right-click radio, Transmit

## Host MP

1. Main menu, Host, Manage Settings, create or edit a preset
2. Mods tab, enable CDCLastHope; Sandbox tab, CDC Last Hope page, enable debug menu
3. Start server; a second client on LAN joins via the local IP shown in console
4. Second player is a different Steam account or a `-nosteam` launch with a different username

CAVEAT: Lua reload does not re-run `OnLoadRadioScripts` or `OnPreDistributionMerge`; radio channel and loot changes need a restart. Server lua on a dedicated host reloads only via restart.

# Adding Items and Art

Items are declared in `CDCLastHope/42/media/scripts/items_cdc.txt`. Inventory icon is a PNG; the dropped-on-floor look is a 3D model reference.

1. Add an `item X { ... }` block in the `module CDCLastHope` block, copy an existing one
2. Add `"ItemName_CDCLastHope.X": "Display Name"` to `42/media/lua/shared/Translate/EN/ItemName.json`
3. Icon: drop a 32x32 PNG at `42/media/textures/Item_<Icon>.png` and set `Icon = <Icon>`
4. World model: set `WorldStaticModel` to a vanilla name from `processes/pz-world-models.md`
5. Restart game (scripts are not hot-reloaded)

CAVEAT: Both `textures/Item_CDCPink.png` and `textures/CDCPink.png` are shipped because B42 vanilla dropped the `Item_` prefix but mod loading was not verified. Delete whichever one turns out unused. Custom 3D models need a `model` script block plus FBX/X mesh and texture under `42/media/models_X/`; not covered here.

# Research Items

Unverified behaviors with fallbacks already in code. Verify in-game and delete this section when done.

1. Pre-cue on dead stations: `CDCRadio.pushPrecue` calls `setAiringBroadcast` on every silent vanilla channel hourly after precue day; confirm lines appear on a dead radio and TV
  - works -> done
  - silent -> restrict to AEBS uuid `EMRG-711984` plus our own channel
2. Floating text: `CDCClient.lua` `CDC.Float.show` calls `IsoWaveSignal:AddDeviceText`; confirm bystanders see blue text above the radio
  - works -> done
  - nothing shown -> fallback `radio:Say` is already wired via pcall, check it fires
3. `ItemType = base:normal` and JSON translations are B42-native formats; confirm items load with names
4. `Sandbox.json` in mod translations: confirm the sandbox page shows labels not raw keys
