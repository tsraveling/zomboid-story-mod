# Making a new quest

### Skald

1. Pick a short lowercase key (`junkie`, `march`).
2. Write `text/quests/<key>.ska` with a `# start` block routing on `get_quest("<key>")` per stage.
3. End the module with a `# back` block containing `GO cdc.ska -> router`.
4. In `text/cdc.ska`, add summary lines to `# summary` and an entry option to `# router`.
5. Run `./compile.sh`; it fails on any Skald parse or validation error.

### Quest wiring

1. Add `Q.available.<key> = function() ... end` to `CDCQuests.lua` (jump `codex:quest_available`).
2. In `CDCQuestStatus.lua`, add the key to `QS.order`, `QS.names`, `QS.lines` per stage, and `QS.completed[100]` (jump `quests:statuses`).
3. Add world content to `story.lua`, gating each entry with `cond = function(ctx) ... ctx.quest("<key>") ... end`.
4. Quest needs new items -> Adding quest items

CAVEAT: Never rename a quest or job key after release; existing saves keep the old key.

## Adding quest items

1. Add an `item X { ... }` block inside `module CDCLastHope` in `42/media/scripts/items_cdc.txt`.
2. Add `"CDCLastHope.X": "Display Name"` to `42/media/lua/shared/Translate/EN/ItemName.json`.
3. Set `Icon` to a vanilla icon, or drop a 32x32 PNG at `42/media/textures/Item_<Icon>.png`.
4. Set `WorldStaticModel` from `processes/pz-world-models.md`.
5. Add the full type to `CDC.story.items` so the debug spawn menu lists it.
6. Restart the game; scripts and textures do not hot-reload.
