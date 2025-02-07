AIJobFollowVehicle = {
	START_ERROR_LIMIT_REACHED = 1,
	START_ERROR_VEHICLE_DELETED = 2,
	START_ERROR_NO_PERMISSION = 3,
	START_ERROR_VEHICLE_IN_USE = 4
}
local AIJobFollowVehicle_mt = Class(AIJobFollowVehicle, AIJob)

function AIJobFollowVehicle.new(isServer, customMt)
	local self = AIJob.new(isServer, customMt or AIJobFollowVehicle_mt)
	self.followVehicleTask = AITaskFollowVehicle.new(isServer, self)

	self:addTask(self.followVehicleTask)

	self.vehicleParameter = AIParameterVehicle.new()
	self.followVehicleParameter = AIParameterVehicle.new()

	self:addNamedParameter("vehicle", self.vehicleParameter)
	self:addNamedParameter("followVehicle", self.followVehicleParameter)
	return self
end

function AIJobFollowVehicle:getPricePerMs()
	return 0.0001
end

function AIJobFollowVehicle:start(farmId)
	AIJobFollowVehicle:superClass().start(self, farmId)

	if self.isServer then
		local vehicle = self.vehicleParameter:getVehicle()
		vehicle:createAgent(self.helperIndex)
		vehicle:aiJobStarted(self, self.helperIndex, farmId)
	end
end

function AIJobFollowVehicle:stop(aiMessage)
	if self.isServer then
		local vehicle = self.vehicleParameter:getVehicle()
		vehicle:deleteAgent()
		vehicle:aiJobFinished()
	end

	AIJobFollowVehicle:superClass().stop(self, aiMessage)
end

function AIJobFollowVehicle:getIsAvailableForVehicle(vehicle)
	return vehicle:getCanStartFollowVehicle()
 end

function AIJobFollowVehicle:getTitle()
	return "Following Vehicle"
end

function AIJobFollowVehicle:applyCurrentState(vehicle, mission, farmId, isDirectStart, vehicleToFollow)
	AIJobFollowVehicle:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
	self.vehicleParameter:setVehicle(vehicle)
	self.followVehicleParameter:setVehicle(vehicleToFollow)
end

function AIJobFollowVehicle:setValues()
	self:resetTasks()
	self.followVehicleTask:setVehicle(self.vehicleParameter:getVehicle())
	self.followVehicleTask:setVehicleToFollow(self.followVehicleParameter:getVehicle())
end

function AIJobFollowVehicle:validate(farmId)
	self:setParameterValid(true)

	local isVehicleValid, errorMessageVehicle = self.vehicleParameter:validate()
	if not isVehicleValid then
		self.vehicleParameter:setIsValid(false)
	end

	local isFollowVehicleValid, errorMessageFollowVehicle = self.followVehicleParameter:validate()
	if not isFollowVehicleValid then
		self.followVehicleParameter:setIsValid(false)
	end

	local isValid = isVehicleValid and isFollowVehicleValid
	local errorMessage = errorMessageVehicle or errorMessageFollowVehicle

	return isValid, errorMessage
end

function AIJobFollowVehicle:getDescription()
	return "Following Vehicle"
end

function AIJobFollowVehicle:getIsStartable(connection)
	if g_currentMission.aiSystem:getAILimitedReached() then
		return false, AIJobFollowVehicle.START_ERROR_LIMIT_REACHED
	end

	local vehicle = self.vehicleParameter:getVehicle()
	if vehicle == nil then
		return false, AIJobFollowVehicle.START_ERROR_VEHICLE_DELETED
	end

	if not g_currentMission:getHasPlayerPermission("hireAssistant", connection, vehicle:getOwnerFarmId()) then
		return false, AIJobFollowVehicle.START_ERROR_NO_PERMISSION
	end

	if vehicle:getIsInUse(connection) then
		return false, AIJobFollowVehicle.START_ERROR_VEHICLE_IN_USE
	end

	return true, AIJob.START_SUCCESS
end

function AIJobFollowVehicle.getIsStartErrorText(state)
	if state == AIJobFollowVehicle.START_ERROR_LIMIT_REACHED then
		return g_i18n:getText("ai_startStateLimitReached")
	elseif state == AIJobFollowVehicle.START_ERROR_VEHICLE_DELETED then
		return g_i18n:getText("ai_startStateVehicleDeleted")
	elseif state == AIJobFollowVehicle.START_ERROR_NO_PERMISSION then
		return g_i18n:getText("ai_startStateNoPermission")
	elseif state == AIJobFollowVehicle.START_ERROR_VEHICLE_IN_USE then
		return g_i18n:getText("ai_startStateVehicleInUse")
	end

	return g_i18n:getText("ai_startStateSuccess")
end
