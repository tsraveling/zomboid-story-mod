if isServer() then return end
require "CDCLastHope/CDCClient"
require "CDCLastHope/CDCWorld"
require "CDCLastHope/CDCDialogue"
require "CDCLastHope/CDCModal"
require "CDCLastHope/TimedActions/ISCDCTransmitAction"
require "CDCLastHope/TimedActions/ISCDCPickupAction"
require "CDCLastHope/TimedActions/ISCDCCorpseAction"
require "CDCLastHope/TimedActions/ISCDCGroundAction"
require "CDCLastHope/TimedActions/ISCDCLockerAction"

CDC.Menu = {}
local M = CDC.Menu

local function tooltip(option, text)
    local tt = ISToolTip:new()
    tt:initialise()
    tt:setVisible(false)
    tt.description = text
    option.toolTip = tt
end

local function squaresOf(worldobjects)
    local seen, out = {}, {}
    for _, obj in ipairs(worldobjects) do
        local sq = obj:getSquare()
        if sq and not seen[sq] then seen[sq] = true; table.insert(out, sq) end
    end
    return out
end

local function hamRadiosOn(squares)
    local out = {}
    for _, sq in ipairs(squares) do
        for i = 0, sq:getObjects():size() - 1 do
            local o = sq:getObjects():get(i)
            if CDC.isHamRadio(o) then table.insert(out, o) end
        end
    end
    return out
end

function M.transmit(player, radio)
    if luautils.walkAdj(player, radio:getSquare()) then
        ISTimedActionQueue.add(ISCDCTransmitAction:new(player, radio))
    end
end

function M.pickup(player, def, square)
    if luautils.walkAdj(player, square) then
        ISTimedActionQueue.add(ISCDCPickupAction:new(player, def, square))
    end
end

function M.corpse(player, def, body)
    if luautils.walkAdj(player, body:getSquare()) then
        ISTimedActionQueue.add(ISCDCCorpseAction:new(player, def, body))
    end
end

function M.ground(player, def, square)
    if luautils.walkAdj(player, square) then
        ISTimedActionQueue.add(ISCDCGroundAction:new(player, def, square))
    end
end

function M.locker(player, def, square)
    if luautils.walkAdj(player, square) then
        ISTimedActionQueue.add(ISCDCLockerAction:new(player, def, square))
    end
end

local DEFAULT_GROUND = { dirt = true, sand = true, clay = true }

local function groundOk(def, sq)
    if sq:getZ() ~= (def.z or 0) then return false end
    local dx, dy = sq:getX() - def.x, sq:getY() - def.y
    if dx * dx + dy * dy > def.radius * def.radius then return false end
    local kind = ISShovelGroundCursor.GetDirtGravelSand(sq)
    if not kind then return false end
    if def.ground then
        for _, g in ipairs(def.ground) do if g == kind then return true end end
        return false
    end
    return DEFAULT_GROUND[kind] == true
end

function M.addRadioOptions(player, context, radio, active)
    if active and CDC.isRadioLive(radio) and CDC.isOnFrequency(radio) then
        context:addOption("Transmit", player, M.transmit, radio)
    end
    context:addOption("View transmission log", player, function(pl, r) CDC.Dialogue.open(pl, r, true) end, radio)
end

local function onTile(def, sq)
    for _, t in ipairs(def.tiles) do
        if sq:getX() == t[1] and sq:getY() == t[2] and sq:getZ() == t[3] then return true end
    end
    return false
end

function M.addPickupOptions(player, context, squares)
    for _, def in ipairs(CDC.story.world.pickups) do
        for _, sq in ipairs(squares) do
            if onTile(def, sq) then
                local spriteOk = true
                if def.sprite then
                    local names = type(def.sprite) == "table" and def.sprite or { def.sprite }
                    spriteOk = false
                    for i = 0, sq:getObjects():size() - 1 do
                        local o = sq:getObjects():get(i)
                        local name = o:getSprite() and o:getSprite():getName()
                        for _, n in ipairs(names) do
                            if name == n then spriteOk = true end
                        end
                    end
                end
                local condOk = def.cond == nil or def.cond(CDC.Context.new(player, nil), sq)
                -- failing cond hides the option unless condFailText is set
                if spriteOk and CDC.Pickup.available(def, player) and (condOk or def.condFailText) then
                    local opt = context:addOption(def.label or ("Take " .. tostring(def.item)), player, M.pickup, def, sq)
                    if not condOk then
                        opt.notAvailable = true
                        tooltip(opt, def.condFailText)
                    end
                    break
                end
            end
        end
    end
end

-- not gated on isActive: the morgue is searchable whatever the story is doing
function M.addLockerOptions(player, context, squares)
    for _, def in ipairs(CDC.story.world.lockers or {}) do
        for _, sq in ipairs(squares) do
            if onTile(def, sq) then
                context:addOption(def.label or "Check locker", player, M.locker, def, sq)
                break
            end
        end
    end
end

function M.addCorpseOptions(player, context)
    local body = ISWorldObjectContextMenu.fetchVars and ISWorldObjectContextMenu.fetchVars.body
    if not body or body:isAnimal() then return end
    local flag = body:getModData().CDCCorpse
    local ctx = CDC.Context.new(player, nil)
    for _, def in ipairs(CDC.story.world.corpseActions) do
        if def.corpse == flag and (def.cond == nil or def.cond(ctx)) then
            local opt = context:addOption(def.label or def.id, player, M.corpse, def, body)
            if def.requires and not CDC.findTool(player:getInventory(), def.requires) then
                opt.notAvailable = true
                tooltip(opt, "Requires: " .. tostring(def.requiresLabel or def.requires))
            end
        end
    end
end

function M.addGroundOptions(player, context, squares)
    local ctx = CDC.Context.new(player, nil)
    for _, def in ipairs(CDC.story.world.groundActions or {}) do
        for _, sq in ipairs(squares) do
            if groundOk(def, sq) and (def.cond == nil or def.cond(ctx, sq)) then
                local opt = context:addOption(def.label or def.id, player, M.ground, def, sq)
                if def.requires and not CDC.findTool(player:getInventory(), def.requires) then
                    opt.notAvailable = true
                    tooltip(opt, "Requires: " .. tostring(def.requiresLabel or def.requires))
                end
                break
            end
        end
    end
end

function M.read(player, def)
    CDC.Modal.show(player, def.text)
end

-- entries are either an item or a stack table
local function selectedItems(items)
    local out = {}
    for _, v in ipairs(items) do
        if not instanceof(v, "InventoryItem") then v = v.items and v.items[1] end
        if v then table.insert(out, v) end
    end
    return out
end

function M.onFillInventory(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local seen = {}
    for _, item in ipairs(selectedItems(items)) do
        local full = item:getFullType()
        if not seen[full] then
            seen[full] = true
            local def = CDC.Story.readable(full)
            if def then context:addOption(def.label or "Read", player, M.read, def) end
        end
    end
end

function M.onFill(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local active = CDC.State.isActive()
    local squares = squaresOf(worldobjects)

    for _, radio in ipairs(hamRadiosOn(squares)) do
        M.addRadioOptions(player, context, radio, active)
    end
    M.addLockerOptions(player, context, squares)
    if active then
        M.addPickupOptions(player, context, squares)
        M.addCorpseOptions(player, context)
        M.addGroundOptions(player, context, squares)
    end
    if CDC.Debug then CDC.Debug.fill(player, context, squares) end
end

Events.OnFillWorldObjectContextMenu.Add(M.onFill)
Events.OnFillInventoryObjectContextMenu.Add(M.onFillInventory)
