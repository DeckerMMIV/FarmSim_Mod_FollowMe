
AIJobTypeManager.loadMapData = Utils.appendedFunction(AIJobTypeManager.loadMapData, function(self)
	self:registerJobType("MOD_FOLLOW_VEHICLE", "(mod) Follow Me", AIJobFollowVehicle)
end)
