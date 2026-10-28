CDC = CDC or {}

CDC.MODDATA_KEY = "CDCLastHope"
CDC.NET_MODULE = "CDCLastHope"
CDC.FREQ_MARGIN = 300      -- kHz either side of story.freq
CDC.FLOAT_RANGE = 20       -- tiles; bystanders see radio text within this
CDC.TXLOG_CAP = 200
CDC.TRANSMIT_TIME = 100    -- timed action ticks, ~3s real time
CDC.EQUIP_RANGE = 3        -- tiles from radio for microscope / computer
CDC.TOWER_RADIUS = 25      -- tiles from a tower for at_tower()
CDC.TOWERS = {}            -- { {x = 0, y = 0} }; broadcast towers for at_tower()
CDC.JOB_ZOMBIE_RANGE = 10  -- visible zombie within this interrupts a radio job
CDC.JOB_SYNC_HOURS = 0.25  -- game hours between job progress syncs
CDC.JOB_GAME_SPEED = 3     -- SP game speed while a radio job runs
CDC.COLOR_CDC = { r = 0.75, g = 0.5, b = 1.0 }
CDC.COLOR_PLAYER = { r = 0.3, g = 0.9, b = 1.0 }
CDC.COLOR_RADIO = { r = 0.6, g = 0.6, b = 0.6 }
CDC.COLOR_OTHER = { r = 1.0, g = 1.0, b = 1.0 }
CDC.COLOR_NARRATION = { r = 0.6, g = 0.6, b = 0.6 }
CDC.COLOR_REWARD = { r = 0.4, g = 0.9, b = 0.4 }

-- Events.*.Add survives a lua reload, so every registration goes through here;
-- without it a reload stacks a second handler and commands fire twice. Handlers
-- dispatch through CDC.* rather than a captured local so a reload still takes
-- effect through the original registration.
CDC.bound = CDC.bound or {}

function CDC.bind(key, fn)
    if CDC.bound[key] then return end
    CDC.bound[key] = true
    fn()
end

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

-- req: full type ("Base.HuntingKnife"), vanilla tag ("tag:SHARP_KNIFE"), weapon category ("category:AXE"), or a list of any of these; returns first matching item or nil
function CDC.findTool(inv, req)
    if type(req) == "table" then
        for _, r in ipairs(req) do
            local item = CDC.findTool(inv, r)
            if item then return item end
        end
        return nil
    end
    local cat = req:match("^category:(.+)$")
    if cat then
        local c = WeaponCategory[cat]
        if not c then CDC.log("unknown weapon category " .. cat); return nil end
        return inv:getFirstEvalRecurse(function(item) return item:getScriptItem():containsWeaponCategory(c) end)
    end
    local tag = req:match("^tag:(.+)$")
    if tag then
        local t = ItemTag[tag]
        if not t then CDC.log("unknown item tag " .. tag); return nil end
        return inv:getFirstTagRecurse(t)
    end
    return inv:getFirstTypeRecurse(req)
end
