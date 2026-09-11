if isServer() then return end
require "ISUI/ISTextBox"
require "CDCLastHope/CDCClient"

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

local function parseValue(s)
    if s == "true" then return true end
    if s == "false" then return false end
    if s == "nil" then return nil end
    return tonumber(s) or s
end

function Dbg.send(player, args)
    CDC.Net.send(player, "debug", args)
end

function Dbg.promptSetFlag(player)
    local pn = player:getPlayerNum()
    local box = ISTextBox:new(0, 0, 300, 160, "Set flag (key=value)", "", nil, function(target, button)
        if button.internal ~= "OK" then return end
        local s = button.parent.entry:getText() or ""
        local k, v = s:match("^%s*([^=%s]+)%s*=%s*(.-)%s*$")
        if not k then k, v = s:match("^%s*(%S+)%s*$"), "true" end
        if k then Dbg.send(player, { op = "setFlag", key = k, value = parseValue(v) }) end
    end, pn)
    box:initialise()
    box:addToUIManager()
    box:setX((getPlayerScreenWidth(pn) - 300) / 2)
    box:setY((getPlayerScreenHeight(pn) - 160) / 2)
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

function Dbg.fill(player, context, squares)
    if not CDC.isDebug() then return end
    local st = CDC.State.get()
    local root = context:addOption("CDC Debug")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)

    menu:addOption("Force active: " .. (st.meta.forceActive and "ON" or "OFF") .. " (day " .. CDC.day() .. "/" .. CDC.State.activationDay() .. ")", player, function(pl) Dbg.send(pl, { op = "forceActive" }) end)
    menu:addOption("Set flag...", player, Dbg.promptSetFlag)

    local clearOpt = menu:addOption("Clear flag")
    local clearMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(clearOpt, clearMenu)
    local any = false
    for k, v in pairs(st.flags) do
        any = true
        clearMenu:addOption(tostring(k) .. " = " .. tostring(v), player, function(pl) Dbg.send(pl, { op = "clearFlag", key = k }) end)
    end
    if not any then clearMenu:addOption("(no flags)").notAvailable = true end

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
        spawnMenu:addOption(t, player, function(pl) pl:getInventory():AddItem(t) end)
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

    menu:addOption("Mark intro unseen (this character)", player, function(pl) pl:getModData().CDCIntroSeen = nil end)
    menu:addOption("Clear uplinks", player, function(pl) Dbg.send(pl, { op = "clearUplinks" }) end)
    menu:addOption("RESET WORLD STATE", player, function(pl) Dbg.send(pl, { op = "reset" }) end)
end
