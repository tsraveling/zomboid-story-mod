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

-- addZombiesInOutfit takes the full debug-menu arity; none of it is optional.
-- It also relocates the zombie off a blocked tile, and a locker tile is blocked,
-- so the new arrival is looked for around the target rather than only on it.
-- Returns zombie, spawned. A nil zombie with spawned true means one exists
-- somewhere but we could not find it to customise.
local function placeZombie(x, y, z, outfit, female)
    local before = {}
    movingNear(x, y, z, before)
    local ok, err = pcall(function()
        addZombiesInOutfit(x, y, z, 1, outfit, female and 100 or 0,
            false, false, false, false, false, false, 1, false, 0, false, false)
    end)
    if not ok then fail("addZombiesInOutfit", err); return nil, false end
    local after = {}
    movingNear(x, y, z, after)
    for o in pairs(after) do
        if not before[o] and instanceof(o, "IsoZombie") then
            -- without this the inventory container has no id and anything added
            -- to it is dropped; vanilla does the same before dressing a zombie
            if type(o.DoZombieInventory) == "function" then o:DoZombieInventory() end
            return o, true
        end
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

-- vanilla corpse removal can delete the body before the quest needs it, which
-- would strand the locker as used forever; an absent body lets it fire again
function Sp.corpseMissing(def)
    local t = def.at or def.tiles[1]
    local sq = square(t[1], t[2], t[3])
    if not sq then return false end
    local objs = sq:getStaticMovingObjects()
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        if instanceof(o, "IsoDeadBody") and o:getModData().CDCCorpse == def.corpse then return false end
    end
    return true
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

-- built from a live zombie so the corpse keeps the clothing and visuals
function Sp.corpse(def)
    local t = def.at or def.tiles[1]
    local sq = square(t[1], t[2], t[3])
    if not sq then CDC.log("spawn: no square at " .. CDC.squareKey(t[1], t[2], t[3])); return false end
    local zed, spawned = placeZombie(t[1], t[2], t[3], def.outfit, def.female)
    if not spawned then return false end
    if not zed then
        CDC.log("spawn: corpse source zombie lost; locker marked used to stop re-firing")
        return true
    end
    dress(zed, def)
    local body
    local ok, err = pcall(function() body = IsoDeadBody.new(zed, false, true) end)
    -- always clear the live zombie, or a failed conversion leaves one loose
    pcall(function() zed:removeFromWorld(); zed:removeFromSquare() end)
    if not ok or not body then fail("IsoDeadBody.new", err or "no body"); return false end
    if def.corpse then
        local flagged, ferr = pcall(function()
            body:getModData().CDCCorpse = def.corpse
            if type(body.transmitModData) == "function" then body:transmitModData() end
        end)
        -- an unflagged body offers the wrong actions; drop it and let a retry work
        if not flagged then
            fail("corpse flag", ferr)
            pcall(function() body:removeFromWorld(); body:removeFromSquare() end)
            return false
        end
    end
    return true
end
