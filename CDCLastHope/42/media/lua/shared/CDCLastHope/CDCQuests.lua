require "CDCLastHope/CDCState"

-- quest_available(key): not started (stage 0) and prereqs met. Unknown keys are unavailable.
-- rules below only express prereqs; the stage check is in isAvailable
CDC.Quests = {}
local Q = CDC.Quests

Q.available = {
  first = function() return CDC.State.quest(CDC.State.get(), "first") < 100 end,
  tri = function() return Q.isDone("first") end,
  junkie = function() return Q.isDone("tri") end,
  march = function() return Q.isDone("junkie") end,
}

-- true if quest has been completed (aka, == 100)
function Q.isDone(key)
  return CDC.State.quest(CDC.State.get(), key) == 100
end

-- @region codex:quest_available
-- returns true if quest is available but hasn't been started.
function Q.isAvailable(key)
  local f = Q.available[key]

  -- function exists, validates true, and quest is unstarted
  return (f ~= nil and f() == true) and CDC.State.quest(CDC.State.get(), key) == 0
end

-- available, or started and not done
function Q.isActive(key)
  local stage = CDC.State.quest(CDC.State.get(), key)
  return Q.isAvailable(key) or (stage > 0 and stage < 100)
end
