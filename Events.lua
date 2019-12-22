local ADDON_NAME, Internal = ...;
local L = Internal.L;

local HelpTipBox_Anchor = Internal.HelpTipBox_Anchor;
local HelpTipBox_SetText = Internal.HelpTipBox_SetText;

local format = string.format
local sort = table.sort

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
                if set.talentSet then
                    BtWLoadoutsSets.talents[set.talentSet].useCount = BtWLoadoutsSets.talents[set.talentSet].useCount + 1;
                end

                if set.pvpTalentSet then
                    BtWLoadoutsSets.pvptalents[set.pvpTalentSet].useCount = BtWLoadoutsSets.pvptalents[set.pvpTalentSet].useCount + 1;
                end

                if set.essencesSet then
                    BtWLoadoutsSets.essences[set.essencesSet].useCount = BtWLoadoutsSets.essences[set.essencesSet].useCount + 1;
                end

                if set.equipmentSet then
                    BtWLoadoutsSets.equipment[set.equipmentSet].useCount = BtWLoadoutsSets.equipment[set.equipmentSet].useCount + 1;
                end

                if set.actionBarSet then
                    BtWLoadoutsSets.actionbars[set.actionBarSet].useCount = BtWLoadoutsSets.actionbars[set.actionBarSet].useCount + 1;
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
        };
        BtWLoadoutsCollapsed.actionbars = BtWLoadoutsCollapsed.actionbars or {}
        Internal.UpdateClassInfo();

        BtWLoadoutsHelpTipFlags = BtWLoadoutsHelpTipFlags or {};

        if not BtWLoadoutsHelpTipFlags["MINIMAP_ICON"] then
            BtWLoadoutsMinimapButton.PulseAlpha:Play();
        end
    end
end
function frame:PLAYER_LOGIN(...)
    Internal.CreateLauncher();

    do
        local name, realm = UnitFullName("player");
        local character = format("%s-%s", realm, name);
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
                set.map.affixesID = nil;
            end
            -- Fix to remove the season affix from condition mapping
            if set.map.affixesID ~= nil then
                set.map.affixesID = bit.band(set.map.affixesID, 0x00ffffff)
            end

            Internal.AddConditionToMap(set);
        end
    end

    self:EQUIPMENT_SETS_CHANGED();
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
        Internal.UpdateConditionsForBoss();
        Internal.UpdateConditionsForAffixes();
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

            local location = locations[inventorySlotId] or 0;
            if location > -1 then -- If location is -1 we ignore it as we cant get the item link for the item
                set.equipment[inventorySlotId] = Internal.GetItemLinkByLocation(location);
            end
        end

        equipmentSetMap[managerID] = set;
        oldEquipmentSetMap[managerID] = nil;
    end

    for managerID,set in pairs(oldEquipmentSetMap) do
        if set.managerID == managerID then
            set.managerID = nil;
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
function frame:ZONE_CHANGED(...)
    Internal.UpdateConditionsForBoss();
    Internal.TriggerConditions();
end
function frame:UPDATE_MOUSEOVER_UNIT(...)
    Internal.UpdateConditionsForBoss("mouseover");
    Internal.TriggerConditions();
end
function frame:NAME_PLATE_UNIT_ADDED(...)
    Internal.UpdateConditionsForBoss(...);
    Internal.TriggerConditions();
end
function frame:PLAYER_TARGET_CHANGED(...)
    Internal.UpdateConditionsForBoss("target");
    Internal.TriggerConditions();
end
function frame:PLAYER_TALENT_UPDATE(...)
    Internal.UpdateLauncher(Internal.GetActiveProfiles());
end
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("PLAYER_LOGIN");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("EQUIPMENT_SETS_CHANGED");
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
frame:RegisterEvent("ZONE_CHANGED");
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED");
frame:RegisterEvent("PLAYER_TARGET_CHANGED");
frame:RegisterEvent("PLAYER_TALENT_UPDATE");