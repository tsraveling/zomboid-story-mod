if isServer() then return end
require "CDCLastHope/CDCClient"
require "CDCLastHope/CDCQuests"

-- codex methods (text/cdc.codex). host = { player, radio }
CDC.Skald = {}
local K = CDC.Skald
local S = CDC.State

local MICROSCOPE_SPRITES = { location_community_medical_01_136 = true }
local COMPUTER_SPRITES = {
    appliances_com_01_72 = true, appliances_com_01_73 = true,
    appliances_com_01_74 = true, appliances_com_01_75 = true,
}

local function st()
    return S.get()
end

local function names(player)
    local d = player:getDescriptor()
    return d:getForename() or "", d:getSurname() or ""
end

local function full(first, last)
    if last == "" then return first end
    return first .. " " .. last
end

local function remembered()
    return st().met[1]
end

local function isCharacter(c, player)
    if not c then return false end
    local first, last = names(player)
    return c.first == first and c.last == last
end

local function customName(obj)
    local ok, v = pcall(function() return obj:getProperties():get("CustomName") end)
    return ok and v or nil
end

local function isEquipment(obj, sprites, label)
    local spr = obj:getSprite()
    if spr and sprites[spr:getName()] then return true end
    return customName(obj) == label
end

local function powered(sq)
    if sq:haveElectricity() then return true end
    local ok, grid = pcall(function() return sq:hasGridPower() end)
    return ok and grid and sq:getRoom() ~= nil
end

-- true if fn(obj, square) holds for any object within CDC.EQUIP_RANGE of the radio, same floor
local function nearRadio(radio, fn)
    local rsq = radio:getSquare()
    if not rsq then return false end
    local r = CDC.EQUIP_RANGE
    for dx = -r, r do
        for dy = -r, r do
            local sq = getCell():getGridSquare(rsq:getX() + dx, rsq:getY() + dy, rsq:getZ())
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    if fn(objs:get(i), sq) then return true end
                end
            end
        end
    end
    return false
end

-- unqualified names try the mod module, then Base
local function itemTypes(item)
    if item:find("%.") then return { item } end
    return { "CDCLastHope." .. item, "Base." .. item }
end

K.queries = {}
local Qy = K.queries

function Qy.check_quest(h, key, stage) return S.quest(st(), key) == stage end
function Qy.get_quest(h, key) return S.quest(st(), key) end
function Qy.quest_available(h, key) return CDC.Quests.isAvailable(st(), key) end

function Qy.check_skill(h, skill, level)
    local ok, lvl = pcall(function() return h.player:getPerkLevel(Perks.FromString(skill)) end)
    if not ok then CDC.log("check_skill: unknown perk " .. tostring(skill)); return false end
    return lvl >= level
end

function Qy.has_item(h, item)
    local inv = h.player:getInventory()
    for _, t in ipairs(itemTypes(item)) do
        if inv:containsTypeRecurse(t) then return true end
    end
    return false
end

function Qy.has_started_job(h, key)
    local j = S.job(st(), key)
    return j ~= nil and j.progress > 0
end

function Qy.check_job_done(h, key) return S.jobDone(st(), key) end

function Qy.radio_has_microscope(h)
    return nearRadio(h.radio, function(o) return isEquipment(o, MICROSCOPE_SPRITES, "Microscope") end)
end

function Qy.radio_has_computer(h)
    return nearRadio(h.radio, function(o, sq) return isEquipment(o, COMPUTER_SPRITES, "Computer") and powered(sq) end)
end

function Qy.at_tower(h)
    local sq = h.radio:getSquare()
    for _, t in ipairs(CDC.TOWERS) do
        if CDC.dist(sq:getX(), sq:getY(), t.x, t.y) <= CDC.TOWER_RADIUS then return true end
    end
    return false
end

function Qy.pc_first_name(h) return (names(h.player)) end
function Qy.pc_last_name(h) local _, l = names(h.player); return l end
function Qy.pc_full_name(h) return full(names(h.player)) end

function Qy.mem_first_name(h) local c = remembered(); return c and c.first or "" end
function Qy.mem_last_name(h) local c = remembered(); return c and c.last or "" end
function Qy.mem_full_name(h) local c = remembered(); return c and full(c.first, c.last) or "" end

function Qy.has_met(h) return S.isMet(st(), names(h.player)) end
function Qy.is_returning(h) return isCharacter(remembered(), h.player) end
function Qy.did_think_dead(h) return S.isDead(st(), names(h.player)) end
function Qy.met_anyone(h) return #st().met > 0 end

-- do_job is async and handled by CDC.Convo
K.posts = {}
local Po = K.posts

local function meet(h)
    local first, last = names(h.player)
    CDC.Client.applyOps(h.player, { { type = "meet", first = first, last = last } })
end

function Po.set_quest(h, key, stage)
    CDC.Client.applyOps(h.player, { { type = "quest", key = key, stage = stage } })
end

function Po.reward_xp(h, skill, amount)
    local perk = Perks.FromString(skill)
    local name = (perk and perk ~= Perks.None) and perk:getName() or skill
    local n = amount == math.floor(amount) and string.format("%d", amount) or tostring(amount)
    h.line("reward", name .. " +" .. n)
    local sq = h.radio:getSquare()
    CDC.Net.send(h.player, "reward", { x = sq:getX(), y = sq:getY(), z = sq:getZ(), xp = { { perk = skill, amount = amount } } })
end

Po.do_meet = meet
Po.update_meet = meet

function Po.set_thought_dead(h)
    local c = remembered()
    if not c then return end
    CDC.Client.applyOps(h.player, { { type = "dead", first = c.first, last = c.last } })
end
