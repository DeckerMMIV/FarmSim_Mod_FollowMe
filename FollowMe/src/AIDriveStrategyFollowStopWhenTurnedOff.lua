AIDriveStrategyFollowStopWhenTurnedOff = {}
local AIDriveStrategyFollowStopWhenTurnedOff_mt = Class(AIDriveStrategyFollowStopWhenTurnedOff, AIDriveStrategy)

AIDriveStrategyFollowStopWhenTurnedOff.ACTION_STOP_FOLLOWING = 1
AIDriveStrategyFollowStopWhenTurnedOff.ACTION_CONTINUE = 2

AIDriveStrategyFollowStopWhenTurnedOff.ACTION_MAXVALUE = 2

function AIDriveStrategyFollowStopWhenTurnedOff.new(reconstructionData, customMt)
    local self = AIDriveStrategy.new(reconstructionData, customMt or AIDriveStrategyFollowStopWhenTurnedOff_mt)
    self.activeImplements = {}
    self:setActionWhenFull(AIDriveStrategyFollowStopWhenTurnedOff.ACTION_STOP_FOLLOWING)
    return self
end

local allowDriveWhenTurnedOnAndLowered = function(self, implement)
    if self.actionWhenFull == AIDriveStrategyFollowStopWhenTurnedOff.ACTION_CONTINUE then
        return true
    end
    return implement:getIsTurnedOn() and implement:getIsLowered()
end

local allowDriveWhenTurnedOn = function(self, implement)
    if self.actionWhenFull == AIDriveStrategyFollowStopWhenTurnedOff.ACTION_CONTINUE then
        return true
    end
    return implement:getIsTurnedOn()
end

function AIDriveStrategyFollowStopWhenTurnedOff:setAIVehicle(vehicle)
    AIDriveStrategyFollowStopWhenTurnedOff:superClass().setAIVehicle(self, vehicle)

    local addIfHasSpecialization = function(object, specialization)
        if SpecializationUtil.hasSpecialization(specialization, object.specializations) then
            local func = nil
            if nil ~= object.getIsTurnedOn then
                if nil ~= object.getIsLowered and (nil ~= object.getAINeedsLowering and object:getAINeedsLowering()) then
                    if object:getIsTurnedOn() and object:getIsLowered() then
                        -- When implement is already turned on and lowered, then allow driving... until it turns off or raises (which usually indicates it has become full)
                        func = allowDriveWhenTurnedOnAndLowered
                    end
                elseif object:getIsTurnedOn() then
                    -- When implement is already turned on, then allow driving... until it turns off (which usually indicates it has become full)
                    func = allowDriveWhenTurnedOn
                end
            end
            if nil ~= func then
                table.insert(self.activeImplements, { object=object, func=func })
            end
        end
    end

    for _,specialization in ipairs({Combine, ForageWagon, StonePicker}) do
        for _, object in pairs(self.vehicle.childVehicles) do
            addIfHasSpecialization(object, specialization)
        end
    end

    return (#self.activeImplements > 0)
end

function AIDriveStrategyFollowStopWhenTurnedOff:setActionWhenFull(value)
    value = value or self.actionWhenFull

    -- Wrap around if outside bounds
    if value < 1 then
        value = AIDriveStrategyFollowStopWhenTurnedOff.ACTION_MAXVALUE
    elseif value > AIDriveStrategyFollowStopWhenTurnedOff.ACTION_MAXVALUE then
        value = 1
    end

    self.actionWhenFull = value
end

function AIDriveStrategyFollowStopWhenTurnedOff:getActionWhenFull()
    return self.actionWhenFull
end

function AIDriveStrategyFollowStopWhenTurnedOff:update(dt)
end

function AIDriveStrategyFollowStopWhenTurnedOff:getDriveData(dt, vX, vY, vZ)
    for _, implement in pairs(self.activeImplements) do
        local allowedToDrive = implement.func(self, implement.object)
        if not allowedToDrive then
            -- Report a negative maxSpeed back, indicating this strategy wants to stop the vehicle
            return nil, nil, true, -1, 0
        end
    end

    return nil, nil, true, math.huge, math.huge
end
