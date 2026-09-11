require "CDCLastHope/CDC"

CDC.State = {}
local S = CDC.State

local function blank()
    return { flags = {}, log = {}, pickups = {}, txlog = {}, radios = {}, meta = { forceActive = false, seq = 0 } }
end

-- always call fresh; client copy is replaced on every server transmit
function S.get()
    local d = ModData.getOrCreate(CDC.MODDATA_KEY)
    for k, v in pairs(blank()) do
        if d[k] == nil then d[k] = v end
    end
    if d.meta.seq == nil then d.meta.seq = 0 end
    return d
end

function S.reset()
    local d = S.get()
    for k in pairs(d) do d[k] = nil end
    for k, v in pairs(blank()) do d[k] = v end
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

function S.lastDelivery(flag)
    local log = S.get().log
    for i = #log, 1, -1 do
        if log[i].flag == flag then return log[i] end
    end
    return nil
end

function S.hoursSince(entry)
    return CDC.hours() - (entry.hours or 0)
end

function S.daysSince(entry)
    return math.floor(S.hoursSince(entry) / 24)
end

function S.uplinkOf(radioObj)
    return S.get().radios[CDC.radioKey(radioObj)]
end
