# Authoring story.lua

All narrative lives in `CDCLastHope/42/media/lua/shared/CDCLastHope/story.lua`. The framework reads the `CDC.story` table; you never touch other lua. Inline lua functions are allowed anywhere a value is documented as `fn`.

1. Set `freq` (kHz) and `precue = { day, text }`; nothing in the mod works before `precue.day`
2. Set `callout.text` (string or list); loops forever on `freq` once active
3. Write `entry(ctx)` returning the first node id for every Transmit
4. Write nodes -> Nodes
5. Add effects to delivery choices -> Effects
6. Add `flagLabels` so the journal history reads well
7. Add `journal` entries: `{ cond = fn(ctx), text = string|fn }`
8. Place world content -> World Content
9. Reload lua in-game; watch console for `WARN` lines from the loader (missing nodes, duplicate ids)

## Nodes

1. `nodes.<id> = { text = string|fn(ctx), choices = { ... } }`
2. Choice: `{ text = string|fn, cond = fn(ctx), effects = { ... }, next = id|fn(ctx)|nil }`
3. `next = nil` hangs up; `cond` false hides the choice
4. Reserved ids: `noResponse` (entry returned nothing valid), `alreadyDone` (server rejected a strict flag set)
5. Node with zero visible choices shows an "End transmission" button

## Effects

1. `CDC.fx.setFlag(key, value)`: strict, rejected with `alreadyDone` if the flag exists; writes a delivery log entry
2. `CDC.fx.putFlag(key, value)`: overwrite silently, no log entry
3. `CDC.fx.clearFlag(key)`
4. `CDC.fx.xp("Electricity", 50)`: granted to every player within RewardRadius of the radio
5. `CDC.fx.fn(function(ctx) end)`: runs on the caller's client after the server accepts

## World Content

1. Pickup: `{ id, x, y, z, sprite, label, item, once, deliveredFlag, duration, text, cond = fn(ctx, square), condFailText, goneText }`
2. `once`: `"global"` (default, one per world), `"character"`, `"untilDelivered"` (needs `deliveredFlag`), `"none"`
3. Corpse action: `{ id, label, requires = fullType, consumes = bool, gives, duration, text }`
4. Spawn: `{ item, lists = { ... }, chance }` with list names from `processes/pz-distribution-lists.md`
5. Site: `{ x, y, r, name, requires = { items = { ["Base.Wire"] = 2 }, perk = "Electricity", level = 2 }, duration, text }`
6. Find coordinates in-game: debug mode shows x,y,z bottom-left; or right-click, Tile Report

## ctx Reference

1. Fields: `player`, `radio`, `day`, `name`, `username`, `isNewCharacter`, `atSite`, `uplinked`
2. `has(flag)`, `get(flag)`, `hasItem(fullType | list | fn(item))`, `countItem(fullType)`, `perkLevel("Doctor")`
3. `lastDelivery(flag)` returns `{ characterName, username, day, hours, x, y }` or nil; `daysSince(entry)`

CAVEAT: Flag keys are strings; values can be anything but booleans are the convention. Never rename a flag after release, saves keep the old key. Quest items are never consumed by the framework; if a story needs that, use `CDC.fx.fn`.
