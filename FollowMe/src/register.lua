--
--  Follow Me
--
-- @author  Decker_MMIV (DCK)
-- @contact forum.farming-simulator.com
-- @date    2021-12-xx, 2023-05-xx
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

--
--
--

--[[
-- The following is only specific for 'FollowMe'...

Lights.updateAILights = Utils.overwrittenFunction(Lights.updateAILights, function(self, superFunc, ...)
  if FollowMe.getIsFollowMeActive(self) then
    -- Let 'FollowMe' control the lights, and not the base game's AI.
    return
  end
  -- 'FollowMe' was not active, so let the original method do what it need to do.
  superFunc(self, ...)
end)
--]]


if Cutter.onEndWorkAreaProcessing ~= nil then
  -- Due to issue #59 with combines with active FollowMe and harvesting, being stopped by Cutter.LUA
  -- during turning at end of field, where there are no crops to harvest.
  Cutter.onEndWorkAreaProcessing = Utils.appendedFunction(Cutter.onEndWorkAreaProcessing, function(self)
    if self.isServer then
      local rootVehicle = self.rootVehicle
      if rootVehicle and rootVehicle.getIsFollowVehicleActive and rootVehicle:getIsFollowVehicleActive() then
        local spec = self.spec_cutter
        if spec then
          spec.aiNoValidGroundTimer = 0
        end
      end
    end
  end)
end


Sprayer.registerOverwrittenFunctions = Utils.appendedFunction(Sprayer.registerOverwrittenFunctions, function(vehicleType)
  -- Due to issues where Sprayer is activated when getIsAIActive returns true, some of the 
  -- Sprayer's functions needs be lied to.
  for _,funcName in pairs({
    "getCanBeTurnedOn",
    "getIsSprayerExternallyFilled",
    "onStartWorkAreaProcessing",
    "processSprayerArea",
  }) do
    SpecializationUtil.registerOverwrittenFunction(vehicleType, funcName, function(self, superFunc, ...)
      self.modFV_LieAboutIt = true
      local res = superFunc(self, ...)
      self.modFV_LieAboutIt = nil
      return res
    end)
  end

  -- Avoid having the AI automatically turn on sprayer when FollowMe is active.
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsAIActive", function(self, superFunc)
    local rootVehicle = self.rootVehicle
    if rootVehicle and rootVehicle.getIsFollowVehicleActive and rootVehicle:getIsFollowVehicleActive() then
      if self.modFV_LieAboutIt then
        return false -- "Hackish" work-around, in attempt at convincing Sprayer.LUA to NOT turn on
      end
    end
    return superFunc(self)
  end)

  -- Avoid having the AI automatically turn on sprayer when FollowMe is active.
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsPowered", function(self, superFunc)
    local rootVehicle = self.rootVehicle
    if rootVehicle and rootVehicle.getIsFollowVehicleActive and rootVehicle:getIsFollowVehicleActive() then
      if self.modFV_LieAboutIt then
        return false -- "Hackish" work-around, in attempt at convincing Sprayer.LUA to NOT turn on
      end
    end
    return superFunc(self)
  end)
end)

--
--
--
local modDir = g_currentModDirectory
local modName = g_currentModName

function injectSpecialization(specTypeName)
    local modSpecTypeName = modName .. ".followVehicle"
    ---- Forcefully add/inject specialization to specific vehicle-types
    local debugAddedToTypes = {}
    for vehTypeName,vehTypeObj in pairs( g_vehicleTypeManager:getTypes() ) do
        if nil == vehTypeObj.specializationsByName[modSpecTypeName] then
            if  true  == SpecializationUtil.hasSpecialization(Drivable      ,vehTypeObj.specializations)
            and true  == SpecializationUtil.hasSpecialization(Motorized     ,vehTypeObj.specializations)
            and true  == SpecializationUtil.hasSpecialization(Enterable     ,vehTypeObj.specializations)
            and true  == SpecializationUtil.hasSpecialization(AIJobVehicle  ,vehTypeObj.specializations)
            and true  == SpecializationUtil.hasSpecialization(Lights        ,vehTypeObj.specializations)
            --and false == SpecializationUtil.hasSpecialization(ConveyorBelt  ,vehTypeObj.specializations)
            and false == SpecializationUtil.hasSpecialization(Locomotive    ,vehTypeObj.specializations) -- No reason to add Follow Me to locomotives
            and false == SpecializationUtil.hasSpecialization(PushHandTool  ,vehTypeObj.specializations) -- Some errors regarding ikChains occurs, when attempting to activate Follow Me for such vehicles, so for now avoid adding to PushHandTool
            then
                g_vehicleTypeManager:addSpecialization(vehTypeName, modSpecTypeName)
                table.insert(debugAddedToTypes, vehTypeName)
            end
        end
    end
    if #debugAddedToTypes > 0 then
        log("  Info: ",modSpecTypeName," specialization added to: ", table.concat(debugAddedToTypes, ", "), ".")
    end
end

TypeManager.validateTypes = Utils.appendedFunction(TypeManager.validateTypes, function(self)
  if self.typeName == "vehicle" then
    injectSpecialization()
  end
end)

----
if nil == AIJobVehicle.aiWaiting then
  AIJobVehicle.registerFunctions = Utils.appendedFunction(AIJobVehicle.registerFunctions, function(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "aiWaiting", AIJobVehicle.aiWaiting)
  end)

  AIJobVehicle.aiWaiting = function(self)
  end
end

if nil == AIJobVehicle.aiResume then
  AIJobVehicle.registerFunctions = Utils.appendedFunction(AIJobVehicle.registerFunctions, function(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "aiResume", AIJobVehicle.aiResume)
  end)

  AIJobVehicle.aiResume = function(self)
  end
end

--
source(modDir .. "src/AIMessageErrorFollowerStopped.lua")

source(modDir .. "src/AITaskFollowVehicle.lua")
source(modDir .. "src/AIJobFollowVehicle.lua")
source(modDir .. "src/AIJobTypeFollowVehicle.lua")

source(modDir .. "src/AIVehicleIsWaitingEvent.lua")

source(modDir .. "src/AIDriveStrategyFollowBaler.lua")
source(modDir .. "src/AIDriveStrategyFollowBaleLoader.lua")
source(modDir .. "src/AIDriveStrategyFollowStopWhenTurnedOff.lua")
source(modDir .. "src/AIDriveStrategyFollowVehicleCollision.lua")
source(modDir .. "src/AIDriveStrategyFollowVehicle.lua")
