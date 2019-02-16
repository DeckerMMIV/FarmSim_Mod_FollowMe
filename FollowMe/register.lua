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
      --print(string.format("%7ums ", g_time) .. txt);
      print(txt)
  end
end;

--
--
--

-- The following is only specific for 'FollowMe'...

AIVehicle.raiseAIEvent = Utils.overwrittenFunction(AIVehicle.raiseAIEvent, function(self, superFunc, aiEvt1, aiEvt2)
  if "FollowMe" == self.spec_aiVehicle.mod_ForcedDrivingStrategyName then
    -- Don't raise the `aiEvt2`.
    -- This to avoid any attached implements to unfold/start/whatever, when FollowMe is activated via AIVehicle.startAIVehicle()
    SpecializationUtil.raiseEvent(self, aiEvt1)
    return
  end
  -- Forced driving-strategy-id was not 'FollowMe', so let the original method do what it need to do.
    superFunc(self, aiEvt1, aiEvt2)
end)

AIVehicle.getCanAIVehicleContinueWork = Utils.overwrittenFunction(AIVehicle.getCanAIVehicleContinueWork, function(self, superFunc)
  if FollowMe.getIsFollowMeActive(self) then
    return true;
  end
  return superFunc(self)
end)

AIVehicle.updateAIDriveStrategies = Utils.overwrittenFunction(AIVehicle.updateAIDriveStrategies, function(self, superFunc)
  if "FollowMe" == self.spec_aiVehicle.mod_ForcedDrivingStrategyName then
    FollowMe.updateAIDriveStrategies(self)
    return
  end
  -- Forced driving-strategy-id was not 'FollowMe', so let the original method do what it need to do.
    superFunc(self)
end)

--
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
  and true  == SpecializationUtil.hasSpecialization(Lights        ,vehTypeObj.specializations)
  and false == SpecializationUtil.hasSpecialization(ConveyorBelt  ,vehTypeObj.specializations)
  and false == SpecializationUtil.hasSpecialization(Locomotive    ,vehTypeObj.specializations)
  then
    g_vehicleTypeManager:addSpecialization(vehTypeName, modSpecTypeName)
    log("  FollowMe added to: ",vehTypeName)
  --else
  --  log("FollowMe ignored for: ",vehTypeName)
  end
end
