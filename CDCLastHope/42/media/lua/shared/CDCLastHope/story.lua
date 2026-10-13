--[[
  CDC Last Hope — world config. Conversations live in text/*.ska (compiled by compile.sh).

  Quick reference (full guide: processes/story-authoring.md):
    freq            kHz. Ham radios within CDC.FREQ_MARGIN of this can Transmit.
    precue          { day, text }  Day counted from the apocalypse date by calendar (default 1993-07-09, so 25 = Aug 3), not nights survived. Nothing works before it; dead vanilla stations carry `text`.
    apocalypse      optional { year, month, day } override of the Knox Event date.
    callout         { text }       Loops forever on `freq` once active, airs hourly. String or list of strings.
    world.pickups   { id, x,y,z, sprite=nil, label, item, once="global"|"character"|"none", duration=2, text, cond=fn(ctx,square), condFailText }
    world.corpseActions { id, label, requires=fullType|"tag:ITEM_TAG"|"category:WEAPON_CATEGORY"|list|nil, requiresLabel, consumes=false, gives, duration=3, text, cond=fn(ctx) }  hidden when cond false
    world.groundActions { id, label, x,y,z, radius, ground={"dirt","sand","clay","gravel"}, requires, requiresLabel, consumes=false, gives, duration=3, text, cond=fn(ctx,square) }  natural ground within radius; hidden when cond false
    world.spawns    { item, lists={"ClassroomDesk"}, chance=5 }
    items           optional extra item list for debug spawn menu

  ctx: player, radio, day, name, username, quest(key), jobDone(key), hasItem(type|list|fn), countItem(type), perkLevel(name)
]]

require "CDCLastHope/CDC"

CDC.story = {
    freq = 104200,

    precue = {
        day = 25,
        text = "PLACEHOLDER PRECUE: CDC requesting urgent assistance from any survivors in the Knox Event Zone. Transmit on 104.2. We'll be listening.",
    },

    callout = {
        text = {
            "PLACEHOLDER CALLOUT: This is the CDC Knox Event Response Team.",
            "Transmit when ready. We are listening.",
        },
    },

    items = { "CDCLastHope.ZombieMeat", "CDCLastHope.VelvetDose", "CDCLastHope.ZombieBrain", "CDCLastHope.SoilSample", "Base.Mov_Microscope", "Base.Mov_DesktopComputer" },

    world = {
        pickups = {},
        corpseActions = {
            { id = "meat", label = "Cut meat", requires = "tag:SHARP_KNIFE", requiresLabel = "a knife or other blade", consumes = false,
              gives = "CDCLastHope.ZombieMeat", duration = 3,
              cond = function(ctx) return ctx.quest("first") == 1 end,
              text = "PLACEHOLDER: You carve off a chunk of meat." },
            { id = "brain_saw", label = "Saw brainpan", requires = { "tag:SAW", "tag:SMALL_SAW", "tag:CRUDE_SAW" }, requiresLabel = "a saw",
              gives = "CDCLastHope.ZombieBrain", duration = 4,
              cond = function(ctx) return ctx.quest("tri") == 1 end,
              text = "PLACEHOLDER: You saw through the skull and lift out the brain." },
            { id = "brain_chop", label = "Chop brainpan", requires = "category:AXE", requiresLabel = "an axe",
              gives = "CDCLastHope.ZombieBrain", duration = 3,
              cond = function(ctx) return ctx.quest("tri") == 1 end,
              text = "PLACEHOLDER: You split the skull open and pry out the brain." },
        },
        groundActions = {
            { id = "soil", label = "Dig soil sample", x = 11213, y = 12316, z = 0, radius = 20,
              requires = "tag:DIG_PLOW", requiresLabel = "a shovel or other digging tool",
              gives = "CDCLastHope.SoilSample", duration = 4,
              cond = function(ctx) return ctx.quest("tri") == 1 end,
              text = "PLACEHOLDER: You dig up a sample of the soil." },
        },
        spawns = {
            { item = "CDCLastHope.VelvetDose", lists = { "PoliceEvidence" }, chance = 30 },
            { item = "CDCLastHope.VelvetDose", lists = { "DrugShackDrugs" }, chance = 10 },
            { item = "CDCLastHope.VelvetDose", lists = { "DerelictHouseDrugs" }, chance = 10 },
            { item = "CDCLastHope.VelvetDose", lists = { "DerelictHouseSquatter" }, chance = 5 },
        },
    },
}
