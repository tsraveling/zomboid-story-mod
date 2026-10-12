require "TimedActions/ISBaseTimedAction"

-- radio job: runs until the job's game-hour progress reaches its duration
ISCDCJobAction = ISBaseTimedAction:derive("ISCDCJobAction")

local CHECK_TICKS = 30
local HURT_THRESHOLD = 2 -- health drop between checks; ignores slow drains like sickness

function ISCDCJobAction:health()
    local ok, v = pcall(function() return self.character:getBodyDamage():getOverallBodyHealth() end)
    return ok and v or nil
end

function ISCDCJobAction:zombieInSight()
    local zs = getCell():getZombieList()
    local px, py, pz = self.character:getX(), self.character:getY(), self.character:getZ()
    for i = 0, zs:size() - 1 do
        local z = zs:get(i)
        if math.floor(z:getZ()) == math.floor(pz) and CDC.dist(px, py, z:getX(), z:getY()) <= CDC.JOB_ZOMBIE_RANGE then
            local ok, seen = pcall(function() return self.character:CanSee(z) end)
            if not ok or seen then return true end
        end
    end
    return false
end

function ISCDCJobAction:isValid()
    return self.radio:getObjectIndex() ~= -1 and CDC.isRadioLive(self.radio)
end

function ISCDCJobAction:sync()
    CDC.Client.applyOps(self.character, { { type = "job", key = self.key, duration = self.duration, progress = self.progress } })
    self.syncedAt = self.progress
end

function ISCDCJobAction:start()
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Mid")
    self.syncedAt = self.progress
    self.last = CDC.hours()
    self.lastHealth = self:health()
    self.ticks = 0
    if not isClient() then
        self.prevSpeed = getGameSpeed()
        setGameSpeed(CDC.JOB_GAME_SPEED)
    end
end

function ISCDCJobAction:update()
    self.character:faceThisObject(self.radio)
    local now = CDC.hours()
    self.progress = math.min(self.duration, self.progress + math.max(0, now - self.last))
    self.last = now
    self:setJobDelta(self.duration > 0 and self.progress / self.duration or 1)
    if self.progress >= self.duration then
        self:forceComplete()
        return
    end
    if self.progress - self.syncedAt >= CDC.JOB_SYNC_HOURS then self:sync() end

    self.ticks = self.ticks + 1
    if self.ticks % CHECK_TICKS ~= 0 then return end
    local hp, prev = self:health(), self.lastHealth
    self.lastHealth = hp
    if (hp and prev and hp < prev - HURT_THRESHOLD) or self:zombieInSight() then
        self:forceStop()
    end
end

function ISCDCJobAction:restoreSpeed()
    if self.prevSpeed then
        setGameSpeed(self.prevSpeed)
        self.prevSpeed = nil
    end
end

function ISCDCJobAction:stop()
    self:restoreSpeed()
    self:sync()
    ISBaseTimedAction.stop(self)
    self.dialogue:onJobStopped()
end

function ISCDCJobAction:perform()
    self:restoreSpeed()
    self.progress = self.duration
    self:sync()
    ISBaseTimedAction.perform(self)
    self.dialogue:onJobDone()
end

function ISCDCJobAction:new(character, radio, key, duration, progress, dialogue)
    local o = ISBaseTimedAction.new(self, character)
    o.radio = radio
    o.key = key
    o.duration = duration
    o.progress = progress
    o.dialogue = dialogue
    o.maxTime = -1
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end
