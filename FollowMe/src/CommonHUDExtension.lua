--
--  Follow Vehicle HUD-extension
--
-- @author  Decker_MMIV (DCK)
-- @contact forum.farming-simulator.com
-- @date    2025-01-xx
--

CommonHUDExtension = {}

local CommonHUDExtension_mt = Class(CommonHUDExtension)

function CommonHUDExtension.new(vehicle, customMt)
    local self = setmetatable({}, customMt or CommonHUDExtension_mt)

    self.priority = GS_PRIO_HIGH

    local r, g, b, a = unpack(HUD.COLOR.BACKGROUND)
    self.backgroundTop = g_overlayManager:createOverlay("gui.hudExtension_top", 0, 0, 0, 0)
    self.backgroundTop:setColor(r, g, b, a)
    self.backgroundScale = g_overlayManager:createOverlay("gui.hudExtension_middle", 0, 0, 0, 0)
    self.backgroundScale:setColor(r, g, b, a)
    self.backgroundBottom = g_overlayManager:createOverlay("gui.hudExtension_bottom", 0, 0, 0, 0)
    self.backgroundBottom:setColor(r, g, b, a)

    --self.separatorHorizontal = g_overlayManager:createOverlay(g_plainColorSliceId, 0, 0, 0, 0)
    --self.separatorHorizontal:setColor(1, 1, 1, 0.25)

    self.vehicle = vehicle
    self.actions = nil
    self.actionNames = {}

    self.keyboardOverlay = ButtonOverlay.new()
    self.keyboardOverlay:setColor(1, 1, 1, 1, 0, 0, 0, 0.80)

    --self:storeScaledValues()

    return self
end

function CommonHUDExtension:delete()
    self.keyboardOverlay:delete()
    --self.separatorHorizontal:delete()
    self.backgroundTop:delete()
    self.backgroundScale:delete()
    self.backgroundBottom:delete()
end

--function CommonHUDExtension:storeScaledValues()
--    -- TODO - Missing sample in Giants Software's public gameSource.zip :-(
--end

function CommonHUDExtension:buildActionsKeys(textSize)
    local buildElement = function(actionName)
        if actionName then
            local actionName2, noModifiers, customBinding = nil,nil,nil
            local helpElement = g_inputDisplayManager:getControllerSymbolOverlays(actionName, actionName2, "", noModifiers, customBinding)
            if #helpElement.keys > 0 then
                local width = 0
                for _, key in ipairs(helpElement.keys) do
                    width = width + self.keyboardOverlay:getButtonWidth(key, textSize)
                end
                return {
                    totalWidth = width,
                    keys = helpElement.keys,
                }
            end
        end
        return nil
    end

    self.actions = {}
    for _, actionName in pairs(self.actionNames) do
        self.actions[actionName] = buildElement(actionName)
    end
end

function CommonHUDExtension:setEventHelpElements(inputHelpDisplay, eventHelpElements)
    if nil == inputHelpDisplay.lineBg then
        self.lineWidth, self.lineHeight = 0,0
        return
    end
    self.lineWidth, self.lineHeight = inputHelpDisplay.lineBg.width, inputHelpDisplay.lineBg.height

    if nil == self.actions then
        self.glyphsHeight = inputHelpDisplay.textSize * 1.3
        self:buildActionsKeys(self.glyphsHeight)
    end
end

function CommonHUDExtension:getHeight()
    return 0
end

function CommonHUDExtension:draw(inputHelpDisplay, posX, posY)
    return 0
end

function CommonHUDExtension:drawActionGlyphs(actionName, posX, posY, glyphsHeight, lineWidth)
    if self.actions then
       local actionElement = self.actions[actionName]
        if actionElement then
            posX = posX + lineWidth - actionElement.totalWidth
            for i, key in ipairs(actionElement.keys) do
                posX = posX + self.keyboardOverlay:renderButton(key, posX, posY, glyphsHeight, true)
            end
        end
    end
end
