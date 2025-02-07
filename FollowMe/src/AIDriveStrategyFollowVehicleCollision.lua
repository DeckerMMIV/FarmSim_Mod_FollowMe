AIDriveStrategyFollowVehicleCollision = {}
local AIDriveStrategyFollowVehicleCollision_mt = Class(AIDriveStrategyFollowVehicleCollision, AIDriveStrategy)

function AIDriveStrategyFollowVehicleCollision.new(reconstructionData, customMt)
    local self = AIDriveStrategy.new(reconstructionData, customMt or AIDriveStrategyFollowVehicleCollision_mt)

    self.collisionHandler = AICollisionTriggerHandler.new()

    self.isBlocked = false
    self.hasStaticCollision = false
    self.hasStaticCollisionTimer = 0
    self.collisionDistance = math.huge

    self.lastMovingDirection = 1

    self.lastMaxSpeed = math.huge

    return self
end

function AIDriveStrategyFollowVehicleCollision:delete()
    AIDriveStrategyFollowVehicleCollision:superClass().delete(self)
end

function AIDriveStrategyFollowVehicleCollision:setAIVehicle(vehicle)
    AIDriveStrategyFollowVehicleCollision:superClass().setAIVehicle(self, vehicle)

    self.collisionHandler:init(vehicle, self)

    self.collisionHandler:setStaticCollisionCallback(function(hasStaticCollision)
        self.hasStaticCollision = hasStaticCollision
    end)

    self.collisionHandler:setIsBlockedCallback(function(isBlocked)
        self.isBlocked = isBlocked
    end)

    self.collisionHandler:setCollisionDistanceCallback(function(distance)
        -- Due to 'static collisions' seems to be frequent near 'not actually visible obstracles' (e.g. driving _on_ bridges), then
        -- if `dynamicHitPointDistance` exist in the collision-handler, then primarily use its value.
        if self.collisionHandler.dynamicHitPointDistance ~= nil then
            self.collisionDistance = self.collisionHandler.dynamicHitPointDistance
        else
            self.collisionDistance = distance
        end
    end)
end

function AIDriveStrategyFollowVehicleCollision:update(dt)
    self.collisionHandler:update(dt, self.lastMovingDirection)
end

function AIDriveStrategyFollowVehicleCollision:getDriveData(dt, vX, vY, vZ)
    local tX, tZ, moveForwards, maxSpeed, distanceToStop = nil, nil, true, math.huge, math.huge

    if self.isBlocked then
        if self.vehicle:getDistance() < 0 then
            -- When being told to follow in-front-of the leader, then ignore any blocks (e.g. leader is not a "blocking object")
            maxSpeed = math.min(maxSpeed, math.max(self.collisionDistance * 2, 5))
        else
            maxSpeed = 0
        end
    elseif self.collisionDistance ~= math.huge and moveForwards then
        -- For some reason the base-game's script regarding collision detection, "finds" collisions at bridges and similar 'not actually visible obstracles'.
        -- So if these are the 'static collisions' then "drive a bit faster" instead of completely slowing down.
        local lowestSpeed = self.hasStaticCollision and 10 or 1

        maxSpeed = math.min(maxSpeed, math.max(self.collisionDistance * 2, lowestSpeed))
    end
    self.lastMaxSpeed = maxSpeed

    return tX, tZ, moveForwards, maxSpeed, distanceToStop
end

function AIDriveStrategyFollowVehicleCollision:isColliding()
    return self.lastMaxSpeed < 0.1
end
