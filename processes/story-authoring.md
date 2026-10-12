# Authoring the story

Conversations are Skald modules in `text/`. World config (frequency, precue, callout, pickups, corpse actions, spawns) lives in `CDCLastHope/42/media/lua/shared/CDCLastHope/story.lua`. Quest journal lines and quest availability are small Lua tables next to it.

1. Write or edit `.ska` files in `text/`; methods available to scripts are declared in `text/cdc.codex`
2. Run `./compile.sh` from the repo root; it fails on any Skald parse or validation error
3. Reload lua in-game (or restart); watch the console for `skald warn` / `skald error` lines
4. Add journal lines for new quest stages -> Quest Status
5. Add an availability rule for new quests -> Quest Availability
6. Place world content in `story.lua` -> World Content

## Conversations

1. Every Transmit loads `cdc.ska` and starts at its first block; nothing carries over between calls except quest/job/character state
2. `cdc:` lines float above the radio in purple, `radio:` lines in gray, any other speaker in white prefixed with its name; unattributed lines are narration and only appear in the dialogue box
3. Player choices float above the player in cyan; options whose `(? ...)` condition fails are shown grayed out
4. Each line waits for Continue; `EXIT` (or running off the end) shows End transmission
5. A block that falls through into the next block keeps going; end conversations with `EXIT` explicitly

## Codex Methods

1. Quests: `get_quest(key)`, `check_quest(key, stage)`, `set_quest(key, stage)`, `quest_available(key)`; stage 0 = not started, 1 = started, 10 = done
2. Jobs: `do_job(key, hours)`, `has_started_job(key)`, `check_job_done(key)` -> Jobs
3. Player: `check_skill("Doctor", 2)`, `has_item("ZombieMeat")` (unqualified names try `CDCLastHope.` then `Base.`), `pc_first_name()`, `pc_last_name()`, `pc_full_name()`
4. Radio surroundings: `radio_has_microscope()` (placed vanilla microscope within 3 tiles), `radio_has_computer()` (placed desktop computer within 3 tiles on a powered square), `at_tower()` (within 25 tiles of an entry in `CDC.TOWERS`; none defined yet)
5. Rewards: `reward_xp("Doctor", 50.0)` grants to every player within the sandbox RewardRadius (default 20) of the radio
6. CDC memory: `met_anyone()`, `has_met()`, `is_returning()`, `did_think_dead()`, `mem_first_name()` / `mem_last_name()` / `mem_full_name()`, `do_meet()`, `update_meet()`, `set_thought_dead()`

## Jobs

1. `do_job(key, hours)` registers the job on first call; later calls ignore `hours`
2. The player stays at the radio while game time passes; single player speeds the game up for the duration
3. The job breaks if the radio loses power or is turned off, a visible zombie comes within 10 tiles, the player moves or gets hurt, or the dialogue window is closed
4. A broken job keeps its progress and ends the conversation; route returning players with `has_started_job(key)` and call `do_job` again to resume
5. A finished job continues instantly

## Quest Status

1. `CDCLastHope/42/media/lua/shared/CDCLastHope/CDCQuestStatus.lua`: `QS.lines[questKey][stage] = "journal line"`
2. Add the quest key to `QS.order`; stages without a line show nothing

## Quest Availability

1. `CDCLastHope/42/media/lua/shared/CDCLastHope/CDCQuests.lua`: `Q.available[questKey] = function(st) ... end`
2. Read state with `CDC.State.quest(st, key)` and `CDC.State.jobDone(st, key)`; unknown keys are unavailable

## World Content

1. Pickup: `{ id, x, y, z, sprite, label, item, once, duration, text, cond = fn(ctx, square), condFailText, goneText }`
2. `once`: `"global"` (default, one per world), `"character"`, `"none"`
3. Corpse action: `{ id, label, requires = fullType, consumes = bool, gives, duration, text, cond = fn(ctx) }`; hidden when `cond` returns false
4. Spawn: `{ item, lists = { ... }, chance }` with list names from `processes/pz-distribution-lists.md`
5. Find coordinates in-game: debug mode shows x,y,z bottom-left; or right-click, Tile Report

## ctx Reference

1. Fields: `player`, `radio`, `day`, `name`, `username`
2. `quest(key)`, `jobDone(key)`, `hasItem(fullType | list | fn(item))`, `countItem(fullType)`, `perkLevel("Doctor")`

## Debug Menu

Enable the sandbox Debug Menu option (or run with `-debug`), then right-click the world: CDC Debug has set quest stage, reset or complete jobs, clear the met and dead lists, jump to a start tag (`router` or `quests/first.ska:job`) at the nearest ham radio, plus force active, advance time, dump state, tune radio, spawn item, reset pickup and reset world.

CAVEAT: Never rename a quest or job key after release; saves keep the old key. Quest items are never consumed by the framework.
