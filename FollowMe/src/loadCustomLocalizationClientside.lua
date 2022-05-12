--
--  Loading client-side/local custom localization XML-file for mod.
--
-- @author  Decker_MMIV (DCK)
-- @contact forum.farming-simulator.com
-- @date    2022-04-xx
--

function loadCustomL10nClientside(languageShort)
    if nil ~= g_dedicatedServer then
        return
    end
    if nil == g_currentModSettingsDirectory then
        print("Warning: Required variable for 'modSettings'-folder not set. Unable to load custom localization file for mod: " .. g_currentModName)
        return
    end

    local l10nFilenames = {}

    local modDescXML = XMLFile.loadIfExists("modDescXML", Utils.getFilename("modDesc.xml", g_currentModDirectory))
    if nil ~= modDescXML then
        local l10nFilenamePrefix = modDescXML:getString("modDesc.l10n#filenamePrefix")
        modDescXML:delete()

        if nil ~= l10nFilenamePrefix and "" ~= l10nFilenamePrefix then
            table.insert(l10nFilenames, l10nFilenamePrefix .. "_" .. languageShort .. ".xml")
            table.insert(l10nFilenames, l10nFilenamePrefix .. ".xml")
        end
    end

    -- Besides the filename-prefix (in case it was not specified), then also look for these filenames
    table.insert(l10nFilenames, "l10n_" .. languageShort .. ".xml")
    table.insert(l10nFilenames, "l10n.xml")
    table.insert(l10nFilenames, "localization_" .. languageShort .. ".xml")
    table.insert(l10nFilenames, "localization.xml")

    for _,filename in ipairs(l10nFilenames) do
        local l10nFilename = Utils.getFilename(filename, g_currentModSettingsDirectory)
        local l10nXML = XMLFile.loadIfExists("l10nXML", l10nFilename)
        if nil == l10nXML then
            --print("Did not find/load custom localization file: " .. l10nFilename)
        else
            print("Reading entries from custom localization file: " .. l10nFilename)
            local idx = 0
            while true do
                local key = string.format("l10n.texts.text(%d)", idx)
                if not l10nXML:hasProperty(key) then
                    break
                end

                local name = l10nXML:getString(key .. "#name")
                local text = l10nXML:getString(key .. "#text")

                if nil ~= name and nil ~= text then
                    if name:sub(1,6) == "input_" then
                        -- Looks like an input-action's name, so dig into g_inputBinding's tables and overwrite its displayName if the action-name exist.
                        local nameAction = name:sub(7)
                        local nameSuffix = name:sub(-2)
                        local actionAxis = 0
                        if nameSuffix == "_1" then
                            actionAxis = 1
                        elseif nameSuffix == "_2" then
                            actionAxis = -1
                        end
                        if 0 ~= actionAxis then
                            nameAction = nameAction:sub(1, #nameAction - 2)
                        end
                        if nil ~= g_inputBinding.nameActions then
                            local inputBindingNameActionObj = g_inputBinding.nameActions[nameAction]
                            if nil ~= inputBindingNameActionObj then
                                if actionAxis == -1 and nil ~= inputBindingNameActionObj.displayNameNegative then
                                    inputBindingNameActionObj.displayNameNegative = text
                                elseif nil ~= inputBindingNameActionObj.displayNamePositive then
                                    inputBindingNameActionObj.displayNamePositive = text
                                end
                            end
                        end
                    else
                        g_i18n:setText(name, text:gsub("\r\n", "\n"))
                    end
                end

                idx = idx + 1
            end
            l10nXML:delete()
            break -- Only read one file.
        end
    end
end

loadCustomL10nClientside(g_languageShort)
