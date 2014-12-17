--
-- AutoFollow a Breadcrumb-trail
--
-- @author  Decker_MMIV  (www.ls-uk.info, forum.farming-simulator.com)
-- @date    2011-02-01
--          2012-08-29 (resumed)
--
-- Modifikationen erst nach Rücksprache
-- Do not edit without my permission
--
-- @history
--    v0.5(beta)  - Beta-release for internal FMC testing/criticism/suggestions
--    v0.51(beta) - Managed to get followers to use speed-throttle (well, not good enough), so they do 
--                   not always drive as fast as possible.
--                - Fixed problem of "circling a breadcrumb that vehicle can never reach", by calculating if 
--                   vehicle is "in front of" the breadcrumb, which in that case it will go to the next one instead.
--    v0.52(beta) - Changed so the functions are appended to Steerable specialization, instead of Hirable, as there
--                   may be many "Truck"-mods that do not have Hirable.
--                - Resets breadcrumb trail at every start. Previous version kept the trail "alive".
--    v0.53(beta) - TextBold=false, TextColor=white.
--  2012-November
--    v0.54(beta) - Lots of changes. Attempt at FS2011 & FS2013 code.
--
--

--[[
oliver45
    what do you do if you deleted the leader, because when i try making a new leader its says "there is already a leader" ?
    http://www.ls-uk.info/forum/index.php?topic=118980.msg767135#msg767135
   
MacPolska
    would it be possible to have some control over the distance and/or speed of the follower from the leader?
    http://www.ls-uk.info/forum/index.php?topic=118980.msg767298#msg767298
    
Feterlj
    it would be nice to have an offset function so that if the leader is using an implement that is centered with the tractor, but the follower is using an implement that is not centered with the tractor, you could offset him to do the job on the correct path.          
    http://www.ls-uk.info/forum/index.php?topic=118980.msg767394#msg767394
    
Rsmasterrs
    put on beacons, they should stay on when you tell the vechicle to follow
    http://www.ls-uk.info/forum/index.php?topic=118980.msg767403#msg767403
    
rh
    - As someone mentioned above, an offset function
    - Beacons/lights for followers? Not sure if this is possible, but would be nice if say the beacons came on when the leader's beacons were on - you get the idea
    - Adjustable following distance?    
    http://www.ls-uk.info/forum/index.php?topic=118980.msg767732#msg767732
    
seederman
    I have found when I tried a lead and 2 followers the 3rd one tends to get real close to the 2nd actually gets dirty and mounts 2nd lol, is there a way to spread them out so they don't get too close
    http://www.ls-uk.info/forum/index.php?topic=118980.msg768374#msg768374
    
Rondo
    is there in some way a possibility to alter the distance between the leader and the follower?    
    http://www.ls-uk.info/forum/index.php?topic=118980.msg768652#msg768652
]]

AutoFollow = {};

AutoFollow.logLevel = 0; -- 1=Seldom occuring logs, 2=Event occuring logs, 3=Often occuring logs, 4=VeryOften occuring logs
AutoFollow.debugShowWaypoints = false;

AutoFollow.cBreadcrumbsMaxEntries          = 50;   -- TODO, make configurable
AutoFollow.cMstimeBetweenDrops             = 40;   -- TODO, make configurable
AutoFollow.cMinDistanceBetweenDrops        = 2;    -- TODO, make configurable
AutoFollow.cMaxDistanceBetweenDrops        = 10;   -- TODO, make configurable
AutoFollow.cMaxAngleBetweenDrops           = 10;   -- TODO, make configurable

-- AutoFollow.afHudWidth  = 0.32;
-- AutoFollow.afHudHeight = 0.18;
-- AutoFollow.afHudOverlayPosX   = 0.43;
-- AutoFollow.afHudOverlayPosY   = 0.044;
-- AutoFollow.afHudOverlay = Overlay:new("AutoFollowHud", Utils.getFilename("AutoFollowHud.png", g_currentModDirectory), AutoFollow.afHudOverlayPosX, AutoFollow.afHudOverlayPosY, AutoFollow.afHudWidth, AutoFollow.afHudHeight);


-- FS2011
function AutoFollow:consoleCommandAutoFollowShowWaypoints(newBool)
    --if newBool ~= nil then
        AutoFollow.debugShowWaypoints = not AutoFollow.debugShowWaypoints;
    --end;
    return "modFollowMeShowWaypoints = "..tostring(AutoFollow.debugShowWaypoints);
end;
addConsoleCommand("modFollowMeShowWaypoints", "For debugging", "consoleCommandAutoFollowShowWaypoints", AutoFollow);
--]]


function AutoFollow:log(logLevel, txt)
  if (AutoFollow.logLevel >= logLevel) then
    print(string.format("%7ums AutoFollow(%s) ", g_currentMission.time, tostring(self)) .. txt);
  end;
end;


--[[ FS2013

-- Support-functions, that I would like to see be added to InputBinding class.
-- Maybe it is, I just do not know what its called.
function getKeyIdOfModifier(binding)
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

function hasKeyModifierPressed(binding)
    return ((binding == nil) or (Input.isKeyPressed(binding)));
end;


-- Get the modifier-key (if any) from input-binding
AutoFollow.inputbindingmodifierAutoFollowLead  = getKeyIdOfModifier(InputBinding.AutoFollowLead);
AutoFollow.inputbindingmodifierAutoFollowDrive = getKeyIdOfModifier(InputBinding.AutoFollowDrive);

--]]

-- FS2011

--http://stackoverflow.com/questions/656199/search-for-an-item-in-a-lua-list
function makeSet(list)
    local set = {};
    for _,l in ipairs(list) do
        set[l]=true;
    end;
    return set;
end;

-- Find which of the modifier-keys (left/right shift/ctrl/alt) that may be assigned to the input-binding
function getKeyModifier(binding)
    local allowedModifiers = makeSet({
        Input.KEY_lshift,
        Input.KEY_rshift,
        Input.KEY_lctrl, 
        Input.KEY_rctrl, 
        Input.KEY_lalt,  
        Input.KEY_ralt,
        Input.KEY_shift
    });
    for _,k in pairs(InputBinding.digitalActions[binding].key1Modifiers) do
        if allowedModifiers[k] then
            return k;
        end;
    end;
    -- No modifier-key found.
    return nil;
end;

function hasKeyModifierPressed(binding)
    return ((binding == nil) or (Input.isKeyPressed(binding)));
end;

-- Get the modifier-key (if any) from input-binding
AutoFollow.inputbindingmodifierAutoFollowLead  = getKeyModifier(InputBinding.AutoFollowLead);
AutoFollow.inputbindingmodifierAutoFollowDrive = getKeyModifier(InputBinding.AutoFollowDrive);

--]]


--
--
--

function AutoFollow.load(self, xmlFile)
    --
    self.afIsInstalled = true;  -- TODO. Make 'FollowMe' a buyable add-on!
    --
    self.afDropperTime = 0;
    self.afDropperCircularArray = {};
    self.afDropperCurrentIndex = 0;
    self.afStalkerVehicleObj = nil;  -- Needed in case self is being deleted.
    --
    self.afFollowTime = 0;
    self.afFollowVehicleObj = nil;
    self.afFollowCurrentIndex = 0;
    --
    --self.startAutoFollow    = SpecializationUtil.callSpecializationsFunction("startAutoFollow");
    --self.stopAutoFollow     = SpecializationUtil.callSpecializationsFunction("stopAutoFollow");
    --
    --self.afHudVisible = false;
    self.afShowWarningText = nil;
    self.afShowWarningTime = 0;
    --
    -- Copied from Hirable, for the mods that do not include that specialization in their vehicle-type.
    self.afPricePerMS = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.pricePerHour"), 2000)/60/60/1000;
    --
-- FS2011    
    -- Copied from AITractor/AICombine, for mods that do not include that specialization in their vehicle-type.
    self.numCollidingVehicles = 0;
    if (self.aiTrafficCollisionTrigger == nil) then
        self.aiTrafficCollisionTrigger = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiTrafficCollisionTrigger#index"));
    end;
    if (self.aiTrafficCollisionTrigger == nil) then
        AutoFollow:log(1, "WARNING: 'aiTrafficCollisionTrigger' is missing for this vehicle-type: ".. tostring(self.typeName));
    end;
--]]    
end;

function AutoFollow.delete(self)
    if self.afStalkerVehicleObj ~= nil then
        AutoFollow.stopAutoFollow(self.afStalkerVehicleObj);
    end;
    --
    AutoFollow.stopAutoFollow(self);
end;

function AutoFollow.mouseEvent(self, posX, posY, isDown, isUp, button)
end;

function AutoFollow.keyEvent(self, unicode, sym, modifier, isDown)
end;

function AutoFollow.setWarning(self, txt)
    self.afShowWarningText = g_i18n:getText(txt);
    self.afShowWarningTime = g_currentMission.time + 2000;
end;

function AutoFollow.update(self, dt)
--[[ FS2013
    if self:getIsActive() and self.isEntered then
--]]
-- FS2011
    if self:getIsActiveForInput() then
--]]    
        if InputBinding.hasEvent(InputBinding.AutoFollowDrive) then
            if self.afFollowVehicleObj == nil then
                AutoFollow.startAutoFollow(self);
            else
                AutoFollow.stopAutoFollow(self);
            end;
        end;
    end;
    --
    if (self.isServer and self.afFollowVehicleObj ~= nil and (self.hire == nil or self.isHired ~= true)) then
        -- Copied from Hirable, for the mods that do not include that specialization in their vehicle-type.
        local difficultyMultiplier = Utils.lerp(0.6, 1, (g_currentMission.missionStats.difficulty-1)/2) -- range from 0.6 (easy)  to  1 (hard)
        g_currentMission:addSharedMoney(-dt * difficultyMultiplier * self.afPricePerMS);
    end;
end;

function AutoFollow.updateTick(self, dt)
  if self.isServer then
    --
    if self.afIsInstalled then
      if (self.movingDirection >= 0) then  -- Must drive forward
        self.afDropperTime = self.afDropperTime - dt;
        if (self.afDropperTime < 0) then
            self.afDropperTime = AutoFollow.cMstimeBetweenDrops;
            local wx,wy,wz = getWorldTranslation(self.components[1].node);
            --
            local distancePrevDrop = 9999;
            if self.afDropperCurrentIndex > 0 then
                local pwx,pwy,pwz = unpack(self.afDropperCircularArray[1+((self.afDropperCurrentIndex-1) % AutoFollow.cBreadcrumbsMaxEntries)].trans);
                local dx,dz = pwx-wx, pwz-wz;
                distancePrevDrop = Utils.vector2Length(dx,dz);
            end;
            --
            if distancePrevDrop > AutoFollow.cMaxDistanceBetweenDrops then
                --AutoFollow:log(3, "DistToPrev:".. distancePrevDrop);
                self.afDropperCurrentIndex = self.afDropperCurrentIndex + 1; -- Keep incrementing index, so followers will be able to detect if they get too far behind of the circular-array.
                local dropIndex = 1+((self.afDropperCurrentIndex-1) % AutoFollow.cBreadcrumbsMaxEntries);
                --
                if self.afDropperCircularArray[dropIndex] ~= nil then
                    if self.afDropperCircularArray[dropIndex].nodeObj ~= nil then
                        --AutoFollow:log(3, "Deleting crumb.");
                        delete(self.afDropperCircularArray[dropIndex].nodeObj);
                        self.afDropperCircularArray[dropIndex].nodeObj = nil;
                    end;
                end;
                --
                local rx,ry,rz  = localDirectionToWorld(self.components[1].node, 0,0,1);
                self.afDropperCircularArray[dropIndex] = { trans={wx,wy,wz}, rot={rx,ry,rz}, lastSpeed=self.lastSpeed };
                --AutoFollow:log(3, string.format("Crumb #%d(%d): dist=%f, trans=%f/%f/%f, rot=%f/%f/%f, lastSpeed=%f", AutoFollow.gBreadcrumbsCurrentDropIndex,dropIndex, distancePrevDrop, wx,wy,wz, rx,ry,rz, self.lastSpeed));
                --
                if AutoFollow.debugShowWaypoints then
                    --AutoFollow:log(3, "Creating crumb.");
                    local wpObj = loadI3DFile(getAppBasePath().. "data/maps/models/objects/checkpoint/waypoint.i3d");
                    setTranslation(wpObj, wx,wy,wz);
                    --setRotation(wpObj, rx,ry,rz);
                    link(getRootNode(), wpObj);
                    self.afDropperCircularArray[dropIndex].nodeObj = wpObj;
                end;
            end;
        end;
      end;
      
      --
      if self.afFollowVehicleObj ~= nil then -- Must have leading vehicle to follow.
        self.afFollowTime = self.afFollowTime + dt;
        if (self.afFollowTime > 20) then
            AutoFollow.updateFollowMovement(self, self.afFollowTime);
            self.afFollowTime = 0;
        end;
      end;
    end;
  end;
end;

function AutoFollow.updateFollowMovement(self, dt)
    assert(self.afFollowVehicleObj ~= nil);
    
    local allowedToDrive = true;
    local moveForwards = true;
    --
    if self.numCollidingVehicles ~= nil and self.numCollidingVehicles > 0 then
        allowedToDrive = false;
    end;
    --
    local acceleration = 1.0;
    local crumb;
    if allowedToDrive then
        local wx,wy,wz = getWorldTranslation(self.components[1].node);

        if self.afFollowCurrentIndex == self.afFollowVehicleObj.afDropperCurrentIndex then
            -- do nothing, waiting for another "crumb"
            --AutoFollow:log(2, "Waiting for next drop-index.");
            allowedToDrive = false;
        elseif self.afFollowCurrentIndex <= (self.afFollowVehicleObj.afDropperCurrentIndex - AutoFollow.cBreadcrumbsMaxEntries) then
            -- circular-array have "circled" once, and this follower did not move fast enough.
            AutoFollow:log(2, "Much too far behind. Stopping auto-follow.");
            AutoFollow.stopAutoFollow(self);
            return;
        else
--[[ FS2013
            if (self.afFollowVehicleObj.afDropperCurrentIndex - self.afFollowCurrentIndex < 10) then
                allowedToDrive = false;
            end
--]]              
            if (self.afFollowVehicleObj.afDropperCurrentIndex - self.afFollowCurrentIndex < 3) then
                -- Approacing leading vehicle, so slow down
                acceleration = 0.2;
            end;
            --
            crumb = self.afFollowVehicleObj.afDropperCircularArray[1+((self.afFollowCurrentIndex-1) % AutoFollow.cBreadcrumbsMaxEntries)];
            if crumb ~= nil then
                local dx,dz = crumb.trans[1]-wx, crumb.trans[3]-wz;
                local dist = Utils.vector2Length(dx,dz);
                -- Rotate to see if the point is still "in front of us"
                rx,ry,rz = unpack(crumb.rot);
                rAngle = math.atan2(rx,rz);
              --local nx = dx * math.cos(rAngle) - dz * math.sin(rAngle);
                local nz = dx * math.sin(rAngle) + dz * math.cos(rAngle);
                --AutoFollow:log(4, string.format("Follow: dist=%f, dxdz=%f/%f, rot=%f/%f/%f, angle=%f, nxnz=%f/%f", dist, dx,dz, rx,ry,rz, rAngle, nx,nz));
                if (dist < 3) or (nz < 0) then
                    -- Go to next crumb
                    self.afFollowCurrentIndex = self.afFollowCurrentIndex + 1;
                    crumb = self.afFollowVehicleObj.afDropperCircularArray[1+((self.afFollowCurrentIndex-1) % AutoFollow.cBreadcrumbsMaxEntries)];
                    --AutoFollow:log(3, string.format("Next crumb:%d(%d)", self.afFollowCurrentIndex, 1+((self.afFollowCurrentIndex-1) % AutoFollow.cBreadcrumbsMaxEntries)));
                elseif dist > 50 then
                    AutoFollow:log(2, "Too far away from next waypoint. Stopping auto-follow.");
                    AutoFollow.stopAutoFollow(self);
                    return;
                end;
            end;
        end;
    end;
    --
    if not allowedToDrive then
        AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 30, allowedToDrive, moveForwards, 0, 1);
    else
        if crumb ~= nil then
            -- Try to adjust the speed, without going too deep into how the VehicleMotor works
            -- This code needs some tweaking, so it does not change speedlevel quickly 1->3, 3->1, 1->3, etc.
            local speedLevel = self.motor.speedLevel;
            if self.lastSpeed < (crumb.lastSpeed * 0.95) then
                speedLevel = Utils.clamp(1 + speedLevel, 1, 3);
            elseif self.lastSpeed > (crumb.lastSpeed * 1.05) then
                speedLevel = Utils.clamp(speedLevel - 1, 1, 3);
            end;
            --            
            local lx,lz = AIVehicleUtil.getDriveDirection(self.components[1].node, crumb.trans[1],crumb.trans[2],crumb.trans[3]);
            AIVehicleUtil.driveInDirection(self, dt, 30, acceleration, 1.0, 30, allowedToDrive, moveForwards, lx, lz, speedLevel, 1);
        else
            AutoFollow:log(2, "crumb == nil. Stopping auto-follow.");
            AutoFollow.stopAutoFollow(self);
        end;
    end;
end;

function AutoFollow.startAutoFollow(self, noEventSend)
--  if noEventSend == nil or noEventSend == false then
--      if g_server ~= nil then
--          g_server:broadcastEvent(AITractorSetStartedEvent:new(self, true), nil, nil, self);
--      else
--          g_client:getServerConnection():sendEvent(AITractorSetStartedEvent:new(self, true));
--      end;
--  end;

-- FS2011
    if self.aiTrafficCollisionTrigger == nil then
        AutoFollow.setWarning(self, "AutoFollowMissingTrafficCollisionTrigger");
        return;
    end;
--]]    
    
    if self.afFollowVehicleObj ~= nil then
        AutoFollow.setWarning(self, "AutoFollowActive");
        return;
    end;

    --
    local wx,wy,wz = getWorldTranslation(self.components[1].node);
    local rx,ry,rz = localDirectionToWorld(self.components[1].node, 0,0,1);
    local rlength = Utils.vector2Length(rx,rz);
    local rotDeg = math.deg(math.atan2(rx/rlength,rz/rlength));
    local rotRad = Utils.degToRad(rotDeg-45.0);
    --AutoFollow:log(2, string.format("getWorldTranslation:%f/%f/%f - localDirectionToWorld:%f/%f/%f - rDeg:%f - rRad:%f", wx,wy,wz, rx,ry,rz, rotDeg, rotRad));

    -- Find closest vehicle, that is in front of self.
    local closestDistance = 50;
    for _,vehicleObj in pairs(g_currentMission.steerables) do
        if vehicleObj.afDropperCircularArray ~= nil and vehicleObj.afStalkerVehicleObj == nil then -- Make sure other vehicle has circular array, and is not already stalked.
            local vx,vy,vz = getWorldTranslation(vehicleObj.components[1].node);
            local dx,dz = vx-wx, vz-wz;
            local dist = Utils.vector2Length(dx,dz);
            if (dist < closestDistance) then
                -- Rotate to see if vehicleObj is "in front of us"
                local nx = dx * math.cos(rotRad) - dz * math.sin(rotRad);
                local nz = dx * math.sin(rotRad) + dz * math.cos(rotRad);
                if (nx > 0) and (nz > 0) then
                    closestDistance = dist;
                    self.afFollowVehicleObj = vehicleObj;
                end;
            end;
        end;
    end;

    if self.afFollowVehicleObj == nil then
        AutoFollow.setWarning(self, "AutoFollowDropperNotFound");
        return;
    end;

    -- Find closest "breadcrumb"
    self.afFollowCurrentIndex = 0;
    local closestDistance = 50;
    for i=self.afFollowVehicleObj.afDropperCurrentIndex, math.max(self.afFollowVehicleObj.afDropperCurrentIndex - AutoFollow.cBreadcrumbsMaxEntries,1), -1 do
        local crumb = self.afFollowVehicleObj.afDropperCircularArray[1+((i-1) % AutoFollow.cBreadcrumbsMaxEntries)];
        if crumb ~= nil then
            local x,y,z = unpack(crumb.trans);
            -- Translate
            local dx,dz = x-wx, z-wz;
            local dist = Utils.vector2Length(dx,dz);
            --local r = Utils.getYRotationFromDirection(dx,dz);
            --AutoFollow:log(3, string.format("#%d - xz:%f/%f - dxdz:%f/%f - r:%f - dist:%f", i, x,z, dx,dz, r, dist));
            if (dist > 4) and (dist < closestDistance) then
                -- Rotate to see if the point is "in front of us"
                local nx = dx * math.cos(rotRad) - dz * math.sin(rotRad);
                local nz = dx * math.sin(rotRad) + dz * math.cos(rotRad);
                if (nx > 0) and (nz > 0) then
                    --AutoFollow:log(3, string.format("#%d - xz:%f/%f - dxdz:%f/%f - dist:%f - nxnz:%f/%f", i, x,z, dx,dz, dist, nx,nz));
                    closestDistance = dist;
                    self.afFollowCurrentIndex = i;
                end;
            end;
        end;
    end;
    AutoFollow:log(2, string.format("ClosestDist:%f, index:%d", closestDistance, self.afFollowCurrentIndex));
    --
    if self.afFollowCurrentIndex == 0 then
        self.afFollowVehicleObj = nil;
        AutoFollow.setWarning(self, "AutoFollowDropperNotFound");
        return;
    end;
    
    -- Chain with leading vehicle.
    self.afFollowVehicleObj.afStalkerVehicleObj = self;
    --
-- FS2011    
    self.numCollidingVehicles = 0;
    if (self.onTrafficCollisionTrigger ~= nil) then
        addTrigger(self.aiTrafficCollisionTrigger, "onTrafficCollisionTrigger", self);
    else
        addTrigger(self.aiTrafficCollisionTrigger, "afOnTrafficCollisionTrigger", self);
    end;
--]]    
    --
    if (self.hire ~= nil) then
        -- Use the Hirable specialization's functionality
        self:hire();
    else
        -- Copied from Hirable, for the mods that do not include that specialization in their vehicle-type.
        self.forceIsActive = true;
        self.stopMotorOnLeave = false;
        self.steeringEnabled = false;
        self.deactivateOnLeave = false;
        self.disableCharacterOnLeave = false;
    end;
    --
end;

function AutoFollow.stopAutoFollow(self, noEventSend)
--  if noEventSend == nil or noEventSend == false then
--      if g_server ~= nil then
--          g_server:broadcastEvent(AITractorSetStartedEvent:new(self, false));
--      else
--          g_client:getServerConnection():sendEvent(AITractorSetStartedEvent:new(self, false));
--      end;
--  end;

    -- Unchain with leading vehicle.
    assert(self.afFollowVehicleObj.afStalkerVehicleObj == self);
    self.afFollowVehicleObj.afStalkerVehicleObj = nil;
    --
    self.afFollowVehicleObj = nil;
    self.afFollowCurrentIndex = 0;

    --
    if (self.dismiss ~= nil) then
        -- Use the Hirable specialization's functionality
        self:dismiss();
    else
      -- Copied from Hirable, for the mods that do not include that specialization in their vehicle-type.
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
    end;
    
    self.motor:setSpeedLevel(0, false);
    self.motor.maxRpmOverride = nil;

    WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeed, 0, false, self.requiredDriveMode);
    
-- FS2011
    if self.aiTrafficCollisionTrigger ~= nil then
        removeTrigger(self.aiTrafficCollisionTrigger);
    end;
--]]            
end;

-- Copied from AITractor. Used in case the vehicle-type does not have AITractor or AICombine.
function AutoFollow.afOnTrafficCollisionTrigger(self, triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if onEnter or onLeave then
        if otherId == g_currentMission.player.rootNode then
            if onEnter then
                self.numCollidingVehicles = self.numCollidingVehicles+1;
            elseif onLeave then
                self.numCollidingVehicles = math.max(self.numCollidingVehicles-1, 0);
            end;
        else
            local vehicle = g_currentMission.nodeToVehicle[otherId];
            if vehicle ~= nil --[[and self.trafficCollisionIgnoreList[otherId] == nil]] then
                if onEnter then
                    self.numCollidingVehicles = self.numCollidingVehicles+1;
                elseif onLeave then
                    self.numCollidingVehicles = math.max(self.numCollidingVehicles-1, 0);
                end;
            end;
        end;
    end;
end;


function AutoFollow.draw(self)
    if self.afShowWarningTime > g_currentMission.time then
        g_currentMission:addWarning(self.afShowWarningText, 0.07+0.022, 0.019+0.029);
    end;

    --if self.afDroppingActive then
    --    setTextBold(false);
    --    setTextColor(1,1,1,1);
    --    setTextAlignment(RenderText.ALIGN_CENTER);
    --    renderText(0.5, 0.025, 0.023, string.format(g_i18n:getText("AutoFollowActiveDrops"), AutoFollow.gBreadcrumbsFollowers)); -- TODO, make screen X/Y position configurable
    --    setTextAlignment(RenderText.ALIGN_LEFT);
    --elseif self.afFollowingActive then
    --    setTextBold(false);
    --    setTextColor(1,1,1,1);
    --    setTextAlignment(RenderText.ALIGN_CENTER);
    --    renderText(0.5, 0.025, 0.023, g_i18n:getText("AutoFollowActiveFollowing")); -- TODO, make screen X/Y position configurable
    --    setTextAlignment(RenderText.ALIGN_LEFT);
    --end;

--    if self.afHudVisible then
--        AutoFollow.afHudOverlay:render();
--    end;
    --
    if g_currentMission.showHelpText then
        --if (hasKeyModifierPressed(AutoFollow.inputbindingmodifierAutoFollowLead)) then
        --    g_currentMission:addHelpButtonText(g_i18n:getText("AutoFollowLead"), InputBinding.AutoFollowLead);
        --end;
        if (hasKeyModifierPressed(AutoFollow.inputbindingmodifierAutoFollowDrive)) then
            g_currentMission:addHelpButtonText(g_i18n:getText("AutoFollowDrive"), InputBinding.AutoFollowDrive);
        end;
    end;
end;

--
Steerable.load        = Utils.appendedFunction(Steerable.load,          AutoFollow.load);
Steerable.delete      = Utils.appendedFunction(Steerable.delete,        AutoFollow.delete);
Steerable.update      = Utils.prependedFunction(Steerable.update,       AutoFollow.update);
Steerable.updateTick  = Utils.appendedFunction(Steerable.updateTick,    AutoFollow.updateTick);
Steerable.draw        = Utils.appendedFunction(Steerable.draw,          AutoFollow.draw);

--
print("Script loaded: AutoFollow.lua (v0.54 beta)");
