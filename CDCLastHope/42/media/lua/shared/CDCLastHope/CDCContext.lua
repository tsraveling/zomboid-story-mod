require "CDCLastHope/CDCState"

CDC.Sites = {}

-- site whose radius covers (x,y), or nil
function CDC.Sites.at(x, y)
    for _, site in ipairs(CDC.story.sites or {}) do
        if CDC.dist(x, y, site.x, site.y) <= (site.r or 20) then return site end
    end
    return nil
end

CDC.Context = {}

-- spec: full type string, list of full types, or function(item) -> bool
local function matchItem(inv, spec)
    if type(spec) == "string" then
        return inv:containsTypeRecurse(spec)
    elseif type(spec) == "table" then
        for _, t in ipairs(spec) do
            if inv:containsTypeRecurse(t) then return true end
        end
        return false
    elseif type(spec) == "function" then
        return inv:containsEvalRecurse(spec)
    end
    return false
end

function CDC.Context.new(player, radio)
    local ctx = {}
    ctx.player = player
    ctx.radio = radio
    ctx.day = CDC.day()
    ctx.name = player:getFullName()
    ctx.username = player:getUsername()
    ctx.isNewCharacter = not player:getModData().CDCIntroSeen

    local sq = radio and radio:getSquare() or player:getSquare()
    ctx.atSite = sq and CDC.Sites.at(sq:getX(), sq:getY()) or nil
    ctx.uplinked = (radio ~= nil) and (CDC.State.uplinkOf(radio) ~= nil)

    function ctx.has(flag)
        local v = CDC.State.get().flags[flag]
        return v ~= nil and v ~= false
    end

    function ctx.get(flag)
        return CDC.State.get().flags[flag]
    end

    function ctx.hasItem(spec)
        return matchItem(player:getInventory(), spec)
    end

    function ctx.countItem(fullType)
        return player:getInventory():getCountTypeRecurse(fullType)
    end

    function ctx.lastDelivery(flag)
        return CDC.State.lastDelivery(flag)
    end

    function ctx.daysSince(entry)
        return CDC.State.daysSince(entry)
    end

    function ctx.perkLevel(perkName)
        return player:getPerkLevel(Perks.FromString(perkName))
    end

    return ctx
end
