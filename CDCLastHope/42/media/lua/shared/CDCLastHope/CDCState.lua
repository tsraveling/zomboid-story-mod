require "CDCLastHope/CDC"

CDC.State = {}
local S = CDC.State

-- met[1] / dead entries: { first, last }; met[1] is the character CDC spoke to most recently
local function blank()
    return { quests = {}, jobs = {}, met = {}, dead = {}, pickups = {}, placed = {}, txlog = {}, meta = { forceActive = false, seq = 0 } }
end

local SCHEMA = 3

-- v1 kept quest stages as flags ("quest_first" = 1)
local function migrate(d)
    for k, v in pairs(blank()) do
        if d[k] == nil then d[k] = v end
    end
    if d.meta.seq == nil then d.meta.seq = 0 end
    for flag, v in pairs(d.flags or {}) do
        local key = type(flag) == "string" and flag:match("^quest_(.+)$")
        if key and type(v) == "number" and d.quests[key] == nil then d.quests[key] = v end
    end
    d.flags, d.log, d.radios = nil, nil, nil
    d.meta.schema = SCHEMA
end

-- always call fresh; client copy is replaced on every server transmit
function S.get()
    local d = ModData.getOrCreate(CDC.MODDATA_KEY)
    if not d.meta or d.meta.schema ~= SCHEMA then migrate(d) end
    return d
end

function S.reset()
    local d = S.get()
    for k in pairs(d) do d[k] = nil end
    migrate(d)
end

function S.activationDay()
    local story = CDC.story
    return (story and story.precue and story.precue.day) or 25
end

-- nothing works before precue day unless debug forced it
function S.isActive()
    if S.get().meta.forceActive then return true end
    return CDC.day() >= S.activationDay()
end

function S.quest(st, key)
    return st.quests[key] or 0
end

function S.job(st, key)
    return st.jobs[key]
end

function S.jobDone(st, key)
    local j = st.jobs[key]
    return j ~= nil and j.progress >= j.duration
end

local function indexOf(list, first, last)
    for i, c in ipairs(list) do
        if c.first == first and c.last == last then return i end
    end
    return nil
end

function S.isMet(st, first, last)
    return indexOf(st.met, first, last) ~= nil
end

function S.isDead(st, first, last)
    return indexOf(st.dead, first, last) ~= nil
end

local function remove(list, first, last)
    local i = indexOf(list, first, last)
    if i then table.remove(list, i) end
end

-- ops are idempotent: client applies them to its mirror and the server applies them again (twice in SP, same table)
S.ops = {}

-- { key, stage }
function S.ops.quest(st, op)
    st.quests[op.key] = op.stage
end

-- { key, duration, progress }
function S.ops.job(st, op)
    st.jobs[op.key] = { duration = op.duration, progress = op.progress }
end

function S.ops.clearJob(st, op)
    st.jobs[op.key] = nil
end

-- { first, last }: out of dead list, to front of met list
function S.ops.meet(st, op)
    remove(st.dead, op.first, op.last)
    remove(st.met, op.first, op.last)
    table.insert(st.met, 1, { first = op.first, last = op.last })
end

-- { first, last }: out of met list, into dead list
function S.ops.dead(st, op)
    remove(st.met, op.first, op.last)
    if not indexOf(st.dead, op.first, op.last) then
        table.insert(st.dead, { first = op.first, last = op.last })
    end
end

function S.ops.clearPeople(st)
    st.met = {}
    st.dead = {}
end

function S.apply(st, op)
    local f = S.ops[op.type]
    if not f then CDC.log("unknown state op " .. tostring(op.type)); return end
    f(st, op)
end
