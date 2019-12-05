local ADDON_NAME,Internal = ...
local L = Internal.L

-- Maps condition flags to condition groups
local conditionMap = {
	instanceType = {},
	difficultyID = {},
	instanceID = {},
	bossID = {},
	affixesID = {},
};
_G['BtWLoadoutsConditionMap'] = conditionMap; --@TODO Remove
local function ActivateConditionMap(map, key)
	if key ~= nil and map[key] ~= nil then
		local tbl = map[key];
		for k,v in pairs(tbl) do
			tbl[k] = true;
		end
	end
end
local function DeactivateConditionMap(map, key)
	if key ~= nil and map[key] ~= nil then
		local tbl = map[key];
		for k,v in pairs(tbl) do
			tbl[k] = false;
		end
	end
end
local function AddConditionToMap(set)
	if set.profileSet ~= nil then
		local profile = GetProfile(set.profileSet);
		local valid = select(5, IsProfileValid(profile));
		if valid then
			for k,v in pairs(set.map) do
				conditionMap[k][v] = conditionMap[k][v] or {};
				conditionMap[k][v][set] = false;
			end
		end
	end
end
local function RemoveConditionFromMap(set)
	for k,v in pairs(set.map) do
		conditionMap[k][v] = conditionMap[k][v] or {};
		conditionMap[k][v][set] = nil;
	end
end
local function IsConditionActive(condition)
	local matchCount = 0;
	for k,v in pairs(condition.map) do
		if not conditionMap[k][v][condition] then
			return false;
		end
		matchCount = matchCount + 1;
	end

	return matchCount;
end
local function AddConditionSet()
	local name = L["New Condition Set"];
	
    local set = {
		setID = GetNextSetID(BtWLoadoutsSets.conditions),
		name = name,
		type = CONDITION_TYPE_WORLD,
		map = {},
    };
    BtWLoadoutsSets.conditions[set.setID] = set;
    return set;
end
local function GetConditionSet(id)
    return BtWLoadoutsSets.conditions[id];
end
local function DeleteConditionSet(id)
	local set = type(id) == "table" and id or GetProfile(id);
	if set.profileSet then
		local subSet = GetProfile(set.profileSet);
		subSet.useCount = (subSet.useCount or 1) - 1;
	end
	RemoveConditionFromMap(set);

	DeleteSet(BtWLoadoutsSets.conditions, id);

	if type(id) == "table" then
		id = id.setID;
	end

	local frame = BtWLoadoutsFrame.Conditions;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil;
		BtWLoadoutsFrame:Update();
	end
end
local previousConditionInfo = {};
_G['BtWLoadoutsPreviousConditionInfo'] = previousConditionInfo; --@TODO Remove
local function UpdateConditionsForInstance()
	local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo();
	if previousConditionInfo.instanceType ~= instanceType then
		DeactivateConditionMap(conditionMap.instanceType, previousConditionInfo.instanceType);
		ActivateConditionMap(conditionMap.instanceType, instanceType);
		previousConditionInfo.instanceType = instanceType;
	end
	if previousConditionInfo.difficultyID ~= difficultyID then
		DeactivateConditionMap(conditionMap.difficultyID, previousConditionInfo.difficultyID);
		ActivateConditionMap(conditionMap.difficultyID, difficultyID);
		previousConditionInfo.difficultyID = difficultyID;
	end
	if previousConditionInfo.instanceID ~= instanceID then
		DeactivateConditionMap(conditionMap.instanceID, previousConditionInfo.instanceID);
		ActivateConditionMap(conditionMap.instanceID, instanceID);
		previousConditionInfo.instanceID = instanceID;
	end
end
local function UpdateConditionsForBoss(unitId)
	local bossID = previousConditionInfo.bossID;
	local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo();
	if instanceType == "party" or instanceType == "raid" then
		local uiMapID = C_Map.GetBestMapForUnit("player");
		if uiMapID then
			bossID = uiMapIDToBossID[uiMapID] or bossID;
		end
		local areaID = instanceID and areaNameToIDMap[instanceID] and areaNameToIDMap[instanceID][GetSubZoneText()] or nil;
		if areaID then
			bossID = InstanceAreaIDToBossID[instanceID][areaID] or bossID;
		end
		if unitId then
			local unitGUID = UnitGUID(unitId);
			if unitGUID and not UnitIsDead(unitId) then
				local type, zero, serverId, instanceId, zone_uid, npcId, spawn_uid = strsplit("-", unitGUID);
				if type == "Creature" and tonumber(npcId) then
					bossID = npcIDToBossID[tonumber(npcId)] or bossID;
				end
			end
		end
	end

	if previousConditionInfo.bossID ~= bossID then
		DeactivateConditionMap(conditionMap.bossID, previousConditionInfo.bossID);
		ActivateConditionMap(conditionMap.bossID, bossID);
		previousConditionInfo.bossID = bossID;
	end
end
local function UpdateConditionsForAffixes()
	local affixesID;
	local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo();
	if difficultyID == 23 then -- In a mythic dungeon (not M+)
		local affixes = C_MythicPlus.GetCurrentAffixes();
		if affixes then
			affixesID = GetAffixesInfo(affixes[1].id, affixes[2].id, affixes[3].id, affixes[4].id).id;
		end
	end

	if previousConditionInfo.affixesID ~= affixesID then
		DeactivateConditionMap(conditionMap.affixesID, previousConditionInfo.affixesID);
		ActivateConditionMap(conditionMap.affixesID, affixesID);
		previousConditionInfo.affixesID = affixesID;
	end
end
local function CompareConditions(a,b)
	for k,v in pairs(a) do
		if b[k] ~= v then
			return false;
		end
	end
	for k,v in pairs(b) do
		if a[k] ~= v then
			return false;
		end
	end
	return true;
end
-- Loops through conditions and checks if they are active
local conditionMatchCount = {};
local function TriggerConditions()
	-- In a Mythic Plus cant cant change anything anyway
	if select(8,GetInstanceInfo()) == 8 then
		return;
	end
	
	-- Generally speaking people wont want a popup asking to switch stuff if they are editing things
	if BtWLoadoutsFrame:IsShown() or Internal.IsActivatingLoadout() then
		return;
	end

	previousActiveConditions,activeConditions = activeConditions,previousActiveConditions;
	wipe(activeConditions);
	wipe(conditionMatchCount);
	for setID,set in pairs(BtWLoadoutsSets.conditions) do
		if type(set) == "table" and set.profileSet ~= nil then
			local profile = GetProfile(set.profileSet);
			if select(5, IsProfileValid(profile)) then
				local match = IsConditionActive(set);
				if match then
					activeConditions[profile] = set;
					conditionMatchCount[profile] = (conditionMatchCount[profile] or 0) + match;
				end
			end
		end
	end

	if CompareConditions(previousActiveConditions, activeConditions) then
		return
	end

	wipe(sortedActiveConditions);
	for profile,condition in pairs(activeConditions) do
		sortedActiveConditions[#sortedActiveConditions+1] = {
			profile = profile,
			condition = condition,
			match = conditionMatchCount[profile],
		};
	end

	if #sortedActiveConditions == 0 then
		return;
	elseif #sortedActiveConditions == 1 then
		if not IsProfileActive(sortedActiveConditions[1].profile) then
			StaticPopup_Hide("BTWLOADOUTS_REQUESTMULTIACTIVATE");
			StaticPopup_Show("BTWLOADOUTS_REQUESTACTIVATE", sortedActiveConditions[1].condition.name, nil, {
				set = sortedActiveConditions[1].profile,
				func = ActivateProfile,
			});
		end
	else
		sort(sortedActiveConditions, function(a,b)
			return a.match > b.match;
		end);

		if not conditionProfilesDropDown.initialized then
			UIDropDownMenu_SetWidth(conditionProfilesDropDown, 170);
			UIDropDownMenu_Initialize(conditionProfilesDropDown, ConditionProfilesDropDownInit);
			UIDropDownMenu_JustifyText(conditionProfilesDropDown, "LEFT");
			conditionProfilesDropDown.initialized = true;
		end

		activeConditionSelection = sortedActiveConditions[1];
		UIDropDownMenu_SetText(conditionProfilesDropDown, activeConditionSelection.condition.name);
		StaticPopup_Hide("BTWLOADOUTS_REQUESTACTIVATE");
		StaticPopup_Show("BTWLOADOUTS_REQUESTMULTIACTIVATE", nil, nil, {
			func = ActivateProfile,
		}, conditionProfilesDropDown);
	end
end

do
    local frame = BtWLoadoutsFrame.Conditions
    Internal.AddTab({
        type = "conditions",
        name = L["Conditions"],
        frame = frame,
        onInit = function ()
        end,
        onUpdate = function (self)
        end,
    })
end