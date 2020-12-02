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
local GetCharacterInfo = Internal.GetCharacterInfo;
local GetCharacterSlug = Internal.GetCharacterSlug

local loadoutSegments = {}
local loadoutSegmentsByID = {}
local loadoutSegmentsUIOrder = {}
_G['BtWLoadoutsLoadoutSegments'] = loadoutSegments; -- @TODO REMOVE

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
		[321923] = true,
		[324028] = true,
		[325012] = true, -- Swolkin ability
		[338907] = true, -- Refuge of the Damned
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
	local tomeLevelRequirements = {
		[141640] = {10, 50}, -- Tome of the Clear Mind
		[143780] = {10, 50}, -- Tome of the Tranquil Mind
		[143785] = {10, 50}, -- Tome of the Tranquil Mind
		[141446] = {10, 50}, -- Tome of the Tranquil Mind
		[153647] = {10, 59}, -- Tome of the Quiet Mind
		[173049] = {51, 60}, -- Tome of the Still Mind
	};
	local tomes = {
		141640, -- Tome of the Clear Mind
		143780, -- Tome of the Tranquil Mind
		143785, -- Tome of the Tranquil Mind
		141446, -- Tome of the Tranquil Mind
		153647, -- Tome of the Quiet Mind
		173049, -- Tome of the Still Mind
	};
	local function GetBestTome()
		local level = UnitLevel("player")
		for _,itemId in ipairs(tomes) do
			local count = GetItemCount(itemId);
			local minLevel, maxLevel = unpack(tomeLevelRequirements[itemId])
			if count >= 1 and minLevel <= level and maxLevel >= level then
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
local targetstate = {};
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
	wipe(targetstate);
	StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
	eventHandler:UnregisterAllEvents();
	eventHandler:Hide();
	Internal.Call("LOADOUT_CHANGE_END")
	Internal.LogMessage("--- END ---")
end
Internal.CancelActivateProfile = CancelActivateProfile;

local errorState = {} -- Reusable state for checking loadouts for errors
local function LoadoutHasErrors(set)
	wipe(errorState)

	errorState.specID = set.specID
	for _,segment in ipairs(loadoutSegments) do
		if segment.enabled and set[segment.id] then
			for index,subsetID in ipairs(set[segment.id]) do
				if segment.checkerrors then
					local error = segment.checkerrors(errorState, subsetID)
					if error then
						return true, errorState.specID
					end
				end
			end
		end
	end

	return false, errorState.specID
end
local function GetLoadoutErrors(errors, set)
	wipe(errorState)

	errorState.specID = set.specID
	local hasError = false

	for _,segment in ipairs(loadoutSegments) do
		if segment.enabled and set[segment.id] then
			local segmenterrors = errors[segment.id]
			if not segmenterrors then
				segmenterrors = {}
				errors[segment.id] = segmenterrors
			else
				wipe(errors[segment.id])
			end

			for index,subsetID in ipairs(set[segment.id]) do
				if segment.checkerrors then
					local error = segment.checkerrors(errorState, subsetID)
					if error then
						hasError = true
						errors[segment.id][index] = error
					end
				end
			end
		end
	end

	return hasError, errors, errorState.specID
end
-- Checks of a loadout is activatable
local function IsLoadoutActivatable(set)
	local specID = set.specID

	if specID and not Internal.CanSwitchToSpecialization(specID) then
		return false
	end

	return true
end

local function UpdateLoadoutFilters(set)
	local specID = set.specID

	local filters = set.filters or {}
	filters.spec = specID
	if specID then
		filters.role, filters.class = select(5, GetSpecializationInfoByID(specID))
	else
		filters.role, filters.class = nil, nil
	end

	-- Rebuild character list
	if type(filters.character) ~= "table" then
		filters.character = {}
	end
	local characters = filters.character
	wipe(characters)
	local class = filters.class
	for _,character in Internal.CharacterIterator() do
		if class == Internal.GetCharacterInfo(character).class or specID == nil then
			characters[#characters+1] = character
		end
	end

	set.filters = filters

    return set
end
local function AddProfile()
	local set = {
		name = L["New Profile"],
		version = 2,
		useCount = 0,
	}

	for _,segment in ipairs(loadoutSegments) do
		set[segment.id] = {}
	end

    return AddSet("profiles", UpdateLoadoutFilters(set))
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

        for _,segment in ipairs(loadoutSegments) do
            local ids = set[segment.id]
            if ids then
                for _,id in ipairs(ids) do
                    local subSet = segment.get(id)
                    subSet.useCount = (subSet.useCount or 1) - 1;
                end
            end
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
	target.state = targetstate

	if specID then
		target.specID = specID or profile.specID;
	end

	for _,segment in ipairs(loadoutSegments) do
		local id = segment.id
		if segment.enabled and profile[id] and #profile[id] > 0 then
			target[id] = target[id] or {};
			for _,setID in ipairs(profile[id]) do
				target[id][#target[id]+1] = setID;
			end
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
	if C_Covenants then -- Skip for pre-Shadowlands
		eventHandler:RegisterEvent("SOULBIND_ACTIVATED");
	end
	eventHandler:RegisterUnitEvent("UNIT_SPELLCAST_START", "player");
	eventHandler:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player");
	eventHandler:Show();
end
local IsProfileActive, AddWipeCacheEvents
do
	local state = {}
	local temp = {}
	local function IsActive(set)
		if set.specID then
			local playerSpecID = GetSpecializationInfo(GetSpecialization());
			if set.specID ~= playerSpecID then
				return false;
			end
		end

		wipe(state)
		for _,segment in ipairs(loadoutSegments) do
			local ids = set[segment.id]
			if segment.enabled and ids and #ids > 0 then
				wipe(temp);

				segment.combine(temp, state, segment.get(unpack(ids)));
				if not segment.isActive(temp) then
					return false;
				end
			end
		end

		return true;
	end
	local activeLoadoutCache = setmetatable({}, {
		__index = function(self, key)
			if type(key) == "number" then
				local result = activeLoadoutCache[GetProfile(key)]
				self[key] = result
				return result
			elseif type(key) == "table" then
				local result = IsActive(key)
				self[key] = result
				return result
			end
		end,
	});
	function IsProfileActive(set)
		return activeLoadoutCache[set]
	end
	local wipeEventHandler = CreateFrame("Frame");
	wipeEventHandler:Hide();
	wipeEventHandler:SetScript("OnEvent", function ()
		wipe(activeLoadoutCache);
	end);

	function AddWipeCacheEvents(...)
		for i=1,select('#', ...) do
			local event = select(i, ...)
			wipeEventHandler:RegisterEvent(event)
		end
	end
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
local combinedSets = {}
local function ContinueActivateProfile()
	local set = target
	local state = target.state
	set.dirty = false

	if Internal.CheckTimeout() then
		Internal.LogMessage("--- TIMEOUT ---")
		CancelActivateProfile()
		return
	end

	Internal.SetWaitReason() -- Clear wait reason
	Internal.UpdateLauncher(GetActiveProfiles());

	if IsChangingSpec() then
		Internal.SetWaitReason(L["Waiting for specialization change"])
		StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
        return;
	end

	wipe(state)
	local specID = set.specID;
	local playerSpecID = GetSpecializationInfo(GetSpecialization());
	if specID ~= nil and specID ~= playerSpecID then
		-- Need to change spec
		state.noCombatSwap = true
		state.noTaxiSwap = true
		state.noMovingSwap = true
	end

	wipe(combinedSets)
	for _,segment in ipairs(loadoutSegments) do
		if segment.enabled and target[segment.id] then
			combinedSets[segment.id] = segment.combine(combinedSets[segment.id], state, segment.get(unpack(target[segment.id])))
		end
	end

	if state.noCombatSwap and InCombatLockdown() then
		Internal.SetWaitReason(L["Waiting for combat to end"])
		StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
		return;
	end

	if state.noTaxiSwap and UnitOnTaxi("player") then
		Internal.SetWaitReason(L["Waiting for taxi ride to end"])
		StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
        return;
	end

	if state.noMovingSwap and IsPlayerMoving() then
		Internal.SetWaitReason(L["Waiting to change specialization"])
		StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
		return;
	end

	if specID ~= nil and specID ~= playerSpecID then
		for specIndex=1,GetNumSpecializations() do
			if GetSpecializationInfo(specIndex) == specID then
				Internal.LogMessage("Switching specialization to %s", (select(2, GetSpecializationInfo(specIndex))))
				Internal.SetWaitReason(L["Waiting for specialization change"])
				SetSpecialization(specIndex);
				target.dirty = false;
				return;
			end
		end
	end

	if state.customWait then
		Internal.SetWaitReason(state.customWait)
		StaticPopup_Hide("BTWLOADOUTS_NEEDTOME")
		return
	end

	if state.needTome and PlayerNeedsTome() then
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
	for _,segment in ipairs(loadoutSegments) do
		if segment.enabled and combinedSets[segment.id] then
			local segmentComplete, segmentDirty = segment.activate(combinedSets[segment.id], state)
			if not segmentComplete then
				complete = false
			end
			if segmentDirty then
				set.dirty = true
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
function eventHandler:SOULBIND_ACTIVATED(...)
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
do
	local function MustBeBefore(a, b)
		if b.after then
			for after in string.gmatch(b.after, "[^,]+") do
				if after == a.id then
					return true
				end
			end
		end

		return false
	end
	function Internal.AddLoadoutSegment(details)
		details.enabled = details.enabled == nil and true or details.enabled

		loadoutSegmentsUIOrder[#loadoutSegmentsUIOrder+1] = details
		loadoutSegmentsByID[details.id] = details

		if details.events then
			AddWipeCacheEvents(strsplit(",", details.events))
		end

		for index,segment in ipairs(loadoutSegments) do
			if MustBeBefore(details, segment) then
				table.insert(loadoutSegments, index, details)
				return
			end
		end
		loadoutSegments[#loadoutSegments+1] = details
	end
	function Internal.EnumerateLoadoutSegments()
		return function (tbl, index)
			repeat
				index = index + 1
			until not tbl[index] or tbl[index].enabled
			if tbl[index] then
				return index, tbl[index]
			end
		end, loadoutSegmentsUIOrder, 0
	end
	function Internal.GetLoadoutSegment(id)
		return loadoutSegmentsByID[id]
	end
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

BtWLoadoutsSetsScrollListItemMixin = {}
function BtWLoadoutsSetsScrollListItemMixin:OnLoad()
	self:RegisterForDrag("LeftButton");
end
function BtWLoadoutsSetsScrollListItemMixin:Set(item)
	self.item = item

	local button = self
	if item and not item.ignore then
		button.type = item.type
		button.isAdd = item.isAdd
		button.isHeader = item.isHeader

		button.name = item.name
		button.error = item.error
		button.ErrorBorder:SetShown(item.error ~= nil)
		button.ErrorOverlay:SetShown(item.error ~= nil)

		if item.isSeparator then
			button:Hide()
		else
			button.index = item.index
			button.id = item.id

			button:SetEnabled(not item.isHeader)
			if item.isHeader then
				button.Name:SetPoint("LEFT", 0, 0)
				button.Name:SetTextColor(0.75, 0.61, 0)
				
				-- if item.isEmpty then
					button.ExpandedIcon:Hide()
					button.CollapsedIcon:Hide()
				-- elseif item.isCollapsed then
				-- 	button.ExpandedIcon:Hide()
				-- 	button.CollapsedIcon:Show()
				-- else
				-- 	button.ExpandedIcon:Show()
				-- 	button.CollapsedIcon:Hide()
				-- end

				button.AddButton:Show()

				button.MoveButton:SetEnabled(false)
				button.MoveButton:Hide()

				button.RemoveButton:SetEnabled(false)
				button.RemoveButton:Hide()
			elseif item.isAdd then
				button.Name:SetPoint("LEFT", 15, 0)
				button.Name:SetTextColor(0.973, 0.937, 0.580)

				button.AddButton:Hide()

				button.MoveButton:SetEnabled(false)
				button.MoveButton:Hide()

				button.RemoveButton:SetEnabled(false)
				button.RemoveButton:Hide()

				button.ExpandedIcon:Hide()
				button.CollapsedIcon:Hide()
			else
				button.Name:SetPoint("LEFT", 15, 0)
				button.Name:SetTextColor(1, 1, 1)

				button.AddButton:Hide()

				button.MoveButton:SetEnabled(true)
				button.MoveButton:Hide()

				button.RemoveButton:SetEnabled(true)
				button.RemoveButton:Hide()

				-- button.AddButton:Hide()
				-- button.RemoveButton:Show()
				-- button.MoveDownButton:Show()
				-- button.MoveUpButton:Show()
				
				-- button.MoveUpButton:SetEnabled(not item.first)
				-- button.MoveDownButton:SetEnabled(not item.last)

				button.ExpandedIcon:Hide()
				button.CollapsedIcon:Hide()
			end

			button.Name:SetText(item.name)

			button:Show();
		end
	else
		button:Hide();
	end
end
function BtWLoadoutsSetsScrollListItemMixin:OnClick()
	if self.isHeader then
		local frame = self:GetParent():GetParent():GetParent()
		frame.Collapsed[self.type] = not frame.Collapsed[self.type]
		frame:Update()
	elseif self.isAdd then
		self:Add(self)
	else
		local DropDown = self:GetParent():GetParent().DropDown
		local index = self.index
		local segment = self.type
		UIDropDownMenu_SetInitializeFunction(DropDown, function (self, level, menuList)
			return Internal.GetLoadoutSegment(segment).dropdowninit(self, level, menuList, index)
		end)

		ToggleDropDownMenu(nil, nil, DropDown, self, 0, 0)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
end
function BtWLoadoutsSetsScrollListItemMixin:OnEnter()
	local scrollChild = self:GetParent()
	local currentDrag = scrollChild.currentDrag
	if currentDrag and currentDrag ~= self then
		if self.isHeader or self.isAdd or self.type ~= currentDrag.type then
			return
		end

		local frame = scrollChild:GetParent():GetParent()
		local a, b = self.item, currentDrag.item
	
		-- Flip the set ids within the loadout and flip their indexes too
		frame.set[a.type][a.index], frame.set[a.type][b.index] = frame.set[a.type][b.index], frame.set[a.type][a.index]
		a.index, b.index = b.index, a.index

		-- Update the buttons with the flipped sets
		self:Set(b)
		currentDrag:Set(a)

		self:GetParent().currentDrag = self

		return
	end

	self.MoveButton:SetShown(self.MoveButton:IsEnabled())
	self.RemoveButton:SetShown(self.RemoveButton:IsEnabled())

	if self.error then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.name, 1, 1, 1)
		GameTooltip:AddLine(format("\n|cffff0000%s|r", self.error))
		GameTooltip:Show()
	end
end
function BtWLoadoutsSetsScrollListItemMixin:OnLeave()
	if not MouseIsOver(self) then
		self.MoveButton:Hide()
		self.RemoveButton:Hide()
	end

	GameTooltip:Hide()
end
function BtWLoadoutsSetsScrollListItemMixin:StartDrag()
	if self.isHeader or self.isAdd then
		return
	end

	self:GetParent().currentDrag = self
end
function BtWLoadoutsSetsScrollListItemMixin:Add(button)
	local DropDown = self:GetParent():GetParent().DropDown
	
	UIDropDownMenu_SetInitializeFunction(DropDown, Internal.GetLoadoutSegment(self.type).dropdowninit)

	ToggleDropDownMenu(nil, nil, DropDown, button, 0, 0)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end
function BtWLoadoutsSetsScrollListItemMixin:Remove()
	local tab = self:GetParent():GetParent():GetParent()
	local set = tab.set

	local index = self.index
	assert(type(set[self.type]) == "table" and index ~= nil and index >= 1 and index <= #set[self.type])
	table.remove(set[self.type], index);

	tab:Update()
end
function BtWLoadoutsSetsScrollListItemMixin:MoveUp()
	local tab = self:GetParent():GetParent():GetParent()
	local set = tab.set

	local index = self.index
	assert(type(set[self.type]) == "table" and index > 1 and index <= #set[self.type])
	set[self.type][index-1], set[self.type][index] = set[self.type][index], set[self.type][index-1]

	tab:Update()
end
function BtWLoadoutsSetsScrollListItemMixin:MoveDown()
	local tab = self:GetParent():GetParent():GetParent()
	local set = tab.set

	local index = self.index
	assert(type(set[self.type]) == "table" and index >= 1 and index < #set[self.type])
	set[self.type][index+1], set[self.type][index] = set[self.type][index], set[self.type][index+1]

	tab:Update()
end

local function SetsScrollFrameUpdate(self)
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
		if sets and #sets > 0 then
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

	for i,segment in Internal.EnumerateLoadoutSegments() do
		if i ~= 1 then
			index = AddSeparator(items, index)
		end
		index = BuildSubSetItems(segment.id, segment.name, segment.get, set[segment.id], items, index, collapsed[segment.id], errors[segment.id])
	end

	while items[index] do
		table.remove(items, index)
	end

	return items
end

-- Stores errors for currently viewed set
local errors = {}
_G['BtWLoadoutsErrors'] = errors

BtWLoadoutsProfilesMixin = {}
function BtWLoadoutsProfilesMixin:OnLoad()
	self:RegisterEvent("GLOBAL_MOUSE_UP")
	
	self.SpecDropDown.includeNone = true;
	UIDropDownMenu_SetWidth(self.SpecDropDown, 300);
	UIDropDownMenu_JustifyText(self.SpecDropDown, "LEFT");

	HybridScrollFrame_CreateButtons(self.SetsScroll, "BtWLoadoutsSetsScrollListItemTemplate", 4, -3, "TOPLEFT", "TOPLEFT", 0, -1, "TOP", "BOTTOM");
	self.SetsScroll.update = SetsScrollFrameUpdate;
end
function BtWLoadoutsProfilesMixin:OnEvent()
	if self.SetsScroll:GetScrollChild().currentDrag  ~= nil then
		self:GetParent():Update()
	end
end
function BtWLoadoutsProfilesMixin:OnShow()
	
end
function BtWLoadoutsProfilesMixin:ChangeSet(set)
    self.set = set
    self:Update()
end
function BtWLoadoutsProfilesMixin:UpdateSetEnabled(value)
	if self.set and self.set.disabled ~= not value then
		self.set.disabled = not value;
		self:Update();
	end
end
function BtWLoadoutsProfilesMixin:UpdateSetName(value)
	if self.set and self.set.name ~= not value then
		self.set.name = value;
		self:Update();
	end
end
function BtWLoadoutsProfilesMixin:OnButtonClick(button)
	CloseDropDownMenus()
	if button.isAdd then
		BtWLoadoutsHelpTipFlags["TUTORIAL_NEW_SET"] = true;

		self.Name:ClearFocus()
		self:ChangeSet(AddProfile())
		
		C_Timer.After(0, function ()
			self.Name:HighlightText()
			self.Name:SetFocus()
		end)
	elseif button.isDelete then
		local set = self.set
		if set.useCount > 0 then
			StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
				set = set,
				func = DeleteProfile,
			})
		else
			StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
				set = set,
				func = DeleteProfile,
			})
		end
	elseif button.isRefresh then
		-- Do nothing
	elseif button.isActivate then
		BtWLoadoutsHelpTipFlags["TUTORIAL_ACTIVATE_SET"] = true

		ActivateProfile(self.set)
		self:Update()
	end
end
function BtWLoadoutsProfilesMixin:OnSidebarItemClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		button.collapsed[button.id] = not button.collapsed[button.id]
		self:Update()
	else
		if IsModifiedClick("SHIFT") then
			ActivateProfile(GetProfile(button.id));
		else
			self.Name:ClearFocus();
			self:ChangeSet(GetProfile(button.id));
		end
	end
end
function BtWLoadoutsProfilesMixin:OnSidebarItemDoubleClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		return
	end

	ActivateProfile(GetProfile(button.id));
end
function BtWLoadoutsProfilesMixin:OnSidebarItemDragStart(button)
	CloseDropDownMenus()
	if button.isHeader then
		return
	end

	local icon = "INV_Misc_QuestionMark";
	local set = GetProfile(button.id);
	local command = format("/btwloadouts activate profile %d", button.id);
	if set.specID then
		icon = select(4, GetSpecializationInfoByID(set.specID));
	end

	if command then
		local macroId;
		local numMacros = GetNumMacros();
		for i=1,numMacros do
			if GetMacroBody(i):trim() == command then
				macroId = i;
				break;
			end
		end

		if not macroId then
			if numMacros == MAX_ACCOUNT_MACROS then
				print(L["Cannot create any more macros"]);
				return;
			end
			if InCombatLockdown() then
				print(L["Cannot create macros while in combat"]);
				return;
			end

			macroId = CreateMacro(set.name, icon, command, false);
		else
			-- Rename the macro while not in combat
			if not InCombatLockdown() then
				icon = select(2,GetMacroInfo(macroId))
				EditMacro(macroId, set.name, icon, command)
			end
		end

		if macroId then
			PickupMacro(macroId);
		end
	end
end
function BtWLoadoutsProfilesMixin:Update()
	self:GetParent().TitleText:SetText(L["Profiles"]);
	local sidebar = BtWLoadoutsFrame.Sidebar

	sidebar:SetSupportedFilters("spec", "class", "role", "character")
	sidebar:SetSets(BtWLoadoutsSets.profiles)
	sidebar:SetCollapsed(BtWLoadoutsCollapsed.profiles)
	sidebar:SetCategories(BtWLoadoutsCategories.profiles)
	sidebar:SetFilters(BtWLoadoutsFilters.profiles)
	sidebar:SetSelected(self.set)
	
	sidebar:Update()
	self.set = sidebar:GetSelected()

	self.Name:SetEnabled(self.set ~= nil);
	self.SpecDropDown.Button:SetEnabled(self.set ~= nil);

	self:GetParent().RefreshButton:SetEnabled(false)

	self.Collapsed = self.Collapsed or {}

	if self.set ~= nil then
		local hasErrors, errors, specID = GetLoadoutErrors(errors, self.set)
		if type(specID) == "number" and self.set.specID == nil then
			self.set.specID = specID
		end

		specID = self.set.specID;

		local set = self.set

		UpdateLoadoutFilters(set)
		sidebar:Update()
		
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
		SetsScrollFrameUpdate(self.SetsScroll)
		
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

		self.SetsScroll.items = self.SetsScroll.items or {}
		wipe(self.SetsScroll.items)
		SetsScrollFrameUpdate(self.SetsScroll)

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