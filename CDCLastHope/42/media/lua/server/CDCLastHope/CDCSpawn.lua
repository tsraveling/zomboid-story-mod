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

-- addZombiesInOutfit takes the full debug-menu arity; none of it is optional
local function placeZombie(sq, x, y, z, outfit, female)
    local seen = {}
    local mo = sq:getMovingObjects()
    for i = 0, mo:size() - 1 do seen[mo:get(i)] = true end
    local ok, err = pcall(function()
        addZombiesInOutfit(x, y, z, 1, outfit, female and 100 or 0,
            false, false, false, false, false, false, 1, false, 0, false, false)
    end)
    if not ok then fail("addZombiesInOutfit", err); return nil end
    mo = sq:getMovingObjects()
    for i = 0, mo:size() - 1 do
        local o = mo:get(i)
        if not seen[o] and instanceof(o, "IsoZombie") then return o end
    end
    CDC.log("spawn: no zombie appeared at " .. CDC.squareKey(x, y, z))
    return nil
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

local function equip(zed, def)
    local inv = zed:getInventory()
    for _, g in ipairs(def.gives or {}) do
        local ok, err = pcall(function()
            local item = inv:AddItem(g.item)
            if not item then error("unknown item " .. tostring(g.item)) end
            if g.condition then item:setCondition(g.condition) end
            if g.ammo then item:setCurrentAmmoCount(g.ammo) end
        end)
        if not ok then fail("equip " .. tostring(g.item), err) end
    end
end

-- no vanilla lua precedent for aggroing one zombie; idle is an acceptable miss
local function alert(zed, player)
    if not player then return end
    if pcall(function() zed:setTarget(player) end) then return end
    if pcall(function() zed:pathToCharacter(player) end) then return end
    CDC.log("spawn: could not alert zombie")
end

function Sp.zombie(def, player)
    local t = def.tiles[1]
    local sq = square(t[1], t[2], t[3])
    if not sq then CDC.log("spawn: no square at " .. CDC.squareKey(t[1], t[2], t[3])); return false end
    local zed = placeZombie(sq, t[1], t[2], t[3], def.outfit, def.female)
    if not zed then return false end
    dress(zed, def)
    equip(zed, def)
    alert(zed, player)
    return true
end

-- built from a live zombie so the corpse keeps the clothing and visuals
function Sp.corpse(def)
    local t = def.at or def.tiles[1]
    local sq = square(t[1], t[2], t[3])
    if not sq then CDC.log("spawn: no square at " .. CDC.squareKey(t[1], t[2], t[3])); return false end
    local zed = placeZombie(sq, t[1], t[2], t[3], def.outfit, def.female)
    if not zed then return false end
    dress(zed, def)
    local body
    local ok, err = pcall(function() body = IsoDeadBody.new(zed, false, true) end)
    if not ok then fail("IsoDeadBody.new", err); return false end
    pcall(function() zed:removeFromWorld(); zed:removeFromSquare() end)
    if body and def.corpse then
        local flagged, ferr = pcall(function() body:getModData().CDCCorpse = def.corpse end)
        if not flagged then fail("corpse flag", ferr) end
    end
    return true
end
