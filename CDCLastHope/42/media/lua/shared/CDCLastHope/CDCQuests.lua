require "CDCLastHope/CDCState"

-- quest_available(key): not started (stage 0) and prereqs met. Unknown keys are unavailable.
-- rules below only express prereqs; the stage check is in isAvailable
CDC.Quests = {}
local Q = CDC.Quests

-- @region quests:availability
Q.available = {
  first = function() return true end,
  tri = function() return Q.isDone("first") end,
}

function Q.isDone(key)
  return CDC.State.quest(CDC.State.get(), key) == 100
end

function Q.isAvailable(key)
  local f = Q.available[key]
  return f ~= nil and CDC.State.quest(CDC.State.get(), key) == 0 and f() == true
end
