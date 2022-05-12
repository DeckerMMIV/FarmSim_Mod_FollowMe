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

local getBalerAllowDriveAndMaxSpeed = function(self, baler)
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
    
        return true, 2 + (freeFillLevel / self.slowDownFillLevel) * self.slowDownStartSpeed
    end

    return true, math.huge
end

local getBalerAllowDriveAndMaxSpeed_NonStopBaling = function(self, baler)
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
        -- elseif SpecializationUtil.hasSpecialization(BaleWrapper, object.specializations) then
        --     table.insert(self.balers, { object=object, func=noOperation })
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
        --local func = baler.func
        --if func then
        --    local allowedToDrive, maxSpeedTemp = func(self, baler.object)
            local allowedToDrive, maxSpeedTemp = baler.func(self, baler.object)
            if not allowedToDrive then
                return nil, nil, true, 0, 0
            end
            maxSpeed = math.min(maxSpeed, maxSpeedTemp)
        --end
	end

    return nil, nil, true, maxSpeed, math.huge
end
