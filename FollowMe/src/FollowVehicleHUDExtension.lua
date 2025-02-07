--
--  Follow Vehicle HUD-extension
--
-- @author  Decker_MMIV (DCK)
-- @contact forum.farming-simulator.com
-- @date    2025-01-xx
--

FollowVehicleHUDExtension = {}

local FollowVehicleHUDExtension_mt = Class(FollowVehicleHUDExtension, CommonHUDExtension)

function FollowVehicleHUDExtension.new(vehicle, customMt)
    local self = FollowVehicleHUDExtension:superClass().new(vehicle, customMt or FollowVehicleHUDExtension_mt)
    self.priority = self.priority - 0.5
    self.actionNames = {
        InputAction.FOLLOW_DISTANCE,
        InputAction.FOLLOW_SIDE_OFFSET,
        InputAction.FOLLOW_PAUSE_RESUME,
        InputAction.FOLLOW_TOOLACTION,
        InputAction.FOLLOW_MARKER_TOGGLE_OFFSET,
    }
    return self
end

function FollowVehicleHUDExtension:getHeight()
    self.toolActionText = self.vehicle:getSelectedToolActionText()
    return self.lineHeight * (3 + ((nil ~= self.toolActionText and 1) or 0))
end

local FOLLOW_SELF_FOLLOWING     = g_i18n:getText("FOLLOW_SELF_FOLLOWING")
local FOLLOW_SELF_DISTANCE      = g_i18n:getText("FOLLOW_SELF_DISTANCE")
local FOLLOW_SELF_SIDEOFFSET    = g_i18n:getText("FOLLOW_SELF_SIDEOFFSET")
local FOLLOW_SELF_WHENFULL      = g_i18n:getText("FOLLOW_SELF_WHENFULL")

function FollowVehicleHUDExtension:draw(inputHelpDisplay, posX, posY)
    local lineWidth, lineHeight = self.lineWidth, self.lineHeight
    local extraRows = (nil ~= self.toolActionText and 1) or 0
    self.backgroundTop   :renderCustom(posX, posY - lineHeight * 1, lineWidth, lineHeight)
    self.backgroundScale :renderCustom(posX, posY - lineHeight * (2 + extraRows), lineWidth, lineHeight * (1 + extraRows))
    self.backgroundBottom:renderCustom(posX, posY - lineHeight * (3 + extraRows), lineWidth, lineHeight)

    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)

    local textSize = inputHelpDisplay.textSize
    local textOffsetX = inputHelpDisplay.textOffsetX
    local textOffsetY = lineHeight - textSize

    local glyphsHeight = self.glyphsHeight

    local txt = self.vehicle:getCurrentStateText(false)
    if nil == txt then
        local leader = self.vehicle:getVehicleToFollow()
        if leader then
            txt = FOLLOW_SELF_FOLLOWING .. leader:getFullName()
        else
            txt = FOLLOW_SELF_FOLLOWING .. "???"
        end
    end
    posY = posY - lineHeight
    renderText(posX + textOffsetX, posY + textOffsetY, textSize, txt)
    self:drawActionGlyphs(InputAction.FOLLOW_PAUSE_RESUME, posX, posY, glyphsHeight, lineWidth)

    posY = posY - lineHeight
    renderText(posX + textOffsetX, posY + textOffsetY, textSize, FOLLOW_SELF_DISTANCE .. ("%.0f"):format(self.vehicle:getDistance()))
    self:drawActionGlyphs(InputAction.FOLLOW_DISTANCE, posX, posY, glyphsHeight, lineWidth)

    posY = posY - lineHeight
    renderText(posX + textOffsetX, posY + textOffsetY, textSize, FOLLOW_SELF_SIDEOFFSET .. ("%.1f"):format(self.vehicle:getSideOffset()))
    self:drawActionGlyphs(InputAction.FOLLOW_SIDE_OFFSET, posX, posY, glyphsHeight, lineWidth)

    if nil ~= self.toolActionText then
        posY = posY - lineHeight
        renderText(posX + textOffsetX, posY + textOffsetY, textSize, FOLLOW_SELF_WHENFULL .. self.toolActionText)
        self:drawActionGlyphs(InputAction.FOLLOW_TOOLACTION, posX, posY, glyphsHeight, lineWidth)
    end

    return posY
end
