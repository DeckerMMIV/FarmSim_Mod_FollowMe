--
--  Follow Vehicle
--
-- @author  Decker_MMIV (DCK)
-- @contact forum.farming-simulator.com
-- @date    2021-12-xx
--

-- For debugging
local function log(...)
    if true then
        local txt = ""
        for idx = 1,select("#", ...) do
            txt = txt .. tostring(select(idx, ...))
        end
        print(txt)
    end
end


FollowVehicle = {}

FollowVehicle.MAX_TRAIL_ENTRIES = 150
FollowVehicle.MIN_DISTANCE_BETWEEN_DROPS = 2
FollowVehicle.MAX_DISTANCE_BETWEEN_DROPS = 10
FollowVehicle.INITIATION_TIMEOUT = 3000

FollowVehicle.debugTrailVisibleEntries = -1
FollowVehicle.debugTrailYOffset = 2

function FollowVehicle.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIJobVehicle, specializations)
       and SpecializationUtil.hasSpecialization(Drivable, specializations)
end

function FollowVehicle.initSpecialization(vehicleType)
end

function FollowVehicle.registerFunctions(vehicleType)
    for _,funcName in pairs( {
        "modifyDistanceAndSideOffset",
        "getDropIndexFromCount",
        "getLastTrailDrop",
        "getTrailDrop",
        "getTrailDropDirection",
        "addTrailDrop",
        "startFollowVehicle",
        "stopFollowVehicle",
        "getIsFollowVehicleActive",
        "getCanStartFollowVehicle",
        "getVehicleToFollow",
        "addFollower",
        "removeFollower",
        "getAllFollowers",
        "getSelectedFollower",
        "togglePauseResume",
        "updateAIFollowVehicleDriveStrategies",
        "updateAIFollowVehicle_DriveData",
        "updateAIFollowVehicle_Steering",
        ----
        "drawNearbyVehicles",
        "drawFollowers",
        "drawDebugTrail",
        "findVehiclesNearby",
        "findOptimalClosestTrailDrop",
        "initiateFollowVehicle",
        --
        "getCurrentSideOffsetModifier",
    } ) do
        SpecializationUtil.registerFunction(vehicleType, funcName, FollowVehicle[funcName])
    end
end

function FollowVehicle.registerOverwrittenFunctions(vehicleType)
    for _,funcName in pairs( {
        "getStartableAIJob",
        "getHasStartableAIJob",
    } ) do
    	SpecializationUtil.registerOverwrittenFunction(vehicleType, funcName, FollowVehicle[funcName])
    end
end

function FollowVehicle.registerEventListeners(vehicleType)
    for _,funcName in pairs( {
--        "onPostLoad",
        "onLoadFinished",
        "onPreDelete",
--        "onDelete",
--        "onWriteStream",
--        "onReadStream",
--        "onWriteUpdateStream",
--        "onReadUpdateStream",
        "onUpdate",
        "onUpdateTick",
        "onDraw",
        "onRegisterActionEvents",
	    "onLeaveVehicle",
--        "onAIStart",
--        "onAIEnd",
--        "onLightsTypesMaskChanged",
--        "onBeaconLightsVisibilityChanged",
--        "onTurnLightStateChanged",
    } ) do
        SpecializationUtil.registerEventListener(vehicleType, funcName, FollowVehicle)
    end
end

function FollowVehicle.registerEvents(vehicleType)
    for _,eventName in pairs( {
        "onAIFollowVehicleStart",
        "onAIFollowVehicleActive",
        "onAIFollowVehicleEnd",
        "onAIFollowVehicleBlock",
        "onAIFollowVehicleContinue",
    } ) do
        SpecializationUtil.registerEvent(vehicleType, eventName)
    end
end

local specName = "spec_" .. g_currentModName .. ".followVehicle"
function getSpec(self)
    return self[specName]
end

function FollowVehicle:onLoadFinished(savegame)
    local spec = getSpec(self)

    spec.isActive = false
    spec.actionEvents = {}
    
	spec.driveStrategies = {}
    spec.didNotMoveTimeout = 10000
    spec.didNotMoveTimer = spec.didNotMoveTimeout

	spec.aiDriveParams = {
		valid = false
	}
	spec.aiUpdateLowFrequencyDt = 0
	spec.aiUpdateDt = 0

	spec.followJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.MOD_FOLLOW_VEHICLE)

    spec.currentFollowers = {}
    spec.selectedFollower = nil
    spec.drawFollowersTimer = 0
    spec.followersOffsetSetting = 1

    spec.dropperCircularArray = {}
    spec.dropperCurrentCount = -1   -- Zero-based index
    spec.sumSpeed = 0
    spec.sumCount = 0

    spec.followingCurrentCount = 0  -- Zero-based index

    spec.offsetLR = 0
    spec.distanceFB = 25
    spec.isWaiting = false

    spec.nearbyVehicles = {}
    spec.nearbyVehicles_timeout = 0

    if nil ~= g_server then
        -- Drop some initial 'bread crumbs', to avoid issues later
        local maxSpeed = 15
        --local direction = self:getReverserDirection()
        self:addTrailDrop(maxSpeed, self:getTurnLightState(), -5)
        self:addTrailDrop(maxSpeed, self:getTurnLightState(), -2.5)
        self:addTrailDrop(maxSpeed, self:getTurnLightState(), 0)
    end
end

function FollowVehicle:onPreDelete()
    if self.isServer then
        local spec = getSpec(self)
        for _,followerVehicle in pairs(spec.currentFollowers) do
            if followerVehicle and followerVehicle:getIsFollowVehicleActive() then
                followerVehicle:stopCurrentAIJob(AIMessageErrorVehicleDeleted.new())
            end
        end
    end
end

local FOLLOW_CHASER_CHOOSEOTHER    = g_i18n:getText("FOLLOW_CHASER_CHOOSEOTHER")
local FOLLOW_CHASER_SIDEOFFSET     = g_i18n:getText("FOLLOW_CHASER_SIDEOFFSET")
local FOLLOW_CHASER_DISTANCE       = g_i18n:getText("FOLLOW_CHASER_DISTANCE")

function FollowVehicle:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = getSpec(self)
        self:clearActionEventsTable(spec.actionEvents)

        if self:getIsActiveForInput(true, true) then
            local _, eventId
            if self:getCanStartFollowVehicle() and g_currentMission:getHasPlayerPermission("hireAssistant") then
                _, eventId = self:addPoweredActionEvent(spec.actionEvents, InputAction.FOLLOW_INITIATE, self, FollowVehicle.actionEventInitiate, false, true, false, true, nil, nil, true, true)
                g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
            end

            _, eventId = self:addActionEvent(spec.actionEvents, InputAction.FOLLOW_MARKER_TOGGLE_OFFSET, self, FollowVehicle.actionEventToggleFollowersOffset, false, true, false, true, nil, nil, true, true)
            g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_LOW)

            local followVehicleActive = self:getIsFollowVehicleActive()
            local otherAIActive = self:getIsAIActive() and (not followVehicleActive)
            if not otherAIActive then
                local priority = (followVehicleActive and GS_PRIO_VERY_HIGH) or GS_PRIO_LOW

                _, eventId = self:addActionEvent(spec.actionEvents, InputAction.FOLLOW_DISTANCE,    self, FollowVehicle.actionEventDistance,   false, true, false, true, nil, nil, true, true)
                g_inputBinding:setActionEventTextPriority(eventId, priority)

                _, eventId = self:addActionEvent(spec.actionEvents, InputAction.FOLLOW_SIDE_OFFSET, self, FollowVehicle.actionEventSideOffset, false, true, false, true, nil, nil, true, true)
                g_inputBinding:setActionEventTextPriority(eventId, priority)

                _, eventId = self:addActionEvent(spec.actionEvents, InputAction.FOLLOW_PAUSE_RESUME,self, FollowVehicle.actionEventPauseResume,false, true, false, true, nil, nil, true, true)
                g_inputBinding:setActionEventTextPriority(eventId, priority)
            end
    
            local followers = {}
            self:getAllFollowers(followers)
            if #followers > 0 then
                _, eventId = self:addActionEvent(spec.actionEvents, InputAction.FOLLOW_CHASER_CHOOSE,  self, FollowVehicle.actionEventFollowerSelect,     false, true, false, true, nil, nil, true, true)
                g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventTextVisibility(eventId, true)
                g_inputBinding:setActionEventText(eventId, FOLLOW_CHASER_CHOOSEOTHER)

                _, eventId = self:addActionEvent(spec.actionEvents, InputAction.FOLLOW_CHASER_DISTANCE,    self, FollowVehicle.actionEventFollowerDistance,   false, true, false, true, nil, nil, true, true)
                g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventTextVisibility(eventId, false)
                g_inputBinding:setActionEventText(eventId, FOLLOW_CHASER_DISTANCE)

                _, eventId = self:addActionEvent(spec.actionEvents, InputAction.FOLLOW_CHASER_SIDE_OFFSET, self, FollowVehicle.actionEventFollowerSideOffset, false, true, false, true, nil, nil, true, true)
                g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventTextVisibility(eventId, false)
                g_inputBinding:setActionEventText(eventId, FOLLOW_CHASER_SIDEOFFSET)

                _, eventId = self:addActionEvent(spec.actionEvents, InputAction.FOLLOW_CHASER_PAUSE_RESUME, self, FollowVehicle.actionEventFollowerPauseResume, false, true, false, true, nil, nil, true, true)
                g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventTextVisibility(eventId, true)
                --g_inputBinding:setActionEventText(eventId, FOLLOW_CHASER_PAUSE)
            end

            FollowVehicle.updateActionEvents(self)
        end
    end
end

function FollowVehicle:actionEventInitiate(actionName, inputValue, callbackState, isAnalog)
    local spec = getSpec(self)
    local newNearbyVehicles = self:findVehiclesNearby()

    local numberOfNewNearbyVehicles = #newNearbyVehicles
    if numberOfNewNearbyVehicles > 0 then
        if numberOfNewNearbyVehicles > 1 then
            spec.nearbyVehicles_timeout = math.max(1000, FollowVehicle.INITIATION_TIMEOUT)
        else
            spec.nearbyVehicles_timeout = 1000
        end

        -- Switch to next vehicle, in case of multiple found vehicles
        local newSelectedIdx = 1
        for _, oldNearbyVehicle in ipairs(spec.nearbyVehicles) do
            if oldNearbyVehicle.selected then
                for idx, newNearbyVehicle in ipairs(newNearbyVehicles) do
                    if newNearbyVehicle.vehicle == oldNearbyVehicle.vehicle then
                        newSelectedIdx = (idx % #newNearbyVehicles) + 1
                        break
                    end
                end
                break
            end
        end
        newNearbyVehicles[newSelectedIdx].selected = true

        local followFromTrailDropCount = self:findOptimalClosestTrailDrop(newNearbyVehicles[newSelectedIdx].vehicle)
        if followFromTrailDropCount > 0 then
            newNearbyVehicles[newSelectedIdx].followFromTrailDropCount = followFromTrailDropCount
        end
    end

    spec.nearbyVehicles = newNearbyVehicles

    FollowVehicle.updateActionEvents(self)
end

function FollowVehicle:actionEventDistance(actionName, inputValue, callbackState, isAnalog)
    self:modifyDistanceAndSideOffset(inputValue, 0)
    FollowVehicle.updateActionEvents(self)
end

function FollowVehicle:actionEventSideOffset(actionName, inputValue, callbackState, isAnalog)
    self:modifyDistanceAndSideOffset(0, inputValue)
    FollowVehicle.updateActionEvents(self)
end

function FollowVehicle:actionEventPauseResume(actionName, inputValue, callbackState, isAnalog)
    self:togglePauseResume()
    FollowVehicle.updateActionEvents(self)
end

function FollowVehicle:togglePauseResume()
    local spec = getSpec(self)
    spec.isWaiting = not spec.isWaiting
end

function FollowVehicle:actionEventFollowerSelect(actionName, inputValue, callbackState, isAnalog)
    local spec = getSpec(self)

    local followers = {}
    self:getAllFollowers(followers)

    for idx,followerVehicle in ipairs(followers) do
        if spec.selectedFollower == followerVehicle then
            -- Keep on same follower if timer have completed, otherwise switch to next follower
            local idxSwitchOffset = (spec.drawFollowersTimer <= 0) and -1 or 0
            idx = ((idx + idxSwitchOffset) % #followers) + 1
            spec.selectedFollower = followers[idx]
            spec.drawFollowersTimer = 7000
            FollowVehicle.updateActionEvents(self)
            return
        end
    end
    if #followers > 0 then
        spec.selectedFollower = followers[1]
        spec.drawFollowersTimer = 7000
        FollowVehicle.updateActionEvents(self)
    else
        spec.selectedFollower = nil
        spec.drawFollowersTimer = 0
    end
end

function FollowVehicle:getSelectedFollower()
    local spec = getSpec(self)

    local followers = {}
    self:getAllFollowers(followers)

    if #followers == 1 then
        return followers[1]
    else
        for _,followerVehicle in ipairs(followers) do
            if spec.selectedFollower == followerVehicle then
                return followerVehicle
            end
        end
    end

    return nil
end

function FollowVehicle:actionEventFollowerPauseResume(actionName, inputValue, callbackState, isAnalog)
    local follower = self:getSelectedFollower()
    if nil ~= follower then
        follower:togglePauseResume()
        FollowVehicle.updateActionEvents(self)
    end
end

local FollowersOffsets = {
    {  1.0, g_i18n:getText("FOLLOW_MARKER_OFFSET_NORMAL") },
    {    0, g_i18n:getText("FOLLOW_MARKER_OFFSET_DISABLED") },
    { -1.0, g_i18n:getText("FOLLOW_MARKER_OFFSET_REVERSED") },
    {    0, g_i18n:getText("FOLLOW_MARKER_OFFSET_DISABLED") },
}

function FollowVehicle:getCurrentSideOffsetModifier()
    local spec = getSpec(self)
    return FollowersOffsets[spec.followersOffsetSetting][1]
end

function FollowVehicle:actionEventToggleFollowersOffset(actionName, inputValue, callbackState, isAnalog)
    local spec = getSpec(self)
    spec.followersOffsetSetting = (spec.followersOffsetSetting % #FollowersOffsets) + 1
    FollowVehicle.updateActionEvents(self)
end

function FollowVehicle:actionEventFollowerDistance(actionName, inputValue, callbackState, isAnalog)
    FollowVehicle.adjustFollowerDistanceAndSideOffset(self, inputValue, 0)
end

function FollowVehicle:actionEventFollowerSideOffset(actionName, inputValue, callbackState, isAnalog)
    FollowVehicle.adjustFollowerDistanceAndSideOffset(self, 0, inputValue)
end

local distanceIntervalChanges = {
    -- distanceLow, distanceHigh, stepChange
    {-math.huge,       -20,  5},
    {       -20,         0,  2},
    {         0,        30,  5},
    {        30, math.huge, 10},
}
function FollowVehicle:modifyDistanceAndSideOffset(distanceDirection, sideoffsetAdjust)
    local spec = getSpec(self)

    local newDistance = spec.distanceFB
    if distanceDirection ~= 0 then
        -- Possible "solution" for issue #62
        distanceDirection = MathUtil.sign(distanceDirection)
        local distance_step = 5
        if distanceDirection < 0 then
            for idx,item in ipairs(distanceIntervalChanges) do
                if item[1] < spec.distanceFB and spec.distanceFB <= item[2] then
                    distance_step = item[3]
                    newDistance = spec.distanceFB + (distance_step * distanceDirection)
                    if newDistance < item[1] then
                        newDistance = item[1]
                        distance_step = distanceIntervalChanges[idx-1][3]
                    end
                    break
                end
            end
        elseif distanceDirection > 0 then
            for idx,item in ipairs(distanceIntervalChanges) do
                if item[1] <= spec.distanceFB and spec.distanceFB < item[2] then
                    distance_step = item[3]
                    newDistance = spec.distanceFB + (distance_step * distanceDirection)
                    if newDistance > item[2] then
                        newDistance = item[2]
                        distance_step = distanceIntervalChanges[idx+1][3]
                    end
                    break
                end
            end
        end
        newDistance = math.floor(newDistance / distance_step) * distance_step
    end

    local sideOffset_step = 0.5
    sideoffsetAdjust = sideOffset_step * MathUtil.sign(sideoffsetAdjust)
    local newOffsetLR = math.floor((spec.offsetLR + sideoffsetAdjust) / sideOffset_step) * sideOffset_step

    FollowVehicle.setDistanceAndSideOffset(self, newDistance, newOffsetLR)
end

function FollowVehicle:setDistanceAndSideOffset(newDistance, newSideoffset)
    local spec = getSpec(self)
    spec.distanceFB = MathUtil.clamp(newDistance, -50, 200)
    spec.offsetLR   = MathUtil.clamp(newSideoffset, -50, 50)
end

function FollowVehicle:adjustFollowerDistanceAndSideOffset(distanceAdjust, sideoffsetAdjust)
    local follower = self:getSelectedFollower()
    if nil ~= follower then
        local spec = getSpec(self)
        follower:modifyDistanceAndSideOffset(distanceAdjust, sideoffsetAdjust)
        spec.drawFollowersTimer = 4000
    end
end

local FOLLOW_CHOOSEOTHER    = g_i18n:getText("FOLLOW_CHOOSEOTHER")
local FOLLOW_INITIATE       = g_i18n:getText("FOLLOW_INITIATE")
local FOLLOW_SIDEOFFSET     = g_i18n:getText("FOLLOW_SIDEOFFSET")
local FOLLOW_DISTANCE       = g_i18n:getText("FOLLOW_DISTANCE")
local FOLLOW_PAUSE          = g_i18n:getText("FOLLOW_PAUSE")
local FOLLOW_RESUME         = g_i18n:getText("FOLLOW_RESUME")
local FOLLOW_CHASER_PAUSE   = g_i18n:getText("FOLLOW_CHASER_PAUSE")
local FOLLOW_CHASER_RESUME  = g_i18n:getText("FOLLOW_CHASER_RESUME")

function FollowVehicle:updateActionEvents()
    if not self.isClient then
        return
    end

    local spec = getSpec(self)

    local followVehicleIsActive = self:getIsFollowVehicleActive()

    local actionEvent = spec.actionEvents[InputAction.FOLLOW_INITIATE]
    if nil ~= actionEvent then
        local numNearbyVehicles = #spec.nearbyVehicles
        if numNearbyVehicles > 1 then
            g_inputBinding:setActionEventText(actionEvent.actionEventId, FOLLOW_CHOOSEOTHER .. (" (%.0fs)"):format(math.ceil(spec.nearbyVehicles_timeout/1000)))
            g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_VERY_HIGH)
            g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, true)
        elseif numNearbyVehicles > 0 then
            g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, false)
        elseif not self:getIsAIActive() then
            g_inputBinding:setActionEventText(actionEvent.actionEventId, FOLLOW_INITIATE)
            g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_NORMAL)
            g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, true)
        else
            g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, false)
        end
    end

    actionEvent = spec.actionEvents[InputAction.FOLLOW_SIDE_OFFSET]
    if nil ~= actionEvent then
        g_inputBinding:setActionEventText(actionEvent.actionEventId, FOLLOW_SIDEOFFSET .. (" (%.1f)"):format(spec.offsetLR))
        if followVehicleIsActive then
            g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_HIGH)
            g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, true)
        else
            g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_LOW)
        end
    end

    actionEvent = spec.actionEvents[InputAction.FOLLOW_DISTANCE]
    if nil ~= actionEvent then
        g_inputBinding:setActionEventText(actionEvent.actionEventId, FOLLOW_DISTANCE .. (" (%.0f)"):format(spec.distanceFB))
        if followVehicleIsActive then
            g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_HIGH)
            g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, true)
        else
            g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_LOW)
        end
    end

    actionEvent = spec.actionEvents[InputAction.FOLLOW_PAUSE_RESUME]
    if nil ~= actionEvent then
        g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, followVehicleIsActive)
        if followVehicleIsActive then
            if spec.isWaiting then
                g_inputBinding:setActionEventText(actionEvent.actionEventId, FOLLOW_RESUME)
                g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_VERY_HIGH)
            else
                g_inputBinding:setActionEventText(actionEvent.actionEventId, FOLLOW_PAUSE)
                g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_LOW)
            end
        end
    end

    actionEvent = spec.actionEvents[InputAction.FOLLOW_MARKER_TOGGLE_OFFSET]
    if nil ~= actionEvent then
        g_inputBinding:setActionEventText(actionEvent.actionEventId, FollowersOffsets[spec.followersOffsetSetting][2])
        if spec.followersOffsetSetting > 1 then
            g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_VERY_HIGH)
        else
            g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_LOW)
        end        
        g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, true)
    end

    actionEvent = spec.actionEvents[InputAction.FOLLOW_CHASER_DISTANCE]
    if nil ~= actionEvent then
        g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, spec.drawFollowersTimer > 0)
    end

    actionEvent = spec.actionEvents[InputAction.FOLLOW_CHASER_SIDEOFFSET]
    if nil ~= actionEvent then
        g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, spec.drawFollowersTimer > 0)
    end

    actionEvent = spec.actionEvents[InputAction.FOLLOW_CHASER_PAUSE_RESUME]
    if nil ~= actionEvent then
        local follower = self:getSelectedFollower()
        g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, nil ~= follower)
        if nil ~= follower then
            local followerSpec = getSpec(follower)    
            if followerSpec and followerSpec.isWaiting then
                g_inputBinding:setActionEventText(actionEvent.actionEventId, FOLLOW_CHASER_RESUME)
                g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_VERY_HIGH)
            else
                g_inputBinding:setActionEventText(actionEvent.actionEventId, FOLLOW_CHASER_PAUSE)
                g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_LOW)
            end
        end
    end
end

function FollowVehicle:initiateFollowVehicle(vehicleToFollow)
    if not g_currentMission:getHasPlayerPermission("hireAssistant") then
        return
    end

    local job = g_currentMission.aiJobTypeManager:createJob(AIJobType.MOD_FOLLOW_VEHICLE)
    job.vehicleParameter:setVehicle(self)
    job.followVehicleParameter:setVehicle(vehicleToFollow)
    job:setValues()

    local success, errorMessage = job:validate(g_currentMission.player.farmId)
    if success then
        g_currentMission.aiSystem:startJob(job, g_currentMission.player.farmId)
    end
end

function FollowVehicle:onLeaveVehicle()
    local spec = getSpec(self)

    -- Leaving vehicle when having initiated a 'follow vehicle' action, before it was actually started, should cancel it.
    if spec and spec.nearbyVehicles_timeout > 0 then
        spec.nearbyVehicles_timeout = 0
        spec.nearbyVehicles = {}
        FollowVehicle.updateActionEvents(self)
    end
end

function FollowVehicle:onUpdateTick(dt, isActiveForInput, isSelected)
    local spec = getSpec(self)

    if spec.nearbyVehicles_timeout > 0 then
        spec.nearbyVehicles_timeout = spec.nearbyVehicles_timeout - dt
        if not self:getCanStartFollowVehicle() then
            spec.nearbyVehicles = {}
            spec.nearbyVehicles_timeout = 0
        elseif spec.nearbyVehicles_timeout <= 0 then
            for _, nearbyVehicle in ipairs(spec.nearbyVehicles) do
                if nearbyVehicle.inViewport and nearbyVehicle.selected then
                    self:initiateFollowVehicle(nearbyVehicle.vehicle)
                    break
                end
            end
            spec.nearbyVehicles = {}
        else
            for _, nearbyVehicle in ipairs(spec.nearbyVehicles) do
                if nearbyVehicle.selected then
                    nearbyVehicle.followFromTrailDropCount = nil
                    local followFromTrailDropCount = self:findOptimalClosestTrailDrop(nearbyVehicle.vehicle)
                    if followFromTrailDropCount > 0 then
                        nearbyVehicle.followFromTrailDropCount = followFromTrailDropCount
                    end
                    break
                end
            end
        end
        FollowVehicle.updateActionEvents(self)
    end

    if spec.drawFollowersTimer > 0 then
        spec.drawFollowersTimer = spec.drawFollowersTimer - dt
        if spec.drawFollowersTimer <= 0 then
            FollowVehicle.updateActionEvents(self)
        end
    end

    if self.isServer then
        local moveDirection = self:getReverserDirection() * self.movingDirection
        if (moveDirection > 0) then  -- Must drive forward to drop trail
            spec.sumSpeed = spec.sumSpeed + self.lastSpeed
            spec.sumCount = spec.sumCount + 1

            local vX,vY,vZ = getWorldTranslation(self.rootNode)
            local lastDrop = self:getLastTrailDrop()
            local oX,oY,oZ = unpack(lastDrop.position)
            local distancePrevDrop = MathUtil.vector2Length(oX - vX, oZ - vZ)
            if distancePrevDrop >= FollowVehicle.MIN_DISTANCE_BETWEEN_DROPS then
                local forceAddDrop = distancePrevDrop >= FollowVehicle.MAX_DISTANCE_BETWEEN_DROPS
                if not forceAddDrop then
                    -- If current driving angle, compared to last drop's angle, is too wide, then add a new trail-drop
                    local node = self:getAISteeringNode()
                    local dirX,_,dirZ = localDirectionToWorld(node, 0,0,1)
                    local dX,dZ = dirX - lastDrop.direction[1], dirZ - lastDrop.direction[3]
                    forceAddDrop = math.abs(dX * dZ) >= 0.000001
                end
                if forceAddDrop then
                    local maxSpeed = math.max(5, (spec.sumSpeed / spec.sumCount) * 3600)
                    self:addTrailDrop(maxSpeed, self:getTurnLightState())
                    spec.sumSpeed = 0
                    spec.sumCount = 0
                end
            end
        end
    end
end

function FollowVehicle:getDropIndexFromCount(count)
    return 1 + (count % FollowVehicle.MAX_TRAIL_ENTRIES)
end

function FollowVehicle:getLastTrailDrop()
    local spec = getSpec(self)
    return spec.dropperCircularArray[self:getDropIndexFromCount(spec.dropperCurrentCount)]
end

function FollowVehicle:getTrailDrop(count)
    local spec = getSpec(self)
    if count > spec.dropperCurrentCount then
        count = spec.dropperCurrentCount
    end
    return spec.dropperCircularArray[self:getDropIndexFromCount(count)]
end

function FollowVehicle:getTrailDropDirection(count)
    local spec = getSpec(self)
    if count > spec.dropperCurrentCount then
        count = spec.dropperCurrentCount
    end

    local currDrop = spec.dropperCircularArray[self:getDropIndexFromCount(count)]

    -- Find the "direction" of trail-drop, by taking the previous drop and next drop's positions,
    -- and generate a normalized direction-vector from those.
    local prevPos
    if count > 0 then
        prevPos = spec.dropperCircularArray[self:getDropIndexFromCount(count - 1)].position
    else
        prevPos = currDrop.position
    end

    local nextPos
    if count < spec.dropperCurrentCount then
        nextPos = spec.dropperCircularArray[self:getDropIndexFromCount(count + 1)].position
    else
        -- Just use vehicle's current position
        nextPos = { getWorldTranslation(self.rootNode) }
    end

    local dX,dZ = MathUtil.vector2Normalize(nextPos[1] - prevPos[1], nextPos[3] - prevPos[3])

    -- ...except if the result is "backwards", then just use the current-drop's direction
    local dotResult = MathUtil.dotProduct(dX,0,dZ, currDrop.direction[1],0,currDrop.direction[3])
    if dotResult < 0.25 then
        dX,dZ = currDrop.direction[1], currDrop.direction[3]
    end

    return dX,dZ
end

function FollowVehicle:addTrailDrop(maxSpeed, turnLightState, zOffset)
    assert(nil ~= g_server)

    local spec = getSpec(self)
    
    local x,y,z = getWorldTranslation(self.rootNode)
    local node = self:getAISteeringNode()
    local dirX,dirY,dirZ = localDirectionToWorld(node, 0,0,1)

    if zOffset ~= nil then
        x = x + dirX * zOffset
        z = z + dirZ * zOffset
    end

    local drivenDistance = 0
    local prevDrop = self:getLastTrailDrop()
    if prevDrop then
        local pX,pY,pZ = unpack(prevDrop.position)

        local dist = MathUtil.vector2Length(pX - x, pZ - z)
        drivenDistance = prevDrop.drivenDistance + dist
    end

    local newDrop = {
        position           = { x,y,z },
        direction          = { dirX,dirY,dirZ },
        drivenDistance     = drivenDistance,
        maxSpeed           = maxSpeed,
        turnLightState     = turnLightState,
        followersOffsetPct = FollowersOffsets[spec.followersOffsetSetting][1],
    }

    spec.dropperCurrentCount = spec.dropperCurrentCount + 1 -- Keep incrementing index, so followers will be able to detect if they get too far behind of the circular-array.
    local dropIndex = self:getDropIndexFromCount(spec.dropperCurrentCount)
    spec.dropperCircularArray[dropIndex] = newDrop
end

local FOLLOW_WAITINGCOLLISION = g_i18n:getText("FOLLOW_WAITINGCOLLISION")
local FOLLOW_WAITING          = g_i18n:getText("FOLLOW_WAITING")

function FollowVehicle:onDraw()
    local spec = getSpec(self)

    if spec.nearbyVehicles_timeout > 0 then
        self:drawNearbyVehicles()
    elseif spec.drawFollowersTimer > 0 then
        self:drawFollowers()
    end

    if FollowVehicle.debugTrailVisibleEntries > 0 then
        self:drawDebugTrail()
        FollowVehicle.drawFollowingTrail(self)

        if spec.aiDriveParams.valid then
            local moveForwards = spec.aiDriveParams.moveForwards
            local tX = spec.aiDriveParams.tX
            local tY = spec.aiDriveParams.tY
            local tZ = spec.aiDriveParams.tZ
            local maxSpeed = spec.aiDriveParams.maxSpeed

            local x1,y1,z1 = getWorldTranslation(self.rootNode)

            local yOffset = FollowVehicle.debugTrailYOffset
            local rgb = {1,0,0}

            drawDebugLine(x1, y1+yOffset, z1, rgb[1], rgb[2], rgb[3], tX, tY+yOffset, tZ, rgb[1], rgb[2], rgb[3])
            if moveForwards then
                drawDebugPoint(tX, tY+yOffset, tZ, 0,1,0, 2)
            else
                drawDebugPoint(tX, tY+yOffset, tZ, 1,0,0, 4)
            end
        end
    end

    if spec.isActive or spec.nearbyVehicles_timeout > 0 then
        setTextBold(true)

        local textSize2 = getCorrectTextSize(0.02)
        local shadeSize = textSize2/10
        local txt = nil

        -- TODO: Figure out a better method, for querying if there is detected a collision, instead of digging into the strategy-object's variable.
        if nil ~= spec.driveStrategyCollision and spec.driveStrategyCollision.lastHasCollision then
            txt = FOLLOW_WAITINGCOLLISION
        elseif spec.isWaiting then
            txt = FOLLOW_WAITING
        end
        if nil ~= txt then
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextColor(0,0,0,1)
            renderText(0.5+shadeSize, 0.05+(6*textSize2)-shadeSize, textSize2, txt)
            setTextColor(1,0.8,0.8,1)
            renderText(0.5, 0.05+(6*textSize2), textSize2, txt)
        end

        -- Front/Back distance
        if spec.distanceFB >= 0 then
            txt = ("|\n|\nv\n%d"):format(spec.distanceFB)
        else
            txt = ("%d\n^\n|\n|"):format(-spec.distanceFB)
        end
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(0,0,0,1)
        renderText(0.5+shadeSize, 0.05+(4*textSize2)-shadeSize, textSize2, txt)
        setTextColor(1,1,1,1)
        renderText(0.5, 0.05+(4*textSize2), textSize2, txt)

        -- Left/Right offset
        if spec.offsetLR ~= 0 then
            if spec.offsetLR < 0 then
                txt = ("%.1f<--   "):format(-spec.offsetLR)
                setTextAlignment(RenderText.ALIGN_RIGHT)
            else
                txt = ("   -->%.1f"):format(spec.offsetLR)
                setTextAlignment(RenderText.ALIGN_LEFT)
            end
            setTextColor(0,0,0,1)
            renderText(0.5+shadeSize, 0.05+(2*textSize2)-shadeSize, textSize2, txt)
            setTextColor(1,1,1,1)
            renderText(0.5, 0.05+(2*textSize2), textSize2, txt)
        end

        --
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(false)
    end

end

local FOLLOW_LEADER_SELECTED = g_i18n:getText("FOLLOW_LEADER_SELECTED")

function FollowVehicle:drawNearbyVehicles()
    local spec = getSpec(self)

	setTextDepthTestEnabled(false)
	setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)

    local textSize = getCorrectTextSize(0.015)
    local textSize2 = getCorrectTextSize(0.025)
    local shadeSize = textSize/10
    local yOffset = 2

    local wx,wy,wz
    local sx,sy,sz

    for _, nearbyVehicle in ipairs(spec.nearbyVehicles) do
        wx,wy,wz = getWorldTranslation(nearbyVehicle.vehicle.rootNode)
        sx,sy,sz = project(wx, wy+yOffset, wz)
        if sx > 0 and sx < 1 and sy > 0 and sy < 1 and sz <= 1 then
            nearbyVehicle.inViewport = true
            if nearbyVehicle.selected then
                local x1,y1,z1 = getWorldTranslation(self.rootNode)

                local followFromTrailDropCount = nearbyVehicle.followFromTrailDropCount
                if nil ~= followFromTrailDropCount then
                    local rgb = {0,1,1}
                    local leaderVehicle = nearbyVehicle.vehicle
                    local leaderDropperCurrentCount = getSpec(leaderVehicle).dropperCurrentCount
                    local percentOfTrailToDraw = 1 - math.min(1, math.max(0, (spec.nearbyVehicles_timeout / FollowVehicle.INITIATION_TIMEOUT)))
                    local drawUntilCount = followFromTrailDropCount + ((leaderDropperCurrentCount - followFromTrailDropCount) * percentOfTrailToDraw)
                    local x2,y2,z2,drop
                    local targetRotX,targetRotY,targetRotZ
                    local sideOffset
                    for i=followFromTrailDropCount, drawUntilCount do
                        drop = leaderVehicle:getTrailDrop(i)
                        x2,y2,z2 = unpack(drop.position)
                        targetRotX,targetRotZ = leaderVehicle:getTrailDropDirection(i)
                        sideOffset = spec.offsetLR * (drop.followersOffsetPct or 1.0)
                        x2 = x2 - targetRotZ * sideOffset
                        z2 = z2 + targetRotX * sideOffset

                        drawDebugLine(x1, y1+yOffset, z1, rgb[1], rgb[2], rgb[3], x2, y2+yOffset, z2, rgb[1], rgb[2], rgb[3])
                        x1,y1,z1 = x2,y2,z2
                    end
                end

                local txt = FOLLOW_LEADER_SELECTED .. "\n" .. nearbyVehicle.vehicle:getFullName()
                setTextColor(0, 0, 0, 1)
                renderText(sx+shadeSize,sy+textSize2-shadeSize, textSize2, txt)
                setTextColor(1, 1, 1, 1)
                renderText(sx,sy+textSize2, textSize2, txt)

                --local rx,ry,rz  = localDirectionToWorld(node, 0,0,1)
                --renderText3D(wx,wy,wz, rx,ry,rz, textSize2 * 5,txt)
            else
                setTextColor(0, 0, 0, 1)
                renderText(sx+shadeSize,sy-shadeSize, textSize, nearbyVehicle.vehicle:getFullName())
                setTextColor(0.7, 0.7, 0.7, 1)
                renderText(sx,sy, textSize, nearbyVehicle.vehicle:getFullName())
            end
        else
            nearbyVehicle.inViewport = false
        end
    end

	setTextDepthTestEnabled(true)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end

local FOLLOW_DISTANCE_OFFSET = g_i18n:getText("FOLLOW_DISTANCE_OFFSET")

function FollowVehicle:drawFollowers()
    local spec = getSpec(self)

    local textSize = getCorrectTextSize(0.015)
    local textSize2 = getCorrectTextSize(0.025)
    local shadeSize = textSize/10
    local yOffset = 2
    local wx,wy,wz
    local sx,sy,sz

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(false)

    if spec.drawFollowersTimer > 4000 then
        setTextColor(0.7, 0.7, 0.7, 1)
    
        local followers = {}
        self:getAllFollowers(followers)
        for _,followerVehicle in ipairs(followers) do
            if spec.selectedFollower ~= followerVehicle then
                FollowVehicle.drawFollowingTrail(followerVehicle)

                wx,wy,wz = getWorldTranslation(followerVehicle.rootNode)
                sx,sy,sz = project(wx, wy+yOffset, wz)
                if sx > 0 and sx < 1 and sy > 0 and sy < 1 and sz <= 1 then
                    local followerSpec = getSpec(followerVehicle)
                    local txt = ""
                    if followerSpec.isWaiting then
                        txt = FOLLOW_WAITING .. "\n"
                    end
                    renderText(sx,sy, textSize, txt .. followerVehicle:getFullName())
                end
            end
        end
    end

    local followerVehicle = spec.selectedFollower
    if nil ~= followerVehicle then
        FollowVehicle.drawFollowingTrail(followerVehicle)

        wx,wy,wz = getWorldTranslation(followerVehicle.rootNode)
        sx,sy,sz = project(wx, wy+yOffset, wz)
        if sx > 0 and sx < 1 and sy > 0 and sy < 1 and sz <= 1 then
            local followerSpec = getSpec(followerVehicle)
            local txt = ""
            if followerSpec.isWaiting then
                txt = FOLLOW_WAITING .. "\n"
            end
            txt = txt .. followerVehicle:getFullName() .. "\n" .. FOLLOW_DISTANCE_OFFSET:format(followerSpec.distanceFB, followerSpec.offsetLR)
            setTextColor(0, 0, 0, 1)
            renderText(sx+shadeSize,sy+textSize2-shadeSize, textSize2, txt)
            setTextColor(1, 1, 1, 1)
            renderText(sx,sy+textSize2, textSize2, txt)
        end
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end

function FollowVehicle:drawDebugTrail()
    local spec = getSpec(self)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(false)
    setTextColor(0, 1, 1, 1)
    local textSize = getCorrectTextSize(0.01)
    local yOffset = FollowVehicle.debugTrailYOffset

    local rgb = {1,1,1}
    local dirX,dirY,dirZ
    local sx, sy, sz
    local dropCount, drop
    local x2,y2,z2

    local x1,y1,z1 = getWorldTranslation(self.rootNode)

    for i=0, FollowVehicle.debugTrailVisibleEntries do
        drawDebugPoint(x1,y1+yOffset,z1, 0,0,1, 2)

        -- Trail
        dropCount = spec.dropperCurrentCount - i
        if dropCount < 0 then
            break
        end
        drop = spec.dropperCircularArray[self:getDropIndexFromCount(dropCount)]
        x2,y2,z2 = unpack(drop.position)
        drawDebugLine(x1, y1+yOffset, z1, rgb[1], rgb[2], rgb[3], x2, y2+yOffset, z2, rgb[1], rgb[2], rgb[3])

        -- Direction
        dirX,dirY,dirZ = unpack(drop.direction)
        drawDebugLine(x2, y2+yOffset, z2, 0,1,0, x2+dirX, y2+dirY+yOffset, z2+dirZ, 0,1,0)

        -- MaxSpeed & DrivenDistance
        sx, sy, sz = project(x2, y2+yOffset+0.5, z2)
        if sx > 0 and sx < 1 and sy > 0 and sy < 1 and sz <= 1 then
            renderText(sx, sy, textSize, ("%d\n%d"):format(drop.maxSpeed, drop.drivenDistance))
        end

        --
        x1,y1,z1 = x2,y2,z2
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end    

function FollowVehicle:drawFollowingTrail()
    local leader = self:getVehicleToFollow()
    if nil == leader then
        return
    end
    local leaderSpec = getSpec(leader)
    if nil == leader then
        return
    end

    local spec = getSpec(self)

    local rgb = {0,1,1}
    local yOffset = FollowVehicle.debugTrailYOffset
    local x1,y1,z1 = getWorldTranslation(self.rootNode)
    local x2,y2,z2
    local tX,tY,tZ
    local dirX,dirZ
    local sideOffset
    local drop

    for i=spec.followingCurrentCount, leaderSpec.dropperCurrentCount do
        drop = leader:getTrailDrop(i)
        x2,y2,z2 = unpack(drop.position)

        dirX,dirZ = leader:getTrailDropDirection(i)
        -- Apply offset
        sideOffset = spec.offsetLR * (drop.followersOffsetPct or 1.0)
        tX = x2 - dirZ * sideOffset
        tY = y2
        tZ = z2 + dirX * sideOffset

        drawDebugLine(x1, y1+yOffset, z1, rgb[1],rgb[2],rgb[3], tX, tY+yOffset, tZ, rgb[1],rgb[2],rgb[3])

        x1,y1,z1 = tX,tY,tZ
    end
end

function FollowVehicle:cmdToggleTrailVisibility(maxEntries,yOffset)
    maxEntries = tonumber(maxEntries)
    FollowVehicle.debugTrailYOffset = tonumber(yOffset) or 4
    if maxEntries ~= nil then
        maxEntries = MathUtil.clamp(maxEntries, 5, FollowVehicle.MAX_TRAIL_ENTRIES - 1)
        FollowVehicle.debugTrailVisibleEntries = maxEntries
    else
        if FollowVehicle.debugTrailVisibleEntries <= 0 then
            FollowVehicle.debugTrailVisibleEntries = FollowVehicle.MAX_TRAIL_ENTRIES - 1
        else
            FollowVehicle.debugTrailVisibleEntries = -1
        end
    end
end

addConsoleCommand("modFV_TrailVisibility", "modFV_TrailVisibility <numTrailDrops> <yOffset>", "cmdToggleTrailVisibility", FollowVehicle)

-----

local function cleanUpDriveStrategies(spec)
    if spec.driveStrategies ~= nil and #spec.driveStrategies > 0 then
        spec.driveStrategyCollision = nil

        for i = #spec.driveStrategies, 1, -1 do
            spec.driveStrategies[i]:delete()
            table.remove(spec.driveStrategies, i)
        end

        spec.driveStrategies = {}
    end
end


function FollowVehicle:getIsFollowVehicleActive()
    local spec = getSpec(self)
    return spec.isActive
end

function FollowVehicle:getVehicleToFollow()
    local spec = getSpec(self)
    return spec.vehicleToFollow
end

function FollowVehicle:addFollower(vehicle)
    local spec = getSpec(self)
    spec.currentFollowers[vehicle] = vehicle
end

function FollowVehicle:removeFollower(vehicle)
    local spec = getSpec(self)
    spec.currentFollowers[vehicle] = nil
    if spec.selectedFollower == vehicle then
        spec.selectedFollower = nil
    end
end

function FollowVehicle:getAllFollowers(resultArray)
    local spec = getSpec(self)

    local nonDupes = {}
    for _, followerVehicle in pairs(spec.currentFollowers) do
        -- Make sure follower-vehicle is not in result-array already (else infinite recursion would occur, and we do not want to wait for that (neither the stack overflow error))
        local alreadyAdded = false
        for _,addedVehicle in pairs(resultArray) do
            if addedVehicle == followerVehicle then
                alreadyAdded = true
                break
            end
        end
        if not alreadyAdded then
            table.insert(resultArray, followerVehicle)
            table.insert(nonDupes, followerVehicle)
        end
    end
    for _, followerVehicle in pairs(nonDupes) do
        followerVehicle:getAllFollowers(resultArray)
    end
end

function FollowVehicle:getStartableAIJob(superFunc)
	local job = superFunc(self)
	if job == nil then
        local spec = getSpec(self)
        spec.vehicleToFollow = nil

		if self:getCanStartFollowVehicle() then
			local followJob = spec.followJob
			followJob:applyCurrentState(self, g_currentMission, g_currentMission.player.farmId, true, spec.vehicleToFollow)
			followJob:setValues()
			local success = followJob:validate(false)
			if success then
				job = followJob
			end
		end
	end
	return job
end

function FollowVehicle:getHasStartableAIJob(superFunc)
    return self:getCanStartFollowVehicle()
end

function FollowVehicle:getCanStartFollowVehicle()
    if self:getIsFollowVehicleActive() then
        return false
    end

    if self:getIsAIActive() then
        return false
    end

    local specAI = self.spec_aiFieldWorker
    if specAI and specAI.isActive then
        return false
    end

    specAI = self.spec_aiDrivable
    if specAI and specAI.isRunning then
        return false
    end

    return true
end

function FollowVehicle:startFollowVehicle(vehicleToFollow)
    local spec = getSpec(self)
    spec.isActive = true

    if self.isServer then
        spec.didNotMoveTimer = spec.didNotMoveTimeout

        spec.vehicleToFollow = vehicleToFollow
        spec.followingCurrentCount = self:findOptimalClosestTrailDrop(vehicleToFollow)
        if vehicleToFollow then
            vehicleToFollow:addFollower(self)
        end

        self:updateAIFollowVehicleDriveStrategies(vehicleToFollow)
    end

    AIFieldWorker.hiredHirables[self] = self

    self:raiseAIEvent("onAIFollowVehicleStart")
end

function FollowVehicle:stopFollowVehicle()
    local spec = getSpec(self)
    spec.isActive = false
    spec.aiDriveParams.valid = false
    AIFieldWorker.hiredHirables[self] = nil

    if nil ~= spec.vehicleToFollow then
        spec.vehicleToFollow:removeFollower(self)
        spec.vehicleToFollow = nil
    end        

    self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF, true)

    if self.isServer then
        WheelsUtil.updateWheelsPhysics(self, 0, spec.lastSpeedReal * spec.movingDirection, 0, true, true)
        cleanUpDriveStrategies(spec)
    end

    if self.brake ~= nil then
        self:brake(1)
    end

    local actionController = self.rootVehicle.actionController
    if actionController ~= nil then
        actionController:resetCurrentState()
    end

    self:raiseAIEvent("onAIFollowVehicleEnd")
end

function FollowVehicle:updateAIFollowVehicleDriveStrategies(vehicleToFollow)
    local spec = getSpec(self)

    cleanUpDriveStrategies(spec)

    local foundBaler = SpecializationUtil.hasSpecialization(Baler, spec.specializations) and self:getIsTurnedOn() and self:getIsLowered()
    for _, childVehicle in pairs(self.rootVehicle.childVehicles) do
        if SpecializationUtil.hasSpecialization(Baler, childVehicle.specializations) then
            if childVehicle:getIsTurnedOn() and childVehicle:getIsLowered() then
                foundBaler = true
            end
        end
    end

    if foundBaler then
        local driveStrategyFollowBaler = AIDriveStrategyFollowBaler.new()
        driveStrategyFollowBaler:setAIVehicle(self)
        table.insert(spec.driveStrategies, driveStrategyFollowBaler)
    end

    local driveStrategyFollowStopWhenTurnedOff = AIDriveStrategyFollowStopWhenTurnedOff.new()
    driveStrategyFollowStopWhenTurnedOff:setAIVehicle(self)
    driveStrategyFollowStopWhenTurnedOff:setForSpecializations(Combine, ForageWagon, StonePicker)
    table.insert(spec.driveStrategies, driveStrategyFollowStopWhenTurnedOff)

    --
    local driveStrategyFollowVehicle = AIDriveStrategyFollowVehicle.new()
    spec.driveStrategyCollision = AIDriveStrategyFollowVehicleCollision.new(driveStrategyFollowVehicle)

    spec.driveStrategyCollision:setAIVehicle(self)
    table.insert(spec.driveStrategies, spec.driveStrategyCollision)

    driveStrategyFollowVehicle:setAIVehicle(self)
    driveStrategyFollowVehicle:setVehicleToFollow(vehicleToFollow)
    table.insert(spec.driveStrategies, driveStrategyFollowVehicle)
end

function FollowVehicle:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if self.isServer and self:getIsFollowVehicleActive() then
        local spec = getSpec(self)

        for i = 1, #spec.driveStrategies do
            local driveStrategy = spec.driveStrategies[i]
            driveStrategy:update(dt)
        end

        self:updateAIFollowVehicle_DriveData(dt)
        self:updateAIFollowVehicle_Steering(dt)
    end
end

function FollowVehicle:updateAIFollowVehicle_DriveData(dt)
	local spec = getSpec(self)

    local vX, vY, vZ = getWorldTranslation(self.rootNode)
    local tX, tZ, moveForwards, strategyMaxSpeed, distanceToStop = nil
    local allowedMaxSpeed = math.huge
    if spec.isWaiting then
        allowedMaxSpeed = 0
    end

    for i = 1, #spec.driveStrategies do
        local driveStrategy = spec.driveStrategies[i]
        tX, tZ, moveForwards, strategyMaxSpeed, distanceToStop = driveStrategy:getDriveData(dt, vX, vY, vZ)
        allowedMaxSpeed = math.min(strategyMaxSpeed or math.huge, allowedMaxSpeed)

        if tX ~= nil then
            break
        end
    end

    if allowedMaxSpeed < 0
    or tX == nil          or tZ == nil
    or MathUtil.isNan(tX) or MathUtil.isNan(tZ)
    then
        spec.aiDriveParams.maxSpeed = 0
        if allowedMaxSpeed < 0 then
            self:stopCurrentAIJob(AIMessageErrorFollowerStopped.new())
        else
            self:stopCurrentAIJob(AIMessageSuccessFinishedJob.new())
        end
        return
    end

    local minimumSpeed = 5
    local lookAheadDistance = 5

    local distSpeed = math.max(minimumSpeed, allowedMaxSpeed * math.min(1, distanceToStop / lookAheadDistance))
    local speedLimit, _ = self:getSpeedLimit(true)
    allowedMaxSpeed = math.min(allowedMaxSpeed, distSpeed, speedLimit)
    allowedMaxSpeed = math.min(allowedMaxSpeed, self:getCruiseControlMaxSpeed())

    local isAllowedToDrive = allowedMaxSpeed ~= 0
    spec.aiDriveParams.moveForwards = moveForwards
    spec.aiDriveParams.tX = tX
    spec.aiDriveParams.tY = vY
    spec.aiDriveParams.tZ = tZ
    spec.aiDriveParams.maxSpeed = allowedMaxSpeed
    spec.aiDriveParams.valid = true

    if isAllowedToDrive and self:getLastSpeed() < 0.5 then
        spec.didNotMoveTimer = spec.didNotMoveTimer - dt

        if spec.didNotMoveTimer < 0 then
            self:stopCurrentAIJob(AIMessageErrorBlockedByObject.new())
        end
    else
        spec.didNotMoveTimer = spec.didNotMoveTimeout
    end

    --self:raiseAIEvent("onAIFollowVehicleActive")
end

function FollowVehicle:updateAIFollowVehicle_Steering(dt)
	local spec = getSpec(self)

	if spec.aiDriveParams.valid then
		local moveForwards = spec.aiDriveParams.moveForwards
		local tX = spec.aiDriveParams.tX
		local tY = spec.aiDriveParams.tY
		local tZ = spec.aiDriveParams.tZ
		local maxSpeed = spec.aiDriveParams.maxSpeed
		local pX, _, pZ = worldToLocal(self:getAISteeringNode(), tX, tY, tZ)

        if not moveForwards then
            local aiReverserNode = self:getAIReverserNode()
            if nil ~= aiReverserNode then
                pX, _, pZ = worldToLocal(aiReverserNode, tX, tY, tZ)
            elseif self.spec_articulatedAxis ~= nil and self.spec_articulatedAxis.aiRevereserNode ~= nil then
                pX, _, pZ = worldToLocal(self.spec_articulatedAxis.aiRevereserNode, tX, tY, tZ)
            end
        end

		local acceleration = 1
		local isAllowedToDrive = maxSpeed ~= 0

		AIVehicleUtil.driveToPoint(self, dt, acceleration, isAllowedToDrive, moveForwards, pX, pZ, maxSpeed)
	end
end

----

function FollowVehicle:findVehiclesNearby()
    local foundVehicles = {}

    local wx,wy,wz  = getWorldTranslation(self.rootNode)
    local node      = self:getAISteeringNode()
    local rx,ry,rz  = localDirectionToWorld(node, 0,0,1)

    for _,vehicleObj in pairs(g_currentMission.vehicles) do
        if vehicleObj ~= self then
            local vehicleSpec = getSpec(vehicleObj)
            if  nil ~= vehicleSpec
            and nil ~= vehicleSpec.dropperCircularArray -- Make sure other vehicle has circular array
            and SpecializationUtil.hasSpecialization(AIJobVehicle, vehicleObj.specializations)
            and SpecializationUtil.hasSpecialization(Drivable,     vehicleObj.specializations)
            then
                if (nil ~= vehicleObj.getIsTabbable and vehicleObj:getIsTabbable())
                or (nil == vehicleObj.getIsTabbable)
                then
                    local vehicleNode = vehicleObj:getAISteeringNode()
                    if nil ~= vehicleNode and nil ~= vehicleObj.rootNode then
                        local vx,vy,vz = getWorldTranslation(vehicleObj.rootNode)
                        local dx,dz = vx-wx, vz-wz
                        local dist = MathUtil.vector2Length(dx,dz)
                        if dist <= 100 then
                            -- Make sure that the other vehicle is actually driving "away from us"
                            -- I.e. in the same direction
                            local vrx, vry, vrz = localDirectionToWorld(vehicleNode, 0,0,1)
                            if MathUtil.dotProduct(rx,0,rz, vrx,0,vrz) > 0.3 then
                                table.insert(foundVehicles, { vehicle=vehicleObj, selected=false, inViewport=false })
                            end
                        end
                    end
                end
            end
        end
    end

    return foundVehicles
end

function FollowVehicle:findOptimalClosestTrailDrop(closestVehicle)
    if not self.isServer then
        return 0
    end

    local followCurrentIndex = 0
    if nil ~= closestVehicle then
        -- Find closest "breadcrumb"
        local closestDistance = 200
        local closestSpec = getSpec(closestVehicle)
        if closestSpec then
            local wx,wy,wz  = getWorldTranslation(self.rootNode)
            local node      = self:getAISteeringNode()
            local rx,ry,rz  = localDirectionToWorld(node, 0,0,1)
            local rlength   = MathUtil.vector2Length(rx,rz)
            local rotDeg    = math.deg(math.atan2(rx/rlength,rz/rlength))
            local rotRad    = MathUtil.degToRad(rotDeg-45.0)
            local rotSin,rotCos = math.sin(rotRad),math.cos(rotRad)

            local stopSearchAfterDistanceIncreasingCount = 3
            for i=closestSpec.dropperCurrentCount, math.max(closestSpec.dropperCurrentCount - FollowVehicle.MAX_TRAIL_ENTRIES + 1,0), -1 do
                local crumb = closestVehicle:getTrailDrop(i)
                if nil ~= crumb then
                    local x,y,z = unpack(crumb.position)
                    -- Translate
                    local dx,dz = x-wx, z-wz
                    local dist = MathUtil.vector2Length(dx,dz)
                    --local r = Utils.getYRotationFromDirection(dx,dz)
                    --log(string.format("#%d - xz:%f/%f - dxdz:%f/%f - r:%f - dist:%f", i, x,z, dx,dz, r, dist))
                    if dist > 2 then
                        -- Rotate to see if the point is "in front of us"
                        local nx = dx * rotCos - dz * rotSin
                        local nz = dx * rotSin + dz * rotCos
                        if (nx > 0) and (nz > 0) then
                            -- Is trail-drop's direction roughly the same as vehicle's direction
                            local trx,try,trz = unpack(crumb.direction)
                            local dotResult = MathUtil.dotProduct(rx,0,rz, trx,0,trz)
                            --
                            if (dist < closestDistance) and (dotResult > 0.4) then
                                --log(string.format("#%d - xz:%f/%f - dxdz:%f/%f - dist:%f - nxnz:%f/%f", i, x,z, dx,dz, dist, nx,nz))
                                closestDistance = dist
                                followCurrentIndex = i
                            else
                                stopSearchAfterDistanceIncreasingCount = stopSearchAfterDistanceIncreasingCount - 1
                                if stopSearchAfterDistanceIncreasingCount <= 0 then
                                    break
                                end
                            end
                        end
                    end
                end
            end
            -- TODO: Figure out a better algorithm, for detecting if vehicle is at the side of the closest-vehicle and therefore cannot find a good closest trail-drop
            if 0 == followCurrentIndex then
                -- Unable to find "nearest trail-drop", so just use closest-vehicle's current trail-drop
                followCurrentIndex = closestSpec.dropperCurrentCount
            end
        end
    end

    return followCurrentIndex
end
