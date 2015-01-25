--
-- add specialization to all mods.
--
--
-- @author:     Xentro (www.fs-uk.com)(Marcus@Xentro.se)
-- @version:    v1.0
-- @date:       2012-11-11
-- @history:    v1.0 - inital implementation
--
-- @edit:       2013-December, Decker_MMIV - Modified for FollowMe, so FollowMe will work with MoreRealistic in multiplayer.
--

addSpecialization = {};
addSpecialization.g_currentModDirectory = g_currentModDirectory;

if SpecializationUtil.specializations["FollowMe"] == nil then
    SpecializationUtil.registerSpecialization("FollowMe", "FollowMe", g_currentModDirectory .. "FollowMe.lua")
    addSpecialization.isLoaded = false;
end;

addModEventListener(addSpecialization);

function addSpecialization:loadMap(name)
    if false == addSpecialization.isLoaded then
        addSpecialization.isLoaded = true;
        addSpecialization:add();
        -- ... removeModEventListener ... (This mod has no need for calling update/draw/etc., after the very first initialization.)
        for i,listener in ipairs(g_modEventListeners) do
            if listener == addSpecialization then
                g_modEventListeners[i] = nil;
                break;
            end;
        end;
    end;
end;

function addSpecialization:deleteMap()
end;

function addSpecialization:mouseEvent(posX, posY, isDown, isUp, button)
end;

function addSpecialization:keyEvent(unicode, sym, modifier, isDown)
end;

function addSpecialization:update(dt)
end;

function addSpecialization:draw()
end;

function addSpecialization:add()
    local searchTable = {
        "FollowMe",
        };

    -- Make code work for both FS2013 and FS15.
    local requiredSpecialization = "steerable" -- FS2013
    if SpecializationUtil.getSpecialization("drivable") ~= nil then
        requiredSpecialization = "drivable" -- FS15
    end

    --
    for k, v in pairs(VehicleTypeUtil.vehicleTypes) do
        local modName = string.match(k, "([^.]+)");
        
        local addSpecialization = true;
        for _, search in pairs(searchTable) do
            if SpecializationUtil.specializations[modName .. "." .. search] ~= nil then
                addSpecialization = false;
                break;
            end;
        end;
        
        if SpecializationUtil.hasSpecialization(FollowMe, v.specializations) then
            addSpecialization = false;
            break;
        end;
        
        local correctLocation = false;
        for i = 1, table.maxn(v.specializations) do
            local vs = v.specializations[i];
            if vs ~= nil and vs == SpecializationUtil.getSpecialization(requiredSpecialization) then
                correctLocation = true;
                break;
            end;
        end;
        
        if addSpecialization and correctLocation then
            table.insert(v.specializations, SpecializationUtil.getSpecialization("FollowMe"));
        end;
    end;

    -- Copy this mod's localization texts to global table - and hope they are unique enough, so not overwriting existing ones.
    for textName,textValue in pairs(g_i18n.texts) do
        g_i18n.globalI18N.texts[textName] = textValue
    end
end;
