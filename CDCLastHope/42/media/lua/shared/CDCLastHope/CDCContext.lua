require "CDCLastHope/CDCState"

-- ctx handed to story.lua world config (pickup / corpse action conds)
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

    function ctx.quest(key)
        return CDC.State.quest(CDC.State.get(), key)
    end

    function ctx.jobDone(key)
        return CDC.State.jobDone(CDC.State.get(), key)
    end

    function ctx.hasItem(spec)
        return matchItem(player:getInventory(), spec)
    end

    function ctx.countItem(fullType)
        return player:getInventory():getCountTypeRecurse(fullType)
    end

    function ctx.perkLevel(perkName)
        return player:getPerkLevel(Perks.FromString(perkName))
    end

    return ctx
end
