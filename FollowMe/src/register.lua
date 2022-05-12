--
--  Follow Me
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

Cutter.getAllowCutterAIFruitRequirements = Utils.overwrittenFunction(Cutter.getAllowCutterAIFruitRequirements, function(self, superFunc, ...)
  -- Work-around/fix for issue #33
  -- Due to `Cutter:onEndWorkAreaProcessing()` getting called, and to avoid it then calling stopAIVehicle().
  if self.isServer then
    local rootVehicle = self:getRootVehicle()
    if nil ~= rootVehicle and FollowMe.getIsFollowMeActive(rootVehicle) then
      self.spec_cutter.aiNoValidGroundTimer = 0
    end
  end
  return superFunc(self, ...)
end)
--]]

--[[
Sprayer.registerOverwrittenFunctions = Utils.appendedFunction(Sprayer.registerOverwrittenFunctions, function(vehicleType)
  -- Having a manureBarrel with a fertilizingCultivator attached, then avoid having the AI automatically turn these on when FollowMe is active.
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsAIActive", function(self, superFunc)
      local rootVehicle = self:getRootVehicle()
      if rootVehicle and rootVehicle.getIsFollowVehicleActive and rootVehicle:getIsFollowVehicleActive() then
        return false -- "Hackish" work-around, in attempt at convincing Sprayer.LUA to NOT turn on
      end
      return superFunc(self)
    end
  )
end)
--]]

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
source(modDir .. "src/AIDriveStrategyFollowStopWhenTurnedOff.lua")
source(modDir .. "src/AIDriveStrategyFollowVehicleCollision.lua")
source(modDir .. "src/AIDriveStrategyFollowVehicle.lua")
