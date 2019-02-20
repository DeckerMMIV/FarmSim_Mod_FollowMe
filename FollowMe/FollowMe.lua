--
-- Follow Me
--
-- @author  Decker_MMIV (DCK)
-- @contact fs-uk.com, forum.farming-simulator.com
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
      print(string.format("%7ums FollowMe.LUA ", (nil ~= g_currentMission and g_currentMission.time or 0)) .. txt);
  end
end;

local function vec2str(x,y,z)
  if "table" == type(x) then
    x,y,z = unpack(x)
  end
  return ("%.3f/%.3f/%.3f"):format(x,y,z)
end

----

FollowMe = {};

local specTypeName = 'followMe'
--local modSpecTypeName = g_currentModName ..".".. specTypeName
local modSpecTypeName = specTypeName

function FollowMe.getSpec(self)
  --return self["spec_" .. modSpecTypeName]
  return self.spec_followMe
end

--
FollowMe.cMinDistanceBetweenDrops        =   5;
FollowMe.cBreadcrumbsMaxEntries          = 150;
FollowMe.debugDraw = {}

FollowMe.COMMAND_NONE           = 0
FollowMe.COMMAND_START          = 1
FollowMe.COMMAND_WAITRESUME     = 2
FollowMe.COMMAND_STOP           = 3
FollowMe.NUM_BITS_COMMAND = 2

FollowMe.STATE_NONE             = 0
FollowMe.STATE_STARTING         = 1
FollowMe.STATE_FOLLOWING        = 2
FollowMe.STATE_WAITING          = 3
FollowMe.STATE_STOPPING         = 4
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
  --log("FollowMe.registerEventListeners() ",vehicleType)
  for _,funcName in pairs( {
    "onDraw",
    "onLoad",
    "onPostLoad",
    "onDelete",
    "onUpdateTick",
    "onRegisterActionEvents",
    "onAIStart",
    "onAIEnd",
  } ) do
    SpecializationUtil.registerEventListener(vehicleType, funcName, FollowMe)
  end
end

function FollowMe:onLoad(savegame)
    self.followMeIsStarted = false

    local spec = FollowMe.getSpec(self)
    spec.actionEvents = {}

    spec.sumSpeed = 0;
    spec.sumCount = 0;
    spec.DropperCircularArray = {};
    spec.DropperCurrentIndex = -1;
    spec.StalkerVehicleObj = nil;  -- Needed in case self is being deleted.
    --
    spec.FollowState = FollowMe.STATE_NONE;
    spec.FollowVehicleObj = nil;  -- What vehicle is this one following (if any)
    spec.FollowCurrentIndex = -1;
    spec.FollowKeepBack = 25;
    spec.FollowXOffset = 0;
    spec.ToggleXOffset = 0;
    --
    spec.ShowWarningText = nil;
    spec.ShowWarningTime = 0;
    --
    spec.isDirty = false;
    spec.delayDirty = nil;

    --
    if nil ~= savegame and not savegame.resetVehicles then
        local modKey = savegame.key ..".".. modSpecTypeName
        local distance = getXMLInt(savegame.xmlFile, modKey .. "#distance")
        local offset = getXMLFloat(savegame.xmlFile, modKey .. "#offset")
        if nil ~= distance then
            FollowMe.changeDistance(self, { distance }, true ); -- Absolute change
        end
        if nil ~= offset then
            FollowMe.changeXOffset(self, { offset }, true ); -- Absolute change
        end
    end
end;

function FollowMe:onPostLoad(savegame)
  local spec = FollowMe.getSpec(self)
  spec.origPricePerMS = self.spec_aiVehicle.pricePerMS
end

function FollowMe:saveToXMLFile(xmlFile, key, usedModNames)
  --log("usedModNames=",unpack(usedModNames))
  local spec = FollowMe.getSpec(self)
  setXMLInt(  xmlFile, key.."#distance", spec.FollowKeepBack)
  setXMLFloat(xmlFile, key.."#offset",   spec.FollowXOffset)
end;

function FollowMe:onDelete()
    local spec = FollowMe.getSpec(self)
    if nil ~= spec.StalkerVehicleObj then
        -- Stop the stalker-vehicle
        if FollowMe.getIsFollowMeActive(spec.StalkerVehicleObj) then
          FollowMe.stopFollowMe(spec.StalkerVehicleObj, FollowMe.REASON_USER_ACTION);
        end
    end;
end;

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
  return self.followMeIsStarted
end

function FollowMe:getIsFollowMeWaiting()
  local spec = FollowMe.getSpec(self)
  return spec.FollowState == FollowMe.STATE_WAITING
end

function FollowMe:getAINeedsTrafficCollisionBox(superFunc)
  if FollowMe.getIsFollowMeActive(self) then
    return false
  end
  return superFunc(self)
end

function FollowMe:onAIStart()
  if FollowMe.getIsFollowMeActive(self) then
    local specFM = FollowMe.getSpec(self)
    local spec = self.spec_aiVehicle
    spec.pricePerMS = Utils.getNoNil(specFM.origPricePerMS, 1500) * 0.2 -- FollowMe AIs wage is only 20% of base-game's AI.

    -- In case player is so fast, that after stopping a regular AI, and in less than 200ms he manages to start FollowMe, then ensure the traffic collision is deleted.
    if spec.aiTrafficCollisionRemoveDelay > 0 then
      if spec.aiTrafficCollision ~= nil then
        if entityExists(spec.aiTrafficCollision) then
          delete(spec.aiTrafficCollision)
        end
      end
      spec.aiTrafficCollisionRemoveDelay = 0
    end

    -- Bug fix for (1.3.0.0-beta) base-game's script, where it does not set `spec.aiTrafficCollision` to nil after it has been deleted in `AIVehicle:onUpdateTick`.
    -- If this 'set to nil' is not done, then `AIVehicle:onUpdate` will attempt to translate + rotate it, even when FollowMe is not using such a traffic collision.
    spec.aiTrafficCollision = nil
  end
end

function FollowMe:onAIEnd()
  if FollowMe.getIsFollowMeActive(self) then
    local spec = FollowMe.getSpec(self)
    self.spec_aiVehicle.pricePerMS = spec.origPricePerMS -- Restore wage to base-game's value.
    self.followMeIsStarted = false
  end
end

function FollowMe:getReverserDirection()
  if nil ~= self.spec_reverseDriving then
    return (self.spec_reverseDriving.isReverseDriving and -1) or 1
  end
  return 1
end

-- function FollowMe:onWriteStream(streamId, connection)
--     local spec = FollowMe.getSpec(self)
--     streamWriteInt8(streamId, Utils.getNoNil(spec.FollowKeepBack, 0))
--     streamWriteInt8(streamId, Utils.getNoNil(spec.FollowXOffset,  0) * 2)
--     if streamWriteBool(streamId, self.followMeIsStarted) then
--         streamWriteUIntN(streamId, spec.FollowState,   FollowMe.NUM_BITS_STATE)
--         streamWriteUIntN(streamId, spec.startedFarmId, FarmManager.FARM_ID_SEND_NUM_BITS)
--         streamWriteUInt8(streamId, spec.currentHelper.index)
--         writeNetworkNodeObject(streamId, spec.FollowVehicleObj)
--     end
-- end;

-- function FollowMe:onReadStream(streamId, connection)
--     local distance  = streamReadInt8(streamId)
--     local offset    = streamReadInt8(streamId) / 2
--     if streamReadBool(streamId) then
--         local state         = streamReadUIntN(       streamId, FollowMe.NUM_BITS_STATE)
--         local farmId        = streamReadUIntN(       streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
--         local helperIndex   = streamReadUInt8(       streamId)
--         local followObj     = readNetworkNodeObject( streamId)

--         FollowMe.onStartFollowMe(self, followObj, helperIndex, true, farmId);

--         local spec = FollowMe.getSpec(self)
--         spec.FollowState = state;
--     end

--     FollowMe.changeDistance(self, { distance }, true ); -- Absolute change
--     FollowMe.changeXOffset( self, { offset },   true ); -- Absolute change
-- end;


function FollowMe:getFollowNode()
    return Utils.getNoNil(self.steeringCenterNode, self.components[1].node)
end

--[[
--FollowMe.objectCollisionMask = 32+64+128+256+4096;
function FollowMe:mouseEvent(posX, posY, isDown, isUp, button)
    if FollowMe.showFollowMeFl then
        FollowMe.raycastResult = nil

        local x,y,z = getWorldTranslation(self.cameras[self.camIndex].cameraNode);
        local wx,wy,wz = unProject(posX, posY, 1);
        local dx,dy,dz = wx-x, wy-y, wz-z;
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
                local spec = FollowMe.getSpec(self)
                local stalker = spec.StalkerVehicleObj;
                if nil ~= stalker then
                    FollowMe.changeDistance(stalker, { oz } );
                    FollowMe.changeXOffset(stalker, { ox } );
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
    assert(nil ~= g_server);

    local spec = FollowMe.getSpec(self)

    spec.DropperCurrentIndex = spec.DropperCurrentIndex + 1; -- Keep incrementing index, so followers will be able to detect if they get too far behind of the circular-array.

    local dropIndex = 1+(spec.DropperCurrentIndex % FollowMe.cBreadcrumbsMaxEntries);
    if nil == targetXYZ then
        spec.DropperCircularArray[dropIndex] = crumb;
    else
        -- Due to a different target, make a "deep-copy" of the crumb.
        spec.DropperCircularArray[dropIndex] = {
            trans           = targetXYZ,
            rot             = crumb.rot,
            maxSpeed        = crumb.maxSpeed,
            turnLightState  = crumb.turnLightState,
        };
    end;
end;

function FollowMe:addDrop(maxSpeed, turnLightState, reverserDirection)
    assert(nil ~= g_server);

    local spec = FollowMe.getSpec(self)
    spec.DropperCurrentIndex = spec.DropperCurrentIndex + 1; -- Keep incrementing index, so followers will be able to detect if they get too far behind of the circular-array.

    local node = self:getAIVehicleSteeringNode()
    local dropIndex = 1+(spec.DropperCurrentIndex % FollowMe.cBreadcrumbsMaxEntries);
    spec.DropperCircularArray[dropIndex] = {
        trans           = { getWorldTranslation(node) }, -- { vX,vY,vZ },
        rot             = { localDirectionToWorld(node, 0,0,Utils.getNoNil(reverserDirection,1)) }, -- { vrX,vrY,vrZ },
        maxSpeed        = maxSpeed,
        turnLightState  = turnLightState,
    };

    --log(string.format("Crumb #%d: trans=%f/%f/%f, rot=%f/%f/%f, avgSpeed=%f", dropIndex, wx,wy,wz, rx,ry,rz, maxSpeed));
end;

function FollowMe:changeDistance(newValue, noSendEvent)
    local spec = FollowMe.getSpec(self)
    if "table" == type(newValue) then
        newValue = newValue[1] -- Absolute change
    else
        newValue = spec.FollowKeepBack + newValue -- Relative change
    end
    spec.FollowKeepBack = MathUtil.clamp(newValue, -50, 127); -- Min -128 and Max 127 due to writeStreamInt8().
    if not noSendEvent then
        spec.delayDirty = g_currentMission.time + 750;
    end
end;

function FollowMe:changeXOffset(newValue, noSendEvent)
    local spec = FollowMe.getSpec(self)
    if "table" == type(newValue) then
        newValue = newValue[1] -- Absolute change
    else
        newValue = spec.FollowXOffset + newValue -- Relative change
    end
    spec.FollowXOffset = MathUtil.clamp(newValue, -50.0, 50.0);
    if not noSendEvent then
        spec.delayDirty = g_currentMission.time + 750;
    end
end;

function FollowMe:toggleXOffset()
    local spec = FollowMe.getSpec(self)
    if 0 == spec.FollowXOffset and 0 ~= spec.ToggleXOffset then
      spec.FollowXOffset = -spec.ToggleXOffset
      spec.ToggleXOffset = 0
    else
      spec.ToggleXOffset = spec.FollowXOffset
      spec.FollowXOffset = 0
    end
    FollowMe.changeXOffset(self, { spec.FollowXOffset } ) -- Absolute change
end

function FollowMe:handleAction(actionName, inputValue, callbackState, isAnalog, isMouse)
    --log("FollowMe:handleAction ",actionName," ",inputValue," ",callbackState," ",isAnalog," ",isMouse)
    local spec = FollowMe.getSpec(self)
    local stalker = spec.StalkerVehicleObj;
    local switch = {
        FollowMeMyToggle = function()
            if FollowMe.getIsFollowMeActive(self) then
                FollowMe.stopFollowMe(self, FollowMe.REASON_USER_ACTION);
            elseif g_currentMission:getHasPlayerPermission("hireAssistant") then
              if FollowMe.getCanStartFollowMe(self) then
                FollowMe.startFollowMe(self, nil, g_currentMission.player.farmId);
              end
            else
                -- No permission
            end
        end
        ,FollowMeMyPause   = function() FollowMe.waitResumeFollowMe(self, FollowMe.REASON_USER_ACTION); end
        ,FollowMeMyOffs    = function(value)
          if math.abs(value) >= 0.8 then
            FollowMe.changeXOffset(self, 0.5 * MathUtil.sign(value));
          end
        end
        ,FollowMeMyOffsTgl = function() FollowMe.toggleXOffset(self); end

        ,FollowMeFlStop = function()
            if nil ~= stalker and FollowMe.getIsFollowMeActive(stalker) then
                FollowMe.stopFollowMe(stalker, FollowMe.REASON_USER_ACTION);
            end
        end
        ,FollowMeFlPause   = function() FollowMe.waitResumeFollowMe(stalker, FollowMe.REASON_USER_ACTION); end
        ,FollowMeFlOffs    = function(value)
          if math.abs(value) >= 0.8 then
            FollowMe.changeXOffset(stalker, 0.5 * MathUtil.sign(value));
          end
        end
        ,FollowMeFlOffsTgl = function() FollowMe.toggleXOffset(stalker); end
    }
    local action = switch[actionName]
    if action then
        action(inputValue)
    -- else
    --   log("Not found action: ",actionName)
    end
end

function FollowMe:actionChangeDistance(actionName, inputValue, callbackState, isAnalog, isMouse)
  local spec = FollowMe.getSpec(self)

  if nil == spec.lastInputTime then
    if math.abs(inputValue) >= 0.8 then
      -- Start of input
      spec.lastInputValue = inputValue
      spec.lastInputTime = g_time
      spec.nextInputTimeout = g_time + 500
    end
  else
    local who = self
    if 1 == callbackState then
      who = spec.StalkerVehicleObj;
    end

    if math.abs(inputValue) >= 0.5 and nil ~= who then
      -- Long-hold? Change distance in steps of 1
      if spec.nextInputTimeout < g_time then
        FollowMe.changeDistance(who, 1 * MathUtil.sign(spec.lastInputValue));
        spec.nextInputTimeout = g_time + 250
      end
    else
      -- Short-tap? Change distance in steps of 5
      if spec.lastInputTime > g_time - 150 and nil ~= who then
        FollowMe.changeDistance(who, 5 * MathUtil.sign(spec.lastInputValue));
      end
      spec.lastInputValue = nil
      spec.lastInputTime = nil
      spec.nextInputTimeout = nil
    end
  end
end


function FollowMe:onRegisterActionEvents(isSelected, isOnActiveVehicle, arg3, arg4, arg5)
    --log("FollowMe:onRegisterActionEvents(",self,") ",isSelected," ",isOnActiveVehicle," ",arg3," ",arg4," ",arg5)
    --Actions are only relevant if the function is run clientside
    if not self.isClient then
      return
    end

    local spec = FollowMe.getSpec(self)
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

    --local activeForInput = self:getIsEntered() and not g_currentMission.isPlayerFrozen and not g_gui:getIsGuiVisible();
    local isEntered = self:getIsEntered()
    local activeForInput = self:getIsActiveForInput(true) and not self.isConveyorBelt
    local isFollowMeActive = FollowMe.getIsFollowMeActive(self)
    --log("FollowMe:onRegisterActionEvents(",self,") isEntered=",isEntered," activeForInput=",activeForInput," followMeActive=",isFollowMeActive)
    if isEntered then
      if (activeForInput or isFollowMeActive) then
        addActionEvents(self, nil, {
          { InputAction.FollowMeMyToggle, g_i18n:getText(isFollowMeActive and "FollowMeMyTurnOff" or "FollowMeMyTurnOn") }
        } )
        if isFollowMeActive then
          addActionEvents(self, GS_PRIO_VERY_HIGH, {
            { InputAction.FollowMeMyPause,   g_i18n:getText(self:getIsFollowMeWaiting() and "FollowMeMyResume" or "FollowMeMyWait") },
            { InputAction.FollowMeMyOffs,    g_i18n:getText("FollowMeMyOffs") },
            { InputAction.FollowMeMyOffsTgl, nil },
          } )
          --
          local _,evtId = self:addActionEvent(spec.actionEvents, InputAction.FollowMeMyDist, self, FollowMe.actionChangeDistance, true, false, true, true, 0)
          g_inputBinding:setActionEventText(evtId, g_i18n:getText("FollowMeMyDist"))
          g_inputBinding:setActionEventTextPriority(evtId, GS_PRIO_VERY_HIGH)
          g_inputBinding:setActionEventTextVisibility(evtId, true)

        end
      end
      if (activeForInput or isFollowMeActive) and nil ~= spec.StalkerVehicleObj then
        addActionEvents(self, GS_PRIO_HIGH, {
          { InputAction.FollowMeFlStop,    nil },
          { InputAction.FollowMeFlPause,   g_i18n:getText(spec.StalkerVehicleObj:getIsFollowMeWaiting() and "FollowMeFlResume" or "FollowMeFlWait") },
          { InputAction.FollowMeFlOffs,    g_i18n:getText("FollowMeFlOffs") },
          { InputAction.FollowMeFlOffsTgl, nil },
        } )
        --
        local _,evtId = self:addActionEvent(spec.actionEvents, InputAction.FollowMeFlDist, self, FollowMe.actionChangeDistance, true, false, true, true, 1)
        g_inputBinding:setActionEventText(evtId, g_i18n:getText("FollowMeFlDist"))
        g_inputBinding:setActionEventTextPriority(evtId, GS_PRIO_HIGH)
        g_inputBinding:setActionEventTextVisibility(evtId, true)
    end
    end
end

function FollowMe:onUpdateTick(dt, isActiveForInput, isSelected)
    local spec = FollowMe.getSpec(self)

    if self.isServer and nil ~= spec then
        if FollowMe.getIsFollowMeActive(self) and nil ~= spec.FollowVehicleObj then
            local leader = spec.FollowVehicleObj;
            local leaderSpec = FollowMe.getSpec(leader)
            local crumbIndexDiff = leaderSpec.DropperCurrentIndex - spec.FollowCurrentIndex;
            if crumbIndexDiff > 0 then
              local crumb = leaderSpec.DropperCircularArray[1+(spec.FollowCurrentIndex % FollowMe.cBreadcrumbsMaxEntries)];
              self:setTurnLightState(crumb.turnLightState)
            else
              self:setTurnLightState(leader:getTurnLightState())
            end

            self:setLightsTypesMask(       leader:getLightsTypesMask())
            self:setBeaconLightsVisibility(leader:getBeaconLightsVisibility())
        else
          local direction = FollowMe.getReverserDirection(self)
          if (direction * self.movingDirection > 0) then  -- Must drive forward to drop crumbs
            spec.sumSpeed = spec.sumSpeed + self.lastSpeed;
            spec.sumCount = spec.sumCount + 1;
            --
            local distancePrevDrop
            if -1 < spec.DropperCurrentIndex then
              local node = self:getAIVehicleSteeringNode()
              local vX,vY,vZ = getWorldTranslation(node)
              local oX,oY,oZ = unpack(spec.DropperCircularArray[1+(spec.DropperCurrentIndex % FollowMe.cBreadcrumbsMaxEntries)].trans);
              distancePrevDrop = MathUtil.vector2LengthSq(oX - vX, oZ - vZ);
            else
              distancePrevDrop = FollowMe.cMinDistanceBetweenDrops
              spec.sumSpeed = 10 / 3600 -- For first trail-crumb dropped, when vehicle is not moving. This should allow followers to "actually move faster" after a savegame reload.
              spec.sumCount = 1
            end
            if distancePrevDrop >= FollowMe.cMinDistanceBetweenDrops then
                local maxSpeed = math.max(1, (spec.sumSpeed / spec.sumCount) * 3600)
                FollowMe.addDrop(self, maxSpeed, self:getTurnLightState(), direction);
                --
                spec.sumSpeed = 0;
                spec.sumCount = 0;
            end;
          end
        end;
    end;

    --FollowMe.sendUpdate(self);
end;

-- function FollowMe.sendUpdate(self)
--     local spec = FollowMe.getSpec(self)

--     if spec.isDirty
--     or (nil ~= spec.delayDirty and spec.delayDirty < g_currentMission.time)
--     then
--         spec.isDirty = false;
--         spec.delayDirty = nil;
--         --
--         if nil == g_server then
--             -- Client - Send "distance/offset update" to server
--             g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_NONE, FollowMe.REASON_NONE, nil));
--         else
--             -- Server only
--             g_server:broadcastEvent(FollowMeResponseEvent:new(self, spec.FollowState, FollowMe.REASON_NONE, spec.currentHelper), nil, nil, self);
--         end
--     end;
-- end;

function FollowMe:startFollowMe(connection, startedFarmId)
    if nil == g_server then
        -- Client - Send command to server
        g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_START, nil, startedFarmId));
    else
        -- Server only
        if FollowMe.getIsFollowMeActive(self) or self:getIsAIActive() then
            FollowMe.showReason(self, connection, FollowMe.REASON_ALREADY_AI)
        elseif not self.spec_motorized.isMotorStarted then
            FollowMe.showReason(self, connection, FollowMe.REASON_ENGINE_STOPPED)
        else
            local closestVehicle = FollowMe.findVehicleInFront(self)
            if nil == closestVehicle then
                FollowMe.showReason(self, connection, FollowMe.REASON_NO_TRAIL_FOUND)
            else
                FollowMe.showReason(self, connection, FollowMe.REASON_CLEAR_WARNING)
                self:startAIVehicle(nil, nil, startedFarmId, "FollowMe")
            end
        end
    end
end

function FollowMe:stopFollowMe(reason)
    if nil == g_server then
        -- Client - Send command to server
        g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_STOP, reason, nil));
    else
        -- Server only
        self:stopAIVehicle()
    end
end

function FollowMe:waitResumeFollowMe(reason, noEventSend)
    if nil == g_server then
        -- Client
        g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_WAITRESUME, reason, nil));
    else
        -- Server only
        FollowMe.onWaitResumeFollowMe(self, reason);
    end
end

--
--

AIDriveStrategyFollow = {};
local AIDriveStrategyFollow_mt = Class(AIDriveStrategyFollow, AIDriveStrategy);

function AIDriveStrategyFollow:new(customMt)
    return AIDriveStrategy:new( Utils.getNoNil(customMt, AIDriveStrategyFollow_mt) );
end

function AIDriveStrategyFollow:delete()
    local vehicle = self.vehicle
    local vehicleSpec = FollowMe.getSpec(vehicle)

    local leader = vehicleSpec.FollowVehicleObj
    if leader then
      local leaderSpec = FollowMe.getSpec(leader)
      leaderSpec.StalkerVehicleObj = nil
    end
    vehicleSpec.FollowVehicleObj = nil
    vehicleSpec.FollowState = FollowMe.STATE_NONE

    vehicle.spec_aiVehicle.mod_CheckSpeedLimitOnlyIfWorking = nil

    AIDriveStrategyFollow:superClass().delete(self);
end

function AIDriveStrategyFollow:setAIVehicle(vehicle)
    AIDriveStrategyFollow:superClass().setAIVehicle(self, vehicle);

    local vehicleSpec = FollowMe.getSpec(vehicle)

    local closestVehicle,startIndex = FollowMe.findVehicleInFront(vehicle)
    if nil ~= closestVehicle then
      local closestVehicleSpec = FollowMe.getSpec(closestVehicle)

      closestVehicleSpec.StalkerVehicleObj = vehicle

      vehicleSpec.FollowVehicleObj = closestVehicle
      vehicleSpec.FollowCurrentIndex = startIndex
      vehicleSpec.FollowState = FollowMe.STATE_FOLLOWING
      vehicle.followMeIsStarted = true

      vehicle.spec_aiVehicle.mod_CheckSpeedLimitOnlyIfWorking = true  -- A work-around, for forcing AIVehicle:onUpdateTick() making its call to `self:getSpeedLimit()` into a `self:getSpeedLimit(true)`
    else
      vehicleSpec.FollowVehicleObj = nil
      vehicle.followMeIsStarted = false
    end
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
    attachedTool:doStateChange(BaleWrapper.CHANGE_BUTTON_EMPTY);
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
      local attachedTool = nil;
      for _,tool in pairs(self.vehicle:getAttachedImplements()) do
          if nil ~= tool.object then
              local spec = tool.object.spec_baler
              if nil ~= spec and nil ~= spec.baleUnloadAnimationName then
                  if nil ~= tool.object.spec_baleWrapper then
                      attachedTool = { tool.object, AIDriveStrategyFollow.checkBalerAndWrapper };
                      break;
                  end

                  attachedTool = { tool.object, AIDriveStrategyFollow.checkBaler };
                  break
              end

              if nil ~= tool.object.spec_baleWrapper then
                  attachedTool = { tool.object, AIDriveStrategyFollow.checkBaleWrapper };
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
    local vehicleSpec = FollowMe.getSpec(vehicle)
    local leader = vehicleSpec.FollowVehicleObj;

    if nil == vehicleSpec.FollowVehicleObj or nil == leader then
      vehicle:stopAIVehicle(AIVehicle.STOP_REASON_UNKOWN);
      return nil,nil,nil,nil,nil
    end

    local leaderSpec = FollowMe.getSpec(leader)
    -- actual target
    local tX,tY,tZ;
    --
    local isAllowedToDrive  = (FollowMe.STATE_WAITING ~= vehicleSpec.FollowState)
    local distanceToStop    = -(FollowMe.getKeepBack(vehicle))
    local keepInFrontMeters = FollowMe.getKeepFront(vehicle)
    local maxSpeed = 0
    local steepTurnAngle = false
    --
    local crumbIndexDiff = leaderSpec.DropperCurrentIndex - vehicleSpec.FollowCurrentIndex;
    --
    if crumbIndexDiff >= FollowMe.cBreadcrumbsMaxEntries then
        -- circular-array have "circled" once, and this follower did not move fast enough.
        if vehicleSpec.FollowState ~= FollowMe.STATE_STOPPING then
            vehicle:stopAIVehicle(AIVehicle.STOP_REASON_UNKOWN);  -- FollowMe.REASON_TOO_FAR_BEHIND
            return nil,nil,nil,nil,nil
        end

        isAllowedToDrive = false

        -- vehicle rotation
        local vRX,vRY,vRZ   = localDirectionToWorld(vehicle:getAIVehicleSteeringNode(), 0,0,FollowMe.getReverserDirection(vehicle));

        -- Set target 2 meters straight ahead of vehicle.
        tX = vX + vRX * 2;
        tY = vY;
        tZ = vZ + vRZ * 2;
    elseif crumbIndexDiff > 0 then
        -- Following crumbs...
        local crumbT = leaderSpec.DropperCircularArray[1+(vehicleSpec.FollowCurrentIndex % FollowMe.cBreadcrumbsMaxEntries)];
        maxSpeed = math.max(5, crumbT.maxSpeed);
        --
        local ox,oy,oz = crumbT.trans[1],crumbT.trans[2],crumbT.trans[3];
        local orx,ory,orz = unpack(crumbT.rot);
        -- Apply offset
        tX = ox - orz * vehicleSpec.FollowXOffset;
        tY = oy;
        tZ = oz + orx * vehicleSpec.FollowXOffset;
        --
        local dx,dz = tX - vX, tZ - vZ;
        local tDist = MathUtil.vector2Length(dx,dz);
        --
        local trAngle = math.atan2(orx,orz);
        local nz = dx * math.sin(trAngle) + dz * math.cos(trAngle);
        steepTurnAngle = (tDist < 15 and (nz / tDist) < 0.8)
        --
        local nextCrumbOffset = 1
        if (tDist < (FollowMe.cMinDistanceBetweenDrops / 2)) -- close enough to crumb?
        or (nz < 0) -- already in front of crumb?
        then
            FollowMe.copyDrop(vehicle, crumbT, (vehicleSpec.FollowXOffset == 0) and nil or {tX,tY,tZ});
            -- Go to next crumb
            vehicleSpec.FollowCurrentIndex = vehicleSpec.FollowCurrentIndex + 1;
            nextCrumbOffset = 0
            crumbIndexDiff = leaderSpec.DropperCurrentIndex - vehicleSpec.FollowCurrentIndex;
        end
        --
        if crumbIndexDiff > 0 then
            -- Still following crumbs...
            local crumbN = leaderSpec.DropperCircularArray[1+((vehicleSpec.FollowCurrentIndex + nextCrumbOffset) % FollowMe.cBreadcrumbsMaxEntries)];
            if nil ~= crumbN then
                -- Apply offset, to next original target
                local ntX = crumbN.trans[1] - crumbN.rot[3] * vehicleSpec.FollowXOffset;
                local ntZ = crumbN.trans[3] + crumbN.rot[1] * vehicleSpec.FollowXOffset;
                local pct = math.max(1 - (tDist / FollowMe.cMinDistanceBetweenDrops), 0);
                tX,_,tZ = MathUtil.vector3ArrayLerp( {tX,0,tZ}, {ntX,0,ntZ}, pct);
                maxSpeed = math.max(5, (maxSpeed + crumbN.maxSpeed) / 2)
            end;
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
        local lx,ly,lz      = getWorldTranslation(lNode);
        local lrx,lry,lrz   = localDirectionToWorld(lNode, 0,0,FollowMe.getReverserDirection(leader));

        maxSpeed = math.max(1, leader.lastSpeed * 3600) -- only consider forward movement.

        -- leader-target adjust with offset
        tX = lx - lrz * vehicleSpec.FollowXOffset + lrx * keepInFrontMeters;
        tY = ly
        tZ = lz + lrx * vehicleSpec.FollowXOffset + lrz * keepInFrontMeters;

        -- Rotate to see if the target is still "in front of us"
        local dx,dz = tX - vX, tZ - vZ;
        local trAngle = math.atan2(lrx,lrz);
        local nz = dx * math.sin(trAngle) + dz * math.cos(trAngle);

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

function FollowMe:updateAIDriveStrategies()
    local spec = self.spec_aiVehicle
    if spec.driveStrategies ~= nil and #spec.driveStrategies > 0 then
        for i=#spec.driveStrategies,1,-1 do
            spec.driveStrategies[i]:delete()
            table.remove(spec.driveStrategies, i)
        end
        spec.driveStrategies = {}
    end

    local driveStrategyFollow = AIDriveStrategyFollow:new()
    driveStrategyFollow:setAIVehicle(self)
    table.insert(spec.driveStrategies, driveStrategyFollow)
end

--
--

function FollowMe:onWaitResumeFollowMe(reason, noEventSend)
    local spec = FollowMe.getSpec(self)

    if spec.FollowState == FollowMe.STATE_FOLLOWING then
        spec.FollowState = FollowMe.STATE_WAITING
        spec.isDirty = (nil ~= g_server)
    elseif spec.FollowState == FollowMe.STATE_WAITING then
        spec.FollowState = FollowMe.STATE_FOLLOWING
        spec.isDirty = (nil ~= g_server)
    end

    self:requestActionEventUpdate()
    spec.FollowVehicleObj:requestActionEventUpdate()
end

function FollowMe:showReason(connection, reason, currentHelper)
    if nil ~= connection then
        local spec = FollowMe.getSpec(self)
        connection:sendEvent(FollowMeResponseEvent:new(self, spec.FollowState, reason, currentHelper), nil, nil, self);
    else
        if reason == FollowMe.REASON_NONE then
            -- No notification needed
        elseif reason == FollowMe.REASON_ALREADY_AI then
            FollowMe.setWarning(self, "FollowMeAlreadyAI");
        elseif reason == FollowMe.REASON_NO_TRAIL_FOUND then
            FollowMe.setWarning(self, "FollowMeDropperNotFound");
        elseif reason == FollowMe.REASON_ENGINE_STOPPED then
            FollowMe.setWarning(self, "FollowMeStartEngine")
        elseif reason == FollowMe.REASON_CLEAR_WARNING then
            FollowMe.setWarning(self, nil)
        elseif nil ~= reason then
            local txtId = ("FollowMeReason%d"):format(reason)
            if g_i18n:hasText(txtId) then
                local helperName = "?"
                if nil ~= currentHelper then
                    helperName = Utils.getNoNil(currentHelper.name, helperName)
                end
                local reasonTxt = g_i18n:getText(txtId):format(helperName)
                local reasonClr = {0.5, 0.5, 1.0, 1.0}
                if reason == FollowMe.REASON_TOO_FAR_BEHIND then
                    reasonClr = FSBaseMission.INGAME_NOTIFICATION_CRITICAL
                end
    --log("FollowMe:showReason(): ",reasonTxt)
                g_currentMission:addIngameNotification(reasonClr, reasonTxt)
            end
        end
    end
end

function FollowMe:setWarning(txt, noSendEvent)
    local spec = FollowMe.getSpec(self)

    if nil == txt then
        spec.ShowWarningText = "";
        spec.ShowWarningTime = 0;
    else
        spec.ShowWarningText = g_i18n:getText(txt);
        spec.ShowWarningTime = g_currentMission.time + 2500;
    end
end;


function FollowMe:findVehicleInFront()
    if not self.isServer then
        return nil
    end
    -- Anything below is only server-side

    --local node      = FollowMe.getFollowNode(self)
    local node      = self:getAIVehicleSteeringNode()
    local wx,wy,wz  = getWorldTranslation(node);
    local rx,ry,rz  = localDirectionToWorld(node, 0,0,FollowMe.getReverserDirection(self));
    local rlength   = MathUtil.vector2Length(rx,rz);
    local rotDeg    = math.deg(math.atan2(rx/rlength,rz/rlength));
    local rotRad    = MathUtil.degToRad(rotDeg-45.0);
    --log(string.format("getWorldTranslation:%f/%f/%f - localDirectionToWorld:%f/%f/%f - rDeg:%f - rRad:%f", wx,wy,wz, rx,ry,rz, rotDeg, rotRad));

    --log("Myself ",self:getName()," Rxyz(",vec2str(rx,ry,rz),") Wxyz(",vec2str(wx,wy,wz),")")

    -- Find closest vehicle, that is in front of self.
    local closestDistance = 50*50; -- due to using Utils.vector2LengthSq()
    local closestVehicle = nil;
    for _,vehicleObj in pairs(g_currentMission.vehicles) do
        local vehicleSpec = FollowMe.getSpec(vehicleObj)
        if SpecializationUtil.hasSpecialization(Drivable, vehicleObj.specializations)
        and nil ~= vehicleSpec -- Make sure its a vehicle that has the FollowMe specialization added.
        and nil ~= vehicleSpec.DropperCircularArray -- Make sure other vehicle has circular array
        and nil == vehicleSpec.StalkerVehicleObj -- and is not already stalked by something.
        then
            --local vehicleNode = FollowMe.getFollowNode(vehicleObj);
            local vehicleNode = vehicleObj:getAIVehicleSteeringNode()
            -- Make sure that the other vehicle is actually driving "away from us"
            -- I.e. in the same direction
            local vrx, vry, vrz = localDirectionToWorld(vehicleNode, 0,0,FollowMe.getReverserDirection(vehicleObj));
            if MathUtil.dotProduct(rx,0,rz, vrx,0,vrz) > 0.2 then
                local vx,vy,vz = getWorldTranslation(vehicleNode);
                local dx,dz = vx-wx, vz-wz;
                local dist = MathUtil.vector2LengthSq(dx,dz);
                if (dist < closestDistance) then
                    -- Rotate to see if vehicleObj is "in front of us"
                    local nx = dx * math.cos(rotRad) - dz * math.sin(rotRad);
                    local nz = dx * math.sin(rotRad) + dz * math.cos(rotRad);
                    if (nx > 0) and (nz > 0) then
                        closestDistance = dist;
                        closestVehicle = vehicleObj;

                        --log("closest(",dist,") ",closestVehicle:getName()," Rxyz(",vec2str(vrx,vry,vrz),") Wxyz(",vec2str(vx,vy,vz),")")
                    end;
                end;
            end;
        end;
    end;

    local followCurrentIndex = -1;
    if nil ~= closestVehicle then
        --log("FollowMe:findVehicleInFront() candidate=",closestVehicle:getName())
        -- Find closest "breadcrumb"
        local closestDistance = 50*50; -- due to using Utils.vector2LengthSq()
        local closestSpec = FollowMe.getSpec(closestVehicle)
        for i=closestSpec.DropperCurrentIndex, math.max(closestSpec.DropperCurrentIndex - FollowMe.cBreadcrumbsMaxEntries,0), -1 do
            local crumb = closestSpec.DropperCircularArray[1+(i % FollowMe.cBreadcrumbsMaxEntries)];
            if nil ~= crumb then
                local x,y,z = unpack(crumb.trans);
                -- Translate
                local dx,dz = x-wx, z-wz;
                local dist = MathUtil.vector2LengthSq(dx,dz);
                --local r = Utils.getYRotationFromDirection(dx,dz);
                --log(string.format("#%d - xz:%f/%f - dxdz:%f/%f - r:%f - dist:%f", i, x,z, dx,dz, r, dist));
                if (dist > 2) and (dist < closestDistance) then
                    -- Rotate to see if the point is "in front of us"
                    local nx = dx * math.cos(rotRad) - dz * math.sin(rotRad);
                    local nz = dx * math.sin(rotRad) + dz * math.cos(rotRad);
                    if (nx > 0) and (nz > 0) then
                        --log(string.format("#%d - xz:%f/%f - dxdz:%f/%f - dist:%f - nxnz:%f/%f", i, x,z, dx,dz, dist, nx,nz));
                        closestDistance = dist;
                        followCurrentIndex = i;
                    end;
                end;
                --
                if -1 ~= followCurrentIndex and dist > closestDistance then
                    -- If crumb is "going further away" from already found one, then stop searching.
                    break;
                end;
            end;
        end;
        --log(string.format("ClosestDist:%f, index:%d", closestDistance, followCurrentIndex));
        --
        if -1 == followCurrentIndex then
          closestVehicle = nil
        end;
    end

    --log("FollowMe:findVehicleInFront() actual=",(nil ~= closestVehicle) and closestVehicle:getFullName() or "(nil)")
    return closestVehicle, followCurrentIndex
end

-- Get distance to keep-in-front, or zero if not.
function FollowMe:getKeepFront()
    local spec = FollowMe.getSpec(self)
    if (spec.FollowKeepBack >= 0) then
        return 0;
    end
    return math.abs(spec.FollowKeepBack);
end

-- Get distance to keep-back, or zero if not.
function FollowMe:getKeepBack(speedKMH)
  local spec = FollowMe.getSpec(self)
  local keepBack = MathUtil.clamp(spec.FollowKeepBack, 0, 999);
  return keepBack
end;

--
--
--

function FollowMe.getWorldToScreen(nodeId)
    if nil ~= nodeId then
        local tX,tY,tZ = getWorldTranslation(nodeId);
        if nil ~= tX then
            --tY = tY + self.displayYoffset;
            local sx,sy,sz = project(tX,tY,tZ);
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

function FollowMe.renderShadedTextCenter(sx,sy, txt)
    setTextAlignment(RenderText.ALIGN_CENTER);
    setTextBold(true)
    setTextColor(0,0,0,1);
    renderText(sx+0.001, sy-0.001, 0.015, txt);
    setTextColor(1,1,1,1);
    renderText(sx, sy, 0.015, txt);
end

function FollowMe:onDraw(isActiveForInput, isSelected)
    local spec = FollowMe.getSpec(self)
    if nil == spec then
        return
    end
    if spec.ShowWarningTime > g_currentMission.time then
        g_currentMission:showBlinkingWarning(spec.ShowWarningText)
    end;
    --
    local showFollowMeMy = true
    local showFollowMeFl = true

    -- if self.isHired then
    --     showFollowMeMy = false
    -- end
    --
    if nil ~= spec.FollowVehicleObj then
        if showFollowMeMy then
            local sx,sy = FollowMe.getWorldToScreen(spec.FollowVehicleObj.rootNode)
            if nil ~= sx then
                local txt = g_i18n:getText("FollowMeLeader")
                local leaderSpec = FollowMe.getSpec(spec.FollowVehicleObj)
                -- if nil ~= leaderSpec.currentHelper then
                --     txt = txt .. (" '%s'"):format(leaderSpec.currentHelper.name)
                -- end
                local dist = spec.FollowKeepBack
                if 0 ~= dist then
                    txt = txt .. "\n" .. (g_i18n:getText((dist > 0) and "FollowMeDistAhead" or "FollowMeDistBehind")):format(math.abs(dist))
                end
                local offs = spec.FollowXOffset;
                if 0 ~= offs then
                    txt = txt .. "\n" .. (g_i18n:getText((offs > 0) and "FollowMeOffLft" or "FollowMeOffRgt")):format(math.abs(offs))
                end
                FollowMe.renderShadedTextCenter(sx,sy, txt)
            end
            if spec.FollowState == FollowMe.STATE_WAITING then
                local sx,sy = FollowMe.getWorldToScreen(self.rootNode)
                if nil ~= sx then
                    FollowMe.renderShadedTextCenter(sx,sy, g_i18n:getText("FollowMePaused"))
                end
            end
        end
    end
    --
    if nil ~= spec.StalkerVehicleObj then
        local stalkerSpec = FollowMe.getSpec(spec.StalkerVehicleObj)
        local txt = nil
        if showFollowMeFl then
            txt = g_i18n:getText("FollowMeFollower")
            -- if nil ~= stalkerSpec.currentHelper then
            --     txt = txt .. (" '%s'"):format(stalkerSpec.currentHelper.name)
            -- end
            if stalkerSpec.FollowState == FollowMe.STATE_WAITING then
                txt = txt .. g_i18n:getText("FollowMePaused")
            end
            local dist = stalkerSpec.FollowKeepBack
            if 0 ~= dist then
                txt = txt .. "\n" .. (g_i18n:getText((dist > 0) and "FollowMeDistBehind" or "FollowMeDistAhead")):format(math.abs(dist))
            end
            local offs = stalkerSpec.FollowXOffset;
            if 0 ~= offs then
                txt = txt .. "\n" .. (g_i18n:getText((offs > 0) and "FollowMeOffRgt" or "FollowMeOffLft")):format(math.abs(offs))
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
                FollowMe.renderShadedTextCenter(sx,sy, txt)
            end
        end
    end
    --
--    if g_gameSettings:getValue("showHelpMenu") then
        -- if nil ~= spec.FollowVehicleObj
        -- or (showFollowMeMy and g_currentMission:getHasPlayerPermission("hireAI"))
        -- then
        --     g_currentMission:addHelpButtonText(g_i18n:getText("FollowMeMyToggle"), InputBinding.FollowMeMyToggle, nil, GS_PRIO_HIGH);
        -- end;
        --
        -- if nil ~= spec.FollowVehicleObj then
        --     g_currentMission:addExtraPrintText(string.format(g_i18n:getText("FollowMeKeysMyself"),FollowMe.keys_FollowMeMy), nil, GS_PRIO_NORMAL);
        -- end;
        -- --
        -- if nil ~= spec.StalkerVehicleObj then
        --     g_currentMission:addExtraPrintText(string.format(g_i18n:getText("FollowMeKeysBehind"),FollowMe.keys_FollowMeFl), nil, GS_PRIO_NORMAL);
        -- end;
--[[DEBUG
    else
        --if nil ~= spec.FollowVehicleObj then
            local yPos = 0.9;
            setTextColor(1,1,1,1);
            setTextBold(true);
            local keys = {}
            for k,_ in pairs(FollowMe.debugDraw) do
                table.insert(keys,k);
            end;
            table.sort(keys);
            for _,k in pairs(keys) do
                local v = FollowMe.debugDraw[k];
                yPos = yPos - 0.02;
                renderText(0.01, yPos, 0.02, v[1]);
                renderText(0.11, yPos, 0.02, v[2]);
            end;
            setTextBold(false);
        --end;
--DEBUG]]
--    end;

--[[DEBUG
    if Vehicle.debugRendering and self.isServer then
        --FollowMe.drawDebug(self);

        local keys = {}
        for k,_ in pairs(FollowMe.debugDraw) do
            table.insert(keys,k);
        end;
        table.sort(keys);
        local txt = "";
        for _,k in pairs(keys) do
            txt = txt .. FollowMe.debugDraw[k][1] .." ".. FollowMe.debugDraw[k][2] .. "\n";
        end;

        setTextBold(false);
        setTextColor(0.85, 0.85, 1, 1);
        setTextAlignment(RenderText.ALIGN_LEFT);
        renderText(0.005, 0.5, 0.02, txt);

        if FollowMe.dbgTarget then
            -- Draw a "dot" as the target for the follower
            local x,y,z = project(FollowMe.dbgTarget[1],FollowMe.dbgTarget[2],FollowMe.dbgTarget[3]);
            if  x<1 and x>0
            and y<1 and y>0
            --and z<1 and z>0
            then
                if (g_currentMission.time % 500) < 250 then
                    setTextColor(1,1,1,1);
                else
                    setTextColor(0.5,0.5,1,1);
                end;
                setTextAlignment(RenderText.ALIGN_CENTER);
                renderText(x,y, 0.04, "."); -- Not exactly at the pixel-point, but close enough for debugging.
                setTextAlignment(RenderText.ALIGN_LEFT);
            end
        end;
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

    setTextAlignment(RenderText.ALIGN_LEFT);
    setTextBold(false);
    setTextColor(1,1,1,1);
end;

function FollowMe:debugDrawTrail()
    local spec = FollowMe.getSpec(self)

    local leader = spec.FollowVehicleObj
    local leaderSpec = FollowMe.getSpec(leader)

    local wpIdx = spec.FollowCurrentIndex
    local crumb1 = leaderSpec.DropperCircularArray[1+(wpIdx % FollowMe.cBreadcrumbsMaxEntries)];
    local crumb2
    while wpIdx < leaderSpec.DropperCurrentIndex do
        wpIdx = wpIdx + 1
        crumb2 = leaderSpec.DropperCircularArray[1+(wpIdx % FollowMe.cBreadcrumbsMaxEntries)];

        local x1,y1,z1 = unpack(crumb1.trans)
        local x2,y2,z2 = unpack(crumb2.trans)
        drawDebugLine(x1,y1+1,z1, 1,1,1, x2,y2+1,z2, 0,0,1, false)

        crumb1 = crumb2
    end
end

---
---
---

-- FollowMeRequestEvent = {};
-- FollowMeRequestEvent_mt = Class(FollowMeRequestEvent, Event);

-- InitEventClass(FollowMeRequestEvent, "FollowMeRequestEvent");

-- function FollowMeRequestEvent:emptyNew()
--     local self = Event:new(FollowMeRequestEvent_mt);
--     self.className = "FollowMeRequestEvent";
--     return self;
-- end;

-- function FollowMeRequestEvent:new(vehicle, cmdId, reason, farmId)
--     local self = FollowMeRequestEvent:emptyNew()
--     self.vehicle    = vehicle
--     self.farmId     = Utils.getNoNil(farmId, 0)
--     self.cmdId      = Utils.getNoNil(cmdId, 0)
--     self.reason     = Utils.getNoNil(reason, 0)
--     self.distance   = 0 --Utils.getNoNil(vehicle.modFM.FollowKeepBack, 0)
--     self.offset     = 0 --Utils.getNoNil(vehicle.modFM.FollowXOffset, 0)
--     return self;
-- end;

-- function FollowMeRequestEvent:writeStream(streamId, connection)
--     writeNetworkNodeObject(streamId, self.vehicle);
--     streamWriteUIntN(      streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
--     streamWriteUIntN(      streamId, self.cmdId,  FollowMe.NUM_BITS_COMMAND)
--     streamWriteUIntN(      streamId, self.reason, FollowMe.NUM_BITS_REASON)
--     streamWriteInt8(       streamId, self.distance)
--     streamWriteInt8(       streamId, self.offset * 2)
-- end;

-- function FollowMeRequestEvent:readStream(streamId, connection)
--     self.vehicle  = readNetworkNodeObject(streamId);
--     self.farmId   = streamReadUIntN(      streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
--     self.cmdId    = streamReadUIntN(      streamId, FollowMe.NUM_BITS_COMMAND)
--     self.reason   = streamReadUIntN(      streamId, FollowMe.NUM_BITS_REASON)
--     self.distance = streamReadInt8(       streamId)
--     self.offset   = streamReadInt8(       streamId) / 2

--     if nil ~= self.vehicle then
--         if     self.cmdId == FollowMe.COMMAND_START then
--             FollowMe.startFollowMe(self.vehicle, connection, self.farmId)
--         elseif self.cmdId == FollowMe.COMMAND_STOP then
--             FollowMe.stopFollowMe(self.vehicle, self.reason)
--         elseif self.cmdId == FollowMe.COMMAND_WAITRESUME then
--             FollowMe.waitResumeFollowMe(self.vehicle, self.reason)
--         else
--             FollowMe.changeDistance(self.vehicle, { self.distance } )
--             FollowMe.changeXOffset( self.vehicle, { self.offset } )
--         end
--     end;
-- end;


-- ---
-- ---
-- ---

-- FollowMeResponseEvent = {};
-- FollowMeResponseEvent_mt = Class(FollowMeResponseEvent, Event);

-- InitEventClass(FollowMeResponseEvent, "FollowMeResponseEvent");

-- function FollowMeResponseEvent:emptyNew()
--     local self = Event:new(FollowMeResponseEvent_mt);
--     self.className = "FollowMeResponseEvent";
--     return self;
-- end;

-- function FollowMeResponseEvent:new(vehicle, stateId, reason, helper, farmId)
--     local self = FollowMeResponseEvent:emptyNew()
--     self.vehicle            = vehicle
--     self.stateId            = Utils.getNoNil(stateId, 0)
--     self.reason             = Utils.getNoNil(reason, 0)
--     self.distance           = 0 --Utils.getNoNil(vehicle.modFM.FollowKeepBack, 0)
--     self.offset             = 0 --Utils.getNoNil(vehicle.modFM.FollowXOffset, 0)
--     self.helperIndex        = 0
--     if nil ~= helper then
--         self.helperIndex = helper.index
--     end
--     self.farmId             = Utils.getNoNil(farmId, 0)
--     self.followVehicleObj   = nil --vehicle.modFM.FollowVehicleObj
--     self.stalkerVehicleObj  = nil --vehicle.modFM.StalkerVehicleObj
--     return self;
-- end;

-- function FollowMeResponseEvent:writeStream(streamId, connection)
--     writeNetworkNodeObject(streamId, self.vehicle)
--     streamWriteUIntN(      streamId, self.stateId,  FollowMe.NUM_BITS_STATE)
--     streamWriteUIntN(      streamId, self.reason,   FollowMe.NUM_BITS_REASON)
--     streamWriteUIntN(      streamId, self.farmId,   FarmManager.FARM_ID_SEND_NUM_BITS)
--     streamWriteInt8(       streamId, self.distance)
--     streamWriteInt8(       streamId, self.offset * 2)
--     streamWriteUInt8(      streamId, self.helperIndex)
--     writeNetworkNodeObject(streamId, self.followVehicleObj )
--     writeNetworkNodeObject(streamId, self.stalkerVehicleObj)
-- end;

-- function FollowMeResponseEvent:readStream(streamId, connection)
--     self.vehicle            = readNetworkNodeObject(streamId)
--     self.stateId            = streamReadUIntN(      streamId, FollowMe.NUM_BITS_STATE)
--     self.reason             = streamReadUIntN(      streamId, FollowMe.NUM_BITS_REASON)
--     self.farmId             = streamReadUIntN(      streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
--     self.distance           = streamReadInt8(       streamId)
--     self.offset             = streamReadInt8(       streamId) / 2
--     self.helperIndex        = streamReadUInt8(      streamId)
--     self.followVehicleObj   = readNetworkNodeObject(streamId)
--     self.stalkerVehicleObj  = readNetworkNodeObject(streamId)

--     if nil ~= self.vehicle then
--         if 0 == self.helperIndex then
--             self.helperIndex = nil
--         end

--         FollowMe.changeDistance(self.vehicle, { self.distance } ,true )
--         FollowMe.changeXOffset( self.vehicle, { self.offset }   ,true )

--         if     self.stateId == FollowMe.STATE_STARTING then
--             FollowMe.onStartFollowMe(self.vehicle, self.followVehicleObj, self.helperIndex, true, self.farmId)
--         elseif self.stateId == FollowMe.STATE_STOPPING then
--             FollowMe.onStopFollowMe(self.vehicle, self.reason, true)
--         else
--             if self.reason ~= 0 then
--                 FollowMe.showReason(self.vehicle, nil, self.reason, nil)
--             end
--             --self.vehicle.modFM.FollowState       = self.stateId
--             --self.vehicle.modFM.FollowVehicleObj  = self.followVehicleObj
--             --self.vehicle.modFM.StalkerVehicleObj = self.stalkerVehicleObj
--         end
--     end;
-- end;

--
print(("Script loaded: FollowMe.lua - from %s (v%s)"):format(g_currentModName, g_modManager:getModByName(g_currentModName).version));
