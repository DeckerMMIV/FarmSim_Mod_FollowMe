AIDriveStrategyFollowVehicle = {}
local AIDriveStrategyFollowVehicle_mt = Class(AIDriveStrategyFollowVehicle, AIDriveStrategy)

function AIDriveStrategyFollowVehicle.new(customMt)
    if customMt == nil then
      customMt = AIDriveStrategyFollowVehicle_mt
    end
    local self = AIDriveStrategy.new( customMt )
    self.vehicleToFollow = nil
    return self
end

function AIDriveStrategyFollowVehicle:delete()
    AIDriveStrategyFollowVehicle:superClass().delete(self)
end

function AIDriveStrategyFollowVehicle:setVehicleToFollow(vehicleToFollow)
    self.vehicleToFollow = vehicleToFollow
end

function AIDriveStrategyFollowVehicle:setAIVehicle(vehicle)
    AIDriveStrategyFollowVehicle:superClass().setAIVehicle(self, vehicle)

    local dx, _, dz = 0,0,1
    self.vehicle.aiDriveDirection = { dx, dz }

    local x, _, z = getWorldTranslation(self.vehicle:getAIDirectionNode())
    self.vehicle.aiDriveTarget = { x, z }
end

function AIDriveStrategyFollowVehicle:update(dt)
end

function AIDriveStrategyFollowVehicle:getDriveData(dt, vX, vY, vZ)
    --log("AIDriveStrategyFollowVehicle:getDriveData ",dt," ",vX," ",vY," ",vZ)

    local vehicle = self.vehicle
    local vehicleSpec = getSpec(vehicle)

    local leader = vehicleSpec.vehicleToFollow
    if nil == leader then
      return nil,nil,nil,-1,0 -- Using negative max-speed for indicating AI needs to stop due to error
    end
    local leaderSpec = getSpec(leader)

    -- actual target
    local tX,tZ
    --
    local isAllowedToDrive  = true
    local distanceToStop    = vehicleSpec.distanceFB>=0 and -vehicleSpec.distanceFB or 0
    local keepInFrontMeters = vehicleSpec.distanceFB< 0 and -vehicleSpec.distanceFB or 0
    local maxSpeed = 0
    local steepTurnAngle = false
    --
    local crumbIndexDiff = leaderSpec.dropperCurrentCount - vehicleSpec.followingCurrentCount
    --
    if crumbIndexDiff >= FollowVehicle.MAX_TRAIL_ENTRIES then
        -- Circular-array have "circled" once, and this follower did not move fast enough.
        return nil,nil,nil,-1,0 -- Using negative max-speed for indicating AI needs to stop due to error
    elseif crumbIndexDiff > 0 then
        -- Following crumbs...
        local crumbT = leader:getTrailDrop(vehicleSpec.followingCurrentCount)
        local crumbN = leader:getTrailDrop(vehicleSpec.followingCurrentCount + 1)
        maxSpeed = math.max(5, (crumbT.maxSpeed + crumbN.maxSpeed) / 2)
        --
        local targetX,_,targetZ = unpack(crumbT.position)
        local targetRotX,targetRotZ = leader:getTrailDropDirection(vehicleSpec.followingCurrentCount)
        -- Apply offset
        local sideOffset = vehicleSpec.offsetLR * (crumbT.followersOffsetPct or 1.0)
        tX = targetX - targetRotZ * sideOffset
        tZ = targetZ + targetRotX * sideOffset
        --
        local dx,dz = tX - vX, tZ - vZ
        local tDist = MathUtil.vector2Length(dx,dz)

        -- When distance is 5 or less to target, lerp towards next target
        if tDist <= 5 then
            local nextTargetX,_,nextTargetZ = unpack(crumbN.position)
            --local nextTargetRotX,_,nextTargetRotZ = unpack(crumbN.direction)
            local nextTargetRotX,nextTargetRotZ = leader:getTrailDropDirection(vehicleSpec.followingCurrentCount + 1)
            local sideOffset = vehicleSpec.offsetLR * (crumbN.followersOffsetPct or 1.0)
            local ntX = nextTargetX - nextTargetRotZ * sideOffset
            local ntZ = nextTargetZ + nextTargetRotX * sideOffset
            --
            local alpha = 1 - tDist/5
            tX = MathUtil.lerp(tX, ntX, alpha)
            tZ = MathUtil.lerp(tZ, ntZ, alpha)
        elseif tDist > 3 * FollowVehicle.MAX_DISTANCE_BETWEEN_DROPS then
            -- Something very wrong happened, as distance is x3 more than the max distance between drops.
            -- Maybe the turning-angle calculation have gone wrong, so better stop vehicle.
            return nil,nil,nil,-2,0 -- Using negative max-speed for indicating AI needs to stop due to error
        end

        --
        local trAngle = math.atan2(targetRotX,targetRotZ)
        local nz = dx * math.sin(trAngle) + dz * math.cos(trAngle)
        --steepTurnAngle = (tDist < 15 and (nz / tDist) < 0.8)

        -- already in front of crumb?
        -- or close enough to crumb?
        if (nz < 0)
        or (tDist <= 1)
        then
            -- Go to next crumb
            vehicleSpec.followingCurrentCount = vehicleSpec.followingCurrentCount + 1
        end

        local leaderLastTrailDrop = leader:getLastTrailDrop()
        local lX,_,lZ = getWorldTranslation(leader:getAISteeringNode())
        local leaderDistanceToLastTrailDrop = MathUtil.vector2Length(lX - leaderLastTrailDrop.position[1], lZ - leaderLastTrailDrop.position[3])
        local leaderDistanceDriven = (leaderDistanceToLastTrailDrop + leaderLastTrailDrop.drivenDistance)
        local followerDistanceToLeader = leaderDistanceDriven - crumbT.drivenDistance

        distanceToStop = distanceToStop + followerDistanceToLeader
        --isAllowedToDrive = isAllowedToDrive and (distanceToStop > 0)
    end
    --
    if crumbIndexDiff <= 0 then
        -- Following leader directly...
        local lNode         = leader:getAISteeringNode()
        local lx,ly,lz      = getWorldTranslation(lNode)
        local lrx,lry,lrz   = localDirectionToWorld(lNode, 0,0,1)

        maxSpeed = math.max(5, leader.lastSpeed * 3600) -- only consider forward movement.

        -- leader-target adjust with offset
        local sideOffset = vehicleSpec.offsetLR * leader:getCurrentSideOffsetModifier()
        tX = lx - lrz * sideOffset + lrx * keepInFrontMeters
        tZ = lz + lrx * sideOffset + lrz * keepInFrontMeters

        -- Rotate to see if the target is still "in front of us"
        local dx,dz = tX - vX, tZ - vZ
        local trAngle = math.atan2(lrx,lrz)
        local nz = dx * math.sin(trAngle) + dz * math.cos(trAngle)

        distanceToStop = distanceToStop + MathUtil.vector2Length(dx,dz)
        isAllowedToDrive = isAllowedToDrive and (nz > 0) --and (distanceToStop > 0)
    else
        distanceToStop = distanceToStop + keepInFrontMeters
    end

    isAllowedToDrive = isAllowedToDrive and (distanceToStop > 0)

    if isAllowedToDrive then
      -- if steepTurnAngle then
      --   maxSpeed = math.min(10, maxSpeed)
      -- else
        local curSpeed = math.max(1, (vehicle.lastSpeed * 3600))
        maxSpeed = maxSpeed * (1 + math.min(1, (distanceToStop / curSpeed)))
      -- end
    end

    if (not isAllowedToDrive) or (maxSpeed < 0.1) then
      maxSpeed = 0
    end

    --
    local dx, _, dz = localDirectionToWorld(vehicle:getAIDirectionNode(), 0, 0, 1)
		local length = MathUtil.vector2Length(dx, dz)
    self.vehicle.aiDriveDirection = { dx / length, dz / length }
    self.vehicle.aiDriveTarget = { tX, tZ }

    --
    return tX, tZ, true, maxSpeed, math.max(0, distanceToStop)
end
