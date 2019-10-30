--
-- Follow Me
--
-- @author  Decker_MMIV (DCK)
-- @contact forum.farming-simulator.com
-- @date    2019-01-xx
--
-- Special credits to Rushmead for doing alot of the initial FS19 script changes.
--  https://github.com/Rushmead/FarmSim_Mod_FollowMe
--

--[[
Notes:

Possible mouse support?:
- ModifierKey + Mouse movement/buttons/wheel
- wheel = select; myself, follower(1), follower(2), ...
- myself: when not following: right-mouse on vehicle in front; start following that
- myself: right-mouse on vehicle at back/behind; it start following me (automatically start motor too)
- myself/follower(#): when following: left-mouse; pause/resume
- myself/follower(#): when following: right-mouse + mouse-pointer: set following distance/offset

--]]

-- For debugging
local function log(...)
  if true then
      local txt = ""
      for idx = 1,select("#", ...) do
          txt = txt .. tostring(select(idx, ...))
      end
      print(string.format("%7ums FollowMe.LUA ", (nil ~= g_currentMission and g_currentMission.time or 0)) .. txt)
  end
end

local function vec2str(x,y,z)
  if "table" == type(x) then
    x,y,z = unpack(x)
  end
  return ("%.3f/%.3f/%.3f"):format(x,y,z)
end

----

FollowMe = {}

local modSpecTypeName = "followMe"


--
FollowMe.cQuickTapTimeMs                = 1000/3 -- '0.3 second'
FollowMe.cMinDistanceBetweenDrops       = 5
FollowMe.cBreadcrumbsMaxEntries         = 150
FollowMe.cTextFadeoutBeginMS            = 5000
FollowMe.cCollisionNotificationDelayMS  = 10000

FollowMe.debugDraw = {}

FollowMe.COMMAND_NONE           = 0
FollowMe.COMMAND_START          = 1
FollowMe.COMMAND_WAITRESUME     = 2
FollowMe.COMMAND_STOP           = 3
FollowMe.COMMAND_TOGGLE_SENSOR  = 4
FollowMe.NUM_BITS_COMMAND = 3

FollowMe.STATE_NONE             = 0
FollowMe.STATE_STOPPING         = 1
FollowMe.STATE_STARTING         = 2
FollowMe.STATE_WAITING          = 3
FollowMe.STATE_UNUSED1          = 4
FollowMe.STATE_UNUSED2          = 5
FollowMe.STATE_FOLLOWING        = 6
FollowMe.STATE_COLLIDING        = 7
FollowMe.NUM_BITS_STATE   = 3

FollowMe.REASON_NONE            = 0
FollowMe.REASON_USER_ACTION     = 1
FollowMe.REASON_NO_TRAIL_FOUND  = 2
FollowMe.REASON_TOO_FAR_BEHIND  = 3
FollowMe.REASON_LEADER_REMOVED  = 4
FollowMe.REASON_ENGINE_STOPPED  = 5
FollowMe.REASON_ALREADY_AI      = 6
FollowMe.REASON_CLEAR_WARNING   = 7
FollowMe.NUM_BITS_REASON  = 3

--
function FollowMe.prerequisitesPresent(specializations)
  return  true  == SpecializationUtil.hasSpecialization(Drivable      ,specializations)
      and true  == SpecializationUtil.hasSpecialization(Motorized     ,specializations)
      and true  == SpecializationUtil.hasSpecialization(Enterable     ,specializations)
      and true  == SpecializationUtil.hasSpecialization(AIVehicle     ,specializations)
      and true  == SpecializationUtil.hasSpecialization(Lights        ,specializations)
      and false == SpecializationUtil.hasSpecialization(ConveyorBelt  ,specializations)
      and false == SpecializationUtil.hasSpecialization(Locomotive    ,specializations)
end

function FollowMe.registerFunctions(vehicleType)
  for _,funcName in pairs( {
    "getIsFollowMeActive",
    "getIsFollowMeWaiting",
  } ) do
    SpecializationUtil.registerFunction(vehicleType, funcName, FollowMe[funcName])
  end

  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAINeedsTrafficCollisionBox", FollowMe.getAINeedsTrafficCollisionBox)
end

function FollowMe.registerEventListeners(vehicleType)
  for _,funcName in pairs( {
    "onPostLoad",
    "onLoadFinished",
    "onDelete",
    "onWriteStream",
    "onReadStream",
    "onWriteUpdateStream",
    "onReadUpdateStream",
    "onUpdateTick",
    "onDraw",
    "onRegisterActionEvents",
    "onAIStart",
    "onAIEnd",
    "onLightsTypesMaskChanged",
    "onBeaconLightsVisibilityChanged",
    "onTurnLightStateChanged",
  } ) do
    SpecializationUtil.registerEventListener(vehicleType, funcName, FollowMe)
  end
end

function FollowMe:onPostLoad(savegame)
    local spec = self.spec_followMe
    spec.actionEvents = {}

    spec.sumSpeed = 0
    spec.sumCount = 0
    spec.DropperCircularArray = {}
    spec.DropperCurrentIndex = -1
    spec.StalkerVehicleObj = nil  -- Needed in case self is being deleted.

    spec.FollowState = FollowMe.STATE_NONE
    spec.FollowVehicleObj = nil  -- What vehicle is this one following (if any)
    spec.FollowCurrentIndex = -1
    spec.distanceFB = 25 -- Distance. front(<0), back(>0)
    spec.offsetLR = 0 -- Offset. left(<0), right(>0)
    spec.prevOffsetLR = 0
    spec.collisionSensorIgnored = false

    spec.ShowWarningText = nil
    spec.ShowWarningTime = 0
    spec.textFadeoutBegin = 0

    if nil ~= savegame and not savegame.resetVehicles then
        local modKey = savegame.key ..".".. modSpecTypeName
        local distance = getXMLInt(savegame.xmlFile, modKey .. "#distance")
        local offset = getXMLFloat(savegame.xmlFile, modKey .. "#offset")
        if nil ~= distance then
            FollowMe.setDistance(self, distance, true)
        end
        if nil ~= offset then
            FollowMe.setOffset(self, offset, true)
        end
    end

    spec.dirtyFlag = self:getNextDirtyFlag()
end

function FollowMe:onLoadFinished(savegame)
  local spec = self.spec_followMe
  spec.origPricePerMS = self.spec_aiVehicle.pricePerMS

  if nil ~= g_server then
    -- Drop two initial 'bread crumbs', to make findClosestVehicle() to work
    local maxSpeed = 10
    local direction = FollowMe.getReverserDirection(self)
    FollowMe.addDrop(self, maxSpeed, self:getTurnLightState(), direction)
    FollowMe.addDrop(self, maxSpeed, self:getTurnLightState(), direction)
  end
end

function FollowMe:saveToXMLFile(xmlFile, key, usedModNames)
--log("FollowMe:saveToXMLFile(",xmlFile,",", key,",", usedModNames,")")
  local spec = self.spec_followMe
  setXMLInt(  xmlFile, key.."#distance", spec.distanceFB)
  setXMLFloat(xmlFile, key.."#offset",   spec.offsetLR)
end

function FollowMe:onDelete()
--log("FollowMe:onDelete()")
    local spec = self.spec_followMe
    if nil ~= spec.StalkerVehicleObj and nil ~= g_server then
        -- Stop the stalker-vehicle
        if FollowMe.getIsFollowMeActive(spec.StalkerVehicleObj) then
          FollowMe.stopFollowMe(spec.StalkerVehicleObj, nil, FollowMe.REASON_USER_ACTION)
        end
    end
end

function FollowMe:getCanStartFollowMe()
  if g_currentMission.disableAIVehicle then
    return false
  end
  if self:getIsAIActive() then
    return false
  end
  if FollowMe.getIsFollowMeActive(self) then
    return false
  end
  return true
end

function FollowMe:getIsFollowMeActive()
  local specAI = self.spec_aiVehicle
  if nil == specAI then
    return false
  end
  return ("FollowMe" == specAI.mod_ForcedDrivingStrategyName)
end

function FollowMe:getIsFollowMeWaiting()
  local spec = self.spec_followMe
  return spec.FollowState == FollowMe.STATE_WAITING
end

function FollowMe:getAINeedsTrafficCollisionBox(superFunc)
  if FollowMe.getIsFollowMeActive(self) then
    return false
  end
  return superFunc(self)
end

function FollowMe:onAIStart()
  local specFM = self.spec_followMe
  local specAI = self.spec_aiVehicle

--log("FollowMe:onAIStart() followMeIsStarted=",FollowMe.getIsFollowMeActive(self))

  if FollowMe.getIsFollowMeActive(self) then
    specAI.pricePerMS = Utils.getNoNil(specFM.origPricePerMS, 1500) * 0.2 -- FollowMe AIs wage is only 20% of base-game's AI.

--     -- Looks like patch 1.5.1.0 removed the `aiTrafficCollisionRemoveDelay`
--     if nil ~= specAI.aiTrafficCollisionRemoveDelay then
--       -- In case player is so fast, that after stopping a regular AI, and in less than 200ms he manages to start FollowMe, then ensure the traffic collision is deleted.
--       if specAI.aiTrafficCollisionRemoveDelay > 0 then
--         if specAI.aiTrafficCollision ~= nil then
--           if entityExists(specAI.aiTrafficCollision) then
--             delete(specAI.aiTrafficCollision)
--           end
--         end
--         specAI.aiTrafficCollisionRemoveDelay = 0
--       end
--     end

--     if nil ~= specAI.aiTrafficCollision then
-- log("Setting specAI.aiTrafficCollision = nil")
--       -- Bug fix for (1.3.0.0-beta) base-game's script, where it does not set `spec.aiTrafficCollision` to nil after it has been deleted in `AIVehicle:onUpdateTick`.
--       -- If this 'set to nil' is not done, then `AIVehicle:onUpdate` will attempt to translate + rotate it, even when FollowMe is not using such a traffic collision.
--       specAI.aiTrafficCollision = nil
--     end

    --
    self:raiseDirtyFlags(specFM.dirtyFlag)
  end
end

function FollowMe:onAIEnd()
  local specFM = self.spec_followMe
  local specAI = self.spec_aiVehicle

--log("FollowMe:onAIEnd() followMeIsStarted=",FollowMe.getIsFollowMeActive(self))

  if FollowMe.getIsFollowMeActive(self) then
    specAI.pricePerMS = specFM.origPricePerMS -- Restore wage to base-game's value.

    self:raiseDirtyFlags(specFM.dirtyFlag)
  end
end

function FollowMe:getReverserDirection()
  if nil ~= self.spec_reverseDriving then
    return (self.spec_reverseDriving.isReverseDriving and -1) or 1
  end
  return 1
end

function FollowMe:onWriteStream(streamId, connection)
--log("FollowMe:onWriteStream(",streamId,",",connection,")")
    local spec = self.spec_followMe
    streamWriteInt8(            streamId, Utils.getNoNil(spec.distanceFB, 0))
    streamWriteInt8(            streamId, Utils.getNoNil(spec.offsetLR,   0) * 2)
    NetworkUtil.writeNodeObject(streamId, spec.StalkerVehicleObj)

    if streamWriteBool(streamId, FollowMe.getIsFollowMeActive(self)) then
        streamWriteBool(            streamId, spec.collisionSensorIgnored)
        streamWriteUIntN(           streamId, spec.FollowState,   FollowMe.NUM_BITS_STATE)
        NetworkUtil.writeNodeObject(streamId, spec.FollowVehicleObj)
    end
  end

function FollowMe:onReadStream(streamId, connection)
--log("FollowMe:onReadStream(",streamId,",",connection,")")
    local spec = self.spec_followMe
    local distance         = streamReadInt8(            streamId)
    local offset           = streamReadInt8(            streamId) / 2
    spec.StalkerVehicleObj = NetworkUtil.readNodeObject(streamId)

    if streamReadBool(streamId) then
        local sensor          = streamReadBool(            streamId)
        spec.FollowState      = streamReadUIntN(           streamId, FollowMe.NUM_BITS_STATE)
        spec.FollowVehicleObj = NetworkUtil.readNodeObject(streamId)

        FollowMe.setSensor(self, sensor, true)
    end

    FollowMe.setDistance(self, distance, true)
    FollowMe.setOffset(  self, offset,   true)
end

function FollowMe:onWriteUpdateStream(streamId, connection, dirtyMask)
  if not connection:getIsServer() then
    local spec = self.spec_followMe

    if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
--log("FollowMe:onWriteUpdateStream(",self,",",streamId,",", connection,",", dirtyMask,")")
      streamWriteBool(            streamId, spec.collisionSensorIgnored)
      streamWriteUIntN(           streamId, spec.FollowState,  FollowMe.NUM_BITS_STATE)
      streamWriteInt8(            streamId, spec.distanceFB)
      streamWriteInt8(            streamId, spec.offsetLR * 2)
      NetworkUtil.writeNodeObject(streamId, spec.FollowVehicleObj )
      NetworkUtil.writeNodeObject(streamId, spec.StalkerVehicleObj)
    end
  end
end

function FollowMe:onReadUpdateStream(streamId, timestamp, connection)
  if connection:getIsServer() then
    local spec = self.spec_followMe

    if streamReadBool(streamId) then
--log("FollowMe:onReadUpdateStream(",self,",",streamId,",", timestamp,",", connection,")")
      spec.collisionSensorIgnored = streamReadBool(            streamId)
      local newFollowState        = streamReadUIntN(           streamId, FollowMe.NUM_BITS_STATE)
      spec.distanceFB             = streamReadInt8(            streamId)
      spec.offsetLR               = streamReadInt8(            streamId) / 2
      local newFollowVehicleObj   = NetworkUtil.readNodeObject(streamId)
      local newStalkerVehicleObj  = NetworkUtil.readNodeObject(streamId)

      spec.needActionEventUpdate = false
        or (spec.FollowState       ~= newFollowState)
        or (spec.FollowVehicleObj  ~= newFollowVehicleObj)
        or (spec.StalkerVehicleObj ~= newStalkerVehicleObj)

      spec.FollowState       = newFollowState
      spec.FollowVehicleObj  = newFollowVehicleObj
      spec.StalkerVehicleObj = newStalkerVehicleObj
    end
  end
end

function FollowMe:getFollowNode()
    local node = self.steeringCenterNode
    if nil == node then
      node = self.components[1].node
    end
    return node
end

--[[
--FollowMe.objectCollisionMask = 32+64+128+256+4096
function FollowMe:mouseEvent(posX, posY, isDown, isUp, button)
    if FollowMe.showFollowMeFl then
        FollowMe.raycastResult = nil

        local x,y,z = getWorldTranslation(self.cameras[self.camIndex].cameraNode)
        local wx,wy,wz = unProject(posX, posY, 1)
        local dx,dy,dz = wx-x, wy-y, wz-z
--print(table.concat({"raycastDir=",dx,",",dy,",",dz},""))
        raycastAll(x, y, z, dx, dy, dz, "raycastCallback", 500, FollowMe) --, FollowMe.objectCollisionMask)

        if nil ~= FollowMe.raycastResult then
            wx,wy,wz = unpack(FollowMe.raycastResult.xyz)
            --print(table.concat({"mouse=",posX,",",posY," / world=",wx,",",wy,",",wz},""))

            --FollowMe.cursorXYZ = { wx,wy,wz }

            local cNode         = FollowMe.getFollowNode(self)
            local vX,vY,vZ      = getWorldTranslation(cNode)
            local vRX,vRY,vRZ   = localDirectionToWorld(cNode, 0,0, FollowMe.getReverserDirection(self))
            --print(table.concat({"veh=",vX,",",vY,",",vZ," / rot=",vRX,",",vRY,",",vRZ},""))

            local lx = vX - wx
            local lz = vZ - wz
            --print(table.concat({"offset=",lx,",",lz},""))

            local ox = (lx * vRZ) + (lz * vRX)
            local oz = (lx * vRX) + (lz * vRZ)
            --print(table.concat({"offset=",ox,",",oz},""))

            FollowMe.cursorXYZ = { vX+ox,vY,vZ+oz }

            if isDown and button == Input.MOUSE_BUTTON_LEFT then
                local spec = self.spec_followMe --FollowMe.getSpec(self)
                local stalker = spec.StalkerVehicleObj
                if nil ~= stalker then
                    FollowMe.setDistance(stalker, oz)
                    FollowMe.setOffset(  stalker, ox)
                end
            end
        end
    end
end

function FollowMe.raycastCallback(self, hitObjectId, x, y, z, distance)
--print(hitObjectId .." : " .. tostring(getName(hitObjectId)))
    if hitObjectId == g_currentMission.terrainRootNode then
        FollowMe.raycastResult = { objectId=hitObjectId, xyz={x,y,z} }
        return false -- stop raycasting
    end
end
--]]

function FollowMe:copyDrop(crumb, targetXYZ)
    assert(nil ~= g_server)

    local spec = self.spec_followMe

    spec.DropperCurrentIndex = spec.DropperCurrentIndex + 1 -- Keep incrementing index, so followers will be able to detect if they get too far behind of the circular-array.

    local dropIndex = 1+(spec.DropperCurrentIndex % FollowMe.cBreadcrumbsMaxEntries)
    if nil == targetXYZ then
        spec.DropperCircularArray[dropIndex] = crumb
    else
        -- Due to a different target, make a "deep-copy" of the crumb.
        spec.DropperCircularArray[dropIndex] = {
            trans           = targetXYZ,
            rot             = crumb.rot,
            maxSpeed        = crumb.maxSpeed,
            turnLightState  = crumb.turnLightState,
        }
    end
end

function FollowMe:addDrop(maxSpeed, turnLightState, reverserDirection)
    assert(nil ~= g_server)

    local spec = self.spec_followMe
    spec.DropperCurrentIndex = spec.DropperCurrentIndex + 1 -- Keep incrementing index, so followers will be able to detect if they get too far behind of the circular-array.

    local node = self:getAIVehicleSteeringNode()
    local dropIndex = 1+(spec.DropperCurrentIndex % FollowMe.cBreadcrumbsMaxEntries)
    spec.DropperCircularArray[dropIndex] = {
        trans           = { getWorldTranslation(node) }, -- { vX,vY,vZ },
        rot             = { localDirectionToWorld(node, 0,0,Utils.getNoNil(reverserDirection,1)) }, -- { vrX,vrY,vrZ },
        maxSpeed        = maxSpeed,
        turnLightState  = turnLightState,
    }

    --log(string.format("Crumb #%d: trans=%f/%f/%f, rot=%f/%f/%f, avgSpeed=%f", dropIndex, wx,wy,wz, rx,ry,rz, maxSpeed))
end

function FollowMe:setDistance(newValue, noSendEvent)
  local spec = self.spec_followMe
  spec.distanceFB = MathUtil.clamp(newValue, -50, 127) -- Min -128 and Max 127 due to writeStreamInt8().
  if not noSendEvent then
    if nil == g_server then
      -- Client - Send command to server
      g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_NONE, nil, nil))
    else
      -- Server - Need to broadcast to clients
      self:raiseDirtyFlags(spec.dirtyFlag)
    end
  end
end

function FollowMe:adjustDistance(diffValue, noSendEvent)
  FollowMe.setDistance(self, self.spec_followMe.distanceFB + diffValue, noSendEvent)
end

function FollowMe:setOffset(newValue, noSendEvent)
  local spec = self.spec_followMe
  spec.offsetLR = MathUtil.clamp(newValue, -50.0, 50.0)
  if not noSendEvent then
    if nil == g_server then
      -- Client - Send command to server
      g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_NONE, nil, nil))
    else
      -- Server - Need to broadcast to clients
      self:raiseDirtyFlags(spec.dirtyFlag)
    end
  end
end

function FollowMe:adjustOffset(diffValue, noSendEvent)
  FollowMe.setOffset(self, self.spec_followMe.offsetLR + diffValue, noSendEvent)
end

function FollowMe:toggleOffset(noSendEvent)
  local spec = self.spec_followMe
  if 0 == spec.offsetLR and 0 ~= spec.prevOffsetLR then
    spec.offsetLR = -spec.prevOffsetLR
    spec.prevOffsetLR = 0
  else
    spec.prevOffsetLR = spec.offsetLR
    spec.offsetLR = 0
  end
  FollowMe.setOffset(self, spec.offsetLR, noSendEvent)
end

function FollowMe:setSensor(newValue, noSendEvent)
  local spec = self.spec_followMe
  spec.collisionSensorIgnored = newValue
  if not noSendEvent then
    if nil == g_server then
      -- Client - Send command to server
      g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_NONE, nil, nil))
    else
      -- Server - Need to broadcast to clients
      self:raiseDirtyFlags(spec.dirtyFlag)
    end
  end
end

function FollowMe:toggleSensor(noSendEvent)
  FollowMe.setSensor(self, not self.spec_followMe.collisionSensorIgnored, noSendEvent)
end

local actionFuncsByName = {
  FollowMeMyToggle = function(self)
    if FollowMe.getIsFollowMeActive(self) then
        FollowMe.stopFollowMe(self, nil, FollowMe.REASON_USER_ACTION)
    elseif g_currentMission:getHasPlayerPermission("hireAssistant") then
      if FollowMe.getCanStartFollowMe(self) then
        FollowMe.startFollowMe(self, nil, g_currentMission.player.farmId)
      end
    else
        -- No permission
    end
  end
  ,
  FollowMeMyPause = function(self)
    FollowMe.waitResumeFollowMe(self, nil, FollowMe.REASON_USER_ACTION)
  end
  ,
  FollowMeMyOffs = function(self, value)
    if math.abs(value) >= 0.8 then
      FollowMe.adjustOffset(self, 0.5 * MathUtil.sign(value))
    end
  end
  ,
  FollowMeMyOffsTgl = function(self)
    FollowMe.toggleOffset(self)
  end
  ,
  FollowMeMySensorTgl = function(self)
    FollowMe.toggleSensor(self)
  end
  ,
  FollowMeFlStop = function(self)
    local stalker = self.spec_followMe.StalkerVehicleObj
    if nil ~= stalker and FollowMe.getIsFollowMeActive(stalker) then
        FollowMe.stopFollowMe(stalker, nil, FollowMe.REASON_USER_ACTION)
    end
  end
  ,
  FollowMeFlPause = function(self)
    local stalker = self.spec_followMe.StalkerVehicleObj
    FollowMe.waitResumeFollowMe(stalker, nil, FollowMe.REASON_USER_ACTION)
  end
  ,
  FollowMeFlOffs = function(self, value)
    if math.abs(value) >= 0.8 then
      local stalker = self.spec_followMe.StalkerVehicleObj
      FollowMe.adjustOffset(stalker, 0.5 * MathUtil.sign(value))
    end
  end
  ,
  FollowMeFlOffsTgl = function(self)
    local stalker = self.spec_followMe.StalkerVehicleObj
    FollowMe.toggleOffset(stalker)
  end
  ,
  FollowMeFlSensorTgl = function(self)
    local stalker = self.spec_followMe.StalkerVehicleObj
    FollowMe.toggleSensor(stalker)
  end
}

function FollowMe:handleAction(actionName, inputValue, callbackState, isAnalog, isMouse)
  local action = actionFuncsByName[actionName]
  if action then
    local spec = self.spec_followMe
    spec.textFadeoutBegin = g_time + FollowMe.cTextFadeoutBeginMS
    action(self, inputValue)
  end
end

function FollowMe:actionAdjustDistance(actionName, inputValue, callbackState, isAnalog, isMouse)
  local spec = self.spec_followMe

  spec.textFadeoutBegin = g_time + FollowMe.cTextFadeoutBeginMS

  if nil == spec.lastInputTime then
    if math.abs(inputValue) >= 0.8 then
      -- Start of input
      spec.lastInputValue = inputValue
      spec.lastInputTime = g_time
      spec.nextInputTimeout = g_time + FollowMe.cQuickTapTimeMs
    end
  else
    local who = self
    if 1 == callbackState then
      who = spec.StalkerVehicleObj
    end

    if math.abs(inputValue) >= 0.5 and nil ~= who then
      -- Long-hold? Adjust distance in steps of 1
      if spec.nextInputTimeout < g_time then
        FollowMe.adjustDistance(who, 1 * MathUtil.sign(spec.lastInputValue))
        spec.nextInputTimeout = g_time + 250
      end
    else
      -- Short-tap? Adjust distance in steps of 5
      if spec.lastInputTime > g_time - FollowMe.cQuickTapTimeMs and nil ~= who then
        FollowMe.adjustDistance(who, 5 * MathUtil.sign(spec.lastInputValue))
      end
      spec.lastInputValue = nil
      spec.lastInputTime = nil
      spec.nextInputTimeout = nil
    end
  end
end


function FollowMe:onRegisterActionEvents(isSelected, isOnActiveVehicle, arg3, arg4, arg5)
--log("FollowMe:onRegisterActionEvents(",self,") ",isSelected," ",isOnActiveVehicle," ",arg3," ",arg4," ",arg5," isClient=",self.isClient)
    --Actions are only relevant if the function is run clientside
    if not self.isClient then
      return
    end

    local spec = self.spec_followMe
    self:clearActionEventsTable(spec.actionEvents)

    local function addActionEvents(veh, prio, tbl)
      for _,actionElem in pairs(tbl) do
        local actionName = actionElem[1]
        local actionText = actionElem[2]
        local succ, eventID, colli = veh:addActionEvent(spec.actionEvents, actionName, veh, FollowMe.handleAction, false, true, false, true, nil)
        if nil ~= actionText then
          g_inputBinding:setActionEventText(eventID, actionText)
        end
        if nil ~= prio then
          g_inputBinding:setActionEventTextPriority(eventID, prio)
        end
        g_inputBinding:setActionEventTextVisibility(eventID, true)
      end
    end

    local isEntered = self:getIsEntered()
    local activeForInput = self:getIsActiveForInput(true) and not self.isConveyorBelt
    local isFollowMeActive = FollowMe.getIsFollowMeActive(self)
--log("FollowMe:onRegisterActionEvents(",self,") isEntered=",isEntered," activeForInput=",activeForInput," followMeActive=",isFollowMeActive," hasStalker=",(nil ~= spec.StalkerVehicleObj))
    if isEntered then
      if (activeForInput or isFollowMeActive) then
        addActionEvents(self, nil, {
          { InputAction.FollowMeMyToggle, g_i18n:getText(isFollowMeActive and "FollowMeMyTurnOff" or "FollowMeMyTurnOn") }
        } )
        if isFollowMeActive then
          addActionEvents(self, GS_PRIO_VERY_HIGH, {
            { InputAction.FollowMeMyPause,     g_i18n:getText(self:getIsFollowMeWaiting() and "FollowMeMyResume" or "FollowMeMyWait") },
            { InputAction.FollowMeMyOffs,      g_i18n:getText("FollowMeMyOffs") },
            { InputAction.FollowMeMyOffsTgl,   nil },
            { InputAction.FollowMeMySensorTgl, g_i18n:getText("FollowMeMySensor") },
          } )
          --
          local _,evtId = self:addActionEvent(spec.actionEvents, InputAction.FollowMeMyDist, self, FollowMe.actionAdjustDistance, true, false, true, true, 0)
          g_inputBinding:setActionEventText(evtId, g_i18n:getText("FollowMeMyDist"))
          g_inputBinding:setActionEventTextPriority(evtId, GS_PRIO_VERY_HIGH)
          g_inputBinding:setActionEventTextVisibility(evtId, true)
        end
      end
      if (activeForInput or isFollowMeActive) and nil ~= spec.StalkerVehicleObj then
        addActionEvents(self, GS_PRIO_HIGH, {
          { InputAction.FollowMeFlStop,      nil },
          { InputAction.FollowMeFlPause,     g_i18n:getText(spec.StalkerVehicleObj:getIsFollowMeWaiting() and "FollowMeFlResume" or "FollowMeFlWait") },
          { InputAction.FollowMeFlOffs,      g_i18n:getText("FollowMeFlOffs") },
          { InputAction.FollowMeFlOffsTgl,   nil },
          { InputAction.FollowMeFlSensorTgl, g_i18n:getText("FollowMeFlSensor") },
        } )
        --
        local _,evtId = self:addActionEvent(spec.actionEvents, InputAction.FollowMeFlDist, self, FollowMe.actionAdjustDistance, true, false, true, true, 1)
        g_inputBinding:setActionEventText(evtId, g_i18n:getText("FollowMeFlDist"))
        g_inputBinding:setActionEventTextPriority(evtId, GS_PRIO_HIGH)
        g_inputBinding:setActionEventTextVisibility(evtId, true)
      end
    end
end

function FollowMe:onLightsTypesMaskChanged(lightsTypesMask)
  local spec = self.spec_followMe
  if nil ~= spec.StalkerVehicleObj then
    spec.StalkerVehicleObj:setLightsTypesMask(lightsTypesMask)
  end
end

function FollowMe:onBeaconLightsVisibilityChanged(beaconVisibility)
  local spec = self.spec_followMe
  if nil ~= spec.StalkerVehicleObj then
    spec.StalkerVehicleObj:setBeaconLightsVisibility(beaconVisibility)
  end
end

function FollowMe:onTurnLightStateChanged(turnLightState)
  local spec = self.spec_followMe
  if nil ~= spec.StalkerVehicleObj then
    local leaderSpec  = spec
    local stalkerSpec = spec.StalkerVehicleObj.spec_followMe
    local crumbIndexDiff = leaderSpec.DropperCurrentIndex - stalkerSpec.FollowCurrentIndex
    if crumbIndexDiff <= 0 then
      spec.StalkerVehicleObj:setTurnLightState(turnLightState)
    end
  end
end

function FollowMe:onUpdateTick(dt, isActiveForInput, isSelected)
    local spec = self.spec_followMe

    if nil ~= g_server and nil ~= spec then
        if FollowMe.getIsFollowMeActive(self) and nil ~= spec.FollowVehicleObj then
            local leader = spec.FollowVehicleObj
            local leaderSpec = leader.spec_followMe
            local crumbIndexDiff = leaderSpec.DropperCurrentIndex - spec.FollowCurrentIndex
            if crumbIndexDiff > 0 then
              local crumb = leaderSpec.DropperCircularArray[1+(spec.FollowCurrentIndex % FollowMe.cBreadcrumbsMaxEntries)]
              self:setTurnLightState(crumb.turnLightState)
            end
        else
          local direction = FollowMe.getReverserDirection(self)
          if (direction * self.movingDirection > 0) then  -- Must drive forward to drop crumbs
            spec.sumSpeed = spec.sumSpeed + self.lastSpeed
            spec.sumCount = spec.sumCount + 1
            --
            local node = self:getAIVehicleSteeringNode()
            local vX,vY,vZ = getWorldTranslation(node)
            local oX,oY,oZ = unpack(spec.DropperCircularArray[1+(spec.DropperCurrentIndex % FollowMe.cBreadcrumbsMaxEntries)].trans)
            local distancePrevDrop = MathUtil.vector2LengthSq(oX - vX, oZ - vZ)
            if distancePrevDrop >= FollowMe.cMinDistanceBetweenDrops then
                local maxSpeed = math.max(1, (spec.sumSpeed / spec.sumCount) * 3600)
                FollowMe.addDrop(self, maxSpeed, self:getTurnLightState(), direction)
                --
                spec.sumSpeed = 0
                spec.sumCount = 0
            end
          end
        end
    end

    if true == spec.needActionEventUpdate then
      spec.needActionEventUpdate = nil
      self:requestActionEventUpdate()
    end
end

function FollowMe:startFollowMe(connection, startedFarmId)
    if nil == g_server then
        -- Client - Send command to server
        g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_START, nil, startedFarmId))
    else
        -- Server only
        if FollowMe.getIsFollowMeActive(self) or self:getIsAIActive() then
            FollowMe.showReason(self, FollowMe.REASON_ALREADY_AI, connection)
        elseif not self.spec_motorized.isMotorStarted then
            FollowMe.showReason(self, FollowMe.REASON_ENGINE_STOPPED, connection)
        else
            local closestVehicle = FollowMe.findVehicleInFront(self)
            if nil == closestVehicle then
                FollowMe.showReason(self, FollowMe.REASON_NO_TRAIL_FOUND, connection)
            else
                FollowMe.showReason(self, FollowMe.REASON_CLEAR_WARNING, connection)
                self:raiseDirtyFlags(self.spec_followMe.dirtyFlag)
                self:startAIVehicle(nil, nil, startedFarmId, "FollowMe")
            end
        end
    end
end

function FollowMe:stopFollowMe(connection, reason)
    if nil == g_server then
        -- Client - Send command to server
        g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_STOP, reason, nil))
    else
        -- Server only
        local spec = self.spec_followMe
        if nil ~= spec.FollowVehicleObj then
          spec.FollowVehicleObj:raiseDirtyFlags(spec.FollowVehicleObj.spec_followMe.dirtyFlag)
        end

        self:raiseDirtyFlags(spec.dirtyFlag)
        self:stopAIVehicle(AIVehicle.STOP_REASON_USER)
    end
end

function FollowMe:waitResumeFollowMe(connection, reason)
    if nil == g_server then
        -- Client
        g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_WAITRESUME, reason, nil))
    else
        -- Server only
        FollowMe.onWaitResumeFollowMe(self, reason)
    end
end

--
--

AIDriveStrategyFollow = {}
local AIDriveStrategyFollow_mt = Class(AIDriveStrategyFollow, AIDriveStrategy)

function AIDriveStrategyFollow:new(customMt)
    return AIDriveStrategy:new( Utils.getNoNil(customMt, AIDriveStrategyFollow_mt) )
end

function AIDriveStrategyFollow:delete()
    local vehicle = self.vehicle
    local vehicleSpec = vehicle.spec_followMe

    local leader = vehicleSpec.FollowVehicleObj
    if leader then
      local leaderSpec = leader.spec_followMe
      leaderSpec.StalkerVehicleObj = nil
    end
    vehicleSpec.FollowVehicleObj = nil
    vehicleSpec.FollowState = FollowMe.STATE_NONE

    vehicle.spec_aiVehicle.mod_CheckSpeedLimitOnlyIfWorking = nil

    AIDriveStrategyFollow:superClass().delete(self)
end

function AIDriveStrategyFollow:setAIVehicle(vehicle)
    AIDriveStrategyFollow:superClass().setAIVehicle(self, vehicle)

    local vehicleSpec = vehicle.spec_followMe

    local closestVehicle,startIndex = FollowMe.findVehicleInFront(vehicle)
    if nil ~= closestVehicle then
      local closestVehicleSpec = closestVehicle.spec_followMe

      closestVehicleSpec.StalkerVehicleObj = vehicle
      closestVehicle:raiseDirtyFlags(closestVehicleSpec.dirtyFlag)

      vehicleSpec.FollowVehicleObj = closestVehicle
      vehicleSpec.FollowCurrentIndex = startIndex
      vehicleSpec.FollowState = FollowMe.STATE_FOLLOWING

      vehicle.spec_aiVehicle.mod_CheckSpeedLimitOnlyIfWorking = true  -- A work-around, for forcing AIVehicle:onUpdateTick() making its call to `self:getSpeedLimit()` into a `self:getSpeedLimit(true)`

      if  nil ~= vehicle.spec_lights
      and nil ~= closestVehicle.spec_lights then
        vehicle:setLightsTypesMask(       closestVehicle:getLightsTypesMask())
        vehicle:setBeaconLightsVisibility(closestVehicle:getBeaconLightsVisibility())
      end
    else
      vehicleSpec.FollowVehicleObj = nil
    end

    vehicle:raiseDirtyFlags(vehicleSpec.dirtyFlag)
end

function AIDriveStrategyFollow:update(dt)
    --log("AIDriveStrategyFollow:update ",dt)
end


function AIDriveStrategyFollow:checkBaler(attachedTool)
  if attachedTool:getIsTurnedOn() then
    local spec = attachedTool.spec_baler
    if spec.unloadingState <= Baler.UNLOADING_CLOSED then
      if table.getn(spec.bales) > 0 then
--        attachedTool:setIsUnloadingBale(true)
        return false, 1
      elseif attachedTool:getFillUnitFillLevel(spec.fillUnitIndex) > (attachedTool:getFillUnitCapacity(spec.fillUnitIndex) * 0.95) then
        return true, 0.25
      end
    else
      if spec.unloadingState == Baler.UNLOADING_OPEN then
--        attachedTool:setIsUnloadingBale(false)
      end
      return false, 1
    end
  end

  return true, 1
end

-- WTF?! Still, in FS19, the same typo-error bug in base-game's script.
-- Try to (again) anticipate future "correct spelling".
local STATE_WRAPPER_FINISHED = Utils.getNoNil(BaleWrapper.STATE_WRAPPER_FINSIHED, BaleWrapper.STATE_WRAPPER_FINISHED)

function AIDriveStrategyFollow:checkBaleWrapper(attachedTool)
  local spec = attachedTool.spec_baleWrapper

  if STATE_WRAPPER_FINISHED == spec.baleWrapperState then
    attachedTool:doStateChange(BaleWrapper.CHANGE_BUTTON_EMPTY)
  end

  return STATE_WRAPPER_FINISHED > spec.baleWrapperState, 1
end

function AIDriveStrategyFollow:checkBalerAndWrapper(attachedTool)
  local allowedToDrive, speedFactor1 = AIDriveStrategyFollow.checkBaleWrapper(self, attachedTool)
  local speedFactor2 = speedFactor1
  if allowedToDrive then
    allowedToDrive, speedFactor2 = AIDriveStrategyFollow.checkBaler(self, attachedTool)
  end
  return allowedToDrive, math.min(speedFactor1, speedFactor2)
end

function AIDriveStrategyFollow:canDriveWithAttachedTool()
    -- Locate supported equipment
    if nil ~= self.vehicle.getAttachedImplements then
      -- Attempt at automatically unloading of round-bales
      local attachedTool = nil
      for _,tool in pairs(self.vehicle:getAttachedImplements()) do
          if nil ~= tool.object then
              local spec = tool.object.spec_baler
              if nil ~= spec and nil ~= spec.baleUnloadAnimationName then
                  if nil ~= tool.object.spec_baleWrapper then
                      attachedTool = { tool.object, AIDriveStrategyFollow.checkBalerAndWrapper }
                      break
                  end

                  attachedTool = { tool.object, AIDriveStrategyFollow.checkBaler }
                  break
              end

              if nil ~= tool.object.spec_baleWrapper then
                  attachedTool = { tool.object, AIDriveStrategyFollow.checkBaleWrapper }
                  break
              end
          end
      end

      if nil ~= attachedTool then
        local tool = attachedTool[1]
        local func = attachedTool[2]
        return func(self, tool)
      end
    end

    return true, 1
end


function AIDriveStrategyFollow:getDriveData(dt, vX, vY, vZ)
    --log("AIDriveStrategyFollow:getDriveData ",dt," ",vX," ",vY," ",vZ)

    local vehicle = self.vehicle
    local vehicleSpec = vehicle.spec_followMe
    local leader = vehicleSpec.FollowVehicleObj

    if nil == vehicleSpec.FollowVehicleObj or nil == leader then
      vehicle:stopAIVehicle(AIVehicle.STOP_REASON_FOLLOWME_LEADER_VANISHED)
      return nil,nil,nil,nil,nil
    end

    local leaderSpec = leader.spec_followMe
    -- actual target
    local tX,tY,tZ
    --
    local isAllowedToDrive  = (FollowMe.STATE_WAITING ~= vehicleSpec.FollowState)
    local distanceToStop    = -(FollowMe.getKeepBack(vehicle))
    local keepInFrontMeters = FollowMe.getKeepFront(vehicle)
    local maxSpeed = 0
    local steepTurnAngle = false
    --
    local crumbIndexDiff = leaderSpec.DropperCurrentIndex - vehicleSpec.FollowCurrentIndex
    --
    if crumbIndexDiff >= FollowMe.cBreadcrumbsMaxEntries then
        -- circular-array have "circled" once, and this follower did not move fast enough.
        if vehicleSpec.FollowState ~= FollowMe.STATE_STOPPING then
            vehicle:stopAIVehicle(AIVehicle.STOP_REASON_FOLLOWME_TRAIL_LOST)
            return nil,nil,nil,nil,nil
        end

        isAllowedToDrive = false

        -- vehicle rotation
        local vRX,vRY,vRZ   = localDirectionToWorld(vehicle:getAIVehicleSteeringNode(), 0,0,FollowMe.getReverserDirection(vehicle))

        -- Set target 2 meters straight ahead of vehicle.
        tX = vX + vRX * 2
        tY = vY
        tZ = vZ + vRZ * 2
    elseif crumbIndexDiff > 0 then
        -- Following crumbs...
        local crumbT = leaderSpec.DropperCircularArray[1+(vehicleSpec.FollowCurrentIndex % FollowMe.cBreadcrumbsMaxEntries)]
        maxSpeed = math.max(5, crumbT.maxSpeed)
        --
        local ox,oy,oz = crumbT.trans[1],crumbT.trans[2],crumbT.trans[3]
        local orx,ory,orz = unpack(crumbT.rot)
        -- Apply offset
        tX = ox - orz * vehicleSpec.offsetLR
        tY = oy
        tZ = oz + orx * vehicleSpec.offsetLR
        --
        local dx,dz = tX - vX, tZ - vZ
        local tDist = MathUtil.vector2Length(dx,dz)
        --
        local trAngle = math.atan2(orx,orz)
        local nz = dx * math.sin(trAngle) + dz * math.cos(trAngle)
        steepTurnAngle = (tDist < 15 and (nz / tDist) < 0.8)
        --
        local nextCrumbOffset = 1
        if (tDist < (FollowMe.cMinDistanceBetweenDrops / 2)) -- close enough to crumb?
        or (nz < 0) -- already in front of crumb?
        then
            FollowMe.copyDrop(vehicle, crumbT, (vehicleSpec.offsetLR == 0) and nil or {tX,tY,tZ})
            -- Go to next crumb
            vehicleSpec.FollowCurrentIndex = vehicleSpec.FollowCurrentIndex + 1
            nextCrumbOffset = 0
            crumbIndexDiff = leaderSpec.DropperCurrentIndex - vehicleSpec.FollowCurrentIndex
        end
        --
        if crumbIndexDiff > 0 then
            -- Still following crumbs...
            local crumbN = leaderSpec.DropperCircularArray[1+((vehicleSpec.FollowCurrentIndex + nextCrumbOffset) % FollowMe.cBreadcrumbsMaxEntries)]
            if nil ~= crumbN then
                -- Apply offset, to next original target
                local ntX = crumbN.trans[1] - crumbN.rot[3] * vehicleSpec.offsetLR
                local ntZ = crumbN.trans[3] + crumbN.rot[1] * vehicleSpec.offsetLR
                local pct = math.max(1 - (tDist / FollowMe.cMinDistanceBetweenDrops), 0)
                tX,_,tZ = MathUtil.vector3ArrayLerp( {tX,0,tZ}, {ntX,0,ntZ}, pct)
                maxSpeed = math.max(5, (maxSpeed + crumbN.maxSpeed) / 2)
            end
        end
        --
        distanceToStop = distanceToStop + (crumbIndexDiff * FollowMe.cMinDistanceBetweenDrops)
        if 0 == keepInFrontMeters then
          isAllowedToDrive = isAllowedToDrive and (distanceToStop > 1)
        end
    end
    --
    if crumbIndexDiff <= 0 then
        -- Following leader directly...
        local lNode         = leader:getAIVehicleSteeringNode()
        local lx,ly,lz      = getWorldTranslation(lNode)
        local lrx,lry,lrz   = localDirectionToWorld(lNode, 0,0,FollowMe.getReverserDirection(leader))

        maxSpeed = math.max(1, leader.lastSpeed * 3600) -- only consider forward movement.

        -- leader-target adjust with offset
        tX = lx - lrz * vehicleSpec.offsetLR + lrx * keepInFrontMeters
        tY = ly
        tZ = lz + lrx * vehicleSpec.offsetLR + lrz * keepInFrontMeters

        -- Rotate to see if the target is still "in front of us"
        local dx,dz = tX - vX, tZ - vZ
        local trAngle = math.atan2(lrx,lrz)
        local nz = dx * math.sin(trAngle) + dz * math.cos(trAngle)

        distanceToStop = distanceToStop + MathUtil.vector2Length(dx,dz)
        isAllowedToDrive = isAllowedToDrive and (nz > 0) and (distanceToStop > 1)
    else
      distanceToStop = distanceToStop + keepInFrontMeters
    end

    if isAllowedToDrive then
      local speedFactor
      isAllowedToDrive, speedFactor = self:canDriveWithAttachedTool()
      maxSpeed = maxSpeed * Utils.getNoNil(speedFactor, 1)
    end

    if isAllowedToDrive then
      if steepTurnAngle then
        maxSpeed = math.min(10, maxSpeed)
      else
        local curSpeed = math.max(1, (vehicle.lastSpeed * 3600))
        maxSpeed = maxSpeed * (1 + math.min(1, (distanceToStop / curSpeed)))
      end
    end

    if (not isAllowedToDrive) or (maxSpeed < 0.1) then
      maxSpeed = 0
    end

    -- distanceToStop = math.floor(distanceToStop)
    -- if self.lastDistToStop ~= distanceToStop then
    --   log("maxSpeed:",maxSpeed," distToStop:",distanceToStop)
    --   self.lastDistToStop = distanceToStop
    -- end

    distanceToStop = math.max(0, distanceToStop)

    local moveForwards = true
    return tX, tZ, moveForwards, maxSpeed, distanceToStop
end

--

---------
AIDriveStrategyCollisionFollow = {}

AIDriveStrategyCollisionFollow_mt = Class(AIDriveStrategyCollisionFollow, AIDriveStrategyCollision)

function AIDriveStrategyCollisionFollow:new(customMt)
  if customMt == nil then
      customMt = AIDriveStrategyCollisionFollow_mt
  end
  local self = AIDriveStrategyCollision:new(customMt)
  self.timeoutCollisionNotification = FollowMe.cCollisionNotificationDelayMS
  self.isCollidingWithFollowMeLeader = false
  return self
end

function AIDriveStrategyCollisionFollow:getDriveData(dt, vX,vY,vZ)
  local spec = self.vehicle.spec_followMe

  if not spec.collisionSensorIgnored then
      for _, count in pairs(self.numCollidingVehicles) do
          if count > 0 then
              local tX,_,tZ = localToWorld(self.vehicle:getAIVehicleDirectionNode(), 0,0,1)
              self.vehicle:addAIDebugText(" AIDriveStrategyCollisionFollow :: STOP due to collision ")
              if not self.isCollidingWithFollowMeLeader then
                self.timeoutCollisionNotification = self.timeoutCollisionNotification - dt
                if self.timeoutCollisionNotification < 0 then
                  self:setHasCollision(true)
                  if spec.FollowState == FollowMe.STATE_FOLLOWING then
                    spec.FollowState = FollowMe.STATE_COLLIDING
                    self.vehicle:raiseDirtyFlags(spec.dirtyFlag)
                  end
                end
              end
              return tX, tZ, true, 0, math.huge
          end
      end
  end

  self.timeoutCollisionNotification = FollowMe.cCollisionNotificationDelayMS
  self:setHasCollision(false)
  if spec.FollowState == FollowMe.STATE_COLLIDING then
    spec.FollowState = FollowMe.STATE_FOLLOWING
    self.vehicle:raiseDirtyFlags(spec.dirtyFlag)
  end
  self.vehicle:addAIDebugText(" AIDriveStrategyCollisionFollow :: no collision ")
  return nil, nil, nil, nil, nil
end

function AIDriveStrategyCollisionFollow:onTrafficCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
  if onEnter or onLeave then

    -- local otherMask = getCollisionMask(otherId)
    -- local otherName = getName(otherId)
    -- local txt = "onEnter"
    -- if onLeave then txt = "onLeave" end
    -- log("onTrafficCollisionTrigger:",otherName," ",otherMask," ",txt)

      if g_currentMission.players[otherId] ~= nil then
          if onEnter then
              self.numCollidingVehicles[triggerId] = self.numCollidingVehicles[triggerId]+1
          elseif onLeave then
              self.numCollidingVehicles[triggerId] = math.max(self.numCollidingVehicles[triggerId]-1, 0)
          end
      else
          local vehicle = g_currentMission.nodeToObject[otherId]
          if  vehicle ~= nil
          and vehicle.getRootVehicle ~= nil
          then
              local rootVehicle = vehicle:getRootVehicle()
              if self.collisionTriggerByVehicle[vehicle] == nil and self.collisionTriggerByVehicle[rootVehicle] == nil then
                  local leader = self.vehicle.spec_followMe.FollowVehicleObj
                  if onEnter then
                      if leader == rootVehicle then
                          self.isCollidingWithFollowMeLeader = true
                      end
                      self.numCollidingVehicles[triggerId] = self.numCollidingVehicles[triggerId]+1
                  elseif onLeave then
                      if leader == rootVehicle then
                          self.isCollidingWithFollowMeLeader = false
                      end
                      self.numCollidingVehicles[triggerId] = math.max(self.numCollidingVehicles[triggerId]-1, 0)
                  end
              end
          else
              local otherMask = getCollisionMask(otherId)
              local otherName = getName(otherId)
              -- CollisionMask bits - from year 2011: https://gdn.giants-software.com/thread.php?categoryId=16&threadId=677
              -- 13 = dynamic_objects_machines
              -- 20 = trigger_player (and trafficBlocker/railroad-crossing-barrier, and beltActivationTrigger, and ...?)
              -- 21 = trigger_tractors
              -- 25 = trigger_trafficVehicles (NPCs own detection traffic-collision-box)
              if  bitAND(otherMask, 2^13 + 2^20 + 2^21) ~= 0
              and bitAND(otherMask, 2^25) == 0 -- Ignore NPCs traffic-collision-boxes
              and not string.match(otherName,'[Tt]rigger') -- OMG! 'trafficBlocker' and 'beltActivationTrigger' uses same collision-value (1048576), so this "hack" is to ignore all nodes with "Trigger" in their name
              then
                  if onEnter then
                      self.numCollidingVehicles[triggerId] = self.numCollidingVehicles[triggerId]+1
                  elseif onLeave then
                      self.numCollidingVehicles[triggerId] = math.max(self.numCollidingVehicles[triggerId]-1, 0)
                  end
              end
        end
      end
  end
end

--
--

function FollowMe:updateAIDriveStrategies()
    -- Copied from `AIVehicle:updateAIDriveStrategies()`
    local spec = self.spec_aiVehicle
    if spec.driveStrategies ~= nil and #spec.driveStrategies > 0 then
        for i=#spec.driveStrategies,1,-1 do
            spec.driveStrategies[i]:delete()
            table.remove(spec.driveStrategies, i)
        end
        spec.driveStrategies = {}
    end

    -- Custom for 'Follow Me'
    local driveStrategyCollision = AIDriveStrategyCollisionFollow:new()
    driveStrategyCollision:setAIVehicle(self)
    table.insert(spec.driveStrategies, driveStrategyCollision)

    local driveStrategyFollow = AIDriveStrategyFollow:new()
    driveStrategyFollow:setAIVehicle(self)
    table.insert(spec.driveStrategies, driveStrategyFollow)
end

--
--

function FollowMe:onWaitResumeFollowMe(reason, noEventSend)
    local spec = self.spec_followMe

    local newState = spec.FollowState

    if spec.FollowState == FollowMe.STATE_FOLLOWING
    or spec.FollowState == FollowMe.STATE_COLLIDING
    then
      newState = FollowMe.STATE_WAITING
    elseif spec.FollowState == FollowMe.STATE_WAITING then
      newState = FollowMe.STATE_FOLLOWING
    end

    if newState ~= spec.FollowState then
      spec.FollowState = newState

      self:raiseDirtyFlags(spec.dirtyFlag)
      self:requestActionEventUpdate()

      if nil ~= spec.FollowVehicleObj then
        spec.FollowVehicleObj:raiseDirtyFlags(spec.FollowVehicleObj.spec_followMe.dirtyFlag)
        spec.FollowVehicleObj:requestActionEventUpdate()
      end
    end
end

function FollowMe:showReason(reason, connection)
    if nil ~= connection then
        connection:sendEvent(FollowMeReasonEvent:new(self, reason), nil, nil, self)
    else
        if reason == FollowMe.REASON_NONE then
            -- No notification needed
        elseif reason == FollowMe.REASON_ALREADY_AI then
            FollowMe.setWarning(self, "FollowMeAlreadyAI")
        elseif reason == FollowMe.REASON_NO_TRAIL_FOUND then
            FollowMe.setWarning(self, "FollowMeDropperNotFound")
        elseif reason == FollowMe.REASON_ENGINE_STOPPED then
            FollowMe.setWarning(self, "FollowMeStartEngine")
        elseif reason == FollowMe.REASON_CLEAR_WARNING then
            FollowMe.setWarning(self, nil)
        --elseif nil ~= reason then
        --    local txtId = ("FollowMeReason%d"):format(reason)
        --    if g_i18n:hasText(txtId) then
        --        local helperName = "?"
        --        if nil ~= currentHelper then
        --            helperName = Utils.getNoNil(currentHelper.name, helperName)
        --        end
        --        local reasonTxt = g_i18n:getText(txtId):format(helperName)
        --        local reasonClr = {0.5, 0.5, 1.0, 1.0}
        --        if reason == FollowMe.REASON_TOO_FAR_BEHIND then
        --            reasonClr = FSBaseMission.INGAME_NOTIFICATION_CRITICAL
        --        end
        --        g_currentMission:addIngameNotification(reasonClr, reasonTxt)
        --    end
        end
    end
end

function FollowMe:setWarning(txt, noSendEvent)
    local spec = self.spec_followMe

    if nil == txt then
        spec.ShowWarningText = ""
        spec.ShowWarningTime = 0
    else
        spec.ShowWarningText = g_i18n:getText(txt)
        spec.ShowWarningTime = g_currentMission.time + 2500
    end
end


function FollowMe:findVehicleInFront()
    if not self.isServer then
        return nil
    end
    -- Anything below is only server-side

    local node      = self:getAIVehicleSteeringNode()
    local wx,wy,wz  = getWorldTranslation(node)
    local rx,ry,rz  = localDirectionToWorld(node, 0,0,FollowMe.getReverserDirection(self))
    local rlength   = MathUtil.vector2Length(rx,rz)
    local rotDeg    = math.deg(math.atan2(rx/rlength,rz/rlength))
    local rotRad    = MathUtil.degToRad(rotDeg-45.0)
    --log(string.format("getWorldTranslation:%f/%f/%f - localDirectionToWorld:%f/%f/%f - rDeg:%f - rRad:%f", wx,wy,wz, rx,ry,rz, rotDeg, rotRad))

    --log("Myself ",self:getName()," Rxyz(",vec2str(rx,ry,rz),") Wxyz(",vec2str(wx,wy,wz),")")

    -- Find closest vehicle, that is in front of self.
    local closestDistance = 50*50 -- due to using Utils.vector2LengthSq()
    local closestVehicle = nil
    for _,vehicleObj in pairs(g_currentMission.vehicles) do
        local vehicleSpec = vehicleObj.spec_followMe
        if SpecializationUtil.hasSpecialization(Drivable, vehicleObj.specializations)
        and nil ~= vehicleSpec -- Make sure its a vehicle that has the FollowMe specialization added.
        and nil ~= vehicleSpec.DropperCircularArray -- Make sure other vehicle has circular array
        and nil == vehicleSpec.StalkerVehicleObj -- and is not already stalked by something.
        then
            --local vehicleNode = FollowMe.getFollowNode(vehicleObj)
            local vehicleNode = vehicleObj:getAIVehicleSteeringNode()
            -- Make sure that the other vehicle is actually driving "away from us"
            -- I.e. in the same direction
            local vrx, vry, vrz = localDirectionToWorld(vehicleNode, 0,0,FollowMe.getReverserDirection(vehicleObj))
            if MathUtil.dotProduct(rx,0,rz, vrx,0,vrz) > 0.2 then
                local vx,vy,vz = getWorldTranslation(vehicleNode)
                local dx,dz = vx-wx, vz-wz
                local dist = MathUtil.vector2LengthSq(dx,dz)
                if (dist < closestDistance) then
                    -- Rotate to see if vehicleObj is "in front of us"
                    local nx = dx * math.cos(rotRad) - dz * math.sin(rotRad)
                    local nz = dx * math.sin(rotRad) + dz * math.cos(rotRad)
                    if (nx > 0) and (nz > 0) then
                        closestDistance = dist
                        closestVehicle = vehicleObj

--log("closest(",dist,") ",closestVehicle:getName()," Rxyz(",vec2str(vrx,vry,vrz),") Wxyz(",vec2str(vx,vy,vz),")")
                    end
                end
            end
        end
    end

    local followCurrentIndex = -1
    if nil ~= closestVehicle then
        --log("FollowMe:findVehicleInFront() candidate=",closestVehicle:getName())
        -- Find closest "breadcrumb"
        local closestDistance = 50*50 -- due to using Utils.vector2LengthSq()
        local closestSpec = closestVehicle.spec_followMe
        for i=closestSpec.DropperCurrentIndex, math.max(closestSpec.DropperCurrentIndex - FollowMe.cBreadcrumbsMaxEntries,0), -1 do
            local crumb = closestSpec.DropperCircularArray[1+(i % FollowMe.cBreadcrumbsMaxEntries)]
            if nil ~= crumb then
                local x,y,z = unpack(crumb.trans)
                -- Translate
                local dx,dz = x-wx, z-wz
                local dist = MathUtil.vector2LengthSq(dx,dz)
                --local r = Utils.getYRotationFromDirection(dx,dz)
                --log(string.format("#%d - xz:%f/%f - dxdz:%f/%f - r:%f - dist:%f", i, x,z, dx,dz, r, dist))
                if (dist > 2) and (dist < closestDistance) then
                    -- Rotate to see if the point is "in front of us"
                    local nx = dx * math.cos(rotRad) - dz * math.sin(rotRad)
                    local nz = dx * math.sin(rotRad) + dz * math.cos(rotRad)
                    if (nx > 0) and (nz > 0) then
--log(string.format("#%d - xz:%f/%f - dxdz:%f/%f - dist:%f - nxnz:%f/%f", i, x,z, dx,dz, dist, nx,nz))
                        closestDistance = dist
                        followCurrentIndex = i
                    end
                end
                --
                if -1 ~= followCurrentIndex and dist > closestDistance then
                    -- If crumb is "going further away" from already found one, then stop searching.
                    break
                end
            end
        end
        --log(string.format("ClosestDist:%f, index:%d", closestDistance, followCurrentIndex))
        --
        if -1 == followCurrentIndex then
          closestVehicle = nil
        end
    end

    --log("FollowMe:findVehicleInFront() actual=",(nil ~= closestVehicle) and closestVehicle:getFullName() or "(nil)")
    return closestVehicle, followCurrentIndex
end

-- Get distance to keep-in-front, or zero if not.
function FollowMe:getKeepFront()
    local spec = self.spec_followMe
    if (spec.distanceFB >= 0) then
        return 0
    end
    return math.abs(spec.distanceFB)
end

-- Get distance to keep-back, or zero if not.
function FollowMe:getKeepBack(speedKMH)
  return MathUtil.clamp(self.spec_followMe.distanceFB, 0, 999)
end

--
--

function FollowMe.getWorldToScreen(nodeId)
    if nil ~= nodeId then
        local tX,tY,tZ = getWorldTranslation(nodeId)
        if nil ~= tX then
            --tY = tY + self.displayYoffset
            local sx,sy,sz = project(tX,tY,tZ)
            if  sx < 1 and sx > 0  -- When "inside" screen
            and sy < 1 and sy > 0  -- When "inside" screen
            and            sz < 1  -- Only draw when "in front of" camera
            then
                return sx,sy
            end
        end
    end
    return nil,nil
end

function FollowMe.renderShadedTextCenter(sx,sy, txt, alpha)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(0,0,0,alpha)
    renderText(sx+0.001, sy-0.001, 0.015, txt)
    setTextColor(1,1,1,alpha)
    renderText(sx, sy, 0.015, txt)
end

function FollowMe:onDraw(isActiveForInput, isSelected)
    local spec = self.spec_followMe
    if nil == spec then
        return
    end
    if spec.ShowWarningTime > g_currentMission.time then
        g_currentMission:showBlinkingWarning(spec.ShowWarningText)
    end

    -- Enhancement due to issue #34
    local textOpaqueness = 1 - (math.max(0, g_time - spec.textFadeoutBegin) / 1000)
    if textOpaqueness <= 0 then
      return
    end

    --
    local showFollowMeMy = true
    local showFollowMeFl = true
    --
    if nil ~= spec.FollowVehicleObj then
        if showFollowMeMy then
            local sx,sy = FollowMe.getWorldToScreen(spec.FollowVehicleObj.rootNode)
            if nil ~= sx then
                local txt = g_i18n:getText("FollowMeLeader")
                local dist = spec.distanceFB
                if 0 ~= dist then
                    txt = txt .. "\n" .. (g_i18n:getText((dist > 0) and "FollowMeDistAhead" or "FollowMeDistBehind")):format(math.abs(dist))
                end
                local offs = spec.offsetLR
                if 0 ~= offs then
                    txt = txt .. "\n" .. (g_i18n:getText((offs > 0) and "FollowMeOffLft" or "FollowMeOffRgt")):format(math.abs(offs))
                --elseif 0 ~= spec.prevOffsetLR then
                --    txt = txt .. "\n(offset toggle)"
                end
                FollowMe.renderShadedTextCenter(sx,sy, txt, textOpaqueness)
            end

            local txt = nil
            if spec.FollowState == FollowMe.STATE_COLLIDING then
              txt = Utils.getNoNil(txt, {})
              table.insert(txt, g_i18n:getText("FollowMeColliding"))
            elseif spec.FollowState == FollowMe.STATE_WAITING then
              txt = Utils.getNoNil(txt, {})
              table.insert(txt, g_i18n:getText("FollowMePaused"))
            end
            if spec.collisionSensorIgnored then
              txt = Utils.getNoNil(txt, {})
              table.insert(txt, g_i18n:getText("FollowMeSensorIgnored"))
            end
            if nil ~= txt then
              local sx,sy = FollowMe.getWorldToScreen(self.rootNode)
              if nil ~= sx then
                txt = table.concat(txt, "\n")
                FollowMe.renderShadedTextCenter(sx,sy, txt, textOpaqueness)
              end
            end
        end
    end
    --
    if nil ~= spec.StalkerVehicleObj then
        local stalkerSpec = spec.StalkerVehicleObj.spec_followMe
        local txt = nil
        if showFollowMeFl then
            txt = g_i18n:getText("FollowMeFollower")
            -- if nil ~= stalkerSpec.currentHelper then
            --     txt = txt .. (" '%s'"):format(stalkerSpec.currentHelper.name)
            -- end
            if stalkerSpec.FollowState == FollowMe.STATE_COLLIDING then
                txt = txt .. " " .. g_i18n:getText("FollowMeColliding")
            elseif stalkerSpec.FollowState == FollowMe.STATE_WAITING then
                txt = txt .. " " .. g_i18n:getText("FollowMePaused")
            end
            if stalkerSpec.collisionSensorIgnored then
                txt = txt .. "\n" .. g_i18n:getText("FollowMeSensorIgnored")
            end
            local dist = stalkerSpec.distanceFB
            if 0 ~= dist then
                txt = txt .. "\n" .. (g_i18n:getText((dist > 0) and "FollowMeDistBehind" or "FollowMeDistAhead")):format(math.abs(dist))
            end
            local offs = stalkerSpec.offsetLR
            if 0 ~= offs then
                txt = txt .. "\n" .. (g_i18n:getText((offs > 0) and "FollowMeOffRgt" or "FollowMeOffLft")):format(math.abs(offs))
            --elseif 0 ~= stalkerSpec.prevOffsetLR then
            --    txt = txt .. "\n(offset toggle)"
            end
        end
        if nil ~= stalkerSpec.trailStrength then
            if nil == txt then
                txt = ""
            else
                txt = txt .. "\n"
            end
            txt = txt .. g_i18n:getText("FollowMeTrailStrength"):format(stalkerSpec.trailStrength)
        end
        if nil ~= txt then
            local sx,sy = FollowMe.getWorldToScreen(spec.StalkerVehicleObj.rootNode)
            if nil ~= sx then
                FollowMe.renderShadedTextCenter(sx,sy, txt, textOpaqueness)
            end
        end
    end
    --
--    if g_gameSettings:getValue("showHelpMenu") then
        -- if nil ~= spec.FollowVehicleObj
        -- or (showFollowMeMy and g_currentMission:getHasPlayerPermission("hireAI"))
        -- then
        --     g_currentMission:addHelpButtonText(g_i18n:getText("FollowMeMyToggle"), InputBinding.FollowMeMyToggle, nil, GS_PRIO_HIGH)
        -- end
        --
        -- if nil ~= spec.FollowVehicleObj then
        --     g_currentMission:addExtraPrintText(string.format(g_i18n:getText("FollowMeKeysMyself"),FollowMe.keys_FollowMeMy), nil, GS_PRIO_NORMAL)
        -- end
        -- --
        -- if nil ~= spec.StalkerVehicleObj then
        --     g_currentMission:addExtraPrintText(string.format(g_i18n:getText("FollowMeKeysBehind"),FollowMe.keys_FollowMeFl), nil, GS_PRIO_NORMAL)
        -- end
--[[DEBUG
    else
        --if nil ~= spec.FollowVehicleObj then
            local yPos = 0.9
            setTextColor(1,1,1,1)
            setTextBold(true)
            local keys = {}
            for k,_ in pairs(FollowMe.debugDraw) do
                table.insert(keys,k)
            end
            table.sort(keys)
            for _,k in pairs(keys) do
                local v = FollowMe.debugDraw[k]
                yPos = yPos - 0.02
                renderText(0.01, yPos, 0.02, v[1])
                renderText(0.11, yPos, 0.02, v[2])
            end
            setTextBold(false)
        --end
--DEBUG]]
--    end

--[[DEBUG
    if Vehicle.debugRendering and self.isServer then
        --FollowMe.drawDebug(self)

        local keys = {}
        for k,_ in pairs(FollowMe.debugDraw) do
            table.insert(keys,k)
        end
        table.sort(keys)
        local txt = ""
        for _,k in pairs(keys) do
            txt = txt .. FollowMe.debugDraw[k][1] .." ".. FollowMe.debugDraw[k][2] .. "\n"
        end

        setTextBold(false)
        setTextColor(0.85, 0.85, 1, 1)
        setTextAlignment(RenderText.ALIGN_LEFT)
        renderText(0.005, 0.5, 0.02, txt)

        if FollowMe.dbgTarget then
            -- Draw a "dot" as the target for the follower
            local x,y,z = project(FollowMe.dbgTarget[1],FollowMe.dbgTarget[2],FollowMe.dbgTarget[3])
            if  x<1 and x>0
            and y<1 and y>0
            --and z<1 and z>0
            then
                if (g_currentMission.time % 500) < 250 then
                    setTextColor(1,1,1,1)
                else
                    setTextColor(0.5,0.5,1,1)
                end
                setTextAlignment(RenderText.ALIGN_CENTER)
                renderText(x,y, 0.04, ".") -- Not exactly at the pixel-point, but close enough for debugging.
                setTextAlignment(RenderText.ALIGN_LEFT)
            end
        end
    end
--DEBUG]]

    -- if FollowMe.showFollowMeFl then
    --     local x,y,z = unpack(FollowMe.cursorXYZ)
    --     drawDebugLine(x,y,z, 1,1,0, x,y+2,z, 1,1,0, true)
    -- end

    -- if self.isServer then
    --     if showFollowMeMy and nil ~= spec.FollowVehicleObj then
    --         FollowMe.debugDrawTrail(self)
    --     elseif showFollowMeFl and nil ~= spec.StalkerVehicleObj then
    --         FollowMe.debugDrawTrail(spec.StalkerVehicleObj)
    --     end
    -- end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(1,1,1,1)
end

function FollowMe:debugDrawTrail()
    local spec = self.spec_followMe

    local leader = spec.FollowVehicleObj
    local leaderSpec = leader.spec_followMe

    local wpIdx = spec.FollowCurrentIndex
    local crumb1 = leaderSpec.DropperCircularArray[1+(wpIdx % FollowMe.cBreadcrumbsMaxEntries)]
    local crumb2
    while wpIdx < leaderSpec.DropperCurrentIndex do
        wpIdx = wpIdx + 1
        crumb2 = leaderSpec.DropperCircularArray[1+(wpIdx % FollowMe.cBreadcrumbsMaxEntries)]

        local x1,y1,z1 = unpack(crumb1.trans)
        local x2,y2,z2 = unpack(crumb2.trans)
        drawDebugLine(x1,y1+1,z1, 1,1,1, x2,y2+1,z2, 0,0,1, false)

        crumb1 = crumb2
    end
end

---
---
---

FollowMeRequestEvent = {}
FollowMeRequestEvent_mt = Class(FollowMeRequestEvent, Event)

InitEventClass(FollowMeRequestEvent, "FollowMeRequestEvent")

function FollowMeRequestEvent:emptyNew()
    local self = Event:new(FollowMeRequestEvent_mt)
    self.className = "FollowMeRequestEvent"
    return self
end

function FollowMeRequestEvent:new(vehicle, cmdId, reason, farmId)
  --log("FollowMeRequestEvent:new")
    local self = FollowMeRequestEvent:emptyNew()
    self.vehicle    = vehicle
    self.farmId     = Utils.getNoNil(farmId, 0)
    self.cmdId      = Utils.getNoNil(cmdId, 0)
    self.reason     = Utils.getNoNil(reason, 0)
    self.sensor     = Utils.getNoNil(vehicle.spec_followMe.collisionSensorIgnored, false)
    self.distance   = Utils.getNoNil(vehicle.spec_followMe.distanceFB, 0)
    self.offset     = Utils.getNoNil(vehicle.spec_followMe.offsetLR, 0)
    return self
end

function FollowMeRequestEvent:writeStream(streamId, connection)
  --log("FollowMeRequestEvent:writeStream")
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(      streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
    streamWriteUIntN(      streamId, self.cmdId,  FollowMe.NUM_BITS_COMMAND)
    streamWriteUIntN(      streamId, self.reason, FollowMe.NUM_BITS_REASON)
    streamWriteBool(       streamId, self.sensor)
    streamWriteInt8(       streamId, self.distance)
    streamWriteInt8(       streamId, self.offset * 2)
end

function FollowMeRequestEvent:readStream(streamId, connection)
  --log("FollowMeRequestEvent:readStream")
    self.vehicle  = NetworkUtil.readNodeObject(streamId)
    self.farmId   = streamReadUIntN(           streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
    self.cmdId    = streamReadUIntN(           streamId, FollowMe.NUM_BITS_COMMAND)
    self.reason   = streamReadUIntN(           streamId, FollowMe.NUM_BITS_REASON)
    self.sensor   = streamReadBool(            streamId)
    self.distance = streamReadInt8(            streamId)
    self.offset   = streamReadInt8(            streamId) / 2

    if nil ~= self.vehicle then
        if     self.cmdId == FollowMe.COMMAND_START then
            FollowMe.startFollowMe(self.vehicle, connection, self.farmId)
        elseif self.cmdId == FollowMe.COMMAND_STOP then
            FollowMe.stopFollowMe(self.vehicle, connection, self.reason)
        elseif self.cmdId == FollowMe.COMMAND_WAITRESUME then
            FollowMe.waitResumeFollowMe(self.vehicle, connection, self.reason)
        end
        FollowMe.setDistance(self.vehicle, self.distance)
        FollowMe.setOffset(  self.vehicle, self.offset)
        FollowMe.setSensor(  self.vehicle, self.sensor)
    end
end


---
---
---

FollowMeReasonEvent = {}
FollowMeReasonEvent_mt = Class(FollowMeReasonEvent, Event)

InitEventClass(FollowMeReasonEvent, "FollowMeReasonEvent")

function FollowMeReasonEvent:emptyNew()
    local self = Event:new(FollowMeReasonEvent_mt)
    self.className = "FollowMeReasonEvent"
    return self
end

function FollowMeReasonEvent:new(vehicle, reason)
--log("FollowMeReasonEvent:new")
    local self = FollowMeReasonEvent:emptyNew()
    local spec = vehicle.spec_followMe
    self.vehicle = vehicle
    self.reason  = Utils.getNoNil(reason, 0)
    return self
end

function FollowMeReasonEvent:writeStream(streamId, connection)
--log("FollowMeReasonEvent:writeStream")
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(           streamId, self.reason,   FollowMe.NUM_BITS_REASON)
end

function FollowMeReasonEvent:readStream(streamId, connection)
--log("FollowMeReasonEvent:readStream")
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.reason  = streamReadUIntN(           streamId, FollowMe.NUM_BITS_REASON)

    if nil ~= self.vehicle then
        FollowMe.showReason(self.vehicle, self.reason, nil)
    end
end

--
print(("Script loaded: FollowMe.lua - from %s (v%s)"):format(g_currentModName, g_modManager:getModByName(g_currentModName).version))
