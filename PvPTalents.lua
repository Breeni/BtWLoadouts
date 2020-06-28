local ADDON_NAME,Internal = ...
local L = Internal.L

local UnitClass = UnitClass;
local GetClassColor = C_ClassColor.GetClassColor;
local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE;

local LearnPvpTalent = LearnPvpTalent;
local GetPvpTalentInfoByID = GetPvpTalentInfoByID;
local GetPvpTalentSlotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo;
local GetAllSelectedPvpTalentIDs = C_SpecializationInfo.GetAllSelectedPvpTalentIDs;

local GetSpecialization = GetSpecialization;
local GetSpecializationInfo = GetSpecializationInfo;
local GetSpecializationInfoByID = GetSpecializationInfoByID;

local UIDropDownMenu_SetText = UIDropDownMenu_SetText;
local UIDropDownMenu_EnableDropDown = UIDropDownMenu_EnableDropDown;
local UIDropDownMenu_DisableDropDown = UIDropDownMenu_DisableDropDown;
local UIDropDownMenu_SetSelectedValue = UIDropDownMenu_SetSelectedValue;

local format = string.format;

local HelpTipBox_Anchor = Internal.HelpTipBox_Anchor;
local HelpTipBox_SetText = Internal.HelpTipBox_SetText;

local function GetPvPTalentSet(id)
    if type(id) == "table" then
		return id;
	else
		return BtWLoadoutsSets.pvptalents[id];
	end
end
local function PvPTalentSetIsValid(set)
	local set = GetPvPTalentSet(set);

	local playerSpecID = GetSpecializationInfo(GetSpecialization());
	local playerClass = select(2, UnitClass("player"));
	local specClass = select(6, GetSpecializationInfoByID(set.specID));

	return true, (playerClass == specClass), (playerSpecID == set.specID)
end
local function IsPvPTalentSetActive(set)
	for talentID in pairs(set.talents) do
        local _, _, _, selected, available = GetPvpTalentInfoByID(talentID, 1);

        if not selected then
            return false;
        end
    end

    return true;
end
local function ActivatePvPTalentSet(set, checkExtraTalents)
	local success, complete = true, true;
	local talents = {};
	local usedSlots = {};

	for talentID in pairs(set.talents) do
		talents[talentID] = true;
	end

	for slot=1,4 do
		local slotInfo = GetPvpTalentSlotInfo(slot);
		local talentID = slotInfo.selectedTalentID;
		if talentID and talents[talentID] then
			usedSlots[slot] = true;
			talents[talentID] = nil;
		end
	end

	if checkExtraTalents then
		local talentIDs = GetAllSelectedPvpTalentIDs()
		for _,talentID in pairs(talentIDs) do
			if talents[talentID] then
				talents[talentID] = nil;
			end
		end
	end

	for slot=1,4 do
		local slotInfo = GetPvpTalentSlotInfo(slot);
		if not usedSlots[slot] and slotInfo.enabled then
			for _,talentID in ipairs(slotInfo.availableTalentIDs) do
				if talents[talentID] then
					local slotSuccess = LearnPvpTalent(talentID, slot)
					success = slotSuccess and success;
					complete = false

					usedSlots[slot] = true;
					talents[talentID] = nil;

					Internal.LogMessage("Switching pvp talent %d to %s (%s)", slot, GetPvpTalentLink(talentID), slotSuccess and "true" or "false")

					break;
				end
			end
		end
	end

	return complete
end
local function RefreshPvPTalentSet(set)
    local talents = set.talents or {}
    wipe(talents)

    local talentIDs = GetAllSelectedPvpTalentIDs();
    for _,talentID in ipairs(talentIDs) do
		talents[talentID] = true;
	end

    set.talents = talents

    return set
end
local function AddPvPTalentSet()
    local specID, specName = GetSpecializationInfo(GetSpecialization());
    local name = format(L["New %s Set"], specName);
	local talents = {};

    local talentIDs = GetAllSelectedPvpTalentIDs();
    for _,talentID in ipairs(talentIDs) do
		talents[talentID] = true;
    end

    local set = {
		setID = Internal.GetNextSetID(BtWLoadoutsSets.pvptalents),
        specID = specID,
        name = name,
        talents = talents,
		useCount = 0,
    };
    BtWLoadoutsSets.pvptalents[set.setID] = set;
    return set;
end
local function GetPvPTalentSetsByName(name)
	return Internal.GetSetsByName("pvptalents", name)
end
local function GetPvPTalentSetByName(name)
	return Internal.GetSetByName("pvptalents", name, PvPTalentSetIsValid)
end
function Internal.GetPvPTalentSets(id, ...)
	if id ~= nil then
		return BtWLoadoutsSets.pvptalents[id], Internal.GetPvPTalentSets(...);
	end
end
function Internal.GetPvPTalentSetIfNeeded(id)
	if id == nil then
		return;
	end

	local set = Internal.GetPvPTalentSet(id);
	if IsPvPTalentSetActive(set) then
		return;
	end

    return set;
end
local function CombinePvPTalentSets(result, ...)
	result = result or {};
	result.talents = {};

	for i=1,select('#', ...) do
		local set = select(i, ...);
		for talentID in pairs(set.talents) do
			if result.talents[talentID] == nil then
				result.talents[talentID] = true;
			end
		end
	end

	return result;
end
local function DeletePvPTalentSet(id)
	Internal.DeleteSet(BtWLoadoutsSets.pvptalents, id);

	if type(id) == "table" then
		id = id.setID;
	end
	for _,set in pairs(BtWLoadoutsSets.profiles) do
        if type(set) == "table" then
            for index,setID in ipairs(set.pvptalents) do
                if setID == id then
                    table.remove(set.pvptalents, index)
                end
            end
		end
	end

	local frame = BtWLoadoutsFrame.PvPTalents;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil;-- = select(2,next(BtWLoadoutsSets.pvptalents)) or {};
		BtWLoadoutsFrame:Update();
	end
end

Internal.GetPvPTalentSet = GetPvPTalentSet
Internal.GetPvPTalentSetsByName = GetPvPTalentSetsByName
Internal.GetPvPTalentSetByName = GetPvPTalentSetByName
Internal.AddPvPTalentSet = AddPvPTalentSet
Internal.RefreshPvPTalentSet = RefreshPvPTalentSet
Internal.DeletePvPTalentSet = DeletePvPTalentSet
Internal.ActivatePvPTalentSet = ActivatePvPTalentSet
Internal.IsPvPTalentSetActive = IsPvPTalentSetActive
Internal.CombinePvPTalentSets = CombinePvPTalentSets

local MAX_PVP_TALENTS = 15;
function Internal.PvPTalentsTabUpdate(self)
	self:GetParent().TitleText:SetText(L["PvP Talents"]);
	local sidebar = BtWLoadoutsFrame.Sidebar

	sidebar:SetSupportedFilters("spec", "class", "role", "character")
	sidebar:SetSets(BtWLoadoutsSets.pvptalents)
	sidebar:SetCollapsed(BtWLoadoutsCollapsed.pvptalents)
	sidebar:SetCategories(BtWLoadoutsCategories.pvptalents)
	sidebar:SetFilters(BtWLoadoutsFilters.pvptalents)
	sidebar:SetSelected(self.set)

	sidebar:Update()
	self.set = sidebar:GetSelected()
	-- self.set = Internal.SetsScrollFrame_SpecFilter(self.set, BtWLoadoutsSets.pvptalents, BtWLoadoutsCollapsed.pvptalents);

	if self.set ~= nil then
		self.Name:SetEnabled(true);
		self.SpecDropDown.Button:SetEnabled(true);
		self.trinkets:SetShown(true);
		self.others:SetShown(true);

		local specID = self.set.specID;

		local set = self.set

		-- Update filters
		do
			local filters = set.filters or {}
			filters.spec = specID
			if specID then
				filters.role, filters.class = select(5, GetSpecializationInfoByID(specID))
			else
				filters.role, filters.class = nil, nil
			end

			-- Rebuild character list
			filters.character = filters.character or {}
			local characters = filters.character
			wipe(characters)
			local class = filters.class
			for _,character in Internal.CharacterIterator() do
				if class == Internal.GetCharacterInfo(character).class then
					characters[#characters+1] = character
				end
			end

			set.filters = filters

			sidebar:Update()
		end


		local selected = self.set.talents;

		if not self.Name:HasFocus() then
			self.Name:SetText(self.set.name or "");
		end

		local _, specName, _, icon, _, classID = GetSpecializationInfoByID(specID);
		local className = LOCALIZED_CLASS_NAMES_MALE[classID];
		local classColor = GetClassColor(classID);
		UIDropDownMenu_SetText(self.SpecDropDown, format("%s: %s", classColor:WrapTextInColorCode(className), specName));

		if self.set.inUse then
			UIDropDownMenu_DisableDropDown(self.SpecDropDown);
		else
			UIDropDownMenu_EnableDropDown(self.SpecDropDown);
		end

		local trinkets = self.trinkets;
		for column=1,3 do
			local item = trinkets.talents[column];
			local talentID, name, texture, _, _, spellID = Internal.GetPvPTrinketTalentInfo(specID, column);

			item.isPvP = true;
			item.id = talentID;
			item.name:SetText(name);
			item.icon:SetTexture(texture);

			if selected[talentID] then
				item.knownSelection:Show();
				item.icon:SetDesaturated(false);
			else
				item.knownSelection:Hide();
				item.icon:SetDesaturated(true);
			end
		end

		local count = 0;
		for index=1,MAX_PVP_TALENTS do
			local talentID, name, texture, _, _, spellID = Internal.GetPvPTalentInfoForSpecID(specID, index);
			if talentID and selected[talentID] then
				count = count + 1;
			end
		end

		local others = self.others;
		for index=1,MAX_PVP_TALENTS do
			local item = others.talents[index];
			local talentID, name, texture, _, _, spellID = Internal.GetPvPTalentInfoForSpecID(specID, index);

			if talentID then
				item.isPvP = true;
				item.id = talentID;
				item.name:SetText(name);
				item.icon:SetTexture(texture);

				if selected[talentID] then
					item.Cover:SetShown(false);
					item:SetEnabled(true);

					item.knownSelection:Show();
					item.icon:SetDesaturated(false);
				else
					item.Cover:SetShown(count >= 3);
					item:SetEnabled(count < 3);

					item.knownSelection:Hide();
					item.icon:SetDesaturated(true);
				end

				item:Show();
			else
				item:Hide();
			end
		end

        local playerSpecIndex = GetSpecialization()
        self:GetParent().RefreshButton:SetEnabled(playerSpecIndex and specID == GetSpecializationInfo(playerSpecIndex))

		local activateButton = self:GetParent().ActivateButton;
		activateButton:SetEnabled(classID == select(2, UnitClass("player")));

		local deleteButton =  self:GetParent().DeleteButton;
		deleteButton:SetEnabled(true);

		local helpTipBox = self:GetParent().HelpTipBox;
		helpTipBox:Hide();

		local addButton = self:GetParent().AddButton;
		addButton.Flash:Hide();
		addButton.FlashAnim:Stop();
	else
		self.Name:SetEnabled(false);
		self.SpecDropDown.Button:SetEnabled(false);
		self.trinkets:SetShown(false);
		self.others:SetShown(false);

		self.Name:SetText("");

        self:GetParent().RefreshButton:SetEnabled(false)

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