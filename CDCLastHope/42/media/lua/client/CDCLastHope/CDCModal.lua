if isServer() then return end
require "CDCLastHope/CDC"

CDC.Modal = {}

-- opts: w, h, image (texture path), imageW, imageH
function CDC.Modal.show(player, text, opts)
    opts = opts or {}
    text = text or ""
    if opts.image then
        local tag = "<IMAGECENTRE:" .. opts.image
        if opts.imageW then tag = tag .. "," .. opts.imageW .. "," .. (opts.imageH or opts.imageW) end
        -- IMAGECENTRE only advances the cursor by half the image height, so body
        -- text would land on top of it; pad out the rest in blank lines
        local pad = "<LINE>"
        if text ~= "" and opts.imageH then
            local lh = getTextManager():getFontHeight(UIFont.Small)
            pad = string.rep("<LINE>", math.ceil((opts.imageH / 2) / lh) + 1)
        end
        text = tag .. "> " .. pad .. " " .. text
    end
    if text == "" then return end
    local pn = player:getPlayerNum()
    local w = opts.w or 380
    local h = opts.h or 160
    local x = getPlayerScreenLeft(pn) + (getPlayerScreenWidth(pn) - w) / 2
    local y = getPlayerScreenTop(pn) + (getPlayerScreenHeight(pn) - h) / 2
    local modal = ISModalRichText:new(x, y, w, h, tostring(text), false, nil, nil, pn)
    modal:initialise()
    modal:addToUIManager()
end
