if isServer() then return end
require "ISUI/ISPanel"
require "ISUI/ISRichTextPanel"
require "XpSystem/ISUI/ISCharacterInfoWindow"
require "CDCLastHope/CDCClient"
require "CDCLastHope/CDCQuestStatus"

CDCJournalPanel = ISPanel:derive("CDCJournalPanel")

function CDCJournalPanel:createChildren()
    self.text = ISRichTextPanel:new(0, 0, self.width, self.height)
    self.text:initialise()
    self.text.autosetheight = false
    self.text.clip = true
    self.text.marginLeft = 10
    self.text.marginRight = 10
    self.text:addScrollBars()
    self.text.anchorRight = true
    self.text.anchorBottom = true
    self:addChild(self.text)
    self.lastRefresh = 0
end

function CDCJournalPanel:refresh()
    local out = {}
    table.insert(out, "<RGB:1,1,1> <SIZE:medium> CDC Objectives <SIZE:small> <LINE> ")
    local items = CDC.State.isActive() and CDC.QuestStatus.current(CDC.State.get()) or {}
    if #items == 0 then
        table.insert(out, "<RGB:0.6,0.6,0.6> No active objectives. <LINE> ")
    end
    for _, line in ipairs(items) do
        table.insert(out, "<RGB:0.9,0.9,0.7> - " .. line .. " <LINE> ")
    end
    self.text:setText(table.concat(out))
    self.text:paginate()
end

function CDCJournalPanel:prerender()
    ISPanel.prerender(self)
    local now = getTimestampMs()
    if now - self.lastRefresh > 1500 then
        self.lastRefresh = now
        self:refresh()
    end
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
