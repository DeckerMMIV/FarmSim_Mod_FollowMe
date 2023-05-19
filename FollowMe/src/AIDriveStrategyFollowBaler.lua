AIDriveStrategyFollowBaler = {}
local AIDriveStrategyFollowBaler_mt = Class(AIDriveStrategyFollowBaler, AIDriveStrategy)

function AIDriveStrategyFollowBaler.new(customMt)
	if customMt == nil then
		customMt = AIDriveStrategyFollowBaler_mt
	end

	local self = AIDriveStrategy.new(customMt)
	self.balers = {}
	self.slowDownFillLevel = 200
	self.slowDownStartSpeed = 15

	return self
end

local getBalerAllowDriveAndMaxSpeed = function(self, baler, dt)
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

        -- Issue #60
        -- If only tiny amounts are being picked up during 0.5 second interval, then keep the vehicle's speed up.
        --if spec.workAreaParameters.lastPickedUpLiters <= 10 then
        --    spec.workAreaParameters.modFV_emptyWorkAreaTimer = Utils.getNoNil(spec.workAreaParameters.modFV_emptyWorkAreaTimer, 500) - dt
        --    if spec.workAreaParameters.modFV_emptyWorkAreaTimer < 0 then
        --        return true, math.huge
        --    end
        --end
        --spec.workAreaParameters.modFV_emptyWorkAreaTimer = nil

        -- Issue #60
        -- Only larger amounts picked up, should slow down vehicle's speed.
        if spec.workAreaParameters.lastPickedUpLiters > 10 then
            return true, 2 + (freeFillLevel / self.slowDownFillLevel) * self.slowDownStartSpeed
        end
    end

    return true, math.huge
end

local getBalerAllowDriveAndMaxSpeed_NonStopBaling = function(self, baler, dt)
    local spec = baler.spec_baler
    if spec.platformDropInProgress then
        return true, spec.platformAIDropSpeed
    end
    return true, math.huge
end

local noOperation = function(self, baler)
    return true, math.huge
end

function AIDriveStrategyFollowBaler:setAIVehicle(vehicle)
	AIDriveStrategyFollowBaler:superClass().setAIVehicle(self, vehicle)

    local addIfHasSpecialization = function(object)
        if SpecializationUtil.hasSpecialization(Baler, object.specializations) then
            local spec = object.spec_baler
            local func = noOperation
            if spec and false == spec.nonStopBaling then
                func = getBalerAllowDriveAndMaxSpeed
            elseif spec and true == spec.nonStopBaling then
                func = getBalerAllowDriveAndMaxSpeed_NonStopBaling
            end
            table.insert(self.balers, { object=object, func=func })
        end
    end

    addIfHasSpecialization(self.vehicle)
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
end

function AIDriveStrategyFollowBaler:update(dt)
end

function AIDriveStrategyFollowBaler:getDriveData(dt, vX, vY, vZ)
	local maxSpeed = math.huge
	for _, baler in pairs(self.balers) do
        local allowedToDrive, maxSpeedTemp = baler.func(self, baler.object, dt)
        if not allowedToDrive then
            return nil, nil, true, 0, 0
        end
        maxSpeed = math.min(maxSpeed, maxSpeedTemp)
	end

    return nil, nil, true, maxSpeed, math.huge
end
