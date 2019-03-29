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

AIVehicle.raiseAIEvent = Utils.overwrittenFunction(AIVehicle.raiseAIEvent, function(self, superFunc, aiEvt1, aiEvt2, ...)
  if "FollowMe" == self.spec_aiVehicle.mod_ForcedDrivingStrategyName then
    -- Don't raise the `aiEvt2`.
    -- This to avoid any attached implements to unfold/start/whatever, when FollowMe is activated via AIVehicle.startAIVehicle()
    SpecializationUtil.raiseEvent(self, aiEvt1, ...)
    return
  end
  -- Forced driving-strategy-id was not 'FollowMe', so let the original method do what it need to do.
  superFunc(self, aiEvt1, aiEvt2, ...)
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

---- Register this specialization
local specTypeName = 'followMe'

--g_specializationManager:addSpecialization(specTypeName, 'FollowMe', Utils.getFilename('FollowMe.lua', g_currentModDirectory), nil)
g_specializationManager:addSpecialization(specTypeName, 'FollowMe', Utils.getFilename('FollowMe.lua', g_currentModDirectory), true, nil) -- What does the last two arguments even do?

---- Add the specialization to specific vehicle-types
--local modSpecTypeName = g_currentModName ..".".. specTypeName
local modSpecTypeName = specTypeName

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

---- Copy all mod-environment-l10n-texts into the game-root-l10n-text object.
-- Sorry GIANTS. This is what we community mod-scripters do as a work-around, when LUADOC documentation is lacking... :-/
local root_i18n = getfenv(0).g_i18n
for k,v in pairs(g_i18n.texts) do
  root_i18n:setText(k,v)
end
