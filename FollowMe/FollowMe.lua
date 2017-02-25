--
-- Follow Me
--
-- @author  Decker_MMIV (DCK)
-- @contact fs-uk.com, modcentral.co.uk, forum.farming-simulator.com
-- @date    2016-11-xx
--

FollowMe = {};
--
local modItem = ModsUtil.findModItemByModName(g_currentModName);
FollowMe.version = (modItem and modItem.version) and modItem.version or "?.?.?";
--

FollowMe.wagePaymentMultiplier = 0.2

--
FollowMe.isInitialized = false
--
FollowMe.cMinDistanceBetweenDrops        =   5;   -- TODO, make configurable
FollowMe.cBreadcrumbsMaxEntries          = 100;   -- TODO, make configurable
FollowMe.cMstimeBetweenDrops             =  40;   -- TODO, make configurable
FollowMe.debugDraw = {}

FollowMe.COMMAND_NONE           = 0
FollowMe.COMMAND_START          = 1
FollowMe.COMMAND_WAITRESUME     = 2
FollowMe.COMMAND_STOP           = 3
FollowMe.NUM_BITS_COMMAND = 2

FollowMe.STATE_NONE             = 0
FollowMe.STATE_STARTING         = 1
FollowMe.STATE_FOLLOWING        = 2
FollowMe.STATE_WAITING          = 3
FollowMe.STATE_STOPPING         = 4
FollowMe.NUM_BITS_STATE   = 3

FollowMe.REASON_NONE            = 0
FollowMe.REASON_USER_ACTION     = 1
FollowMe.REASON_NO_TRAIL_FOUND  = 2    
FollowMe.REASON_TOO_FAR_BEHIND  = 3
FollowMe.REASON_LEADER_REMOVED  = 4
FollowMe.REASON_ENGINE_STOPPED  = 5
FollowMe.REASON_ALREADY_AI      = 6
FollowMe.NUM_BITS_REASON  = 3


-- For debugging
local function log(...)
    if true then
        local txt = ""
        for idx = 1,select("#", ...) do
            txt = txt .. tostring(select(idx, ...))
        end
        print(string.format("%7ums FollowMe.LUA ", (g_currentMission ~= nil and g_currentMission.time or 0)) .. txt);
    end
end;


-- Support-function, that I would like to see be added to InputBinding class.
-- Maybe it is, I just do not know what its called.
local function getKeyIdOfModifier(binding)
    if InputBinding.actions[binding] == nil then
        return nil;  -- Unknown input-binding.
    end;
    if table.getn(InputBinding.actions[binding].keys1) <= 1 then
        return nil; -- Input-binding has only one or zero keys. (Well, in the keys1 - I'm not checking keys2)
    end;
    -- Check if first key in key-sequence is a modifier key (LSHIFT/RSHIFT/LCTRL/RCTRL/LALT/RALT)
    if Input.keyIdIsModifier[ InputBinding.actions[binding].keys1[1] ] then
        return InputBinding.actions[binding].keys1[1]; -- Return the keyId of the modifier key
    end;
    return nil;
end

function FollowMe.initialize()
    if FollowMe.isInitialized then
        return;
    end;
    FollowMe.isInitialized = true;

    --
    local removeFromString = function(src, toRemove)
        if (type(src)==type({})) then
            local tmp = ""
            for _,s in pairs(src) do
                tmp = tmp.." "..tostring(s)
            end
            src = tmp
        end

        local srcArr = Utils.splitString(" ", src:upper());
        local remArr = Utils.splitString(" ", toRemove:upper());
        local result = "";
        for i,p in ipairs(srcArr) do
            if i>1 then
                local found=false;
                for _,r in pairs(remArr) do
                    if p == r then
                        found=true
                        break;
                    end
                end
                if not found then
                    result = result .. (result~="" and " " or "") .. p;
                end;
            end;
        end;
        return result;
    end;
    
    -- Get the modifier-key (if any) from input-binding
    FollowMe.keyModifier_FollowMeMyToggle = getKeyIdOfModifier(InputBinding.FollowMeMyToggle);
    if nil == FollowMe.keyModifier_FollowMeMyToggle then
        log("WARNING: Modifier-key(1) is nil!");
    end
    
    -- Test that these four use the same modifier-key
       FollowMe.keyModifier_FollowMeMy  = getKeyIdOfModifier(InputBinding.FollowMeMyToggle )
    if FollowMe.keyModifier_FollowMeMy ~= getKeyIdOfModifier(InputBinding.FollowMeMyPause  )
    or FollowMe.keyModifier_FollowMeMy ~= getKeyIdOfModifier(InputBinding.FollowMeMyDistDec)
    or FollowMe.keyModifier_FollowMeMy ~= getKeyIdOfModifier(InputBinding.FollowMeMyDistInc)
    or FollowMe.keyModifier_FollowMeMy ~= getKeyIdOfModifier(InputBinding.FollowMeMyOffsDec)
    or FollowMe.keyModifier_FollowMeMy ~= getKeyIdOfModifier(InputBinding.FollowMeMyOffsInc)
    or FollowMe.keyModifier_FollowMeMy ~= getKeyIdOfModifier(InputBinding.FollowMeMyOffsTgl)
    then
        -- warning!
        log("WARNING: Not all action-keys(1) use the same modifier-key!");
    end;

    -- Build a string, that is much shorter than what InputBinding.getKeyNamesOfDigitalAction() returns
    FollowMe.keys_FollowMeMy = FollowMe.keyModifier_FollowMeMy ~= nil and getKeyName(FollowMe.keyModifier_FollowMeMy) or "";
    FollowMe.keys_FollowMeMy = FollowMe.keys_FollowMeMy:upper();
    local shortKeys = removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeMyToggle ), FollowMe.keys_FollowMeMy)
            .. "," .. removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeMyPause  ), FollowMe.keys_FollowMeMy)
            .. "," .. removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeMyDistDec), FollowMe.keys_FollowMeMy)
            .. "/" .. removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeMyDistInc), FollowMe.keys_FollowMeMy)
            .. "," .. removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeMyOffsDec), FollowMe.keys_FollowMeMy)
            .. "/" .. removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeMyOffsInc), FollowMe.keys_FollowMeMy)
            .. "," .. removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeMyOffsTgl), FollowMe.keys_FollowMeMy);
    FollowMe.keys_FollowMeMy = FollowMe.keys_FollowMeMy .. " " .. shortKeys;
    
    -- Test that these use the same modifier-key
    FollowMe.keyModifier_FollowMeFl = getKeyIdOfModifier(InputBinding.FollowMeFlStop);
    if nil == FollowMe.keyModifier_FollowMeFl then
        log("WARNING: Modifier-key(2) is nil!");
    end
    
    if FollowMe.keyModifier_FollowMeFl ~= getKeyIdOfModifier(InputBinding.FollowMeFlPause  )
    or FollowMe.keyModifier_FollowMeFl ~= getKeyIdOfModifier(InputBinding.FollowMeFlDistDec)
    or FollowMe.keyModifier_FollowMeFl ~= getKeyIdOfModifier(InputBinding.FollowMeFlDistInc)
    or FollowMe.keyModifier_FollowMeFl ~= getKeyIdOfModifier(InputBinding.FollowMeFlOffsDec)
    or FollowMe.keyModifier_FollowMeFl ~= getKeyIdOfModifier(InputBinding.FollowMeFlOffsInc)
    or FollowMe.keyModifier_FollowMeFl ~= getKeyIdOfModifier(InputBinding.FollowMeFlOffsTgl)
    then
        -- warning!
        log("WARNING: Not all action-keys(2) use the same modifier-key!");
    end;

    -- Build a string, that is much shorter than what InputBinding.getKeyNamesOfDigitalAction() returns
    FollowMe.keys_FollowMeFl = FollowMe.keyModifier_FollowMeFl ~= nil and getKeyName(FollowMe.keyModifier_FollowMeFl) or "";
    FollowMe.keys_FollowMeFl = FollowMe.keys_FollowMeFl:upper();

    local shortKeys = removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeFlStop   ), FollowMe.keys_FollowMeFl)
            .. "," .. removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeFlPause  ), FollowMe.keys_FollowMeFl)
            .. "," .. removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeFlDistDec), FollowMe.keys_FollowMeFl)
            .. "/" .. removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeFlDistInc), FollowMe.keys_FollowMeFl)
            .. "," .. removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeFlOffsDec), FollowMe.keys_FollowMeFl)
            .. "/" .. removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeFlOffsInc), FollowMe.keys_FollowMeFl)
            .. "," .. removeFromString(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.FollowMeFlOffsTgl), FollowMe.keys_FollowMeFl);

    FollowMe.keys_FollowMeFl = FollowMe.keys_FollowMeFl .. " " .. shortKeys;
end;

--
--
--

function FollowMe.load(self, savegame)
    FollowMe.initialize();

    --
    self.getIsFollowMeActive  = FollowMe.getIsFollowMeActive
    self.getDeactivateOnLeave = Utils.overwrittenFunction(self.getDeactivateOnLeave, FollowMe.getDeactivateOnLeave);
    
    self.followMeIsStarted = false
    
    -- A simple attempt at making a "namespace" for 'Follow Me' variables.
    self.modFM = {};
    --
    self.modFM.IsInstalled = true;  -- TODO. Make 'FollowMe' a buyable add-on! This is expensive equipment ;-)
    --
    self.modFM.sumSpeed = 0;
    self.modFM.sumCount = 0;
    self.modFM.DropperCircularArray = {};
    self.modFM.DropperCurrentIndex = 0;
    self.modFM.StalkerVehicleObj = nil;  -- Needed in case self is being deleted.
    --
    self.modFM.FollowState = FollowMe.STATE_NONE;
    self.modFM.FollowVehicleObj = nil;  -- What vehicle is this one following (if any)
    self.modFM.FollowCurrentIndex = 0;
    self.modFM.FollowKeepBack = 20;
    self.modFM.FollowXOffset = 0;
    self.modFM.ToggleXOffset = 0;
    --
    self.modFM.reduceSpeedTime = 0;
    self.modFM.lastAcceleration  = 0;
    self.modFM.lastLastSpeedReal = 0;
    --
    self.modFM.ShowWarningText = nil;
    self.modFM.ShowWarningTime = 0;
    --
    self.modFM.currentHelper = nil
    --
    self.modFM.isDirty = false;
    self.modFM.delayDirty = nil;
    --
    if self.isServer then
        if self.pricePerMS == nil then
            -- Copied from FS17-AIVehicle
            self.pricePerMS = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.ai.pricePerHour"), 2000)/60/60/1000;
        end
        
        -- Drop one "crumb", to get it started...
        local wx,wy,wz = getWorldTranslation(self.components[1].node);
        FollowMe.addDrop(self, wx,wy,wz, 10);
    end;

    --
    if savegame ~= nil and not savegame.resetVehicles then
        local distance = getXMLFloat(savegame.xmlFile, savegame.key .. ".followMe#backDist")
        if distance ~= nil then
            FollowMe.changeDistance(self, { distance }, true ); -- Absolute change
        end
        local offset = getXMLFloat(savegame.xmlFile, savegame.key .. ".followMe#sideOffs")
        if offset ~= nil then
            FollowMe.changeXOffset(self, { offset }, true ); -- Absolute change
        end
    end
end;

function FollowMe.delete(self)
    if self.modFM.StalkerVehicleObj ~= nil then
        -- Stop the stalker-vehicle
        FollowMe.onStopFollowMe(self.modFM.StalkerVehicleObj, FollowMe.REASON_LEADER_REMOVED, true);
    end;
    if self.modFM.FollowVehicleObj ~= nil then
        -- Stop ourself
        FollowMe.onStopFollowMe(self, FollowMe.REASON_NONE, true);
    end
end;


function FollowMe.getIsFollowMeActive(self)
    return self.followMeIsStarted
end


function FollowMe.writeStream(self, streamId, connection)
    streamWriteInt8(            streamId, Utils.getNoNil(self.modFM.FollowKeepBack, 0))
    streamWriteInt8(            streamId, Utils.getNoNil(self.modFM.FollowXOffset,  0) * 2)
    if streamWriteBool(         streamId, self.followMeIsStarted) then
        streamWriteUIntN(       streamId, self.modFM.FollowState, FollowMe.NUM_BITS_STATE)
        streamWriteUInt8(       streamId, self.modFM.currentHelper.index)
        writeNetworkNodeObject( streamId, self.modFM.FollowVehicleObj)
    end
end;

function FollowMe.readStream(self, streamId, connection)
    local distance  = streamReadInt8(streamId)
    local offset    = streamReadInt8(streamId) / 2
    if streamReadBool(streamId) then
        local state         = streamReadUIntN(       streamId, FollowMe.NUM_BITS_STATE)
        local helperIndex   = streamReadUInt8(       streamId)
        local followObj     = readNetworkNodeObject( streamId)

        FollowMe.onStartFollowMe(self, followObj, helperIndex, true);
        
        self.modFM.FollowState = state;
    end
    
    FollowMe.changeDistance(self, { distance }, true ); -- Absolute change
    FollowMe.changeXOffset( self, { offset },   true ); -- Absolute change
end;


function FollowMe.getSaveAttributesAndNodes(self, nodeIdent)
    local attributes, nodes
    if self.modFM ~= nil then
        nodes = nodeIdent .. ('<followMe backDist="%.0f" sideOffs="%.1f" />'):format(self.modFM.FollowKeepBack, self.modFM.FollowXOffset)
    end
    return attributes, nodes;
end;


function FollowMe.mouseEvent(self, posX, posY, isDown, isUp, button)
end;

function FollowMe.keyEvent(self, unicode, sym, modifier, isDown)
end;

function FollowMe.copyDrop(self, crumb, targetXYZ)
    assert(g_server ~= nil);

    self.modFM.DropperCurrentIndex = self.modFM.DropperCurrentIndex + 1; -- Keep incrementing index, so followers will be able to detect if they get too far behind of the circular-array.
    local dropIndex = 1+((self.modFM.DropperCurrentIndex-1) % FollowMe.cBreadcrumbsMaxEntries);

    if targetXYZ == nil then
        self.modFM.DropperCircularArray[dropIndex] = crumb;
    else
        -- Due to a different target, make a "deep-copy" of the crumb.
        self.modFM.DropperCircularArray[dropIndex] = {
            trans           = targetXYZ,
            rot             = crumb.rot,
            avgSpeedKMH     = crumb.avgSpeedKMH,
            turnLightState  = crumb.turnLightState,
        };
    end;
end;

function FollowMe.addDrop(self, wx,wy,wz, avgSpeedKMH, turnLightState, reverserDirection)
    assert(g_server ~= nil);

    self.modFM.DropperCurrentIndex = self.modFM.DropperCurrentIndex + 1; -- Keep incrementing index, so followers will be able to detect if they get too far behind of the circular-array.
    local dropIndex = 1+((self.modFM.DropperCurrentIndex-1) % FollowMe.cBreadcrumbsMaxEntries);

    local rx,ry,rz  = localDirectionToWorld(self.components[1].node, 0,0, Utils.getNoNil(reverserDirection, 1));
    self.modFM.DropperCircularArray[dropIndex] = {
        trans           = {wx,wy,wz},
        rot             = {rx,ry,rz},
        avgSpeedKMH     = avgSpeedKMH,
        turnLightState  = turnLightState,
    };

    --log(string.format("Crumb #%d(%d): trans=%f/%f/%f, rot=%f/%f/%f, avgSpeed=%f, movTime=%f", FollowMe.gBreadcrumbsCurrentDropIndex,dropIndex, wx,wy,wz, rx,ry,rz, avgSpeedKMH, self.modFM.movingTime));
end;

function FollowMe.changeDistance(self, newValue, noSendEvent)
    if type(newValue) == "table" then
        newValue = newValue[1] -- Absolute change
    else
        newValue = self.modFM.FollowKeepBack + newValue -- Relative change
    end
    self.modFM.FollowKeepBack = Utils.clamp(newValue, -50, 127); -- Min -128 and Max 127 due to writeStreamInt8().
    if not noSendEvent then
        self.modFM.delayDirty = g_currentMission.time + 750;
    end
end;

function FollowMe.changeXOffset(self, newValue, noSendEvent)
    if type(newValue) == "table" then
        newValue = newValue[1] -- Absolute change
    else
        newValue = self.modFM.FollowXOffset + newValue -- Relative change
    end
    self.modFM.FollowXOffset = Utils.clamp(newValue, -50.0, 50.0);
    if not noSendEvent then
        self.modFM.delayDirty = g_currentMission.time + 750;
    end
end;

function FollowMe.toggleXOffset(self, withZero, noSendEvent)
    if withZero == true then
        if self.modFM.FollowXOffset == 0 and self.modFM.ToggleXOffset ~= 0 then
            self.modFM.FollowXOffset = self.modFM.ToggleXOffset
            self.modFM.ToggleXOffset = 0;
        elseif self.modFM.FollowXOffset ~= 0 then
            self.modFM.ToggleXOffset = self.modFM.FollowXOffset
            self.modFM.FollowXOffset = 0;
        end
        if not noSendEvent then
            self.modFM.delayDirty = g_currentMission.time + 750;
        end;
    else
        FollowMe.changeXOffset(self, { -self.modFM.FollowXOffset }, noSendEvent) -- Absolute change
    end
end

--
FollowMe.InputEvents = {}
FollowMe.INPUTEVENT_MILLISECONDS = 500
FollowMe.INPUTEVENT_NONE    = 0
FollowMe.INPUTEVENT_SHORT   = 1 -- Key-action was pressed/released quickly
FollowMe.INPUTEVENT_LONG    = 2 -- Key-action was pressed/hold for longer
FollowMe.INPUTEVENT_REPEAT  = 3 -- Key-action is still pressed/hold for much longer

function FollowMe.hasEventShortLong(inBinding, repeatIntervalMS)
    local isPressed = InputBinding.isPressed(inBinding);
    -- If no previous input-event for this binding...
    if not FollowMe.InputEvents[inBinding] then
        -- ...and it is now pressed down, then remember the time of initiation.
        if isPressed then
            FollowMe.InputEvents[inBinding] = g_currentMission.time;
        end
        return FollowMe.INPUTEVENT_NONE; -- Not pressed or Can not determine.
    end;
    -- For how long have this input-event been hold down?
    local timeDiff = g_currentMission.time - FollowMe.InputEvents[inBinding];
    if not isPressed then
        FollowMe.InputEvents[inBinding] = nil;
        if timeDiff > 0 and timeDiff < FollowMe.INPUTEVENT_MILLISECONDS then
            return FollowMe.INPUTEVENT_SHORT; -- Short press
        end
        return FollowMe.INPUTEVENT_NONE; -- It was probably a long event, which has already been processed.
    elseif timeDiff > FollowMe.INPUTEVENT_MILLISECONDS then
        FollowMe.InputEvents[inBinding] = g_currentMission.time + 10000000;
        if repeatIntervalMS ~= nil then
            return FollowMe.INPUTEVENT_REPEAT; -- Long-and-repeating press
        end
        return FollowMe.INPUTEVENT_LONG; -- Long press
    elseif timeDiff < 0 then
        if repeatIntervalMS ~= nil and (timeDiff + 10000000) > repeatIntervalMS then
            FollowMe.InputEvents[inBinding] = g_currentMission.time + 10000000;
            return FollowMe.INPUTEVENT_REPEAT; -- Long-and-repeating press
        end;
    end;
    return FollowMe.INPUTEVENT_NONE; -- Not released
end;

--
function FollowMe.update(self, dt)

    local activeForInput = self.isEntered and not g_currentMission.isPlayerFrozen and not g_gui:getIsGuiVisible();

    if activeForInput and not self.isConveyorBelt then
        if InputBinding.hasEvent(InputBinding.FollowMeMyToggle) then
            if self:getIsFollowMeActive() then
                FollowMe.stopFollowMe(self, FollowMe.REASON_USER_ACTION);
            elseif g_currentMission:getHasPermission("hireAI") then
                FollowMe.startFollowMe(self);
            else
                -- No permission
            end
        elseif InputBinding.hasEvent(InputBinding.FollowMeMyPause) then
            FollowMe.waitResumeFollowMe(self, FollowMe.REASON_USER_ACTION);
        end;

        if self.modFM.FollowVehicleObj ~= nil then
            -- Due to three functions per InputBinding; press-and-release (short), press-and-hold (long), and press-and-hold-longer (repeat)
            local  myDistDec = FollowMe.hasEventShortLong(InputBinding.FollowMeMyDistDec, 500);
            local  myDistInc = FollowMe.hasEventShortLong(InputBinding.FollowMeMyDistInc, 500);
            local  myOffsDec = FollowMe.hasEventShortLong(InputBinding.FollowMeMyOffsDec, 250);
            local  myOffsInc = FollowMe.hasEventShortLong(InputBinding.FollowMeMyOffsInc, 250);
            local  myOffsTgl = FollowMe.hasEventShortLong(InputBinding.FollowMeMyOffsTgl);
            --
            if     myDistDec == FollowMe.INPUTEVENT_SHORT  then FollowMe.changeDistance(self, -5);
            elseif myDistDec == FollowMe.INPUTEVENT_REPEAT then FollowMe.changeDistance(self, -1);
            
            elseif myDistInc == FollowMe.INPUTEVENT_SHORT  then FollowMe.changeDistance(self,  5);
            elseif myDistInc == FollowMe.INPUTEVENT_REPEAT then FollowMe.changeDistance(self,  1);
            
            elseif myOffsDec == FollowMe.INPUTEVENT_SHORT  
                or myOffsDec == FollowMe.INPUTEVENT_REPEAT then FollowMe.changeXOffset(self, -0.5);
            
            elseif myOffsInc == FollowMe.INPUTEVENT_SHORT  
                or myOffsInc == FollowMe.INPUTEVENT_REPEAT then FollowMe.changeXOffset(self,  0.5);
            
            elseif myOffsTgl == FollowMe.INPUTEVENT_SHORT  then FollowMe.toggleXOffset(self, true); -- Toggle between 'zero' and 'offset'
            elseif myOffsTgl == FollowMe.INPUTEVENT_LONG   then FollowMe.toggleXOffset(self); -- Invert offset
            end
        end;

        local stalker = self.modFM.StalkerVehicleObj;
        if stalker ~= nil then
            if InputBinding.hasEvent(InputBinding.FollowMeFlStop) then
                if stalker:getIsFollowMeActive() then
                    FollowMe.stopFollowMe(stalker, FollowMe.REASON_USER_ACTION);
                end
            elseif InputBinding.hasEvent(InputBinding.FollowMeFlPause) then
                FollowMe.waitResumeFollowMe(stalker, FollowMe.REASON_USER_ACTION);
            end;
            
            -- Due to three functions per InputBinding; press-and-release (short), press-and-hold (long), and press-and-hold-longer (repeat)
            local  flDistDec = FollowMe.hasEventShortLong(InputBinding.FollowMeFlDistDec, 500);
            local  flDistInc = FollowMe.hasEventShortLong(InputBinding.FollowMeFlDistInc, 500);
            local  flOffsDec = FollowMe.hasEventShortLong(InputBinding.FollowMeFlOffsDec, 250);
            local  flOffsInc = FollowMe.hasEventShortLong(InputBinding.FollowMeFlOffsInc, 250);
            local  flOffsTgl = FollowMe.hasEventShortLong(InputBinding.FollowMeFlOffsTgl);
            --
            if     flDistDec == FollowMe.INPUTEVENT_SHORT  then FollowMe.changeDistance(stalker, -5);
            elseif flDistDec == FollowMe.INPUTEVENT_REPEAT then FollowMe.changeDistance(stalker, -1);
            
            elseif flDistInc == FollowMe.INPUTEVENT_SHORT  then FollowMe.changeDistance(stalker,  5);
            elseif flDistInc == FollowMe.INPUTEVENT_REPEAT then FollowMe.changeDistance(stalker,  1);
            
            elseif flOffsDec == FollowMe.INPUTEVENT_SHORT  
                or flOffsDec == FollowMe.INPUTEVENT_REPEAT then FollowMe.changeXOffset(stalker, -0.5);
            
            elseif flOffsInc == FollowMe.INPUTEVENT_SHORT  
                or flOffsInc == FollowMe.INPUTEVENT_REPEAT then FollowMe.changeXOffset(stalker,  0.5);

            elseif flOffsTgl == FollowMe.INPUTEVENT_SHORT  then FollowMe.toggleXOffset(stalker, true); -- Toggle between 'zero' and 'offset'
            elseif flOffsTgl == FollowMe.INPUTEVENT_LONG   then FollowMe.toggleXOffset(stalker); -- Invert offset
            end
        end;
    end;
    
    if self:getIsFollowMeActive() then
        self.forceIsActive = true;
        self.stopMotorOnLeave = false;
        self.steeringEnabled = false;    
    end
end;

function FollowMe.updateTick(self, dt)
    if self.isServer
    and self.modFM ~= nil
    --and self.modFM.IsInstalled
    then
        if self:getIsFollowMeActive() and self.modFM.FollowVehicleObj ~= nil then 
            -- Have leading vehicle to follow.
            local turnLightState = FollowMe.updateFollowMovement(self, dt);

            if self.modFM.FollowVehicleObj ~= nil and self.setBeaconLightsVisibility ~= nil then
                -- Simon says: Lights!
                self:setLightsTypesMask(       self.modFM.FollowVehicleObj.lightsTypesMask or 0);
                self:setBeaconLightsVisibility(self.modFM.FollowVehicleObj.beaconLightsActive or false);
                -- ...and Garfunkel follows up with turn-signals
                if nil ~= turnLightState then
                    self:setTurnLightState(turnLightState)
                end
            end
            
            local wage = (dt * self.pricePerMS * g_currentMission.missionInfo.buyPriceMultiplier) * FollowMe.wagePaymentMultiplier
            g_currentMission:addSharedMoney(-wage, "wagePayment");
            g_currentMission:addMoneyChange(-wage, FSBaseMission.MONEY_TYPE_AI)        
        elseif (Utils.getNoNil(self.reverserDirection, 1) * self.movingDirection > 0) then  -- Must drive forward to drop crumbs
            self.modFM.sumSpeed = self.modFM.sumSpeed + self.lastSpeed;
            self.modFM.sumCount = self.modFM.sumCount + 1;
            --
            local wx,wy,wz = getWorldTranslation(self.components[1].node); -- current position
            local pwx,pwy,pwz = unpack(self.modFM.DropperCircularArray[1+((self.modFM.DropperCurrentIndex-1) % FollowMe.cBreadcrumbsMaxEntries)].trans); -- previous position
            local distancePrevDrop = Utils.vector2Length(pwx-wx, pwz-wz);
            if distancePrevDrop >= FollowMe.cMinDistanceBetweenDrops then
                local avgSpeedKMH = math.max((self.modFM.sumSpeed / (self.modFM.sumCount>0 and self.modFM.sumCount or 1)) * 3600, 1)
                FollowMe.addDrop(self, wx,wy,wz, avgSpeedKMH, self.turnLightState, self.reverserDirection);
                --
                self.modFM.sumSpeed = 0;
                self.modFM.sumCount = 0;
            end;
        end;
    end;

    FollowMe.sendUpdate(self);
end;

function FollowMe.sendUpdate(self)
    if self.modFM.isDirty
    or (self.modFM.delayDirty ~= nil and self.modFM.delayDirty < g_currentMission.time)
    then
        self.modFM.isDirty = false;
        self.modFM.delayDirty = nil;
        --
        if g_server == nil then
            -- Client - Send "distance/offset update" to server
            g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_NONE, FollowMe.REASON_NONE, nil));
        else
            -- Server only
            g_server:broadcastEvent(FollowMeResponseEvent:new(self, self.modFM.FollowState, FollowMe.REASON_NONE, self.modFM.currentHelper), nil, nil, self);
        end
    end;
end;


function FollowMe.startFollowMe(self, connection)
    if g_server == nil then
        -- Client - Send command to server
        g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_START));
    else
        -- Server only
        if not self:getIsFollowMeActive() and self:getIsHired() then
            FollowMe.showReason(self, connection, FollowMe.REASON_ALREADY_AI)
        elseif not self.isMotorStarted then
            FollowMe.showReason(self, connection, FollowMe.REASON_ENGINE_STOPPED)
        else
            local closestVehicle = FollowMe.findVehicleInFront(self)
            if closestVehicle == nil 
            --or self.modFM.FollowVehicleObj ~= nil
            then
                FollowMe.showReason(self, connection, FollowMe.REASON_NO_TRAIL_FOUND)
            else
                FollowMe.onStartFollowMe(self, closestVehicle);
            end
        end
    end
end

function FollowMe.stopFollowMe(self, reason)
    if g_server == nil then
        -- Client - Send command to server
        g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_STOP, reason, nil));
    else
        -- Server only
        FollowMe.onStopFollowMe(self, reason);
    end
end

function FollowMe.waitResumeFollowMe(self, reason, noEventSend)
    if g_server == nil then
        -- Client
        g_client:getServerConnection():sendEvent(FollowMeRequestEvent:new(self, FollowMe.COMMAND_WAITRESUME, reason, nil));
    else
        -- Server only
        FollowMe.onWaitResumeFollowMe(self, reason);
    end
end

--
--

function FollowMe.aquireHelper(helperIndex)
    local helperObj
    if helperIndex ~= nil and helperIndex >= 1 and helperIndex <= table.getn(HelperUtil.helperIndexToDesc) then
        helperObj = HelperUtil.helperIndexToDesc[helperIndex]
    else
        helperObj = HelperUtil.getRandomHelper()
    end

    HelperUtil.useHelper(helperObj)
    
    return helperObj
end

function FollowMe.releaseHelper(helperObj)
    if helperObj ~= nil then
        HelperUtil.releaseHelper(helperObj)
    end
    return nil
end


function FollowMe.onStartFollowMe(self, followObj, helperIndex, noEventSend)
    if followObj == nil then
        log("onStartFollowMe(followObj=",followObj,", helperIndex=",helperIndex,")")
    end

    if not self.followMeIsStarted and followObj ~= nil then
        self.followMeIsStarted = true;

        self.modFM.currentHelper = FollowMe.aquireHelper(helperIndex)

        --
        followObj.modFM.StalkerVehicleObj = self
        self.modFM.FollowVehicleObj = followObj
        self.modFM.FollowState = FollowMe.STATE_FOLLOWING
        
        if noEventSend ~= true and g_server ~= nil then
            g_server:broadcastEvent(FollowMeResponseEvent:new(self, FollowMe.STATE_STARTING, FollowMe.REASON_NONE, self.modFM.currentHelper), nil, nil, self);
        end

        self.isHirableBlocked = false;
        self.forceIsActive = true;
        self.stopMotorOnLeave = false;
        self.steeringEnabled = false;
        self.disableCharacterOnLeave = false;

        if self.vehicleCharacter ~= nil then
            self.vehicleCharacter:delete();
            if self.modFM.currentHelper ~= nil then
                self.vehicleCharacter:loadCharacter(self.modFM.currentHelper.xmlFilename, getUserRandomizedMpColor(self.modFM.currentHelper.name))
                if self.isEntered then
                    self.vehicleCharacter:setCharacterVisibility(false)
                end
            end
        end

        if self.modFM.currentHelper ~= nil then
            local hotspotX, _, hotspotZ = getWorldTranslation(self.rootNode);
            local _, textSize = getNormalizedScreenValues(0, 6);
            local _, textOffsetY = getNormalizedScreenValues(0, 11.5);
            local width, height = getNormalizedScreenValues(15,15)
            self.mapAIHotspot = g_currentMission.ingameMap:createMapHotspot("helper", self.modFM.currentHelper.name, nil, getNormalizedUVs({776, 520, 240, 240}), {0.052, 0.1248, 0.672, 1}, hotspotX, hotspotZ, width, height, false, false, true, self.components[1].node, true, MapHotspot.CATEGORY_AI, textSize, textOffsetY, {1, 1, 1, 1}, nil, getNormalizedUVs({776, 520, 240, 240}), Overlay.ALIGN_VERTICAL_MIDDLE, 0.7)
        end
    end
end


function FollowMe.onStopFollowMe(self, reason, noEventSend)
    if self.followMeIsStarted then
        self.followMeIsStarted = false;

        if self.modFM.FollowVehicleObj ~= nil then
            self.modFM.FollowVehicleObj.modFM.StalkerVehicleObj = nil
        end
        self.modFM.FollowVehicleObj = nil
        self.modFM.FollowState = FollowMe.STATE_NONE

        if noEventSend ~= true and g_server ~= nil then
            g_server:broadcastEvent(FollowMeResponseEvent:new(self, FollowMe.STATE_STOPPING, reason, self.modFM.currentHelper), nil, nil, self);
        end

        self.forceIsActive = false;
        self.stopMotorOnLeave = true;
        self.steeringEnabled = true;
        self.disableCharacterOnLeave = true;

        if self.vehicleCharacter ~= nil then
           self.vehicleCharacter:delete();
        end

        if self.isEntered or self.isControlled then
            if self.vehicleCharacter ~= nil then
                --g_gameSettings:getValue("playerIndex")
                --g_gameSettings:getValue("playerColorIndex")
                self.vehicleCharacter:loadCharacter(PlayerUtil.playerIndexToDesc[self.playerIndex].xmlFilename, self.playerColorIndex)
                self.vehicleCharacter:setCharacterVisibility(not self.isEntered)
            end
        end;

        if self.mapAIHotspot ~= nil then
            g_currentMission.ingameMap:deleteMapHotspot(self.mapAIHotspot);
            self.mapAIHotspot = nil;
        end

        self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF, true);
        if self.isServer then
            WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeedReal, 0, true, self.requiredDriveMode);
        end

        -- TODO - does a g_gameSettings:getValue() exist for 'automaticMotorStartEnabled'?
        if self.isServer and g_currentMission.missionInfo.automaticMotorStartEnabled and not (self.isEntered or self.isControlled) then
            self:stopMotor();
        end

        FollowMe.showReason(self, nil, reason, self.modFM.currentHelper)

        self.modFM.currentHelper = FollowMe.releaseHelper(self.modFM.currentHelper)
    end
end

function FollowMe.onWaitResumeFollowMe(self, reason, noEventSend)
    if self.modFM.FollowState == FollowMe.STATE_FOLLOWING then
        self.modFM.FollowState = FollowMe.STATE_WAITING
        self.modFM.isDirty = (g_server ~= nil)
    elseif self.modFM.FollowState == FollowMe.STATE_WAITING then
        self.modFM.FollowState = FollowMe.STATE_FOLLOWING
        self.modFM.isDirty = (g_server ~= nil)
    end
end

function FollowMe.showReason(self, connection, reason, currentHelper)
    if connection ~= nil then
        connection:sendEvent(FollowMeResponseEvent:new(self, self.modFM.FollowState, reason, currentHelper), nil, nil, self);    
    else
        if reason == FollowMe.REASON_NONE then
            -- No notification needed
        elseif reason == FollowMe.REASON_ALREADY_AI then
            FollowMe.setWarning(self, "FollowMeAlreadyAI");
        elseif reason == FollowMe.REASON_NO_TRAIL_FOUND then
            FollowMe.setWarning(self, "FollowMeDropperNotFound");
        elseif reason == FollowMe.REASON_ENGINE_STOPPED then
            FollowMe.setWarning(self, "FollowMeStartEngine")
        elseif reason ~= nil then
            local txtId = ("FollowMeReason%d"):format(reason)
            if g_i18n:hasText(txtId) then
                local helperName = "?"
                if currentHelper ~= nil then
                    helperName = Utils.getNoNil(currentHelper.name, helperName)
                end
                local reasonTxt = g_i18n:getText(txtId):format(helperName)
                local reasonClr = {0.5, 0.5, 1.0, 1.0}
                if reason == FollowMe.REASON_TOO_FAR_BEHIND then
                    reasonClr = FSBaseMission.INGAME_NOTIFICATION_CRITICAL
                end
                g_currentMission:addIngameNotification(reasonClr, reasonTxt)
            end
        end
    end
end

function FollowMe.setWarning(self, txt, noSendEvent)
    self.modFM.ShowWarningText = g_i18n:getText(txt);
    self.modFM.ShowWarningTime = g_currentMission.time + 2500;
end;


function FollowMe.findVehicleInFront(self)
    if not self.isServer then
        return nil
    end
    -- Anything below is only server-side
    
    local wx,wy,wz = getWorldTranslation(self.components[1].node);
    local rx,ry,rz = localDirectionToWorld(self.components[1].node, 0,0, Utils.getNoNil(self.reverserDirection, 1));
    local rlength = Utils.vector2Length(rx,rz);
    local rotDeg = math.deg(math.atan2(rx/rlength,rz/rlength));
    local rotRad = Utils.degToRad(rotDeg-45.0);
    local rotRad = Utils.degToRad(rotDeg-45.0);
    --log(string.format("getWorldTranslation:%f/%f/%f - localDirectionToWorld:%f/%f/%f - rDeg:%f - rRad:%f", wx,wy,wz, rx,ry,rz, rotDeg, rotRad));

    -- Find closest vehicle, that is in front of self.
    local closestDistance = 50;
    local closestVehicle = nil;
    for _,vehicleObj in pairs(g_currentMission.steerables) do
        if vehicleObj.modFM ~= nil -- Make sure its a vehicle that has the FollowMe specialization added.
        and vehicleObj.modFM.DropperCircularArray ~= nil -- Make sure other vehicle has circular array
        and vehicleObj.modFM.StalkerVehicleObj == nil then -- and is not already stalked by something.
            local vx,vy,vz = getWorldTranslation(vehicleObj.components[1].node);
            local dx,dz = vx-wx, vz-wz;
            local dist = Utils.vector2Length(dx,dz);
            if (dist < closestDistance) then
                -- Rotate to see if vehicleObj is "in front of us"
                local nx = dx * math.cos(rotRad) - dz * math.sin(rotRad);
                local nz = dx * math.sin(rotRad) + dz * math.cos(rotRad);
                if (nx > 0) and (nz > 0) then
                    closestDistance = dist;
                    closestVehicle = vehicleObj;
                end;
            end;
        end;
    end;

    if closestVehicle ~= nil then
        -- Find closest "breadcrumb"
        self.modFM.FollowCurrentIndex = 0;
        local closestDistance = 50;
        for i=closestVehicle.modFM.DropperCurrentIndex, math.max(closestVehicle.modFM.DropperCurrentIndex - FollowMe.cBreadcrumbsMaxEntries,1), -1 do
            local crumb = closestVehicle.modFM.DropperCircularArray[1+((i-1) % FollowMe.cBreadcrumbsMaxEntries)];
            if crumb ~= nil then
                local x,y,z = unpack(crumb.trans);
                -- Translate
                local dx,dz = x-wx, z-wz;
                local dist = Utils.vector2Length(dx,dz);
                --local r = Utils.getYRotationFromDirection(dx,dz);
                --log(string.format("#%d - xz:%f/%f - dxdz:%f/%f - r:%f - dist:%f", i, x,z, dx,dz, r, dist));
                if (dist > 2) and (dist < closestDistance) then
                    -- Rotate to see if the point is "in front of us"
                    local nx = dx * math.cos(rotRad) - dz * math.sin(rotRad);
                    local nz = dx * math.sin(rotRad) + dz * math.cos(rotRad);
                    if (nx > 0) and (nz > 0) then
                        --log(string.format("#%d - xz:%f/%f - dxdz:%f/%f - dist:%f - nxnz:%f/%f", i, x,z, dx,dz, dist, nx,nz));
                        closestDistance = dist;
                        self.modFM.FollowCurrentIndex = i;
                    end;
                end;
                --
                if self.modFM.FollowCurrentIndex ~= 0 and dist > closestDistance then
                    -- If crumb is "going further away" from already found one, then stop searching.
                    break;
                end;
            end;
        end;
        --log(string.format("ClosestDist:%f, index:%d", closestDistance, self.modFM.FollowCurrentIndex));
        --
        if self.modFM.FollowCurrentIndex == 0 then
            closestVehicle = nil;
        end;
    end
    
    return closestVehicle
end


-- Copied from FS17-AIVehicle, and adapted for FollowMe
function FollowMe.onEnter(self, isControlling)
    if self.mapAIHotspot ~= nil then
        self.mapAIHotspot.enabled = false;
    end
end

-- Copied from FS17-AIVehicle, and adapted for FollowMe
function FollowMe.onLeave(self)
    if self.mapAIHotspot ~= nil then
        self.mapAIHotspot.enabled = true;
    end
    if self.followMeIsStarted and self.vehicleCharacter ~= nil then
        self.vehicleCharacter:setCharacterVisibility(true);
    end
end

function FollowMe.getDeactivateOnLeave(self, superFunc)
    local deactivate = not self.followMeIsStarted

    if deactivate and superFunc ~= nil then
        deactivate = superFunc(self)
    end

    return deactivate
end;


-- Get distance to keep-in-front, or zero if not.
function FollowMe.getKeepFront(self)
    if (self.modFM.FollowKeepBack >= 0) then return 0; end
    return math.abs(self.modFM.FollowKeepBack);
end

-- Get distance to keep-back, or zero if not.
function FollowMe.getKeepBack(self, speedKMH)
    --if speedKMH == nil then speedKMH=0; end;
    local keepBack = Utils.clamp(self.modFM.FollowKeepBack, 0, 999);
    return keepBack --* (1 + speedKMH/100);
end;


function FollowMe.checkBaler(attachedTool)
    local allowedToDrive = true
    local hasCollision = false
    local pctSpeedReduction = 0
    if attachedTool:getIsTurnedOn() then
        if attachedTool.baler.unloadingState == Baler.UNLOADING_CLOSED then
            local unitFillLevel = attachedTool:getUnitFillLevel(attachedTool.baler.fillUnitIndex) 
            local unitCapacity  = attachedTool:getUnitCapacity(attachedTool.baler.fillUnitIndex)
            if unitFillLevel >= unitCapacity then
                allowedToDrive = false
                --hasCollision = true -- Stop faster
                if (table.getn(attachedTool.baler.bales) > 0) and attachedTool:isUnloadingAllowed() then
                    -- Activate the bale unloading (server-side only!)
                    attachedTool:setIsUnloadingBale(true);
                end
            else
                -- When baler is more than 95% full, then reduce speed in an attempt at not leaving spots of straw.
                pctSpeedReduction = Utils.lerp(0.0, 0.75, math.max((unitFillLevel / unitCapacity) - 0.95, 0))
            end
        else
            allowedToDrive = false
            --hasCollision = true
            if attachedTool.baler.unloadingState == Baler.UNLOADING_OPEN then
                -- Activate closing (server-side only!)
                attachedTool:setIsUnloadingBale(false);
            end
        end
    end
    return allowedToDrive, hasCollision, pctSpeedReduction;
end

function FollowMe.checkBaleWrapper(attachedTool)
    -- Typo-error bug in base-game's script.
    -- Try to anticipate future "correct spelling".
    local STATE_WRAPPER_FINISHED = Utils.getNoNil(BaleWrapper.STATE_WRAPPER_FINSIHED, BaleWrapper.STATE_WRAPPER_FINISHED)

    local allowedToDrive = true
    local hasCollision = false
    local pctSpeedReduction = 0
    if attachedTool.baleWrapperState == BaleWrapper.STATE_WRAPPER_WRAPPING_BALE then
        pctSpeedReduction = 0.5
    elseif attachedTool.baleWrapperState == STATE_WRAPPER_FINISHED then -- '4'
        allowedToDrive = false
        -- Activate the bale unloading (server-side only!)
        attachedTool:doStateChange(BaleWrapper.CHANGE_BUTTON_EMPTY);
    elseif attachedTool.baleWrapperState > STATE_WRAPPER_FINISHED then -- '4'
        allowedToDrive = false
    end
    return allowedToDrive, hasCollision, pctSpeedReduction;
end

function FollowMe.checkBalerAndWrapper(attachedTool)
    local d1, c1, r1 = FollowMe.checkBaler(attachedTool)
    local d2, c2, r2 = FollowMe.checkBaleWrapper(attachedTool)
    local allowedToDrive    = d1 and d2
    local hasCollision      = c1 and c2
    local pctSpeedReduction = math.max(r1, r2)
    return allowedToDrive, hasCollision, pctSpeedReduction
end

function FollowMe.updateFollowMovement(self, dt)
    assert(self.modFM.FollowVehicleObj ~= nil);

    local allowedToDrive = (self.modFM.FollowState == FollowMe.STATE_FOLLOWING) and self.isMotorStarted;
    --local hasCollision = false;
    local moveForwards = true;
    local turnLightState = nil;
    
    --
    --if allowedToDrive and self.numCollidingVehicles ~= nil then
    --    for _,numCollisions in pairs(self.numCollidingVehicles) do
    --        if numCollisions > 0 then
    --            hasCollision = true; -- Collision imminent! Brake! Brake!
    --            break;
    --        end;
    --    end;
    --end

    -- Attempt at automatically unloading of round-bales
    local attachedTool = nil;
    -- Locate supported equipment
    for _,tool in pairs(self.attachedImplements) do
        if tool.object ~= nil then
            if  tool.object.baler ~= nil
            and tool.object.baler.baleUnloadAnimationName ~= nil  -- Seems RoundBalers are the only ones which have set the 'baleUnloadAnimationName'
            and SpecializationUtil.hasSpecialization(Baler, tool.object.specializations)
            then
                if tool.object.baleWrapperState ~= nil
                and SpecializationUtil.hasSpecialization(BaleWrapper, tool.object.specializations)
                then
                    -- Found both baler and wrapper (Kuhn DLC)
                    attachedTool = { tool.object, FollowMe.checkBalerAndWrapper };
                    break;
                end
            
                -- Found (Round)Baler.LUA
                attachedTool = { tool.object, FollowMe.checkBaler };
                break
            end

            if tool.object.baleWrapperState ~= nil
            and SpecializationUtil.hasSpecialization(BaleWrapper, tool.object.specializations)
            then
                -- Found BaleWrapper
                attachedTool = { tool.object, FollowMe.checkBaleWrapper };
                break
            end
        end
    end
    --
    if attachedTool ~= nil then
        local setAllowedToDrive
        local setHasCollision
        local pctSpeedReduction
        setAllowedToDrive, setHasCollision, pctSpeedReduction = attachedTool[2](attachedTool[1]);
        allowedToDrive = allowedToDrive and Utils.getNoNil(setAllowedToDrive, allowedToDrive);
        --hasCollision   = setHasCollision~=nil   and setHasCollision   or hasCollision;
        if pctSpeedReduction ~= nil and pctSpeedReduction > 0 then
            self.modFM.reduceSpeedTime = g_currentMission.time + 250
            -- TODO - change above, so it actually affects acceleration value
        end
    end

    --
    local leader = self.modFM.FollowVehicleObj;

    -- current location / rotation
    local cx,cy,cz      = getWorldTranslation(self.components[1].node);
    local crx,cry,crz   = localDirectionToWorld(self.components[1].node, 0,0,Utils.getNoNil(self.reverserDirection, 1));
    -- leader location / rotation
    local lx,ly,lz      = getWorldTranslation(leader.components[1].node);
    local lrx,lry,lrz   = localDirectionToWorld(leader.components[1].node, 0,0,Utils.getNoNil(leader.reverserDirection, 1));

    -- original target
    local ox,oy,oz;
    local orx,ory,orz;
    -- actual target
    local tx,ty,tz;
    local trx,try,trz;
    --
    local acceleration = 1.0;
    local avgSpeedKMH = 0.0;

    -- leader-target
    local keepInFrontMeters = FollowMe.getKeepFront(self);
    lx = lx - lrz * self.modFM.FollowXOffset + lrx * keepInFrontMeters;
    lz = lz + lrx * self.modFM.FollowXOffset + lrz * keepInFrontMeters;
    -- distance to leader-target (only "correct" when trail is a straight-line)
    local distMeters = Utils.vector2Length(cx-lx,cz-lz);

    local crumbIndexDiff = leader.modFM.DropperCurrentIndex - self.modFM.FollowCurrentIndex;

    --
    if crumbIndexDiff >= FollowMe.cBreadcrumbsMaxEntries then
        -- circular-array have "circled" once, and this follower did not move fast enough.
        if self.modFM.FollowState ~= FollowMe.STATE_STOPPING then
            FollowMe.stopFollowMe(self, FollowMe.REASON_TOO_FAR_BEHIND);
        end
        --hasCollision = true
        allowedToDrive = false
        acceleration = 0.0
        -- Set target 2 meters straight ahead of vehicle.
        tx = cx + crx * 2;
        ty = cy;
        tz = cz + crz * 2;
    elseif crumbIndexDiff > 0 then
        -- Following crumbs...
        local crumbT = leader.modFM.DropperCircularArray[1+((self.modFM.FollowCurrentIndex-1) % FollowMe.cBreadcrumbsMaxEntries)];
        turnLightState = crumbT.turnLightState
        --
        ox,oy,oz = crumbT.trans[1],crumbT.trans[2],crumbT.trans[3];
        orx,ory,orz = unpack(crumbT.rot);
        -- Apply offset
        tx = ox - orz * self.modFM.FollowXOffset;
        ty = oy;
        tz = oz + orx * self.modFM.FollowXOffset;
        --
        local dx,dz = tx - cx, tz - cz;
        local tDist = Utils.vector2Length(dx,dz);
        --
        local trAngle = math.atan2(orx,orz);
        local nz = dx * math.sin(trAngle) + dz * math.cos(trAngle);
        --
        if (tDist < (FollowMe.cMinDistanceBetweenDrops / 2)) -- close enough to crumb?
        or (nz < 0) -- in front of crumb?
        then
            FollowMe.copyDrop(self, crumbT, (self.modFM.FollowXOffset == 0) and nil or {tx,ty,tz});
            -- Go to next crumb
            self.modFM.FollowCurrentIndex = self.modFM.FollowCurrentIndex + 1;
            crumbIndexDiff = leader.modFM.DropperCurrentIndex - self.modFM.FollowCurrentIndex;
        end;
        --
        if crumbIndexDiff > 0 then
            -- Still following crumbs...
            avgSpeedKMH = crumbT.avgSpeedKMH;
            local crumbN = leader.modFM.DropperCircularArray[1+((self.modFM.FollowCurrentIndex  ) % FollowMe.cBreadcrumbsMaxEntries)];
            if crumbN ~= nil then
                -- Apply offset, to next original target
                local ntx = crumbN.trans[1] - crumbN.rot[3] * self.modFM.FollowXOffset;
                local ntz = crumbN.trans[3] + crumbN.rot[1] * self.modFM.FollowXOffset;
                local pct = math.max(1 - (tDist / FollowMe.cMinDistanceBetweenDrops), 0);
                tx,_,tz = Utils.vector3ArrayLerp( {tx,0,tz}, {ntx,0,ntz}, pct);
                avgSpeedKMH = (avgSpeedKMH + crumbN.avgSpeedKMH) / 2;
            end;
            --
            local keepBackMeters = FollowMe.getKeepBack(self) --, math.max(0, self.lastSpeed) * 3600);
            local distCrumbs   = math.floor(keepBackMeters / FollowMe.cMinDistanceBetweenDrops);
            local distFraction = keepBackMeters - (distCrumbs * FollowMe.cMinDistanceBetweenDrops);

            allowedToDrive = allowedToDrive and not (crumbIndexDiff < distCrumbs); -- Too far ahead?

            if allowedToDrive then
                if keepInFrontMeters > 0 then
                    avgSpeedKMH = avgSpeedKMH * 2
                elseif (crumbIndexDiff > distCrumbs) then
                    --avgSpeedKMH = math.max(5, avgSpeedKMH * 1.33)
                    --local factor = (math.min(1, (distCrumbs * FollowMe.cMinDistanceBetweenDrops) / 10) * 1.2) + 0.2
                    --avgSpeedKMH = avgSpeedKMH + avgSpeedKMH * factor
                    --acceleration = math.min(0.5, math.max(1.0, acceleration * factor))
                    
                    avgSpeedKMH = avgSpeedKMH + avgSpeedKMH * ((crumbIndexDiff - distCrumbs) / 5)
                elseif not ((crumbIndexDiff == distCrumbs) and (tDist >= distFraction)) then 
                    avgSpeedKMH = 0
                end
            end
        end;
    end;
    --
    if crumbIndexDiff <= 0 then
        -- Following leader directly...
        turnLightState = leader.turnLightState
        
        tx = lx;
        ty = ly;
        tz = lz;
        -- Rotate to see if the target is still "in front of us"
        local dx,dz = tx - cx, tz - cz;
        local trAngle = math.atan2(lrx,lrz);
        local nz = dx * math.sin(trAngle) + dz * math.cos(trAngle);
        --
        local distMetersDiff = distMeters - FollowMe.getKeepBack(self);

        allowedToDrive = allowedToDrive and (nz > 0);
        avgSpeedKMH = math.max(0, leader.lastSpeed) * 3600; -- only consider forward movement.

        if distMetersDiff < 0 then
            local factor = 1 - math.min(1, math.abs(distMetersDiff)/10)
            avgSpeedKMH = avgSpeedKMH * factor
            acceleration = 0
        elseif distMetersDiff > 1 then
            local factor = (math.min(1, distMetersDiff / 10) * 1.2) + 0.2
            avgSpeedKMH = avgSpeedKMH + 10 * factor
            acceleration = math.min(0.5, math.max(1.0, acceleration * factor))
        end
    end;

    if self.modFM.reduceSpeedTime > g_currentMission.time then
        --acceleration = math.max(0.1, acceleration * 0.5)
        avgSpeedKMH = math.max(1, avgSpeedKMH * 0.3)
    --else
    --    -- Reduce speed if "attack angle" against target is more than 45degrees.
    --    local lx,lz = AIVehicleUtil.getDriveDirection(self.components[1].node, tx,ty,tz);
    --    if (self.lastSpeed*3600 > 10) and (math.abs(math.atan2(lx,lz)) > (math.pi/4)) then
    --        acceleration = math.max(0.1, acceleration * 0.5)
    --        avgSpeedKMH = math.max(1, avgSpeedKMH * 0.3)
    --        self.modFM.reduceSpeedTime = g_currentMission.time + 250; -- For the next 250ms, keep speed reduced.
    --    end;
    end

    -- Check if any equipment is active, which will then limit the speed further
    local speedLimit,speedLimitActive = self:getSpeedLimit()
    if speedLimitActive then
        avgSpeedKMH = math.min(avgSpeedKMH, speedLimit)
    end
    
    --
    local pX,pY,pZ = worldToLocal(self.components[1].node, tx,ty,tz);
    AIVehicleUtil.driveToPoint(self, dt, acceleration, allowedToDrive, moveForwards, pX,pZ, avgSpeedKMH)
    
    return turnLightState
end;

--
--
--

function FollowMe.getWorldToScreen(nodeId)
    if nodeId ~= nil then
        local tx,ty,tz = getWorldTranslation(nodeId);
        if tx ~= nil then
            --ty = ty + self.displayYoffset;
            local sx,sy,sz = project(tx,ty,tz);
            if  sx<1 and sx>0  -- When "inside" screen
            and sy<1 and sy>0  -- When "inside" screen
            and          sz<1  -- Only draw when "in front of" camera
            then
                return sx,sy
            end
        end
    end
    return nil,nil
end

function FollowMe.renderShadedTextCenter(sx,sy, txt)
    setTextAlignment(RenderText.ALIGN_CENTER);
    setTextBold(true)
    setTextColor(0,0,0,1);
    renderText(sx+0.001, sy-0.001, 0.015, txt);
    setTextColor(1,1,1,1);
    renderText(sx, sy, 0.015, txt);
end

function FollowMe.draw(self)
    if self.modFM.ShowWarningTime > g_currentMission.time then
        g_currentMission:showBlinkingWarning(self.modFM.ShowWarningText)
    end;
    --
    local showFollowMeMy = FollowMe.keyModifier_FollowMeMy == nil or (FollowMe.keyModifier_FollowMeMy ~= nil and Input.isKeyPressed(FollowMe.keyModifier_FollowMeMy));
    local showFollowMeFl = FollowMe.keyModifier_FollowMeFl == nil or (FollowMe.keyModifier_FollowMeFl ~= nil and Input.isKeyPressed(FollowMe.keyModifier_FollowMeFl));
    
    if self.isHired then
        showFollowMeMy = false
    end
    --
    if showFollowMeMy and self.modFM.FollowVehicleObj ~= nil then
        local sx,sy = FollowMe.getWorldToScreen(self.modFM.FollowVehicleObj.components[1].node)
        if sx~=nil then
            local txt = g_i18n:getText("FollowMeLeader")
            if self.modFM.FollowVehicleObj.modFM.currentHelper ~= nil then -- FS17
                txt = txt .. (" '%s'"):format(self.modFM.FollowVehicleObj.modFM.currentHelper.name)
            end
            local dist = self.modFM.FollowKeepBack
            if (dist ~= 0) then
                txt = txt .. "\n" .. (g_i18n:getText((dist > 0) and "FollowMeDistAhead" or "FollowMeDistBehind")):format(math.abs(dist))
            end
            local offs = self.modFM.FollowXOffset;
            if (offs ~= 0) then
                txt = txt .. "\n" .. (g_i18n:getText((offs > 0) and "FollowMeOffLft" or "FollowMeOffRgt")):format(math.abs(offs))
            end
            FollowMe.renderShadedTextCenter(sx,sy, txt)
        end
        if (self.modFM.FollowState == FollowMe.STATE_WAITING) then
            local sx,sy = FollowMe.getWorldToScreen(self.components[1].node)
            if sx~=nil then
                FollowMe.renderShadedTextCenter(sx,sy, g_i18n:getText("FollowMePaused"))
            end
        end
    end
    --
    if showFollowMeFl and self.modFM.StalkerVehicleObj ~= nil then
        local sx,sy = FollowMe.getWorldToScreen(self.modFM.StalkerVehicleObj.components[1].node)
        if sx~=nil then
            local txt = g_i18n:getText("FollowMeFollower")
            if self.modFM.StalkerVehicleObj.modFM.currentHelper ~= nil then -- FS17
                txt = txt .. (" '%s'"):format(self.modFM.StalkerVehicleObj.modFM.currentHelper.name)
            end
            if (self.modFM.StalkerVehicleObj.modFM.FollowState == FollowMe.STATE_WAITING) then
                txt = txt .. g_i18n:getText("FollowMePaused")
            end
            local dist = self.modFM.StalkerVehicleObj.modFM.FollowKeepBack
            if (dist ~= 0) then
                txt = txt .. "\n" .. (g_i18n:getText((dist > 0) and "FollowMeDistBehind" or "FollowMeDistAhead")):format(math.abs(dist))
            end
            local offs = self.modFM.StalkerVehicleObj.modFM.FollowXOffset;
            if (offs ~= 0) then
                txt = txt .. "\n" .. (g_i18n:getText((offs > 0) and "FollowMeOffRgt" or "FollowMeOffLft")):format(math.abs(offs))
            end
            FollowMe.renderShadedTextCenter(sx,sy, txt)
        end
    end
    --
    if g_gameSettings:getValue("showHelpMenu") then
        if self.modFM.FollowVehicleObj ~= nil
        or (showFollowMeMy and g_currentMission:getHasPermission("hireAI"))
        then
            g_currentMission:addHelpButtonText(g_i18n:getText("FollowMeMyToggle"), InputBinding.FollowMeMyToggle, nil, GS_PRIO_HIGH);
        end;
        --
        if self.modFM.FollowVehicleObj ~= nil then
            g_currentMission:addExtraPrintText(string.format(g_i18n:getText("FollowMeKeysMyself"),FollowMe.keys_FollowMeMy), nil, GS_PRIO_NORMAL);
        end;
        --
        if self.modFM.StalkerVehicleObj ~= nil then
            g_currentMission:addExtraPrintText(string.format(g_i18n:getText("FollowMeKeysBehind"),FollowMe.keys_FollowMeFl), nil, GS_PRIO_NORMAL);
        end;
--[[DEBUG
    else
        --if self.modFM.FollowVehicleObj ~= nil then
            local yPos = 0.9;
            setTextColor(1,1,1,1);
            setTextBold(true);
            local keys = {}
            for k,_ in pairs(FollowMe.debugDraw) do
                table.insert(keys,k);
            end;
            table.sort(keys);
            for _,k in pairs(keys) do
                local v = FollowMe.debugDraw[k];
                yPos = yPos - 0.02;
                renderText(0.01, yPos, 0.02, v[1]);
                renderText(0.11, yPos, 0.02, v[2]);
            end;
            setTextBold(false);
        --end;
--DEBUG]]
    end;

--[[DEBUG
    if Vehicle.debugRendering and self.isServer then
        --FollowMe.drawDebug(self);

        local keys = {}
        for k,_ in pairs(FollowMe.debugDraw) do
            table.insert(keys,k);
        end;
        table.sort(keys);
        local txt = "";
        for _,k in pairs(keys) do
            txt = txt .. FollowMe.debugDraw[k][1] .." ".. FollowMe.debugDraw[k][2] .. "\n";
        end;

        setTextBold(false);
        setTextColor(0.85, 0.85, 1, 1);
        setTextAlignment(RenderText.ALIGN_LEFT);
        renderText(0.005, 0.5, 0.02, txt);

        if FollowMe.dbgTarget then
            -- Draw a "dot" as the target for the follower
            local x,y,z = project(FollowMe.dbgTarget[1],FollowMe.dbgTarget[2],FollowMe.dbgTarget[3]);
            if  x<1 and x>0
            and y<1 and y>0
            --and z<1 and z>0
            then
                if (g_currentMission.time % 500) < 250 then
                    setTextColor(1,1,1,1);
                else
                    setTextColor(0.5,0.5,1,1);
                end;
                setTextAlignment(RenderText.ALIGN_CENTER);
                renderText(x,y, 0.04, "."); -- Not exactly at the pixel-point, but close enough for debugging.
                setTextAlignment(RenderText.ALIGN_LEFT);
            end
        end;
    end
--DEBUG]]

    setTextAlignment(RenderText.ALIGN_LEFT);
    setTextBold(false);
    setTextColor(1,1,1,1);
end;

---
---
---

FollowMeRequestEvent = {};
FollowMeRequestEvent_mt = Class(FollowMeRequestEvent, Event);

InitEventClass(FollowMeRequestEvent, "FollowMeRequestEvent");

function FollowMeRequestEvent:emptyNew()
    local self = Event:new(FollowMeRequestEvent_mt);
    self.className = "FollowMeRequestEvent";
    return self;
end;

function FollowMeRequestEvent:new(vehicle, cmdId, reason)
    local self = FollowMeRequestEvent:emptyNew()
    self.vehicle    = vehicle
    self.cmdId      = Utils.getNoNil(cmdId, 0)
    self.reason     = Utils.getNoNil(reason, 0)
    self.distance   = Utils.getNoNil(vehicle.modFM.FollowKeepBack, 0)
    self.offset     = Utils.getNoNil(vehicle.modFM.FollowXOffset, 0)
    return self;
end;

function FollowMeRequestEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.vehicle);
    streamWriteUIntN(      streamId, self.cmdId,  FollowMe.NUM_BITS_COMMAND)
    streamWriteUIntN(      streamId, self.reason, FollowMe.NUM_BITS_REASON)
    streamWriteInt8(       streamId, self.distance)
    streamWriteInt8(       streamId, self.offset * 2)
end;

function FollowMeRequestEvent:readStream(streamId, connection)
    self.vehicle  = readNetworkNodeObject(streamId);
    self.cmdId    = streamReadUIntN(      streamId, FollowMe.NUM_BITS_COMMAND)
    self.reason   = streamReadUIntN(      streamId, FollowMe.NUM_BITS_REASON)
    self.distance = streamReadInt8(       streamId)
    self.offset   = streamReadInt8(       streamId) / 2
    
    if self.vehicle ~= nil then
        if     self.cmdId == FollowMe.COMMAND_START then
            FollowMe.startFollowMe(self.vehicle, connection)
        elseif self.cmdId == FollowMe.COMMAND_STOP then
            FollowMe.stopFollowMe(self.vehicle, self.reason)
        elseif self.cmdId == FollowMe.COMMAND_WAITRESUME then
            FollowMe.waitResumeFollowMe(self.vehicle, self.reason)
        else
            FollowMe.changeDistance(self.vehicle, { self.distance } )
            FollowMe.changeXOffset( self.vehicle, { self.offset } )
        end
    end;
end;


---
---
---

FollowMeResponseEvent = {};
FollowMeResponseEvent_mt = Class(FollowMeResponseEvent, Event);

InitEventClass(FollowMeResponseEvent, "FollowMeResponseEvent");

function FollowMeResponseEvent:emptyNew()
    local self = Event:new(FollowMeResponseEvent_mt);
    self.className = "FollowMeResponseEvent";
    return self;
end;

function FollowMeResponseEvent:new(vehicle, stateId, reason, helper)
    local self = FollowMeResponseEvent:emptyNew()
    self.vehicle            = vehicle
    self.stateId            = Utils.getNoNil(stateId, 0)
    self.reason             = Utils.getNoNil(reason, 0)
    self.distance           = Utils.getNoNil(vehicle.modFM.FollowKeepBack, 0)
    self.offset             = Utils.getNoNil(vehicle.modFM.FollowXOffset, 0)
    self.helperIndex        = 0
    if helper ~= nil then 
        self.helperIndex = helper.index
    end
    self.followVehicleObj   = vehicle.modFM.FollowVehicleObj 
    self.stalkerVehicleObj  = vehicle.modFM.StalkerVehicleObj
    return self;
end;

function FollowMeResponseEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteUIntN(      streamId, self.stateId,  FollowMe.NUM_BITS_STATE)
    streamWriteUIntN(      streamId, self.reason,   FollowMe.NUM_BITS_REASON)
    streamWriteInt8(       streamId, self.distance)
    streamWriteInt8(       streamId, self.offset * 2)
    streamWriteUInt8(      streamId, self.helperIndex)
    writeNetworkNodeObject(streamId, self.followVehicleObj )
    writeNetworkNodeObject(streamId, self.stalkerVehicleObj)
end;

function FollowMeResponseEvent:readStream(streamId, connection)
    self.vehicle            = readNetworkNodeObject(streamId)
    self.stateId            = streamReadUIntN(      streamId, FollowMe.NUM_BITS_STATE)
    self.reason             = streamReadUIntN(      streamId, FollowMe.NUM_BITS_REASON)
    self.distance           = streamReadInt8(       streamId)
    self.offset             = streamReadInt8(       streamId) / 2
    self.helperIndex        = streamReadUInt8(      streamId)
    self.followVehicleObj   = readNetworkNodeObject(streamId)
    self.stalkerVehicleObj  = readNetworkNodeObject(streamId)
    
    if self.vehicle ~= nil then
        if self.helperIndex == 0 then
            self.helperIndex = nil
        end
    
        FollowMe.changeDistance(self.vehicle, { self.distance } ,true )
        FollowMe.changeXOffset( self.vehicle, { self.offset }   ,true )
        
        if     self.stateId == FollowMe.STATE_STARTING then
            FollowMe.onStartFollowMe(self.vehicle, self.followVehicleObj, self.helperIndex, true)
        elseif self.stateId == FollowMe.STATE_STOPPING then
            FollowMe.onStopFollowMe(self.vehicle, self.reason, true)
        else
            if self.reason ~= 0 then
                FollowMe.showReason(self.vehicle, nil, self.reason, nil)
            end
            self.vehicle.modFM.FollowState       = self.stateId
            self.vehicle.modFM.FollowVehicleObj  = self.followVehicleObj
            self.vehicle.modFM.StalkerVehicleObj = self.stalkerVehicleObj
        end
    end;
end;


--
print(string.format("Script loaded: FollowMe.lua (v%s)", FollowMe.version));
