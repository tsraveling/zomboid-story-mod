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
    local radius = CDC.sandbox("RewardRadius", 10)
    for _, p in ipairs(playersNear(x, y, z, radius)) do
        reply(p, "grantXp", { xp = xp })
    end
end

Srv.handlers = {}

-- args: reqId, ops = { {type,key,value} }, xp = { {perk,amount} }, x,y,z
function Srv.handlers.commit(player, args)
    local st = S.get()
    for _, op in ipairs(args.ops or {}) do
        if op.type == "setFlag" and st.flags[op.key] ~= nil then
            reply(player, "commitResult", { reqId = args.reqId, ok = false, reason = "alreadyDone" })
            return
        end
    end
    for _, op in ipairs(args.ops or {}) do
        if op.type == "setFlag" then
            st.flags[op.key] = op.value
            table.insert(st.log, {
                flag = op.key, value = op.value,
                characterName = player:getFullName(), username = player:getUsername(),
                day = CDC.day(), hours = CDC.hours(), x = args.x, y = args.y,
            })
        elseif op.type == "putFlag" then
            st.flags[op.key] = op.value
        elseif op.type == "clearFlag" then
            st.flags[op.key] = nil
        end
    end
    grantXp(args.x, args.y, args.z, args.xp)
    sync()
    reply(player, "commitResult", { reqId = args.reqId, ok = true })
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

-- args: id, x,y,z ; client spawns the item on ok
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
    if once == "untilDelivered" and def.deliveredFlag and st.flags[def.deliveredFlag] ~= nil then
        reply(player, "pickupResult", { id = args.id, ok = false })
        return
    end
    st.pickups[args.id] = { characterName = player:getFullName(), username = player:getUsername(), day = CDC.day(), count = (taken and taken.count or 0) + 1 }
    sync()
    reply(player, "pickupResult", { id = args.id, ok = true })
end

-- args: x,y,z, site
function Srv.handlers.uplink(player, args)
    local st = S.get()
    st.radios[CDC.squareKey(args.x, args.y, args.z)] = { site = args.site, characterName = player:getFullName(), day = CDC.day() }
    local sq = getCell():getGridSquare(args.x, args.y, args.z)
    if sq then
        for i = 0, sq:getObjects():size() - 1 do
            local obj = sq:getObjects():get(i)
            if CDC.isHamRadio(obj) then
                obj:getModData().CDCUplink = args.site
                if isServer() then obj:transmitModData() end
            end
        end
    end
    sync()
end

function Srv.handlers.reward(player, args)
    grantXp(args.x, args.y, args.z, args.xp)
end

-- args: op, key, value, id
function Srv.handlers.debug(player, args)
    if not CDC.isDebug() then return end
    local st = S.get()
    if args.op == "forceActive" then
        st.meta.forceActive = not st.meta.forceActive
    elseif args.op == "setFlag" then
        st.flags[args.key] = args.value
    elseif args.op == "clearFlag" then
        st.flags[args.key] = nil
    elseif args.op == "reset" then
        S.reset()
    elseif args.op == "resetPickup" then
        st.pickups[args.id] = nil
    elseif args.op == "clearUplinks" then
        st.radios = {}
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
