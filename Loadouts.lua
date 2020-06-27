local ADDON_NAME,Internal = ...
local L = Internal.L

local External = {}
_G[ADDON_NAME] = External

local HelpTipBox_Anchor = Internal.HelpTipBox_Anchor;
local HelpTipBox_SetText = Internal.HelpTipBox_SetText;

local IsResting = IsResting;
local UnitAura = UnitAura;
local UnitClass = UnitClass;
local UnitLevel = UnitLevel;
local UnitFullName = UnitFullName;
local UnitCastingInfo = UnitCastingInfo;
local GetClassColor = C_ClassColor.GetClassColor;
local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE;

local GetItemCount = GetItemCount;
local GetItemInfo = GetItemInfo;

local SetSpecialization = SetSpecialization;
local GetSpecialization = GetSpecialization;
local GetNumSpecializations = GetNumSpecializations;
local GetSpecializationInfo = GetSpecializationInfo;
local GetSpecializationInfoByID = GetSpecializationInfoByID;

local GetMilestoneEssence = C_AzeriteEssence.GetMilestoneEssence

local StaticPopup_Show = StaticPopup_Show;
local StaticPopup_Hide = StaticPopup_Hide;
local StaticPopup_Visible = StaticPopup_Visible;

local UIDropDownMenu_SetText = UIDropDownMenu_SetText;
local UIDropDownMenu_EnableDropDown = UIDropDownMenu_EnableDropDown;
local UIDropDownMenu_DisableDropDown = UIDropDownMenu_DisableDropDown;
local UIDropDownMenu_SetSelectedValue = UIDropDownMenu_SetSelectedValue;

local format = string.format;

local AddSet = Internal.AddSet;
local DeleteSet = Internal.DeleteSet;

local loadoutSegments = {}

local PlayerNeedsTome;
do
	local talentChangeBuffs = {
		[32727] = true,
		[44521] = true,
		[226234] = true,
		[226241] = true,
		[227041] = true,
		[227563] = true,
		[227564] = true,
		[227565] = true,
		[227569] = true,
		[228128] = true,
		[248473] = true,
		[256229] = true,
		[256230] = true,
		[256231] = true,
	};
	function PlayerNeedsTome()
		if IsResting() then
			return false;
		end

		local index = 1;
		local name, _, _, _, _, _, _, _, _, spellId = UnitAura("player", index, "HELPFUL");
		while name do
			if talentChangeBuffs[spellId] then
				return false;
			end

			index = index + 1;
			name, _, _, _, _, _, _, _, _, spellId = UnitAura("player", index, "HELPFUL");
		end

		return true;
	end
end
local RequestTome;
do
	local tomes = {
		143780, -- Tome of the Tranquil Mind
		143785, -- Tome of the Tranquil Mind
		141446, -- Tome of the Tranquil Mind
		153647, -- Tome of the Quiet Mind
	};
	local function GetBestTome()
		if UnitLevel("player") <= 109 then -- Tome of the Clear Mind (WOD)
			local itemId = 141640
			local count = GetItemCount(itemId);
			if count >= 1 then
				local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemId);
				return itemId, name, link, quality, icon;
			end
		end
		for _,itemId in ipairs(tomes) do
			local count = GetItemCount(itemId);
			if count >= 1 then
				local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemId);
				return itemId, name, link, quality, icon;
			end
		end
	end
	function RequestTome()
		if not StaticPopup_Visible("BTWLOADOUTS_NEEDTOME") then --  and not StaticPopup_Visible("BTWLOADOUTS_NEEDRESTED")
			local itemId, name, link, quality, icon = GetBestTome();
			if name ~= nil then
				local r, g, b = GetItemQualityColor(quality or 2);
				StaticPopup_Show("BTWLOADOUTS_NEEDTOME", "", nil, {["texture"] = icon, ["name"] = name, ["color"] = {r, g, b, 1}, ["link"] = link, ["count"] = 1});
			elseif itemId == nil then
				-- StaticPopup_Show("BTWLOADOUTS_NEEDRESTED", "", nil, {["texture"] = icon, ["name"] = name, ["color"] = {r, g, b, 1}, ["link"] = link, ["count"] = 1});
			end
		end
	end
end

-- We need to add a small delay after switching specs before changing other things because Blizzard is
-- still changing things after the cast is finished
local specChangeInfo = {
	spellId = 200749, -- 200749 is the changing spec spell id
	endTime = nil,
	castGUID = nil,
}
local function IsChangingSpec(verifyCastGUID)
	if not specChangeInfo.endTime then
		return false
	end

	if specChangeInfo.endTime + .5 < GetTime() then
		specChangeInfo.endTime = nil
		specChangeInfo.castGUID = nil

		return false
	end

	if verifyCastGUID ~= nil and specChangeInfo.castGUID ~= verifyCastGUID then
		return false
	end

	return true
end

-- Activating a set can take multiple passes, things maybe delayed
-- by switching spec or waiting for the player to use a tome
local target = {};
_G['BtWLoadoutsTarget'] = target; -- @TODO REMOVE

-- Handles events during loadout changing
local eventHandler = CreateFrame("Frame");
eventHandler:Hide();

local uiErrorTracking
local function CancelActivateProfile()
	C_Timer.After(1, function ()
		UIErrorsFrame:Clear()
		if uiErrorTracking then
			UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
		end
		uiErrorTracking = nil
	end)

	wipe(target);
	StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
	eventHandler:UnregisterAllEvents();
	eventHandler:Hide();
	Internal.Call("LOADOUT_CHANGE_END")
	Internal.LogMessage("--- END ---")
end
Internal.CancelActivateProfile = CancelActivateProfile;

local function LoadoutHasErrors(set)
	local specID, role, class = set.specID

	if set.talents then
		for _,subsetID in ipairs(set.talents) do
			local subset = Internal.GetTalentSet(subsetID)
			specID = specID or subset.specID

			if specID ~= subset.specID then
				return true, specID
			end
		end
	end

	if set.pvptalents then
		for _,subsetID in ipairs(set.pvptalents) do
			local subset = Internal.GetPvPTalentSet(subsetID)
			specID = specID or subset.specID

			if specID ~= subset.specID then
				return true, specID
			end
		end
	end

	if specID then
		role, class = select(5, GetSpecializationInfoByID(specID))
	end

	if set.essences then
		for _,subsetID in ipairs(set.essences) do
			local subset = Internal.GetEssenceSet(subsetID)
			role = role or subset.role

			if role ~= subset.role then
				return true, specID
			end
		end
	end

	if set.equipment then
		for _,subsetID in ipairs(set.equipment) do
			local subset = Internal.GetEquipmentSet(subsetID)
			local characterInfo = Internal.GetCharacterInfo(subset.character);
			class = class or characterInfo.class;

			if class ~= characterInfo.class then
				return true, specID
			end
		end
	end

	return false, specID
end

local function GetLoadoutErrors(errors, set)
	local specID, hasError, role, class = set.specID, false

	wipe(errors["talents"])
	for index,subsetID in ipairs(set.talents) do
		local subset = Internal.GetTalentSet(subsetID)
		specID = specID or subset.specID

		if specID ~= subset.specID then
			hasError = true
			errors["talents"][index] = L["Incompatible Specialization"]
		end
	end

	wipe(errors["pvptalents"])
	for index,subsetID in ipairs(set.pvptalents) do
		local subset = Internal.GetPvPTalentSet(subsetID)
		specID = specID or subset.specID

		if specID ~= subset.specID then
			hasError = true
			errors["pvptalents"][index] = L["Incompatible Specialization"]
		end
	end

	if specID then
		role, class = select(5, GetSpecializationInfoByID(specID))
	end

	wipe(errors["essences"])
	for index,subsetID in ipairs(set.essences) do
		local subset = Internal.GetEssenceSet(subsetID)
		role = role or subset.role

		if role ~= subset.role then
			hasError = true
			errors["essences"][index] = L["Incompatible Role"]
		end
	end

	wipe(errors["equipment"])
	for index,subsetID in ipairs(set.equipment) do
		local subset = Internal.GetEquipmentSet(subsetID)
		local characterInfo = Internal.GetCharacterInfo(subset.character);
		class = class or characterInfo.class;

		if class ~= characterInfo.class then
			hasError = true
			errors["equipment"][index] = L["Incompatible Class"]
		end
	end

	return hasError, errors, specID
end
-- Checks of a loadout is activatable
local function IsLoadoutActivatable(set)
	local specID = set.specID

	if specID and not Internal.CanSwitchToSpecialization(specID) then
		return false
	end

	return true
end

local function AddProfile()
    return AddSet("profiles", {
		name = L["New Profile"],
		talents = {},
		pvptalents = {},
		essences = {},
		equipment = {},
		actionbars = {},
		version = 2,
		useCount = 0,
    })
end
local function GetProfile(id)
    return BtWLoadoutsSets.profiles[id];
end
local function GetProfileByName(name)
	for _,set in pairs(BtWLoadoutsSets.profiles) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
end
Internal.GetProfileByName = GetProfileByName
local function DeleteProfile(id)
	do
        local set = type(id) == "table" and id or GetProfile(id);

        -- for _,segment in ipairs(loadoutSegments) do
        --     local ids = set[segment.id]
        --     if ids then
        --         for _,id in ipairs(ids) do
        --             local subSet = segment.get(id)
        --             subSet.useCount = (subSet.useCount or 1) - 1;
        --         end
        --     end
        -- end

		for _,setID in ipairs(set.talents) do
			local subSet = Internal.GetTalentSet(setID);
			subSet.useCount = (subSet.useCount or 1) - 1;
		end
		for _,setID in ipairs(set.pvptalents) do
			local subSet = Internal.GetPvPTalentSet(setID);
			subSet.useCount = (subSet.useCount or 1) - 1;
		end
		for _,setID in ipairs(set.essences) do
			local subSet = Internal.GetEssencetSet(setID);
			subSet.useCount = (subSet.useCount or 1) - 1;
		end
		for _,setID in ipairs(set.equipment) do
			local subSet = Internal.GetEquipmentSet(setID);
			subSet.useCount = (subSet.useCount or 1) - 1;
		end
		for _,setID in ipairs(set.actionbars) do
			local subSet = Internal.GetActionBarSet(setID);
			subSet.useCount = (subSet.useCount or 1) - 1;
		end

		-- Disconnect conditions for the deleted loadout
		for _,superset in pairs(BtWLoadoutsSets.conditions) do
			if type(superset) == "table" and superset.profileSet == set.setID then
				Internal.RemoveConditionFromMap(superset);

				superset.profileSet = nil;
			end
		end
	end
	DeleteSet(BtWLoadoutsSets.profiles, id);

	local frame = BtWLoadoutsFrame.Profiles;
	local set = frame.set;
	if set == id or set.setID == id then
		frame.set = nil;--select(2,next(BtWLoadoutsSets.profiles)) or {};
		BtWLoadoutsFrame:Update();
	end
end
local function ActivateProfile(profile)
	local hasErrors, specID = LoadoutHasErrors(profile)
	if not hasErrors and not IsLoadoutActivatable(profile) then
		--@TODO display an error
		return;
	end

	target.name = profile.name

	if specID then
		target.specID = specID or profile.specID;
	end

	if profile.talents then
		target.talents = target.talents or {};
		for _,setID in ipairs(profile.talents) do
			target.talents[#target.talents+1] = setID;
		end
	end
	if profile.pvptalents then
		target.pvptalents = target.pvptalents or {};
		for _,setID in ipairs(profile.pvptalents) do
			target.pvptalents[#target.pvptalents+1] = setID;
		end
	end
	if profile.essences then
		target.essences = target.essences or {};
		for _,setID in ipairs(profile.essences) do
			target.essences[#target.essences+1] = setID;
		end
	end
	if profile.equipment then
		target.equipment = target.equipment or {};
		for _,setID in ipairs(profile.equipment) do
			target.equipment[#target.equipment+1] = setID;
		end
	end
	if profile.actionbars then
		target.actionbars = target.actionbars or {};
		for _,setID in ipairs(profile.actionbars) do
			target.actionbars[#target.actionbars+1] = setID;
		end
	end

	if not target.active then
		Internal.Call("LOADOUT_CHANGE_START")
		Internal.ClearLog()
		Internal.LogMessage("--- START ---")
		Internal.LogMessage(format("%s: %s", (select(2, GetAddOnInfo(ADDON_NAME))), (GetAddOnMetadata(ADDON_NAME, "Version"))))
	else
		Internal.Call("LOADOUT_CHANGE_APPEND")
		Internal.LogMessage("--- APPEND ---")
	end

	target.active = true
    target.dirty = true;
	eventHandler:RegisterEvent("GET_ITEM_INFO_RECEIVED");
	eventHandler:RegisterEvent("PLAYER_REGEN_DISABLED");
	eventHandler:RegisterEvent("PLAYER_REGEN_ENABLED");
	eventHandler:RegisterEvent("PLAYER_UPDATE_RESTING");
	eventHandler:RegisterUnitEvent("UNIT_AURA", "player");
	eventHandler:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
	eventHandler:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
	eventHandler:RegisterEvent("ZONE_CHANGED");
	eventHandler:RegisterEvent("ZONE_CHANGED_INDOORS");
	eventHandler:RegisterEvent("ITEM_UNLOCKED");
	eventHandler:RegisterEvent("SPELL_UPDATE_COOLDOWN");
	eventHandler:RegisterEvent("PLAYER_STOPPED_MOVING");
	eventHandler:RegisterEvent("PLAYER_TALENT_UPDATE");
	eventHandler:RegisterEvent("PLAYER_LEARN_TALENT_FAILED");
	eventHandler:RegisterEvent("PLAYER_PVP_TALENT_UPDATE");
	eventHandler:RegisterEvent("PLAYER_LEARN_PVP_TALENT_FAILED");
	eventHandler:RegisterUnitEvent("UNIT_SPELLCAST_START", "player");
	eventHandler:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player");
	eventHandler:Show();
end
local temp = {}
local function IsProfileActive(set)
	if set.specID then
		local playerSpecID = GetSpecializationInfo(GetSpecialization());
		if set.specID ~= playerSpecID then
			return false;
		end
    end

    -- for _,segment in ipairs(loadoutSegments) do
    --     local ids = set[segment.id]
    --     if ids then
    --         wipe(temp);
    --         segment.combine(temp, unpack(ids));
    --         if not set.isActive(temp) then
    --             return false;
    --         end
    --     end
    -- end

    if set.talents then
		local subset = Internal.CombineTalentSets({}, Internal.GetTalentSets(unpack(set.talents)));
		if not Internal.IsTalentSetActive(subset) then
			return false;
		end
	end

    if set.pvptalents then
		local subset = Internal.CombinePvPTalentSets({}, Internal.GetPvPTalentSets(unpack(set.pvptalents)));
		if not Internal.IsPvPTalentSetActive(subset) then
			return false;
		end
	end

    if set.essences then
		local subset = Internal.CombineEssenceSets({}, Internal.GetEssenceSets(unpack(set.essences)));
		if not Internal.IsEssenceSetActive(subset) then
			return false;
		end
	end

    if set.equipment then
		local subset = Internal.CombineEquipmentSets({}, Internal.GetEquipmentSets(unpack(set.equipment)));
		if not Internal.IsEquipmentSetActive(subset) then
			return false;
		end
	end

    if set.actionbars then
		local subset = Internal.CombineActionBarSets({}, Internal.GetActionBarSets(unpack(set.actionbars)));
		if not Internal.IsActionBarSetActive(subset) then
			return false;
		end
	end

	return true;
end
local function GetActiveProfiles()
	if target.active then
		if target.name then
			return format(L["Changing to %s..."], target.name)
		else
			return L["Changing..."]
		end
	end

	local activeProfiles = {}
	for _,profile in pairs(BtWLoadoutsSets.profiles) do
		if type(profile) == "table" and not profile.disabled and IsProfileActive(profile) then
			activeProfiles[#activeProfiles+1] = profile.name
		end
	end
	if #activeProfiles == 0 then
		return nil
	end

	table.sort(activeProfiles)
	return table.concat(activeProfiles, "/");
end
local function ContinueActivateProfile()
    local set = target
	set.dirty = false

	if Internal.CheckTimeout() then
		Internal.LogMessage("--- TIMEOUT ---")
		CancelActivateProfile()
		return
	end

	Internal.SetWaitReason() -- Clear wait reason

	Internal.UpdateLauncher(GetActiveProfiles());

	if InCombatLockdown() then
		Internal.SetWaitReason(L["Waiting for combat to end"])
		StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
        return;
    end

	if IsChangingSpec() then
		Internal.SetWaitReason(L["Waiting for specialization change"])
		StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
        return;
	end

	local specID = set.specID;
	if specID ~= nil then
		local playerSpecID = GetSpecializationInfo(GetSpecialization());
		if specID ~= playerSpecID then
			if IsPlayerMoving() then -- Cannot change spec while moving
				Internal.SetWaitReason(L["Waiting to change specialization"])
				StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
				return;
			end

			for specIndex=1,GetNumSpecializations() do
				if GetSpecializationInfo(specIndex) == specID then
					Internal.LogMessage("Switching specialization to %s", (select(2, GetSpecializationInfo(specIndex))))
					SetSpecialization(specIndex);
					target.dirty = false;
					return;
				end
			end
		end
	end

	local talentSet;
	if set.talents then
		talentSet = Internal.CombineTalentSets({}, Internal.GetTalentSets(unpack(set.talents)));
	end

	if talentSet and Internal.TalentSetDelay(talentSet) then
		Internal.SetWaitReason(L["Waiting for talent cooldown"])
		StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
        return;
	end

	local pvpTalentSet;
	if set.pvptalents then
		pvpTalentSet = Internal.CombinePvPTalentSets({}, Internal.GetPvPTalentSets(unpack(set.pvptalents)));
	end

	local essencesSet;
	if set.essences then
		essencesSet = Internal.CombineEssenceSets({}, Internal.GetEssenceSets(unpack(set.essences)));
	end

	if essencesSet and Internal.EssenceSetDelay(essencesSet) then
		Internal.SetWaitReason(L["Waiting for essence cooldown"])
		StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
        return;
	end

	if talentSet and not Internal.IsTalentSetActive(talentSet) and PlayerNeedsTome() then
		Internal.SetWaitReason(L["Waiting for tome"])
		RequestTome();
		return;
	end

	if essencesSet and not Internal.IsEssenceSetActive(essencesSet) and PlayerNeedsTome() then
		Internal.SetWaitReason(L["Waiting for tome"])
		RequestTome();
		return;
	end

	StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
	-- StaticPopup_Hide("BTWLOADOUTS_NEEDRESTED");

	if uiErrorTracking == nil then
		uiErrorTracking = UIErrorsFrame:IsEventRegistered("UI_ERROR_MESSAGE")
		UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
	end

	local complete = true;
    if talentSet then
		if not Internal.ActivateTalentSet(talentSet) then
			complete = false;
		end
	end

	-- When we will finish with Conflict as a major there is a chance we wont be able to put all the
	-- pvp talents in the 4 slots so we need to check other set pvp talents too
	local conflictAndStrife = false
	if essencesSet then
		conflictAndStrife = essencesSet.essences[115] == 32; -- We are trying to equip Conflict
	else
		conflictAndStrife = GetMilestoneEssence(115) == 32; -- Conflict is equipped
	end

    if pvpTalentSet then
		if not Internal.ActivatePvPTalentSet(pvpTalentSet, conflictAndStrife) then
			complete = false;
		end
    end

    if essencesSet and C_AzeriteEmpoweredItem.IsHeartOfAzerothEquipped() then
		if not Internal.ActivateEssenceSet(essencesSet) then
			complete = false;
			set.dirty = true; -- Just run next frame
		end
    end

	local equipmentSet;
	if set.equipment then
		equipmentSet = Internal.CombineEquipmentSets({}, Internal.GetEquipmentSets(unpack(set.equipment)));

		if equipmentSet then
			Internal.CheckEquipmentSetForIssues(equipmentSet) -- This will "solve" any unique-equipped issues

			if not Internal.ActivateEquipmentSet(equipmentSet) then
				complete = false;
			end
		end
	end

	local actionBarSet;
	if set.actionbars then
		actionBarSet = Internal.CombineActionBarSets({}, Internal.GetActionBarSets(unpack(set.actionbars)));

		if actionBarSet then
			if not Internal.ActivateActionBarSet(actionBarSet) then
				complete = false;
				set.dirty = true; -- Just run next frame
			end
		end
	end

	-- Done
	if complete then
		CancelActivateProfile();
	end

	Internal.UpdateLauncher(GetActiveProfiles());
end

function Internal.DirtyAfter(timer)
	C_Timer.After(timer, function()
		target.dirty = true;
	end);
end

eventHandler:SetScript("OnEvent", function (self, event, ...)
    self[event](self, ...);
end);
function eventHandler:GET_ITEM_INFO_RECEIVED()
    target.dirty = true;
end
function eventHandler:PLAYER_REGEN_DISABLED()
    StaticPopup_Hide("BTWLOADOUTS_NEEDTOME");
end
function eventHandler:PLAYER_REGEN_ENABLED()
    target.dirty = true;
end
function eventHandler:PLAYER_UPDATE_RESTING()
	target.dirty = true;
end
function eventHandler:PLAYER_STOPPED_MOVING()
	target.dirty = true;
end
function eventHandler:UNIT_AURA()
	C_Timer.After(1, function()
		target.dirty = true;
	end);
end
function eventHandler:PLAYER_SPECIALIZATION_CHANGED(...)
	-- Added delay just to be safe
	C_Timer.After(1, function()
		target.dirty = true;
	end);
end
function eventHandler:ACTIVE_TALENT_GROUP_CHANGED(...)
end
function eventHandler:ZONE_CHANGED(...)
	target.dirty = true;
end
eventHandler.ZONE_CHANGED_INDOORS = eventHandler.ZONE_CHANGED;
function eventHandler:ITEM_UNLOCKED(...)
	target.dirty = true;
end
function eventHandler:PLAYER_TALENT_UPDATE(...)
	target.dirty = true;
end
function eventHandler:PLAYER_LEARN_TALENT_FAILED(...)
	target.dirty = true;
end
function eventHandler:PLAYER_PVP_TALENT_UPDATE(...)
	target.dirty = true;
end
function eventHandler:PLAYER_LEARN_PVP_TALENT_FAILED(...)
	target.dirty = true;
end
function eventHandler:SPELL_UPDATE_COOLDOWN()
	-- Added delay because it didnt seem to always trigger correctly
	C_Timer.After(1, function()
		target.dirty = true;
	end);
end
function eventHandler:UNIT_SPELLCAST_START()
	local endTime, _, castGUID, _, spellId = select(5, UnitCastingInfo("player"))
	if spellId == specChangeInfo.spellId then
		specChangeInfo.endTime = endTime / 1000
		specChangeInfo.castGUID = castGUID
	end
end
function eventHandler:UNIT_SPELLCAST_INTERRUPTED(_, castGUID, spellId, ...)
	if spellId == specChangeInfo.spellId and IsChangingSpec(castGUID) then
		CancelActivateProfile();
		Internal.UpdateLauncher(GetActiveProfiles());
	end
end

eventHandler:SetScript("OnUpdate", function (self)
    if target.dirty then
		ContinueActivateProfile();
    end
end)

-- [[ Internal API ]]
-- Loadouts are split into segments, ... @TODO
function Internal.AddLoadoutSegment(details)
    loadoutSegments[#loadoutSegments+1] = details;
end
function Internal.IsActivatingLoadout()
    return target.active
end
function Internal.SetWaitReason(reason)
	if reason == nil then
		target.timeout = target.timeout or (GetTime() + 10) -- Set a timeout
	else
		target.timeout = nil
	end

	target.currentWaitReason = reason
end
function Internal.CheckTimeout()
	if not target.timeout then
		return false
	end

	return target.timeout < GetTime()
end
function Internal.GetWaitReason()
	return target.currentWaitReason
end

Internal.GetProfile = GetProfile
Internal.GetActiveProfiles = GetActiveProfiles
Internal.ActivateProfile = ActivateProfile
Internal.LoadoutHasErrors = LoadoutHasErrors
Internal.GetLoadoutErrors = GetLoadoutErrors
Internal.IsLoadoutActivatable = IsLoadoutActivatable
Internal.IsProfileActive = IsProfileActive
Internal.AddProfile = AddProfile
Internal.DeleteProfile = DeleteProfile

-- [[ External API ]]
-- Return: id, name, specID, character
function External.GetLoadoutInfo(id)
	local set = GetProfile(id)
	if not set then
		return
	end

	return set.setID, set.name, set.specID, set.character
end
function External.IsLoadoutActive(id)
	local set = GetProfile(id)
	if not set then
		return
	end

	return IsProfileActive(set)
end
do
	local loadouts = {}
	-- Get a list of all loadouts
	-- Return: id, ...
	function External.GetLoadouts()
		wipe(loadouts);
		for id,set in pairs(BtWLoadoutsSets.profiles) do
			if type(set) == "table" then
				loadouts[#loadouts+1] = id
			end
		end
		return unpack(loadouts);
	end
	-- Get a list of all currently active loadouts
	-- Return: id, ...
	function External.GetActiveLoadouts()
		wipe(loadouts);
		for id,set in pairs(BtWLoadoutsSets.profiles) do
			if type(set) == "table" and IsProfileActive(set) then
				loadouts[#loadouts+1] = id
			end
		end
		return unpack(loadouts);
	end
	-- Get a list of all loadouts valid for the current character
	-- Return: id, ...
	function External.GetCharacterLoadouts()
		wipe(loadouts);
		for id,set in pairs(BtWLoadoutsSets.profiles) do
			if type(set) == "table" and IsLoadoutActivatable(set) then
				loadouts[#loadouts+1] = id
			end
		end
		return unpack(loadouts);
	end
end

function Internal.SetsScrollFrameUpdate(self)
	self:GetScrollChild().currentDrag = nil -- Clear current drag

	local buttons = self.buttons
	local items = self.items
	local offset = HybridScrollFrame_GetOffset(self)
	
	if not buttons then
		return
	end

	local totalHeight, displayedHeight = #items * (buttons[1]:GetHeight() + 1), self:GetHeight()
	local hasScrollBar = totalHeight > displayedHeight

	for i,button in ipairs(buttons) do
		button:SetWidth(hasScrollBar and 530 or 540)

		local item = items[i+offset]
		button:Set(item)
	end
	HybridScrollFrame_Update(self, totalHeight, displayedHeight)
end
local function AddItem(items, index)
	item = items[index] or {}
	items[index] = item
	
	wipe(item)

	return item, index + 1
end
local function BuildSubSetItems(type, header, getcallback, sets, items, index, isCollapsed, errors)
	local item

	do
		item, index = AddItem(items, index)

		item.name = header
		item.type = type
		item.isCollapsed = isCollapsed
		item.isHeader = true
		-- item.isEmpty = subset == nil
	end
	
	if not isCollapsed then
		if #sets > 0 then
			for i,setID in ipairs(sets) do
				local subset = getcallback(setID)
				item, index = AddItem(items, index)
				
				if subset.character then
					local characterInfo = Internal.GetCharacterInfo(subset.character);
					if characterInfo then
						item.name = format("%s |cFFD5D5D5(%s - %s)|r", subset.name, characterInfo.name, characterInfo.realm);
					else
						item.name = format("%s |cFFD5D5D5(%s)|r", subset.name, subset.character);
					end
				else
					item.name = subset.name;
				end
	
				item.error = errors[i]
				item.type = type
				item.index = i
				item.id = subset.setID
				item.first = i == 1
				item.last = i == #sets
			end
		else
			item, index = AddItem(items, index)

			item.type = type
			item.name = L["Add"]
			item.isAdd = true
		end
	end

	return index
end
local function AddSeparator(items, index)
	-- item, index = AddItem(items, index)
	-- item.isSeparator = true
	return index
end
local function BuildSetItems(set, items, collapsed, errors)
	local index = 1

	index = BuildSubSetItems("talents", L["Talents"], Internal.GetTalentSet, set.talents, items, index, collapsed["talents"], errors["talents"])
	index = AddSeparator(items, index)

	index = BuildSubSetItems("pvptalents", L["PvP Talents"], Internal.GetPvPTalentSet, set.pvptalents, items, index, collapsed["pvptalents"], errors["pvptalents"])
	index = AddSeparator(items, index)

	index = BuildSubSetItems("essences", L["Essences"], Internal.GetEssenceSet, set.essences, items, index, collapsed["essences"], errors["essences"])
	index = AddSeparator(items, index)

	index = BuildSubSetItems("equipment", L["Equipment"], Internal.GetEquipmentSet, set.equipment, items, index, collapsed["equipment"], errors["equipment"])
	index = AddSeparator(items, index)

	index = BuildSubSetItems("actionbars", L["Action Bars"], Internal.GetActionBarSet, set.actionbars, items, index, collapsed["actionbars"], errors["actionbars"])

	while items[index] do
		table.remove(items, index)
	end

	return items
end

-- Stores errors for currently viewed set
local errors = {
	talents = {},
	pvptalents = {},
	essences = {},
	equipment = {},
	actionbars = {},
}
_G['BtWLoadoutsErrors'] = errors
function Internal.ProfilesTabUpdate(self)
	self:GetParent().TitleText:SetText(L["Profiles"]);
	self.set = Internal.SetsScrollFrame_SpecFilter(self.set, BtWLoadoutsSets.profiles, BtWLoadoutsCollapsed.profiles);

	self.Name:SetEnabled(self.set ~= nil);
	self.SpecDropDown.Button:SetEnabled(self.set ~= nil);

	self:GetParent().RefreshButton:SetEnabled(false)

	self.Collapsed = self.Collapsed or {}

	if self.set ~= nil then
		local hasErrors, errors, specID = GetLoadoutErrors(errors, self.set)
		if type(specID) == "number" and self.set.specID ~= specID then
			self.set.specID = specID;
			Internal.SetsScrollFrame_SpecFilter(self.set, BtWLoadoutsSets.profiles, BtWLoadoutsCollapsed.profiles);
		end

		specID = self.set.specID;

		if specID == nil or specID == 0 then
			UIDropDownMenu_SetText(self.SpecDropDown, L["None"]);
		else
			local _, specName, _, icon, _, classID = GetSpecializationInfoByID(specID);
			local className = LOCALIZED_CLASS_NAMES_MALE[classID];
			local classColor = GetClassColor(classID);
			UIDropDownMenu_SetText(self.SpecDropDown, format("%s: %s", classColor:WrapTextInColorCode(className), specName));
		end
		
		self.Enabled:SetEnabled(true);
		self.Enabled:SetChecked(not self.set.disabled);

		self.SetsScroll.items = BuildSetItems(self.set, self.SetsScroll.items or {}, self.Collapsed, errors)
		Internal.SetsScrollFrameUpdate(self.SetsScroll)
		
		if not self.Name:HasFocus() then
			self.Name:SetText(self.set.name or "");
		end

		local activateButton = self:GetParent().ActivateButton;
		activateButton:SetEnabled(not hasErrors and IsLoadoutActivatable(self.set));

		local deleteButton =  self:GetParent().DeleteButton;
		deleteButton:SetEnabled(true);

		local addButton = self:GetParent().AddButton;
		addButton.Flash:Hide();
		addButton.FlashAnim:Stop();

		local helpTipBox = self:GetParent().HelpTipBox;
		-- Tutorial stuff
		if not BtWLoadoutsHelpTipFlags["TUTORIAL_RENAME_SET"] then
			helpTipBox.closeFlag = "TUTORIAL_RENAME_SET";

			HelpTipBox_Anchor(helpTipBox, "TOP", self.Name);

			helpTipBox:Show();
			HelpTipBox_SetText(helpTipBox, L["Change the name of your new profile."]);
		elseif not BtWLoadoutsHelpTipFlags["TUTORIAL_CREATE_TALENT_SET"] then
			helpTipBox.closeFlag = "TUTORIAL_CREATE_TALENT_SET";

			HelpTipBox_Anchor(helpTipBox, "TOP", self.TalentsDropDown);

			helpTipBox:Show();
			HelpTipBox_SetText(helpTipBox, L["Create a talent set for your new profile."]);
		elseif not BtWLoadoutsHelpTipFlags["TUTORIAL_ACTIVATE_SET"] then
			helpTipBox.closeFlag = "TUTORIAL_ACTIVATE_SET";

			HelpTipBox_Anchor(helpTipBox, "TOP", activateButton);

			helpTipBox:Show();
			HelpTipBox_SetText(helpTipBox, L["Activate your profile."]);
		else
			helpTipBox.closeFlag = nil;
			helpTipBox:Hide();
		end
	else
		self.Name:SetText("");

		local activateButton = self:GetParent().ActivateButton;
		activateButton:SetEnabled(false);

		local deleteButton =  self:GetParent().DeleteButton;
		deleteButton:SetEnabled(false);

		local addButton = self:GetParent().AddButton;
		addButton.Flash:Show();
		addButton.FlashAnim:Play();

		local helpTipBox = self:GetParent().HelpTipBox;
		-- Tutorial stuff
		if not BtWLoadoutsHelpTipFlags["TUTORIAL_NEW_SET"] then
			helpTipBox.closeFlag = "TUTORIAL_NEW_SET";

			HelpTipBox_Anchor(helpTipBox, "TOP", addButton);

			helpTipBox:Show();
			HelpTipBox_SetText(helpTipBox, L["To begin, create a new set."]);
		else
			helpTipBox.closeFlag = nil;
			helpTipBox:Hide();
		end
	end
end