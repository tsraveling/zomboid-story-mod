require "CDCLastHope/CDCState"

-- journal line items keyed by quest, then stage; stages without an entry show nothing
-- lines = active objectives, completed = finished-quest entries
CDC.QuestStatus = {}
local QS = CDC.QuestStatus

QS.order = { "first" }

QS.lines = {
    first = {
        [0] = "Contact the CDC to accept the zombie meat job.",
        [1] = "Get some zombie meat and then call the CDC.",
    },
}

QS.completed = {
    first = {
        [100] = "Analyzed a hunk of zombie meat for the CDC.",
    },
}

local function collect(st, map)
    local out = {}
    for _, key in ipairs(QS.order) do
        local line = (map[key] or {})[CDC.State.quest(st, key)]
        if line then table.insert(out, line) end
    end
    return out
end

function QS.current(st)
    return collect(st, QS.lines)
end

function QS.done(st)
    return collect(st, QS.completed)
end
