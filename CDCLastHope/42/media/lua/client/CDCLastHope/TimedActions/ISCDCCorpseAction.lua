require "TimedActions/ISBaseTimedAction"

ISCDCCorpseAction = ISBaseTimedAction:derive("ISCDCCorpseAction")

function ISCDCCorpseAction:isValid()
    if self.def.requires and not self.character:getInventory():containsTypeRecurse(self.def.requires) then return false end
    return self.body:getSquare() ~= nil
end

function ISCDCCorpseAction:update()
    self.character:faceThisObject(self.body)
end

function ISCDCCorpseAction:start()
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Low")
end

function ISCDCCorpseAction:perform()
    local inv = self.character:getInventory()
    if self.def.requires and self.def.consumes then
        local tool = inv:getFirstTypeRecurse(self.def.requires)
        if tool then inv:Remove(tool) end
    end
    if self.def.gives then inv:AddItem(self.def.gives) end
    CDC.Modal.show(self.character, self.def.text)
    ISBaseTimedAction.perform(self)
end

function ISCDCCorpseAction:new(character, def, body)
    local o = ISBaseTimedAction.new(self, character)
    o.def = def
    o.body = body
    o.maxTime = math.floor((def.duration or 3) * 33)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end
