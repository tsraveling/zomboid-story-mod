if isServer() then return end
require "ISUI/ISPanel"
require "ISUI/ISRichTextPanel"
require "XpSystem/ISUI/ISCharacterInfoWindow"
require "CDCLastHope/CDCClient"
require "CDCLastHope/CDCQuestStatus"

CDCJournalPanel = ISPanel:derive("CDCJournalPanel")

local MIN_WIDTH = 400
local MIN_HEIGHT = 400
local TAB_PAD = 10

function CDCJournalPanel:createChildren()
    self.text = ISRichTextPanel:new(0, 0, self.width, self.height)
    self.text:initialise()
    self.text.autosetheight = false
    self.text.clip = true
    self.text.background = false
    self.text.marginLeft = 10
    self.text.marginRight = 30
    self.text:addScrollBars()
    self.text.anchorRight = true
    self.text.anchorBottom = true
    self:addChild(self.text)
    self.lastRefresh = 0
end

function CDCJournalPanel:refresh()
    local out = {}
    table.insert(out, "<RGB:1,1,1> <SIZE:medium> CDC Objectives <LINE> <SIZE:small> <LINE> ")
    local items = CDC.State.isActive() and CDC.QuestStatus.current(CDC.State.get()) or {}
    if #items == 0 then
        table.insert(out, "<RGB:0.6,0.6,0.6> No active objectives. <LINE> ")
    end
    for _, line in ipairs(items) do
        table.insert(out, "<RGB:0.9,0.9,0.7> - " .. line .. " <LINE> ")
    end
    local done = CDC.QuestStatus.done(CDC.State.get())
    if #done > 0 then
        table.insert(out, " <LINE> <RGB:1,1,1> <SIZE:medium> Completed Quests <LINE> <SIZE:small> <LINE> ")
        for _, line in ipairs(done) do
            table.insert(out, "<RGB:0.6,0.8,0.6> - " .. line .. " <LINE> ")
        end
    end
    self.text:setText(table.concat(out))
    self.text:paginate()
end

function CDCJournalPanel:prerender()
    ISPanel.prerender(self)
    local w = self:desiredWidth()
    if w ~= self.width or (self.parent and self.parent.width ~= w) then
        self:setWidthAndParentWidth(w)
        self.text:setWidth(w)
        self.lastRefresh = 0
    end
    self:fitHeight()
    local now = getTimestampMs()
    if now - self.lastRefresh > 1500 then
        self.lastRefresh = now
        self:refresh()
    end
end

-- fill the window vertically, growing it to MIN_HEIGHT if needed
function CDCJournalPanel:fitHeight()
    if not self.parent then return end
    local avail = self.parent.height - self:getY()
    local h = math.max(avail, MIN_HEIGHT)
    if h == self.height and h == self.text.height then return end
    if h > avail then self:setHeightAndParentHeight(h) else self:setHeight(h) end
    self.text:setHeight(h)
    self.lastRefresh = 0
end

-- wide enough for the full tab strip, like vanilla tabs
function CDCJournalPanel:desiredWidth()
    local tabs = self.parent
    if not tabs or not tabs.viewList then return math.max(self.width, MIN_WIDTH) end
    local w = 2
    for _, v in ipairs(tabs.viewList) do w = w + v.tabWidth + 1 end
    return math.max(w + TAB_PAD * 2, MIN_WIDTH)
end

function CDCJournalPanel:new(x, y, w, h, playerNum)
    local o = ISPanel.new(self, x, y, w, h)
    o.playerNum = playerNum
    o.background = false
    return o
end

-- add a CDC tab to the character info window
local origCreateChildren = ISCharacterInfoWindow.createChildren
function ISCharacterInfoWindow:createChildren()
    origCreateChildren(self)
    self.cdcView = CDCJournalPanel:new(0, 8, self.panel.width, self.height - 8, self.playerNum)
    self.cdcView:initialise()
    self.cdcView.infoText = "CDC Last Hope objectives."
    self.panel:addView("CDC", self.cdcView)
end
