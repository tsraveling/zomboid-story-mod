if isServer() then return end
require "ISUI/ISPanel"
require "ISUI/ISRichTextPanel"
require "XpSystem/ISUI/ISCharacterInfoWindow"
require "CDCLastHope/CDCClient"

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
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    local out = {}
    table.insert(out, "<RGB:1,1,1> <SIZE:medium> CDC Objectives <SIZE:small> <LINE> ")
    if not CDC.State.isActive() then
        table.insert(out, "<RGB:0.6,0.6,0.6> Nothing yet. <LINE> ")
    else
        local ctx = CDC.Context.new(player, nil)
        local n = 0
        for _, j in ipairs(CDC.story.journal) do
            if j.cond == nil or j.cond(ctx) then
                n = n + 1
                table.insert(out, "<RGB:0.9,0.9,0.7> - " .. tostring(CDC.Story.resolve(j.text, ctx)) .. " <LINE> ")
            end
        end
        if n == 0 then table.insert(out, "<RGB:0.6,0.6,0.6> No active objectives. <LINE> ") end
    end
    table.insert(out, " <LINE> <RGB:1,1,1> <SIZE:medium> World History <SIZE:small> <LINE> ")
    local log = CDC.State.get().log
    if #log == 0 then
        table.insert(out, "<RGB:0.6,0.6,0.6> Nothing delivered yet. <LINE> ")
    else
        for i = #log, 1, -1 do
            local e = log[i]
            table.insert(out, string.format("<RGB:0.7,0.85,1> Day %d: %s delivered by %s (%s) <LINE> ",
                e.day or 0, CDC.Story.flagLabel(e.flag), tostring(e.characterName), tostring(e.username)))
        end
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
    self.cdcView.infoText = "CDC Last Hope objectives and world history."
    self.panel:addView("CDC", self.cdcView)
end
