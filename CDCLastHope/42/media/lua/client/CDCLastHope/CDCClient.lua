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

CDC.Client.handlers = {}
local H = CDC.Client.handlers

function H.commitResult(args)
    if CDC.Dialogue then CDC.Dialogue.onCommitResult(args) end
end

function H.pickupResult(args)
    if CDC.Pickup then CDC.Pickup.onResult(args) end
end

function H.grantXp(args)
    local p = getSpecificPlayer(0)
    if not p then return end
    for _, e in ipairs(args.xp or {}) do
        local perk = Perks.FromString(e.perk)
        if perk then p:getXp():AddXP(perk, e.amount) else CDC.log("unknown perk " .. tostring(e.perk)) end
    end
end

function H.floatText(args)
    CDC.Float.enqueue(args)
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
CDC.Float = { queue = {}, nextAt = 0, STAGGER_MS = 3000, MAX_LINES = 4 }
local F = CDC.Float

function F.split(text)
    local out = {}
    for s in tostring(text):gmatch("[^%.%?!]+[%.%?!]*") do
        s = s:gsub("^%s+", ""):gsub("%s+$", "")
        if s ~= "" then table.insert(out, s) end
    end
    if #out == 0 then out = { tostring(text) } end
    return out
end

function F.enqueue(args)
    local parts = F.split(args.text)
    for i = 1, math.min(#parts, F.MAX_LINES) do
        table.insert(F.queue, { x = args.x, y = args.y, z = args.z, text = parts[i], color = args.color or CDC.COLOR_CDC })
    end
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
    local c = item.color
    local ok = pcall(function() radio:AddDeviceText(item.text, c.r, c.g, c.b, "", "", CDC.FLOAT_RANGE) end)
    if not ok then pcall(function() radio:Say(item.text) end) end
end

Events.OnTick.Add(function()
    if #F.queue == 0 then return end
    local now = getTimestampMs()
    if now < F.nextAt then return end
    F.show(table.remove(F.queue, 1))
    F.nextAt = now + F.STAGGER_MS
end)
