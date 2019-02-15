--[[

This is an attempt at being able to add other/additional 'driving strategies' to the AIVehicle specialization.
FollowMe uses this, to "persuade" AIVehicle:startAIVehicle() to use a FollowMe-'driving strategy'.

But this LUA file is intended to be "mod agnostic" or "mod reentrant", so other mods can include it too, yet
even if multiple mods load this LUA file, the overrides will only be done 'once'.

--]]

--
--

local thisVersion = 20190215

local function applyOverrides(clazz, versionField, applyFunc)
  if nil == clazz[versionField] then
    clazz[versionField] = thisVersion
    applyFunc()
  elseif clazz[versionField] < thisVersion then
    print("WARNING: Discovered older `AIVehicle_Override.lua` from other mod. - This mod has a newer version; " .. g_currentModName)
  end
end

--
--

applyOverrides(AIVehicleSetStartedEvent, "mod_AddedForcedDrivingStrategy", function()

  AIVehicleSetStartedEvent.new = Utils.overwrittenFunction(AIVehicleSetStartedEvent.new, function(dummySelf, superFunc, object, reason, isStarted, helper, startedFarmId)
    local self = superFunc(dummySelf, object, reason, isStarted, helper, startedFarmId)
    self.mod_ForcedDrivingStrategyName = object.spec_aiVehicle.mod_ForcedDrivingStrategyName
    return self
  end)

  AIVehicleSetStartedEvent.writeStream = Utils.overwrittenFunction(AIVehicleSetStartedEvent.writeStream, function(self, superFunc, streamId, connection)
    if nil ~= self.mod_ForcedDrivingStrategyName
    and "" ~= self.mod_ForcedDrivingStrategyName then
      streamWriteBool(streamId, true)
      streamWriteString(streamId, self.mod_ForcedDrivingStrategyName)
    else
      streamWriteBool(streamId, false)
    end
    superFunc(self, streamId, connection)
  end)

  AIVehicleSetStartedEvent.readStream = Utils.overwrittenFunction(AIVehicleSetStartedEvent.readStream, function(self, superFunc, streamId, connection)
    if streamReadBool(streamId) then
      self.mod_ForcedDrivingStrategyName = streamReadString(streamId)
    else
      self.mod_ForcedDrivingStrategyName = nil
    end
    superFunc(self, streamId, connection)
  end)

  AIVehicleSetStartedEvent.run = Utils.overwrittenFunction(AIVehicleSetStartedEvent.run, function(self, superFunc, connection)
    self.object.spec_aiVehicle.mod_ForcedDrivingStrategyName = self.mod_ForcedDrivingStrategyName
    superFunc(self, connection)
  end)

end)

--
--

applyOverrides(AIVehicle, "mod_AddedForcedDrivingStrategy", function()

  AIVehicle.onWriteStream = Utils.overwrittenFunction(AIVehicle.onWriteStream, function(self, superFunc, streamId, connection)
    if nil ~= self.spec_aiVehicle.mod_ForcedDrivingStrategyName
    and "" ~= self.spec_aiVehicle.mod_ForcedDrivingStrategyName then
      streamWriteBool(streamId, true)
      streamWriteString(streamId, self.spec_aiVehicle.mod_ForcedDrivingStrategyName)
    else
      streamWriteBool(streamId, false)
    end
    superFunc(self, streamId, connection)
  end)

  AIVehicle.onReadStream = Utils.overwrittenFunction(AIVehicle.onReadStream, function(self, superFunc, streamId, connection)
    if streamReadBool(streamId) then
      self.spec_aiVehicle.mod_ForcedDrivingStrategyName = streamReadString(streamId)
    else
      self.spec_aiVehicle.mod_ForcedDrivingStrategyName = nil
    end
    superFunc(self, streamId, connection)
  end)

  AIVehicle.startAIVehicle = Utils.overwrittenFunction(AIVehicle.startAIVehicle, function(self, superFunc, helperIndex, noEventSend, startedFarmId, forcedDrivingStrategyName)
    if nil ~= forcedDrivingStrategyName then
      self.spec_aiVehicle.mod_ForcedDrivingStrategyName = forcedDrivingStrategyName
    end
    superFunc(self, helperIndex, noEventSend, startedFarmId, forcedDrivingStrategyName)
  end)

  AIVehicle.stopAIVehicle = Utils.appendedFunction(AIVehicle.stopAIVehicle, function(self, reason)
    self.spec_aiVehicle.mod_ForcedDrivingStrategyName = nil
  end)

end)

--
--

applyOverrides(Vehicle, "mod_AddedCheckSpeedLimitOnlyIfWorking", function()

  Vehicle.getSpeedLimit = Utils.overwrittenFunction(Vehicle.getSpeedLimit, function(self, superFunc, onlyIfWorking)
    if  nil == onlyIfWorking
    and nil ~= self.spec_aiVehicle
    then
      onlyIfWorking = self.spec_aiVehicle.mod_CheckSpeedLimitOnlyIfWorking
    end
    return superFunc(self, onlyIfWorking)
  end)

end)
