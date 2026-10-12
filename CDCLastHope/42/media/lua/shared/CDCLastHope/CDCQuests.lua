require "CDCLastHope/CDCState"

-- quest_available(key): prereqs met and quest built. Unknown keys are unavailable.
CDC.Quests = {}
local Q = CDC.Quests

Q.available = {
    first = function(st) return CDC.State.quest(st, "first") == 0 end,
}

function Q.isAvailable(st, key)
    local f = Q.available[key]
    return f ~= nil and f(st) == true
end
