require "TimedActions/ISBaseTimedAction"

ISCDCGroundAction = ISBaseTimedAction:derive("ISCDCGroundAction")

function ISCDCGroundAction:isValid()
    if self.def.requires and not CDC.findTool(self.character:getInventory(), self.def.requires) then return false end
    if self.def.cond and not self.def.cond(CDC.Context.new(self.character, nil), self.square) then return false end
    return true
end

function ISCDCGroundAction:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
end

function ISCDCGroundAction:start()
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Low")
end

function ISCDCGroundAction:perform()
    local inv = self.character:getInventory()
    if self.def.requires and self.def.consumes then
        local tool = CDC.findTool(inv, self.def.requires)
        if tool then inv:Remove(tool) end
    end
    if self.def.gives then inv:AddItem(self.def.gives) end
    CDC.Modal.show(self.character, self.def.text)
    ISBaseTimedAction.perform(self)
end

function ISCDCGroundAction:new(character, def, square)
    local o = ISBaseTimedAction.new(self, character)
    o.def = def
    o.square = square
    o.maxTime = math.floor((def.duration or 3) * 33)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end
