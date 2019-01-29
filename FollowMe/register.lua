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

-- FS19
local specTypeName = 'followMe'
g_specializationManager:addSpecialization(specTypeName, 'FollowMe', g_currentModDirectory .. 'FollowMe.lua', "")
local modSpecTypeName = g_currentModName ..".".. specTypeName
--
for vehTypeName,vehTypeObj in pairs( g_vehicleTypeManager.vehicleTypes ) do
  if  true  == SpecializationUtil.hasSpecialization(Drivable      ,vehTypeObj.specializations)
  and true  == SpecializationUtil.hasSpecialization(Motorized     ,vehTypeObj.specializations)
  and true  == SpecializationUtil.hasSpecialization(Enterable     ,vehTypeObj.specializations)
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