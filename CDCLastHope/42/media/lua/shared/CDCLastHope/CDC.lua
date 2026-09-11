CDC = CDC or {}

CDC.MODDATA_KEY = "CDCLastHope"
CDC.NET_MODULE = "CDCLastHope"
CDC.FREQ_MARGIN = 300      -- kHz either side of story.freq
CDC.FLOAT_RANGE = 20       -- tiles; bystanders see radio text within this
CDC.TXLOG_CAP = 200
CDC.TRANSMIT_TIME = 100    -- timed action ticks, ~3s real time
CDC.COLOR_CDC = { r = 0.35, g = 0.6, b = 1.0 }
CDC.COLOR_PLAYER = { r = 0.78, g = 0.6, b = 0.92 }

function CDC.log(msg)
    print("[CDCLastHope] " .. tostring(msg))
end

function CDC.day()
    return getGameTime():getNightsSurvived()
end

function CDC.hours()
    return getGameTime():getWorldAgeHours()
end

-- "x,y,z" key for a placed radio
function CDC.squareKey(x, y, z)
    return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
end

function CDC.radioKey(obj)
    local sq = obj:getSquare()
    return CDC.squareKey(sq:getX(), sq:getY(), sq:getZ())
end

function CDC.sandbox(name, default)
    local ok, v = pcall(function() return SandboxVars.CDCLastHope[name] end)
    if ok and v ~= nil then return v end
    return default
end

function CDC.isDebug()
    return CDC.sandbox("DebugMenu", false) or isDebugEnabled()
end

function CDC.dist(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

function CDC.isHamRadio(obj)
    if not obj or not instanceof(obj, "IsoWaveSignal") then return false end
    local dd = obj:getDeviceData()
    return dd ~= nil and dd:getIsTwoWay() and not dd:getIsPortable()
end

function CDC.isRadioLive(obj)
    local dd = obj:getDeviceData()
    return dd:getIsTurnedOn() and dd:getPower() > 0
end

function CDC.isOnFrequency(obj)
    local dd = obj:getDeviceData()
    return math.abs(dd:getChannel() - CDC.story.freq) <= CDC.FREQ_MARGIN
end

-- effect descriptors; story.lua uses these in choice.effects
CDC.fx = {}

-- strict: server rejects if flag already set (drives "alreadyDone")
function CDC.fx.setFlag(key, value)
    if value == nil then value = true end
    return { type = "setFlag", key = key, value = value }
end

-- overwrite silently
function CDC.fx.putFlag(key, value)
    if value == nil then value = true end
    return { type = "putFlag", key = key, value = value }
end

function CDC.fx.clearFlag(key)
    return { type = "clearFlag", key = key }
end

-- perk is a string name, e.g. "Electricity"
function CDC.fx.xp(perk, amount)
    return { type = "xp", perk = perk, amount = amount }
end

-- runs client-side on the caller after server commit succeeds
function CDC.fx.fn(f)
    return { type = "fn", fn = f }
end
