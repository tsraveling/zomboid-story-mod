if isServer() then return end
require "ISUI/ISCollapsableWindow"
require "ISUI/ISRichTextPanel"
require "ISUI/ISButton"
require "CDCLastHope/CDCConvo"
require "CDCLastHope/TimedActions/ISCDCJobAction"

ISCDCDialogue = ISCollapsableWindow:derive("ISCDCDialogue")

CDC.Dialogue = { instance = nil }
local D = CDC.Dialogue

local BTN_H, PAD, LOG_H = 26, 8, 260

local COLORS = {
    player = CDC.COLOR_PLAYER,
    cdc = CDC.COLOR_CDC,
    radio = CDC.COLOR_RADIO,
    other = CDC.COLOR_OTHER,
    narration = CDC.COLOR_NARRATION,
    reward = CDC.COLOR_REWARD,
}

-- tag: optional block tag to start at (debug)
function D.open(player, radio, readOnly, tag)
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
    if readOnly then win:refreshLog() else win:begin(tag) end
    return win
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

function ISCDCDialogue:begin(tag)
    self.history = {}
    for _, l in ipairs(CDC.State.get().txlog) do table.insert(self.history, l) end
    self.lines = {}
    self.convo = CDC.Convo.new(self.player, self.radio, self)
    self.convo:begin(tag)
end

-- SECTION: Convo view

function ISCDCDialogue:line(kind, who, text)
    local color = COLORS[kind] or CDC.COLOR_OTHER
    local l = { who = who, text = text, color = color }
    table.insert(self.lines, l)
    CDC.Net.send(self.player, "txlog", l)
    self:refreshLog()
    if kind == "player" then
        self:floatPlayer(text, color)
    elseif kind == "other" then
        self:floatRadio(who .. ": " .. text, color)
    elseif kind ~= "narration" and kind ~= "reward" then
        self:floatRadio(text, color)
    end
end

function ISCDCDialogue:waiting()
    self:buildButtons({ { label = "Continue", onClick = function() self.convo:continue() end } })
end

-- unavailable options show grayed only when their text starts with "(", e.g. "(Doctor 4) ..."
local function showLocked(text)
    return text:match("^%s*%(") ~= nil
end

function ISCDCDialogue:options(opts)
    local defs, any = {}, false
    for i, o in ipairs(opts) do
        any = any or o.available
        if o.available or showLocked(o.text) then
            table.insert(defs, { label = clean(o.text), disabled = not o.available, onClick = function() self.convo:choose(i) end })
        end
    end
    if not any then
        table.insert(defs, { label = "Continue", onClick = function() self.convo:choose(nil) end })
    end
    self:buildButtons(defs)
end

function ISCDCDialogue:working(key, duration, progress)
    self:buildButtons({ { label = "Working...", disabled = true } })
    self.job = ISCDCJobAction:new(self.player, self.radio, key, duration, progress, self)
    ISTimedActionQueue.add(self.job)
end

function ISCDCDialogue:ended(reason)
    if reason == "interrupted" then self:close(); return end
    self:buildButtons({ { label = "End transmission", onClick = function() self:close() end } })
end

-- SECTION: Job callbacks (ISCDCJobAction)

function ISCDCDialogue:onJobDone()
    self.job = nil
    self.convo:jobDone()
end

function ISCDCDialogue:onJobStopped()
    if not self.job then return end
    self.job = nil
    self.convo:jobInterrupted()
end

-- SECTION: Rendering

function ISCDCDialogue:floatRadio(text, color)
    local sq = self.radio:getSquare()
    CDC.Net.send(self.player, "floatText", { x = sq:getX(), y = sq:getY(), z = sq:getZ(), text = text, color = color })
end

function ISCDCDialogue:floatPlayer(text, color)
    local p = self.player
    CDC.Net.send(p, "floatText", {
        x = math.floor(p:getX()), y = math.floor(p:getY()), z = math.floor(p:getZ()),
        text = text, color = color, onlineId = p:getOnlineID(),
    })
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
        if d.disabled then btn.textColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 } end
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
        local prefix = (l.who and l.who ~= "") and (clean(l.who) .. ": ") or ""
        if #out > 0 then table.insert(out, "<LINE> ") end
        table.insert(out, rgb(c) .. prefix .. clean(l.text) .. " <LINE> ")
    end
    for _, l in ipairs(hist or {}) do line(l) end
    if self.lines and #self.lines > 0 then
        if #hist > 0 then table.insert(out, "<LINE> <RGB:0.5,0.5,0.5> --- <LINE> ") end
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
    if self.closed then return end
    self.closed = true
    local job = self.job
    if job and job.action then
        job:forceStop()
    elseif job then
        ISTimedActionQueue.clear(self.player)
        self:onJobStopped()
    end
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
