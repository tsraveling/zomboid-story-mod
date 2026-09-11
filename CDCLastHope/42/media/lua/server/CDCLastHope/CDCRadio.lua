require "CDCLastHope/CDCStoryLoader"

-- CDC channel + pre-cue, using vanilla DynamicRadio (see media/lua/server/radio/ISDynamicRadio.lua)
CDC.Radio = {}
local R = CDC.Radio
R.channelUUID = "CDC-LASTHOPE-01"

local function lines(v)
    if type(v) == "table" then return v end
    return { v }
end

local function newBroadcast(texts, c)
    local bc = RadioBroadCast.new("CDC-" .. tostring(ZombRand(100000, 999999)), -1, -1)
    for _, t in ipairs(texts) do
        bc:AddRadioLine(RadioLine.new(tostring(t), c.r, c.g, c.b))
    end
    return bc
end

-- called every game hour by DynamicRadio with our channel
function R.OnEveryHour(channel, gametime, radio)
    if not CDC.State.isActive() then return end
    channel:setAiringBroadcast(newBroadcast(lines(CDC.story.callout.text), CDC.COLOR_CDC))
end

-- pre-cue: push the carrier line onto every silent vanilla station
-- RESEARCH: confirm dead channels accept setAiringBroadcast; if not, fall back to AEBS uuid only
function R.pushPrecue()
    local story = CDC.story
    if not story.precue or CDC.day() < story.precue.day then return end
    if not RadioScriptManager.hasInstance() then return end
    local mgr = RadioScriptManager.getInstance()
    local list = mgr:getChannelsList()
    local bcText = lines(story.precue.text)
    for i = 0, list:size() - 1 do
        local ch = list:get(i)
        local cat = tostring(ch:GetCategory())
        local ours = ch:GetFrequency() == story.freq
        if not ours and cat ~= "Emergency" and ch:getAiringBroadcast() == nil then
            ch:setAiringBroadcast(newBroadcast(bcText, { r = 0.7, g = 0.7, b = 0.7 }))
        end
    end
end

function R.OnLoadRadioScripts()
    table.insert(DynamicRadio.scripts, { channelUUID = R.channelUUID, OnEveryHour = R.OnEveryHour })
end

-- register before DynamicRadio.OnLoadRadioScripts runs (mod lua loads after vanilla)
table.insert(DynamicRadio.channels, {
    name = "CDC Knox Event Response",
    freq = CDC.story.freq,
    category = "Emergency",
    uuid = R.channelUUID,
    register = true,
    airCounterMultiplier = 1.0,
})

Events.OnLoadRadioScripts.Add(R.OnLoadRadioScripts)
Events.EveryHours.Add(R.pushPrecue)
