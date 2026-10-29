if isServer() then return end
require "RadioCom/RadioWindowModules/RWMMicrophone"
require "CDCLastHope/CDCContextMenu"

-- Transmit button under Mute Microphone in the vanilla radio UI, same action as
-- the world context menu option. Vanilla methods are chained, not replaced.

local BUTTON_HGT = getTextManager():getFontHeight(UIFont.Small) + 6
local GAP = 4

-- captured once and parked on CDC so a Lua reload does not re-wrap our own
-- overrides, which would recurse forever
CDC.RadioPanelBase = CDC.RadioPanelBase or {
    createChildren = RWMMicrophone.createChildren,
    update = RWMMicrophone.update,
    onJoypadDown = RWMMicrophone.onJoypadDown,
    getBPrompt = RWMMicrophone.getBPrompt,
}
local base = CDC.RadioPanelBase

-- same terms as CDC.Menu.addRadioOptions; the button greys out rather than
-- hiding, so the panel height stays put while the player tunes
local function canTransmit(self)
    if not self.player or not self.device or self.deviceType ~= "IsoObject" then return false end
    if not CDC.State.isActive() then return false end
    if not CDC.isHamRadio(self.device) then return false end
    return CDC.isRadioLive(self.device) and CDC.isOnFrequency(self.device)
end

function RWMMicrophone:createChildren()
    base.createChildren(self)
    local mute = self.muteButton
    local b = ISButton:new(mute:getX(), mute:getY() + mute:getHeight() + GAP,
        mute:getWidth(), BUTTON_HGT, "Transmit", self, RWMMicrophone.onCDCTransmit)
    b:initialise()
    b.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    b.backgroundColorMouseOver = { r = 1.0, g = 1.0, b = 1.0, a = 0.1 }
    b.borderColor = { r = 1.0, g = 1.0, b = 1.0, a = 0.3 }
    self:addChild(b)
    self.cdcTransmit = b
    self:setHeight(self:getHeight() + GAP + BUTTON_HGT)
end

function RWMMicrophone:onCDCTransmit()
    if canTransmit(self) then CDC.Menu.transmit(self.player, self.device) end
end

function RWMMicrophone:update()
    base.update(self)
    if self.cdcTransmit then self.cdcTransmit:setEnable(canTransmit(self)) end
end

function RWMMicrophone:onJoypadDown(button)
    if button == Joypad.BButton and self.cdcTransmit and self.cdcTransmit.enable then
        return self:onCDCTransmit()
    end
    if base.onJoypadDown then return base.onJoypadDown(self, button) end
end

function RWMMicrophone:getBPrompt()
    if self.cdcTransmit and self.cdcTransmit.enable then return "Transmit" end
    return base.getBPrompt and base.getBPrompt(self) or nil
end
