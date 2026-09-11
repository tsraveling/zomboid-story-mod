if isServer() then return end
require "CDCLastHope/CDCClient"
require "CDCLastHope/CDCModal"

-- pickups
CDC.Pickup = { pending = {} }
local P = CDC.Pickup

-- is this pickup still available for this player, per its once mode
function P.available(def, player)
    local st = CDC.State.get()
    local once = def.once or "global"
    if once == "global" then return st.pickups[def.id] == nil end
    if once == "character" then return not (player:getModData().CDCPickups or {})[def.id] end
    if once == "untilDelivered" then return def.deliveredFlag == nil or st.flags[def.deliveredFlag] == nil end
    return true
end

function P.request(player, def)
    P.pending[def.id] = { player = player, def = def }
    CDC.Net.send(player, "pickup", { id = def.id, x = def.x, y = def.y, z = def.z })
end

function P.onResult(args)
    local p = P.pending[args.id]
    if not p then return end
    P.pending[args.id] = nil
    if not args.ok then
        CDC.Modal.show(p.player, p.def.goneText or "PLACEHOLDER: Nothing here anymore.")
        return
    end
    p.player:getInventory():AddItem(p.def.item)
    if (p.def.once or "global") == "character" then
        local md = p.player:getModData()
        md.CDCPickups = md.CDCPickups or {}
        md.CDCPickups[p.def.id] = true
    end
    CDC.Modal.show(p.player, p.def.text)
end

-- uplink sites
CDC.Uplink = {}
local U = CDC.Uplink

function U.meetsRequirements(player, site)
    local req = site.requires or {}
    local inv = player:getInventory()
    for t, n in pairs(req.items or {}) do
        if inv:getCountTypeRecurse(t) < n then return false end
    end
    if req.perk and req.level then
        if player:getPerkLevel(Perks.FromString(req.perk)) < req.level then return false end
    end
    return true
end

function U.requirementText(site)
    local req = site.requires or {}
    local parts = {}
    for t, n in pairs(req.items or {}) do table.insert(parts, tostring(n) .. "x " .. t) end
    if req.perk and req.level then table.insert(parts, req.perk .. " " .. tostring(req.level)) end
    return table.concat(parts, ", ")
end

function U.consume(player, site)
    local inv = player:getInventory()
    for t, n in pairs((site.requires or {}).items or {}) do
        for _ = 1, n do
            local it = inv:getFirstTypeRecurse(t)
            if it then inv:Remove(it) end
        end
    end
end
