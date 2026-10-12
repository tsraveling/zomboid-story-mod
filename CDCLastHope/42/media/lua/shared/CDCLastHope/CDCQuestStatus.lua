require "CDCLastHope/CDCState"

-- journal line items keyed by quest, then stage; stages without an entry show nothing
CDC.QuestStatus = {}
local QS = CDC.QuestStatus

QS.order = { "first" }

QS.lines = {
    first = {
        [0] = "Contact the CDC to accept the zombie meat job.",
        [1] = "Get some zombie meat and then call the CDC.",
    },
}

function QS.current(st)
    local out = {}
    for _, key in ipairs(QS.order) do
        local line = (QS.lines[key] or {})[CDC.State.quest(st, key)]
        if line then table.insert(out, line) end
    end
    return out
end
