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

-- Knox Event date; story.apocalypse may override (1-based month/day)
CDC.APOCALYPSE = { year = 1993, month = 7, day = 9 }

-- days since 1970-01-01 for a civil date (1-based month/day)
function CDC.daysFromCivil(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = math.floor(y / 400)
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = math.floor((153 * mp + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

-- inverse of daysFromCivil; returns y, m, d (1-based)
function CDC.civilFromDays(z)
    z = z + 719468
    local era = math.floor(z / 146097)
    local doe = z - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp = math.floor((5 * doy + 2) / 153)
    local d = doy - math.floor((153 * mp + 2) / 5) + 1
    local m = mp < 10 and mp + 3 or mp - 9
    if m <= 2 then y = y + 1 end
    return y, m, d
end

-- current in-game calendar as absolute day number (GameTime month/day are 0-based)
function CDC.calendarDays()
    local gt = getGameTime()
    return CDC.daysFromCivil(gt:getYear(), gt:getMonth() + 1, gt:getDay() + 1)
end

function CDC.apocalypseDays()
    local a = (CDC.story and CDC.story.apocalypse) or CDC.APOCALYPSE
    return CDC.daysFromCivil(a.year, a.month, a.day)
end

-- days since the apocalypse by calendar date, independent of when this save started
function CDC.day()
    return CDC.calendarDays() - CDC.apocalypseDays()
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
