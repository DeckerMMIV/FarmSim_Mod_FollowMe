AIMessageErrorFollowerStopped = {}
local AIMessageErrorFollowerStopped_mt = Class(AIMessageErrorFollowerStopped, AIMessage)

function AIMessageErrorFollowerStopped.new(customMt)
	local self = AIMessage.new(customMt or AIMessageErrorFollowerStopped_mt)
	return self
end

local FOLLOW_AIERROR_CHASER_STOPPED = g_i18n:getText("FOLLOW_AIERROR_CHASER_STOPPED")
function AIMessageErrorFollowerStopped:getMessage()
	return FOLLOW_AIERROR_CHASER_STOPPED
end
