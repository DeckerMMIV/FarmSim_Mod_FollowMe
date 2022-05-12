AIVehicleIsWaitingEvent = {}
local AIVehicleIsWaitingEvent_mt = Class(AIVehicleIsWaitingEvent, Event)

function AIVehicleIsWaitingEvent.emptyNew()
	local self = Event.new(AIVehicleIsWaitingEvent_mt)
	return self
end

function AIVehicleIsWaitingEvent.new(object, isWaiting)
	local self = AIVehicleIsWaitingEvent.emptyNew()
	self.object = object
	self.isWaiting = isWaiting

	return self
end

function AIVehicleIsWaitingEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.isWaiting = streamReadBool(streamId)

	self:run(connection)
end

function AIVehicleIsWaitingEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.isWaiting)
end

function AIVehicleIsWaitingEvent:run(connection)
	if self.object ~= nil and self.object:getIsSynchronized() then
		if self.isWaiting then
			self.object:aiWaiting()
		else
			self.object:aiResume()
		end
	end
end
