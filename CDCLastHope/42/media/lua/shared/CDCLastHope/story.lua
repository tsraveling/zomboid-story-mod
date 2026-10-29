--[[
  CDC Last Hope — world config. Conversations live in text/*.ska (compiled by compile.sh).

  Quick reference (full guide: processes/story-authoring.md):
    freq            kHz. Ham radios within CDC.FREQ_MARGIN of this can Transmit.
    precue          { day, text }  Day counted from the apocalypse date by calendar (default 1993-07-09, so 25 = Aug 3), not nights survived. Nothing works before it; dead vanilla stations carry `text`.
    apocalypse      optional { year, month, day } override of the Knox Event date.
    callout         { text }       Loops forever on `freq` once active, airs hourly. String or list of strings.
    world.pickups   { id, x,y,z | tiles={{x,y,z},...}, sprite=nil|name|{names}, label, item, once="global"|"character"|"none", duration=2, text, cond=fn(ctx,square), condFailText }  hidden when cond false unless condFailText (then grayed)
    world.corpseActions { id, label, corpse=nil|"od", requires=fullType|"tag:ITEM_TAG"|"category:WEAPON_CATEGORY"|list|nil, requiresLabel, consumes=false, gives, duration=3, text, cond=fn(ctx) }  hidden when cond false; corpse must match the body's CDCCorpse flag, nil for ordinary zombies
    world.groundActions { id, label, x,y,z, radius, ground={"dirt","sand","clay","gravel"}, requires, requiresLabel, consumes=false, gives, duration=3, text, cond=fn(ctx,square) }  natural ground within radius; hidden when cond false
    world.lockers   { id, tiles={{x,y,z},...}, label="Check locker", kind=nil|"zombie"|"corpse", duration=2, text, emptyText }  always offered; a kind fires once then reads empty forever. zombie: outfit, female, skin=0..4, gives={{item,condition,ammo}} in its inventory, drops={{...}} on the floor beside it (weapons will not stay in a zombie). corpse: at={x,y,z}, corpse="od", outfit, skin, wears={{item,tint={r,g,b}}}
    world.placements { id, x,y,z, item, container="desk" }  Dropped into that container once, the first time the chunk streams in near a player. container omitted = first container on the square.
    world.readables { id, item, label="Read", text }  Read option on the item in inventory; shows text in a modal instead of the vanilla reading action
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

  items = { "CDCLastHope.ZombieMeat", "CDCLastHope.VelvetDose", "CDCLastHope.ZombieBrain", "CDCLastHope.SoilSample", "CDCLastHope.ODVictimMeat", "CDCLastHope.ODVictimBrain", "CDCLastHope.MedicalExaminerNotes", "Base.Mov_Microscope", "Base.Mov_DesktopComputer" },

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
        text =
        "You rummage through the desk until you find the leather case full of contraband. Dozens of tiny glass vials, the contents and unsettling deep purple. You pocket one of these.",
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
      {
        id = "od_muscle",
        corpse = "od",
        label = "Muscle sample",
        requires = "tag:SHARP_KNIFE",
        requiresLabel = "a knife or other blade",
        consumes = false,
        gives = "CDCLastHope.ODVictimMeat",
        duration = 3,
        cond = function(ctx)
          local q = ctx.quest("junkie"); return q >= 1 and q < 100
        end,
        text =
        "Despite the similarities in the unnaturally preserved dead flesh to that of the living dead outside, it still feels like you're cutting into an actual person. You try to do it as quickly and respectfully as possible.",
      },
      {
        id = "od_brain_saw",
        corpse = "od",
        label = "Saw brainpan",
        requires = { "tag:SAW", "tag:SMALL_SAW", "tag:CRUDE_SAW" },
        requiresLabel = "a saw",
        gives = "CDCLastHope.ODVictimBrain",
        duration = 4,
        cond = function(ctx)
          local q = ctx.quest("junkie"); return q >= 1 and q < 100
        end,
        text =
        "Saying a silent apology to the poor soul lying before you, you clench your jaw and place the saw against his temple, and begin to work. The brainpan opens with a wet sucking sound, and you carefully take a sample.",
      },
      {
        id = "od_brain_chop",
        corpse = "od",
        label = "Chop brainpan",
        requires = "category:AXE",
        requiresLabel = "an axe",
        gives = "CDCLastHope.ODVictimBrain",
        duration = 3,
        cond = function(ctx)
          local q = ctx.quest("junkie"); return q >= 1 and q < 100
        end,
        text =
        "There is no respectful way to open someone's head with an axe, so you place the blade against their temple and say a quick apology.\n\nThe skull cracks after a few precise blows, and you carefully take a sample of the gray brain matter that lies underneath.",
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
    lockers = {
      {
        id = "morgue_trap",
        tiles = { { 10631, 10409, -1 } },
        kind = "zombie",
        outfit = "ArmyCamoGreen",
        female = true,
        skin = 4,
        drops = {
          { item = "Base.AssaultRifle", condition = 8 },
        },
        gives = {
          { item = "Base.556Clip", ammo = 30 },
          { item = "Base.556Clip", ammo = 11 },
        },
      },
      {
        id = "morgue_empty_n",
        tiles = { { 10631, 10410, -1 }, { 10631, 10411, -1 } },
      },
      {
        id = "morgue_junkie",
        tiles = { { 10634, 10402, -1 } },
        kind = "corpse",
        at = { 10633, 10403, -1 },
        corpse = "od",
        text =
        "The locker table slides out smoothly a foot or so, then jams. This police station wasn't in the best shape before the apocalypse; now, like the rest of the world, it's going to seed.\n\nYou carefully lift out the dead body inside, bracing for the smell of decay ... but there's nothing. The young man is unnaturally preserved, and not *quite* motionless in death. You have to double check his pulse to convince yourself, finally, that he's not just sleeping.",
        outfit = "Generic01",
        female = false,
        skin = 0,
        wears = {
          { item = "Base.Tshirt_WhiteTINT", tint = { 0.85, 0.75, 0.25 } },
        },
      },
      {
        id = "morgue_empty_s",
        tiles = { { 10635, 10402, -1 }, { 10636, 10402, -1 }, { 10637, 10402, -1 }, { 10638, 10402, -1 } },
      },
    },
    placements = {
      {
        id = "me_notes",
        x = 10645,
        y = 10410,
        z = -1,
        container = "desk",
        item = "CDCLastHope.MedicalExaminerNotes",
      },
    },
    readables = {
      {
        id = "me_notes",
        item = "CDCLastHope.MedicalExaminerNotes",
        text =
            "The majority of this notebook is from Before. Autopsies, musings, even a suspicious death. But the last few pages before it goes blank and smeared with blood are about the overdose victim. How they were pronounced dead on scene by the EMTs. How their heart was stopped and their lungs were collapsed.\n\n" ..
            "But how, despite this, their eyelids quivered as if the corpse was dreaming, and its fingers twitched.\n\n" ..
            "There follows an in-depth medical analysis of this that the CDC will surely be able to make use of.",
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
