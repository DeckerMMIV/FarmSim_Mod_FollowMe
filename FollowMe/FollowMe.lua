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
local modSpecTypeName = g_currentModName ..".".. specTypeName
function FollowMe.getSpec(self)
  return self["spec_" .. modSpecTypeName] -- Work-around... while waiting for some better published LUADOCs from GIANTS Software...
end

--
--FollowMe.wagePaymentMultiplier = 0.2

--
FollowMe.cMinDistanceBetweenDrops        =   5;   -- TODO, make configurable
FollowMe.cBreadcrumbsMaxEntries          = 150;   -- TODO, make configurable
FollowMe.cMstimeBetweenDrops             =  40;   -- TODO, make configurable
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
      and false == SpecializationUtil.hasSpecialization(ConveyorBelt  ,specializations)
      and false == SpecializationUtil.hasSpecialization(Locomotive    ,specializations)
end

function FollowMe.registerFunctions(vehicleType)
  for _,funcName in pairs( { "getIsFollowMeActive" } ) do
    SpecializationUtil.registerFunction(vehicleType, funcName, FollowMe[funcName])
  end
end

function FollowMe.registerEventListeners(vehicleType)
  --log("FollowMe.registerEventListeners() ",vehicleType)
  for _,funcName in pairs( {
    "onDraw",
    "onLoad",
    "onUpdate",
    "onUpdateTick",
    "onRegisterActionEvents",
    "onReadStream", "onWriteStream",
    --"onEnterVehicle", "onLeaveVehicle",
  } ) do
    SpecializationUtil.registerEventListener(vehicleType, funcName, FollowMe)
  end
end

-- function FollowMe.initialize()
--     if FollowMe.isInitialized then
--         return;
--     end;
--     FollowMe.isInitialized = true;

--     -- FollowMe.showMouse = false
--     -- FollowMe.cursorXYZ = {0,0,0}
-- end;

--
--
--

function FollowMe:onLoad(savegame)
    --log("FollowMe:onLoad()")
    --FollowMe.initialize();

    local spec = FollowMe.getSpec(self)
    spec.actionEvents = {}

    --
    self.getIsFollowMeActive  = FollowMe.getIsFollowMeActive
    --self.getDeactivateOnLeave = Utils.overwrittenFunction(self.getDeactivateOnLeave, FollowMe.getDeactivateOnLeave);

    self.followMeIsStarted = false

    -- A simple attempt at making a "namespace" for 'Follow Me' variables.
    --self.modFM = {};  -- TODO: Change to use the 'spec_<modName>.FollowMe' thingy...
    --
    spec.IsInstalled = true;  -- TODO. Make 'FollowMe' a buyable add-on! This is expensive equipment ;-)
    --
    spec.sumSpeed = 0;
    spec.sumCount = 0;
    spec.DropperCircularArray = {};
    spec.DropperCurrentIndex = -1;
    spec.StalkerVehicleObj = nil;  -- Needed in case self is being deleted.
    --
    spec.FollowState = FollowMe.STATE_NONE;
    spec.FollowVehicleObj = nil;  -- What vehicle is this one following (if any)
    spec.FollowCurrentIndex = -1;
    spec.FollowKeepBack = 20;
    spec.FollowXOffset = 0;
    spec.ToggleXOffset = 0;
    --
    spec.reduceSpeedTime = 0;
    spec.lastAcceleration  = 0;
    spec.lastLastSpeedReal = 0;
    --
    spec.ShowWarningText = nil;
    spec.ShowWarningTime = 0;
    --
    spec.currentHelper = nil
    spec.startedFarmId = 0
    --
    spec.isDirty = false;
    spec.delayDirty = nil;
    --
    if self.isServer then
      if nil ~= self.spec_aiVehicle then
        if nil == self.spec_aiVehicle.pricePerMS then
            -- Copied from AIVehicle
            self.spec_aiVehicle.pricePerMS = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.ai.pricePerHour"), 2000)/60/60/1000;
        end
      end
    end;

    --
    if nil ~= savegame and not savegame.resetVehicles then
        local distance = getXMLFloat(savegame.xmlFile, savegame.key .. ".followMe#backDist")
        if nil ~= distance then
            FollowMe.changeDistance(self, { distance }, true ); -- Absolute change
        end
        local offset = getXMLFloat(savegame.xmlFile, savegame.key .. ".followMe#sideOffs")
        if nil ~= offset then
            FollowMe.changeXOffset(self, { offset }, true ); -- Absolute change
        end
    end
end;

function FollowMe:getSaveAttributesAndNodes(nodeIdent)
  local spec = FollowMe.getSpec(self)
  local attributes, nodes
  if nil ~= spec then
      nodes = nodeIdent .. ('<followMe backDist="%.0f" sideOffs="%.1f" />'):format(spec.FollowKeepBack, spec.FollowXOffset)
  end
  return attributes, nodes;
end;

function FollowMe:delete()
    local spec = FollowMe.getSpec(self)
    if nil ~= spec.StalkerVehicleObj then
        -- Stop the stalker-vehicle
        FollowMe.onStopFollowMe(spec.StalkerVehicleObj, FollowMe.REASON_LEADER_REMOVED, true);
    end;
    if nil ~= spec.FollowVehicleObj then
        -- Stop ourself
        FollowMe.onStopFollowMe(self, FollowMe.REASON_NONE, true);
    end
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

-- AIVehicle.getCanStartAIVehicle = Utils.overwrittenFunction(AIVehicle.getCanStartAIVehicle, function(self, superFunc)
--   if FollowMe.getIsFollowMeActive(self) then
--     return false
--   end
--   return superFunc(self)
-- end)


function FollowMe:onWriteStream(streamId, connection)
    local spec = FollowMe.getSpec(self)
    streamWriteInt8(streamId, Utils.getNoNil(spec.FollowKeepBack, 0))
    streamWriteInt8(streamId, Utils.getNoNil(spec.FollowXOffset,  0) * 2)
    if streamWriteBool(streamId, self.followMeIsStarted) then
        streamWriteUIntN(streamId, spec.FollowState,   FollowMe.NUM_BITS_STATE)
        streamWriteUIntN(streamId, spec.startedFarmId, FarmManager.FARM_ID_SEND_NUM_BITS)
        streamWriteUInt8(streamId, spec.currentHelper.index)
        writeNetworkNodeObject(streamId, spec.FollowVehicleObj)
    end
end;

function FollowMe:onReadStream(streamId, connection)
    local distance  = streamReadInt8(streamId)
    local offset    = streamReadInt8(streamId) / 2
    if streamReadBool(streamId) then
        local state         = streamReadUIntN(       streamId, FollowMe.NUM_BITS_STATE)
        local farmId        = streamReadUIntN(       streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
        local helperIndex   = streamReadUInt8(       streamId)
        local followObj     = readNetworkNodeObject( streamId)

        FollowMe.onStartFollowMe(self, followObj, helperIndex, true, farmId);

        local spec = FollowMe.getSpec(self)
        spec.FollowState = state;
    end

    FollowMe.changeDistance(self, { distance }, true ); -- Absolute change
    FollowMe.changeXOffset( self, { offset },   true ); -- Absolute change
end;


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
            local vRX,vRY,vRZ   = localDirectionToWorld(cNode, 0,0,Utils.getNoNil(self.reverserDirection, 1))
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

-- function FollowMe:keyEvent(unicode, sym, modifier, isDown)
-- end;

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

    --local node        = FollowMe.getFollowNode(self)
    local node = self:getAIVehicleSteeringNode()
    --local vX,vY,vZ    = getWorldTranslation(node);
    --local vrX,vrY,vrZ = localDirectionToWorld(node, 0,0, Utils.getNoNil(reverserDirection, 1));

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

function FollowMe:toggleXOffset(withZero, noSendEvent)
    local spec = FollowMe.getSpec(self)
    if true == withZero then
        if 0 == spec.FollowXOffset and 0 ~= spec.ToggleXOffset then
            spec.FollowXOffset = spec.ToggleXOffset
            spec.ToggleXOffset = 0;
        elseif 0 ~= spec.FollowXOffset then
            spec.ToggleXOffset = spec.FollowXOffset
            spec.FollowXOffset = 0;
        end
        if not noSendEvent then
            spec.delayDirty = g_currentMission.time + 750;
        end;
    else
        FollowMe.changeXOffset(self, { -spec.FollowXOffset }, noSendEvent) -- Absolute change
    end
end

--[[
--
FollowMe.InputEvents = {}
FollowMe.INPUTEVENT_MILLISECONDS = 500
FollowMe.INPUTEVENT_NONE    = 0
FollowMe.INPUTEVENT_SHORT   = 1 -- Key-action was pressed/released quickly
FollowMe.INPUTEVENT_LONG    = 2 -- Key-action was pressed/hold for longer
FollowMe.INPUTEVENT_REPEAT  = 3 -- Key-action is still pressed/hold for much longer

function FollowMe.hasEventShortLong(inBinding, repeatIntervalMS)
    local isPressed = InputBinding.isPressed(inBinding);
    -- If no previous input-event for this binding...
    if not FollowMe.InputEvents[inBinding] then
        -- ...and it is now pressed down, then remember the time of initiation.
        if isPressed then
            FollowMe.InputEvents[inBinding] = g_currentMission.time;
        end
        return FollowMe.INPUTEVENT_NONE; -- Not pressed or Can not determine.
    end;
    -- For how long have this input-event been hold down?
    local timeDiff = g_currentMission.time - FollowMe.InputEvents[inBinding];
    if not isPressed then
        FollowMe.InputEvents[inBinding] = nil;
        if timeDiff > 0 and timeDiff < FollowMe.INPUTEVENT_MILLISECONDS then
            return FollowMe.INPUTEVENT_SHORT; -- Short press
        end
        return FollowMe.INPUTEVENT_NONE; -- It was probably a long event, which has already been processed.
    elseif timeDiff > FollowMe.INPUTEVENT_MILLISECONDS then
        FollowMe.InputEvents[inBinding] = g_currentMission.time + 10000000;
        if nil ~= repeatIntervalMS then
            return FollowMe.INPUTEVENT_REPEAT; -- Long-and-repeating press
        end
        return FollowMe.INPUTEVENT_LONG; -- Long press
    elseif timeDiff < 0 then
        if nil ~= repeatIntervalMS and (timeDiff + 10000000) > repeatIntervalMS then
            FollowMe.InputEvents[inBinding] = g_currentMission.time + 10000000;
            return FollowMe.INPUTEVENT_REPEAT; -- Long-and-repeating press
        end;
    end;
    return FollowMe.INPUTEVENT_NONE; -- Not released
end;
--]]


function FollowMe:handleAction(actionName, inputValue, callbackState, isAnalog, isMouse)
    log("FollowMe:handleAction ",actionName," ",inputValue," ",callbackState," ",isAnalog," ",isMouse)
    local spec = FollowMe.getSpec(self)
    local stalker = spec.StalkerVehicleObj;
    local switch = {
        FollowMeMyToggle = function()
            if FollowMe.getIsFollowMeActive(self) then
                FollowMe.stopFollowMe(self, FollowMe.REASON_USER_ACTION);
            elseif g_currentMission:getHasPlayerPermission("hireAI") then
              if FollowMe.getCanStartFollowMe(self) then
                FollowMe.startFollowMe(self, nil, g_currentMission.player.farmId);
              end
            else
                -- No permission
            end
        end
        ,FollowMeMyPause   = function() FollowMe.waitResumeFollowMe(self, FollowMe.REASON_USER_ACTION); end
        ,FollowMeMyDistDec = function() FollowMe.changeDistance(self, -5); end
        ,FollowMeMyDistInc = function() FollowMe.changeDistance(self, 5); end
        ,FollowMeMyOffsDec = function() FollowMe.changeXOffset(self, -0.5); end
        ,FollowMeMyOffsInc = function() FollowMe.changeXOffset(self, 0.5); end
        ,FollowMeMyOffsTgl = function() FollowMe.toggleXOffset(self, true); end

        ,FollowMeFlStop = function()
            if FollowMe.getIsFollowMeActive(stalker) then
                FollowMe.stopFollowMe(stalker, FollowMe.REASON_USER_ACTION);
            end
        end
        ,FollowMeFlPause   = function() FollowMe.waitResumeFollowMe(stalker, FollowMe.REASON_USER_ACTION); end
        ,FollowMeFlDistDec = function() FollowMe.changeDistance(stalker, -5); end
        ,FollowMeFlDistInc = function() FollowMe.changeDistance(stalker, 5); end
        ,FollowMeFlOffsDec = function() FollowMe.changeXOffset(stalker, -0.5); end
        ,FollowMeFlOffsInc = function() FollowMe.changeXOffset(stalker, 0.5); end
        ,FollowMeFlOffsTgl = function() FollowMe.toggleXOffset(stalker, true); end
    }
    local action = switch[actionName]
    if action then
        action()
    else
      log("Not found action: ",actionName)
    end
end


function FollowMe:onRegisterActionEvents(isSelected, isOnActiveVehicle)
    --log("FollowMe:onRegisterActionEvents(",self,") ",isSelected," ",isOnActiveVehicle)
    --Actions are only relevant if the function is run clientside
    if not self.isClient then
      return
    end

    local spec = FollowMe.getSpec(self)
    self:clearActionEventsTable(spec.actionEvents)

    local function addActionEvents(tbl)
      for _,actionName in pairs(tbl) do
        local succ, eventID, colli = self:addActionEvent(spec.actionEvents, actionName, self, FollowMe.handleAction, false, true, false, true, nil)
        --g_inputBinding:setActionEventText(eventID, "..todo..")
        g_inputBinding:setActionEventTextVisibility(eventID, true)
      end
    end

    --local activeForInput = self:getIsEntered() and not g_currentMission.isPlayerFrozen and not g_gui:getIsGuiVisible();
    local activeForInput = self:getIsActiveForInput(true) and not self.isConveyorBelt
    local isFollowMeActive = FollowMe.getIsFollowMeActive(self)
    --log("FollowMe:onRegisterActionEvents(",self,") activeForInput=",activeForInput)
    if activeForInput or isFollowMeActive then
      addActionEvents( { InputAction.FollowMeMyToggle } )
      if isFollowMeActive then
        addActionEvents( { InputAction.FollowMeMyPause, InputAction.FollowMeMyDistDec, InputAction.FollowMeMyDistInc, InputAction.FollowMeMyOffsDec, InputAction.FollowMeMyOffsInc, InputAction.FollowMeMyOffsTgl } )
      end
      -- local actionsMy = { InputAction.FollowMeMyToggle, InputAction.FollowMeMyPause, InputAction.FollowMeMyDistDec, InputAction.FollowMeMyDistInc, InputAction.FollowMeMyOffsDec, InputAction.FollowMeMyOffsInc, InputAction.FollowMeMyOffsTgl }
      -- for _,actionName in pairs(actionsMy) do
      --   local succ, eventID, colli = self:addActionEvent(spec.actionEvents, actionName, self, FollowMe.handleAction, false, true, false, true, nil)
      --   g_inputBinding:setActionEventTextVisibility(eventID, false)
      -- end
    end
    if (activeForInput or isFollowMeActive) and nil ~= spec.StalkerVehicleObj then
      addActionEvents( { InputAction.FollowMeFlStop, InputAction.FollowMeFlPause, InputAction.FollowMeFlDistDec, InputAction.FollowMeFlDistInc, InputAction.FollowMeFlOffsDec, InputAction.FollowMeFlOffsInc, InputAction.FollowMeFlOffsTgl } )
      -- local actionsFl = { InputAction.FollowMeFlStop,   InputAction.FollowMeFlPause, InputAction.FollowMeFlDistDec, InputAction.FollowMeFlDistInc, InputAction.FollowMeFlOffsDec, InputAction.FollowMeFlOffsInc, InputAction.FollowMeFlOffsTgl }
      -- for _,actionName in pairs(actionsFl) do
      --   local succ, eventID, colli = self:addActionEvent(spec.actionEvents, actionName, self, FollowMe.handleAction, false, true, false, true, nil)
      --   g_inputBinding:setActionEventTextVisibility(eventID, false)
      -- end
    end
end
--
function FollowMe:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    -- if FollowMe.getIsFollowMeActive(self) then
    --     -- self.forceIsActive = true;
    --     -- self.steeringEnabled = false;
    --     -- self.spec_motorized.stopMotorOnLeave  = false
    --     -- self.spec_drivable.allowPlayerControl = false

    --     -- self:raiseActive()
    -- end
end;

function FollowMe:onUpdateTick(dt, isActiveForInput, isSelected)
    local spec = FollowMe.getSpec(self)

    if self.isServer and nil ~= spec then
        if FollowMe.getIsFollowMeActive(self) and nil ~= spec.FollowVehicleObj then
            -- -- Have leading vehicle to follow.
            -- local turnLightState, trailStrength = FollowMe.updateFollowMovement(self, dt);
            -- if trailStrength < 0.2 then
            --     -- Loosing trail
            --     spec.trailStrength = trailStrength * 100
            -- else
            --     spec.trailStrength = nil
            -- end

            -- if nil ~= spec.FollowVehicleObj and nil ~= self.spec_lights and nil ~= self.spec_lights.setBeaconLightsVisibility then
            --     -- Simon says: Lights!
            --     self.spec_lights:setLightsTypesMask(       spec.FollowVehicleObj.spec_lights:getLightsTypesMask() or 0);
            --     self.spec_lights:setBeaconLightsVisibility(spec.FollowVehicleObj.spec_lights:getBeaconLightsVisibility() or false);
            --     -- ...and Garfunkel follows up with turn-signals
            --     if nil ~= turnLightState then
            --         self.spec_lights:setTurnLightState(turnLightState)
            --     end
            -- end

            -- --if nil ~= spec.startedFarmId then
            --   local price = (-dt * self.spec_aiVehicle.pricePerMS * g_currentMission.missionInfo.buyPriceMultiplier) * FollowMe.wagePaymentMultiplier
            --   g_currentMission:addMoney(      price, spec.startedFarmId, "wagePayment");
            --   g_currentMission:addMoneyChange(price, spec.startedFarmId, MoneyType.AI)
            -- --end
        elseif (Utils.getNoNil(self.reverserDirection, 1) * self.movingDirection > 0) then  -- Must drive forward to drop crumbs
            spec.sumSpeed = spec.sumSpeed + self.lastSpeed;
            spec.sumCount = spec.sumCount + 1;
            --
            local distancePrevDrop
            if -1 < spec.DropperCurrentIndex then
              local node = self:getAIVehicleSteeringNode() -- FollowMe.getFollowNode(self)
              local vX,vY,vZ = getWorldTranslation(node) -- current position
              local oX,oY,oZ = unpack(spec.DropperCircularArray[1+(spec.DropperCurrentIndex % FollowMe.cBreadcrumbsMaxEntries)].trans); -- old position
              distancePrevDrop = MathUtil.vector2LengthSq(oX - vX, oZ - vZ);
            else
              distancePrevDrop = FollowMe.cMinDistanceBetweenDrops
            end
            if distancePrevDrop >= FollowMe.cMinDistanceBetweenDrops then
                local maxSpeed = math.max(5, (spec.sumSpeed / spec.sumCount) * 3600)
                FollowMe.addDrop(self, maxSpeed, self.turnLightState, self.reverserDirection);
                --
                spec.sumSpeed = 0;
                spec.sumCount = 0;
            end;
        end;
    end;

    --FollowMe.sendUpdate(self);
end;

function FollowMe.sendUpdate(self)
    local spec = FollowMe.getSpec(self)

    if spec.isDirty
    or (nil ~= spec.delayDirty and spec.delayDirty < g_currentMission.time)
    then
        spec.isDirty = false;
        spec.delayDirty = nil;
        --
        if nil == g_server then
            -- Client - Send "distance/offset update" to server
            g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_NONE, FollowMe.REASON_NONE, nil));
        else
            -- Server only
            g_server:broadcastEvent(FollowMeResponseEvent:new(self, spec.FollowState, FollowMe.REASON_NONE, spec.currentHelper), nil, nil, self);
        end
    end;
end;

-- -- Hack'ish covert attempt, at _avoiding_ AIVehicle.updateAIDriveStrategies() to create any 'driveStrategies'.
-- -- This "hack" is part of tRYing to get `self:getIsAIActive()` to return true, when FollowMe is active, but without
-- -- anything actually happening in AIVehicle.onUpdate and .onUpdateTick
-- AIVehicle.updateAIImplementData = Utils.overwrittenFunction(AIVehicle.updateAIImplementData, function(self, superFunc)
--   if FollowMe.getIsFollowMeActive(self) then
--     self.spec_aiVehicle.aiImplementList = {}
--   else
--     superFunc(self)
--   end
-- end)

-- -- Hack'ish attempt at, when FollowMe is active, then disable the 'TOGGLE_AI' event that is tested for in the AIVehicle.onUpdateTick method
-- AIVehicle.onUpdateTick = Utils.appendedFunction(AIVehicle.onUpdateTick, function(self, superFunc, dt, isActiveForInput, isSelected)
--   if self.isClient then
--     if FollowMe.getIsFollowMeActive(self) then
--       local actionEvent = self.spec_aiVehicle.actionEvents[InputAction.TOGGLE_AI]
--       if nil ~= actionEvent then
--         g_inputBinding:setActionEventActive(actionEvent.actionEventId, false)
--       end
--     end
--   end
-- end)


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
                --FollowMe.onStartFollowMe(self, closestVehicle, nil, nil, startedFarmId);

                self:startAIVehicle(nil, nil, startedFarmId, AIVehicle.FORCED_DRIVING_STRATEGY_1)
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
        --FollowMe.onStopFollowMe(self, reason);
        self:stopAIVehicle(nil, nil)
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
    vehicle.followMeIsStarted = false

    vehicle.spec_aiVehicle.modFM_doCheckSpeedLimitOnlyIfWorking = nil

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

      vehicle.spec_aiVehicle.modFM_doCheckSpeedLimitOnlyIfWorking = true  -- A work-around, for forcing AIVehicle:onUpdateTick() making its call to `self:getSpeedLimit()` into a `self:getSpeedLimit(true)`
    else
      vehicleSpec.FollowVehicleObj = nil
      vehicle.followMeIsStarted = false
    end
end

function AIDriveStrategyFollow:update(dt)
    --log("AIDriveStrategyFollow:update ",dt)
end

function AIDriveStrategyFollow:getDriveData(dt, vX, vY, vZ)
    --log("AIDriveStrategyFollow:getDriveData ",dt," ",vX," ",vY," ",vZ)

    local vehicle = self.vehicle
    local vehicleSpec = FollowMe.getSpec(vehicle)

    if nil == vehicleSpec.FollowVehicleObj then
      vehicle:stopAIVehicle(AIVehicle.STOP_REASON_UNKOWN);
      return nil,nil,nil,nil,nil
    end

    --
    local leader = vehicleSpec.FollowVehicleObj;
    local leaderSpec = FollowMe.getSpec(leader)
    -- actual target
    local tX,tY,tZ;
    --
    local isAllowedToDrive = (FollowMe.STATE_WAITING ~= vehicleSpec.FollowState)
    local distanceToStop = 10
    --local acceleration = 1.0
    local maxSpeed = 0
    --
    local crumbIndexDiff = leaderSpec.DropperCurrentIndex - vehicleSpec.FollowCurrentIndex;
    --
    if crumbIndexDiff >= FollowMe.cBreadcrumbsMaxEntries then
        -- circular-array have "circled" once, and this follower did not move fast enough.
        if vehicleSpec.FollowState ~= FollowMe.STATE_STOPPING then
            --FollowMe.stopFollowMe(vehicle, FollowMe.REASON_TOO_FAR_BEHIND);
            vehicle:stopAIVehicle(AIVehicle.STOP_REASON_UNKOWN);
            return nil,nil,nil,nil,nil
        end

        --trailStrength = 0.0
        --hasCollision = true
        isAllowedToDrive = false
        --acceleration = 0.0

        -- vehicle rotation
        local vRX,vRY,vRZ   = localDirectionToWorld(vehicle:getAIVehicleSteeringNode(), 0,0,Utils.getNoNil(vehicle.reverserDirection, 1));

        -- Set target 2 meters straight ahead of vehicle.
        tX = vX + vRX * 2;
        tY = vY;
        tZ = vZ + vRZ * 2;
    elseif crumbIndexDiff > 0 then
        --trailStrength = 1.0 - (crumbIndexDiff / FollowMe.cBreadcrumbsMaxEntries)

        -- Following crumbs...
        local crumbT = leaderSpec.DropperCircularArray[1+(vehicleSpec.FollowCurrentIndex % FollowMe.cBreadcrumbsMaxEntries)];
        maxSpeed = crumbT.maxSpeed;
        --turnLightState = crumbT.turnLightState
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
        --
        if (tDist < (FollowMe.cMinDistanceBetweenDrops / 2)) -- close enough to crumb?
        or (nz < 0) -- in front of crumb?
        then
            FollowMe.copyDrop(vehicle, crumbT, (vehicleSpec.FollowXOffset == 0) and nil or {tX,tY,tZ});
            -- Go to next crumb
            vehicleSpec.FollowCurrentIndex = vehicleSpec.FollowCurrentIndex + 1;
            crumbIndexDiff = leaderSpec.DropperCurrentIndex - vehicleSpec.FollowCurrentIndex;
        end;
        --
        if crumbIndexDiff > 0 then
            -- Still following crumbs...
            --maxSpeed = crumbT.maxSpeed;
            local crumbN = leaderSpec.DropperCircularArray[1+((vehicleSpec.FollowCurrentIndex+1) % FollowMe.cBreadcrumbsMaxEntries)];
            if nil ~= crumbN then
                -- Apply offset, to next original target
                local ntX = crumbN.trans[1] - crumbN.rot[3] * vehicleSpec.FollowXOffset;
                local ntZ = crumbN.trans[3] + crumbN.rot[1] * vehicleSpec.FollowXOffset;
                local pct = math.max(1 - (tDist / FollowMe.cMinDistanceBetweenDrops), 0);
                tX,_,tZ = MathUtil.vector3ArrayLerp( {tX,0,tZ}, {ntX,0,ntZ}, pct);
                maxSpeed = (maxSpeed + crumbN.maxSpeed) / 2;
            end;
            --
            local keepBackMeters = FollowMe.getKeepBack(vehicle) --, math.max(0, self.lastSpeed) * 3600);
            local distCrumbs   = math.floor(keepBackMeters / FollowMe.cMinDistanceBetweenDrops);
            local distFraction = keepBackMeters - (distCrumbs * FollowMe.cMinDistanceBetweenDrops);

            isAllowedToDrive = isAllowedToDrive and not (crumbIndexDiff < distCrumbs); -- Too far ahead?

            if isAllowedToDrive then
                if (crumbIndexDiff > distCrumbs) then
                  distanceToStop = ((crumbIndexDiff - distCrumbs) * FollowMe.cMinDistanceBetweenDrops) + FollowMe.getKeepFront(vehicle)
                    --local lastSpeedKMH = (vehicle.lastSpeed * 3600)
                    --if true == vehicle.mrIsMrVehicle and lastSpeedKMH > 5 then
                    --    -- Don't allow MR vehicle to 'speed up to catch up', as it may fall over when cornering at higher speeds
                    --    local diffSpeedKMH = (lastSpeedKMH - maxSpeed)
                    --    if diffSpeedKMH > 1 then
                    --        -- Apply brake if going faster than allowed
                    --        --acceleration = MathUtil.lerp(0, -1, math.sin(math.min(diffSpeedKMH-1, math.pi/2)))
                    --    end
                    --else
                        maxSpeed = maxSpeed + maxSpeed * (math.min(5, (crumbIndexDiff - distCrumbs)) / 5)
                    --end
                elseif FollowMe.getKeepFront(vehicle) <= 0 then
                  distanceToStop = math.max(0, tDist - distFraction)
                --elseif not ((crumbIndexDiff == distCrumbs) and (tDist >= distFraction)) then
                --    maxSpeed = 0
                --else
                --    maxSpeed = maxSpeed * 2
                end
            end
        end;
    end;
    --
    if crumbIndexDiff <= 0 then
        -- Following leader directly...
        --turnLightState = leader.spec_lights:getTurnLightState()

        local lNode         = leader:getAIVehicleSteeringNode() --FollowMe.getFollowNode(leader)
        local lx,ly,lz      = getWorldTranslation(lNode);
        local lrx,lry,lrz   = localDirectionToWorld(lNode, 0,0,Utils.getNoNil(leader.reverserDirection, 1));

        -- leader-target adjust with offset
        local keepInFrontMeters = FollowMe.getKeepFront(vehicle);
        tX = lx - lrz * vehicleSpec.FollowXOffset + lrx * keepInFrontMeters;
        tY = ly
        tZ = lz + lrx * vehicleSpec.FollowXOffset + lrz * keepInFrontMeters;

        -- Rotate to see if the target is still "in front of us"
        local dx,dz = tX - vX, tZ - vZ;
        local trAngle = math.atan2(lrx,lrz);
        local nz = dx * math.sin(trAngle) + dz * math.cos(trAngle);

        maxSpeed = math.max(5, leader.lastSpeed * 3600); -- only consider forward movement.
        distanceToStop = MathUtil.vector2Length(dx,dz) - FollowMe.getKeepBack(vehicle);
        isAllowedToDrive = isAllowedToDrive and (nz > 0) and (distanceToStop > 0)
    end;

    if (not isAllowedToDrive) or (maxSpeed < 0.5) then
      maxSpeed = 0
    end
    distanceToStop = math.floor(distanceToStop)

    -- if self.lastDistToStop ~= distanceToStop then
    --   log("maxSpeed:",maxSpeed," distToStop:",distanceToStop)
    --   self.lastDistToStop = distanceToStop
    -- end

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

function FollowMe.acquireHelper(helperIndex)
    local helperObj
    if nil ~= helperIndex and helperIndex >= 1 and helperIndex <= table.getn(g_helperManager.indexToHelper) then
        helperObj = g_helperManager.indexToHelper[helperIndex]
    else
        helperObj = g_helperManager:getRandomHelper()
    end

    g_helperManager:useHelper(helperObj)

    return helperObj
end

function FollowMe.releaseHelper(helperObj)
    if nil ~= helperObj then
        g_helperManager:releaseHelper(helperObj)
    end
    return nil
end

function FollowMe:activateHotspot()
  local spec = FollowMe.getSpec(self)

  local _, textSize    = getNormalizedScreenValues(0, 9)
  local _, textOffsetY = getNormalizedScreenValues(0, 18)
  local width, height  = getNormalizedScreenValues(24, 24)
  spec.mapAIHotspot = MapHotspot:new("helper", MapHotspot.CATEGORY_AI)
  spec.mapAIHotspot:setSize(width, height)
  spec.mapAIHotspot:setLinkedNode(FollowMe.getFollowNode(self))
  if nil ~= spec.currentHelper and nil ~= spec.currentHelper.name then
    spec.mapAIHotspot:setText(spec.currentHelper.name)
  end
  spec.mapAIHotspot:setImage(nil, getNormalizedUVs(MapHotspot.UV.HELPER), {0.052, 0.1248, 0.672, 1})
  spec.mapAIHotspot:setBackgroundImage(nil, getNormalizedUVs(MapHotspot.UV.HELPER))
  spec.mapAIHotspot:setIconScale(0.7)
  spec.mapAIHotspot:setTextOptions(textSize, nil, textOffsetY, {1, 1, 1, 1}, Overlay.ALIGN_VERTICAL_MIDDLE)
  g_currentMission:addMapHotspot(spec.mapAIHotspot)
end

function FollowMe:deactivateHotspot()
  local spec = FollowMe.getSpec(self)
  if nil ~= spec.mapAIHotspot then
    g_currentMission:removeMapHotspot(spec.mapAIHotspot)
    spec.mapAIHotspot:delete()
    spec.mapAIHotspot = nil
  end
end

function FollowMe:onStartFollowMe(leader, helperIndex, noEventSend, startedFarmId)
    log("onStartFollowMe(leader=",leader,", helperIndex=",helperIndex,")")

    if not FollowMe.getIsFollowMeActive(self) and nil ~= leader then
        local spec = FollowMe.getSpec(self)

        self.followMeIsStarted = true;

        spec.currentHelper = FollowMe.acquireHelper(helperIndex)
        spec.startedFarmId = startedFarmId

        --
        local leaderSpec = FollowMe.getSpec(leader)
        leaderSpec.StalkerVehicleObj = self

        spec.FollowVehicleObj = followObj
        spec.FollowState = FollowMe.STATE_FOLLOWING

        if true ~= noEventSend and nil ~= g_server then
            g_server:broadcastEvent(FollowMeResponseEvent:new(self, FollowMe.STATE_STARTING, FollowMe.REASON_NONE, spec.currentHelper, spec.startedFarmId), nil, nil, self);
        end

        --self.isHirableBlocked = false;
        --self.forceIsActive = true;
        self.steeringEnabled = false;
        self.spec_motorized.stopMotorOnLeave  = false
        self.spec_drivable.allowPlayerControl = false

        -- self.spec_enterable.disableCharacterOnLeave = false
        -- if nil ~= self.spec_enterable:getVehicleCharacter() then
        --     self.spec_enterable:deleteVehicleCharacter()
        -- end
        -- if nil ~= spec.currentHelper then
        --     self.spec_enterable:setRandomVehicleCharacter()
        --     if not self.spec_enterable.isEntered then
        --         if nil ~= self.spec_enterable.enterAnimation and nil ~= self.spec_enterable.playAnimation then
        --             self:playAnimation(self.spec_enterable.enterAnimation, 1, nil, true)
        --         end
        --     end
        -- end

        FollowMe.activateHotspot(self)

        --
        self.spec_aiVehicle.isActive = true
        self:requestActionEventUpdate()
    end
end

function FollowMe:onStopFollowMe(reason, noEventSend)
    log("FollowMe:onStopFollowMe() ",reason)
    if FollowMe.getIsFollowMeActive(self) then
        local spec = FollowMe.getSpec(self)

        self.spec_aiVehicle.isActive = false

        self.followMeIsStarted = false;

        if nil ~= spec.FollowVehicleObj then
          local leaderSpec = FollowMe.getSpec(spec.FollowVehicleObj)
          leaderSpec.StalkerVehicleObj = nil
        end
        spec.FollowVehicleObj = nil
        spec.FollowState = FollowMe.STATE_NONE

        if true ~= noEventSend and nil ~= g_server then
            log("g_server:broadcastEvent")
            g_server:broadcastEvent(FollowMeResponseEvent:new(self, FollowMe.STATE_STOPPING, reason, spec.currentHelper, 0), nil, nil, self);
        end

        FollowMe.showReason(self, nil, reason, spec.currentHelper)

        spec.currentHelper = FollowMe.releaseHelper(spec.currentHelper)

        --self.forceIsActive = false;
        --self.steeringEnabled = true;
        self.spec_motorized.stopMotorOnLeave  = true
        self.spec_drivable.allowPlayerControl = true

        self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF, true);

        -- self.spec_enterable.disableCharacterOnLeave = true

        -- -- Remove helper-character
        -- if nil ~= self.spec_enterable:getVehicleCharacter() then
        --   self.spec_enterable:deleteVehicleCharacter()
        -- end

        -- if self.spec_enterable.isEntered or self.spec_enterable.isControlled then
        --     -- if nil ~= self.spec_enterable.vehicleCharacter then
        --     --     log("self.spec_enterable:setVehicleCharacter")
        --     --     --g_gameSettings:getValue("playerIndex")
        --     --     --g_gameSettings:getValue("playerColorIndex")
        --     --     self.spec_enterable:setVehicleCharacter(g_playerModelManager:getPlayerModelByIndex(self.playerIndex).filename, self.playerColorIndex)
        --     --     self.spec_enterable.vehicleCharacter:setCharacterVisibility(not self.spec_enterable.isEntered)
        --     -- end

        --     -- Add player-character
        --     local playerModel = g_playerModelManager:getPlayerModelByIndex(self.spec_enterable.playerStyle.selectedModelIndex)
        --     self:setVehicleCharacter(playerModel.xmlFilename, self.spec_enterable.playerStyle)
        --     -- if self.spec_enterable.enterAnimation ~= nil and self.playAnimation ~= nil then
        --     --     self:playAnimation(self.spec_enterable.enterAnimation, 1, nil, true)
        --     -- end
        -- end;

        FollowMe.deactivateHotspot(self)

        if self.isServer then
            --log("WheelsUtil.updateWheelsPhysics")
            WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeedReal, 0, true, self.requiredDriveMode);
        end

        -- TODO - does a g_gameSettings:getValue() exist for 'automaticMotorStartEnabled'?
        if self.isServer and g_currentMission.missionInfo.automaticMotorStartEnabled and not (self.spec_enterable.isEntered or self.spec_enterable.isControlled) then
            --log("self:stopMotor")
            self:stopMotor();
            -- TODO: Stopping motor also causes brakes to not work!!?!? What kind of vehicle inspector authorized such a vehicle that cannot brake when engine is off?
        end

        self:requestActionEventUpdate()
    end
end

function FollowMe:onWaitResumeFollowMe(reason, noEventSend)
    local spec = FollowMe.getSpec(self)

    if spec.FollowState == FollowMe.STATE_FOLLOWING then
        spec.FollowState = FollowMe.STATE_WAITING
        spec.isDirty = (nil ~= g_server)
    elseif spec.FollowState == FollowMe.STATE_WAITING then
        spec.FollowState = FollowMe.STATE_FOLLOWING
        spec.isDirty = (nil ~= g_server)
    end
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
    local rx,ry,rz  = localDirectionToWorld(node, 0,0, Utils.getNoNil(self.reverserDirection, 1));
    local rlength   = MathUtil.vector2Length(rx,rz);
    local rotDeg    = math.deg(math.atan2(rx/rlength,rz/rlength));
    local rotRad    = MathUtil.degToRad(rotDeg-45.0);
    --log(string.format("getWorldTranslation:%f/%f/%f - localDirectionToWorld:%f/%f/%f - rDeg:%f - rRad:%f", wx,wy,wz, rx,ry,rz, rotDeg, rotRad));

    log("Myself ",self:getName()," Rxyz(",vec2str(rx,ry,rz),") Wxyz(",vec2str(wx,wy,wz),")")

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
            local vrx, vry, vrz = localDirectionToWorld(vehicleNode, 0,0, Utils.getNoNil(vehicleObj.reverserDirection, 1));
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

                        log("closest(",dist,") ",closestVehicle:getName()," Rxyz(",vec2str(vrx,vry,vrz),") Wxyz(",vec2str(vx,vy,vz),")")
                    end;
                end;
            end;
        end;
    end;

    local followCurrentIndex = -1;
    if nil ~= closestVehicle then
        log("FollowMe:findVehicleInFront() candidate=",closestVehicle:getName())
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

    log("FollowMe:findVehicleInFront() actual=",(nil ~= closestVehicle) and closestVehicle:getFullName() or "(nil)")
    return closestVehicle, followCurrentIndex
end

-- function FollowMe:onEnterVehicle(isControlling)
--     log("onEnterVehicle() ",isControlling)
--     if nil ~= self.mapAIHotspot then
--         self.mapAIHotspot.enabled = false;
--     end
-- end

-- function FollowMe:onLeaveVehicle()
--     log("onLeaveVehicle(",self,")")
--     if nil ~= self.mapAIHotspot then
--         self.mapAIHotspot.enabled = true;
--     end
--     if self.followMeIsStarted and nil ~= self.spec_enterable.vehicleCharacter then
--         self.spec_enterable.vehicleCharacter:setCharacterVisibility(true);
--     end
-- end

-- function FollowMe:getDeactivateOnLeave(superFunc)
--   if FollowMe.getIsFollowMeActive(self) then
--     return false
--   end
--   if nil == superFunc then
--     return true
--   end
--   return superFunc(self)
-- end


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


function FollowMe.checkBaler(attachedTool)
    local allowedToDrive = true
    local hasCollision = false
    local pctSpeedReduction = 0
--[[
    if attachedTool:getIsTurnedOn() then
        if attachedTool.baler.unloadingState == Baler.UNLOADING_CLOSED then
            local unitFillLevel = attachedTool:getUnitFillLevel(attachedTool.baler.fillUnitIndex)
            local unitCapacity  = attachedTool:getUnitCapacity(attachedTool.baler.fillUnitIndex)
            if unitFillLevel >= unitCapacity then
                allowedToDrive = false
                --hasCollision = true -- Stop faster
                if (table.getn(attachedTool.baler.bales) > 0) and attachedTool:isUnloadingAllowed() then
                    -- Activate the bale unloading (server-side only!)
                    attachedTool:setIsUnloadingBale(true);
                end
            else
                -- When baler is more than 95% full, then reduce speed in an attempt at not leaving spots of straw.
                local top5pct = math.max((unitFillLevel / unitCapacity) - 0.95, 0)
                pctSpeedReduction = MathUtil.lerp(0.0, 0.75, top5pct * 20)
            end
        else
            allowedToDrive = false
            --hasCollision = true
            if attachedTool.baler.unloadingState == Baler.UNLOADING_OPEN then
                -- Activate closing (server-side only!)
                attachedTool:setIsUnloadingBale(false);
            end
        end
    end
--]]
    return allowedToDrive, hasCollision, pctSpeedReduction;
end

function FollowMe.checkBaleWrapper(attachedTool)
    -- Typo-error bug in base-game's script.
    -- Try to anticipate future "correct spelling".
    --local STATE_WRAPPER_FINISHED = Utils.getNoNil(BaleWrapper.STATE_WRAPPER_FINSIHED, BaleWrapper.STATE_WRAPPER_FINISHED)

    local allowedToDrive = true
    local hasCollision = false
    local pctSpeedReduction = 0
--[[
    if attachedTool.baleWrapperState == BaleWrapper.STATE_WRAPPER_WRAPPING_BALE then
        pctSpeedReduction = 0.5
    elseif attachedTool.baleWrapperState == STATE_WRAPPER_FINISHED then -- '4'
        allowedToDrive = false
        -- Activate the bale unloading (server-side only!)
        attachedTool:doStateChange(BaleWrapper.CHANGE_BUTTON_EMPTY);
    elseif attachedTool.baleWrapperState > STATE_WRAPPER_FINISHED then -- '4'
        allowedToDrive = false
    end
--]]
    return allowedToDrive, hasCollision, pctSpeedReduction;
end

function FollowMe.checkBalerAndWrapper(attachedTool)
    local d1, c1, r1 = FollowMe.checkBaler(attachedTool)
    local d2, c2, r2 = FollowMe.checkBaleWrapper(attachedTool)
    local allowedToDrive    = d1 -- only baler part determines allowed-to-drive
    local hasCollision      = c1 and c2
    local pctSpeedReduction = r1 -- only baler part determines speed-reduction
    return allowedToDrive, hasCollision, pctSpeedReduction
end

function FollowMe:updateFollowMovement(dt)
    local spec = FollowMe.getSpec(self)
    assert(nil ~= spec.FollowVehicleObj);
    local allowedToDrive = (spec.FollowState == FollowMe.STATE_FOLLOWING) and self.spec_motorized.isMotorStarted;
    --local hasCollision = false;
    local moveForwards = true;
    local turnLightState = nil;
    local trailStrength = 1.0;

    --
    --if allowedToDrive and nil ~= self.numCollidingVehicles then
    --    for _,numCollisions in pairs(self.numCollidingVehicles) do
    --        if numCollisions > 0 then
    --            hasCollision = true; -- Collision imminent! Brake! Brake!
    --            break;
    --        end;
    --    end;
    --end

    -- Attempt at automatically unloading of round-bales
    local attachedTool = nil;
    -- Locate supported equipment
    for _,tool in pairs(self:getAttachedImplements()) do
        if nil ~= tool.object then
            if  nil ~= tool.object.baler
            and nil ~= tool.object.baler.baleUnloadAnimationName  -- Seems RoundBalers are the only ones which have set the 'baleUnloadAnimationName'
            and SpecializationUtil.hasSpecialization(Baler, tool.object.specializations)
            then
                if nil ~= tool.object.baleWrapperState
                and SpecializationUtil.hasSpecialization(BaleWrapper, tool.object.specializations)
                then
                    -- Found both baler and wrapper (Kuhn DLC)
                    attachedTool = { tool.object, FollowMe.checkBalerAndWrapper };
                    break;
                end

                -- Found (Round)Baler.LUA
                attachedTool = { tool.object, FollowMe.checkBaler };
                break
            end
            if nil ~= tool.object.baleWrapperState
            and SpecializationUtil.hasSpecialization(BaleWrapper, tool.object.specializations)
            then
                -- Found BaleWrapper
                attachedTool = { tool.object, FollowMe.checkBaleWrapper };
                break
            end
        end
    end
    --
    if nil ~= attachedTool then
        local setAllowedToDrive
        local setHasCollision
        local pctSpeedReduction
        setAllowedToDrive, setHasCollision, pctSpeedReduction = attachedTool[2](attachedTool[1]);
        allowedToDrive = allowedToDrive and Utils.getNoNil(setAllowedToDrive, allowedToDrive);
        --hasCollision   = setHasCollision~=nil   and setHasCollision   or hasCollision;
        if nil ~= pctSpeedReduction and pctSpeedReduction > 0 then
            spec.reduceSpeedTime = g_currentMission.time + 250
            -- TODO - change above, so it actually affects acceleration value
        end
    end

    -- current location / rotation
    local cNode         = FollowMe.getFollowNode(self)
    local vX,vY,vZ      = getWorldTranslation(cNode);
    local vRX,vRY,vRZ   = localDirectionToWorld(cNode, 0,0,Utils.getNoNil(self.reverserDirection, 1));

    -- leader location / rotation
    local leader        = spec.FollowVehicleObj;
    local lNode         = FollowMe.getFollowNode(leader)
    local lx,ly,lz      = getWorldTranslation(lNode);
    local lrx,lry,lrz   = localDirectionToWorld(lNode, 0,0,Utils.getNoNil(leader.reverserDirection, 1));

    -- original target
    local ox,oy,oz;
    local orx,ory,orz;
    -- actual target
    local tX,tY,tZ;
    local tRX,tRY,tRZ;
    --
    local acceleration = 1.0;
    local maxSpeed = 0.0;

    -- leader-target
    local keepInFrontMeters = FollowMe.getKeepFront(self);
    lx = lx - lrz * spec.FollowXOffset + lrx * keepInFrontMeters;
    lz = lz + lrx * spec.FollowXOffset + lrz * keepInFrontMeters;
    -- distance to leader-target (only "correct" when trail is a straight-line)
    local distMeters = MathUtil.vector2Length(vX-lx,vZ-lz);

    local crumbIndexDiff = leader.modFM.DropperCurrentIndex - spec.FollowCurrentIndex;
    --
    if crumbIndexDiff >= FollowMe.cBreadcrumbsMaxEntries then
        -- circular-array have "circled" once, and this follower did not move fast enough.
        if spec.FollowState ~= FollowMe.STATE_STOPPING then
            FollowMe.stopFollowMe(self, FollowMe.REASON_TOO_FAR_BEHIND);
        end
        trailStrength = 0.0
        --hasCollision = true
        allowedToDrive = false
        acceleration = 0.0
        -- Set target 2 meters straight ahead of vehicle.
        tX = vX + vRX * 2;
        tY = vY;
        tZ = vZ + vRZ * 2;
    elseif crumbIndexDiff > 0 then
        trailStrength = 1.0 - (crumbIndexDiff / FollowMe.cBreadcrumbsMaxEntries)

        -- Following crumbs...
        local crumbT = leader.modFM.DropperCircularArray[1+(spec.FollowCurrentIndex % FollowMe.cBreadcrumbsMaxEntries)];
        turnLightState = crumbT.turnLightState
        --
        ox,oy,oz = crumbT.trans[1],crumbT.trans[2],crumbT.trans[3];
        orx,ory,orz = unpack(crumbT.rot);
        -- Apply offset
        tX = ox - orz * spec.FollowXOffset;
        tY = oy;
        tZ = oz + orx * spec.FollowXOffset;
        --
        local dx,dz = tX - vX, tZ - vZ;
        local tDist = MathUtil.vector2Length(dx,dz);
        --
        local trAngle = math.atan2(orx,orz);
        local nz = dx * math.sin(trAngle) + dz * math.cos(trAngle);
        --
        if (tDist < (FollowMe.cMinDistanceBetweenDrops / 2)) -- close enough to crumb?
        or (nz < 0) -- in front of crumb?
        then
            FollowMe.copyDrop(self, crumbT, (spec.FollowXOffset == 0) and nil or {tX,tY,tZ});
            -- Go to next crumb
            spec.FollowCurrentIndex = spec.FollowCurrentIndex + 1;
            crumbIndexDiff = leader.modFM.DropperCurrentIndex - spec.FollowCurrentIndex;
        end;
        --
        if crumbIndexDiff > 0 then
            -- Still following crumbs...
            maxSpeed = crumbT.maxSpeed;
            local crumbN = leader.modFM.DropperCircularArray[1+((spec.FollowCurrentIndex+1) % FollowMe.cBreadcrumbsMaxEntries)];
            if nil ~= crumbN then
                -- Apply offset, to next original target
                local ntX = crumbN.trans[1] - crumbN.rot[3] * spec.FollowXOffset;
                local ntZ = crumbN.trans[3] + crumbN.rot[1] * spec.FollowXOffset;
                local pct = math.max(1 - (tDist / FollowMe.cMinDistanceBetweenDrops), 0);
                tX,_,tZ = MathUtil.vector3ArrayLerp( {tX,0,tZ}, {ntX,0,ntZ}, pct);
                maxSpeed = (maxSpeed + crumbN.maxSpeed) / 2;
            end;
            --
            local keepBackMeters = FollowMe.getKeepBack(self) --, math.max(0, self.lastSpeed) * 3600);
            local distCrumbs   = math.floor(keepBackMeters / FollowMe.cMinDistanceBetweenDrops);
            local distFraction = keepBackMeters - (distCrumbs * FollowMe.cMinDistanceBetweenDrops);

            allowedToDrive = allowedToDrive and not (crumbIndexDiff < distCrumbs); -- Too far ahead?

            if allowedToDrive then
                if keepInFrontMeters > 0 then
                    maxSpeed = maxSpeed * 2
                elseif (crumbIndexDiff > distCrumbs) then
                    local lastSpeedKMH = (self.lastSpeed * 3600)
                    if true == self.mrIsMrVehicle and lastSpeedKMH > 5 then
                        -- Don't allow MR vehicle to 'speed up to catch up', as it may fall over when cornering at higher speeds
                        local diffSpeedKMH = (lastSpeedKMH - maxSpeed)
                        if diffSpeedKMH > 1 then
                            -- Apply brake if going faster than allowed
                            acceleration = MathUtil.lerp(0, -1, math.sin(math.min(diffSpeedKMH-1, math.pi/2)))
                        end
                    else
                        maxSpeed = maxSpeed + maxSpeed * ((crumbIndexDiff - distCrumbs) / 5)
                    end
                elseif not ((crumbIndexDiff == distCrumbs) and (tDist >= distFraction)) then
                    maxSpeed = 0
                end
            end
        end;
    end;
    --
    if crumbIndexDiff <= 0 then
        -- Following leader directly...
        turnLightState = leader.spec_lights:getTurnLightState()

        tX = lx;
        tY = ly;
        tZ = lz;
        -- Rotate to see if the target is still "in front of us"
        local dx,dz = tX - vX, tZ - vZ;
        local trAngle = math.atan2(lrx,lrz);
        local nz = dx * math.sin(trAngle) + dz * math.cos(trAngle);
        --
        local distMetersDiff = distMeters - FollowMe.getKeepBack(self);

        allowedToDrive = allowedToDrive and (nz > 0);
        maxSpeed = math.max(0, leader.lastSpeed) * 3600; -- only consider forward movement.

        if distMetersDiff < 0.5 then
            local factor = 1 - math.min(1, math.abs(distMetersDiff)/10)
            maxSpeed = maxSpeed * factor
            acceleration = 0
        elseif distMetersDiff > 1 then
            local factor = (math.min(1, distMetersDiff / 10) * 1.2) + 0.2
            maxSpeed = maxSpeed + 10 * factor
            acceleration = math.min(0.5, math.max(1.0, acceleration * factor))
        end
    end;

    if spec.reduceSpeedTime > g_currentMission.time then
        --acceleration = math.max(0.1, acceleration * 0.5)
        maxSpeed = math.max(1, maxSpeed * 0.3)
    --else
    --    -- Reduce speed if "attack angle" against target is more than 45degrees.
    --    local lx,lz = AIVehicleUtil.getDriveDirection(self.components[1].node, tX,tY,tZ);
    --    if (self.lastSpeed*3600 > 10) and (math.abs(math.atan2(lx,lz)) > (math.pi/4)) then
    --        acceleration = math.max(0.1, acceleration * 0.5)
    --        maxSpeed = math.max(1, maxSpeed * 0.3)
    --        spec.reduceSpeedTime = g_currentMission.time + 250; -- For the next 250ms, keep speed reduced.
    --    end;
    end

    -- Check if any equipment is active, which will then limit the speed further
    local speedLimit,speedLimitActive = self:getSpeedLimit()
    if speedLimitActive then
        maxSpeed = math.min(maxSpeed, speedLimit)
    end

    --
    -- if allowedToDrive then
    --   self.spec_motorized.motor:setSpeedLimit(speedLimit);
    --   if self.spec_drivable.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_ACTIVE then
    --     self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE);
    --   end
    -- end

    --
    local pX,pY,pZ = worldToLocal(cNode, tX,tY,tZ);
    AIVehicleUtil.driveToPoint(self, dt, acceleration, allowedToDrive, moveForwards, pX,pZ, maxSpeed)

    return turnLightState, trailStrength
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
                if nil ~= leaderSpec.currentHelper then
                    txt = txt .. (" '%s'"):format(leaderSpec.currentHelper.name)
                end
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
            if nil ~= stalkerSpec.currentHelper then
                txt = txt .. (" '%s'"):format(stalkerSpec.currentHelper.name)
            end
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

    if FollowMe.showFollowMeFl then
        local x,y,z = unpack(FollowMe.cursorXYZ)
        drawDebugLine(x,y,z, 1,1,0, x,y+2,z, 1,1,0, true)
    end

    if self.isServer then
        if showFollowMeMy and nil ~= spec.FollowVehicleObj then
            FollowMe.debugDrawTrail(self)
        elseif showFollowMeFl and nil ~= spec.StalkerVehicleObj then
            FollowMe.debugDrawTrail(spec.StalkerVehicleObj)
        end
    end

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

FollowMeRequestEvent = {};
FollowMeRequestEvent_mt = Class(FollowMeRequestEvent, Event);

InitEventClass(FollowMeRequestEvent, "FollowMeRequestEvent");

function FollowMeRequestEvent:emptyNew()
    local self = Event:new(FollowMeRequestEvent_mt);
    self.className = "FollowMeRequestEvent";
    return self;
end;

function FollowMeRequestEvent:new(vehicle, cmdId, reason, farmId)
    local self = FollowMeRequestEvent:emptyNew()
    self.vehicle    = vehicle
    self.farmId     = Utils.getNoNil(farmId, 0)
    self.cmdId      = Utils.getNoNil(cmdId, 0)
    self.reason     = Utils.getNoNil(reason, 0)
    self.distance   = 0 --Utils.getNoNil(vehicle.modFM.FollowKeepBack, 0)
    self.offset     = 0 --Utils.getNoNil(vehicle.modFM.FollowXOffset, 0)
    return self;
end;

function FollowMeRequestEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.vehicle);
    streamWriteUIntN(      streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
    streamWriteUIntN(      streamId, self.cmdId,  FollowMe.NUM_BITS_COMMAND)
    streamWriteUIntN(      streamId, self.reason, FollowMe.NUM_BITS_REASON)
    streamWriteInt8(       streamId, self.distance)
    streamWriteInt8(       streamId, self.offset * 2)
end;

function FollowMeRequestEvent:readStream(streamId, connection)
    self.vehicle  = readNetworkNodeObject(streamId);
    self.farmId   = streamReadUIntN(      streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
    self.cmdId    = streamReadUIntN(      streamId, FollowMe.NUM_BITS_COMMAND)
    self.reason   = streamReadUIntN(      streamId, FollowMe.NUM_BITS_REASON)
    self.distance = streamReadInt8(       streamId)
    self.offset   = streamReadInt8(       streamId) / 2

    if nil ~= self.vehicle then
        if     self.cmdId == FollowMe.COMMAND_START then
            FollowMe.startFollowMe(self.vehicle, connection, self.farmId)
        elseif self.cmdId == FollowMe.COMMAND_STOP then
            FollowMe.stopFollowMe(self.vehicle, self.reason)
        elseif self.cmdId == FollowMe.COMMAND_WAITRESUME then
            FollowMe.waitResumeFollowMe(self.vehicle, self.reason)
        else
            FollowMe.changeDistance(self.vehicle, { self.distance } )
            FollowMe.changeXOffset( self.vehicle, { self.offset } )
        end
    end;
end;


---
---
---

FollowMeResponseEvent = {};
FollowMeResponseEvent_mt = Class(FollowMeResponseEvent, Event);

InitEventClass(FollowMeResponseEvent, "FollowMeResponseEvent");

function FollowMeResponseEvent:emptyNew()
    local self = Event:new(FollowMeResponseEvent_mt);
    self.className = "FollowMeResponseEvent";
    return self;
end;

function FollowMeResponseEvent:new(vehicle, stateId, reason, helper, farmId)
    local self = FollowMeResponseEvent:emptyNew()
    self.vehicle            = vehicle
    self.stateId            = Utils.getNoNil(stateId, 0)
    self.reason             = Utils.getNoNil(reason, 0)
    self.distance           = 0 --Utils.getNoNil(vehicle.modFM.FollowKeepBack, 0)
    self.offset             = 0 --Utils.getNoNil(vehicle.modFM.FollowXOffset, 0)
    self.helperIndex        = 0
    if nil ~= helper then
        self.helperIndex = helper.index
    end
    self.farmId             = Utils.getNoNil(farmId, 0)
    self.followVehicleObj   = nil --vehicle.modFM.FollowVehicleObj
    self.stalkerVehicleObj  = nil --vehicle.modFM.StalkerVehicleObj
    return self;
end;

function FollowMeResponseEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteUIntN(      streamId, self.stateId,  FollowMe.NUM_BITS_STATE)
    streamWriteUIntN(      streamId, self.reason,   FollowMe.NUM_BITS_REASON)
    streamWriteUIntN(      streamId, self.farmId,   FarmManager.FARM_ID_SEND_NUM_BITS)
    streamWriteInt8(       streamId, self.distance)
    streamWriteInt8(       streamId, self.offset * 2)
    streamWriteUInt8(      streamId, self.helperIndex)
    writeNetworkNodeObject(streamId, self.followVehicleObj )
    writeNetworkNodeObject(streamId, self.stalkerVehicleObj)
end;

function FollowMeResponseEvent:readStream(streamId, connection)
    self.vehicle            = readNetworkNodeObject(streamId)
    self.stateId            = streamReadUIntN(      streamId, FollowMe.NUM_BITS_STATE)
    self.reason             = streamReadUIntN(      streamId, FollowMe.NUM_BITS_REASON)
    self.farmId             = streamReadUIntN(      streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
    self.distance           = streamReadInt8(       streamId)
    self.offset             = streamReadInt8(       streamId) / 2
    self.helperIndex        = streamReadUInt8(      streamId)
    self.followVehicleObj   = readNetworkNodeObject(streamId)
    self.stalkerVehicleObj  = readNetworkNodeObject(streamId)

    if nil ~= self.vehicle then
        if 0 == self.helperIndex then
            self.helperIndex = nil
        end

        FollowMe.changeDistance(self.vehicle, { self.distance } ,true )
        FollowMe.changeXOffset( self.vehicle, { self.offset }   ,true )

        if     self.stateId == FollowMe.STATE_STARTING then
            FollowMe.onStartFollowMe(self.vehicle, self.followVehicleObj, self.helperIndex, true, self.farmId)
        elseif self.stateId == FollowMe.STATE_STOPPING then
            FollowMe.onStopFollowMe(self.vehicle, self.reason, true)
        else
            if self.reason ~= 0 then
                FollowMe.showReason(self.vehicle, nil, self.reason, nil)
            end
            --self.vehicle.modFM.FollowState       = self.stateId
            --self.vehicle.modFM.FollowVehicleObj  = self.followVehicleObj
            --self.vehicle.modFM.StalkerVehicleObj = self.stalkerVehicleObj
        end
    end;
end;

--
print(("Script loaded: FollowMe.lua - from %s (v%s)"):format(g_currentModName, g_modManager:getModByName(g_currentModName).version));
