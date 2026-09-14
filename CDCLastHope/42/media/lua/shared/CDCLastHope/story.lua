--[[
  CDC Last Hope — story file. Everything the author controls lives here.

  Quick reference (full guide: processes/ howto in repo):
    freq            kHz. Ham radios within CDC.FREQ_MARGIN of this can Transmit.
    precue          { day, text }  Day counted from the apocalypse date by calendar (default 1993-07-09, so 25 = Aug 3), not nights survived. Nothing works before it; dead vanilla stations carry `text`.
    apocalypse      optional { year, month, day } override of the Knox Event date.
    callout         { text }       Loops forever on `freq` once active, airs hourly. String or list of strings.
    sites           { {x,y,r,name,requires={items={["Base.Wire"]=2}, perk="Electricity", level=2}} }
    entry(ctx)      Returns first node id for every Transmit. "noResponse" and "alreadyDone" are reserved nodes.
    nodes[id]       { text = string|fn(ctx), choices = { { text, cond=fn(ctx), effects={...}, next=id|fn(ctx)|nil } } }
                    nil next = hang up. Choices with failing cond are hidden.
    effects         CDC.fx.setFlag(k,v) strict (rejected if set -> alreadyDone), putFlag, clearFlag, xp("Perk", n), fn(f)
    flagLabels      { flag = "Human label" } used in journal history.
    journal         { { cond=fn(ctx), text=string|fn } } shown in CDC journal tab.
    world.pickups   { id, x,y,z, sprite=nil, label, item, once="global"|"character"|"untilDelivered"|"none", deliveredFlag, duration=2, text, cond=fn(ctx,square), condFailText }
    world.corpseActions { id, label, requires=fullType|nil, consumes=false, gives, duration=3, text }
    world.spawns    { item, lists={"ClassroomDesk"}, chance=5 }
    items           optional extra item list for debug spawn menu

  ctx: player, radio, day, name, username, isNewCharacter, atSite, uplinked,
       has(flag), get(flag), hasItem(type|list|fn), countItem(type), lastDelivery(flag), daysSince(entry), perkLevel(name)
]]

require "CDCLastHope/CDC"

local fx = CDC.fx

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

    sites = {
        { x = 10000, y = 10000, r = 30, name = "PLACEHOLDER relay tower",
          requires = { items = { ["Base.Wire"] = 2 }, perk = "Electricity", level = 2 } },
    },

    items = { "CDCLastHope.ScientistLaptop", "CDCLastHope.ThumbDrive", "CDCLastHope.TissueSample", "CDCLastHope.Microscope" },

    flagLabels = {
        gotLaptop = "PLACEHOLDER Scientist's laptop",
        gotSample = "PLACEHOLDER Tissue sample analysis",
    },

    entry = function(ctx)
        if ctx.isNewCharacter then return "intro" end
        return "hub"
    end,

    nodes = {
        noResponse = {
            text = "NO RESPONSE PLACEHOLDER TEXT",
        },

        alreadyDone = {
            text = function(ctx)
                return "PLACEHOLDER: Someone already got that to us. Check the log."
            end,
            choices = {
                { text = "PLACEHOLDER: Understood.", next = "hub" },
            },
        },

        intro = {
            text = "PLACEHOLDER INTRO: This is the CDC Knox Event Response Team. We didn't think anyone was left out there. Who is this?",
            choices = {
                { text = "PLACEHOLDER: A survivor. What do you need?", next = "hub" },
                { text = "PLACEHOLDER: Nobody. (hang up)", next = nil },
            },
        },

        hub = {
            text = function(ctx)
                if ctx.has("gotSample") then
                    return "PLACEHOLDER: You've done everything we asked. Stand by."
                elseif ctx.has("gotLaptop") then
                    local d = ctx.lastDelivery("gotLaptop")
                    return "PLACEHOLDER: " .. d.characterName .. " got us the laptop about " .. ctx.daysSince(d) .. " days ago. Now we need a tissue sample analyzed from an uplink site."
                end
                return "PLACEHOLDER: We need the scientist's laptop from the lab. Do you have it?"
            end,
            choices = {
                { text = "PLACEHOLDER: I have the laptop.",
                  cond = function(ctx) return not ctx.has("gotLaptop") and ctx.hasItem("CDCLastHope.ScientistLaptop") end,
                  effects = { fx.setFlag("gotLaptop"), fx.xp("Electricity", 50) },
                  next = "q1_done" },
                { text = "PLACEHOLDER: I have the sample and I'm at an uplink.",
                  cond = function(ctx) return ctx.has("gotLaptop") and not ctx.has("gotSample") and ctx.uplinked and ctx.hasItem("CDCLastHope.TissueSample") end,
                  effects = { fx.setFlag("gotSample"), fx.xp("Doctor", 50) },
                  next = "q2_done" },
                { text = "PLACEHOLDER: I have the sample but no uplink.",
                  cond = function(ctx) return ctx.has("gotLaptop") and not ctx.has("gotSample") and not ctx.uplinked and ctx.hasItem("CDCLastHope.TissueSample") end,
                  next = "needUplink" },
                { text = "PLACEHOLDER: Not yet. I'll go look.", next = nil },
            },
        },

        needUplink = {
            text = "PLACEHOLDER: This radio can't carry the data. Wire a ham radio into the relay tower and call from there.",
            choices = { { text = "PLACEHOLDER: On it.", next = nil } },
        },

        q1_done = {
            text = "PLACEHOLDER: Receiving... got it. That's the laptop. Thank you. Call back when you can.",
            choices = { { text = "PLACEHOLDER: Will do.", next = nil } },
        },

        q2_done = {
            text = "PLACEHOLDER: Upload complete. This changes everything. Stand by for further instructions.",
            choices = { { text = "PLACEHOLDER: Standing by.", next = nil } },
        },
    },

    journal = {
        { cond = function(ctx) return not ctx.has("gotLaptop") end,
          text = "PLACEHOLDER: Find the scientist's laptop and Transmit to the CDC on 104.2." },
        { cond = function(ctx) return ctx.has("gotLaptop") and not ctx.has("gotSample") end,
          text = "PLACEHOLDER: Take a tissue sample from a zombie corpse. Deliver from an uplinked ham radio." },
    },

    world = {
        pickups = {
            { id = "labLaptop", x = 10010, y = 10010, z = 0, sprite = nil,
              label = "PLACEHOLDER Take laptop", item = "CDCLastHope.ScientistLaptop",
              once = "untilDelivered", deliveredFlag = "gotLaptop", duration = 2,
              text = "PLACEHOLDER: You pull the laptop out of the dusty desk drawer.",
              cond = function(ctx, square) return square:haveElectricity() end,
              condFailText = "PLACEHOLDER: The desk terminal is dead. No power." },
        },
        corpseActions = {
            { id = "sample", label = "PLACEHOLDER Take tissue sample", requires = "Base.HuntingKnife", consumes = false,
              gives = "CDCLastHope.TissueSample", duration = 3,
              text = "PLACEHOLDER: You cut a sample free and bag it." },
        },
        spawns = {
            { item = "CDCLastHope.Microscope", lists = { "ClassroomDesk", "MedicalStorageTools" }, chance = 5 },
        },
    },
}
