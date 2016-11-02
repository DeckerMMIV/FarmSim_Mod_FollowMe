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

FollowMe.cMinDistanceBetweenDrops        =   5;   -- TODO, make configurable
FollowMe.cBreadcrumbsMaxEntries          = 100;   -- TODO, make configurable
FollowMe.cMstimeBetweenDrops             =  40;   -- TODO, make configurable
FollowMe.debugDraw = {}

FollowMe.COMMAND_NONE       = 0
FollowMe.COMMAND_START      = 1
FollowMe.COMMAND_WAITRESUME = 2
FollowMe.COMMAND_STOP       = 3

FollowMe.STATE_NONE         = 0
FollowMe.STATE_FOLLOWING    = 1
FollowMe.STATE_WAITING      = 2
FollowMe.STATE_STOPPING     = 3

FollowMe.REASON_NONE                = 0
FollowMe.REASON_USER_ACTION         = 1
FollowMe.REASON_NO_TRAIL_FOUND      = 2    
FollowMe.REASON_TOO_FAR_BEHIND      = 3
FollowMe.REASON_LEADER_REMOVED      = 4


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
    
    -- Test that these four use the same modifier-key
       FollowMe.keyModifier_FollowMeFl  = getKeyIdOfModifier(InputBinding.FollowMeFlStop);
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
    self.modFM.FollowKeepBack = 10;
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
--[[DEBUG
    self.modFM.dbgAcceleration = 0;
    self.modFM.dbgAllowedToDrive = false;
--DEBUG]]
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
        FollowMe.addDrop(self, wx,wy,wz, 30/3600);
    end;

    if savegame ~= nil and not savegame.resetVehicles then
        local value = getXMLString(savegame.xmlFile, savegame.key .. "#followMe")
        local keepBack, offset = Utils.getVectorFromString(value);
        if keepBack ~= nil then
            FollowMe.changeDistance(self, { keepBack } ); -- Absolute change
        end
        if offset ~= nil then
            FollowMe.changeXOffset(self, { offset } ); -- Absolute change
        end
    end
end;

function FollowMe.delete(self)
    if self.isServer then
        if self.modFM.StalkerVehicleObj ~= nil then
            -- Stop the stalker-vehicle
            FollowMe.stopFollowMe(self.modFM.StalkerVehicleObj, FollowMe.REASON_LEADER_REMOVED);
        end;
        if self.modFM.FollowVehicleObj ~= nil then
            -- Stop ourself
            FollowMe.stopFollowMe(self, FollowMe.REASON_NONE);
        end
    end;
end;


FollowMe.NUM_BITS_COMMAND = 2
FollowMe.NUM_BITS_STATE   = 2
FollowMe.NUM_BITS_REASON  = 3

function FollowMe.NEWsharedWriteStream(serverToClients, streamId, vehObj, followsObj, stalkedByObj, cmdId, stateId, keepBackDistance, xOffset, reason, helperIndex)
    writeNetworkNodeObject(streamId, vehObj);
    streamWriteInt8(       streamId, Utils.getNoNil(keepBackDistance, 0))
    streamWriteInt8(       streamId, Utils.getNoNil(xOffset, 0) * 2)
    streamWriteUIntN(      streamId, Utils.getNoNil(cmdId,   0), FollowMe.NUM_BITS_COMMAND)
    if serverToClients then
        streamWriteUIntN(  streamId, Utils.getNoNil(stateId, 0), FollowMe.NUM_BITS_STATE)
        streamWriteUIntN(  streamId, Utils.getNoNil(reason,  0), FollowMe.NUM_BITS_REASON)
        streamWriteBool(   streamId, followsObj   ~= nil)
        streamWriteBool(   streamId, stalkedByObj ~= nil)
        if followsObj ~= nil then
            streamWriteUInt8(  streamId, Utils.getNoNil(helperIndex, 0))
            writeNetworkNodeObject(streamId, followsObj)
        end
        if stalkedByObj ~= nil then
            writeNetworkNodeObject(streamId, stalkedByObj)
        end
    end
end;

function FollowMe.NEWsharedReadStream(serverToClients, streamId)
    local stateId, followsObj, stalkedByObj, reason, helperIndex

    local vehObj            = readNetworkNodeObject(streamId);
    local keepBackDistance  = streamReadInt8( streamId);
    local xOffset           = streamReadInt8( streamId) / 2;
    local cmdId             = streamReadUIntN(streamId, FollowMe.NUM_BITS_COMMAND)
    if serverToClients then
        stateId             = streamReadUIntN(streamId, FollowMe.NUM_BITS_STATE)
        reason              = streamReadUIntN(streamId, FollowMe.NUM_BITS_REASON)
        local hasFollowsObj = streamReadBool( streamId)
        local hasStalkerObj = streamReadBool( streamId)
        if hasFollowsObj then
            helperIndex     = streamReadUInt8( streamId)
            followsObj      = readNetworkNodeObject(streamId)
        end
        if hasStalkerObj then
            stalkedByObj    = readNetworkNodeObject(streamId)
        end
    end
    if helperIndex == 0 then
        helperIndex = nil
    end
    
    return vehObj, followsObj, stalkedByObj, cmdId, stateId, keepBackDistance, xOffset, reason, helperIndex
end;


function FollowMe.writeStream(self, streamId, connection)
    FollowMe.NEWsharedWriteStream(
        true,   -- 'true' = server to clients
        streamId,
        self,
        self.modFM.FollowVehicleObj,
        self.modFM.StalkerVehicleObj,
        0, -- no command
        self.modFM.FollowState,
        self.modFM.FollowKeepBack,
        self.modFM.FollowXOffset,
        0, -- no reason
        self.modFM.helperIndex
    );
end;

function FollowMe.readStream(self, streamId, connection)
    local dummyVeh, dummyCmd, dummyReason
    --
    dummyVeh,
    self.modFM.FollowVehicleObj,
    self.modFM.StalkerVehicleObj,
    dummyCmd,
    self.modFM.FollowState,
    self.modFM.FollowKeepBack,
    self.modFM.FollowXOffset,
    dummyReason,
    self.modFM.helperIndex  = FollowMe.NEWsharedReadStream(true, streamId); -- 'true' = server to clients
end;


function FollowMe.getSaveAttributesAndNodes(self, nodeIdent)
    local attributes = nil
    if self.modFM ~= nil then
        attributes = ('followMe="%.0f %.1f"'):format(self.modFM.FollowKeepBack, self.modFM.FollowXOffset)
    end
    return attributes, nil;
end;


function FollowMe.mouseEvent(self, posX, posY, isDown, isUp, button)
end;

function FollowMe.keyEvent(self, unicode, sym, modifier, isDown)
end;

function FollowMe.setWarning(self, txt, noSendEvent)
    self.modFM.ShowWarningText = txt;   -- must be a string that can be given to g_i18n:getText()
    self.modFM.ShowWarningTime = g_currentMission.time + 2500;
    ----
    --if self.isServer and not noSendEvent then
    --    self.modFM.isDirty = true;
    --end;
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
            trans = targetXYZ,
            rot = crumb.rot,
            avgSpeed = crumb.avgSpeed,
            turnLightState = crumb.turnLightState,
        };
    end;
end;

function FollowMe.addDrop(self, wx,wy,wz, avgSpeed, turnLightState)
    assert(g_server ~= nil);

    self.modFM.DropperCurrentIndex = self.modFM.DropperCurrentIndex + 1; -- Keep incrementing index, so followers will be able to detect if they get too far behind of the circular-array.
    local dropIndex = 1+((self.modFM.DropperCurrentIndex-1) % FollowMe.cBreadcrumbsMaxEntries);

    local rx,ry,rz  = localDirectionToWorld(self.components[1].node, 0,0,1);
    self.modFM.DropperCircularArray[dropIndex] = {
        trans = {wx,wy,wz},
        rot = {rx,ry,rz},
        avgSpeed = avgSpeed,
        turnLightState = turnLightState,
    };

    --log(string.format("Crumb #%d(%d): trans=%f/%f/%f, rot=%f/%f/%f, avgSpeed=%f, movTime=%f", FollowMe.gBreadcrumbsCurrentDropIndex,dropIndex, wx,wy,wz, rx,ry,rz, avgSpeed, self.modFM.movingTime));
end;

function FollowMe.changeDistance(self, newValue, noSendEvent)
    if type(newValue) == "table" then
        newValue = newValue[1] -- Absolute change
    else
        newValue = self.modFM.FollowKeepBack + newValue -- Relative change
    end
    self.modFM.FollowKeepBack = Utils.clamp(newValue, -50, 127); -- Min -128 and Max 127 due to writeStreamInt8().
    if not noSendEvent then
        self.modFM.delayDirty = g_currentMission.time + 500;
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
        self.modFM.delayDirty = g_currentMission.time + 500;
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
            self.modFM.delayDirty = g_currentMission.time + 500;
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

    local activeForInput = not g_gui:getIsGuiVisible() and not g_currentMission.isPlayerFrozen and self.isEntered;

    if activeForInput and not self.isConveyorBelt then
        if InputBinding.hasEvent(InputBinding.FollowMeMyToggle) then
            if self.followMeIsStarted then
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
                if stalker.followMeIsStarted then
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
    
    --if not self.isServer then
    --    return
    --end
    ---- Anything below is only server-side
    
    if self.modFM.FollowVehicleObj ~= nil then
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
        if self.modFM.FollowVehicleObj ~= nil then 
            -- Have leading vehicle to follow.
            local turnLightState = FollowMe.updateFollowMovement(self, dt);

            if self.setBeaconLightsVisibility ~= nil then
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
        elseif (self.reverserDirection * self.movingDirection > 0) then  -- Must drive forward to drop crumbs
            self.modFM.sumSpeed = self.modFM.sumSpeed + self.lastSpeed;
            self.modFM.sumCount = self.modFM.sumCount + 1;
            --
            local wx,wy,wz = getWorldTranslation(self.components[1].node); -- current position
            local pwx,pwy,pwz = unpack(self.modFM.DropperCircularArray[1+((self.modFM.DropperCurrentIndex-1) % FollowMe.cBreadcrumbsMaxEntries)].trans); -- previous position
            local distancePrevDrop = Utils.vector2Length(pwx-wx, pwz-wz);
            if distancePrevDrop >= FollowMe.cMinDistanceBetweenDrops then
                local avgSpeed = math.max((self.modFM.sumSpeed / (self.modFM.sumCount>0 and self.modFM.sumCount or 1)), (5/3600));
                FollowMe.addDrop(self, wx,wy,wz, avgSpeed, self.turnLightState);
                --
                self.modFM.sumSpeed = 0;
                self.modFM.sumCount = 0;
            end;
        end;
    end;

    FollowMe.sendUpdate(self);
end;

function FollowMe.sendUpdate(self) --, stateId)
    if self.modFM.isDirty
    --or stateId ~= nil
    or (self.modFM.delayDirty ~= nil and self.modFM.delayDirty < g_currentMission.time)
    then
        self.modFM.isDirty = false;
        self.modFM.delayDirty = nil;
        --
        
        --if noEventSend == nil or noEventSend == false then
            if g_server ~= nil then
                g_server:broadcastEvent(FollowMeEvent:new(self, FollowMe.COMMAND_NONE, FollowMe.REASON_NONE, nil), nil, nil, self);
            else
                g_client:getServerConnection():sendEvent(FollowMeEvent:new(self, FollowMe.COMMAND_NONE, FollowMe.REASON_NONE, nil));
            end
        --end
        
        
        --if self.isServer then
        --    ---- Remove warning-text if not needed anymore
        --    --if self.modFM.ShowWarningTime < g_currentMission.time then
        --    --    self.modFM.ShowWarningText = nil;
        --    --end;
        --    ---- Broadcast current state to all clients.
        --    --FollowMeEvent.sendEvent(self, self.modFM.FollowState);
        --else
        --    ---- Only send the client's action-commands to server.
        --    --FollowMeEvent.sendEvent(self, Utils.getNoNil(stateId, FollowMe.STATE_NONE));
        --end;
    end;
end;

--function FollowMe:recvUpdate(stateId, keepBackDist, xOffset, followsObj, stalkedByObj, warnTxt, helperIndex)
--    if self.isServer then
--        -- Received a client's action-commands. Set and mark dirty to broadcast to clients.
--        FollowMe.changeDistance(self, { keepBackDist }, false);
--        FollowMe.changeXOffset(self, { xOffset }, false);
--        --if stateId ~= FollowMe.STATE_NONE then
--        --    FollowMe.commandFollowMe(self, stateId, false);
--        --end;
--        --if self.modFM.delayDirty ~= nil then
--            self.modFM.isDirty = true;
--        --end
--        -- the next updateTick() will broadcast to all clients
--    else
--        -- Received the server's state.
--        self.modFM.FollowState = stateId;
--        FollowMe.changeDistance(self, { keepBackDist }, true);
--        FollowMe.changeXOffset(self, { xOffset }, true);
--        if warnTxt ~= nil and warnTxt ~= "" then
--            FollowMe.setWarning(self, warnTxt, true)
--        end;
--        self.modFM.StalkerVehicleObj = stalkedByObj
--        self.modFM.FollowVehicleObj = followsObj
--    end;
--end;

-- Copied from FS17-AIVehicle, and adapted for FollowMe
function FollowMe.startFollowMe(self, helperIndex, noEventSend)
    if helperIndex ~= nil then
        self.currentHelper = HelperUtil.helperIndexToDesc[helperIndex]
    else
        self.currentHelper = HelperUtil.getRandomHelper()
    end

    HelperUtil.useHelper(self.currentHelper)

    --g_currentMission.missionStats:updateStats("workersHired", 1);

    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(FollowMeEvent:new(self, FollowMe.COMMAND_START, FollowMe.REASON_NONE, helperIndex), nil, nil, self);
        else
            g_client:getServerConnection():sendEvent(FollowMeEvent:new(self, FollowMe.COMMAND_START, FollowMe.REASON_NONE, helperIndex));
        end
    end

    FollowMe.onStartFollowMe(self);
end


-- Copied from FS17-AIVehicle, and adapted for FollowMe
function FollowMe.stopFollowMe(self, reason, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(FollowMeEvent:new(self, FollowMe.COMMAND_STOP, reason, nil), nil, nil, self);
        else
            g_client:getServerConnection():sendEvent(FollowMeEvent:new(self, FollowMe.COMMAND_STOP, reason, nil));
        end
    end

    --if reason ~= nil and reason ~= AIVehicle.STOP_REASON_USER then
    --    local notificationType = FSBaseMission.INGAME_NOTIFICATION_CRITICAL
    --    if reason == AIVehicle.STOP_REASON_REGULAR then
    --        notificationType = FSBaseMission.INGAME_NOTIFICATION_OK
    --    end
    --    g_currentMission:addIngameNotification(notificationType, string.format(g_i18n:getText(AIVehicle.REASON_TEXT_MAPPING[reason]), self.currentHelper.name))
    --end

    if reason ~= nil then
        if     reason == FollowMe.REASON_NONE           then
            --
        elseif reason == FollowMe.REASON_USER_ACTION    then
            g_currentMission:addIngameNotification(
                {0.5, 0.5, 1.0, 1.0}, --FSBaseMission.INGAME_NOTIFICATION_INFO, 
                "'Follower' vehicle stopped (by player)"
            )
        elseif reason == FollowMe.REASON_NO_TRAIL_FOUND then    
            FollowMe.setWarning(self, "FollowMeDropperNotFound");
        elseif reason == FollowMe.REASON_TOO_FAR_BEHIND then
            --FollowMe.setWarning(self, "FollowMeTooFarBehind");
            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_CRITICAL, 
                "'Follower' vehicle stopped (too far behind)"
            )
        elseif reason == FollowMe.REASON_LEADER_REMOVED then
            g_currentMission:addIngameNotification(
                {0.5, 0.5, 1.0, 1.0}, --FSBaseMission.INGAME_NOTIFICATION_INFO, 
                "'Follower' vehicle stopped (leader vanished)"
            )
        end
    end
    
    HelperUtil.releaseHelper(self.currentHelper)

    --g_currentMission.missionStats:updateStats("workersHired", -1);

    FollowMe.onStopFollowMe(self);
end


function FollowMe.waitResumeFollowMe(self, reason, noEventSend)
    FollowMe.onWaitResumeFollowMe(self);
    
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(FollowMeEvent:new(self, FollowMe.COMMAND_WAITRESUME, reason, nil), nil, nil, self);
        else
            g_client:getServerConnection():sendEvent(FollowMeEvent:new(self, FollowMe.COMMAND_WAITRESUME, reason, nil));
        end
    end
end


-- Copied from FS17-AIVehicle, and adapted for FollowMe
function FollowMe.onStartFollowMe(self)
    if not self.followMeIsStarted then
        --if not self.isHired then
        --    AIVehicle.numHirablesHired = AIVehicle.numHirablesHired + 1;
        --end;
        --self.isHired = true;
        self.isHirableBlocked = false;
        self.forceIsActive = true;
        self.stopMotorOnLeave = false;
        self.steeringEnabled = false;
        self.disableCharacterOnLeave = false;

        if self.vehicleCharacter ~= nil then
           self.vehicleCharacter:delete();
           self.vehicleCharacter:loadCharacter(self.currentHelper.xmlFilename, getUserRandomizedMpColor(self.currentHelper.name))
           if self.isEntered then
                self.vehicleCharacter:setCharacterVisibility(false)
           end
        end

        local hotspotX, _, hotspotZ = getWorldTranslation(self.rootNode);

        local _, textSize = getNormalizedScreenValues(0, 6);
        local _, textOffsetY = getNormalizedScreenValues(0, 11.5);
        local width, height = getNormalizedScreenValues(15,15)
        self.mapAIHotspot = g_currentMission.ingameMap:createMapHotspot("helper", self.currentHelper.name, nil, getNormalizedUVs({776, 520, 240, 240}), {0.052, 0.1248, 0.672, 1}, hotspotX, hotspotZ, width, height, false, false, true, self.components[1].node, true, MapHotspot.CATEGORY_AI, textSize, textOffsetY, {1, 1, 1, 1}, nil, getNormalizedUVs({776, 520, 240, 240}), Overlay.ALIGN_VERTICAL_MIDDLE, 0.7)

        self.followMeIsStarted = true;

        --if self.isServer then
        --    self:getVehicleData();
        --    self:setDriveStrategies();
        --end
        --
        --self:aiTurnOn();
        --for _,implement in pairs(self.aiImplementList) do
        --    implement.object:aiTurnOn();
        --end
        
        if self.isServer then        
            local closestVehicle = FollowMe.findVehicleInFront(self)
            if closestVehicle == nil then
                FollowMe.stopFollowMe(self, FollowMe.REASON_NO_TRAIL_FOUND)
            else
                closestVehicle.modFM.StalkerVehicleObj = self
                closestVehicle.modFM.isDirty = true
                
                self.modFM.FollowVehicleObj = closestVehicle
                self.modFM.isDirty = true
                
                self.modFM.FollowState = FollowMe.STATE_FOLLOWING
            end
        end
    end
end


-- Copied from FS17-AIVehicle, and adapted for FollowMe
function FollowMe.onStopFollowMe(self)
    if self.followMeIsStarted then
        --if self.isHired then
        --    AIVehicle.numHirablesHired = math.max(AIVehicle.numHirablesHired - 1, 0);
        --end;

        --self.isHired = false;

        self.forceIsActive = false;
        self.stopMotorOnLeave = true;
        self.steeringEnabled = true;

        self.disableCharacterOnLeave = true;

        if self.vehicleCharacter ~= nil then
           self.vehicleCharacter:delete();
        end

        if self.isEntered or self.isControlled then
            if self.vehicleCharacter ~= nil then
                self.vehicleCharacter:loadCharacter(PlayerUtil.playerIndexToDesc[self.playerIndex].xmlFilename, self.playerColorIndex)
                self.vehicleCharacter:setCharacterVisibility(not self.isEntered)
            end
        end;
        self.currentHelper = nil

        if self.mapAIHotspot ~= nil then
            g_currentMission.ingameMap:deleteMapHotspot(self.mapAIHotspot);
            self.mapAIHotspot = nil;
        end

        self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF, true);
        if self.isServer then
            WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeedReal, 0, true, self.requiredDriveMode);
        end

        if not g_currentMission.missionInfo.automaticMotorStartEnabled and not self.isEntered then
            self:stopMotor(true);
        end

        --if self.isServer then
        --    if self.driveStrategies ~= nil and #self.driveStrategies > 0 then
        --        for i=#self.driveStrategies,1,-1 do
        --            self.driveStrategies[i]:delete();
        --            table.remove(self.driveStrategies, i);
        --        end
        --        self.driveStrategies = {};
        --    end
        --end
        --
        --self:aiTurnOff();
        --for _,implement in pairs(self.aiImplementList) do
        --    if implement.object ~= nil then
        --        implement.object:aiTurnOff();
        --    end;
        --end
        
        if self.isServer then
            if self.modFM.FollowVehicleObj ~= nil then
                self.modFM.FollowVehicleObj.modFM.StalkerVehicleObj = nil
                self.modFM.FollowVehicleObj.modFM.isDirty = true
            end

            self.modFM.FollowVehicleObj = nil
            self.modFM.isDirty = true

            self.modFM.FollowState = FollowMe.STATE_NONE
        end

        self.followMeIsStarted = false;
    end
end

function FollowMe.onWaitResumeFollowMe(self)
    if self.followMeIsStarted then
        if self.isServer then
            if self.modFM.FollowState == FollowMe.STATE_FOLLOWING then
                self.modFM.FollowState = FollowMe.STATE_WAITING
                self.modFM.isDirty = true
            elseif self.modFM.FollowState == FollowMe.STATE_WAITING then
                self.modFM.FollowState = FollowMe.STATE_FOLLOWING
                self.modFM.isDirty = true
            end
        end
    end
end


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


--function FollowMe.commandFollowMe(self, stateId, noSendEvent)
--    if not self.modFM.IsInstalled then
--        FollowMe.setWarning(self, "FollowMeNotAvailable");
--    elseif self.isServer then
--        if self.isHired then
--            -- Already an AI controlling this vehicle.
--            return
--        end
--        
--        if stateId == FollowMe.STATE_TOGGLE then
--            local toggleStates = {
--                [FollowMe.STATE_NONE     ] = FollowMe.STATE_START,
--                [FollowMe.STATE_FOLLOWING] = FollowMe.STATE_STOP ,
--                [FollowMe.STATE_WAITING  ] = FollowMe.STATE_STOP ,
--                [FollowMe.STATE_STOPPING ] = FollowMe.STATE_START,
--            }
--            stateId = Utils.getNoNil(toggleStates[self.modFM.FollowState], FollowMe.STATE_NONE);
--        end
--        --
--        if stateId == FollowMe.STATE_START then
--            FollowMe.startFollowMe(self, noSendEvent);
--        elseif stateId == FollowMe.STATE_STOP then
--            FollowMe.stopFollowMe(self, noSendEvent);
--        elseif stateId == FollowMe.STATE_WAITRESUME then
--            if self.modFM.FollowState == FollowMe.STATE_FOLLOWING then
--                self.modFM.FollowState = FollowMe.STATE_WAITING
--                self.modFM.isDirty = true;
--            elseif self.modFM.FollowState == FollowMe.STATE_WAITING then
--                self.modFM.FollowState = FollowMe.STATE_FOLLOWING
--                self.modFM.isDirty = true;
--            end
--        end
--    else
--        FollowMe.sendUpdate(self, stateId);
--    end;
--end;
--
--function FollowMe.setStalker(self, stalkedByObj, noSendEvent)
--    self.modFM.StalkerVehicleObj = stalkedByObj;
--    self.modFM.isDirty = self.isServer and true or self.modFM.isDirty;
--end;
--
--function FollowMe.setStateLeaderStalker(self, leaderObj, stalkedByObj, helperIndex)
--    -- Try to fix the problem of clients not seeing wheel-rotation and the "farmer-in-the-seat".
--    if leaderObj ~= nil and leaderObj ~= self.modFM.FollowVehicleObj then
--        self.forceIsActive = true;
--        self.stopMotorOnLeave = false;
--        self.steeringEnabled = false;
--        self.deactivateOnLeave = false;  -- ???
--        self.disableCharacterOnLeave = false;
--        
--        if self.vehicleCharacter ~= nil then
--            self.vehicleCharacter:delete()
--            
--            if helperIndex ~= nil then
--                helperIndex = Utils.clamp(helperIndex, 1, table.getn(HelperUtil.helperIndexToDesc))
--                
--                self.currentHelper = HelperUtil.helperIndexToDesc[helperIndex]
--                HelperUtil.useHelper(self.currentHelper)
--                self.vehicleCharacter:loadCharacter(self.currentHelper.xmlFilename, getUserRandomizedMpColor(self.currentHelper.name))
--                if self.isEntered then
--                    self.vehicleCharacter:setCharacterVisibility(false)
--                end
--            end
--        end
--    elseif nil ~= self.modFM.FollowVehicleObj then
--        self.forceIsActive = false;
--        self.stopMotorOnLeave = true;
--        self.steeringEnabled = true;
--        --self.deactivateOnLeave = true;
--        self.disableCharacterOnLeave = true;
--        
--        if self.vehicleCharacter ~= nil then
--            self.vehicleCharacter:delete()
--        end        
--        
--        if self.currentHelper ~= nil then
--            HelperUtil.releaseHelper(self.currentHelper)
--        end
--    end;
--
--    self.modFM.FollowVehicleObj  = leaderObj
--    self.modFM.StalkerVehicleObj = stalkedByObj
--    self.modFM.helperIndex       = helperIndex
--end;
--
--function FollowMe.startFollowMe(self, noEventSend)
--    assert(g_server ~= nil);
--
--    if self.modFM.FollowVehicleObj ~= nil then
--        return;
--    end;
--
--    -- Make sure the motor is turned on
--    if not self.isMotorStarted then
--        FollowMe.setWarning(self, "FollowMeStartEngine");
--        return;
--    end;
--
--    --
--    local wx,wy,wz = getWorldTranslation(self.components[1].node);
--    local rx,ry,rz = localDirectionToWorld(self.components[1].node, 0,0,1);
--    local rlength = Utils.vector2Length(rx,rz);
--    local rotDeg = math.deg(math.atan2(rx/rlength,rz/rlength));
--    local rotRad = Utils.degToRad(rotDeg-45.0);
--    local rotRad = Utils.degToRad(rotDeg-45.0);
--    --log(string.format("getWorldTranslation:%f/%f/%f - localDirectionToWorld:%f/%f/%f - rDeg:%f - rRad:%f", wx,wy,wz, rx,ry,rz, rotDeg, rotRad));
--
--    -- Find closest vehicle, that is in front of self.
--    local closestDistance = 50;
--    local closestVehicle = nil;
--    for _,vehicleObj in pairs(g_currentMission.steerables) do
--        if vehicleObj.modFM ~= nil -- (v2.0.6) Make sure its a vehicle that has the FollowMe specialization added.
--        and vehicleObj.modFM.DropperCircularArray ~= nil -- Make sure other vehicle has circular array
--        and vehicleObj.modFM.StalkerVehicleObj == nil then -- and is not already stalked by something.
--            local vx,vy,vz = getWorldTranslation(vehicleObj.components[1].node);
--            local dx,dz = vx-wx, vz-wz;
--            local dist = Utils.vector2Length(dx,dz);
--            if (dist < closestDistance) then
--                -- Rotate to see if vehicleObj is "in front of us"
--                local nx = dx * math.cos(rotRad) - dz * math.sin(rotRad);
--                local nz = dx * math.sin(rotRad) + dz * math.cos(rotRad);
--                if (nx > 0) and (nz > 0) then
--                    closestDistance = dist;
--                    closestVehicle = vehicleObj;
--                end;
--            end;
--        end;
--    end;
--
--    if closestVehicle == nil then
--        FollowMe.setWarning(self, "FollowMeDropperNotFound");
--        return;
--    end;
--
--    -- Find closest "breadcrumb"
--    self.modFM.FollowCurrentIndex = 0;
--    local closestDistance = 50;
--    for i=closestVehicle.modFM.DropperCurrentIndex, math.max(closestVehicle.modFM.DropperCurrentIndex - FollowMe.cBreadcrumbsMaxEntries,1), -1 do
--        local crumb = closestVehicle.modFM.DropperCircularArray[1+((i-1) % FollowMe.cBreadcrumbsMaxEntries)];
--        if crumb ~= nil then
--            local x,y,z = unpack(crumb.trans);
--            -- Translate
--            local dx,dz = x-wx, z-wz;
--            local dist = Utils.vector2Length(dx,dz);
--            --local r = Utils.getYRotationFromDirection(dx,dz);
--            --log(string.format("#%d - xz:%f/%f - dxdz:%f/%f - r:%f - dist:%f", i, x,z, dx,dz, r, dist));
--            if (dist > 2) and (dist < closestDistance) then
--                -- Rotate to see if the point is "in front of us"
--                local nx = dx * math.cos(rotRad) - dz * math.sin(rotRad);
--                local nz = dx * math.sin(rotRad) + dz * math.cos(rotRad);
--                if (nx > 0) and (nz > 0) then
--                    --log(string.format("#%d - xz:%f/%f - dxdz:%f/%f - dist:%f - nxnz:%f/%f", i, x,z, dx,dz, dist, nx,nz));
--                    closestDistance = dist;
--                    self.modFM.FollowCurrentIndex = i;
--                end;
--            end;
--            --
--            if self.modFM.FollowCurrentIndex ~= 0 and dist > closestDistance then
--                -- If crumb is "going further away" from already found one, then stop searching.
--                break;
--            end;
--        end;
--    end;
--    --log(string.format("ClosestDist:%f, index:%d", closestDistance, self.modFM.FollowCurrentIndex));
--    --
--    if self.modFM.FollowCurrentIndex == 0 then
--        self.modFM.FollowVehicleObj = nil;
--        FollowMe.setWarning(self, "FollowMeDropperNotFound");
--        return;
--    end;
--
--    -- Chain with leading vehicle.
--    FollowMe.setStateLeaderStalker(self, closestVehicle, self.modFM.StalkerVehicleObj, helperIndex)
--    FollowMe.setStalker(self.modFM.FollowVehicleObj, self);
--    
--    -- Set engaged state
--    self.modFM.FollowState = FollowMe.STATE_FOLLOWING;
--
----[[    
--    --
--    if SpecializationUtil.hasSpecialization(AITractor, self.specializations) then
--        AITractor.addCollisionTrigger(self, self);
--    elseif SpecializationUtil.hasSpecialization(AICombine, self.specializations) then
--        AICombine.addCollisionTrigger(self, self);
--    else
--        -- TODO - Display warning!
--    end;
----]]
--
----[[FS2015
--    if g_currentMission.ingameMap ~= nil and g_currentMission.ingameMap.createMapHotspot ~= nil then
--        -- TODO, make visible on clients too!
--        local iconWidth = math.floor(0.015 * g_screenWidth) / g_screenWidth;
--        local iconHeight = iconWidth * g_screenAspectRatio;
--    
--        self.modFM.mapIcon = g_currentMission.ingameMap:createMapHotspot(
--            "fm",
--            FollowMe.mapIconFile,
--            0,0,
--            iconWidth,iconHeight,
--            false,
--            false,
--            false,
--            self.rootNode,
--            false,
--            false
--        );
--    end
----FS2015]]    
--
--    --
--    self.modFM.isDirty = true;
--end;
--
--function FollowMe.stopFollowMe(self, noSendEvent)
--    assert(g_server ~= nil);
--
--    if self.modFM.FollowVehicleObj == nil then
--        return;
--    end;
--
--    self.modFM.FollowState = FollowMe.STATE_STOPPING;
--    self.modFM.isDirty = true;
--end;
--
--function FollowMe.stoppedFollowMe(self, noSendEvent)
--    assert(g_server ~= nil);
--
--    if self.modFM.FollowVehicleObj == nil then
--        return;
--    end;
--
--    -- Set Disengaged state
--    self.modFM.FollowState = FollowMe.STATE_NONE;
--
--    -- Unchain with leading vehicle.
--    assert(self.modFM.FollowVehicleObj.modFM.StalkerVehicleObj == self);
--    FollowMe.setStalker(self.modFM.FollowVehicleObj, nil);
--    FollowMe.setStateLeaderStalker(self, nil, self.modFM.StalkerVehicleObj, 0)
--    --
--    self.modFM.FollowCurrentIndex = 0;
--    self.modFM.isDirty = true;
--
--    --
--    self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF, true);
--    if self.isServer then
--        WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeedReal, 0, true, self.requiredDriveMode);
--    end
--
--    if g_currentMission.missionInfo.automaticMotorStartEnabled and not self.isEntered then
--        self:stopMotor(true);
--    end
--
--    --
--    g_currentMission:addIngameNotification(
--        {0.5, 0.5, 1.0, 1.0}, --FSBaseMission.INGAME_NOTIFICATION_INFO, 
--        "'Follower' vehicle stopped"    --string.format(g_i18n:getText(AIVehicle.REASON_TEXT_MAPPING[reason]), self.currentHelper.name)
--    )
--end;



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

--function FollowMe.getDeactivateOnLeave(self, superFunc)
--    local deactivate = true
--    if superFunc ~= nil then
--        deactivate = deactivate and superFunc(self)
--    end
--
--    return deactivate and not self.isHired
--end;


-- Get distance to keep-in-front, or zero if not.
function FollowMe.getKeepFront(self)
    if (self.modFM.FollowKeepBack >= 0) then return 0; end
    return math.abs(self.modFM.FollowKeepBack);
end

-- Get distance to keep-back, or zero if not.
function FollowMe.getKeepBack(self, speedKMH)
    if speedKMH == nil then speedKMH=0; end;
    local keepBack = Utils.clamp(self.modFM.FollowKeepBack, 0, 999);
    return keepBack * (1 + speedKMH/100);
end;


function FollowMe.checkBaler(attachedTool)
    local allowedToDrive
    local hasCollision
    local pctSpeedReduction
    if attachedTool:getIsTurnedOn() then
        if attachedTool.baler.unloadingState == Baler.UNLOADING_CLOSED then
            local unitFillLevel = attachedTool:getUnitFillLevel(self.baler.fillUnitIndex) 
            local unitCapacity  = attachedTool:getUnitCapacity(self.baler.fillUnitIndex)
            if unitFillLevel >= unitCapacity then
                allowedToDrive = false
                hasCollision = true -- Stop faster
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
            hasCollision = true
            if attachedTool.baler.unloadingState == Baler.UNLOADING_OPEN then
                -- Activate closing (server-side only!)
                attachedTool:setIsUnloadingBale(false);
            end
        end
    end
    return allowedToDrive, hasCollision, pctSpeedReduction;
end

function FollowMe.checkBaleWrapper(attachedTool)
    local allowedToDrive
    local hasCollision
    if attachedTool.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINISHED then -- '4'
        allowedToDrive = false
        -- Activate the bale unloading (server-side only!)
        attachedTool:doStateChange(BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE);  -- '5'
    elseif attachedTool.baleWrapperState > BaleWrapper.STATE_WRAPPER_FINISHED then -- '4'
        allowedToDrive = false
    end
    return allowedToDrive, hasCollision;
end

function FollowMe.updateFollowMovement(self, dt)
    assert(self.modFM.FollowVehicleObj ~= nil);

    local allowedToDrive = (self.modFM.FollowState == FollowMe.STATE_FOLLOWING) and self.isMotorStarted;
    local hasCollision = false;
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
    -- TODO - Try to figure out if this can be moved elsewhere, so its NOT executed so often.
    for _,tool in pairs(self.attachedImplements) do
        if tool.object ~= nil then
            if  tool.object.baler ~= nil
            and tool.object.baler.baleUnloadAnimationName ~= nil  -- Seems RoundBalers are the only ones which have set the 'baleUnloadAnimationName'
            and SpecializationUtil.hasSpecialization(Baler, tool.object.specializations)
            then
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
        allowedToDrive = setAllowedToDrive~=nil and setAllowedToDrive or allowedToDrive;
        hasCollision   = setHasCollision~=nil   and setHasCollision   or hasCollision;
        if pctSpeedReduction ~= nil and pctSpeedReduction > 0 then
            self.modFM.reduceSpeedTime = g_currentMission.time + 250
            -- TODO - change above, so it actually affects acceleration value
        end
    end

--[[DEBUG
    local dbgId = tostring(networkGetObjectId(self));
--DEBUG]]

    --
    local leader = self.modFM.FollowVehicleObj;

    -- current location / rotation
    local cx,cy,cz      = getWorldTranslation(self.components[1].node);
    local crx,cry,crz   = localDirectionToWorld(self.components[1].node, 0,0,1);
    -- leader location / rotation
    local lx,ly,lz      = getWorldTranslation(leader.components[1].node);
    local lrx,lry,lrz   = localDirectionToWorld(leader.components[1].node, 0,0,1);

    -- original target
    local ox,oy,oz;
    local orx,ory,orz;
    -- actual target
    local tx,ty,tz;
    local trx,try,trz;
    --
    local acceleration = 1.0;

    -- leader-target
    local keepInFrontMeters = FollowMe.getKeepFront(self);
    lx = lx - lrz * self.modFM.FollowXOffset + lrx * keepInFrontMeters;
    lz = lz + lrx * self.modFM.FollowXOffset + lrz * keepInFrontMeters;
    -- distance to leader-target
    local distMeters = Utils.vector2Length(cx-lx,cz-lz);

    local crumbIndexDiff = leader.modFM.DropperCurrentIndex - self.modFM.FollowCurrentIndex;

    --
    if crumbIndexDiff >= FollowMe.cBreadcrumbsMaxEntries then
        -- circular-array have "circled" once, and this follower did not move fast enough.
        --DEBUG log("Much too far behind. Stopping auto-follow.");
        if self.modFM.FollowState ~= FollowMe.STATE_STOPPING then
            --FollowMe.setWarning(self, "FollowMeTooFarBehind");
            FollowMe.stopFollowMe(self, FollowMe.REASON_TOO_FAR_BEHIND);
        end
        hasCollision = true
        allowedToDrive = false
        acceleration = 0.0
        -- Set target 2 meters straight ahead of vehicle.
        tx = cx + crx * 2;
        ty = cy;
        tz = cz + crz * 2;
    elseif crumbIndexDiff > 0 then
        -- Following crumbs...
        --
        local crumbT = leader.modFM.DropperCircularArray[1+((self.modFM.FollowCurrentIndex-1) % FollowMe.cBreadcrumbsMaxEntries)];
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
            turnLightState = crumbT.turnLightState
            local crumbAvgSpeed = crumbT.avgSpeed;
            local crumbN = leader.modFM.DropperCircularArray[1+((self.modFM.FollowCurrentIndex  ) % FollowMe.cBreadcrumbsMaxEntries)];
            if crumbN ~= nil then
                -- Apply offset, to next original target
                local ntx = crumbN.trans[1] - crumbN.rot[3] * self.modFM.FollowXOffset;
                local ntz = crumbN.trans[3] + crumbN.rot[1] * self.modFM.FollowXOffset;
                --local ntDist = Utils.vector2Length(ntx - cx, ntz - cz);
                local pct = math.max(1 - (tDist / FollowMe.cMinDistanceBetweenDrops), 0);
                tx,_,tz = Utils.vector3ArrayLerp( {tx,0,tz}, {ntx,0,ntz}, pct);
                crumbAvgSpeed = (crumbAvgSpeed + crumbN.avgSpeed) / 2;
            end;
            --
            local keepBackMeters = FollowMe.getKeepBack(self, ((self.realGroundSpeed~=nil) and (self.realGroundSpeed*3.6) or (math.max(0,self.lastSpeedReal)*3600)));
            local distCrumbs   = math.floor(keepBackMeters / FollowMe.cMinDistanceBetweenDrops);
            local distFraction = keepBackMeters - (distCrumbs * FollowMe.cMinDistanceBetweenDrops);

            allowedToDrive = allowedToDrive and ((crumbIndexDiff > distCrumbs) or ((crumbIndexDiff == distCrumbs) and (tDist >= distFraction)));
            hasCollision = hasCollision or (crumbIndexDiff < distCrumbs); -- Too far ahead?
--[[DEBUG
if Vehicle.debugRendering then
    FollowMe.debugDraw[dbgId.."a3"] = {"FM",string.format("KeepBack:%.2f, DistCrumbs:%.0f/%.2f, DistTarget:%.2f", keepBackMeters, distCrumbs, distFraction, tDist) };
end;
--DEBUG]]
            --
            local mySpeedDiffPct = (math.max(0, self.lastSpeedReal) / math.max(0.00001,self.modFM.lastLastSpeedReal)) - 1;

            local targetSpeedDiffPct = Utils.clamp(((math.max(5/3600, crumbAvgSpeed) - math.max(0,self.lastSpeedReal))*3600) / math.max(1,crumbAvgSpeed*3600), -1, 1);
            acceleration = Utils.clamp(self.modFM.lastAcceleration * 0.9  + (targetSpeedDiffPct * (1 - math.abs(mySpeedDiffPct))), 0.01, 1);

            if keepInFrontMeters > 0 then
                if distMeters > 10 then
                    acceleration = math.max(1.0, acceleration)
                else
                    acceleration = math.max(0.75, acceleration)
                end
            end
--[[DEBUG
if Vehicle.debugRendering then
    FollowMe.debugDraw[dbgId.."a5"] = {"FM",string.format("MySpdDiff:%+3.1f, TrgSpdDiff:%+.2f, Apply:%+.4f", mySpeedDiffPct*100, targetSpeedDiffPct, (targetSpeedDiffPct * (1 - math.abs(mySpeedDiffPct))) ) };
end;
--DEBUG]]
        end;
    end;
    --
    if crumbIndexDiff <= 0 then
        ---- Following leader directly...
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
--[[DEBUG
if Vehicle.debugRendering then
    FollowMe.debugDraw[dbgId.."a3"] = {"FM",string.format("DistDiff: %.2f", distMetersDiff)};
end;
--DEBUG]]
        allowedToDrive = allowedToDrive and (keepInFrontMeters >= 0) and (nz > 0) and (distMetersDiff > 0.5);

        -- Leader-vehicle can be vanilla or MoreRealistic. Get speed from the proper one.
        local leaderLastSpeedKMH = math.max(0, leader.lastSpeedReal) * 3600; -- only consider forward movement.
        local mySpeedDiffPct = (math.max(0, self.lastSpeedReal) / math.max(0.00001,self.modFM.lastLastSpeedReal)) - 1;

        local leaderLastSpeedReal = leaderLastSpeedKMH / 3600;

        local targetSpeedDiffPct = Utils.clamp(((math.max(5/3600, leaderLastSpeedReal) - math.max(0,self.lastSpeedReal))*3600) / math.max(1,leaderLastSpeedReal*3600), -1, 1);
        acceleration = Utils.clamp(self.modFM.lastAcceleration * 0.9 + (targetSpeedDiffPct * (1 - math.abs(mySpeedDiffPct))), 0.01, 1);

        if distMetersDiff > 1 then
            if distMetersDiff > 15 then
                acceleration = math.max(1.0, acceleration)
            elseif distMetersDiff > 10 then
                acceleration = math.max(0.75, acceleration)
            elseif distMetersDiff > 5 then
                acceleration = math.max(0.5, acceleration);
            else
                acceleration = math.max(0.25, acceleration);
            end
        end
--[[DEBUG
if Vehicle.debugRendering then
    FollowMe.debugDraw[dbgId.."a5"] = {"FM",string.format("MySpdDiff:%+3.1f, TrgSpdDiff:%+3.1f, Apply:%+.4f", mySpeedDiffPct*100, targetSpeedDiffPct*100, (targetSpeedDiffPct * (1 - math.abs(mySpeedDiffPct))) ) };
end;
--DEBUG]]
    end;
    --
--[[DEBUG
    FollowMe.dbgTarget = {tx,ty,tz};
--DEBUG]]
    --
    local lx,lz = AIVehicleUtil.getDriveDirection(self.components[1].node, tx,ty,tz);

    -- Reduce speed if "attack angle" against target is more than 45degrees.
    if self.modFM.reduceSpeedTime > g_currentMission.time then
        acceleration = acceleration * 0.5;
    elseif (self.lastSpeed*3600 > 10) and (math.abs(math.atan2(lx,lz)) > (math.pi/4)) then
        acceleration = acceleration * 0.5;
        self.modFM.reduceSpeedTime = g_currentMission.time + 250; -- For the next 250ms, keep speed reduced.
    end;

--[[DEBUG
if Vehicle.debugRendering then
    FollowMe.debugDraw[dbgId.."a4"] = {"FM",string.format("Steer:%.2f/%.2f, Degree:%3.2f", lx,lz, math.deg(math.atan2(lx,lz)) ) };
end;
--DEBUG]]
    --
    self.modFM.lastAcceleration  = acceleration;
    self.modFM.lastLastSpeedReal = math.max(0, self.lastSpeedReal); -- Only forward movement considered.
    --
    if hasCollision or not allowedToDrive then
        acceleration = (hasCollision and (self.lastSpeedReal * 3600 > 5)) and -1 or 0; -- colliding and speed more than 5km/h, then negative acceleration (brake?)
        lx,lz = 0,1
        AIVehicleUtil.driveInDirection(self, dt, 30, acceleration, (acceleration * 0.7), 30, allowedToDrive, moveForwards, lx,lz, nil, 1);

        if self.modFM.FollowState == FollowMe.STATE_STOPPING then
            if (self.lastSpeedReal*3600 < 2) then
                --FollowMe.stopFollowMe(self)
                self.modFM.FollowState = FollowMe.STATE_NONE
                self.modFM.isDirty = true
            end
        end
    else
        AIVehicleUtil.driveInDirection(self, dt, 30, acceleration, (acceleration * 0.7), 30, allowedToDrive, moveForwards, lx,lz, nil, 1);
--[[
        if self.aiTrafficCollisionTrigger ~= nil then
            -- Attempt to rotate the traffic-collision-trigger in direction of steering
            AIVehicleUtil.setCollisionDirection(getParent(self.aiTrafficCollisionTrigger), self.aiTrafficCollisionTrigger, lx,lz);
        end
--]]        
    end;

--[[  DEBUG
if Vehicle.debugRendering then
    FollowMe.debugDraw[dbgId.."a0"] = {"FM",string.format("Vehicle:%s",    tostring(self.realVehicleName))};
    FollowMe.debugDraw[dbgId.."a1"] = {"FM",string.format("AllowDrive:%s, Collision:%s, CrumbIdx:%s, CrumbDiff:%s", allowedToDrive and "Y" or "N", hasCollision and "Y" or "N", tostring(self.modFM.FollowCurrentIndex), tostring(crumbIndexDiff))};
    FollowMe.debugDraw[dbgId.."a2"] = {"FM",string.format("Acc:%1.2f, LstSpd:%2.3f, mrRealSpd:%2.3f, %s", acceleration, self.lastSpeed*3600, tMRRealSpd, (self.modFM.reduceSpeedTime > g_currentMission.time) and "Half!" or "")};
end;
--DEBUG]]

    return turnLightState
end;





function FollowMe.getWorldToScreen(nodeId)
    local tx,ty,tz = getWorldTranslation(nodeId);
    --ty = ty + self.displayYoffset;
    local sx,sy,sz = project(tx,ty,tz);
    if  sx<1 and sx>0  -- When "inside" screen
    and sy<1 and sy>0  -- When "inside" screen
    and          sz<1  -- Only draw when "in front of" camera
    then
        return sx,sy
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
        g_currentMission:showBlinkingWarning(g_i18n:getText(self.modFM.ShowWarningText))
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
    if g_currentMission.missionInfo.showHelpMenu then
        if self.modFM.FollowVehicleObj ~= nil
        or showFollowMeMy then
            g_currentMission:addHelpButtonText(g_i18n:getText("FollowMeMyToggle"), InputBinding.FollowMeMyToggle, nil, GS_PRIO_NORMAL);
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

----[[DEBUG
--function getString(value, defaultValue)
--  if value == nil then return defaultValue; end;
--  return tostring(value);
--end
--function getFloat(value, defaultValue)
--  if value == nil then return defaultValue; end;
--  return value; -- TODO : Check it is a float type!
--end;
--
--function FollowMe.drawDebug(self)
--  if Vehicle.debugRendering and self.modFM.StalkerVehicleObj ~= nil then
--    local stalker = self.modFM.StalkerVehicleObj;
--    local txt = "";
--    txt = txt .. string.format("\nFM-Drv: %s,%s", getString(stalker.modFM.dbgAllowedToDrive, "nil"), getString(stalker.modFM.dbgHasCollision, "nil"));
--    txt = txt .. string.format("\nFM-Acc: %1.2f", getFloat(stalker.modFM.dbgAcceleration, 0.0));
--    txt = txt .. string.format("\nFM-Ang: %1.2f", getFloat(stalker.modFM.dbgAngleDiff, 0.0));
--
--    txt = txt .. string.format("\nFM-Spd: %2.3f", getFloat(stalker.modFM.dbgRealSpeedLevelsAI4,0.0));
--
--    --txt = txt .. string.format("\ndbgActive:%s", tostring(stalker.modFM.dbgActive));
--    --txt = txt .. string.format("\nActive:%s", tostring(stalker.isActive));
--    --
--    --txt = txt .. string.format(",isEntered:%s", tostring(stalker.isEntered));
--    --txt = txt .. string.format(",isControlled:%s", tostring(stalker.isControlled));
--    --txt = txt .. string.format(",forceIsActive:%s", tostring(stalker.forceIsActive));
--    --
--    --txt = txt .. string.format(",realActive:%s", tostring(stalker.realIsActive));
--    --txt = txt .. string.format(",realForceIsActive:%s", tostring(stalker.realForceIsActive));
--    --
--    --txt = txt .. string.format("\nmrMotorStarted: %s", tostring(stalker.realIsMotorStarted));
--    --
--    setTextBold(false);
--    setTextColor(1, 1, 1, 1);
--    setTextAlignment(RenderText.ALIGN_LEFT);
--    renderText(0.005, 0.5, 0.02, txt);
--  end
--end
----DEBUG]]

---
---
---

FollowMeEvent = {};
FollowMeEvent_mt = Class(FollowMeEvent, Event);

InitEventClass(FollowMeEvent, "FollowMeEvent");

function FollowMeEvent:emptyNew()
    local self = Event:new(FollowMeEvent_mt);
    self.className = "FollowMeEvent";
    return self;
end;

function FollowMeEvent:new(vehicle, cmdId, reason, helperIndex)
    local self = FollowMeEvent:emptyNew()
    self.vehicle            = vehicle
    self.followVehicleObj   = vehicle.modFM.FollowVehicleObj
    self.stalkerVehicleObj  = vehicle.modFM.StalkerVehicleObj
    self.cmdId              = cmdId
    self.stateId            = vehicle.modFM.FollowState
    self.distance           = vehicle.modFM.FollowKeepBack
    self.offset             = vehicle.modFM.FollowXOffset
    self.reason             = reason
    self.helperIndex        = helperIndex
    return self;
end;

function FollowMeEvent:writeStream(streamId, connection)
    FollowMe.NEWsharedWriteStream(
        g_server ~= nil,
        streamId,
        self.vehicle,
        self.followVehicleObj,
        self.stalkerVehicleObj,
        self.cmdId,
        self.stateId,
        self.distance,
        self.offset,
        self.reason,
        self.helperIndex
    );
end;

function FollowMeEvent:readStream(streamId, connection)
    local vehObj, followsObj, stalkedByObj, cmdId, stateId, keepBackDist, xOffset, reason, helperIndex = FollowMe.NEWsharedReadStream(g_server == nil, streamId);

    if vehObj ~= nil then
        --FollowMe.recvUpdate(vehObj, stateId, keepBackDist, xOffset, followsObj, stalkedByObj, warnTxt, helperIndex);
        if connection:getIsServer() then
            -- Received from server
            vehObj.modFM.FollowState        = stateId
            vehObj.modFM.FollowVehicleObj   = followsObj
            vehObj.modFM.StalkerVehicleObj  = stalkedByObj
        end
        
        local noEventSend = connection:getIsServer()
        
        if     cmdId == FollowMe.COMMAND_START then
            FollowMe.startFollowMe(vehObj, helperIndex, noEventSend)
        elseif cmdId == FollowMe.COMMAND_STOP then
            FollowMe.stopFollowMe(vehObj, reason, noEventSend)
        elseif cmdId == FollowMe.COMMAND_WAITRESUME then
            FollowMe.waitResumeFollowMe(vehObj, reason, noEventSend)
        else
            FollowMe.changeDistance(vehObj, { keepBackDist }, noEventSend)
            FollowMe.changeOffset(  vehObj, { xOffset },      noEventSend)
        end
    end;
end;

--function FollowMeEvent.sendEvent(vehicle, cmdId, stateId, distance, offset, noEventSend)
--    if noEventSend == nil or noEventSend == false then
--        if g_server ~= nil then
--            g_server:broadcastEvent(FollowMeEvent:new(vehicle, stateId), nil, nil, vehicle);
--        else
--            g_client:getServerConnection():sendEvent(FollowMeEvent:new(vehicle, stateId));
--        end;
--    end;
--end;

--
print(string.format("Script loaded: FollowMe.lua (v%s)", FollowMe.version));
