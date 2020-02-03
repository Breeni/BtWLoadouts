local ADDON_NAME,Internal = ...
local L = Internal.L
local Settings = Internal.Settings

local GetSubZoneText = GetSubZoneText
local GetRealZoneText = GetRealZoneText
local GetInstanceInfo = GetInstanceInfo
local GetDifficultyInfo = GetDifficultyInfo
local GetCurrentAffixes = C_MythicPlus.GetCurrentAffixes;
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

local CONDITION_TYPES = Internal.CONDITION_TYPES;
local CONDITION_TYPE_NAMES = Internal.CONDITION_TYPE_NAMES;

local CONDITION_TYPE_WORLD = "none";
local CONDITION_TYPE_DUNGEONS = "party";
local CONDITION_TYPE_RAIDS = "raid";
local CONDITION_TYPE_ARENA = "arena";
local CONDITION_TYPE_BATTLEGROUND = "pvp";
local CONDITION_TYPE_SCENARIO = "scenario";

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
		setID = Internal.GetNextSetID(BtWLoadoutsSets.conditions),
		name = name,
		type = CONDITION_TYPE_WORLD,
		map = {},
    };
    BtWLoadoutsSets.conditions[set.setID] = set;
    return set;
end
Internal.AddConditionSet = AddConditionSet;
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
Internal.DeleteConditionSet = DeleteConditionSet
local previousConditionInfo = {};
_G['BtWLoadoutsPreviousConditionInfo'] = previousConditionInfo; --@TODO Remove
function Internal.ClearConditions()
	wipe(previousConditionInfo);
	wipe(activeConditions);
end
function Internal.UpdateConditionsForInstance()
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
function Internal.UpdateConditionsForBoss(unitId)
	local bossID = previousConditionInfo.bossID;
	local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo();
	if instanceType == "party" or instanceType == "raid" then
		local uiMapID = C_Map.GetBestMapForUnit("player");
		if uiMapID then
			bossID = Internal.uiMapIDToBossID[uiMapID] or bossID;
		end
		local areaID = instanceID and Internal.areaNameToIDMap[instanceID] and Internal.areaNameToIDMap[instanceID][GetSubZoneText()] or nil;
		if areaID then
			bossID = Internal.InstanceAreaIDToBossID[instanceID][areaID] or bossID;
		end
		if unitId then
			local unitGUID = UnitGUID(unitId);
			if unitGUID and not UnitIsDead(unitId) then
				local type, zero, serverId, instanceId, zone_uid, npcId, spawn_uid = strsplit("-", unitGUID);
				if type == "Creature" and tonumber(npcId) then
					bossID = Internal.npcIDToBossID[tonumber(npcId)] or bossID;
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
function Internal.UpdateConditionsForAffixes()
	local affixesID;
	local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo();
	if difficultyID == 23 then -- In a mythic dungeon (not M+)
		local affixes = GetCurrentAffixes();
		if affixes then
			-- Ignore the 4th (seasonal) affix
			affixesID = Internal.GetAffixesInfo(affixes[1].id, affixes[2].id, affixes[3].id).id
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
function Internal.TriggerConditions()
	-- In a Mythic Plus cant cant change anything anyway
	if select(3,GetInstanceInfo()) == 8 then
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
			if select(5, Internal.IsProfileValid(profile)) then
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
		if not Internal.IsProfileActive(sortedActiveConditions[1].profile) then
			StaticPopup_Hide("BTWLOADOUTS_REQUESTMULTIACTIVATE");
			StaticPopup_Show("BTWLOADOUTS_REQUESTACTIVATE", sortedActiveConditions[1].condition.name, nil, {
				set = sortedActiveConditions[1].profile,
				func = Internal.ActivateProfile,
			});
		end
	else
		sort(sortedActiveConditions, function(a,b)
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

Internal.GetConditionSet = GetConditionSet

function Internal.ConditionsTabUpdate(self)
	self:GetParent().TitleText:SetText(L["Conditions"]);
	self.set = Internal.SetsScrollFrame_NoFilter(self.set, BtWLoadoutsSets.conditions);

	if self.set ~= nil then
		local set = self.set;

		-- 8 is M+ and 23 is Mythic, since we cant change specs inside a M+ we need to check trigger within the mythic but still,
		-- show in the editor as Mythic Keystone whatever.
		if set.difficultyID == 8 then
			set.mapDifficultyID = 23;
		else
			set.mapDifficultyID = set.difficultyID;
		end

		if set.map.instanceType ~= set.type or
		   set.map.instanceID ~= set.instanceID or
		   set.map.difficultyID ~= set.mapDifficultyID or
		   set.map.bossID ~= set.bossID or
		   set.map.affixesID ~= (set.affixesID ~= nil and bit.band(set.affixesID, 0x00ffffff) or nil) or
		   set.mapProfileSet ~= set.profileSet then
			RemoveConditionFromMap(set);

			set.mapProfileSet = set.profileSet; -- Used to check if we should handle the condition

			wipe(set.map);
			set.map.instanceType = set.type;
			set.map.instanceID = set.instanceID;
			set.map.difficultyID = set.mapDifficultyID;
			set.map.bossID = set.bossID;
			set.map.affixesID = (set.affixesID ~= nil and bit.band(set.affixesID, 0x00ffffff) or nil);
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
		end

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
		self.AffixesDropDown:Hide();

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
