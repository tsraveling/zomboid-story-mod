if isServer() then return end
require "CDCLastHope/CDC"

CDC.Modal = {}

function CDC.Modal.show(player, text)
    if not text or text == "" then return end
    local pn = player:getPlayerNum()
    local w, h = 380, 160
    local x = getPlayerScreenLeft(pn) + (getPlayerScreenWidth(pn) - w) / 2
    local y = getPlayerScreenTop(pn) + (getPlayerScreenHeight(pn) - h) / 2
    local modal = ISModalRichText:new(x, y, w, h, tostring(text), false, nil, nil, pn)
    modal:initialise()
    modal:addToUIManager()
end
