AIDriveStrategyFollowBaleLoader = {}
local AIDriveStrategyFollowBaleLoader_mt = Class(AIDriveStrategyFollowBaleLoader, AIDriveStrategy)

AIDriveStrategyFollowBaleLoader.ACTION_STOP_FOLLOWING = 1
AIDriveStrategyFollowBaleLoader.ACTION_CONTINUE = 2
AIDriveStrategyFollowBaleLoader.ACTION_EMPTY_BALELOADER = 3

AIDriveStrategyFollowBaleLoader.ACTION_MAXVALUE = 3

function AIDriveStrategyFollowBaleLoader.new(reconstructionData, customMt)
    local self = AIDriveStrategy.new(reconstructionData, customMt or AIDriveStrategyFollowBaleLoader_mt)
    self.baleLoaders = {}
    self:setActionWhenFull(AIDriveStrategyFollowBaleLoader.ACTION_STOP_FOLLOWING)

    return self
end

local whenGrappingOperation = function(self, baleLoader, dt)
    local spec = baleLoader.spec_baleLoader
    if spec.grabberIsMoving or spec.grabberMoveState ~= nil then
        -- Slower driving, while grapping bale
        return true, 2
    end
    return true, math.huge
end

local whenFullOperation = function(self, baleLoader, dt)
    local spec = baleLoader.spec_baleLoader

    if self.actionWhenFull == AIDriveStrategyFollowBaleLoader.ACTION_EMPTY_BALELOADER then
        spec.lastPickupTime = 0 -- Overrule the delay of getIsAutomaticBaleUnloadingAllowed()
        if baleLoader:getIsAutomaticBaleUnloadingInProgress() then
            if spec.emptyState > BaleLoader.EMPTY_NONE then
                if spec.emptyState < BaleLoader.EMPTY_WAIT_TO_DROP then
                    -- No driving while raising/opening bale-loader for unloading
                    return false, 0
                end
                -- 
                spec.transportPositionAfterUnloading = false
                -- Slow driving, while finishing unloading
                return true, 2
            end
        elseif baleLoader:getIsAutomaticBaleUnloadingAllowed() then
            if baleLoader:getFillUnitFreeCapacity(spec.fillUnitIndex) == 0 then
                baleLoader:startAutomaticBaleUnloading()
                -- No driving while unloading
                return false, 0
            end
        elseif not spec.isInWorkPosition then
            baleLoader:doStateChange(BaleLoader.CHANGE_MOVE_TO_WORK)
        end
    else
        if baleLoader:getFillUnitFreeCapacity(spec.fillUnitIndex) > 0 then
            self.whenFullTimeout = 0
        else
            -- TODO - maybe use getIsBaleLoaderFoldingPlaying ?
            if self.whenFullTimeout < 5 then
                self.whenFullTimeout = self.whenFullTimeout + 1
                return false, 0
            end
            if spec.isInWorkPosition and not spec.grabberIsMoving then
                baleLoader:doStateChange(BaleLoader.CHANGE_MOVE_TO_TRANSPORT)
            end
            if spec.grabberIsMoving then
                -- Wait for grapper to be folded, so keep vehicle's engine running, but disallow driving
                return false, 0
            end
            if self.actionWhenFull == AIDriveStrategyFollowBaleLoader.ACTION_STOP_FOLLOWING then
                -- Report a negative maxSpeed back, indicating this strategy wants to stop the vehicle
                return true, -1
            end
            -- Fall through to last return statement, which allows continuing driving
        end
    end

    return true, math.huge
end

function AIDriveStrategyFollowBaleLoader:setAIVehicle(vehicle)
    AIDriveStrategyFollowBaleLoader:superClass().setAIVehicle(self, vehicle)

    -- Sanity check, that vanilla game's constants are there
    if nil == BaleLoader.EMPTY_NONE
    or nil == BaleLoader.EMPTY_WAIT_TO_DROP
    or not (BaleLoader.EMPTY_NONE < BaleLoader.EMPTY_WAIT_TO_DROP)
    or nil == BaleLoader.CHANGE_MOVE_TO_WORK
    or nil == BaleLoader.CHANGE_MOVE_TO_TRANSPORT
    then
        return false
    end

    local funcCheckWhenGrapping = function(object)
        if SpecializationUtil.hasSpecialization(BaleLoader, object.specializations) then
            return whenGrappingOperation
        end
        return nil
    end

    local funcCheckWhenFull = function(object)
        if SpecializationUtil.hasSpecialization(BaleLoader, object.specializations) then
            local spec = object.spec_baleLoader
            if spec
            and spec.isInWorkPosition
            and nil ~= object.getIsAutomaticBaleUnloadingAllowed and nil ~= object.getIsAutomaticBaleUnloadingInProgress and nil ~= object.startAutomaticBaleUnloading
            and nil ~= object.doStateChange and nil ~= object.getIsBaleGrabbingAllowed
            and nil ~= object.getFillUnitFreeCapacity
            then
                -- If FollowMe activated on a BaleLoader that has free capacity and allow bale grabbing,
                -- then use detection for when to automatically unload.
                if object:getFillUnitFreeCapacity(spec.fillUnitIndex) >= 1
                and object:getIsBaleGrabbingAllowed()
                then
                    return whenFullOperation
                end
                -- Otherwise instruct it into transport-position, and set the actionWhenFull to continue driving,
                -- as player likely wants to just follow a leader, without (or can't) picking up bales.
                object:doStateChange(BaleLoader.CHANGE_MOVE_TO_TRANSPORT)
                self:setActionWhenFull(AIDriveStrategyFollowBaleLoader.ACTION_CONTINUE)
            end
        end
        return nil
    end

    local addIfHasSpecialization = function(object)
        local func = funcCheckWhenFull(object)
        if nil ~= func then
            table.insert(self.baleLoaders, { object=object, func=func })
        end
        func = funcCheckWhenGrapping(object)
        if nil ~= func then
            table.insert(self.baleLoaders, { object=object, func=func })
        end
    end

    for _, object in pairs(self.vehicle.childVehicles) do
        addIfHasSpecialization(object)
    end

    return (#self.baleLoaders > 0)
end

function AIDriveStrategyFollowBaleLoader:setActionWhenFull(value)
    value = value or self.actionWhenFull

    -- Wrap around if outside bounds
    if value < 1 then
        value = AIDriveStrategyFollowBaleLoader.ACTION_MAXVALUE
    elseif value > AIDriveStrategyFollowBaleLoader.ACTION_MAXVALUE then
        value = 1
    end

    self.actionWhenFull = value
    self.whenFullTimeout = 0
end

function AIDriveStrategyFollowBaleLoader:getActionWhenFull()
    return self.actionWhenFull
end

function AIDriveStrategyFollowBaleLoader:update(dt)
end

function AIDriveStrategyFollowBaleLoader:getDriveData(dt, vX, vY, vZ)
    local maxSpeed = math.huge
    for _, baleLoader in pairs(self.baleLoaders) do
        local allowedToDrive, maxSpeedTemp = baleLoader.func(self, baleLoader.object, dt)
        if not allowedToDrive then
            return nil, nil, true, maxSpeedTemp, 0
        end
        maxSpeed = math.min(maxSpeed, maxSpeedTemp)
    end

    return nil, nil, true, maxSpeed, math.huge
end
