local ADDON_NAME, Internal = ...;
local L = Internal.L;

local HelpTipBox_Anchor = Internal.HelpTipBox_Anchor;
local HelpTipBox_SetText = Internal.HelpTipBox_SetText;

local format = string.format
local sort = table.sort

local GetCharacterSlug = Internal.GetCharacterSlug

-- A map from the equipment manager ids to our sets
local equipmentSetMap = {};

local frame = CreateFrame("Frame");
frame:SetScript("OnEvent", function (self, event, ...)
    self[event](self, ...);
end);
function frame:ADDON_LOADED(...)
    if ... == ADDON_NAME then
        BtWLoadoutsSettings = BtWLoadoutsSettings or {};
        Internal.Settings(BtWLoadoutsSettings);

        Internal.UpdateClassInfo();

        BtWLoadoutsSets = BtWLoadoutsSets or {
            profiles = {},
            talents = {},
            pvptalents = {},
            essences = {},
            equipment = {},
            actionbars = {},
            conditions = {},
        };
        BtWLoadoutsSets.actionbars = BtWLoadoutsSets.actionbars or {}

        for _,sets in pairs(BtWLoadoutsSets) do
            for setID,set in pairs(sets) do
                if type(set) == "table" then
                    set.setID = setID;
                    set.useCount = 0;

                    -- Refresh filtering
                    set.filters = set.filters or {}
                    if set.character then
                        set.filters.character = set.character
                        local characterInfo = Internal.GetCharacterInfo(set.character)
                        if characterInfo then
                            set.filters.class = characterInfo.class
                        end
                    end
                    if set.specID then
                        set.filters.spec = set.specID
                        set.filters.role, set.filters.class = select(5, GetSpecializationInfoByID(set.specID))

                        if not set.filters.character then
                            local characters = {}
                            local class = set.filters.class
                            for _,character in Internal.CharacterIterator() do
                                if class == Internal.GetCharacterInfo(character).class then
                                    characters[#characters+1] = character
                                end
                            end
                            set.filters.character = characters
                        end
                    end
                    if set.role then
                        set.filters.role = set.role

                        if not set.filters.character then
                            local characters = {}
                            local role = set.filters.role
                            for _,character in Internal.CharacterIterator() do
                                if Internal.IsClassRoleValid(Internal.GetCharacterInfo(character).class, role) then
                                    characters[#characters+1] = character
                                end
                            end
                            set.filters.character = characters
                        end
                    end
                end
            end
        end
        for setID,set in pairs(BtWLoadoutsSets.equipment) do
            if type(set) == "table" then
                set.extras = set.extras or {};
                set.locations = set.locations or {};
            end
        end
        for setID,set in pairs(BtWLoadoutsSets.profiles) do
            if type(set) == "table" then
                -- Convert from version 1 to version 2 loadouts
                if set.version == nil then
                    set.talents = {set.talentSet}
                    set.talentSet = nil

                    set.pvptalents = {set.pvpTalentSet}
                    set.pvpTalentSet = nil

                    set.essences = {set.essencesSet}
                    set.essencesSet = nil

                    set.equipment = {set.equipmentSet}
                    set.equipmentSet = nil

                    set.actionbars = {set.actionBarSet}
                    set.actionBarSet = nil

                    set.version = 2
                end

                set.character = nil -- Loadouts are no longer character restricted

                for _,subsetID in ipairs(set.talents) do
                    if BtWLoadoutsSets.talents[subsetID] then
                        BtWLoadoutsSets.talents[subsetID].useCount = BtWLoadoutsSets.talents[subsetID].useCount + 1;
                    end
                end

                for _,subsetID in ipairs(set.pvptalents) do
                    if BtWLoadoutsSets.pvptalents[subsetID] then
                        BtWLoadoutsSets.pvptalents[subsetID].useCount = BtWLoadoutsSets.pvptalents[subsetID].useCount + 1;
                    end
                end

                for _,subsetID in ipairs(set.essences) do
                    if BtWLoadoutsSets.essences[subsetID] then
                        BtWLoadoutsSets.essences[subsetID].useCount = BtWLoadoutsSets.essences[subsetID].useCount + 1;
                    end
                end

                for _,subsetID in ipairs(set.equipment) do
                    if BtWLoadoutsSets.equipment[subsetID] then
                        BtWLoadoutsSets.equipment[subsetID].useCount = BtWLoadoutsSets.equipment[subsetID].useCount + 1;
                    end
                end

                for _,subsetID in ipairs(set.actionbars) do
                    if BtWLoadoutsSets.actionbars[subsetID] then
                        BtWLoadoutsSets.actionbars[subsetID].useCount = BtWLoadoutsSets.actionbars[subsetID].useCount + 1;
                    end
                end
            end
        end
        for setID,set in pairs(BtWLoadoutsSets.conditions) do
            if type(set) == "table" then
                if set.profileSet and BtWLoadoutsSets.profiles[set.profileSet] then
                    BtWLoadoutsSets.profiles[set.profileSet].useCount = BtWLoadoutsSets.profiles[set.profileSet].useCount + 1;
                end
            end
        end

        BtWLoadoutsSpecInfo = BtWLoadoutsSpecInfo or {};
        BtWLoadoutsRoleInfo = BtWLoadoutsRoleInfo or {};
        BtWLoadoutsEssenceInfo = BtWLoadoutsEssenceInfo or {};
        BtWLoadoutsCharacterInfo = BtWLoadoutsCharacterInfo or {};
        BtWLoadoutsCollapsed = BtWLoadoutsCollapsed or {
            profiles = {},
            talents = {},
            pvptalents = {},
            essences = {},
            equipment = {},
            actionbars = {},
            conditions = {},
        };
        BtWLoadoutsCollapsed.actionbars = BtWLoadoutsCollapsed.actionbars or {}
        BtWLoadoutsCollapsed.conditions = BtWLoadoutsCollapsed.conditions or {}
        BtWLoadoutsCategories = BtWLoadoutsCategories or {
            profiles = {"spec"},
            talents = {"spec"},
            pvptalents = {"spec"},
            essences = {"role"},
            equipment = {"character"},
            actionbars = {},
            conditions = {},
        };
        BtWLoadoutsFilters = BtWLoadoutsFilters or {
            profiles = {},
            talents = {},
            pvptalents = {},
            essences = {},
            equipment = {},
            actionbars = {},
            conditions = {},
        };

        BtWLoadoutsHelpTipFlags = BtWLoadoutsHelpTipFlags or {};

        if not BtWLoadoutsHelpTipFlags["MINIMAP_ICON"] then
            BtWLoadoutsMinimapButton.FirstTimeAnim:Play();
        end
    end
end
function frame:PLAYER_LOGIN(...)
    Internal.CreateLauncher();
    Internal.CreateLauncherMinimapIcon();

    frame:RegisterEvent("PLAYER_TALENT_UPDATE");

    do
        local character = GetCharacterSlug();
        for setID,set in pairs(BtWLoadoutsSets.equipment) do
            if type(set) == "table" and set.character == character and set.managerID ~= nil then
                if equipmentSetMap[set.managerID] then
                    set.managerID = nil;
                else
                    equipmentSetMap[set.managerID] = set;
                end
            end
        end
    end

    for _,set in pairs(BtWLoadoutsSets.conditions) do
        if type(set) == "table" then
            if set.difficultyID ~= 8 then
                set.map.affixesID = nil
                set.map.affixID1 = nil
                set.map.affixID2 = nil
                set.map.affixID3 = nil
                set.map.affixID4 = nil
            end
            -- Fix to remove the season affix from condition mapping
            if set.map.affixesID ~= nil then
                if set.affixesID then
                    local affixID1, affixID2, affixID3, affixID4 = Internal.GetAffixesForID(set.affixesID)

                    set.map.affixID1 = (affixID1 ~= 0 and affixID1 or nil)
                    set.map.affixID2 = (affixID2 ~= 0 and affixID2 or nil)
                    set.map.affixID3 = (affixID3 ~= 0 and affixID3 or nil)
                    set.map.affixID4 = (affixID4 ~= 0 and affixID4 or nil)
                end

                set.map.affixesID = nil
            end

            -- Fixes an issue where conditions could be left with a missing loadout
            if set.profileSet and Internal.GetProfile(set.profileSet) == nil then
                set.profileSet = nil
            end

			if not set.disabled then
                Internal.AddConditionToMap(set);
            end
        end
    end

    if C_EquipmentSet.GetNumEquipmentSets() > 0 then
        self:EQUIPMENT_SETS_CHANGED();
    end
end
function frame:PLAYER_ENTERING_WORLD()
    for specIndex=1,GetNumSpecializations() do
        local specID = GetSpecializationInfo(specIndex);
        local spec = BtWLoadoutsSpecInfo[specID] or {talents = {}};
        spec.talents = spec.talents or {};
        local talents = spec.talents;
        for tier=1,MAX_TALENT_TIERS do
            local tierItems = talents[tier] or {};

            for column=1,3 do
                local talentID = GetTalentInfoBySpecialization(specIndex, tier, column);
                tierItems[column] = talentID;
            end

            talents[tier] = tierItems;
        end

        BtWLoadoutsSpecInfo[specID] = spec;
    end

    do
        local specID = GetSpecializationInfo(GetSpecialization());
        local spec = BtWLoadoutsSpecInfo[specID] or {};
        spec.pvptalenttrinkets = spec.pvptalenttrinkets or {};
        wipe(spec.pvptalenttrinkets);
        local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(1);
        if slotInfo then
            local availableTalentIDs = slotInfo.availableTalentIDs;
            for index,talentID in ipairs(availableTalentIDs) do
                spec.pvptalenttrinkets[index] = talentID;
            end
        end

        spec.pvptalents = spec.pvptalents or {};
        wipe(spec.pvptalents);
        local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(2);
        if slotInfo then
            local availableTalentIDs = slotInfo.availableTalentIDs;
            for index,talentID in ipairs(availableTalentIDs) do
                spec.pvptalents[index] = talentID;
            end
        end

        spec.pvptalentslots = spec.pvptalentslots or {};
        wipe(spec.pvptalentslots);
        do
            local index = 1
            local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(index)
            while slotInfo do
                spec.pvptalentslots[index] = slotInfo

                index = index + 1
                slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(index)
            end
        end

        BtWLoadoutsSpecInfo[specID] = spec;
    end

    do
        local essences = C_AzeriteEssence.GetEssences();
        if essences ~= nil then
            local roleID = select(5, GetSpecializationInfo(GetSpecialization()));
            local role = BtWLoadoutsRoleInfo[roleID] or {};

            role.essences = role.essences or {};
            wipe(role.essences);

            sort(essences, function (a,b)
                return a.name < b.name;
            end);
            for _,essence in ipairs(essences) do
                if essence.valid then
                    role.essences[#role.essences+1] = essence.ID;
                end

                local essenceInfo = BtWLoadoutsEssenceInfo[essence.ID] or {};
                wipe(essenceInfo);
                essenceInfo.ID = essence.ID;
                essenceInfo.name = essence.name;
                essenceInfo.icon = essence.icon;

                BtWLoadoutsEssenceInfo[essence.ID] = essenceInfo;
            end

            BtWLoadoutsRoleInfo[roleID] = role;
        end
    end

    Internal.UpdatePlayerInfo();
    Internal.UpdateAreaMap();

    -- Run conditions for instance info
    do
        Internal.UpdateConditionsForInstance();
		local bossID = Internal.UpdateConditionsForBoss();
        Internal.UpdateConditionsForAffixes();
        -- Boss is unavailable so dont trigger conditions
        if bossID and not Internal.BossAvailable(bossID) then
            return
        end
        Internal.TriggerConditions();
    end

    Internal.UpdateLauncher(Internal.GetActiveProfiles());
end
function frame:EQUIPMENT_SETS_CHANGED(...)
    -- Update our saved equipment sets to match the built in equipment sets
    local oldEquipmentSetMap = equipmentSetMap;
    equipmentSetMap = {};

    local managerIDs = C_EquipmentSet.GetEquipmentSetIDs();
    for _,managerID in ipairs(managerIDs) do
        local set = oldEquipmentSetMap[managerID];
        if set == nil then
            set = Internal.AddBlankEquipmentSet();
        end

        set.managerID = managerID;
        set.name = C_EquipmentSet.GetEquipmentSetInfo(managerID);

        local ignored = C_EquipmentSet.GetIgnoredSlots(managerID);
        local locations = C_EquipmentSet.GetItemLocations(managerID);
        for inventorySlotId=INVSLOT_FIRST_EQUIPPED,INVSLOT_LAST_EQUIPPED do
            set.ignored[inventorySlotId] = ignored[inventorySlotId] and true or nil;

            if locations then -- Seems in some situations the locations table is nil instead
                local location = locations[inventorySlotId] or 0;
                if location > -1 then -- If location is -1 we ignore it as we cant get the item link for the item
                    set.equipment[inventorySlotId] = Internal.GetItemLinkByLocation(location);
                end
            end
        end

        equipmentSetMap[managerID] = set;
        oldEquipmentSetMap[managerID] = nil;
    end

    -- If a set previously managed by the blizzard manager is deleted
    -- we delete our set unless its in use, then we just disconnect it from
    -- the blizzard manager
    for managerID,set in pairs(oldEquipmentSetMap) do
        if set.managerID == managerID then
            if set.useCount > 0 then
                set.managerID = nil;
            else
                Internal.DeleteEquipmentSet(set)
            end
        end
    end

    BtWLoadoutsFrame:Update();
    Internal.UpdateLauncher(Internal.GetActiveProfiles());
end
function frame:PLAYER_SPECIALIZATION_CHANGED(...)
    do
        local specID = GetSpecializationInfo(GetSpecialization());
        local spec = BtWLoadoutsSpecInfo[specID] or {};

        spec.pvptalenttrinkets = spec.pvptalenttrinkets or {};
        wipe(spec.pvptalenttrinkets);
        local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(1);
        if slotInfo then
            local availableTalentIDs = slotInfo.availableTalentIDs;
            for index,talentID in ipairs(availableTalentIDs) do
                spec.pvptalenttrinkets[index] = talentID;
            end
        end

        spec.pvptalents = spec.pvptalents or {};
        wipe(spec.pvptalents);
        local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(2);
        if slotInfo then
            local availableTalentIDs = slotInfo.availableTalentIDs;
            for index,talentID in ipairs(availableTalentIDs) do
                spec.pvptalents[index] = talentID;
            end
        end

        BtWLoadoutsSpecInfo[specID] = spec;
    end
    Internal.UpdateLauncher(Internal.GetActiveProfiles());
end
function frame:UPDATE_INSTANCE_INFO(...)
    local name, realm = UnitFullName("player")
    if not realm then
        return
    end
    
    Internal.UpdateConditionsForInstance();
    local bossID = Internal.UpdateConditionsForBoss();
    -- Boss is unavailable so dont trigger conditions
    if bossID and not Internal.BossAvailable(bossID) then
        return
    end
    Internal.TriggerConditions();
end
function frame:ZONE_CHANGED(...)
    local bossID = Internal.UpdateConditionsForBoss();
    -- Boss is unavailable so dont trigger conditions
    if bossID and not Internal.BossAvailable(bossID) then
        return
    end
    Internal.TriggerConditions();
end
function frame:UPDATE_MOUSEOVER_UNIT(...)
    local bossID = Internal.UpdateConditionsForBoss("mouseover");
    -- Boss is unavailable so dont trigger conditions
    if bossID and not Internal.BossAvailable(bossID) then
        return
    end
    Internal.TriggerConditions();
end
function frame:NAME_PLATE_UNIT_ADDED(...)
    local bossID = Internal.UpdateConditionsForBoss(...);
    -- Boss is unavailable so dont trigger conditions
    if bossID and not Internal.BossAvailable(bossID) then
        return
    end
    Internal.TriggerConditions();
end
function frame:PLAYER_TARGET_CHANGED(...)
    local bossID = Internal.UpdateConditionsForBoss("target");
    -- Boss is unavailable so dont trigger conditions
    if bossID and not Internal.BossAvailable(bossID) then
        return
    end
    Internal.TriggerConditions();
end
function frame:PLAYER_TALENT_UPDATE(...)
    Internal.UpdateLauncher(Internal.GetActiveProfiles());
end
function frame:ENCOUNTER_END(...)
    -- We dont trigger events during an encounter so we retrigger things after an encounter ends
    local bossID = Internal.UpdateConditionsForBoss();
    -- Boss is unavailable so dont trigger conditions
    if bossID and not Internal.BossAvailable(bossID) then
        return
    end
    Internal.TriggerConditions();
end
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("PLAYER_LOGIN");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("EQUIPMENT_SETS_CHANGED");
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
frame:RegisterEvent("UPDATE_INSTANCE_INFO");
frame:RegisterEvent("ZONE_CHANGED");
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED");
frame:RegisterEvent("PLAYER_TARGET_CHANGED");
frame:RegisterEvent("ENCOUNTER_END");