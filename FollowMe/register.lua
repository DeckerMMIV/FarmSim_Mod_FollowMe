--
--  Follow Me
--
-- @author  Decker_MMIV - fs-uk.com, forum.farming-simulator.com
-- @date    2019-01-xx
--


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



-- FS19
local specTypeName = 'followMe'
g_specializationManager:addSpecialization(specTypeName, 'FollowMe', g_currentModDirectory .. 'FollowMe.lua', "")
local modSpecTypeName = g_currentModName ..".".. specTypeName
--local modSpecTypeName = specTypeName
--
for vehTypeName,vehTypeObj in pairs( g_vehicleTypeManager.vehicleTypes ) do
  if  true  == SpecializationUtil.hasSpecialization(Drivable      ,vehTypeObj.specializations)
  and true  == SpecializationUtil.hasSpecialization(Motorized     ,vehTypeObj.specializations)
  and true  == SpecializationUtil.hasSpecialization(Enterable     ,vehTypeObj.specializations)
  and true  == SpecializationUtil.hasSpecialization(AIVehicle     ,vehTypeObj.specializations)
  and false == SpecializationUtil.hasSpecialization(ConveyorBelt  ,vehTypeObj.specializations)
  and false == SpecializationUtil.hasSpecialization(Locomotive    ,vehTypeObj.specializations)
  then
    g_vehicleTypeManager:addSpecialization(vehTypeName, modSpecTypeName)
    log("FollowMe added to:    ",vehTypeName)
  else
    log("FollowMe ignored for: ",vehTypeName)
  end
end


--[[
for _,vehTypeName in pairs( { 'baseDrivable' } ) do
  g_vehicleTypeManager:addSpecialization(vehTypeName, modSpecTypeName)
end
--]]



--[[
RegistrationHelper_FM = {};
RegistrationHelper_FM.isLoaded = false;

source(Utils.getFilename("FollowMe.lua", g_currentModDirectory))

if g_specializationManager:getSpecializationByName("FollowMe") == nil then
    if FollowMe == nil then
       print("Unable to find specialization '" .. "FollowMe" .. "'");
    else
        for i, typeDef in pairs(g_vehicleTypeManager.vehicleTypes) do
            if typeDef ~= nil and i ~= "locomotive" then
                local isDrivable = false
                local isEnterable = false
                local hasMotor = false
                for name, spec in pairs(typeDef.specializationsByName) do
                    if name == "drivable" then
                        isDrivable = true
                    elseif name == "motorized" then
                        hasMotor = true
                    elseif name == "enterable" then
                        isEnterable = true
                    end
                end
                if isDrivable and isEnterable and hasMotor then
                    print("Attached specialization " .. "'" .. "FollowMe" .. "'" .. "to vehicleType '" .. tostring(i) .. "'")
                    typeDef.specializationsByName["FollowMe"] = FollowMe
                    table.insert(typeDef.specializationNames, "FollowMe")
                    table.insert(typeDef.specializations, FollowMe)
                end
            end
        end
    end
end

function RegistrationHelper_FM:loadMap(name)
    if not g_currentMission.RegistrationHelper_FM_isLoaded then
        if not RegistrationHelper_FM.isLoaded then
            self:register();
        end
        g_currentMission.RegistrationHelper_FM_isLoaded = true
    else
        print("Error: FollowMe has been loaded already!");
    end
end

function RegistrationHelper_FM:deleteMap()
    g_currentMission.RegistrationHelper_FM_isLoaded = nil
end

function RegistrationHelper_FM:keyEvent(unicode, sym, modifier, isDown)
end

function RegistrationHelper_FM:mouseEvent(posX, posY, isDown, isUp, button)
end

function RegistrationHelper_FM:update(dt)
end

function RegistrationHelper_FM:draw()
end


function RegistrationHelper_FM:getIsHired(superFunc)
    if self.getIsFollowMeActive ~= nil and self:getIsFollowMeActive() then
        return true;
    end
    return superFunc()
end


function RegistrationHelper_FM:register()

    -- Make sure that it is not possible to start a hired helper, when FollowMe is active.
    AIVehicle.canStartAIVehicle = Utils.overwrittenFunction(AIVehicle.canStartAIVehicle, function(self, superFunc)
        if self.getIsFollowMeActive ~= nil and self:getIsFollowMeActive() then
            return false;
        end
        return superFunc(self);
    end);

    -- Overwrite getIsHired() to get other base-game script functionality to "work"
    Vehicle.getIsAIActive = Utils.overwrittenFunction(Vehicle.getIsAIActive, RegistrationHelper_FM.getIsHired);

    -- More overwrite stuff, because base-game scripts calls stopAIVehicle when out-of-fuel and alike.
    AIVehicle.stopAIVehicle = Utils.overwrittenFunction(AIVehicle.stopAIVehicle, function(self, superFunc, reason, noEventSend)
        if self.getIsFollowMeActive ~= nil and self:getIsFollowMeActive() then
            FollowMeSpec.stopFollowMe(self, nil, noEventSend)
            return
        end
        return superFunc(self, reason, noEventSend)
    end);

    RegistrationHelper_FM.isLoaded = true
end

addModEventListener(RegistrationHelper_FM)
--]]