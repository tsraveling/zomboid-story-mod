require "CDCLastHope/CDCContext"
require "CDCLastHope/story"

CDC.Story = {}
local St = CDC.Story

function St.node(id)
    return CDC.story.nodes[id]
end

-- resolves string-or-function fields
function St.resolve(v, ctx)
    if type(v) == "function" then return v(ctx) end
    return v
end

function St.text(node, ctx)
    return tostring(St.resolve(node.text, ctx) or "")
end

function St.visibleChoices(node, ctx)
    local out = {}
    for _, c in ipairs(node.choices or {}) do
        if c.cond == nil or c.cond(ctx) then table.insert(out, c) end
    end
    return out
end

function St.flagLabel(flag)
    local labels = CDC.story.flagLabels or {}
    return labels[flag] or flag
end

function St.pickup(id)
    for _, p in ipairs(CDC.story.world.pickups or {}) do
        if p.id == id then return p end
    end
    return nil
end

function St.corpseAction(id)
    for _, c in ipairs(CDC.story.world.corpseActions or {}) do
        if c.id == id then return c end
    end
    return nil
end

-- every item the story references; used by debug spawn menu
function St.items()
    local seen, out = {}, {}
    local function add(t) if t and not seen[t] then seen[t] = true; table.insert(out, t) end end
    for _, t in ipairs(CDC.story.items or {}) do add(t) end
    for _, p in ipairs(CDC.story.world.pickups or {}) do add(p.item) end
    for _, c in ipairs(CDC.story.world.corpseActions or {}) do add(c.gives) end
    for _, s in ipairs(CDC.story.world.spawns or {}) do add(s.item) end
    table.sort(out)
    return out
end

function St.validate()
    local s = CDC.story
    if not s then CDC.log("ERROR: CDC.story missing"); return end
    s.nodes = s.nodes or {}
    s.sites = s.sites or {}
    s.journal = s.journal or {}
    s.world = s.world or {}
    s.world.pickups = s.world.pickups or {}
    s.world.corpseActions = s.world.corpseActions or {}
    s.world.spawns = s.world.spawns or {}
    if not s.freq then CDC.log("ERROR: story.freq missing") end
    for _, req in ipairs({ "noResponse", "alreadyDone" }) do
        if not s.nodes[req] then CDC.log("WARN: story.nodes." .. req .. " missing") end
    end
    for id, node in pairs(s.nodes) do
        for i, c in ipairs(node.choices or {}) do
            if type(c.next) == "string" and not s.nodes[c.next] then
                CDC.log("WARN: node '" .. id .. "' choice " .. i .. " -> missing node '" .. c.next .. "'")
            end
        end
    end
    local ids = {}
    for _, p in ipairs(s.world.pickups) do
        if ids[p.id] then CDC.log("WARN: duplicate pickup id " .. tostring(p.id)) end
        ids[p.id] = true
    end
    CDC.log("story loaded: " .. tostring(#s.world.pickups) .. " pickups, freq " .. tostring(s.freq))
end

St.validate()
