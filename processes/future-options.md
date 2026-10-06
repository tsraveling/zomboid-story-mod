# Future Options

Framework features discussed but not built. Each has verified vanilla API behind it. Promote to a `_spec/` section when wanted.

# Placed Vehicle Wrecks

Spawn a specific wreck at exact coords with quest items inside. Vanilla does the same for unique profession vans in `lua/server/Vehicles/ProfessionVehicles.lua`. Result is a real car object, so players loot the trunk normally.

1. Add `world.vehicles` to story.lua: `{ id, x, y, z, script, direction, condition, rust, items = { TruckBed = {"CDCLastHope.ThumbDrive"} }, once }`
2. Server file `CDCVehicles.lua` hooks `Events.LoadGridsquare`
3. On the target square loading, skip if world state `vehicles[id]` is set
4. Call `addVehicleDebug(script, direction, nil, square)` and set `vehicles[id]`
5. Dress it: `vehicle:setCondition(n)`, `setRust(f)`, `setBloodIntensity(part, f)`, `setColor(r,g,b)`
6. Fill containers: `vehicle:getPartById("TruckBed"):getItemContainer():AddItem(fullType)`; glovebox part id is `GloveBox`
7. Tag it: `vehicle:getModData().CDCWreck = id` for later identification
8. Optional custom right-click -> Wreck Right-Click

## Wreck Right-Click

Adds a "Search wreck" style action with once modes and flavor text, same shape as desk pickups.

1. Wrap the global `ISVehicleMenu.FillMenuOutsideVehicle(player, context, vehicle, test)` like `CDCJournal.lua` wraps `createChildren`
2. Inside, read `vehicle:getModData().CDCWreck`; if set, look up the story def
3. Reuse `CDC.Pickup` flow keyed on the vehicle id instead of square coords

CAVEAT: Pre-wrecked vanilla scripts live in `scripts/generated/vehicles/burntAndSmashedVehicles/`, e.g. `Base.CarNormalBurnt`, `Base.CarNormalSmashedFront`, `Base.AmbulanceBurnt`, `Base.CarLuxurySmashedRear`. Burnt variants may have no trunk part; smashed variants keep parts. Verify per script. Spawn is server-side and syncs to MP clients automatically. On an existing save the spawn waits until the chunk unloads and reloads. Pick a spot off vanilla parking zones to avoid overlap.

# Skald as Story Front-End

PZ's Lua is Kahlua, a Java-hosted VM with no C FFI, so `libskald` can never run inside the game. Skald can still author the story if it compiles ahead of time to a Lua table the mod interprets. Skald currently has no JSON or Lua emitter in its core (JSON is LSP-only), so that comes first.

1. Add an emitter to `skalder`: `.ska` plus `.codex` to a pre-parsed Lua AST (`story_compiled.lua`); resolve relative transitions and parse conditionals and insertions at compile time
2. Write `CDCSkaldRuntime.lua` in the mod: tree-walker over blocks, beats, choices, `@if`, operations, `{var}` insertions, `GO`/`END`
3. Map Skald methods to `ctx`: `:hasItem("CDCLastHope.X")`, `:has("flag")`, `:uplinked()`; register them in the codex
4. Map codex globals to world flags: reads from `CDC.State`, writes become strict `setFlag` commits so `alreadyDone` still works
5. Ad hoc variables stay per-call, client-side, discarded on hang up
6. Present beats one at a time in the transmission log with a Continue button, choices when the beat has them; attribution tag picks the speaker color
7. Keep `story.lua` `entry(ctx)` and `world.*` as-is; Skald replaces only `nodes`

CAVEAT: Runtime is roughly 500 to 800 lines of Lua if the compiler pre-parses expressions; several times that if the mod parses Skald text itself. The Event Thread query model maps cleanly since every `ctx` method is synchronous here. Do this after the framework is stable and Skald has a tested emitter, not before.

# Quest Target Zombies

Spawn a specific zombie carrying quest items, either when a player enters a zone or when a player digs a specific grave. Vanilla precedent is the tutorial (`lua/client/Tutorial/Steps.lua`, `FightStep`): `addZombiesInOutfit(x, y, z, 1, outfit, femaleChance):get(0)`, then `zombie:getInventory():AddItem(...)`, `zombie:setAttachedItem("Knife in Back", item)`, and `Events.OnZombieDead` to notice the kill. Item drops into the corpse inventory on death, so looting works with no extra code.

1. Add `world.targets` to story.lua: `{ id, x, y, z, trigger = "zone"|"grave", r, outfit, items = {...}, attached = { ["Knife in Back"] = "Base.HuntingKnife" }, crawler, fakeDead, requires, label, text, respawnHours }`
2. Server spawns via `addZombiesInOutfit`, tags `zombie:getModData().CDCTarget = id`, fills inventory, records `targets[id] = { spawned = day }` in world state
3. Server hooks `Events.OnZombieDead`; if `getModData().CDCTarget` is set, record `targets[id].killed` and who
4. Zone trigger -> Zone Entry
5. Grave trigger -> Grave Dig
6. Debug menu: "Spawn target" and "Reset target" entries

## Zone Entry

1. Client `Events.OnPlayerUpdate` throttled to once per second; check distance to each zone target not yet spawned
2. On entry send `spawnTarget { id }`; server validates flag and spawns at the target coords, not at the player
3. Skip if `targets[id].spawned` and not `killed`, unless `respawnHours` has passed since spawn (zombie was culled or wandered)

## Grave Dig

1. Reuse the pickup flow: option appears on the exact square, label "Exhume", `requires` a shovel via `ItemTag.DIG_GRAVE` like vanilla `DiggingUtil`
2. Timed action with the dig animation, then `spawnTarget { id }`
3. Spawn with `crawler = true` or `fakeDead = true` on the grave square so it rises out; `addZombiesInOutfit` exposes both flags plus knockedDown and health
4. Flavor text through the existing modal

CAVEAT: Zombies are not durable world objects. Vanilla culls or migrates them when chunks unload, so a target that is spawned and not killed may vanish with its items. `respawnHours` covers that; the story should also allow a second copy. Corpses persist with the chunk, so once killed the item is safe until looted or the corpse decays. `OnZombieDead` fires client-side on the killer and server-side in MP; commit the kill from the server path. Empty grave sprites are `location_community_cemetary_01_32` through `_35`; headstone tiles are separate sprites and should be matched by coordinates, not sprite name.
