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
