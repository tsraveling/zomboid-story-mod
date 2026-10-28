require "CDCLastHope/CDCStoryLoader"

-- runs on dedicated/host server and in SP (client lua calls handle() directly when not isClient())
CDC.Server = {}
local Srv = CDC.Server
local S = CDC.State

local function sync()
    if isServer() then ModData.transmit(CDC.MODDATA_KEY) end
end

local function reply(player, cmd, args)
    if isServer() then
        sendServerCommand(player, CDC.NET_MODULE, cmd, args)
    elseif CDC.Client then
        CDC.Client.onServerCommand(cmd, args)
    end
end

local function playersNear(x, y, z, radius)
    local out = {}
    if isServer() then
        local list = getOnlinePlayers()
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            if p:getZ() == z and CDC.dist(p:getX(), p:getY(), x, y) <= radius then table.insert(out, p) end
        end
    else
        local p = getSpecificPlayer(0)
        if p then table.insert(out, p) end
    end
    return out
end

local function appendTx(who, text, color)
    local st = S.get()
    st.meta.seq = st.meta.seq + 1
    table.insert(st.txlog, { seq = st.meta.seq, who = who, text = text, color = color, day = CDC.day(), hour = getGameTime():getHour() })
    while #st.txlog > CDC.TXLOG_CAP do table.remove(st.txlog, 1) end
end

local function grantXp(x, y, z, xp)
    if not xp or #xp == 0 then return end
    local radius = CDC.sandbox("RewardRadius", 20)
    for _, p in ipairs(playersNear(x, y, z, radius)) do
        for _, e in ipairs(xp) do
            local perk = Perks.FromString(e.perk)
            if perk and perk ~= Perks.None then
                local before = p:getXp():getXP(perk)
                addXpNoMultiplier(p, perk, e.amount)
                if CDC.isDebug() then
                    CDC.log(string.format("xp %s +%s -> %s: %.1f -> %.1f (level %d)", e.perk, tostring(e.amount), p:getFullName(), before, p:getXp():getXP(perk), p:getPerkLevel(perk)))
                end
            else
                CDC.log("unknown perk " .. tostring(e.perk))
            end
        end
        reply(p, "xpHalo", { xp = xp })
    end
end

-- inventory is server-owned in MP; client-side adds/removes are ghosts
local function giveItem(player, fullType)
    local inv = player:getInventory()
    local item = inv:AddItem(fullType)
    if item then sendAddItemToContainer(inv, item) end
    return item
end

local function findContainer(sq, wanted)
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local c = objs:get(i):getContainer()
        if c and (not wanted or c:getType() == wanted) then return c end
    end
    return nil
end

local function takeItem(item)
    local c = item:getContainer()
    if not c then return end
    c:Remove(item)
    sendRemoveItemFromContainer(c, item)
end

Srv.handlers = {}

-- args: ops = { {type, ...} }; see CDC.State.ops
local DEBUG_OPS = { clearJob = true, clearPeople = true }

function Srv.handlers.state(player, args)
    local st = S.get()
    for _, op in ipairs(args.ops or {}) do
        if not DEBUG_OPS[op.type] or CDC.isDebug() then S.apply(st, op) end
    end
    sync()
end

-- args: who, text, color = {r,g,b}
function Srv.handlers.txlog(player, args)
    appendTx(args.who, args.text, args.color)
    sync()
end

-- args: x,y,z, text, color
function Srv.handlers.floatText(player, args)
    for _, p in ipairs(playersNear(args.x, args.y, args.z, CDC.FLOAT_RANGE)) do
        reply(p, "floatText", args)
    end
end

-- args: id
function Srv.handlers.pickup(player, args)
    local def = CDC.Story.pickup(args.id)
    if not def then return end
    local st = S.get()
    local once = def.once or "global"
    local taken = st.pickups[args.id]
    if once == "global" and taken then
        reply(player, "pickupResult", { id = args.id, ok = false })
        return
    end
    st.pickups[args.id] = { characterName = player:getFullName(), username = player:getUsername(), day = CDC.day(), count = (taken and taken.count or 0) + 1 }
    sync()
    if def.item then giveItem(player, def.item) end
    reply(player, "pickupResult", { id = args.id, ok = true })
end

-- corpse/ground action finished; args: kind = "corpse"|"ground", id
function Srv.handlers.grant(player, args)
    local def
    if args.kind == "corpse" then def = CDC.Story.corpseAction(args.id)
    elseif args.kind == "ground" then def = CDC.Story.groundAction(args.id) end
    if not def then return end
    if def.requires then
        local tool = CDC.findTool(player:getInventory(), def.requires)
        if not tool then return end
        if def.consumes then takeItem(tool) end
    end
    if def.gives then giveItem(player, def.gives) end
end

-- a chunk holding a placement just loaded; args: id
function Srv.handlers.place(player, args)
    local def = CDC.Story.placement(args.id)
    if not def then return end
    local st = S.get()
    st.placed = st.placed or {}
    if st.placed[args.id] then return end
    local z = def.z or 0
    local sq = getCell() and getCell():getGridSquare(def.x, def.y, z)
    if not sq then
        CDC.log("placement " .. tostring(args.id) .. ": square not loaded server-side")
        return
    end
    local cont = findContainer(sq, def.container)
    if not cont then
        CDC.log("placement " .. tostring(args.id) .. ": no " .. tostring(def.container or "container") ..
            " at " .. CDC.squareKey(def.x, def.y, z))
        return
    end
    local item = cont:AddItem(def.item)
    if not item then return end
    sendAddItemToContainer(cont, item)
    st.placed[args.id] = { day = CDC.day() }
    sync()
    if CDC.isDebug() then CDC.log("placed " .. tostring(def.item) .. " in " .. cont:getType()) end
end

-- args: x,y,z, xp = { {perk,amount} }
function Srv.handlers.reward(player, args)
    grantXp(args.x, args.y, args.z, args.xp)
end

-- args: op, key, value, id
function Srv.handlers.debug(player, args)
    if not CDC.isDebug() then return end
    local st = S.get()
    if args.op == "forceActive" then
        st.meta.forceActive = not st.meta.forceActive
    elseif args.op == "reset" then
        S.reset()
    elseif args.op == "resetPickup" then
        st.pickups[args.id] = nil
    elseif args.op == "resetPlacement" then
        st.placed[args.id] = nil
    elseif args.op == "spawn" then
        giveItem(player, args.item)
    end
    sync()
    reply(player, "debugDone", { op = args.op })
end

function Srv.handle(player, cmd, args)
    local h = Srv.handlers[cmd]
    if not h then CDC.log("unknown command " .. tostring(cmd)); return end
    h(player, args or {})
end

local function onClientCommand(module, cmd, player, args)
    if module ~= CDC.NET_MODULE then return end
    Srv.handle(player, cmd, args)
end
Events.OnClientCommand.Add(onClientCommand)

-- make sure the table exists server-side on world load
Events.OnInitGlobalModData.Add(function() S.get() end)
