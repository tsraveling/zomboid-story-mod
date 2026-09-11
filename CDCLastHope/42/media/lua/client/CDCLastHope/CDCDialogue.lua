if isServer() then return end
require "ISUI/ISCollapsableWindow"
require "ISUI/ISRichTextPanel"
require "ISUI/ISButton"
require "CDCLastHope/CDCClient"

ISCDCDialogue = ISCollapsableWindow:derive("ISCDCDialogue")

CDC.Dialogue = { instance = nil, reqCounter = 0 }
local D = CDC.Dialogue

local BTN_H, PAD, LOG_H = 26, 8, 260

function D.open(player, radio, readOnly)
    if D.instance then D.instance:close() end
    local pn = player:getPlayerNum()
    local w, h = 520, LOG_H + 120
    local x = getPlayerScreenLeft(pn) + (getPlayerScreenWidth(pn) - w) / 2
    local y = getPlayerScreenTop(pn) + (getPlayerScreenHeight(pn) - h) / 2
    local win = ISCDCDialogue:new(x, y, w, h, player, radio, readOnly)
    win:initialise()
    win:addToUIManager()
    win:setVisible(true)
    D.instance = win
    pcall(function() player:playSound(readOnly and "RadioButton" or "RadioStatic") end)
    if readOnly then win:refreshLog() else win:begin() end
    return win
end

function D.onCommitResult(args)
    local inst = D.instance
    if not inst or not inst.pending or inst.pending.reqId ~= args.reqId then return end
    local p = inst.pending
    inst.pending = nil
    if args.ok then
        for _, f in ipairs(p.fns) do f(inst.ctx) end
        inst:route(p.choice)
    else
        inst:showNode("alreadyDone")
    end
end

local function clean(s)
    return tostring(s or ""):gsub("<", "("):gsub(">", ")")
end

local function rgb(c)
    return string.format("<RGB:%.2f,%.2f,%.2f>", c.r, c.g, c.b)
end

function ISCDCDialogue:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    self.log = ISRichTextPanel:new(0, th, self.width, LOG_H)
    self.log:initialise()
    self.log.autosetheight = false
    self.log.clip = true
    self.log.marginLeft = 10
    self.log.marginRight = 10
    self.log:addScrollBars()
    self:addChild(self.log)
    self.buttons = {}
    if self.readOnly then
        self:buildButtons({ { label = "Close", onClick = function() self:close() end } })
    end
end

function ISCDCDialogue:begin()
    self.ctx = CDC.Context.new(self.player, self.radio)
    self.player:getModData().CDCIntroSeen = true
    self.history = {}
    for _, l in ipairs(CDC.State.get().txlog) do table.insert(self.history, l) end
    self.lines = {}
    local id = CDC.story.entry(self.ctx) or "noResponse"
    self:showNode(id)
end

function ISCDCDialogue:showNode(id)
    local node = CDC.Story.node(id) or CDC.Story.node("noResponse")
    if not node then self:close(); return end
    self.node = node
    local text = CDC.Story.text(node, self.ctx)
    self:say("CDC", text, CDC.COLOR_CDC)
    self:emitFloat(text, CDC.COLOR_CDC)
    local choices = CDC.Story.visibleChoices(node, self.ctx)
    local defs = {}
    for _, c in ipairs(choices) do
        table.insert(defs, { label = clean(CDC.Story.resolve(c.text, self.ctx)), choice = c, onClick = function() self:onChoice(c) end })
    end
    if #defs == 0 then
        table.insert(defs, { label = "End transmission", onClick = function() self:close() end })
    end
    self:buildButtons(defs)
end

function ISCDCDialogue:say(who, text, color)
    table.insert(self.lines, { who = who, text = text, color = color })
    CDC.Net.send(self.player, "txlog", { who = who, text = text, color = color })
    self:refreshLog()
end

function ISCDCDialogue:emitFloat(text, color)
    local sq = self.radio:getSquare()
    CDC.Net.send(self.player, "floatText", { x = sq:getX(), y = sq:getY(), z = sq:getZ(), text = text, color = color })
end

function ISCDCDialogue:onChoice(c)
    if self.pending then return end
    local text = tostring(CDC.Story.resolve(c.text, self.ctx))
    self:say(self.ctx.name, text, CDC.COLOR_PLAYER)
    self:emitFloat(text, CDC.COLOR_PLAYER)
    local pc = CDC.COLOR_PLAYER
    local ok = pcall(function() self.player:Say(text, pc.r, pc.g, pc.b, UIFont.Dialogue, 30, "default") end)
    if not ok then self.player:Say(text) end

    local ops, xp, fns = {}, {}, {}
    for _, e in ipairs(c.effects or {}) do
        if e.type == "xp" then table.insert(xp, { perk = e.perk, amount = e.amount })
        elseif e.type == "fn" then table.insert(fns, e.fn)
        else table.insert(ops, e) end
    end
    if #ops > 0 or #xp > 0 then
        D.reqCounter = D.reqCounter + 1
        self.pending = { reqId = D.reqCounter, choice = c, fns = fns }
        self:buildButtons({ { label = "Transmitting...", disabled = true } })
        local sq = self.radio:getSquare()
        CDC.Net.send(self.player, "commit", { reqId = D.reqCounter, ops = ops, xp = xp, x = sq:getX(), y = sq:getY(), z = sq:getZ() })
    else
        for _, f in ipairs(fns) do f(self.ctx) end
        self:route(c)
    end
end

function ISCDCDialogue:route(c)
    local nxt = c.next
    if type(nxt) == "function" then nxt = nxt(self.ctx) end
    if nxt == nil then self:close() else self:showNode(nxt) end
end

function ISCDCDialogue:buildButtons(defs)
    for _, b in ipairs(self.buttons) do self:removeChild(b) end
    self.buttons = {}
    local y = self:titleBarHeight() + LOG_H + PAD
    for _, d in ipairs(defs) do
        local btn = ISButton:new(PAD, y, self.width - PAD * 2, BTN_H, d.label, self, function() if d.onClick then d.onClick() end end)
        btn:initialise()
        btn:instantiate()
        btn.enable = not d.disabled
        self:addChild(btn)
        table.insert(self.buttons, btn)
        y = y + BTN_H + 4
    end
    self:setHeight(y + PAD + self:resizeWidgetHeight())
end

function ISCDCDialogue:refreshLog()
    local hist = self.history
    if self.readOnly then hist = CDC.State.get().txlog end
    local out = {}
    local function line(l)
        local c = l.color or CDC.COLOR_CDC
        table.insert(out, rgb(c) .. clean(l.who) .. ": " .. clean(l.text) .. " <LINE> ")
    end
    for _, l in ipairs(hist) do line(l) end
    if self.lines and #self.lines > 0 then
        if #hist > 0 then table.insert(out, "<RGB:0.5,0.5,0.5> --- <LINE> ") end
        for _, l in ipairs(self.lines) do line(l) end
    end
    if #out == 0 then table.insert(out, "<RGB:0.5,0.5,0.5> (no transmissions logged) ") end
    self.log:setText(table.concat(out))
    self.log:paginate()
    self.log:setYScroll(-math.max(0, self.log:getScrollHeight() - self.log:getHeight()))
end

function ISCDCDialogue:prerender()
    ISCollapsableWindow.prerender(self)
    if self.readOnly then
        local seq = CDC.State.get().meta.seq
        if seq ~= self.lastSeq then self.lastSeq = seq; self:refreshLog() end
    end
end

function ISCDCDialogue:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function ISCDCDialogue:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:close() end
end

function ISCDCDialogue:close()
    pcall(function() self.player:playSound("RadioButton") end)
    self:removeFromUIManager()
    if D.instance == self then D.instance = nil end
end

function ISCDCDialogue:new(x, y, w, h, player, radio, readOnly)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.player = player
    o.radio = radio
    o.readOnly = readOnly
    o.title = readOnly and "CDC Transmission Log" or "CDC Transmission"
    o.resizable = false
    o.pin = false
    return o
end
