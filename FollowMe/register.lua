--
--  Follow Me
--
-- @author  Decker_MMIV - fs-uk.com, forum.farming-simulator.com
-- @date    2019-01-xx
--

-- For debugging
local function log(...)
  if true then
      local txt = ""
      for idx = 1,select("#", ...) do
          txt = txt .. tostring(select(idx, ...))
      end
      print(string.format("%7ums ", g_time) .. txt);
  end
end;



--
--

-- WARNING!
AIVehicleSetStartedEvent.new = Utils.overwrittenFunction(AIVehicleSetStartedEvent.new, function(dummySelf, superFunc, object, reason, isStarted, helper, startedFarmId)
  local self = superFunc(dummySelf, object, reason, isStarted, helper, startedFarmId)
  self.mod_ForcedDrivingStrategyName = object.spec_aiVehicle.mod_ForcedDrivingStrategyName
  return self
end)

-- WARNING!
AIVehicleSetStartedEvent.writeStream = Utils.overwrittenFunction(AIVehicleSetStartedEvent.writeStream, function(self, superFunc, streamId, connection)
  if nil ~= self.mod_ForcedDrivingStrategyName
  and "" ~= self.mod_ForcedDrivingStrategyName then
    streamWriteBool(streamId, true)
    streamWriteString(streamId, self.mod_ForcedDrivingStrategyName)
  else
    streamWriteBool(streamId, false)
  end
  superFunc(self, streamId, connection)
end)

-- WARNING!
AIVehicleSetStartedEvent.readStream = Utils.overwrittenFunction(AIVehicleSetStartedEvent.readStream, function(self, superFunc, streamId, connection)
  if streamReadBool(streamId) then
    self.mod_ForcedDrivingStrategyName = streamReadString(streamId)
  else
    self.mod_ForcedDrivingStrategyName = nil
  end
  superFunc(self, streamId, connection)
end)

-- WARNING!
AIVehicleSetStartedEvent.run = Utils.overwrittenFunction(AIVehicleSetStartedEvent.run, function(self, superFunc, connection)
  self.object.spec_aiVehicle.mod_ForcedDrivingStrategyName = self.mod_ForcedDrivingStrategyName
  superFunc(self, connection)
end)

--
--

-- WARNING!
AIVehicle.onWriteStream = Utils.overwrittenFunction(AIVehicle.onWriteStream, function(self, superFunc, streamId, connection)
  if nil ~= self.spec_aiVehicle.mod_ForcedDrivingStrategyName
  and "" ~= self.spec_aiVehicle.mod_ForcedDrivingStrategyName then
    streamWriteBool(streamId, true)
    streamWriteString(streamId, self.spec_aiVehicle.mod_ForcedDrivingStrategyName)
  else
    streamWriteBool(streamId, false)
  end
  superFunc(self, streamId, connection)
end)

-- WARNING!
AIVehicle.onReadStream = Utils.overwrittenFunction(AIVehicle.onReadStream, function(self, superFunc, streamId, connection)
  if streamReadBool(streamId) then
    self.spec_aiVehicle.mod_ForcedDrivingStrategyName = streamReadString(streamId)
  else
    self.spec_aiVehicle.mod_ForcedDrivingStrategyName = nil
  end
  superFunc(self, streamId, connection)
end)

-- WARNING!
AIVehicle.startAIVehicle = Utils.overwrittenFunction(AIVehicle.startAIVehicle, function(self, superFunc, helperIndex, noEventSend, startedFarmId, forcedDrivingStrategyName)
  if nil ~= forcedDrivingStrategyName then
    self.spec_aiVehicle.mod_ForcedDrivingStrategyName = forcedDrivingStrategyName
  end
  superFunc(self, helperIndex, noEventSend, startedFarmId, forcedDrivingStrategyName)
end)

--
--

-- WARNING!
AIVehicle.raiseAIEvent = Utils.overwrittenFunction(AIVehicle.raiseAIEvent, function(self, superFunc, aiEvt1, aiEvt2)
  if "FollowMe" == self.spec_aiVehicle.mod_ForcedDrivingStrategyName then
    -- Don't raise the `aiEvt2`.
    -- This to avoid any attached implements to unfold/start/whatever, when FollowMe is activated via AIVehicle.startAIVehicle()
    SpecializationUtil.raiseEvent(self, aiEvt1)
    return
  end
  superFunc(self, aiEvt1, aiEvt2)
end)

-- WARNING!
AIVehicle.getCanAIVehicleContinueWork = Utils.overwrittenFunction(AIVehicle.getCanAIVehicleContinueWork, function(self, superFunc)
  if FollowMe.getIsFollowMeActive(self) then
    return true;
  end
  return superFunc(self)
end)

-- WARNING!
AIVehicle.updateAIDriveStrategies = Utils.overwrittenFunction(AIVehicle.updateAIDriveStrategies, function(self, superFunc)
  if "FollowMe" == self.spec_aiVehicle.mod_ForcedDrivingStrategyName then
    FollowMe.updateAIDriveStrategies(self)
    return
  end
  -- No forced driving-strategy-id given, so let the original method do what it need to do.
  superFunc(self)
end)


-- WARNING!
Vehicle.getSpeedLimit = Utils.overwrittenFunction(Vehicle.getSpeedLimit, function(self, superFunc, onlyIfWorking)
  if  nil == onlyIfWorking
  and nil ~= self.spec_aiVehicle
  then
    onlyIfWorking = self.spec_aiVehicle.mod_CheckSpeedLimitOnlyIfWorking
  end
  return superFunc(self, onlyIfWorking)
end)

--
--

local specTypeName = 'followMe'
g_specializationManager:addSpecialization(specTypeName, 'FollowMe', g_currentModDirectory .. 'FollowMe.lua', "")

local modSpecTypeName = g_currentModName ..".".. specTypeName
for vehTypeName,vehTypeObj in pairs( g_vehicleTypeManager.vehicleTypes ) do
  if  true  == SpecializationUtil.hasSpecialization(Drivable      ,vehTypeObj.specializations)
  and true  == SpecializationUtil.hasSpecialization(Motorized     ,vehTypeObj.specializations)
  and true  == SpecializationUtil.hasSpecialization(Enterable     ,vehTypeObj.specializations)
  and true  == SpecializationUtil.hasSpecialization(AIVehicle     ,vehTypeObj.specializations)
  and false == SpecializationUtil.hasSpecialization(ConveyorBelt  ,vehTypeObj.specializations)
  and false == SpecializationUtil.hasSpecialization(Locomotive    ,vehTypeObj.specializations)
  then
    g_vehicleTypeManager:addSpecialization(vehTypeName, modSpecTypeName)
    log("FollowMe added to: ",vehTypeName)
  --else
  --  log("FollowMe ignored for: ",vehTypeName)
  end
end
