--
--  Follow Me
--
-- @author  Decker_MMIV - fs-uk.com, forum.farming-simulator.com
-- @date    2016-11-xx
--

RegistrationHelper_FM = {};
RegistrationHelper_FM.isLoaded = false;

if SpecializationUtil.specializations['FollowMe'] == nil then
    SpecializationUtil.registerSpecialization('FollowMe', 'FollowMe', g_currentModDirectory .. 'FollowMe.lua')
    RegistrationHelper_FM.isLoaded = false;
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

function RegistrationHelper_FM:register()
    for _, vehicle in pairs(VehicleTypeUtil.vehicleTypes) do
        if vehicle ~= nil and SpecializationUtil.hasSpecialization(Drivable, vehicle.specializations) then
            table.insert(vehicle.specializations, SpecializationUtil.getSpecialization("FollowMe"))
        end
    end
    RegistrationHelper_FM.isLoaded = true
end

addModEventListener(RegistrationHelper_FM)