--[[
  CDC Last Hope — world config. Conversations live in text/*.ska (compiled by compile.sh).

  Quick reference (full guide: processes/story-authoring.md):
    freq            kHz. Ham radios within CDC.FREQ_MARGIN of this can Transmit.
    precue          { day, text }  Day counted from the apocalypse date by calendar (default 1993-07-09, so 25 = Aug 3), not nights survived. Nothing works before it; dead vanilla stations carry `text`.
    apocalypse      optional { year, month, day } override of the Knox Event date.
    callout         { text }       Loops forever on `freq` once active, airs hourly. String or list of strings.
    world.pickups   { id, x,y,z, sprite=nil, label, item, once="global"|"character"|"none", duration=2, text, cond=fn(ctx,square), condFailText }
    world.corpseActions { id, label, requires=fullType|nil, consumes=false, gives, duration=3, text, cond=fn(ctx) }  hidden when cond false
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

    items = { "CDCLastHope.ZombieMeat", "Base.Mov_Microscope", "Base.Mov_DesktopComputer" },

    world = {
        pickups = {},
        corpseActions = {
            { id = "meat", label = "Cut meat", requires = "Base.HuntingKnife", consumes = false,
              gives = "CDCLastHope.ZombieMeat", duration = 3,
              cond = function(ctx) return ctx.quest("first") == 1 end,
              text = "PLACEHOLDER: You carve off a chunk of meat." },
        },
        spawns = {},
    },
}
