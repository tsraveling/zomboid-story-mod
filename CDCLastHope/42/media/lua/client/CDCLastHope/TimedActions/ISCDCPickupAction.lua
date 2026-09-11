require "TimedActions/ISBaseTimedAction"

ISCDCPickupAction = ISBaseTimedAction:derive("ISCDCPickupAction")

function ISCDCPickupAction:isValid()
    return true
end

function ISCDCPickupAction:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
end

function ISCDCPickupAction:start()
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Mid")
end

function ISCDCPickupAction:perform()
    CDC.Pickup.request(self.character, self.def)
    ISBaseTimedAction.perform(self)
end

function ISCDCPickupAction:new(character, def, square)
    local o = ISBaseTimedAction.new(self, character)
    o.def = def
    o.square = square
    o.maxTime = math.floor((def.duration or 2) * 33)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end
