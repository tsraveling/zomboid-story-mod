require "TimedActions/ISBaseTimedAction"

ISCDCTransmitAction = ISBaseTimedAction:derive("ISCDCTransmitAction")

function ISCDCTransmitAction:isValid()
    return self.radio:getObjectIndex() ~= -1 and CDC.isRadioLive(self.radio)
end

function ISCDCTransmitAction:update()
    self.character:faceThisObject(self.radio)
end

function ISCDCTransmitAction:start()
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Mid")
end

function ISCDCTransmitAction:perform()
    CDC.Dialogue.open(self.character, self.radio, false)
    ISBaseTimedAction.perform(self)
end

function ISCDCTransmitAction:new(character, radio)
    local o = ISBaseTimedAction.new(self, character)
    o.radio = radio
    o.maxTime = CDC.TRANSMIT_TIME
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end
