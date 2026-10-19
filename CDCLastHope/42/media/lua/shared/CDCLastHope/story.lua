--[[
  CDC Last Hope — world config. Conversations live in text/*.ska (compiled by compile.sh).

  Quick reference (full guide: processes/story-authoring.md):
    freq            kHz. Ham radios within CDC.FREQ_MARGIN of this can Transmit.
    precue          { day, text }  Day counted from the apocalypse date by calendar (default 1993-07-09, so 25 = Aug 3), not nights survived. Nothing works before it; dead vanilla stations carry `text`.
    apocalypse      optional { year, month, day } override of the Knox Event date.
    callout         { text }       Loops forever on `freq` once active, airs hourly. String or list of strings.
    world.pickups   { id, x,y,z | tiles={{x,y,z},...}, sprite=nil|name|{names}, label, item, once="global"|"character"|"none", duration=2, text, cond=fn(ctx,square), condFailText }  hidden when cond false unless condFailText (then grayed)
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
    text =
    "This is the CDC response team, calling from the vault in Atlanta. To any survivors, we are requesting assistance. Transmit on 104.2. We'll be listening.",
  },

  callout = {
    text = {
      "This is the CDC Knox Event Response Team.",
      "Transmit when ready. We are listening.",
    },
  },

  items = { "CDCLastHope.ZombieMeat", "CDCLastHope.VelvetDose", "CDCLastHope.ZombieBrain", "CDCLastHope.SoilSample", "Base.Mov_Microscope", "Base.Mov_DesktopComputer" },

  world = {
    pickups = {
      {
        id = "velvet_desk",
        label = "Retrieve Velvet Sample",
        tiles = { { 8074, 11723, 0 }, { 8075, 11723, 0 } },
        item = "CDCLastHope.VelvetDose",
        once = "none",
        cond = function(ctx)
          local q = ctx.quest("tri"); return q == 1 or q == 2
        end,
        text = "PLACEHOLDER: You find a dose of Velvet in the desk and bag it as a sample.",
      },
    },
    corpseActions = {
      {
        id = "meat",
        label = "Cut meat",
        requires = "tag:SHARP_KNIFE",
        requiresLabel = "a knife or other blade",
        consumes = false,
        gives = "CDCLastHope.ZombieMeat",
        duration = 3,
        cond = function(ctx) return ctx.quest("first") == 1 end,
        text =
        "Holding your breath, you cut through the zombie's waxy skin. The meat beneath has a sick, sweet smell to it that goes beyond normal blood, and you could swear it's still moving. You cut a sample, trying not to vomit."
      },
      {
        id = "brain_saw",
        label = "Saw brainpan",
        requires = { "tag:SAW", "tag:SMALL_SAW", "tag:CRUDE_SAW" },
        requiresLabel = "a saw",
        gives = "CDCLastHope.ZombieBrain",
        duration = 4,
        cond = function(ctx)
          local q = ctx.quest("tri"); return q == 1 or q == 2
        end,
        text =
        "Clenching your jaw and steeling your stomach, you begin sawing through the lifeless zombie's skull. After a moment, it separates with an oozing sound, revealing the brain. You take care not to touch it as you scoop a sample of brainmatter into a jar for later study."
      },
      {
        id = "brain_chop",
        label = "Chop brainpan",
        requires = "category:AXE",
        requiresLabel = "an axe",
        gives = "CDCLastHope.ZombieBrain",
        duration = 3,
        cond = function(ctx)
          local q = ctx.quest("tri"); return q == 1 or q == 2
        end,
        text =
        "You suppress the urge to vomit as you carefully lay into the zombie's skull with the axe, trying to crack open the skull. It's a long, messy process, but finally you expose the brain. Being careful not to touch it, you scoop it into a receptacle for later study."
      },
    },
    groundActions = {
      {
        id = "soil",
        label = "Dig soil sample",
        x = 11213,
        y = 12316,
        z = 0,
        radius = 20,
        requires = "tag:DIG_PLOW",
        requiresLabel = "a shovel or other digging tool",
        gives = "CDCLastHope.SoilSample",
        duration = 4,
        cond = function(ctx)
          local q = ctx.quest("tri"); return q == 1 or q == 2
        end,
        text =
        "The grass here is wilted and listless, a visible discoloration in the entire area. You lay aside a patch of sod to get to the soil underneath. The whole area has an unsettling, sickly-sweet odor. You try not to touch the soil as you store it in a container for later study."
      },
    },
    spawns = {
      { item = "CDCLastHope.VelvetDose", lists = { "PoliceEvidence" },        chance = 30 },
      { item = "CDCLastHope.VelvetDose", lists = { "PoliceDesk" },            chance = 35 },
      { item = "CDCLastHope.VelvetDose", lists = { "DrugShackDrugs" },        chance = 10 },
      { item = "CDCLastHope.VelvetDose", lists = { "DerelictHouseDrugs" },    chance = 10 },
      { item = "CDCLastHope.VelvetDose", lists = { "DerelictHouseSquatter" }, chance = 5 },
    },
  },
}
