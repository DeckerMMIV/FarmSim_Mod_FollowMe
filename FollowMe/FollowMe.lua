--
-- "Follow Me" - AutoFollow a Breadcrumb-trail
--
-- @team    Freelance Modding Crew (FMC)
-- @author  Decker_MMIV - fs-uk.com, forum.farming-simulator.com, modhoster.com
-- @date    2011-02-01
--          2012-08-29 (resumed)
--          2013-09-xx (resumed)
--
-- Modifikationen erst nach Rücksprache
-- Do not edit without my permission
--
-- @history
--      v0.5(beta)  - Beta-release for internal FMC testing/criticism/suggestions
--      v0.51(beta) - Managed to get followers to use speed-throttle (well, not good enough), so they do
--                     not always drive as fast as possible.
--                  - Fixed problem of "circling a breadcrumb that vehicle can never reach", by calculating if
--                     vehicle is "in front of" the breadcrumb, which in that case it will go to the next one instead.
--      v0.52(beta) - Changed so the functions are appended to Steerable specialization, instead of Hirable, as there
--                     may be many "Truck"-mods that do not have Hirable.
--                  - Resets breadcrumb trail at every start. Previous version kept the trail "alive".
--      v0.53(beta) - TextBold=false, TextColor=white.
--  2012-November
--      v0.54       - Lots of changes. Attempt at FS2011 & FS2013 code.
--      v0.55       - Preliminary multiplayer support added.
--  2012-December
--      v0.56       - Misc. cleanup.
--                  - Added offset-left/right ability for follower (default keys: RIGHT CTRL + A / D)
--                  - Added keep back distance ability for follower (default keys: RIGHT CTRL + W / S)
--      v0.57       - Ability for the leading vehicle to "control" offset and keep-back on the follower,
--                    and only the _one_ following, _not_ the entire "chain".
--                      (default keys: RIGHT SHIFT + W / S and RIGHT SHIFT + A / D)
--      v0.58       - Read/write network stream functions changed.
--                  - Checks for existance of beaconlight, before attempting to turn on/off.
--      v0.59       - The 'steeringAngleLimit' for AIVehicleUtil.driveInDirection() should NOT be larger.
--      v0.60       - Misc. tweaks.
--                  - Attempt at translations to German, Polish & French.
--      v0.61       - If motor is not started, do not allow auto-follow. (Bug discovered by DrUptown)
--                  - Added ability to stop follower (default keys: RIGHT SHIFT + F)
--      v0.62       - Renamed input-binding to 'AutoFollowMeToggle', from 'AutoFollowDrive'.
--                  - Found that ESLimiter causes problems, due to its usage of self.isHired and setting speed-level.
--      v0.63       - Put all 'Follow Me' variables into a self.modFM, to reduce potential clashes with other mods/specializations.
--                  - Renamed/prefixed everything to 'FollowMe', instead of 'AutoFollow'.
--      v0.64       - More tweaking of the follower's speed.
--  2012-Xmas
--      v0.65       - Followers now duplicate the leader's dropped "crumbs", and will not make their own.
--                    This is to fix an "increasing amplitude" problem, when having a "convoy of vehicles".
--                    However, this also causes the "annoyance", that from a fresh loaded savegame each vehicle in
--                    a convoy must be driven a little distance first _before_ activating the FollowMe, so the
--                    vehicle behind it can "discover/locate" the trail.
--                  - For clients, added setStateFollowStalker() which hopefully will make the wheels turn etc.
--                    when vehicle is in follow-mode (i.e. hired).
--                  - More tweaking of the follower's speed (this never ends).
--  2013-January
--      v0.66       - Changed some functionality with regards to network-messages between server and clients.
--      v0.67       - Changed minimum-distance-between-drops to 5 (from 10), and max-entries to 100 (from 50).
--  2013-February
--      v0.68       - Misc. cleanup.
--                  - Made some preliminary documentation for the mod.
--  2013-September
--      v0.69       - Patch 1.4.0.x required.
--                  - Attempt at supporting "MR" MoreRealistic v1.0.3
--                      - Changed ZIP name to "zzz_FollowMe2013.zip", so this mod loads _after_ MoreRealistic.ZIP.
--                      - Added "self.turnStage=-1" to force faster steeringSpeed in [Override]AIVehicleUtil.driveInDirection().
--                          - When starting/stopping FollowMe, switching MR's realSpeedLevels[2] <-> [4],
--                            due to driveInDirection() sets/hardcoded speedLevel=2 when turnStage!=0.
--                      //- Confused about the "MR"-vehicles not starts driving automatically, when FollowMe is activated,
--                      //  but first does it when a player has entered, and must do so every time the "MR"-vehicle is
--                      //  blocked and pauses. Thinking it might be something about the "MR" clutch or brake variables
--                      //  in [Override]WheelsUtil.updateWheelsPhysics().
--                      - Ah! RealisticVehicle:update() overrules self.forceIsActive, and that then causes self.isActive to be
--                        false, which then causes RealisticSteerable:update() to not run any of the MR functions.
--                      - "Fixing" this problem, by overwriting Vehicle:getIsActive() to return true, if vehicle is a
--                        MR-vehicle and has FollowMe active.
--      v0.70       - MoreRealistic v1.0.5 changes. Thank you DURAL for your code additions.
--                  - Added negative "keep back distance", i.e. the follower can now drive beside or in front of leading vehicle.
--                  - Changed keep-back/front distance to meters, instead of unit-of-crumbs.
--                  - More naive tweaks regarding vanilla acceleration.
--      v0.71       - Now requires patch 2.0.0.7 or higher
--                  - Changed distance increments to +/-5 when press-and-release, and +/-1 when using press-and-hold,
--                    due to more often than not I needed bigger distance changes than small ones.
--                  - Little tweaks regarding "catch up" to in-front-of.
--  2013-October
--      v0.72       - More tweaks for vanilla "catch up" to in-front-of.
--                  - Fix for 'in-front-of' getting leader's speed, for a MR following a Vanilla.
--                  - Tested/works with MoreRealistic v1.1.
--  2013-November
--      v0.73       - Side-offset now in steps of 0.5 (Requested by Napalm)
--                  - Changed <title> name, to ensure this mod gets loaded _after_ MoreRealistic on dedicated-server.
--  2013-December
--      v0.74       - Faster stopping, when Follow Me is disengaged. Particular noticeable on MoreRealistic vehicles (Discovered by DrUptown)
--      v0.75       - Preliminar support for the vanilla (Round)Baler script, making it unload bale when full.
--      v0.76       - Polish translations by spinah.
--                  - Added BJR-Modding's John Deere 864 Premium v1.0 to auto-unload too. Pickup-choke is not handled though!
--                  - Using AIVehicleUtil.setCollisionDirection() to set aiTrafficCollisionTrigger towards steering direction.
--      v0.77       - Hmm, apparently relying on the file- or <title> name alphabetically being after moreRealistic still does NOT work.
--                    The load-order of mods in multiplayer is very non-deterministic in FS2013, which is very annoying!
--                    So a solution was to use Xentro's addSpecialization.LUA script, instead of overwriting the Steerable-functions.
--  2014-January
--      v0.78       - If getting further ahead more than one 'crumb', then apply brakes. 
--                    If MoreRealistic vehicle, and driving 10% faster than what 'crumb' specifies, then apply brakes.
--                    This to stop gaining speed, when driving down hill without actually accelerating. Problem discovered by DrUptown.
--      v0.79       - Tweaked MoreRealistic, if driving 5% faster then apply brakes.
--                  - Remember 'keep back distance' and 'side offset' when saving game-session.
--  2014-March
--      v0.80       - Followers sets lights and beacon-lights as what the leader has them set to.
--  2014-June
--      v1.0.81     - Due to other versioning scheme, removed hack for ShowWorkersOnPDA v0.96.
--  2014-November
--      v2.0.0      - Begun upgrading to FS15
--  2014-December
--      v2.0.1      - Added map-icon for vehicle when in Follow mode. Inspired by CoursePlay.
--      v2.0.2      - Minor code-cleanup.
--      v2.0.4      - Now using individual localization (l10n) XML-files.
--      v2.0.5      - Default keep-back distance now 10 (was 0).
--      v2.0.6      - Fix for searching, where it should ignore 'steerables' that are not 'drivables'.
--                  - Updated Russian translations, by Gonimy_Vetrom.
--

--[[
Suggestions:
    MR vehicle - the more weight/load, increase keepback distance.

    
Tonoppa - http://fs-uk.com/forum/index.php?topic=151431.msg1080633#msg1080633    
    Just wondering would it be how difficult thing to add somehow a speedlimit for following vehicles? I'm playing with moreRealistic, let's clear that. My issue; I often drive myself tractor with mowers and set something to follow me with swather/rake/thingy and even though I try to keep my mower speed way under 14 kph what Dural have set for rakes, following tractor often exceeds that speed when coming downhill and leaving non-swathed bits behind. 

]]

--

FollowMe = {};
--
local modItem = ModsUtil.findModItemByModName(g_currentModName);
FollowMe.version = (modItem and modItem.version) and modItem.version or "?.?.?";
--

FollowMe.debugDraw = {}
FollowMe.mapIconFile = Utils.getFilename('mapMarker.DDS', g_currentModDirectory);


FollowMe.cMinDistanceBetweenDrops        =   5;   -- TODO, make configurable
FollowMe.cBreadcrumbsMaxEntries          = 100;   -- TODO, make configurable
FollowMe.cMstimeBetweenDrops             =  40;   -- TODO, make configurable
--FollowMe.cStartExp = 2;
--FollowMe.cBaseExp = math.exp(FollowMe.cStartExp);

FollowMe.STATE_NONE      = 0;
FollowMe.STATE_TOGGLE    = 1;
FollowMe.STATE_START     = 2;
FollowMe.STATE_STOP      = 3;


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

local function removeFromString(src, toRemove)
    local srcArr = Utils.splitString(" ", src);
    local remArr = Utils.splitString(" ", toRemove);
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

function FollowMe.initialize()
    if FollowMe.isInitialized then
        return;
    end;
    FollowMe.isInitialized = true;

    -- Get the modifier-key (if any) from input-binding
    FollowMe.keyModifier_FollowMeMyToggle = getKeyIdOfModifier(InputBinding.FollowMeMyToggle);

    -- Test that these four use the same modifier-key
        FollowMe.keyModifier_FollowMeMy  = getKeyIdOfModifier(InputBinding.FollowMeMyDistDec);
    if (FollowMe.keyModifier_FollowMeMy ~= getKeyIdOfModifier(InputBinding.FollowMeMyDistInc)
    or  FollowMe.keyModifier_FollowMeMy ~= getKeyIdOfModifier(InputBinding.FollowMeMyOffsDec)
    or  FollowMe.keyModifier_FollowMeMy ~= getKeyIdOfModifier(InputBinding.FollowMeMyOffsInc)
    ) then
        -- warning!
        log("WARNING: Not all action-keys(1) use the same modifier-key!");
    end;

    -- Build a string, that is much shorter than what InputBinding.getKeyNamesOfDigitalAction() returns
    FollowMe.keys_FollowMeMy = FollowMe.keyModifier_FollowMeMy ~= nil and getKeyName(FollowMe.keyModifier_FollowMeMy) or "";
    FollowMe.keys_FollowMeMy = FollowMe.keys_FollowMeMy:upper();

    local shortKeys = removeFromString(InputBinding.getKeyNamesOfDigitalAction(InputBinding.FollowMeMyDistDec), FollowMe.keys_FollowMeMy)
            .. "," .. removeFromString(InputBinding.getKeyNamesOfDigitalAction(InputBinding.FollowMeMyDistInc), FollowMe.keys_FollowMeMy)
            .. "," .. removeFromString(InputBinding.getKeyNamesOfDigitalAction(InputBinding.FollowMeMyOffsDec), FollowMe.keys_FollowMeMy)
            .. "," .. removeFromString(InputBinding.getKeyNamesOfDigitalAction(InputBinding.FollowMeMyOffsInc), FollowMe.keys_FollowMeMy);

    FollowMe.keys_FollowMeMy = FollowMe.keys_FollowMeMy .. " " .. shortKeys;

    -- Test that these four use the same modifier-key
        FollowMe.keyModifier_FollowMeFl  = getKeyIdOfModifier(InputBinding.FollowMeFlDistDec);
    if (FollowMe.keyModifier_FollowMeFl ~= getKeyIdOfModifier(InputBinding.FollowMeFlDistInc)
    or  FollowMe.keyModifier_FollowMeFl ~= getKeyIdOfModifier(InputBinding.FollowMeFlOffsDec)
    or  FollowMe.keyModifier_FollowMeFl ~= getKeyIdOfModifier(InputBinding.FollowMeFlOffsInc)
    ) then
        -- warning!
        log("WARNING: Not all action-keys(2) use the same modifier-key!");
    end;

    -- Build a string, that is much shorter than what InputBinding.getKeyNamesOfDigitalAction() returns
    FollowMe.keys_FollowMeFl = FollowMe.keyModifier_FollowMeFl ~= nil and getKeyName(FollowMe.keyModifier_FollowMeFl) or "";
    FollowMe.keys_FollowMeFl = FollowMe.keys_FollowMeFl:upper();

    local shortKeys = removeFromString(InputBinding.getKeyNamesOfDigitalAction(InputBinding.FollowMeFlDistDec), FollowMe.keys_FollowMeFl)
            .. "," .. removeFromString(InputBinding.getKeyNamesOfDigitalAction(InputBinding.FollowMeFlDistInc), FollowMe.keys_FollowMeFl)
            .. "," .. removeFromString(InputBinding.getKeyNamesOfDigitalAction(InputBinding.FollowMeFlOffsDec), FollowMe.keys_FollowMeFl)
            .. "," .. removeFromString(InputBinding.getKeyNamesOfDigitalAction(InputBinding.FollowMeFlOffsInc), FollowMe.keys_FollowMeFl);

    FollowMe.keys_FollowMeFl = FollowMe.keys_FollowMeFl .. " " .. shortKeys;
end;

--
--
--

function FollowMe.load(self, xmlFile)
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
    self.modFM.FollowState = nil; -- nil/0=Disengaged, 1=Engaged, 2=BrakeForDisengage
    self.modFM.FollowVehicleObj = nil;  -- What vehicle is this one following (if any)
    self.modFM.FollowCurrentIndex = 0;
    --self.modFM.lastZeroSpeedIndex = self.modFM.FollowCurrentIndex;
    self.modFM.FollowKeepBack = 10;
    self.modFM.FollowXOffset = 0;
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
        -- Copied from FS2011-Hirable, for the mods that do not include that specialization in their vehicle-type.
        self.modFM.PricePerMS = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.pricePerHour"), 2000)/60/60/1000;

        -- Drop one "crumb", to get it started...
        local wx,wy,wz = getWorldTranslation(self.components[1].node);
        FollowMe.addDrop(self, wx,wy,wz, 30/3600);
    end;
end;

function FollowMe.delete(self)
    if self.isServer then
        if self.modFM.StalkerVehicleObj ~= nil then
            -- Stop the stalker-vehicle
            FollowMe.stopFollowMe(self.modFM.StalkerVehicleObj, true);
        end;
        -- Stop ourself
        FollowMe.stopFollowMe(self, true);
    end;
end;

function FollowMe.sharedWriteStream(serverToClients, streamId, vehObj, followsObj, stalkedByObj, state, keepBackDistance, xOffset, warnTxt)
    local vehId = (networkGetObjectId(vehObj) or 0);

    streamWriteInt32(streamId, vehId);
    streamWriteInt8( streamId, keepBackDistance);
    streamWriteInt8( streamId, xOffset * 2); -- v0.73

    if (serverToClients) then
        -- server to clients
        local followsId     = (networkGetObjectId(followsObj)    or 0);
        local stalkedById   = (networkGetObjectId(stalkedByObj)  or 0);
        warnTxt = (warnTxt ~= nil and warnTxt or "");

        streamWriteInt32( streamId, followsId);
        streamWriteInt32( streamId, stalkedById);
        streamWriteString(streamId, warnTxt);
    else
        -- client to server
        streamWriteUInt8(streamId, state);
    end;
end;

function FollowMe.sharedReadStream(serverToClients, streamId)
    local state;
    local warnTxt;
    local followsObj;
    local stalkedByObj;

    local vehId            = streamReadInt32(streamId);
    local keepBackDistance = streamReadInt8( streamId);
    local xOffset          = streamReadInt8( streamId) / 2; -- v0.73

    if (serverToClients) then
        -- server to clients
        local followsId;
        local stalkedById;

        followsId    = streamReadInt32( streamId);
        stalkedById  = streamReadInt32( streamId);
        warnTxt      = streamReadString(streamId);

        followsObj   = (followsId   ~= 0 and networkGetObject(followsId)   or nil);
        stalkedByObj = (stalkedById ~= 0 and networkGetObject(stalkedById) or nil);
    else
        -- client to server
        state        = streamReadUInt8(streamId);
    end;

    local vehObj = (vehId ~= 0 and networkGetObject(vehId) or nil);

    return
        vehObj,
        followsObj,
        stalkedByObj,
        state,
        keepBackDistance,
        xOffset,
        warnTxt;
end;

function FollowMe.writeStream(self, streamId, connection)
    FollowMe.sharedWriteStream(
        true,
        streamId,
        self,
        self.modFM.FollowVehicleObj,
        self.modFM.StalkerVehicleObj,
        FollowMe.STATE_NONE,
        self.modFM.FollowKeepBack,
        self.modFM.FollowXOffset,
        self.modFM.ShowWarningText
    );
end;

function FollowMe.readStream(self, streamId, connection)
    local dummySelf, dummyState, dummyWarnTxt;
    --
    dummySelf,
    self.modFM.FollowVehicleObj,
    self.modFM.StalkerVehicleObj,
    dummyState,
    self.modFM.FollowKeepBack,
    self.modFM.FollowXOffset,
    dummyWarnTxt                = FollowMe.sharedReadStream(true, streamId);
end;

function FollowMe.loadFromAttributesAndNodes(self, xmlFile, key, resetVehicles)
    if (not resetVehicles) and (self.modFM ~= nil) then
        local keepBack, offset = Utils.getVectorFromString(getXMLString(xmlFile, key.."#followMe"));
        if keepBack ~= nil then
            FollowMe.changeDistance(self, keepBack);
        end
        if offset ~= nil then
            FollowMe.changeXOffset(self, offset);
        end
    end
    return BaseMission.VEHICLE_LOAD_OK;
end;

function FollowMe.getSaveAttributesAndNodes(self, nodeIdent)
    local attributes = nil
    if self.modFM ~= nil then
        attributes = string.format('followMe="%.0f %.1f"', self.modFM.FollowKeepBack, self.modFM.FollowXOffset);
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
    --
    if self.isServer and not noSendEvent then
        self.modFM.isDirty = true;
    end;
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
            --realGroundSpeed = crumb.realGroundSpeed -- MoreRealistic - DURAL : add the speed information to the "crumb"
        };
    end;
end;

function FollowMe.addDrop(self, wx,wy,wz, avgSpeed)
    assert(g_server ~= nil);

    self.modFM.DropperCurrentIndex = self.modFM.DropperCurrentIndex + 1; -- Keep incrementing index, so followers will be able to detect if they get too far behind of the circular-array.
    local dropIndex = 1+((self.modFM.DropperCurrentIndex-1) % FollowMe.cBreadcrumbsMaxEntries);

    local rx,ry,rz  = localDirectionToWorld(self.components[1].node, 0,0,1);
    self.modFM.DropperCircularArray[dropIndex] = {
        trans = {wx,wy,wz},
        rot = {rx,ry,rz},
        avgSpeed = avgSpeed,
        ---- MoreRealistic - DURAL : add the speed information to the "crumb"
        --realGroundSpeed = self.realGroundSpeed
    };

    --log(string.format("Crumb #%d(%d): trans=%f/%f/%f, rot=%f/%f/%f, avgSpeed=%f, movTime=%f", FollowMe.gBreadcrumbsCurrentDropIndex,dropIndex, wx,wy,wz, rx,ry,rz, avgSpeed, self.modFM.movingTime));
end;

function FollowMe.changeDistance(self, newKeepBack, noSendEvent)
    local prevValue = self.modFM.FollowKeepBack;
    self.modFM.FollowKeepBack = Utils.clamp(newKeepBack, -50, 250);
    if prevValue ~= self.modFM.FollowKeepBack and not noSendEvent then
        self.modFM.delayDirty = g_currentMission.time + 500;
    end;
end;

function FollowMe.changeXOffset(self, newXOffset, noSendEvent)
    local prevValue = self.modFM.FollowXOffset;
    self.modFM.FollowXOffset = Utils.clamp(newXOffset, -50.0, 50.0);
    if prevValue ~= self.modFM.FollowXOffset and not noSendEvent then
        self.modFM.delayDirty = g_currentMission.time + 500;
    end;
end;

-- 
FollowMe.InputEvents = {}
FollowMe.INPUTEVENT_MILLISECONDS = 500
FollowMe.INPUTEVENT_NONE    = 0
FollowMe.INPUTEVENT_SHORT   = 1 -- Key-action was pressed/released quickly
FollowMe.INPUTEVENT_LONG    = 2 -- Key-action was pressed/hold for longer
FollowMe.INPUTEVENT_REPEAT  = 3 -- Key-action is still pressed/hold for much longer
function FollowMe.hasEventShortLong(inBinding, repeatIntervalMS)
    local prevEvent = FollowMe.InputEvents[inBinding];
    local isPressed = InputBinding.isPressed(inBinding);
    if not prevEvent then
        if isPressed then
            FollowMe.InputEvents[inBinding] = g_currentMission.time;
        end
        return FollowMe.INPUTEVENT_NONE; -- Not pressed or Can not determine.
    end;
    local timeDiff = g_currentMission.time - FollowMe.InputEvents[inBinding];
    if not isPressed then
        FollowMe.InputEvents[inBinding] = nil;
        if timeDiff > 0 and timeDiff < FollowMe.INPUTEVENT_MILLISECONDS then
            return FollowMe.INPUTEVENT_SHORT; -- Short press
        end
        return FollowMe.INPUTEVENT_NONE; -- It was probably a long event, which has already been processed.
    elseif timeDiff > FollowMe.INPUTEVENT_MILLISECONDS then
        FollowMe.InputEvents[inBinding] = g_currentMission.time + 10000000;
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
    if self.motor == nil then  -- Due to FS15 Steerable without Motorized.
        return;
    end

    if self:getIsActiveForInput(false) then
        if InputBinding.hasEvent(InputBinding.FollowMeMyToggle) then
            FollowMe.toggleFollowMe(self);
        end;

        if self.modFM.FollowVehicleObj ~= nil then
            -- v0.77 - Show "activity" on clients also
            self.forceIsActive = true;
            self.stopMotorOnLeave = false;
            self.steeringEnabled = false;
            self.deactivateOnLeave = false;
            self.disableCharacterOnLeave = false;

            -- Due to three functions per InputBinding; press-and-release (short), press-and-hold (long), and press-and-hold-longer (repeat)
            local  myDistDec = FollowMe.hasEventShortLong(InputBinding.FollowMeMyDistDec, 500);
            local  myDistInc = FollowMe.hasEventShortLong(InputBinding.FollowMeMyDistInc, 500);
            local  myOffsDec = FollowMe.hasEventShortLong(InputBinding.FollowMeMyOffsDec);
            local  myOffsInc = FollowMe.hasEventShortLong(InputBinding.FollowMeMyOffsInc);
            
            if     myDistDec == FollowMe.INPUTEVENT_SHORT  then FollowMe.changeDistance(self, self.modFM.FollowKeepBack - 5);
            elseif myDistDec == FollowMe.INPUTEVENT_REPEAT then FollowMe.changeDistance(self, self.modFM.FollowKeepBack - 1);
            elseif myDistInc == FollowMe.INPUTEVENT_SHORT  then FollowMe.changeDistance(self, self.modFM.FollowKeepBack + 5);
            elseif myDistInc == FollowMe.INPUTEVENT_REPEAT then FollowMe.changeDistance(self, self.modFM.FollowKeepBack + 1);
            elseif myOffsDec == FollowMe.INPUTEVENT_SHORT  then FollowMe.changeXOffset(self, self.modFM.FollowXOffset - .5);
            elseif myOffsDec == FollowMe.INPUTEVENT_LONG   then FollowMe.changeXOffset(self, -self.modFM.FollowXOffset); -- Invert offset
            elseif myOffsInc == FollowMe.INPUTEVENT_SHORT  then FollowMe.changeXOffset(self, self.modFM.FollowXOffset + .5);
            elseif myOffsInc == FollowMe.INPUTEVENT_LONG   then FollowMe.changeXOffset(self, -self.modFM.FollowXOffset); -- Invert offset
            end
        end;

        if self.modFM.StalkerVehicleObj ~= nil then
            local stalker = self.modFM.StalkerVehicleObj;
            if InputBinding.hasEvent(InputBinding.FollowMeFlStop) then
                FollowMe.toggleFollowMe(stalker);
            end
            
            -- Due to three functions per InputBinding; press-and-release (short), press-and-hold (long), and press-and-hold-longer (repeat)
            local  flDistDec = FollowMe.hasEventShortLong(InputBinding.FollowMeFlDistDec, 500);
            local  flDistInc = FollowMe.hasEventShortLong(InputBinding.FollowMeFlDistInc, 500);
            local  flOffsDec = FollowMe.hasEventShortLong(InputBinding.FollowMeFlOffsDec);
            local  flOffsInc = FollowMe.hasEventShortLong(InputBinding.FollowMeFlOffsInc);
            
            if     flDistDec == FollowMe.INPUTEVENT_SHORT  then FollowMe.changeDistance(stalker, stalker.modFM.FollowKeepBack - 5);
            elseif flDistDec == FollowMe.INPUTEVENT_REPEAT then FollowMe.changeDistance(stalker, stalker.modFM.FollowKeepBack - 1);
            elseif flDistInc == FollowMe.INPUTEVENT_SHORT  then FollowMe.changeDistance(stalker, stalker.modFM.FollowKeepBack + 5);
            elseif flDistInc == FollowMe.INPUTEVENT_REPEAT then FollowMe.changeDistance(stalker, stalker.modFM.FollowKeepBack + 1);
            elseif flOffsDec == FollowMe.INPUTEVENT_SHORT  then FollowMe.changeXOffset(stalker, stalker.modFM.FollowXOffset - .5);
            elseif flOffsDec == FollowMe.INPUTEVENT_LONG   then FollowMe.changeXOffset(stalker, -stalker.modFM.FollowXOffset); -- Invert offset
            elseif flOffsInc == FollowMe.INPUTEVENT_SHORT  then FollowMe.changeXOffset(stalker, stalker.modFM.FollowXOffset + .5);
            elseif flOffsInc == FollowMe.INPUTEVENT_LONG   then FollowMe.changeXOffset(stalker, -stalker.modFM.FollowXOffset); -- Invert offset
            end
        end;
    end;
end;

function FollowMe.updateTick(self, dt)
    if self.motor == nil then  -- Due to FS15 Steerable without Motorized.
        return;
    end

  if self.isServer then
    --
    if (self.modFM ~= nil) and self.modFM.IsInstalled then
      if self.modFM.FollowState == 1 and self.modFM.FollowVehicleObj ~= nil then -- Have leading vehicle to follow.
        -- Simon Says: Lights!
        self:setLightsTypesMask(       self.modFM.FollowVehicleObj.lightsTypesMask);
        self:setBeaconLightsVisibility(self.modFM.FollowVehicleObj.beaconLightsActive);
        --
        FollowMe.updateFollowMovement(self, dt);
        --
        -- Copied from FS2011-Hirable
        local difficultyMultiplier = Utils.lerp(0.6, 1, (g_currentMission.missionStats.difficulty-1)/2) -- range from 0.6 (easy)  to  1 (hard)
        g_currentMission:addSharedMoney(-dt * difficultyMultiplier * self.modFM.PricePerMS, "wagePayment");
      elseif self.modFM.FollowState == 2 then -- BrakeForDisengage
        FollowMe.updateFollowDisengage(self, dt)
      elseif (self.movingDirection > 0) then  -- Must drive forward to drop crumbs
        self.modFM.sumSpeed = self.modFM.sumSpeed + self.lastSpeed;
        self.modFM.sumCount = self.modFM.sumCount + 1;
        --
        local wx,wy,wz = getWorldTranslation(self.components[1].node); --unpack(self.lastPosition); --getWorldTranslation(self.components[1].node); -- current position
        local pwx,pwy,pwz = unpack(self.modFM.DropperCircularArray[1+((self.modFM.DropperCurrentIndex-1) % FollowMe.cBreadcrumbsMaxEntries)].trans); -- previous position
        local distancePrevDrop = Utils.vector2Length(pwx-wx, pwz-wz);
        if distancePrevDrop >= FollowMe.cMinDistanceBetweenDrops then
            local avgSpeed = math.max((self.modFM.sumSpeed / (self.modFM.sumCount>0 and self.modFM.sumCount or 1)), (5/3600));
            FollowMe.addDrop(self, wx,wy,wz, avgSpeed);
            --
            self.modFM.sumSpeed = 0;
            self.modFM.sumCount = 0;
        end;
      end;
    end;
  end;
  --
  FollowMe.sendUpdate(self);
end;

function FollowMe:sendUpdate(stateId)
  if self.modFM.isDirty 
  or stateId ~= nil 
  or (self.modFM.delayDirty ~= nil and self.modFM.delayDirty < g_currentMission.time) 
  then
    self.modFM.isDirty = false;
    self.modFM.delayDirty = nil;
    --
    if self.isServer then
      -- Remove warning-text if not needed anymore
      if self.modFM.ShowWarningTime < g_currentMission.time then
        self.modFM.ShowWarningText = nil;
      end;
      -- Broadcast current state to all clients.
      FollowMeEvent.sendEvent(self, FollowMe.STATE_NONE);
    else
      -- Only send the client's action-commands to server.
      FollowMeEvent.sendEvent(self, stateId~=nil and stateId or FollowMe.STATE_NONE);
    end;
  end;
end;

function FollowMe:recvUpdate(stateId, keepBackDist, xOffset, followsObj, stalkedByObj, warnTxt)
  if self.isServer then
    -- Received a client's action-commands. Set and mark dirty to broadcast to clients.
    FollowMe.changeDistance(self, keepBackDist, false);
    FollowMe.changeXOffset(self, xOffset, false);
    if stateId ~= FollowMe.STATE_NONE then
      FollowMe.toggleFollowMe(self, stateId, false);
    end;
    if self.modFM.delayDirty ~= nil then
        self.modFM.isDirty = true;
    end
    -- the next updateTick() will broadcast to all clients
  else
    -- Received the server's state. Set and ignore any set dirty flags.
    local prevDirty = self.modFM.isDirty;

    FollowMe.changeDistance(self, keepBackDist, true);
    FollowMe.changeXOffset(self, xOffset, true);
    if warnTxt ~= nil and warnTxt ~= "" then
      FollowMe.setWarning(self, warnTxt, true)
    end;
    FollowMe.setStateFollowStalker(self, followsObj, stalkedByObj);

    self.modFM.isDirty = prevDirty;
  end;
end;


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
    --if (self.modFM.FollowKeepBack < 0) then return 0 + offset; end;
    --return self.modFM.FollowKeepBack + offset;
end;

function FollowMe.updateFollowDisengage(self, dt)
    local acceleration = -1; -- Brake!
    local allowedToDrive = false;
    local lx,lz = 0,1;
    
    --if AIVehicleUtil.mrDriveInDirection and self.isRealistic then
    --    -- MoreRealistic
    --    AIVehicleUtil.mrDriveInDirection(self, dt, acceleration, allowedToDrive, true, lx,lz, 4, false, true);
    --    
    --    if (self.realGroundSpeed*3.6 < 2) then
    --        FollowMe.stoppedFollowMe(self)
    --    end
    --else
        -- Vanilla
        AIVehicleUtil.driveInDirection(self, dt, 30, acceleration, (acceleration * 0.7), 30, allowedToDrive, true, lx,lz, nil, 1);
        
        if (self.lastSpeedReal*3600 < 2) then
            FollowMe.stoppedFollowMe(self)
        end
    --end;
end

function FollowMe.checkBaler(attachedTool)
    local allowedToDrive
    local hasCollision
    if attachedTool.balerUnloadingState == Baler.UNLOADING_CLOSED then
        if attachedTool.fillLevel >= attachedTool.capacity then
            allowedToDrive = false
            hasCollision = true -- Stop faster
            if (table.getn(attachedTool.bales) > 0) and attachedTool:isUnloadingAllowed() then
                -- Activate the bale unloading (server-side only!)
                attachedTool:setIsUnloadingBale(true); 
            end
        end
    else
        allowedToDrive = false
        hasCollision = true
        if attachedTool.balerUnloadingState == Baler.UNLOADING_OPEN then
            -- Activate closing (server-side only!)
            attachedTool:setIsUnloadingBale(false); 
        end
    end
    return allowedToDrive, hasCollision;
end

function FollowMe.checkBaleWrapper(attachedTool)
    local allowedToDrive
    local hasCollision
    if attachedTool.baleWrapperState == 4 then
        allowedToDrive = false
        -- Activate the bale unloading (server-side only!)
        attachedTool:doStateChange(5);
    elseif attachedTool.baleWrapperState > 4 then
        allowedToDrive = false
    end
    return allowedToDrive, hasCollision;
end

function FollowMe.updateFollowMovement(self, dt)
    assert(self.modFM.FollowVehicleObj ~= nil);

    -- Bug-fix: If motor is turned off, stop following.
    if not self.isMotorStarted then
        FollowMe.stopFollowMe(self);
        return;
    end;

    local allowedToDrive = true;
    local hasCollision = false;
    local moveForwards = true;
    --
    if self.numCollidingVehicles ~= nil then
        for _,numCollisions in pairs(self.numCollidingVehicles) do
            if numCollisions > 0 then
                hasCollision = true; -- Collision imminent! Brake! Brake!
                break;
            end;
        end;
    end
    -- v0.75 - attempt at automatically unloading of round-bales
    local attachedTool = nil;
    -- Locate RoundBaler
    for _,tool in pairs(self.attachedImplements) do
        if tool.object ~= nil then
        
            if tool.object.isTurnedOn then 
                if (tool.object.baleUnloadAnimationName ~= nil)  -- Seems RoundBalers are the only ones which have set the 'baleUnloadAnimationName'
                   and SpecializationUtil.hasSpecialization(Baler, tool.object.specializations) then
                    -- Found (Round)Baler.LUA
                    attachedTool = { tool.object, FollowMe.checkBaler };
                    break
                ----elseif SpecializationUtil.hasSpecialization(getfenv(0)[tool.object.customEnvironment].VariableChamberBaler, tool.object.specializations) then
                --elseif tool.object.netBaleAnimation ~= nil and tool.object.setShouldNet ~= nil and tool.object.nettingAnimation ~= nil then
                --    -- Probably found VariableChamberBaler.LUA
                --    attachedTool = { tool.object, FollowMe.checkBaler };
                --    break
                end
            end
            
            if tool.object.baleWrapperState ~= nil then
                if SpecializationUtil.hasSpecialization(BaleWrapper, tool.object.specializations) then
                    -- Found BaleWrapper
                    attachedTool = { tool.object, FollowMe.checkBaleWrapper };
                    break
                end
            end
        end
    end
    --
    if attachedTool ~= nil then
        local setAllowedToDrive
        local setHasCollision
        setAllowedToDrive, setHasCollision = attachedTool[2](attachedTool[1]);
        allowedToDrive = setAllowedToDrive~=nil and setAllowedToDrive or allowedToDrive;
        hasCollision   = setHasCollision~=nil   and setHasCollision   or hasCollision;
    end

--  DEBUG
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
    local acceleration = 1.0; -- Vanilla
    local tMRRealSpd = 0.0; -- MoreRealistic

    -- leader-target
    local keepInFrontMeters = FollowMe.getKeepFront(self);
    lx = lx - lrz * self.modFM.FollowXOffset + lrx * keepInFrontMeters;
    lz = lz + lrx * self.modFM.FollowXOffset + lrz * keepInFrontMeters;
    -- distance to leader-target
    local distMeters = Utils.vector2Length(cx-lx,cz-lz);
    
    local crumbIndexDiff = leader.modFM.DropperCurrentIndex - self.modFM.FollowCurrentIndex;
    
    --
    if crumbIndexDiff > 0 then
        -- Following crumbs...
        if crumbIndexDiff >= FollowMe.cBreadcrumbsMaxEntries then
            -- circular-array have "circled" once, and this follower did not move fast enough.
            --DEBUG log("Much too far behind. Stopping auto-follow.");
            FollowMe.setWarning(self, "FollowMeTooFarBehind");
            FollowMe.stopFollowMe(self);
            return;        
        end;
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
--  DEBUG
if Vehicle.debugRendering then
    FollowMe.debugDraw[dbgId.."a3"] = {"FM",string.format("KeepBack:%.2f, DistCrumbs:%.0f/%.2f, DistTarget:%.2f", keepBackMeters, distCrumbs, distFraction, tDist) };
end;    
--DEBUG]]    
            --
            --if AIVehicleUtil.mrDriveInDirection and self.isRealistic then
            --    if crumbT.realGroundSpeed ~= nil then
            --        tMRRealSpd = math.max(1.1 * crumbT.realGroundSpeed * 3.6, 5); -- 10% quicker to "chase" the followed
            --    else
            --        tMRRealSpd = math.max(1.1 * crumbAvgSpeed * 3600, 5);
            --    end;
            --    
            --    if keepInFrontMeters > 0 then
            --        if distMeters > 20 then
            --          tMRRealSpd = math.max(tMRRealSpd, 25) -- 25km/h or more...
            --        elseif distMeters > 5 and tMRRealSpd < 10 then
            --          tMRRealSpd = tMRRealSpd * (1.2 + ((distMeters - 5) / 15)); -- 20% or more faster speed to "catch up"
            --        elseif distMeters > 2 then
            --          tMRRealSpd = tMRRealSpd * 1.1 -- 10% faster speed than leader to "follow"
            --        end
            --    end;
            --    
            --    if (self.realGroundSpeed*3.6) > (tMRRealSpd * 1.00) then
            --        -- Going too fast!
            --        allowedToDrive = false;
            --        
            --        if (self.realGroundSpeed*3.6) > (tMRRealSpd * 1.05) then
            --            -- Going way much too fast!
            --            hasCollision = true; -- apply brakes
            --        end
            --    end;
            --else
                --local mySpeedDiff = (math.max(0, self.lastSpeedReal) - math.max(0,self.modFM.lastLastSpeedReal)) / dt;
                --local mySpeedDiffPct = (mySpeedDiff / math.max(0.00001,self.modFM.lastLastSpeedReal)) - 1;
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
--  DEBUG
if Vehicle.debugRendering then
    FollowMe.debugDraw[dbgId.."a5"] = {"FM",string.format("MySpdDiff:%+3.1f, TrgSpdDiff:%+.2f, Apply:%+.4f", mySpeedDiffPct*100, targetSpeedDiffPct, (targetSpeedDiffPct * (1 - math.abs(mySpeedDiffPct))) ) };
    tMRRealSpd = crumbAvgSpeed*3600;
end;    
--DEBUG]]                
            --end
        end;
    end;
    --
    if crumbIndexDiff <= 0 then
        ---- Following leader directly...
        tx = lx;
        ty = ly;
        tz = lz;
        -- Rotate to see if the target is still "in front of us"
        local dx,dz = tx - cx, tz - cz;
        local trAngle = math.atan2(lrx,lrz);
        local nz = dx * math.sin(trAngle) + dz * math.cos(trAngle);
        --
        local distMetersDiff = distMeters - FollowMe.getKeepBack(self);
--  DEBUG
if Vehicle.debugRendering then
    FollowMe.debugDraw[dbgId.."a3"] = {"FM",string.format("DistDiff: %.2f", distMetersDiff)};
end;    
--DEBUG]]    
        allowedToDrive = allowedToDrive and (keepInFrontMeters >= 0) and (nz > 0) and (distMetersDiff > 0.5);
        
        -- Leader-vehicle can be vanilla or MoreRealistic. Get speed from the proper one.
        local leaderLastSpeedKMH = math.max(0, leader.lastSpeedReal) * 3600; -- only consider forward movement.
        --if leader.isRealistic then
        --    leaderLastSpeedKMH = leader.realGroundSpeed * 3.6;
        --end

        --if AIVehicleUtil.mrDriveInDirection and self.isRealistic then
        --    local minSpeed = (leaderLastSpeedKMH < 1.0) and 5 or 0; -- if leader is basically stopped, set stalker's minimum speed to 5km/h
        --    tMRRealSpd = math.max(leaderLastSpeedKMH, minSpeed);
        --
        --    if distMetersDiff > 2 then
        --        if distMetersDiff > 15 then
        --          tMRRealSpd = math.max(tMRRealSpd * 1.75, 25) -- 25km/h or more...
        --        elseif distMetersDiff > 10 then
        --          tMRRealSpd = math.max(tMRRealSpd * 1.5, 17) -- 17km/h or more...
        --        elseif distMetersDiff > 5 then
        --          tMRRealSpd = math.max(tMRRealSpd * 1.25, 10) -- 10km/h or more...
        --        else
        --          tMRRealSpd = tMRRealSpd * 1.1 -- 10% faster speed than leader to "follow"
        --        end
        --    elseif distMetersDiff < 1 then
        --        tMRRealSpd = tMRRealSpd * 0.9; -- Try to attempt not going too fast, and thereby doing "drive-stop-drive-stop-..."
        --    end;
        --    
        --    if (self.realGroundSpeed*3.6) > (tMRRealSpd + 10) then
        --        -- Going too fast!
        --        allowedToDrive = false;
        --    end;
        --else
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
--  DEBUG
if Vehicle.debugRendering then
    FollowMe.debugDraw[dbgId.."a5"] = {"FM",string.format("MySpdDiff:%+3.1f, TrgSpdDiff:%+3.1f, Apply:%+.4f", mySpeedDiffPct*100, targetSpeedDiffPct*100, (targetSpeedDiffPct * (1 - math.abs(mySpeedDiffPct))) ) };
    tMRRealSpd = leaderLastSpeedKMH;
end;    
--DEBUG]]                
        --end;
    end;
    --
--  DEBUG
    FollowMe.dbgTarget = {tx,ty,tz};
--DEBUG]]    
    --
    local lx,lz = AIVehicleUtil.getDriveDirection(self.components[1].node, tx,ty,tz);

    -- Reduce speed if "attack angle" against target is more than 45degrees.
    if self.modFM.reduceSpeedTime > g_currentMission.time then
        --tMRRealSpd = tMRRealSpd * 0.5
        acceleration = acceleration * 0.5;
    elseif (self.lastSpeed*3600 > 10) and (math.abs(math.atan2(lx,lz)) > (math.pi/4)) then
        --tMRRealSpd = tMRRealSpd * 0.5
        acceleration = acceleration * 0.5;
        self.modFM.reduceSpeedTime = g_currentMission.time + 250; -- For the next 250ms, keep speed reduced.
    end;
    
--  DEBUG
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

        --if AIVehicleUtil.mrDriveInDirection and self.isRealistic then
        --    -- MoreRealistic
        --    self.motor.realSpeedLevelsAI[1] = 0.0;
        --    AIVehicleUtil.mrDriveInDirection(self, dt, acceleration, allowedToDrive, true, lx,lz, 1, false, true);
        --else
            -- Vanilla
            AIVehicleUtil.driveInDirection(self, dt, 30, acceleration, (acceleration * 0.7), 30, allowedToDrive, moveForwards, lx,lz, nil, 1);
        --end;
    else
        --if AIVehicleUtil.mrDriveInDirection and self.isRealistic then
        --    -- MoreRealistic
        --    self.motor.realSpeedLevelsAI[4] = tMRRealSpd;
        --    AIVehicleUtil.mrDriveInDirection(self, dt, 1, allowedToDrive, true, lx,lz, 4, false, true);
        --else
            -- Vanilla
            -- self.turnStage = -1; -- MoreRealistic v1.0 - Make MR think that we are not "working in line", so the steeringSpeed will be faster.
            --self.motor.maxRpmOverride = nil;
            AIVehicleUtil.driveInDirection(self, dt, 30, acceleration, (acceleration * 0.7), 30, allowedToDrive, moveForwards, lx,lz, nil, 1);
        --end
    end;

    -- v0.76
    if self.aiTrafficCollisionTrigger ~= nil then
        -- Attempt to rotate the traffic-collision-trigger in direction of steering
        AIVehicleUtil.setCollisionDirection(getParent(self.aiTrafficCollisionTrigger), self.aiTrafficCollisionTrigger, lx,lz);
    end

--  DEBUG
if Vehicle.debugRendering then
    FollowMe.debugDraw[dbgId.."a0"] = {"FM",string.format("Vehicle:%s",    tostring(self.realVehicleName))};
    FollowMe.debugDraw[dbgId.."a1"] = {"FM",string.format("AllowDrive:%s, Collision:%s, CrumbIdx:%s, CrumbDiff:%s", allowedToDrive and "Y" or "N", hasCollision and "Y" or "N", tostring(self.modFM.FollowCurrentIndex), tostring(crumbIndexDiff))};
    FollowMe.debugDraw[dbgId.."a2"] = {"FM",string.format("Acc:%1.2f, LstSpd:%2.3f, mrRealSpd:%2.3f, %s", acceleration, self.lastSpeed*3600, tMRRealSpd, (self.modFM.reduceSpeedTime > g_currentMission.time) and "Half!" or "")};
end;    
--DEBUG]]
end;

function FollowMe.toggleFollowMe(self, stateId, noSendEvent)
    if not self.modFM.IsInstalled then
        FollowMe.setWarning(self, "FollowMeNotAvailable");
    elseif self.isServer then
--  DEBUG
FollowMe.debugDraw = {};
--DEBUG]]
        if self.modFM.FollowVehicleObj == nil and (stateId == nil or stateId ~= FollowMe.STATE_STOP) then
            FollowMe.startFollowMe(self, noSendEvent);
        else
            FollowMe.stopFollowMe(self, noSendEvent);
        end;
    else
        FollowMe.sendUpdate(self, FollowMe.STATE_TOGGLE);
    end;
end;

function FollowMe.setStalker(self, stalkerVeh, noSendEvent)
    self.modFM.StalkerVehicleObj = stalkerVeh;
    self.modFM.isDirty = self.isServer and true or self.modFM.isDirty;
end;

function FollowMe.setStateFollowStalker(self, followsObj, stalkedByObj)
    assert(g_server == nil);    -- Only for clients
    --
    self.modFM.FollowVehicleObj  = followsObj;
    self.modFM.StalkerVehicleObj = stalkedByObj;
    --
    -- Try to fix the problem of clients not seeing wheel-rotation and the "farmer-in-the-seat".
    if (self.modFM.FollowVehicleObj ~= nil) then
        self.forceIsActive = true;
        self.stopMotorOnLeave = false;
        self.steeringEnabled = false;
        self.deactivateOnLeave = false;
        self.disableCharacterOnLeave = false;

        ---- MoreRealistic - DURAL
        --self.realForceAiDriven = true;
    else
        self.forceIsActive = false;
        self.stopMotorOnLeave = true;
        self.steeringEnabled = true;
        self.deactivateOnLeave = true;
        self.disableCharacterOnLeave = true;
        if not self.isEntered and not self.isControlled then
            if self.characterNode ~= nil then
                setVisibility(self.characterNode, false);
            end;
        end;

        ---- MoreRealistic - DURAL
        --self.realForceAiDriven = false;
    end;
end;

function FollowMe.startFollowMe(self, noEventSend)
    assert(g_server ~= nil);

    if self.modFM.FollowVehicleObj ~= nil then
        --FollowMe.setWarning(self, "FollowMeActive");
        return;
    end;
    -- Make sure the motor is turned on, before allowing to auto-follow
    if not self.isMotorStarted then
        FollowMe.setWarning(self, "FollowMeStartEngine");
        return;
    end;

    --
    local wx,wy,wz = getWorldTranslation(self.components[1].node);
    local rx,ry,rz = localDirectionToWorld(self.components[1].node, 0,0,1);
    local rlength = Utils.vector2Length(rx,rz);
    local rotDeg = math.deg(math.atan2(rx/rlength,rz/rlength));
    local rotRad = Utils.degToRad(rotDeg-45.0);
    local rotRad = Utils.degToRad(rotDeg-45.0);
    --log(string.format("getWorldTranslation:%f/%f/%f - localDirectionToWorld:%f/%f/%f - rDeg:%f - rRad:%f", wx,wy,wz, rx,ry,rz, rotDeg, rotRad));

    -- Find closest vehicle, that is in front of self.
    local closestDistance = 50;
    local closestVehicle = nil;
    for _,vehicleObj in pairs(g_currentMission.steerables) do
        if vehicleObj.modFM ~= nil -- (v2.0.6) Make sure its a vehicle that has the FollowMe specialization added.
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

    if closestVehicle == nil then
        FollowMe.setWarning(self, "FollowMeDropperNotFound");
        return;
    end;

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
        self.modFM.FollowVehicleObj = nil;
        FollowMe.setWarning(self, "FollowMeDropperNotFound");
        return;
    end;

    -- Chain with leading vehicle.
    self.modFM.FollowVehicleObj = closestVehicle;
    FollowMe.setStalker(self.modFM.FollowVehicleObj, self);
    -- Set engaged state
    self.modFM.FollowState = 1;
   
    --
    if SpecializationUtil.hasSpecialization(AITractor, self.specializations) then
        AITractor.addCollisionTrigger(self, self);
    elseif SpecializationUtil.hasSpecialization(AICombine, self.specializations) then
        AICombine.addCollisionTrigger(self, self);
    else
        -- TODO - Display warning!
    end;
    
    -- Copied from FS2011-Hirable, for the mods that do not include that specialization in their vehicle-type.
    self.forceIsActive = true;
    self.stopMotorOnLeave = false;
    self.steeringEnabled = false;
    self.deactivateOnLeave = false;
    self.disableCharacterOnLeave = false;

    ---- moreRealistic vv
    --if AIVehicleUtil.mrDriveInDirection ~= nil then
    --    -- MoreRealistic - DURAL
    --    self.realForceAiDriven = true;
    ----else
    ----    if self.motor.isRealistic then
    ----        -- MoreRealistic v1.0
    ----        -- Due to moreRealistic's driveInDirection(), which sets speedLevel=2 in a "hardcoded" manner,
    ----        -- I'm here switching the realSpeedLevels 2 and 4 - these are then switched again, when FollowMe is stopped.
    ----        local temp = self.motor.realSpeedLevels[2];
    ----        self.motor.realSpeedLevels[2] = self.motor.realSpeedLevels[4];
    ----        self.motor.realSpeedLevels[4] = temp;
    ----    end
    --end;
    ---- moreRealistic ^^

    ----FS2015 - TODO, make visible on clients too!
    local iconWidth = math.floor(0.015 * g_screenWidth) / g_screenWidth;
    local iconHeight = iconWidth * g_screenAspectRatio;
    
    self.modFM.mapIcon = g_currentMission.ingameMap:createMapHotspot(
        "fm", 
        FollowMe.mapIconFile, 
        0,0, 
        iconWidth,iconHeight,
        false, 
        false, 
        false, 
        self.rootNode,
        false,
        false
    );
    
    self.modFM.isDirty = true;
end;

function FollowMe.stopFollowMe(self, noSendEvent)
    assert(g_server ~= nil);

    if self.modFM.FollowVehicleObj == nil then
        return;
    end;

    -- Unchain with leading vehicle.
    assert(self.modFM.FollowVehicleObj.modFM.StalkerVehicleObj == self);
    FollowMe.setStalker(self.modFM.FollowVehicleObj, nil);
    --
    self.modFM.FollowVehicleObj = nil;
    self.modFM.FollowCurrentIndex = 0;

    --
    if SpecializationUtil.hasSpecialization(AITractor, self.specializations) then
        AITractor.removeCollisionTrigger(self, self);
    elseif SpecializationUtil.hasSpecialization(AICombine, self.specializations) then
        AICombine.removeCollisionTrigger(self, self);
    end;
    
    -- Set BrakeToDisengage state
    self.modFM.FollowState = 2;
end;
    
function FollowMe.stoppedFollowMe(self, noSendEvent)
    assert(g_server ~= nil);

    -- Set Disengaged state
    self.modFM.FollowState = 0;

    ----FS2015
    --if self.dismiss then
    --  self:dismiss()
    --end
    
    -- Copied from FS2011-Hirable, for the mods that do not include that specialization in their vehicle-type.
    self.forceIsActive = false;
    self.stopMotorOnLeave = true;
    self.steeringEnabled = true;
    self.deactivateOnLeave = true;
    self.disableCharacterOnLeave = true;
    
    if not self.isEntered and not self.isControlled then
        if self.characterNode ~= nil then
            setVisibility(self.characterNode, false);
        end;

        -- Stop engine, as there is no player in the vehicle.
        self:stopMotor(noSendEvent);
    end;

    -- Copied from Steerable:onLeave, in attempt at making the vehicle brake/stop.
    self.lastAcceleration = 0;

    -- Vanilla
    --self.motor:setSpeedLevel(0, false);
    --self.motor.maxRpmOverride = nil;

    ---- moreRealistic vv
    --if AIVehicleUtil.mrDriveInDirection ~= nil then
    --    -- MoreRealistic - DURAL
    --    self.realForceAiDriven = false;
    --    
    --    --Steerable.realDesactivateVehicle(self);
    ----else
    ----    if self.motor.isRealistic then
    ----        -- MoreRealistic v1.0
    ----        local temp = self.motor.realSpeedLevels[2];
    ----        self.motor.realSpeedLevels[2] = self.motor.realSpeedLevels[4];
    ----        self.motor.realSpeedLevels[4] = temp;
    ----    end
    --end;
    ---- moreRealistic ^^

    WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeed, 0, true, self.requiredDriveMode); -- doHandBrake

    -- FS2015
    if self.modFM.mapIcon ~= nil then
        g_currentMission.ingameMap:deleteMapHotspot(self.modFM.mapIcon);
        self.modFM.mapIcon = nil;
    end
    --
    self.modFM.isDirty = true;
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
        g_currentMission:addWarning(g_i18n:getText(self.modFM.ShowWarningText))
    end;
    --
    local showFollowMeMy = FollowMe.keyModifier_FollowMeMy == nil or (FollowMe.keyModifier_FollowMeMy ~= nil and Input.isKeyPressed(FollowMe.keyModifier_FollowMeMy));
    local showFollowMeFl = FollowMe.keyModifier_FollowMeFl == nil or (FollowMe.keyModifier_FollowMeFl ~= nil and Input.isKeyPressed(FollowMe.keyModifier_FollowMeFl));
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
    end
    --
    if showFollowMeFl and self.modFM.StalkerVehicleObj ~= nil then
        local sx,sy = FollowMe.getWorldToScreen(self.modFM.StalkerVehicleObj.components[1].node)
        if sx~=nil then
            local txt = g_i18n:getText("FollowMeFollower")
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
    if g_currentMission.showHelpText then
        if self.modFM.FollowVehicleObj ~= nil
        or showFollowMeMy then
            g_currentMission:addHelpButtonText(g_i18n:getText("FollowMeMyToggle"), InputBinding.FollowMeMyToggle);
        end;
        --
        if self.modFM.FollowVehicleObj ~= nil then
            g_currentMission:addExtraPrintText(
                string.format(
                    g_i18n:getText("FollowMeKeysMyself")
                    ,FollowMe.keys_FollowMeMy
                    ,self.modFM.FollowKeepBack
                    ,self.modFM.FollowXOffset
                )
            );
        end;
        --
        if self.modFM.StalkerVehicleObj ~= nil then
            g_currentMission:addHelpButtonText(g_i18n:getText("FollowMeFlStop"), InputBinding.FollowMeFlStop);
            g_currentMission:addExtraPrintText(
                string.format(
                    g_i18n:getText("FollowMeKeysBehind")
                    ,FollowMe.keys_FollowMeFl
                    ,self.modFM.StalkerVehicleObj.modFM.FollowKeepBack
                    ,self.modFM.StalkerVehicleObj.modFM.FollowXOffset
                )
            );
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

--  DEBUG
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

----  DEBUG
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

--Steerable.load        = Utils.appendedFunction( Steerable.load,          FollowMe.load);
--Steerable.delete      = Utils.appendedFunction( Steerable.delete,        FollowMe.delete);
--Steerable.writeStream = Utils.appendedFunction( Steerable.writeStream,   FollowMe.writeStream);
--Steerable.readStream  = Utils.appendedFunction( Steerable.readStream,    FollowMe.readStream);
--Steerable.update      = Utils.prependedFunction(Steerable.update,        FollowMe.update);
--Steerable.updateTick  = Utils.appendedFunction( Steerable.updateTick,    FollowMe.updateTick);
--Steerable.draw        = Utils.appendedFunction( Steerable.draw,          FollowMe.draw);

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

function FollowMeEvent:new(vehicle, stateId)
    local self = FollowMeEvent:emptyNew()
    self.vehicle      = vehicle;
    self.stateId      = stateId;
    return self;
end;

function FollowMeEvent:writeStream(streamId, connection)
--log("FollowMeEvent:writeStream()");
    FollowMe.sharedWriteStream(
        g_server ~= nil,
        streamId,
        self.vehicle,
        self.vehicle.modFM.FollowVehicleObj,
        self.vehicle.modFM.StalkerVehicleObj,
        self.stateId,
        self.vehicle.modFM.FollowKeepBack,
        self.vehicle.modFM.FollowXOffset,
        self.vehicle.modFM.ShowWarningText
    );
end;

function FollowMeEvent:readStream(streamId, connection)
    local vehObj, followsObj, stalkedByObj, stateId, keepBackDist, xOffset, warnTxt;
    vehObj,
    followsObj,
    stalkedByObj,
    stateId,
    keepBackDist,
    xOffset,
    warnTxt         = FollowMe.sharedReadStream(g_server == nil, streamId);
    --
    if vehObj ~= nil then
--log("FollowMeEvent:readStream()");
        FollowMe.recvUpdate(vehObj, stateId, keepBackDist, xOffset, followsObj, stalkedByObj, warnTxt);
    end;
end;

function FollowMeEvent.sendEvent(vehicle, stateId, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
--log("g_server:broadcastEvent");
            g_server:broadcastEvent(FollowMeEvent:new(vehicle, stateId), nil, nil, vehicle);
        else
--log("g_client:getServerConnection():sendEvent()");
            g_client:getServerConnection():sendEvent(FollowMeEvent:new(vehicle, stateId));
        end;
    end;
end;
    
--
print(string.format("Script loaded: FollowMe.lua (v%s)", FollowMe.version));
