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




-- WARNING! This forced change of a constant, is a hack'ish attempt at getting a bit more data through to AIVehicle's methods!
FarmManager.modOrig_FARM_ID_SEND_NUM_BITS = FarmManager.FARM_ID_SEND_NUM_BITS
FarmManager.FARM_ID_SEND_NUM_BITS = 8

AIVehicle.FORCED_DRIVING_STRATEGY_0 = 0   -- Game's default AI
AIVehicle.FORCED_DRIVING_STRATEGY_1 = 1   -- Mod: Follow Me

-- WARNING!
AIVehicleSetStartedEvent.new = Utils.overwrittenFunction(AIVehicleSetStartedEvent.new, function(self, superFunc, object, reason, isStarted, helper, startedFarmId)
  if nil ~= startedFarmId then
    local mod_ForcedDrivingStrategyId = Utils.getNoNil(object.spec_aiVehicle.mod_ForcedDrivingStrategyId, 0)
    startedFarmId = bitOR(startedFarmId, mod_ForcedDrivingStrategyId * 16)
  end
  return superFunc(self, object, reason, isStarted, helper, startedFarmId)
end)

-- WARNING!
AIVehicle.onWriteStream = Utils.overwrittenFunction(AIVehicle.onWriteStream, function(self, superFunc, streamId, connection)
  local orig_StartedFarmId = self.spec_aiVehicle.startedFarmId
  local mod_ForcedDrivingStrategyId = Utils.getNoNil(self.spec_aiVehicle.mod_ForcedDrivingStrategyId, 0)
  self.spec_aiVehicle.startedFarmId = bitOR(self.spec_aiVehicle.startedFarmId, mod_ForcedDrivingStrategyId * 16)
  superFunc(self, streamId, connection)
  self.spec_aiVehicle.startedFarmId = orig_StartedFarmId
end)

-- WARNING!
AIVehicle.startAIVehicle = Utils.overwrittenFunction(AIVehicle.startAIVehicle, function(self, superFunc, helperIndex, noEventSend, startedFarmId, forcedDrivingStrategyId)
  if nil ~= forcedDrivingStrategyId then
    self.spec_aiVehicle.mod_ForcedDrivingStrategyId = forcedDrivingStrategyId
  else
    self.spec_aiVehicle.mod_ForcedDrivingStrategyId = bitAND(startedFarmId / 16, 15)
  end
  startedFarmId = bitAND(startedFarmId, 15)
  superFunc(self, helperIndex, noEventSend, startedFarmId)
end)

-- WARNING!
AIVehicle.updateAIDriveStrategies = Utils.overwrittenFunction(AIVehicle.updateAIDriveStrategies, function(self, superFunc)
  local mod_ForcedDrivingStrategyId = Utils.getNoNil(self.spec_aiVehicle.mod_ForcedDrivingStrategyId, 0)
  if 0 == mod_ForcedDrivingStrategyId then
    -- No forced driving-strategy-id given, so let the original method do what it need to do.
    superFunc(self)
  else
    -- TODO: Have some 'lookup' table, where other mods can register their 'driving-strategy-id' number (maximum 15 available)
    if AIVehicle.FORCED_DRIVING_STRATEGY_1 == mod_ForcedDrivingStrategyId then
      FollowMe.updateAIDriveStrategies(self)
    end
  end
end)


-- WARNING!
Vehicle.getSpeedLimit = Utils.overwrittenFunction(Vehicle.getSpeedLimit, function(self, superFunc, onlyIfWorking)
  if  nil == onlyIfWorking
  and nil ~= self.spec_aiVehicle
  and nil ~= self.spec_aiVehicle.modFM_doCheckSpeedLimitOnlyIfWorking
  then
    onlyIfWorking = self.spec_aiVehicle.modFM_doCheckSpeedLimitOnlyIfWorking
  end
  return superFunc(self, onlyIfWorking)
end)


-- FS19
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
