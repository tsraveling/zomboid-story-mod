require "TimedActions/ISBaseTimedAction"

ISCDCLockerAction = ISBaseTimedAction:derive("ISCDCLockerAction")

function ISCDCLockerAction:isValid()
    return self.square ~= nil
end

function ISCDCLockerAction:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
end

function ISCDCLockerAction:start()
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Mid")
end

function ISCDCLockerAction:perform()
    CDC.Net.send(self.character, "locker", { id = self.def.id })
    ISBaseTimedAction.perform(self)
end

function ISCDCLockerAction:new(character, def, square)
    local o = ISBaseTimedAction.new(self, character)
    o.def = def
    o.square = square
    o.maxTime = math.floor((def.duration or 2) * 33)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end
