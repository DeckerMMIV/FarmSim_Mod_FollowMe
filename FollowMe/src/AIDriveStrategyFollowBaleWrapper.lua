AIDriveStrategyFollowBaleWrapper = {}
local AIDriveStrategyFollowBaleWrapper_mt = Class(AIDriveStrategyFollowBaleWrapper, AIDriveStrategy)

function AIDriveStrategyFollowBaleWrapper.new(reconstructionData, customMt)
    local self = AIDriveStrategy.new(reconstructionData, customMt or AIDriveStrategyFollowBaleWrapper_mt)
    self.baleWrappers = {}
    return self
end

local getBaleWrapperAllowContinuing = function(self, baleWrapper, dt)
    if not baleWrapper:getConsumableIsAvailable(BaleWrapper.CONSUMABLE_TYPE_NAME) then
        -- Abort following when balewrapper is empty of consumables
        -- Report a negative maxSpeed back, indicating this strategy wants to stop the vehicle
        return false, -1
    end
    return true, math.huge
end

function AIDriveStrategyFollowBaleWrapper:setAIVehicle(vehicle)
    AIDriveStrategyFollowBaleWrapper:superClass().setAIVehicle(self, vehicle)

    local addIfHasSpecialization = function(object)
        if SpecializationUtil.hasSpecialization(BaleWrapper, object.specializations)
        and nil ~= object.getConsumableIsAvailable
        then
            local isTurnedOn = true
            if nil ~= object.allowsGrabbingBale then
                isTurnedOn = object:allowsGrabbingBale()
            end
            if isTurnedOn then
                table.insert(self.baleWrappers, { object=object, func=getBaleWrapperAllowContinuing })
            end
        end
    end

    for _, object in pairs(self.vehicle.childVehicles) do
        addIfHasSpecialization(object)
    end

    for _, objFunc in pairs(self.baleWrappers) do
        local object = objFunc.object
        if nil ~= object.setBaleWrapperAutomaticDrop then
            object:setBaleWrapperAutomaticDrop(true)
        end
    end

    return (#self.baleWrappers > 0)
end

function AIDriveStrategyFollowBaleWrapper:update(dt)
end

function AIDriveStrategyFollowBaleWrapper:getDriveData(dt, vX, vY, vZ)
    local maxSpeed = math.huge
    for _, baleWrapper in pairs(self.baleWrappers) do
        local allowedToDrive, maxSpeedTemp = baleWrapper.func(self, baleWrapper.object, dt)
        if not allowedToDrive then
            return nil, nil, true, maxSpeedTemp, 0
        end
        maxSpeed = math.min(maxSpeed, maxSpeedTemp)
    end

    return nil, nil, true, maxSpeed, math.huge
end
