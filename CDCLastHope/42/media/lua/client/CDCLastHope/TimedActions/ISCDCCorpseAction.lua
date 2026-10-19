require "TimedActions/ISBaseTimedAction"

ISCDCCorpseAction = ISBaseTimedAction:derive("ISCDCCorpseAction")

function ISCDCCorpseAction:isValid()
    if self.def.requires and not CDC.findTool(self.character:getInventory(), self.def.requires) then return false end
    if self.def.cond and not self.def.cond(CDC.Context.new(self.character, nil)) then return false end
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
    CDC.Net.send(self.character, "grant", { kind = "corpse", id = self.def.id })
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
