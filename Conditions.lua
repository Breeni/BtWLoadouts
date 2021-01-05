local ADDON_NAME,Internal = ...
local L = Internal.L
local Settings = Internal.Settings

local GetSubZoneText = GetSubZoneText
local GetRealZoneText = GetRealZoneText
local GetInstanceInfo = GetInstanceInfo
local GetDifficultyInfo = GetDifficultyInfo
local GetCurrentAffixes = C_MythicPlus.GetCurrentAffixes
local EJ_GetEncounterInfo = EJ_GetEncounterInfo

local StaticPopup_Show = StaticPopup_Show
local StaticPopup_Hide = StaticPopup_Hide

local UIDropDownMenu_SetText = UIDropDownMenu_SetText
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_JustifyText = UIDropDownMenu_JustifyText
local UIDropDownMenu_EnableDropDown = UIDropDownMenu_EnableDropDown;
local UIDropDownMenu_DisableDropDown = UIDropDownMenu_DisableDropDown;
local UIDropDownMenu_SetSelectedValue = UIDropDownMenu_SetSelectedValue;
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo;

local sort = table.sort


local instanceBosses = Internal.instanceBosses;
local scenarioInfo = Internal.scenarioInfo;
local dungeonDifficultiesAll = Internal.dungeonDifficultiesAll;
local raidDifficultiesAll = Internal.raidDifficultiesAll;
local instanceDifficulties = Internal.instanceDifficulties;
local dungeonInfo = Internal.dungeonInfo;
local raidInfo = Internal.raidInfo;
local npcIDToBossID = Internal.npcIDToBossID;
local InstanceAreaIDToBossID = Internal.InstanceAreaIDToBossID;
local uiMapIDToBossID = Internal.uiMapIDToBossID;

local CONDITION_TYPE_WORLD = "none";
local CONDITION_TYPE_DUNGEONS = "party";
local CONDITION_TYPE_RAIDS = "raid";
local CONDITION_TYPE_ARENA = "arena";
local CONDITION_TYPE_BATTLEGROUND = "pvp";
local CONDITION_TYPE_SCENARIO = "scenario";
local CONDITION_TYPES = {
	CONDITION_TYPE_WORLD,
	CONDITION_TYPE_DUNGEONS,
	CONDITION_TYPE_RAIDS,
	CONDITION_TYPE_ARENA,
	CONDITION_TYPE_BATTLEGROUND,
	CONDITION_TYPE_SCENARIO
}
local CONDITION_TYPE_NAMES = {
	[CONDITION_TYPE_WORLD] = L["World"],
	[CONDITION_TYPE_DUNGEONS] = L["Dungeons"],
	[CONDITION_TYPE_RAIDS] = L["Raids"],
	[CONDITION_TYPE_ARENA] = L["Arena"],
	[CONDITION_TYPE_BATTLEGROUND] = L["Battlegrounds"],
	[CONDITION_TYPE_SCENARIO] = L["Scenarios"]
}

local activeConditionSelection;
local previousActiveConditions = {}; -- List of the previously active conditions
local activeConditions = {}; -- List of the currently active conditions profiles
local sortedActiveConditions = {};
local conditionProfilesDropDown = CreateFrame("FRAME", "BtWLoadoutsConditionProfilesDropDown", UIParent, "UIDropDownMenuTemplate");
local function ConditionProfilesDropDown_OnClick(self, arg1, arg2, checked)
	activeConditionSelection = arg1;
	UIDropDownMenu_SetText(conditionProfilesDropDown, arg1.condition.name);
end
local function ConditionProfilesDropDownInit(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo();

    if (level or 1) == 1 then
		for _,set in ipairs(sortedActiveConditions) do
            info.text = set.condition.name;
            info.arg1 = set;
            info.func = ConditionProfilesDropDown_OnClick;
            info.checked = activeConditionSelection == set;
            UIDropDownMenu_AddButton(info, level);
        end
    end
end
function Internal.GetAciveConditionSelection()
	return activeConditionSelection
end

-- Maps condition flags to condition groups
local conditionMap = {
	instanceType = {},
	difficultyID = {},
	instanceID = {},
	bossID = {},
	affixID1 = {},
	affixID2 = {},
	affixID3 = {},
	affixID4 = {},
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
-- As long as a set hasnt been changed it can be added multiple times
-- without causing any issues
local function AddConditionToMap(set)
	if set.profileSet ~= nil then
		local profile = Internal.GetProfile(set.profileSet);
		for k,v in pairs(set.map) do
			conditionMap[k][v] = conditionMap[k][v] or {};
			conditionMap[k][v][set] = false;
		end
	end
end
Internal.AddConditionToMap = AddConditionToMap;
local function RemoveConditionFromMap(set)
	for k,v in pairs(set.map) do
		conditionMap[k][v] = conditionMap[k][v] or {};
		conditionMap[k][v][set] = nil;
	end
end
Internal.RemoveConditionFromMap = RemoveConditionFromMap;
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
-- Update a condition set with current active conditions
local function RefreshConditionSet(set)
	local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo();

	if instanceType ~= "party" and instanceType ~= "raid" and instanceType ~= "arena" and instanceType ~= "pvp" and instanceType ~= "scenario" then
		instanceType = "none"
		difficultyID = nil
		instanceID = nil
	end

	set.type = instanceType
	set.instanceID = instanceID
	set.difficultyID = difficultyID
	set.bossID = nil
	set.affixID1 = nil
	set.affixID2 = nil
	set.affixID3 = nil
	set.affixID4 = nil
	if difficultyID == 8 then -- In M+
		local affixes = GetCurrentAffixes();
		if affixes then
			for i=1,4 do
				set["affixID" .. i] = affixes[i] and affixes[i].id or nil
			end
		end
		-- if affixes then
		-- 	-- Ignore the 4th (seasonal) affix
		-- 	set.affixesID = Internal.GetAffixesInfo(affixes[1].id, affixes[2].id, affixes[3].id).id
		-- end
	else
		set.bossID = Internal.GetCurrentBoss()
	end

	return set
end
local function AddConditionSet()
	local name = L["New Condition Set"];

    local set = {
		setID = Internal.GetNextSetID(BtWLoadoutsSets.conditions),
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
	local set = type(id) == "table" and id or Internal.GetProfile(id);
	if set.profileSet then
		local subSet = Internal.GetProfile(set.profileSet);
		subSet.useCount = (subSet.useCount or 1) - 1;
	end
	RemoveConditionFromMap(set);

	Internal.DeleteSet(BtWLoadoutsSets.conditions, id);

	if type(id) == "table" then
		id = id.setID;
	end

	local frame = BtWLoadoutsFrame.Conditions;
	set = frame.set;
	if set.setID == id then
		frame.set = nil;
		BtWLoadoutsFrame:Update();
	end
end
local previousConditionInfo = {};
_G['BtWLoadoutsPreviousConditionInfo'] = previousConditionInfo; --@TODO Remove
function Internal.ClearConditions()
	wipe(previousConditionInfo);
	wipe(activeConditions);
end
-- Table of Instances IDs that we want to override instanceType
local instanceTypeOverride = {
	-- Garrisons
	[1152] = "none",
	[1330] = "none",
	[1153] = "none",
	[1154] = "none",

	[1158] = "none",
	[1331] = "none",
	[1159] = "none",
	[1160] = "none",
}
function Internal.UpdateConditionsForInstance()
	local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo();

	instanceType = instanceTypeOverride[instanceID] or instanceType

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
function Internal.UpdateConditionsForBoss(unitId)
	local bossID = Internal.GetCurrentBoss(unitId) or previousConditionInfo.bossID;

	if previousConditionInfo.bossID ~= bossID then
		DeactivateConditionMap(conditionMap.bossID, previousConditionInfo.bossID);
		ActivateConditionMap(conditionMap.bossID, bossID);
		previousConditionInfo.bossID = bossID;
	end

	return bossID
end
function Internal.UpdateConditionsForAffixes()
	-- local affixesID;
	local affixIDs = {}
	local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo();
	if difficultyID == 23 then -- In a mythic dungeon (not M+)
		local affixes = GetCurrentAffixes();
		if affixes then
			for i=1,4 do
				affixIDs[i] = affixes[i] and affixes[i].id or nil
			end
		-- 	-- Ignore the 4th (seasonal) affix
		-- 	affixesID = Internal.GetAffixesInfo(affixes[1].id, affixes[2].id, affixes[3].id).id
		end
	end

	for i=1,4 do
		local key = "affixID" .. i
		if previousConditionInfo[key] ~= affixIDs[i] then
			DeactivateConditionMap(conditionMap[key], previousConditionInfo[key]);
			ActivateConditionMap(conditionMap[key], affixIDs[i]);
			previousConditionInfo[key] = affixIDs[i];
		end
	end
	-- if previousConditionInfo.affixesID ~= affixesID then
	-- 	DeactivateConditionMap(conditionMap.affixesID, previousConditionInfo.affixesID);
	-- 	ActivateConditionMap(conditionMap.affixesID, affixesID);
	-- 	previousConditionInfo.affixesID = affixesID;
	-- end
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
function Internal.TriggerConditions()
	-- In a Mythic Plus cant cant change anything anyway or during a boss
	if select(3,GetInstanceInfo()) == 8 or IsEncounterInProgress() then
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
		if type(set) == "table" and set.profileSet ~= nil and not set.disabled then
			local profile = Internal.GetProfile(set.profileSet);
			if Internal.IsLoadoutActivatable(profile) then
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

	local specID = GetSpecializationInfo(GetSpecialization());
	wipe(sortedActiveConditions);
	for profile,condition in pairs(activeConditions) do
		sortedActiveConditions[#sortedActiveConditions+1] = {
			profile = profile,
			condition = condition,
			match = conditionMatchCount[profile],
			specMatch = specID == profile.specID and 1 or 0
		};
	end

	if #sortedActiveConditions == 0 then
		return;
	elseif #sortedActiveConditions == 1 then
		if not Internal.IsProfileActive(sortedActiveConditions[1].profile) then
			StaticPopup_Hide("BTWLOADOUTS_REQUESTMULTIACTIVATE");
			StaticPopup_Show("BTWLOADOUTS_REQUESTACTIVATE", sortedActiveConditions[1].condition.name, nil, {
				set = sortedActiveConditions[1].profile,
				func = Internal.ActivateProfile,
			});
		end
	else
		sort(sortedActiveConditions, function(a,b)
			if a.match == b.match then
				return a.specMatch > b.specMatch;
			end
			return a.match > b.match;
		end);

		if Settings.limitConditions then
			local match = sortedActiveConditions[1].match
			for _,condition in ipairs(sortedActiveConditions) do
				if condition.match ~= match then
					break
				end

				if Internal.IsProfileActive(condition.profile) then
					return
				end
			end
		end

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
			func = Internal.ActivateProfile,
		}, conditionProfilesDropDown);
	end
end

Internal.AddConditionSet = AddConditionSet
Internal.RefreshConditionSet = RefreshConditionSet
Internal.GetConditionSet = GetConditionSet
Internal.DeleteConditionSet = DeleteConditionSet

local setsFiltered = {} -- Used to filter sets in various parts of the file
local function ProfilesDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Conditions

	CloseDropDownMenus();
	local set = tab.set;

	if set.profileSet then
		local subset = Internal.GetProfile(set.profileSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	set.profileSet = arg1;

	if set.profileSet then
		local subset = Internal.GetProfile(set.profileSet);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame:Update();
end
local function ProfilesDropDown_NewOnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Conditions

	CloseDropDownMenus();
	local set = tab.set;

	if set.profileSet then
		local subset = Internal.GetProfile(set.profileSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local newSet = Internal.AddProfile();
	set.profileSet = newSet.setID;

	if set.profileSet then
		local subset = Internal.GetProfile(set.profileSet);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame.Profiles.set = newSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, BtWLoadoutsFrame.Profiles:GetID());

	BtWLoadoutsFrame:Update();
end
local function ProfilesDropDownInit(self, level, menuList)
	if not BtWLoadoutsSets or not BtWLoadoutsSets.profiles then
		return;
	end

	local info = UIDropDownMenu_CreateInfo();

	local frame = BtWLoadoutsFrame -- self:GetParent():GetParent();
	local tab = BtWLoadoutsFrame.Conditions

	local set = tab.set;
	local selected = set and set.profileSet;

	if (level or 1) == 1 then
		info.text = L["None"];
		info.func = ProfilesDropDown_OnClick;
		info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

		wipe(setsFiltered);
		local sets = BtWLoadoutsSets.profiles;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" then
				setsFiltered[subset.specID or 0] = true;
			end
		end

		local className, classFile, classID = UnitClass("player");
		local classColor = C_ClassColor.GetClassColor(classFile);
		className = classColor and classColor:WrapTextInColorCode(className) or className;

		for specIndex=1,GetNumSpecializationsForClassID(classID) do
			local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
			if setsFiltered[specID] then
				info.text = format("%s: %s", className, specName);
				info.hasArrow, info.menuList = true, specID;
				info.keepShownOnClick = true;
				info.notCheckable = true;
				UIDropDownMenu_AddButton(info, level);
			end
		end

		local playerClassID = classID;
		for classID=1,GetNumClasses() do
			if classID ~= playerClassID then
				local className, classFile = GetClassInfo(classID);
				local classColor = C_ClassColor.GetClassColor(classFile);
				className = classColor and classColor:WrapTextInColorCode(className) or className;

				for specIndex=1,GetNumSpecializationsForClassID(classID) do
					local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
					if setsFiltered[specID] then
						info.text = format("%s: %s", className, specName);
						info.hasArrow, info.menuList = true, specID;
						info.keepShownOnClick = true;
						info.notCheckable = true;
						UIDropDownMenu_AddButton(info, level);
					end
				end
			end
		end

		local specID = 0;
		if setsFiltered[specID] then
			info.text = L["Other"];
			info.hasArrow, info.menuList = true, nil;
			info.keepShownOnClick = true;
			info.notCheckable = true;
			UIDropDownMenu_AddButton(info, level);
		end

		info.text = L["New Set"];
		info.func = ProfilesDropDown_NewOnClick;
		info.hasArrow, info.menuList = false, nil;
		info.keepShownOnClick = false;
		info.notCheckable = true;
		info.checked = false;
		UIDropDownMenu_AddButton(info, level);
	else
		local specID = menuList;

		wipe(setsFiltered);
		local sets = BtWLoadoutsSets.profiles;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" and subset.specID == specID then
				setsFiltered[#setsFiltered+1] = setID;
			end
		end
		sort(setsFiltered, function (a,b)
			return sets[a].name < sets[b].name;
		end)

		for _,setID in ipairs(setsFiltered) do
			info.text = sets[setID].name;
			info.arg1 = setID;
			info.func = ProfilesDropDown_OnClick;
			info.checked = selected == setID;
			UIDropDownMenu_AddButton(info, level);
		end
	end
end

local function ConditionTypeDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Conditions

	CloseDropDownMenus();
	local set = tab.set;

	set.type = arg1;
	set.instanceID = nil;
	set.difficultyID = nil;
	set.bossID = nil;
	set.affixesID = nil;

	BtWLoadoutsFrame:Update();
end
local function ConditionTypeDropDownInit(self, level, menuList)
	local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local selected = set and set.type;

	if (level or 1) == 1 then
		for _,conditionType in ipairs(CONDITION_TYPES) do
			info.text = CONDITION_TYPE_NAMES[conditionType];
			info.arg1 = conditionType;
			info.func = ConditionTypeDropDown_OnClick;
			info.checked = selected == conditionType;
			UIDropDownMenu_AddButton(info, level);
		end
	end
end


local function InstanceDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Conditions

	CloseDropDownMenus();
	local set = tab.set;

	set.instanceID = arg1;
	set.bossID = nil;
	if set.difficultyID ~= nil then
		local supportsDifficulty = (set.instanceID == nil);
		if not supportsDifficulty then
			for _,difficultyID in ipairs(instanceDifficulties[set.instanceID]) do
				if difficultyID == set.difficultyID then
					supportsDifficulty = true;
					break;
				end
			end
		end

		if not supportsDifficulty then
			set.difficultyID = nil;
		end

		if set.difficultyID ~= 8 then
			set.affixesID = nil;
		end
	else
		set.affixesID = nil;
	end

	BtWLoadoutsFrame:Update();
end
local CURRENT_EXPANSION = 9
if GetExpansionLevel() ~= 8 then
	CURRENT_EXPANSION = 8
end
local function InstanceDropDownInit(self, level, menuList)
	local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local dungeonType = set and set.type;
	local selected = set and set.instanceID;

	if dungeonType == CONDITION_TYPE_DUNGEONS then
		if (level or 1) == 1 then
			info.text = L["Any"];
			info.func = InstanceDropDown_OnClick;
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);

		-- 	for expansion,expansionData in ipairs(dungeonInfo) do
		-- 		info.text = expansionData.name;
		-- 		info.hasArrow, info.menuList = true, expansion;
		-- 		info.keepShownOnClick = true;
		-- 		info.notCheckable = true;
		-- 		UIDropDownMenu_AddButton(info, level);
		-- 	end
		-- else
			for _,instanceID in ipairs(dungeonInfo[CURRENT_EXPANSION].instances) do
				info.text = GetRealZoneText(instanceID);
				info.arg1 = instanceID;
				info.func = InstanceDropDown_OnClick;
				info.checked = selected == instanceID;
				UIDropDownMenu_AddButton(info, level);
			end
		end
	elseif dungeonType == CONDITION_TYPE_RAIDS then
		if (level or 1) == 1 then
			info.text = L["Any"];
			info.func = InstanceDropDown_OnClick;
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);

		-- 	for expansion,expansionData in ipairs(dungeonInfo) do
		-- 		info.text = expansionData.name;
		-- 		info.hasArrow, info.menuList = true, expansion;
		-- 		info.keepShownOnClick = true;
		-- 		info.notCheckable = true;
		-- 		UIDropDownMenu_AddButton(info, level);
		-- 	end
		-- else
			for _,instanceID in ipairs(raidInfo[CURRENT_EXPANSION].instances) do
				info.text = GetRealZoneText(instanceID);
				info.arg1 = instanceID;
				info.func = InstanceDropDown_OnClick;
				info.checked = selected == instanceID;
				UIDropDownMenu_AddButton(info, level);
			end
		end
	end
end


local function DifficultyDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Conditions

	CloseDropDownMenus();
	local set = tab.set;

	set.difficultyID = arg1;
	if arg1 == 8 then
		set.bossID = nil;
	else
		set.affixesID = nil;
	end

	BtWLoadoutsFrame:Update();
end
local function DifficultyDropDownInit(self, level, menuList)
	local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local conditionType = set and set.type;
	local instanceID = set and set.instanceID;
	local selected = set and set.difficultyID;

	if instanceID == nil then
		if conditionType == CONDITION_TYPE_DUNGEONS then
			info.text = L["Any"];
			info.func = DifficultyDropDown_OnClick;
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);

			for _,difficultyID in ipairs(Internal.dungeonDifficultiesAll) do
				info.text = GetDifficultyInfo(difficultyID);
				info.arg1 = difficultyID;
				info.func = DifficultyDropDown_OnClick;
				info.checked = selected == difficultyID;
				UIDropDownMenu_AddButton(info, level);
			end
		elseif conditionType == CONDITION_TYPE_RAIDS then
			info.text = L["Any"];
			info.func = DifficultyDropDown_OnClick;
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);

			for _,difficultyID in ipairs(Internal.raidDifficultiesAll) do
				info.text = GetDifficultyInfo(difficultyID);
				info.arg1 = difficultyID;
				info.func = DifficultyDropDown_OnClick;
				info.checked = selected == difficultyID;
				UIDropDownMenu_AddButton(info, level);
			end
		end
	else
		if (level or 1) == 1 then
			info.text = L["Any"];
			info.func = DifficultyDropDown_OnClick;
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);

			for _,difficultyID in ipairs(instanceDifficulties[instanceID]) do
				info.text = GetDifficultyInfo(difficultyID);
				info.arg1 = difficultyID;
				info.func = DifficultyDropDown_OnClick;
				info.checked = selected == difficultyID;
				UIDropDownMenu_AddButton(info, level);
			end
		end
	end
end


local function BossDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Conditions

	CloseDropDownMenus();
	local set = tab.set;

	set.bossID = arg1;

	BtWLoadoutsFrame:Update();
end
local function BossDropDownInit(self, level, menuList)
	local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local instanceID = set and set.instanceID;
	local selected = set and set.bossID;

	if (level or 1) == 1 then
		info.text = L["Any"];
		info.func = BossDropDown_OnClick;
		info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

		if instanceBosses[instanceID] then
			for _,bossID in ipairs(instanceBosses[instanceID]) do
				info.text = EJ_GetEncounterInfo(bossID);
				info.arg1 = bossID;
				info.func = BossDropDown_OnClick;
				info.checked = selected == bossID;
				UIDropDownMenu_AddButton(info, level);
			end
		end
	end
end

local function ScenarioDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Conditions

	CloseDropDownMenus();
	local set = tab.set;

	set.instanceID = arg1;
	set.difficultyID = arg2;

	BtWLoadoutsFrame:Update();
end
local function ScenarioDropDownInit(self, level, menuList)
	local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local instanceID = set and set.instanceID;
	local difficultyID = set and set.difficultyID;

	if (level or 1) == 1 then
		info.text = L["Any"];
		info.func = ScenarioDropDown_OnClick;
		info.checked = (instanceID == nil) and (difficultyID == nil);
		UIDropDownMenu_AddButton(info, level);

	-- 	for expansion,expansionData in ipairs(dungeonInfo) do
	-- 		info.text = expansionData.name;
	-- 		info.hasArrow, info.menuList = true, expansion;
	-- 		info.keepShownOnClick = true;
	-- 		info.notCheckable = true;
	-- 		UIDropDownMenu_AddButton(info, level);
	-- 	end
	-- else
		for _,details in ipairs(scenarioInfo[CURRENT_EXPANSION].instances) do
			info.text = details[3];
			info.arg1 = details[1];
			info.arg2 = details[2];
			info.func = ScenarioDropDown_OnClick;
			info.checked = (instanceID == details[1]) and (difficultyID == details[2]);
			UIDropDownMenu_AddButton(info, level);
		end
	end
end

local function AffixDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Conditions

	CloseDropDownMenus();
	local set = tab.set;

	if set.affixesID ~= nil and bit.band(set.affixesID, arg2) == arg2 then
		set.affixesID = bit.band(set.affixesID, arg1);
	else
		set.affixesID = bit.bor(bit.band(set.affixesID or 0, arg1), arg2);
	end
	if set.affixesID == 0 then
		set.affixesID = nil
	end

	BtWLoadoutsFrame:Update();
end

do
	BtWLoadoutsConditionsAffixesMixin = {}
	function BtWLoadoutsConditionsAffixesMixin:OnLoad()
		self.Buttons = {}
		for index,level in Internal.AffixesLevels() do
			local x = ((index - 1) * 90) + 20
			local y = -17
			local relativeTo
			for _,affix in Internal.Affixes(level) do
				local name = self:GetName() .. "Button" .. affix
				local button = CreateFrame("Button", name, self, "BtWLoadoutsConditionsAffixesDropDownButton", affix);
				button:SetWidth(85);
				if relativeTo then
					button:SetPoint("TOP", relativeTo, "BOTTOM", 0, -5);
				else
					button:SetPoint("TOPLEFT", x, y);
				end

				local fullname, icons, mask = select(2, Internal.GetAffixesName(affix));
				_G[name .. "NormalText"]:SetText(icons);
				button.mask = mask;

				button.keepShownOnClick = true
				button.notCheckable = true
				button.arg1 = bit.bxor(0xffffffff, bit.lshift(0xff, 8*(index-1)))
				button.arg2 = bit.lshift(affix, 8*(index-1))
				button.func = AffixDropDown_OnClick

				self.Buttons[#self.Buttons+1] = button
				
				button:Show();
				relativeTo = button;
			end
		end
		hooksecurefunc("CloseDropDownMenus", function ()
			if not MouseIsOver(self) then
				self:Hide();
			end
		end)
	end
	-- Changes the buttons based on mask
	function BtWLoadoutsConditionsAffixesMixin:Update(affixesID)
		local a, b, c, d = Internal.GetAffixesForID(affixesID)
		local mask = Internal.GetExclusiveAffixes(affixesID)
		for _,button in ipairs(self.Buttons) do
			button:SetEnabled(Internal.CompareAffixMasks(button.mask, mask));
			local affixID = button:GetID()
			button.Selection:SetShown(affixID == a or affixID == b or affixID == c or affixID == d);
		end
	end
end

BtWLoadoutsConditionsMixin = {}
function BtWLoadoutsConditionsMixin:OnLoad()
end
function BtWLoadoutsConditionsMixin:OnShow()
	if not self.initialized then
		UIDropDownMenu_SetWidth(self.ProfileDropDown, 400);
		UIDropDownMenu_Initialize(self.ProfileDropDown, ProfilesDropDownInit);
		UIDropDownMenu_JustifyText(self.ProfileDropDown, "LEFT");

		UIDropDownMenu_SetWidth(self.ConditionTypeDropDown, 400);
		UIDropDownMenu_Initialize(self.ConditionTypeDropDown, ConditionTypeDropDownInit);
		UIDropDownMenu_JustifyText(self.ConditionTypeDropDown, "LEFT");

		UIDropDownMenu_SetWidth(self.InstanceDropDown, 175);
		UIDropDownMenu_Initialize(self.InstanceDropDown, InstanceDropDownInit);
		UIDropDownMenu_JustifyText(self.InstanceDropDown, "LEFT");

		UIDropDownMenu_SetWidth(self.DifficultyDropDown, 175);
		UIDropDownMenu_Initialize(self.DifficultyDropDown, DifficultyDropDownInit);
		UIDropDownMenu_JustifyText(self.DifficultyDropDown, "LEFT");

		UIDropDownMenu_SetWidth(self.BossDropDown, 400);
		UIDropDownMenu_Initialize(self.BossDropDown, BossDropDownInit);
		UIDropDownMenu_JustifyText(self.BossDropDown, "LEFT");

		UIDropDownMenu_SetWidth(self.AffixesDropDown, 400);
		UIDropDownMenu_JustifyText(self.AffixesDropDown, "LEFT");

		self.AffixesDropDown.Button:SetScript("OnClick", function ()
			BtWLoadoutsConditionsAffixesDropDownList:SetShown(not BtWLoadoutsConditionsAffixesDropDownList:IsShown());
		end)

		UIDropDownMenu_SetWidth(self.ScenarioDropDown, 400);
		UIDropDownMenu_Initialize(self.ScenarioDropDown, ScenarioDropDownInit);
		UIDropDownMenu_JustifyText(self.ScenarioDropDown, "LEFT");
		self.initialized = true;
	end
end
function BtWLoadoutsConditionsMixin:ChangeSet(set)
    self.set = set
    self:Update()
end
function BtWLoadoutsConditionsMixin:UpdateSetEnabled(value)
	if self.set and self.set.disabled ~= value then
		self.set.disabled = value;
		self:Update();
	end
end
function BtWLoadoutsConditionsMixin:UpdateSetName(value)
	if self.set and self.set.name ~= not value then
		self.set.name = value;
		self:Update();
	end
end
function BtWLoadoutsConditionsMixin:OnButtonClick(button)
	CloseDropDownMenus()
	if button.isAdd then
		self.Name:ClearFocus();
		self:ChangeSet(AddConditionSet())
		C_Timer.After(0, function ()
			self.Name:HighlightText();
			self.Name:SetFocus();
		end);
	elseif button.isDelete then
		local set = self.set;
		StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
			set = set,
			func = DeleteConditionSet,
		});
	elseif button.isRefresh then
		RefreshConditionSet(self.set)
		self:Update();
	end
end
function BtWLoadoutsConditionsMixin:OnSidebarItemClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		button.collapsed[button.id] = not button.collapsed[button.id]
		self:Update()
	else
		self.Name:ClearFocus();
		self:ChangeSet(GetConditionSet(button.id))
	end
end
function BtWLoadoutsConditionsMixin:OnSidebarItemDoubleClick(button)
end
function BtWLoadoutsConditionsMixin:OnSidebarItemDragStart(button)
end
function BtWLoadoutsConditionsMixin:Update()
	self:GetParent().TitleText:SetText(L["Conditions"]);
	local sidebar = BtWLoadoutsFrame.Sidebar

	sidebar:SetSupportedFilters()
	sidebar:SetSets(BtWLoadoutsSets.conditions)
	sidebar:SetCollapsed(BtWLoadoutsCollapsed.conditions)
	sidebar:SetCategories(BtWLoadoutsCategories.conditions)
	sidebar:SetFilters(BtWLoadoutsFilters.conditions)
	sidebar:SetSelected(self.set)

	sidebar:Update()
	self.set = sidebar:GetSelected()

	if self.set ~= nil then
		local set = self.set;

		-- 8 is M+ and 23 is Mythic, since we cant change specs inside a M+ we need to check trigger within the mythic but still,
		-- show in the editor as Mythic Keystone whatever.
		if set.difficultyID == 8 then
			set.mapDifficultyID = 23;
		else
			set.mapDifficultyID = set.difficultyID;
		end

		local affixID1, affixID2, affixID3, affixID4
		if set.affixesID then
			affixID1, affixID2, affixID3, affixID4 = Internal.GetAffixesForID(set.affixesID)
		end
		if set.map.instanceType ~= set.type or
		   set.map.instanceID ~= set.instanceID or
		   set.map.difficultyID ~= set.mapDifficultyID or
		   set.map.bossID ~= set.bossID or

		   set.map.affixID1 ~= (affixID1 ~= 0 and affixID1 or nil) or
		   set.map.affixID2 ~= (affixID2 ~= 0 and affixID2 or nil) or
		   set.map.affixID3 ~= (affixID3 ~= 0 and affixID3 or nil) or
		   set.map.affixID4 ~= (affixID4 ~= 0 and affixID4 or nil) or

		   set.mapProfileSet ~= set.profileSet then
			RemoveConditionFromMap(set);

			set.mapProfileSet = set.profileSet; -- Used to check if we should handle the condition

			wipe(set.map);
			set.map.instanceType = set.type;
			set.map.instanceID = set.instanceID;
			set.map.difficultyID = set.mapDifficultyID;
			set.map.bossID = set.bossID;
			set.map.affixID1 = (affixID1 ~= 0 and affixID1 or nil)
			set.map.affixID2 = (affixID2 ~= 0 and affixID2 or nil)
			set.map.affixID3 = (affixID3 ~= 0 and affixID3 or nil)
			set.map.affixID4 = (affixID4 ~= 0 and affixID4 or nil)
		end

		if set.disabled then
			RemoveConditionFromMap(set);
		else
			AddConditionToMap(set);
		end

		self.Name:SetEnabled(true);
		if not self.Name:HasFocus() then
			self.Name:SetText(set.name or "");
		end

		self.Enabled:SetEnabled(true);
		self.Enabled:SetChecked(not set.disabled);

		self.ProfileDropDown.Button:SetEnabled(true);
		self.ConditionTypeDropDown.Button:SetEnabled(true);
		self.InstanceDropDown.Button:SetEnabled(true);
		self.DifficultyDropDown.Button:SetEnabled(true);
		self.ScenarioDropDown.Button:SetEnabled(true);

		if set.profileSet == nil then
			UIDropDownMenu_SetText(self.ProfileDropDown, L["None"]);
		else
			local subset = Internal.GetProfile(set.profileSet);
			UIDropDownMenu_SetText(self.ProfileDropDown, subset.name);
		end

		UIDropDownMenu_SetText(self.ConditionTypeDropDown, CONDITION_TYPE_NAMES[self.set.type]);
		self.InstanceDropDown:SetShown(set.type == CONDITION_TYPE_DUNGEONS or set.type == CONDITION_TYPE_RAIDS);
		if set.instanceID == nil then
			UIDropDownMenu_SetText(self.InstanceDropDown, L["Any"]);
		else
			UIDropDownMenu_SetText(self.InstanceDropDown, GetRealZoneText(set.instanceID));
		end
		self.DifficultyDropDown:SetShown(set.type == CONDITION_TYPE_DUNGEONS or set.type == CONDITION_TYPE_RAIDS);
		if set.difficultyID == nil then
			UIDropDownMenu_SetText(self.DifficultyDropDown, L["Any"]);
		else
			UIDropDownMenu_SetText(self.DifficultyDropDown, GetDifficultyInfo(set.difficultyID));
		end

		-- With no instance selected, no bosses for that instance, or when M+ is selected, hide the boss drop down
		if set.instanceID == nil or Internal.instanceBosses[set.instanceID] == nil or set.difficultyID == 8 then
			self.BossDropDown:SetShown(false);
		else
			self.BossDropDown:SetShown(true);
			self.BossDropDown.Button:SetEnabled(true);

			if set.bossID == nil then
				UIDropDownMenu_SetText(self.BossDropDown, L["Any"]);
			else
				UIDropDownMenu_SetText(self.BossDropDown, EJ_GetEncounterInfo(set.bossID));
			end
		end
		if set.difficultyID ~= 8 then
			self.AffixesDropDown:SetShown(false);
		else
			self.AffixesDropDown:SetShown(true);
			self.AffixesDropDown.Button:SetEnabled(true);

			if set.affixesID == nil then
				UIDropDownMenu_SetText(self.AffixesDropDown, L["Any"]);
			else
				UIDropDownMenu_SetText(self.AffixesDropDown, select(3, Internal.GetAffixesName(set.affixesID)));
			end
			BtWLoadoutsConditionsAffixesDropDownList:Update(set.affixesID or 0)
		end
		self.ScenarioDropDown:SetShown(set.type == CONDITION_TYPE_SCENARIO);
		if set.instanceID == nil and set.difficultyID == nil then
			UIDropDownMenu_SetText(self.ScenarioDropDown, L["Any"]);
		else
			-- This isnt a good way to do this, but it'll work
			for _,details in ipairs(scenarioInfo[CURRENT_EXPANSION].instances) do
				if (set.instanceID == details[1]) and (set.difficultyID == details[2]) then
					UIDropDownMenu_SetText(self.ScenarioDropDown, details[3]);
				end
			end
		end

		self:GetParent().RefreshButton:SetEnabled(true)

		local activateButton = self:GetParent().ActivateButton;
		activateButton:SetEnabled(false);

		local deleteButton =  self:GetParent().DeleteButton;
		deleteButton:SetEnabled(true);

		local helpTipBox = self:GetParent().HelpTipBox;
		helpTipBox:Hide();

		local addButton = self:GetParent().AddButton;
		addButton.Flash:Hide();
		addButton.FlashAnim:Stop();
	else
		self.Name:SetEnabled(false);
		self.Name:SetText("");
		
		self.Enabled:SetEnabled(false);
		self.Enabled:SetChecked(false);

		self.ProfileDropDown.Button:SetEnabled(false);
		self.ConditionTypeDropDown.Button:SetEnabled(false);
		self.InstanceDropDown.Button:SetEnabled(false);
		self.DifficultyDropDown.Button:SetEnabled(false);
		self.BossDropDown.Button:SetEnabled(false);
		self.ScenarioDropDown.Button:SetEnabled(false);
		self.ScenarioDropDown:Hide();
		self.AffixesDropDown:Hide();

		self:GetParent().RefreshButton:SetEnabled(false)

		local activateButton = self:GetParent().ActivateButton;
		activateButton:SetEnabled(false);

		local deleteButton =  self:GetParent().DeleteButton;
		deleteButton:SetEnabled(false);

		local helpTipBox = self:GetParent().HelpTipBox;
		helpTipBox:Hide();

		local addButton = self:GetParent().AddButton;
		addButton.Flash:Show();
		addButton.FlashAnim:Play();
	end
end
