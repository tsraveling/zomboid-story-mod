if isServer() then return end
require "CDCLastHope/CDCClient"

-- Story items that belong in a specific container somewhere in the world. The
-- square does not exist until its chunk streams in, so the load is the trigger;
-- the server owns the add and the once-only flag.
CDC.Placement = CDC.Placement or {}
local P = CDC.Placement
P.tries = P.tries or {}
P.asks = P.asks or {}

-- a placement whose container is missing would otherwise re-ask every sweep.
-- Only a server-reported container miss burns a try; a chunk the server has not
-- loaded yet is transient and must stay retryable.
local MAX_TRIES = 5
-- bad coordinates make the server report an unloadable square forever, so cap
-- total requests too; the budget resets each time the chunk streams in
local MAX_ASKS = 60

local byKey

local function index()
    if byKey then return byKey end
    byKey = {}
    for _, def in ipairs(CDC.story.world.placements or {}) do
        local k = CDC.squareKey(def.x, def.y, def.z or 0)
        byKey[k] = byKey[k] or {}
        table.insert(byKey[k], def)
    end
    return byKey
end

-- duplicate requests are harmless; the server is the one that checks placed
local function request(defs)
    local player = getSpecificPlayer(0)
    if not player then return end
    local placed = CDC.State.get().placed or {}
    for _, def in ipairs(defs) do
        local asks = P.asks[def.id] or 0
        if not placed[def.id] and (P.tries[def.id] or 0) < MAX_TRIES and asks < MAX_ASKS then
            P.asks[def.id] = asks + 1
            if asks + 1 == MAX_ASKS then
                CDC.log("placement " .. tostring(def.id) .. ": no response after " .. MAX_ASKS .. " requests")
            end
            CDC.Net.send(player, "place", { id = def.id })
        end
    end
end

function P.onResult(args)
    if args.ok or (args.reason ~= "container" and args.reason ~= "item") then return end
    local n = (P.tries[args.id] or 0) + 1
    P.tries[args.id] = n
    if n == MAX_TRIES then
        CDC.log("placement " .. tostring(args.id) .. ": no container after " .. MAX_TRIES .. " tries, giving up")
    end
end

function P.onLoad(square)
    local defs = index()[CDC.squareKey(square:getX(), square:getY(), square:getZ())]
    if not defs then return end
    for _, def in ipairs(defs) do P.asks[def.id] = 0 end
    request(defs)
end

-- LoadGridsquare only fires as a chunk streams in, so it misses a square that
-- was already in memory when the placement was added. Catch those here.
function P.sweep()
    local placed = CDC.State.get().placed or {}
    local cell = getCell()
    if not cell then return end
    for _, def in ipairs(CDC.story.world.placements or {}) do
        if not placed[def.id] and cell:getGridSquare(def.x, def.y, def.z or 0) then
            request({ def })
        end
    end
end

CDC.bind("placement", function()
    Events.LoadGridsquare.Add(function(sq) CDC.Placement.onLoad(sq) end)
    Events.EveryOneMinute.Add(function() CDC.Placement.sweep() end)
end)
