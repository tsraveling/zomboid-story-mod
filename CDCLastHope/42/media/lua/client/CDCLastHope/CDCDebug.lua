if isServer() then return end
require "ISUI/ISTextBox"
require "CDCLastHope/CDCClient"
require "CDCLastHope/CDCDialogue"

CDC.Debug = {}
local Dbg = CDC.Debug

local function dump(v, indent, out)
    indent = indent or ""
    if type(v) ~= "table" then table.insert(out, indent .. tostring(v)); return end
    for k, val in pairs(v) do
        if type(val) == "table" then
            table.insert(out, indent .. tostring(k) .. ":")
            dump(val, indent .. "  ", out)
        else
            table.insert(out, indent .. tostring(k) .. " = " .. tostring(val))
        end
    end
end

function Dbg.send(player, args)
    CDC.Net.send(player, "debug", args)
end

-- one-line text prompt; onText(text) on OK
function Dbg.prompt(player, title, onText)
    local pn = player:getPlayerNum()
    local box = ISTextBox:new(0, 0, 300, 160, title, "", nil, function(target, button)
        if button.internal ~= "OK" then return end
        onText(button.parent.entry:getText() or "")
    end, pn)
    box:initialise()
    box:addToUIManager()
    box:setX((getPlayerScreenWidth(pn) - 300) / 2)
    box:setY((getPlayerScreenHeight(pn) - 160) / 2)
end

function Dbg.promptQuest(player)
    Dbg.prompt(player, "Set quest stage (key=stage)", function(s)
        local k, v = s:match("^%s*([^=%s]+)%s*=%s*(%d+)%s*$")
        if not k then player:Say("Expected key=stage"); return end
        CDC.Client.applyOps(player, { { type = "quest", key = k, stage = tonumber(v) } })
    end)
end

function Dbg.promptJump(player)
    Dbg.prompt(player, "Start at (tag or module.ska:tag)", function(s)
        s = s:gsub("^%s+", ""):gsub("%s+$", "")
        if s == "" then return end
        local radio = Dbg.nearestHam(player)
        if not radio then player:Say("No ham radio nearby"); return end
        CDC.Dialogue.open(player, radio, false, s)
    end)
end

function Dbg.nearestHam(player)
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local best, bestD = nil, 99
    for dx = -6, 6 do
        for dy = -6, 6 do
            local sq = getCell():getGridSquare(px + dx, py + dy, pz)
            if sq then
                for i = 0, sq:getObjects():size() - 1 do
                    local o = sq:getObjects():get(i)
                    if CDC.isHamRadio(o) then
                        local d = CDC.dist(px, py, px + dx, py + dy)
                        if d < bestD then best, bestD = o, d end
                    end
                end
            end
        end
    end
    return best
end

function Dbg.tune(player)
    local radio = Dbg.nearestHam(player)
    if not radio then player:Say("No ham radio nearby"); return end
    local dd = radio:getDeviceData()
    local ok = pcall(function() dd:setChannel(CDC.story.freq, true) end)
    if not ok then dd:setChannel(CDC.story.freq) end
    player:Say("Tuned to " .. tostring(CDC.story.freq / 1000))
end

-- SP only; in MP the server owns game time.
-- Moves the calendar (our gate), nights survived (vanilla radio clock), and fast-forwards radio scripts
-- the same way vanilla does for a late sandbox start (ZomboidRadio.Init -> simulateScriptsUntil).
function Dbg.advanceDays(player, n)
    local gt = getGameTime()
    local y, m, d = CDC.civilFromDays(CDC.calendarDays() + n)
    gt:setYear(y)
    gt:setMonth(m - 1)
    gt:setDay(d - 1)
    local nights = gt:getNightsSurvived() + n
    gt:setNightsSurvived(nights)
    local ok, err = pcall(function()
        local stamp
        if RadioAPI and RadioAPI.timeToTimeStamp then
            stamp = RadioAPI.timeToTimeStamp(nights, gt:getHour(), 0)
        else
            stamp = nights * 1440 + gt:getHour() * 60
        end
        getZomboidRadio():getScriptManager():simulateScriptsUntil(stamp, false)
    end)
    if not ok then CDC.log("radio fast-forward failed: " .. tostring(err)) end
    player:Say(string.format("%04d-%02d-%02d, apocalypse day %d, night %d", y, m, d, CDC.day(), nights))
end

function Dbg.fill(player, context, squares)
    if not CDC.isDebug() then return end
    local st = CDC.State.get()
    local root = context:addOption("CDC Debug")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)

    menu:addOption("Force active: " .. (st.meta.forceActive and "ON" or "OFF") .. " (apocalypse day " .. CDC.day() .. "/" .. CDC.State.activationDay() .. ")", player, function(pl) Dbg.send(pl, { op = "forceActive" }) end)
    if not isClient() then
        local timeOpt = menu:addOption("Advance time (SP only)")
        local timeMenu = ISContextMenu:getNew(context)
        menu:addSubMenu(timeOpt, timeMenu)
        timeMenu:addOption("+1 day", player, Dbg.advanceDays, 1)
        timeMenu:addOption("+10 days", player, Dbg.advanceDays, 10)
        timeMenu:addOption("Jump to activation day", player, function(pl)
            Dbg.advanceDays(pl, math.max(0, CDC.State.activationDay() - CDC.day()))
        end)
    end
    menu:addOption("Set quest stage...", player, Dbg.promptQuest)

    local jobOpt = menu:addOption("Jobs")
    local jobMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(jobOpt, jobMenu)
    local any = false
    for k, j in pairs(st.jobs) do
        any = true
        local label = string.format("%s (%.2f/%.2f h)", tostring(k), j.progress, j.duration)
        jobMenu:addOption("Reset " .. label, player, function(pl)
            CDC.Client.applyOps(pl, { { type = "clearJob", key = k } })
        end)
        jobMenu:addOption("Complete " .. label, player, function(pl)
            CDC.Client.applyOps(pl, { { type = "job", key = k, duration = j.duration, progress = j.duration } })
        end)
    end
    if not any then jobMenu:addOption("(no jobs)").notAvailable = true end

    menu:addOption("Clear met + dead lists", player, function(pl)
        CDC.Client.applyOps(pl, { { type = "clearPeople" } })
    end)
    menu:addOption("Jump to start tag...", player, Dbg.promptJump)

    menu:addOption("Dump state to console", player, function(pl)
        local out = {}
        dump(CDC.State.get(), "", out)
        CDC.log("STATE DUMP\n" .. table.concat(out, "\n"))
        pl:Say("CDC state dumped to console")
    end)
    menu:addOption("Tune nearest ham radio to CDC", player, Dbg.tune)

    local spawnOpt = menu:addOption("Spawn item")
    local spawnMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(spawnOpt, spawnMenu)
    for _, t in ipairs(CDC.Story.items()) do
        spawnMenu:addOption(t, player, function(pl) Dbg.send(pl, { op = "spawn", item = t }) end)
    end

    local pkOpt = menu:addOption("Reset pickup")
    local pkMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(pkOpt, pkMenu)
    for _, p in ipairs(CDC.story.world.pickups) do
        local taken = st.pickups[p.id] and " [taken]" or ""
        pkMenu:addOption(p.id .. taken, player, function(pl)
            Dbg.send(pl, { op = "resetPickup", id = p.id })
            local md = pl:getModData()
            if md.CDCPickups then md.CDCPickups[p.id] = nil end
        end)
    end

    local plOpt = menu:addOption("Reset placement")
    local plMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(plOpt, plMenu)
    for _, p in ipairs(CDC.story.world.placements) do
        local done = (st.placed or {})[p.id] and " [placed]" or ""
        plMenu:addOption(p.id .. done, player, function(pl)
            Dbg.send(pl, { op = "resetPlacement", id = p.id })
            if CDC.Placement then
                CDC.Placement.tries[p.id] = nil
                CDC.Placement.asks[p.id] = nil
            end
        end)
    end
    if #CDC.story.world.placements == 0 then plMenu:addOption("(none)").notAvailable = true end

    local lkOpt = menu:addOption("Reset locker")
    local lkMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(lkOpt, lkMenu)
    for _, l in ipairs(CDC.story.world.lockers) do
        local used = (st.lockers or {})[l.id] and " [used]" or ""
        lkMenu:addOption(l.id .. used, player, function(pl)
            Dbg.send(pl, { op = "resetLocker", id = l.id })
        end)
    end
    if #CDC.story.world.lockers == 0 then lkMenu:addOption("(none)").notAvailable = true end

    menu:addOption("RESET WORLD STATE", player, function(pl) Dbg.send(pl, { op = "reset" }) end)
end
