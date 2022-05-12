AITaskFollowVehicle = {}
local AITaskFollowVehicle_mt = Class(AITaskFollowVehicle, AITask)

function AITaskFollowVehicle.new(isServer, job, customMt)
	local self = AITask.new(isServer, job, customMt or AITaskFollowVehicle_mt)
	self.vehicle = nil
	self.vehicleToFollow = nil

	return self
end

function AITaskFollowVehicle:reset()
	self.vehicle = nil

	AITaskFollowVehicle:superClass().reset(self)
end

function AITaskFollowVehicle:update(dt)
end

function AITaskFollowVehicle:setVehicle(vehicle)
	self.vehicle = vehicle
end

function AITaskFollowVehicle:setVehicleToFollow(vehicle)
	self.vehicleToFollow = vehicle
end

function AITaskFollowVehicle:start()
	if self.isServer then
		self.vehicle:startFollowVehicle(self.vehicleToFollow)
	end

	AITaskFollowVehicle:superClass().start(self)
end

function AITaskFollowVehicle:stop()
	AITaskFollowVehicle:superClass().stop(self)

	if self.isServer then
		self.vehicle:stopFollowVehicle()
	end
end
