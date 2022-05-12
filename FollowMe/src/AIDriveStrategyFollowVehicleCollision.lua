AIDriveStrategyFollowVehicleCollision = {}
local AIDriveStrategyFollowVehicleCollision_mt = Class(AIDriveStrategyFollowVehicleCollision, AIDriveStrategyCollision)

function AIDriveStrategyFollowVehicleCollision.new(driveStrategyStraight, customMt)
	if customMt == nil then
		customMt = AIDriveStrategyFollowVehicleCollision_mt
	end

	local self = AIDriveStrategyCollision.new(driveStrategyStraight, customMt)
	return self
end

function AIDriveStrategyFollowVehicleCollision:generateTriggerPath(vehicle, trigger)
	if vehicle ~= self.vehicle then
		-- Ignore attached implements that are in their folded position, in attempt at reducing the amount of false "positive collisions" for Follow Vehicle
		if nil ~= vehicle.getIsUnfolded and false == vehicle:getIsUnfolded() then
			trigger.isValid = false
			return
		end
	end

	-- Attempt at causing "follower to get just a bit closer", when leader is doing sharp turns, and follower is driving right next to it.
	if trigger.hasCollision and self.vehicle:getLastSpeed() < 0.5 then
		trigger.modFV_Timeout = Utils.getNoNil(trigger.modFV_Timeout, 0) + 1
		if trigger.modFV_Timeout > 10 then
			trigger.modFV_Timeout = nil
			trigger.hasCollision = false
		end
	end

	--
	AIDriveStrategyFollowVehicleCollision:superClass().generateTriggerPath(self, vehicle, trigger)
end

function AIDriveStrategyFollowVehicleCollision:setHasCollision(state)
	if state ~= self.lastHasCollision then
		self.lastHasCollision = state

		if g_server ~= nil then
			-- Use different event for Follow Vehicle, to make it not; turn off its implements and display a notification
			g_server:broadcastEvent(AIVehicleIsWaitingEvent.new(self.vehicle, state), true, nil, self.vehicle)
		end
	end
end
