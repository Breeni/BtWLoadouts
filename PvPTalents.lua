local ADDON_NAME,Internal = ...
local L = Internal.L

local UnitClass = UnitClass;
local GetClassColor = C_ClassColor.GetClassColor;
local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE;

local LearnPvpTalent = LearnPvpTalent;
local GetPvpTalentSlotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo;
local GetPvpTalentUnlockLevel = C_SpecializationInfo.GetPvpTalentUnlockLevel;
local GetAllSelectedPvpTalentIDs = C_SpecializationInfo.GetAllSelectedPvpTalentIDs;
local GetPvpTalentSlotInfoForSpecID = Internal.GetPvpTalentSlotInfoForSpecID;

local GetSpecialization = GetSpecialization;
local GetSpecializationInfo = GetSpecializationInfo;
local GetSpecializationInfoByID = GetSpecializationInfoByID;

local UIDropDownMenu_SetText = UIDropDownMenu_SetText;
local UIDropDownMenu_EnableDropDown = UIDropDownMenu_EnableDropDown;
local UIDropDownMenu_DisableDropDown = UIDropDownMenu_DisableDropDown;
local UIDropDownMenu_SetSelectedValue = UIDropDownMenu_SetSelectedValue;

local AddSet = Internal.AddSet;

local format = string.format;

local HelpTipBox_Anchor = Internal.HelpTipBox_Anchor;
local HelpTipBox_SetText = Internal.HelpTipBox_SetText;

-- Make sure talent sets dont have incorrect id, call from GetTalentSet and the UI?
local function FixPvPTalentSet(set)
    local changed = false
    for talentID in pairs(set.talents) do
        local available = Internal.VerifyPvPTalentForSpec(set.specID, talentID)
        if not available then
            set.talents[talentID] = nil
            changed = true
        end
    end
    return changed
end
local function UpdatePvPTalentSetFilters(set)
    local specID = set.specID;

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
	table.wipe(characters)
	local class = filters.class
	for _,character in Internal.CharacterIterator() do
		if class == Internal.GetCharacterInfo(character).class then
			characters[#characters+1] = character
		end
	end

	set.filters = filters

    return set
end
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
	local playerLevel = UnitLevel("player")
	local talents = {};
	local slots = {}

	-- Clone the talents list so we can remove things as needed
	for talentID in pairs(set.talents) do
		if GetPvpTalentUnlockLevel(talentID) <= playerLevel then
			talents[talentID] = true;
		end
	end

	-- All the talents arent available yet so we are as active as we can get
	if next(talents) == nil then
		return true
	end

	local index = 1
	local slotInfo = GetPvpTalentSlotInfo(index)
	while slotInfo do
		if slotInfo.enabled then
			if slotInfo.selectedTalentID and talents[slotInfo.selectedTalentID] then
				talents[slotInfo.selectedTalentID] = nil
			else
				slots[slotInfo] = true
			end
		end

		index = index + 1
		slotInfo = GetPvpTalentSlotInfo(index)
	end

	-- All the talents that are available are currenctly active
	if next(talents) == nil then
		return true
	end

	for slotInfo in pairs(slots) do
		for _,talentID in ipairs(slotInfo.availableTalentIDs) do
			-- One of the talents that is available can go in a free slot so we arent active yet
			if talents[talentID] then
				return false
			end
		end
	end

    return true;
end
local function ActivatePvPTalentSet(set, state)
	local success, complete = true, true;
	local talents = {};
	local usedSlots = {};

	for talentID in pairs(set.talents) do
		talents[talentID] = true;
	end

	local index = 1
	local slotInfo = GetPvpTalentSlotInfo(index)
	while slotInfo do
		local talentID = slotInfo.selectedTalentID;
		if talentID and talents[talentID] then
			usedSlots[index] = true;
			talents[talentID] = nil;
		end

		index = index + 1
		slotInfo = GetPvpTalentSlotInfo(index)
	end

	if state.conflictAndStrife then
		local talentIDs = GetAllSelectedPvpTalentIDs()
		for _,talentID in pairs(talentIDs) do
			if talents[talentID] then
				talents[talentID] = nil;
			end
		end
	end

	local index = 1
	local slotInfo = GetPvpTalentSlotInfo(index)
	while slotInfo do
		if not usedSlots[index] and slotInfo.enabled then
			for _,talentID in ipairs(slotInfo.availableTalentIDs) do
				if talents[talentID] then
					local slotSuccess = LearnPvpTalent(talentID, index)
					success = slotSuccess and success;
					complete = false

					usedSlots[index] = true;
					talents[talentID] = nil;

					Internal.LogMessage("Switching pvp talent %d to %s (%s)", index, GetPvpTalentLink(talentID), slotSuccess and "true" or "false")

					break;
				end
			end
		end

		index = index + 1
		slotInfo = GetPvpTalentSlotInfo(index)
	end

	return complete, false
end
local function RefreshPvPTalentSet(set)
    local talents = set.talents or {}
    wipe(talents)

    local talentIDs = GetAllSelectedPvpTalentIDs();
    for _,talentID in ipairs(talentIDs) do
		talents[talentID] = true;
	end

    set.talents = talents

    return UpdatePvPTalentSetFilters(set)
end
local function AddPvPTalentSet()
    local specID, specName = GetSpecializationInfo(GetSpecialization());
    return AddSet("pvptalents", RefreshPvPTalentSet({
        specID = specID,
		name = format(L["New %s Set"], specName),
		useCount = 0,
        talents = {},
	}))
end
local function GetPvPTalentSetsByName(name)
	return Internal.GetSetsByName("pvptalents", name)
end
local function GetPvPTalentSetByName(name)
	return Internal.GetSetByName("pvptalents", name, PvPTalentSetIsValid)
end
local function GetPvPTalentSets(id, ...)
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
local function CombinePvPTalentSets(result, state, ...)
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

	if state then
		state.noCombatSwap = true
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
local function CheckErrors(errorState, set)
    set = GetPvPTalentSet(set)
    errorState.specID = errorState.specID or set.specID

    if errorState.specID ~= set.specID then
        return L["Incompatible Specialization"]
    end
end

Internal.FixPvPTalentSet = FixPvPTalentSet
Internal.GetPvPTalentSet = GetPvPTalentSet
Internal.GetPvPTalentSetsByName = GetPvPTalentSetsByName
Internal.GetPvPTalentSetByName = GetPvPTalentSetByName
Internal.AddPvPTalentSet = AddPvPTalentSet
Internal.RefreshPvPTalentSet = RefreshPvPTalentSet
Internal.DeletePvPTalentSet = DeletePvPTalentSet
Internal.ActivatePvPTalentSet = ActivatePvPTalentSet
Internal.IsPvPTalentSetActive = IsPvPTalentSetActive
Internal.CombinePvPTalentSets = CombinePvPTalentSets
Internal.GetPvPTalentSets = GetPvPTalentSets

local setsFiltered = {};
local function PvPTalentsDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Profiles

	CloseDropDownMenus();
	local set = tab.set;
	local index = arg2 or (#set.pvptalents + 1)

	if set.pvptalents[index] then
		local subset = Internal.GetPvPTalentSet(set.pvptalents[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	if arg1 == nil then
		table.remove(set.pvptalents, index);
	else
		set.pvptalents[index] = arg1;
	end

	if set.pvptalents[index] then
		local subset = Internal.GetPvPTalentSet(set.pvptalents[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame:Update();
end
local function PvPTalentsDropDown_NewOnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Profiles

	CloseDropDownMenus();
	local set = tab.set;
	local index = arg2 or (#set.pvptalents + 1)

	if set.pvptalents[index] then
		local subset = Internal.GetPvPTalentSet(set.pvptalents[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local newSet = Internal.AddPvPTalentSet();
	set.pvptalents[index] = newSet.setID;

	if set.pvptalents[index] then
		local subset = Internal.GetPvPTalentSet(set.pvptalents[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame.PvPTalents.set = newSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, BtWLoadoutsFrame.PvPTalents:GetID());

	BtWLoadoutsFrame:Update();
end
local function PvPTalentsDropDownInit(self, level, menuList, index)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.pvptalents then
        return;
	end

	local info = UIDropDownMenu_CreateInfo();

	local tab = BtWLoadoutsFrame.Profiles

	local set = tab.set;
	local selected = set and set.pvptalents and set.pvptalents[index];

	info.arg2 = index

	if (level or 1) == 1 then
		info.text = NONE;
		info.func = PvPTalentsDropDown_OnClick;
		info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

		wipe(setsFiltered);
		local sets = BtWLoadoutsSets.pvptalents;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" then
				setsFiltered[subset.specID] = true;
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

		info.text = L["New Set"];
		info.func = PvPTalentsDropDown_NewOnClick;
		info.hasArrow, info.menuList = false, nil;
		info.keepShownOnClick = false;
		info.notCheckable = true;
		info.checked = false;
		UIDropDownMenu_AddButton(info, level);
	else
		local specID = menuList;

		wipe(setsFiltered);
		local sets = BtWLoadoutsSets.pvptalents;
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
			info.func = PvPTalentsDropDown_OnClick;
			info.checked = selected == setID;
			UIDropDownMenu_AddButton(info, level);
		end
	end
end

Internal.AddLoadoutSegment({
    id = "pvptalents",
    name = L["PvP Talents"],
    after = "essences", -- Essences can give pvp talents
    events = "PLAYER_PVP_TALENT_UPDATE",
    get = GetPvPTalentSets,
    combine = CombinePvPTalentSets,
    isActive = IsPvPTalentSetActive,
	activate = ActivatePvPTalentSet,
	dropdowninit = PvPTalentsDropDownInit,
    checkerrors = CheckErrors,
})

local function CompareTalentList(a, b)
	if #a ~= #b then
		return false
	end

	for i=1,#a do
		if a[i] ~= b[i] then
			return false
		end
	end

	return true
end

BtWLoadoutsPvPTalentsMixin = {}
function BtWLoadoutsPvPTalentsMixin:OnLoad()
	self.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
	self.GridPool = CreateFramePool("FRAME", self, "BtWLoadoutsTalentSelectionTemplate")
end
function BtWLoadoutsPvPTalentsMixin:OnShow()
    if not self.initialized then
        UIDropDownMenu_SetWidth(self.SpecDropDown, 170);
        UIDropDownMenu_JustifyText(self.SpecDropDown, "LEFT");

        self.initialized = true;
    end
end
function BtWLoadoutsPvPTalentsMixin:ChangeSet(set)
    self.set = set
    self:Update()
end
function BtWLoadoutsPvPTalentsMixin:UpdateSetName(value)
	if self.set and self.set.name ~= not value then
		self.set.name = value;
		self:Update();
	end
end
function BtWLoadoutsPvPTalentsMixin:OnButtonClick(button)
	CloseDropDownMenus()
	if button.isAdd then
		self.Name:ClearFocus();
		self:ChangeSet(AddPvPTalentSet())
		C_Timer.After(0, function ()
			self.Name:HighlightText();
			self.Name:SetFocus();
		end)
	elseif button.isDelete then
		local set = self.set;
		if set.useCount > 0 then
			StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
				set = set,
				func = DeletePvPTalentSet,
			});
		else
			StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
				set = set,
				func = DeletePvPTalentSet,
			});
		end
	elseif button.isRefresh then
		local set = self.set;
		RefreshPvPTalentSet(set)
		self:Update()
	elseif button.isActivate then
		local set = self.set;
		if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
			Internal.ActivateProfile({
				pvptalents = {set.setID}
			});
		end
	end
end
function BtWLoadoutsPvPTalentsMixin:OnSidebarItemClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		button.collapsed[button.id] = not button.collapsed[button.id]
		self:Update()
	else
		if IsModifiedClick("SHIFT") then
			local set = GetPvPTalentSet(button.id);
			if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
				Internal.ActivateProfile({
					pvptalents = {button.id}
				});
			end
		else
			self.Name:ClearFocus();
			self:ChangeSet(GetPvPTalentSet(button.id))
		end
	end
end
function BtWLoadoutsPvPTalentsMixin:OnSidebarItemDoubleClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		return
	end

	local set = GetPvPTalentSet(button.id);
	if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
		Internal.ActivateProfile({
			pvptalents = {button.id}
		});
	end
end
function BtWLoadoutsPvPTalentsMixin:OnSidebarItemDragStart(button)
	CloseDropDownMenus()
	if button.isHeader then
		return
	end

	local icon = "INV_Misc_QuestionMark";
	local set = GetPvPTalentSet(button.id);
	local command = format("/btwloadouts activate pvptalents %d", button.id);
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
function BtWLoadoutsPvPTalentsMixin:Update()
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

	if self.set ~= nil then
		self.Name:SetEnabled(true);
		self.SpecDropDown.Button:SetEnabled(true);
		-- self.trinkets:SetShown(true);
		-- self.others:SetShown(true);

		local specID = self.set.specID;

		local set = self.set

		UpdatePvPTalentSetFilters(set)
		sidebar:Update()

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

		do
			self.GridPool:ReleaseAll()

			local previous
			local index = 1
			local slotInfo = GetPvpTalentSlotInfoForSpecID(specID, index)
			while slotInfo do
				local slotGrid

				for grid in self.GridPool:EnumerateActive() do
					if CompareTalentList(grid.talents, slotInfo.availableTalentIDs) then
						grid:SetMaxSelections(grid:GetMaxSelections() + 1)
						slotGrid = grid
					end
				end

				if not slotGrid then
					slotGrid = self.GridPool:Acquire()
					slotGrid:SetTalents(slotInfo.availableTalentIDs, true)
					slotGrid:SetMaxSelections(1)

					if previous then
						slotGrid:SetPoint("TOP", previous, "BOTTOM")
					else
						slotGrid:SetPoint("TOPLEFT", 0, -38)
					end
					slotGrid:Show()

					previous = slotGrid
				end

				index = index + 1
				slotInfo = GetPvpTalentSlotInfoForSpecID(specID, index)
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
		-- self.trinkets:SetShown(false);
		-- self.others:SetShown(false);

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