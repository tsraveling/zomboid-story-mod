if isServer() then return end
require "CDCLastHope/CDCClient"

-- Story items that belong in a specific container somewhere in the world. The
-- square does not exist until its chunk streams in, so the load is the trigger;
-- the server owns the add and the once-only flag.
CDC.Placement = {}
local P = CDC.Placement

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
        if not placed[def.id] then CDC.Net.send(player, "place", { id = def.id }) end
    end
end

function P.onLoad(square)
    local defs = index()[CDC.squareKey(square:getX(), square:getY(), square:getZ())]
    if defs then request(defs) end
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

Events.LoadGridsquare.Add(P.onLoad)
Events.EveryOneMinute.Add(P.sweep)
