if isServer() then return end
require "CDCLastHope/CDCClient"
require "CDCLastHope/CDCWorld"
require "CDCLastHope/CDCDialogue"
require "CDCLastHope/TimedActions/ISCDCTransmitAction"
require "CDCLastHope/TimedActions/ISCDCPickupAction"
require "CDCLastHope/TimedActions/ISCDCCorpseAction"
require "CDCLastHope/TimedActions/ISCDCUplinkAction"

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

function M.uplink(player, radio, site)
    if luautils.walkAdj(player, radio:getSquare()) then
        ISTimedActionQueue.add(ISCDCUplinkAction:new(player, radio, site))
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

function M.addRadioOptions(player, context, radio, active)
    if active and CDC.isRadioLive(radio) and CDC.isOnFrequency(radio) then
        context:addOption("Transmit", player, M.transmit, radio)
    end
    context:addOption("View transmission log", player, function(pl, r) CDC.Dialogue.open(pl, r, true) end, radio)
    if active then
        local sq = radio:getSquare()
        local site = CDC.Sites.at(sq:getX(), sq:getY())
        if site and not CDC.State.uplinkOf(radio) then
            local opt = context:addOption("Connect to uplink (" .. tostring(site.name) .. ")", player, M.uplink, radio, site)
            local ok = CDC.Uplink.meetsRequirements(player, site)
            opt.notAvailable = not ok
            tooltip(opt, "Requires: " .. CDC.Uplink.requirementText(site))
        end
    end
end

function M.addPickupOptions(player, context, squares)
    for _, def in ipairs(CDC.story.world.pickups) do
        for _, sq in ipairs(squares) do
            if sq:getX() == def.x and sq:getY() == def.y and sq:getZ() == def.z then
                local spriteOk = true
                if def.sprite then
                    spriteOk = false
                    for i = 0, sq:getObjects():size() - 1 do
                        local o = sq:getObjects():get(i)
                        if o:getSprite() and o:getSprite():getName() == def.sprite then spriteOk = true end
                    end
                end
                if spriteOk and CDC.Pickup.available(def, player) then
                    local opt = context:addOption(def.label or ("Take " .. tostring(def.item)), player, M.pickup, def, sq)
                    if def.cond then
                        local ctx = CDC.Context.new(player, nil)
                        if not def.cond(ctx, sq) then
                            opt.notAvailable = true
                            if def.condFailText then tooltip(opt, def.condFailText) end
                        end
                    end
                end
            end
        end
    end
end

function M.addCorpseOptions(player, context)
    local body = ISWorldObjectContextMenu.fetchVars and ISWorldObjectContextMenu.fetchVars.body
    if not body or body:isAnimal() then return end
    for _, def in ipairs(CDC.story.world.corpseActions) do
        local opt = context:addOption(def.label or def.id, player, M.corpse, def, body)
        if def.requires and not player:getInventory():containsTypeRecurse(def.requires) then
            opt.notAvailable = true
            tooltip(opt, "Requires: " .. tostring(def.requires))
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
    if active then
        M.addPickupOptions(player, context, squares)
        M.addCorpseOptions(player, context)
    end
    if CDC.Debug then CDC.Debug.fill(player, context, squares) end
end

Events.OnFillWorldObjectContextMenu.Add(M.onFill)
