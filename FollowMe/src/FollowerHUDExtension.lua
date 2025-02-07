--
--  Follow Vehicle HUD-extension
--
-- @author  Decker_MMIV (DCK)
-- @contact forum.farming-simulator.com
-- @date    2025-01-xx
--

FollowerHUDExtension = {}

local FollowerHUDExtension_mt = Class(FollowerHUDExtension, CommonHUDExtension)

function FollowerHUDExtension.new(vehicle, customMt)
    local self = FollowVehicleHUDExtension:superClass().new(vehicle, customMt or FollowerHUDExtension_mt)
    --self.priority = self.priority + 0.5
    self.actionNames = {
        InputAction.FOLLOW_CHASER_CHOOSE,
        InputAction.FOLLOW_CHASER_DISTANCE,
        InputAction.FOLLOW_CHASER_SIDE_OFFSET,
        InputAction.FOLLOW_CHASER_PAUSE_RESUME,
        InputAction.FOLLOW_CHASER_TOOLACTION,
    }
    return self
end

function FollowerHUDExtension:getHeight()
    local follower = self.vehicle:getSelectedFollower()
    if follower then
        self.toolActionText = follower:getSelectedToolActionText()
        self.followerStateText = follower:getCurrentStateText(true)
    else
        self.toolActionText = nil
        self.followerStateText = nil
    end
    return self.lineHeight * (3 + ((nil ~= self.toolActionText and 1) or 0) + ((nil ~= self.followerStateText and 1) or 0))
end

local FOLLOW_OTHER_SELECTED     = g_i18n:getText("FOLLOW_OTHER_SELECTED")
local FOLLOW_OTHER_STATE        = g_i18n:getText("FOLLOW_OTHER_STATE")
local FOLLOW_OTHER_DISTANCE     = g_i18n:getText("FOLLOW_OTHER_DISTANCE")
local FOLLOW_OTHER_SIDEOFFSET   = g_i18n:getText("FOLLOW_OTHER_SIDEOFFSET")
local FOLLOW_OTHER_WHENFULL     = g_i18n:getText("FOLLOW_OTHER_WHENFULL")

function FollowerHUDExtension:draw(inputHelpDisplay, posX, posY)
    local lineWidth, lineHeight = self.lineWidth, self.lineHeight
    local extraRows = ((nil ~= self.toolActionText and 1) or 0) + ((nil ~= self.followerStateText and 1) or 0)
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

    local follower = self.vehicle:getSelectedFollower()
    local txt, distance, sideOffset
    if follower then
        txt = FOLLOW_OTHER_SELECTED .. follower:getFullName()
        distance = follower:getDistance()
        sideOffset = follower:getSideOffset()
    else
        txt = FOLLOW_OTHER_SELECTED .. "???"
        distance = 0
        sideOffset = 0
    end
    posY = posY - lineHeight
    renderText(posX + textOffsetX, posY + textOffsetY, textSize, txt)
    self:drawActionGlyphs(InputAction.FOLLOW_CHASER_CHOOSE, posX, posY, glyphsHeight, lineWidth)

    if self.followerStateText then
        posY = posY - lineHeight
        renderText(posX + textOffsetX, posY + textOffsetY, textSize, FOLLOW_OTHER_STATE .. self.followerStateText)
        self:drawActionGlyphs(InputAction.FOLLOW_CHASER_PAUSE_RESUME, posX, posY, glyphsHeight, lineWidth)
    end

    posY = posY - lineHeight
    renderText(posX + textOffsetX, posY + textOffsetY, textSize, FOLLOW_OTHER_DISTANCE .. ("%.0f"):format(distance))
    self:drawActionGlyphs(InputAction.FOLLOW_CHASER_DISTANCE, posX, posY, glyphsHeight, lineWidth)

    posY = posY - lineHeight
    renderText(posX + textOffsetX, posY + textOffsetY, textSize, FOLLOW_OTHER_SIDEOFFSET .. ("%.1f"):format(sideOffset))
    self:drawActionGlyphs(InputAction.FOLLOW_CHASER_SIDE_OFFSET, posX, posY, glyphsHeight, lineWidth)

    if nil ~= self.toolActionText then
        posY = posY - lineHeight
        renderText(posX + textOffsetX, posY + textOffsetY, textSize, FOLLOW_OTHER_WHENFULL .. self.toolActionText)
        self:drawActionGlyphs(InputAction.FOLLOW_CHASER_TOOLACTION, posX, posY, glyphsHeight, lineWidth)
    end

    return posY
end
