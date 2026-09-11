require "TimedActions/ISBaseTimedAction"

ISCDCUplinkAction = ISBaseTimedAction:derive("ISCDCUplinkAction")

function ISCDCUplinkAction:isValid()
    return self.radio:getObjectIndex() ~= -1 and CDC.Uplink.meetsRequirements(self.character, self.site)
end

function ISCDCUplinkAction:update()
    self.character:faceThisObject(self.radio)
end

function ISCDCUplinkAction:start()
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Mid")
end

function ISCDCUplinkAction:perform()
    CDC.Uplink.consume(self.character, self.site)
    local sq = self.radio:getSquare()
    CDC.Net.send(self.character, "uplink", { x = sq:getX(), y = sq:getY(), z = sq:getZ(), site = self.site.name })
    CDC.Modal.show(self.character, self.site.text or ("PLACEHOLDER: Radio wired into " .. tostring(self.site.name) .. "."))
    ISBaseTimedAction.perform(self)
end

function ISCDCUplinkAction:new(character, radio, site)
    local o = ISBaseTimedAction.new(self, character)
    o.radio = radio
    o.site = site
    o.maxTime = math.floor((site.duration or 5) * 33)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end
