AIDriveStrategyFollowBaler = {}
local AIDriveStrategyFollowBaler_mt = Class(AIDriveStrategyFollowBaler, AIDriveStrategy)

function AIDriveStrategyFollowBaler.new(reconstructionData, customMt)
    local self = AIDriveStrategy.new(reconstructionData, customMt or AIDriveStrategyFollowBaler_mt)
    self.balers = {}
    self.slowDownFillLevel = 200
    self.slowDownStartSpeed = 15

    return self
end

local getBalerAllowDriveAndMaxSpeed = function(self, baler, dt)
    if not baler:getConsumableIsAvailable(Baler.CONSUMABLE_TYPE_NAME_ROUND)
    or not baler:getConsumableIsAvailable(Baler.CONSUMABLE_TYPE_NAME_SQUARE) then
        -- Abort following when baler is empty of consumables
        -- Report a negative maxSpeed back, indicating this strategy wants to stop the vehicle
        return false, -1
    end

    local spec = baler.spec_baler
    if spec.unloadingState ~= Baler.UNLOADING_CLOSED then
        return false, 0
    end

    local fillLevel = baler:getFillUnitFillLevel(spec.fillUnitIndex)
    local capacity = baler:getFillUnitCapacity(spec.fillUnitIndex)
    local freeFillLevel = capacity - fillLevel

    if freeFillLevel < self.slowDownFillLevel then
        if freeFillLevel <= 0 then
            return false, 0
        end
        -- Only larger amounts picked up, should slow down vehicle's speed.
        if spec.workAreaParameters.lastPickedUpLiters > 10 then
            return true, 2 + (freeFillLevel / self.slowDownFillLevel) * self.slowDownStartSpeed
        end
    end

    return true, math.huge
end

local getBalerAllowDriveAndMaxSpeed_NonStopBaling = function(self, baler, dt)
    if not baler:getConsumableIsAvailable(Baler.CONSUMABLE_TYPE_NAME_ROUND)
    or not baler:getConsumableIsAvailable(Baler.CONSUMABLE_TYPE_NAME_SQUARE) then
        -- Abort following when baler is empty of consumables
        -- Report a negative maxSpeed back, indicating this strategy wants to stop the vehicle
        return false, -1
    end

    local spec = baler.spec_baler
    if spec.platformDropInProgress then
        return true, spec.platformAIDropSpeed
    end
    return true, math.huge
end

function AIDriveStrategyFollowBaler:setAIVehicle(vehicle)
    AIDriveStrategyFollowBaler:superClass().setAIVehicle(self, vehicle)

    local addIfHasSpecialization = function(object)
        if SpecializationUtil.hasSpecialization(Baler, object.specializations) then
            local func = nil

            local spec = object.spec_baler
            if spec and false == spec.nonStopBaling then
                func = getBalerAllowDriveAndMaxSpeed
            elseif spec and true == spec.nonStopBaling then
                func = getBalerAllowDriveAndMaxSpeed_NonStopBaling
            end

            if nil ~= func then
                table.insert(self.balers, { object=object, func=func })
            end
        end
    end

    for _, object in pairs(self.vehicle.childVehicles) do
        addIfHasSpecialization(object)
    end

    for _, objFunc in pairs(self.balers) do
        local object = objFunc.object
        if nil ~= object.setBalerAutomaticDrop then
            object:setBalerAutomaticDrop(true)
        end
        if nil ~= object.setBaleWrapperAutomaticDrop then
            object:setBaleWrapperAutomaticDrop(true)
        end
    end

    return (#self.balers > 0)
end

function AIDriveStrategyFollowBaler:update(dt)
end

function AIDriveStrategyFollowBaler:getDriveData(dt, vX, vY, vZ)
    local maxSpeed = math.huge
    for _, baler in pairs(self.balers) do
        local allowedToDrive, maxSpeedTemp = baler.func(self, baler.object, dt)
        if not allowedToDrive then
            return nil, nil, true, maxSpeedTemp, 0
        end
        maxSpeed = math.min(maxSpeed, maxSpeedTemp)
    end

    return nil, nil, true, maxSpeed, math.huge
end
