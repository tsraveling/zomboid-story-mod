require "CDCLastHope/CDCStoryLoader"

-- World spawning for lockers. Every vanilla call is pcall-guarded: the zombie
-- spawn globals are only documented client-side, so a dedicated server may not
-- expose them and we would rather log than break the action.
CDC.Spawn = {}
local Sp = CDC.Spawn

local function fail(what, err)
    CDC.log("spawn: " .. what .. " failed: " .. tostring(err))
end

local function square(x, y, z)
    local cell = getCell()
    return cell and cell:getGridSquare(x, y, z) or nil
end

local SCAN = 4

local function movingNear(x, y, z, into)
    for dx = -SCAN, SCAN do
        for dy = -SCAN, SCAN do
            local sq = square(x + dx, y + dy, z)
            if sq then
                local mo = sq:getMovingObjects()
                for i = 0, mo:size() - 1 do into[mo:get(i)] = true end
            end
        end
    end
end

-- without this the inventory container has no id and anything added to it is
-- dropped; vanilla does the same before dressing a zombie
local function readyInventory(zed)
    if type(zed.DoZombieInventory) == "function" then zed:DoZombieInventory() end
    return zed
end

-- addZombiesInOutfit takes the full debug-menu arity; none of it is optional.
-- It returns the zombies it made, but it also relocates them off a blocked tile
-- and a locker tile is blocked, so an empty return falls back to diffing the
-- moving objects around the target.
-- Returns zombie, spawned. A nil zombie with spawned true means one exists
-- somewhere but we could not find it to customise.
local function placeZombie(x, y, z, outfit, female, prone)
    local before = {}
    movingNear(x, y, z, before)
    local made
    local ok, err = pcall(function()
        -- arity is crawler, fallOnFront, fakeDead, knockedDown, invulnerable,
        -- sitting, health, recordAnims, heightOffset, ragdolling, onFire
        made = addZombiesInOutfit(x, y, z, 1, outfit, female and 100 or 0,
            false, prone == true, false, prone == true, false, false, 1, false, 0, false, false)
    end)
    if not ok then fail("addZombiesInOutfit", err); return nil, false end
    if made and made:size() > 0 then return readyInventory(made:get(0)), true end
    local after = {}
    movingNear(x, y, z, after)
    for o in pairs(after) do
        if not before[o] and instanceof(o, "IsoZombie") then return readyInventory(o), true end
    end
    CDC.log("spawn: no zombie appeared near " .. CDC.squareKey(x, y, z))
    return nil, true
end

local function dress(zed, def)
    local ok, err = pcall(function()
        if def.skin then zed:getHumanVisual():setSkinTextureIndex(def.skin) end
        local inv = zed:getInventory()
        for _, w in ipairs(def.wears or {}) do
            local item = inv:AddItem(w.item)
            if item then
                if w.tint then
                    item:getVisual():setTint(ImmutableColor.new(w.tint[1], w.tint[2], w.tint[3], 1))
                end
                zed:setWornItem(item:getBodyLocation(), item)
            end
        end
        zed:resetModel()
    end)
    if not ok then fail("dress", err) end
end

-- def.gives goes in the zombie; anything heavy belongs in def.drops, since a
-- zombie will not hold onto a weapon
local function equip(zed, def)
    local inv = zed:getInventory()
    for _, g in ipairs(def.gives or {}) do
        local ok, err = pcall(function()
            local item = inv:AddItem(g.item)
            if not item then error("unknown item " .. tostring(g.item)) end
            if g.condition then item:setCondition(g.condition) end
            if g.ammo and type(item.setCurrentAmmoCount) == "function" then
                item:setCurrentAmmoCount(g.ammo)
            end
        end)
        if not ok then fail("equip " .. tostring(g.item), err) end
    end
end

-- onto the floor where the zombie actually ended up, not the blocked locker tile
local function drop(zed, def, sq)
    local at = zed and zed:getCurrentSquare() or sq
    if not at then return end
    for _, d in ipairs(def.drops or {}) do
        local ok, err = pcall(function()
            local item = at:AddWorldInventoryItem(d.item, 0.5, 0.5, 0)
            if not item then error("unknown item " .. tostring(d.item)) end
            if d.condition then item:setCondition(d.condition) end
            if d.ammo and type(item.setCurrentAmmoCount) == "function" then
                item:setCurrentAmmoCount(d.ammo)
            end
        end)
        if not ok then fail("drop " .. tostring(d.item), err) end
    end
end

-- no vanilla lua precedent for aggroing one zombie, so probe rather than guess:
-- a missing java method indexes to nil, which would otherwise trip break-on-error
local function alert(zed, player)
    if not player then return end
    for _, name in ipairs({ "setTarget", "pathToCharacter" }) do
        if type(zed[name]) == "function" and pcall(function() zed[name](zed, player) end) then return end
    end
    CDC.log("spawn: no usable aggro method; zombie left idle")
end

-- a dying zombie drops where it stands, which is not always the tile it was
-- asked for, so the body is looked for around the target rather than only on it
local BODY_SCAN = 2

-- every body lying around the target, flagged or not
local function bodiesNear(def, into)
    local t = def.at or def.tiles[1]
    for dx = -BODY_SCAN, BODY_SCAN do
        for dy = -BODY_SCAN, BODY_SCAN do
            local sq = square(t[1] + dx, t[2] + dy, t[3])
            if sq then
                local objs = sq:getStaticMovingObjects()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    if instanceof(o, "IsoDeadBody") then into[o] = true end
                end
            end
        end
    end
end

-- skip holds the bodies that were already here, so a corpse left by an earlier
-- run is not mistaken for the one a spawn in progress is waiting on
local function bodyNear(def, skip)
    -- an unflagged body is any body; without a flag there is nothing to match
    if not def.corpse then return nil end
    local t = def.at or def.tiles[1]
    for dx = -BODY_SCAN, BODY_SCAN do
        for dy = -BODY_SCAN, BODY_SCAN do
            local sq = square(t[1] + dx, t[2] + dy, t[3])
            if sq then
                local objs = sq:getStaticMovingObjects()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    if instanceof(o, "IsoDeadBody") and not (skip and skip[o])
                        and o:getModData().CDCCorpse == def.corpse then
                        return o
                    end
                end
            end
        end
    end
    return nil
end

-- vanilla corpse removal can delete the body before the quest needs it, which
-- would strand the locker as used forever; an absent body lets it fire again.
-- An unflagged corpse cannot be told from the zombies a player killed nearby,
-- so it is never counted missing and its locker stays used.
function Sp.corpseMissing(def)
    if not def.corpse then return false end
    return bodyNear(def) == nil
end

function Sp.zombie(def, player)
    local t = def.tiles[1]
    local sq = square(t[1], t[2], t[3])
    if not sq then CDC.log("spawn: no square at " .. CDC.squareKey(t[1], t[2], t[3])); return false end
    local zed, spawned = placeZombie(t[1], t[2], t[3], def.outfit, def.female)
    if not spawned then return false end
    -- a plain uncustomised zombie still beats re-firing the locker forever
    if not zed then return true end
    dress(zed, def)
    equip(zed, def)
    drop(zed, def, sq)
    alert(zed, player)
    return true
end

-- IsoDeadBody.new builds a body the server never tells anyone about: the class
-- registers no object factory, so the generic object packet cannot rebuild it
-- client-side either. Killing a zombie is the only corpse path that replicates,
-- since the engine itself sends the death. The body copies the character's
-- modData when it is built, so the flag goes on the zombie first.
-- nothing polls a zombie's health, so zeroing it leaves the zombie standing.
-- die() runs the real path: Kill -> becomeCorpse -> the died listener the
-- zombie registers on itself, which is what sends the death to clients.
local function kill(zed)
    for _, name in ipairs({ "die", "Kill" }) do
        if type(zed[name]) == "function" then
            local ok, err = pcall(function()
                if name == "die" then zed:die() else zed:Kill(nil) end
            end)
            if ok then return true end
            fail(name, err)
        end
    end
    CDC.log("spawn: no usable kill method; zombie left alive")
    return false
end

-- The death packet resolves the body from the character the receiving client is
-- already holding, and is dropped when that lookup fails. A zombie spawned and
-- killed in the same tick never reaches anyone, so it is left alive briefly to
-- replicate first. Wall clock, because a server's loop rate is not a client's.
local SETTLE_MS = 750
-- if no body has shown up by now the kill did not take; try once more
local NUDGE_MS = 4000
local GIVEUP_MS = 10000

local watching = {}

-- the engine's own object modData packet addresses a corpse by its index in
-- the square's moving objects, which races the client building that body and
-- drifts with any other corpse on the tile. The shared table is already synced
-- and already survives a relog, so the resting square is recorded there instead.
local function pushFlag(def, skip)
    local body = bodyNear(def, skip)
    if not body then return false end
    local sq = body:getSquare()
    if not sq then return false end
    CDC.State.apply(CDC.State.get(), {
        type = "corpse", id = def.id, corpse = def.corpse,
        x = sq:getX(), y = sq:getY(), z = sq:getZ(),
    })
    CDC.sync()
    return true
end

-- it has to be alive long enough to replicate, but it should not get a bite in
-- while it is: knocked down and unable to walk, it can only lie there
local function hold(zed)
    if type(zed.setCanWalk) == "function" then pcall(function() zed:setCanWalk(false) end) end
    if type(zed.setKnockedDown) == "function" then pcall(function() zed:setKnockedDown(true) end) end
end

function Sp.onTick()
    local now = getTimestampMs()
    for i = #watching, 1, -1 do
        local w = watching[i]
        -- a player swinging at it during the wait kills it just as well, and the
        -- flag is already on, so an early body is taken as done
        if pushFlag(w.def, w.before) then
            table.remove(watching, i)
        elseif not w.killed then
            if now >= w.settleAt then
                w.killed = true
                -- nothing to push without a flag, so the kill is the whole job
                if not kill(w.zed) or not w.def.corpse then table.remove(watching, i) end
            else
                hold(w.zed)
            end
        elseif now >= w.giveUpAt then
            CDC.log("spawn: corpse for " .. tostring(w.def.id) .. " never appeared")
            table.remove(watching, i)
        elseif not w.nudged and now >= w.nudgeAt then
            w.nudged = true
            CDC.log("spawn: corpse for " .. tostring(w.def.id) .. " still upright; killing again")
            kill(w.zed)
        end
    end
end

-- the zombie is spawned prone so it reads as a body on the floor for the second
-- or so it has to stay alive, and the narration modal covers that wait
function Sp.corpse(def)
    local t = def.at or def.tiles[1]
    local sq = square(t[1], t[2], t[3])
    if not sq then CDC.log("spawn: no square at " .. CDC.squareKey(t[1], t[2], t[3])); return false end
    local before = {}
    bodiesNear(def, before)
    local zed, spawned = placeZombie(t[1], t[2], t[3], def.outfit, def.female, true)
    if not spawned then return false end
    if not zed then
        CDC.log("spawn: corpse source zombie lost; locker marked used to stop re-firing")
        return true
    end
    dress(zed, def)
    if def.corpse then
        local flagged, ferr = pcall(function() zed:getModData().CDCCorpse = def.corpse end)
        -- an unflagged body offers the wrong actions; clear it and let a retry work
        if not flagged then
            fail("corpse flag", ferr)
            pcall(function() zed:removeFromWorld(); zed:removeFromSquare() end)
            return false
        end
    end
    local now = getTimestampMs()
    table.insert(watching, { def = def, zed = zed, before = before, killed = false, nudged = false,
        settleAt = now + SETTLE_MS, nudgeAt = now + NUDGE_MS, giveUpAt = now + GIVEUP_MS })
    return true
end

CDC.bind("spawn", function()
    Events.OnTick.Add(function() CDC.Spawn.onTick() end)
end)
