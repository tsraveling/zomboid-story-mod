if isServer() then return end
require "CDCLastHope/CDCStoryLoader"

CDC.Client = {}
CDC.Net = {}

-- SP has no network; call the server handler directly
function CDC.Net.send(player, cmd, args)
    if isClient() then
        sendClientCommand(player, CDC.NET_MODULE, cmd, args)
    elseif CDC.Server then
        CDC.Server.handle(player, cmd, args)
    end
end

-- applies to the local mirror now so later queries see it, then lets the server own it
function CDC.Client.applyOps(player, ops)
    local st = CDC.State.get()
    for _, op in ipairs(ops) do CDC.State.apply(st, op) end
    if CDC.isDebug() then CDC.log("state ops sent: " .. #ops .. ", met " .. #st.met .. ", dead " .. #st.dead) end
    CDC.Net.send(player, "state", { ops = ops })
end

CDC.Client.handlers = {}
local H = CDC.Client.handlers

function H.pickupResult(args)
    if CDC.Pickup then CDC.Pickup.onResult(args) end
end

-- skill-up arrow over the local player, same as vanilla VHS gains
function H.xpHalo(args)
    local p = getSpecificPlayer(0)
    if not p then return end
    for _, e in ipairs(args.xp or {}) do
        local perk = Perks.FromString(e.perk)
        if perk and perk ~= Perks.None then
            HaloTextHelper.addTextWithArrow(p, perk:getName(), "[br/]", true, HaloTextHelper.getGoodColor())
        end
    end
end

function H.floatText(args)
    CDC.Float.display(args)
end

function H.debugDone(args)
    CDC.log("debug op done: " .. tostring(args.op))
end

function CDC.Client.onServerCommand(cmd, args)
    local h = H[cmd]
    if h then h(args or {}) end
end

Events.OnServerCommand.Add(function(module, cmd, args)
    if module ~= CDC.NET_MODULE then return end
    CDC.Client.onServerCommand(cmd, args)
end)

Events.OnReceiveGlobalModData.Add(function(key, data)
    if key == CDC.MODDATA_KEY and type(data) == "table" then
        ModData.add(key, data)
    end
end)

Events.OnGameStart.Add(function()
    if isClient() then ModData.request(CDC.MODDATA_KEY) end
end)

-- floating text above the radio for bystanders
CDC.Float = {}
local F = CDC.Float

-- floats drop a quote pair wrapping the whole line; color already marks speech
function F.unquote(text)
    local inner = tostring(text):match('^%s*"(.*)"%s*$')
    return inner or tostring(text)
end

function F.display(args)
    args.text = F.unquote(args.text)
    if args.onlineId ~= nil then F.sayAs(args); return end
    F.show({ x = args.x, y = args.y, z = args.z, text = args.text, color = args.color or CDC.COLOR_CDC })
end

local function findSpeaker(onlineId)
    if isClient() then return getPlayerByOnlineID(onlineId) end
    return getSpecificPlayer(0)
end

-- player lines float above the speaking player, shown immediately
function F.sayAs(args)
    local p = findSpeaker(args.onlineId)
    if not p then return end
    local c = args.color or CDC.COLOR_PLAYER
    local ok = pcall(function() p:Say(args.text, c.r, c.g, c.b, UIFont.Dialogue, 30, "default") end)
    if not ok then p:Say(args.text) end
end

local function findRadio(x, y, z)
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then return nil end
    for i = 0, sq:getObjects():size() - 1 do
        local o = sq:getObjects():get(i)
        if CDC.isHamRadio(o) then return o end
    end
    return nil
end

-- RESEARCH: AddDeviceText is the vanilla broadcast bubble; Say is the fallback
function F.show(item)
    local radio = findRadio(item.x, item.y, item.z)
    if not radio then return end
    -- Java picks the int overload (0-255) for Lua numbers; floats 0-1 truncate to black
    local c = item.color
    local r, g, b = math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5)
    local ok = pcall(function() radio:AddDeviceText(item.text, r, g, b, "", "", CDC.FLOAT_RANGE) end)
    if not ok then pcall(function() radio:Say(item.text) end) end
end
