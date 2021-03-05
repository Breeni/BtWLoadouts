local ADDON_NAME,Internal = ...
local L = Internal.L
local Settings = Internal.Settings

local UnitClass = UnitClass;
local GetClassColor = C_ClassColor.GetClassColor;
local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE;

local MAX_TALENT_TIERS = MAX_TALENT_TIERS;
local LearnTalent = LearnTalent;
local GetTalentInfo = GetTalentInfo;
local GetTalentTierInfo = GetTalentTierInfo;
local GetTalentInfoByID = GetTalentInfoByID
local GetTalentInfoForSpecID = Internal.GetTalentInfoForSpecID;

local GetSpecialization = GetSpecialization;
local GetSpecializationInfo = GetSpecializationInfo;
local GetSpecializationInfoByID = GetSpecializationInfoByID;

local UIDropDownMenu_SetText = UIDropDownMenu_SetText;
local UIDropDownMenu_EnableDropDown = UIDropDownMenu_EnableDropDown;
local UIDropDownMenu_DisableDropDown = UIDropDownMenu_DisableDropDown;
local UIDropDownMenu_SetSelectedValue = UIDropDownMenu_SetSelectedValue;

local format = string.format

local AddSet = Internal.AddSet;
local DeleteSet = Internal.DeleteSet;

local HelpTipBox_Anchor = Internal.HelpTipBox_Anchor;
local HelpTipBox_SetText = Internal.HelpTipBox_SetText;

do -- Filter chat spam
    local filters = {
        string.gsub(ERR_LEARN_ABILITY_S, "%%s", "(.*)"),
        string.gsub(ERR_LEARN_SPELL_S, "%%s", "(.*)"),
        string.gsub(ERR_LEARN_PASSIVE_S, "%%s", "(.*)"),
        string.gsub(ERR_SPELL_UNLEARNED_S, "%%s", "(.*)"),
    }
    local function ChatFrame_FilterTalentChanges(self, event, msg, ...)
        if Settings.filterChatSpam then
            for _,pattern in ipairs(filters) do
                if string.match(msg, pattern) then
                    return true
                end
            end
        end

        return false, msg, ...
    end

    Internal.OnEvent("LOADOUT_CHANGE_START", function ()
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", ChatFrame_FilterTalentChanges)
    end)
    Internal.OnEvent("LOADOUT_CHANGE_END", function ()
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", ChatFrame_FilterTalentChanges)
    end)
end

do -- Prevent new spells from flying to the action bar
    local WasEventRegistered
    Internal.OnEvent("LOADOUT_CHANGE_START", function ()
        WasEventRegistered = IconIntroTracker:IsEventRegistered("SPELL_PUSHED_TO_ACTIONBAR")
        IconIntroTracker:UnregisterEvent("SPELL_PUSHED_TO_ACTIONBAR")
    end)
    Internal.OnEvent("LOADOUT_CHANGE_END", function ()
        if WasEventRegistered then
            IconIntroTracker:RegisterEvent("SPELL_PUSHED_TO_ACTIONBAR")
        end
    end)
end

-- Make sure talent sets dont have incorrect id, call from GetTalentSet and the UI?
local function FixTalentSet(set)
    local temp = {}
    local changed = false
    for talentID in pairs(set.talents) do
        local tier, column = Internal.VerifyTalentForSpec(set.specID, talentID)
        if tier == nil or temp[tier] then
            set.talents[talentID] = nil
            changed = true
        else
            temp[tier] = talentID
        end
    end
    return changed
end
local function UpdateTalentSetFilters(set)
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
local function GetTalentSet(id)
    if type(id) == "table" then
		return id;
	else
		return BtWLoadoutsSets.talents[id];
	end;
end
-- In General, For Player, For Player Spec
local function TalentSetIsValid(set)
	set = GetTalentSet(set);

	local playerSpecID = GetSpecializationInfo(GetSpecialization());
	local playerClass = select(2, UnitClass("player"));
	local specClass = select(6, GetSpecializationInfoByID(set.specID));

	return true, (playerClass == specClass), (playerSpecID == set.specID)
end
-- Check if the talents in the table talentIDs are selected
local function IsTalentSetActive(set)
    for talentID in pairs(set.talents) do
        local _, _, _, selected, _, _, _, tier = GetTalentInfoByID(talentID, 1);
        local tierAvailable = GetTalentTierInfo(tier, 1)

        -- For lower level characters just ignore tiers over their currently available
        if tierAvailable and not selected then
            return false;
        end
    end

    return true;
end
--[[
    Activate a talent set
    return complete, dirty
]]
local function ActivateTalentSet(set)
	local success, complete = true, true;
	for talentID in pairs(set.talents) do
		local selected, _, _, _, tier = select(4, GetTalentInfoByID(talentID, 1));
        if not selected and GetTalentTierInfo(tier, 1) then
            local slotSuccess = LearnTalent(talentID)
            success = slotSuccess and success
            complete = false

            Internal.LogMessage("Switching talent %d to %s (%s)", tier, GetTalentLink(talentID, 1), slotSuccess and "true" or "false")
		end
    end

	return complete, false;
end
local function RefreshTalentSet(set)
    local talents = set.talents or {}
    wipe(talents)
	for tier=1,MAX_TALENT_TIERS do
        local _, column = GetTalentTierInfo(tier, 1);
        local talentID = GetTalentInfo(tier, column, 1);
        if talentID then
            talents[talentID] = true;
        end
    end
    set.talents = talents

    return UpdateTalentSetFilters(set)
end
local function AddTalentSet()
    local specID, specName = GetSpecializationInfo(GetSpecialization());
    return AddSet("talents", RefreshTalentSet({
        specID = specID,
		name = format(L["New %s Set"], specName),
		useCount = 0,
        talents = {},
    }))
end
local function TalentSetDelay(set)
    for talentID in pairs(set.talents) do
        local row = select(8, GetTalentInfoByID(talentID, 1))
        local column = select(2, GetTalentTierInfo(row, 1))
        local selectedTalentID, _, _, _, _, spellID = GetTalentInfo(row, column, 1)
        if selectedTalentID ~= talentID and spellID then
			spellID = FindSpellOverrideByID(spellID)
			local start, duration = GetSpellCooldown(spellID)
			if start ~= 0 then -- Talent spell on cooldown, we need to wait before switching
				Internal.DirtyAfter((start + duration) - GetTime() + 1)
				return true
			end
        end
    end
    return false
end
--[[
    Check what is needed to activate this talent set
    return isActive, waitForCooldown, anySelected
]]
local function TalentSetRequirements(set)
    local isActive, waitForCooldown, anySelected = true, false, false

    for talentID in pairs(set.talents) do
        local row = select(8, GetTalentInfoByID(talentID, 1))
        local available, column = GetTalentTierInfo(row, 1)
        if available then
            local selectedTalentID, _, _, _, _, spellID = GetTalentInfo(row, column, 1)

            if selectedTalentID ~= talentID then
                isActive = false

                if spellID then
                    spellID = FindSpellOverrideByID(spellID)
                    local start, duration = GetSpellCooldown(spellID)
                    if start ~= 0 then -- Talent spell on cooldown, we need to wait before switching
                        Internal.DirtyAfter((start + duration) - GetTime() + 1)
                        waitForCooldown = true
                        break -- We dont actually need to check anything more
                    end
                end

                if column ~= 0 then
                    anySelected = true
                end
            end
        end
    end

    return isActive, waitForCooldown, anySelected
end
local function GetTalentSetsByName(name)
	return Internal.GetSetsByName("talents", name)
end
local function GetTalentSetByName(name)
	return Internal.GetSetByName("talents", name, TalentSetIsValid)
end
local function GetTalentSets(id, ...)
	if id ~= nil then
		return GetTalentSet(id), GetTalentSets(...);
	end
end
local function GetTalentSetIfNeeded(id)
	if id == nil then
		return;
	end

	local set = Internal.GetTalentSet(id);
	if IsTalentSetActive(set) then
		return;
	end

    return set;
end
local talentSetsByTier = {};
local function CombineTalentSets(result, state, ...)
	result = result or {};
	result.talents = {};

	wipe(talentSetsByTier);
	for i=1,select('#', ...) do
		local set = Internal.GetTalentSet(select(i, ...));
		for talentID in pairs(set.talents) do
			if result.talents[talentID] == nil then
				local tier = select(8, GetTalentInfoByID(talentID, 1));
                if (GetTalentTierInfo(tier, 1)) then
                    if talentSetsByTier[tier] then
                        result.talents[talentSetsByTier[tier]] = nil;
                    end

                    result.talents[talentID] = true;
                    talentSetsByTier[tier] = talentID;
                end
			end
		end
    end

    if state then
        state.noCombatSwap = true
        state.noTaxiSwap = true -- Maybe check for rested area or tomb first?

        if not state.customWait or not state.needTome then
            local isActive, waitForCooldown, anySelected = TalentSetRequirements(result)

            state.needTome = state.needTome or (not isActive and anySelected)
            state.customWait = state.customWait or (waitForCooldown and L["Waiting for talent cooldown"])
        end
    end

	return result;
end
local function DeleteTalentSet(id)
	Internal.DeleteSet(BtWLoadoutsSets.talents, id);

	if type(id) == "table" then
		id = id.setID;
	end
	for _,set in pairs(BtWLoadoutsSets.profiles) do
        if type(set) == "table" then
            for index,setID in ipairs(set.talents) do
                if setID == id then
                    table.remove(set.talents, index)
                end
            end
		end
	end

	local frame = BtWLoadoutsFrame.Talents;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil;-- = select(2,next(BtWLoadoutsSets.talents)) or {};
		BtWLoadoutsFrame:Update();
	end
end
local function CheckErrors(errorState, set)
    set = GetTalentSet(set)
    errorState.specID = errorState.specID or set.specID

    if errorState.specID ~= set.specID then
        return L["Incompatible Specialization"]
    end
end

Internal.FixTalentSet = FixTalentSet
Internal.GetTalentSet = GetTalentSet
Internal.GetTalentSets = GetTalentSets
Internal.GetTalentSetIfNeeded = GetTalentSetIfNeeded
Internal.GetTalentSetsByName = GetTalentSetsByName
Internal.GetTalentSetByName = GetTalentSetByName
Internal.TalentSetDelay = TalentSetDelay
Internal.AddTalentSet = AddTalentSet
Internal.RefreshTalentSet = RefreshTalentSet
Internal.DeleteTalentSet = DeleteTalentSet
Internal.ActivateTalentSet = ActivateTalentSet
Internal.IsTalentSetActive = IsTalentSetActive
Internal.CombineTalentSets = CombineTalentSets
Internal.GetTalentSets = GetTalentSets

local setsFiltered = {}
local function TalentsDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Profiles

	CloseDropDownMenus();
	local set = tab.set;
	local index = arg2 or (#set.talents + 1)

	if set.talents[index] then
		local subset = Internal.GetTalentSet(set.talents[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	if arg1 == nil then
		table.remove(set.talents, index);
	else
		set.talents[index] = arg1;
	end

	if set.talents[index] then
		local subset = Internal.GetTalentSet(set.talents[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame:Update();
end
local function TalentsDropDown_NewOnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Profiles

	CloseDropDownMenus();
	local set = tab.set;
	local index = arg2 or (#set.talents + 1)

	if set.talents[index] then
		local subset = Internal.GetTalentSet(set.talents[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local talentSet = Internal.AddTalentSet();
	set.talents[index] = talentSet.setID;

	if set.talents[index] then
		local subset = Internal.GetTalentSet(set.talents[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame.Talents.set = talentSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, BtWLoadoutsFrame.Talents:GetID());

	BtWLoadoutsHelpTipFlags["TUTORIAL_CREATE_TALENT_SET"] = true;
	BtWLoadoutsFrame:Update();
end
local function TalentsDropDownInit(self, level, menuList, index)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.talents then
        return;
	end
    local info = UIDropDownMenu_CreateInfo();

	local tab = BtWLoadoutsFrame.Profiles

	local set = tab.set;
	local selected = set and set.talents and set.talents[index];

	info.arg2 = index

	if (level or 1) == 1 then
		info.text = L["None"];
		info.func = TalentsDropDown_OnClick;
		info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

		wipe(setsFiltered);
		local sets = BtWLoadoutsSets.talents;
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
		info.func = TalentsDropDown_NewOnClick;
		info.hasArrow, info.menuList = false, nil;
		info.keepShownOnClick = false;
		info.notCheckable = true;
		info.checked = false;
		UIDropDownMenu_AddButton(info, level);
	else
		local specID = menuList;

		wipe(setsFiltered);
		local sets = BtWLoadoutsSets.talents;
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
            info.func = TalentsDropDown_OnClick;
            info.checked = selected == setID;
            UIDropDownMenu_AddButton(info, level);
        end
    end
end

Internal.AddLoadoutSegment({
    id = "talents",
    name = L["Talents"],
    events = "PLAYER_TALENT_UPDATE",
    get = GetTalentSets,
    combine = CombineTalentSets,
    isActive = IsTalentSetActive,
    activate = ActivateTalentSet,
    dropdowninit = TalentsDropDownInit,
    checkerrors = CheckErrors,
})

BtWLoadoutsTalentsMixin = {}
function BtWLoadoutsTalentsMixin:OnLoad()
    self.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
    self.talentIDs = {}
    for tier=1,MAX_TALENT_TIERS do
        self.talentIDs[tier] = {}
    end
end
function BtWLoadoutsTalentsMixin:OnShow()
    if not self.initialized then
        UIDropDownMenu_SetWidth(self.SpecDropDown, 170);
        UIDropDownMenu_JustifyText(self.SpecDropDown, "LEFT");

        self.initialized = true;
    end
end
function BtWLoadoutsTalentsMixin:ChangeSet(set)
    self.set = set
    self:Update()
end
function BtWLoadoutsTalentsMixin:UpdateSetName(value)
	if self.set and self.set.name ~= not value then
		self.set.name = value;
		self:Update();
	end
end
function BtWLoadoutsTalentsMixin:OnButtonClick(button)
	CloseDropDownMenus()
	if button.isAdd then
		BtWLoadoutsHelpTipFlags["TUTORIAL_NEW_SET"] = true;

		self.Name:ClearFocus()
        self:ChangeSet(AddTalentSet())
		C_Timer.After(0, function ()
			self.Name:HighlightText()
			self.Name:SetFocus()
		end)
	elseif button.isDelete then
		local set = self.set
		if set.useCount > 0 then
			StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
				set = set,
				func = DeleteTalentSet,
			})
		else
			StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
				set = set,
				func = DeleteTalentSet,
			})
		end
	elseif button.isRefresh then
        local set = self.set;
        RefreshTalentSet(set)
        self:Update()
	elseif button.isActivate then
        local set = self.set;
        if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
            Internal.ActivateProfile({
                talents = {set.setID}
            });
        end
	end
end
function BtWLoadoutsTalentsMixin:OnSidebarItemClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		button.collapsed[button.id] = not button.collapsed[button.id]
		self:Update()
	else
        if IsModifiedClick("SHIFT") then
            local set = GetTalentSet(button.id);
            if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
                Internal.ActivateProfile({
                    talents = {button.id}
                });
            end
        else
            self.Name:ClearFocus();
            self:ChangeSet(GetTalentSet(button.id))
        end
	end
end
function BtWLoadoutsTalentsMixin:OnSidebarItemDoubleClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		return
	end

    local set = GetTalentSet(button.id);
    if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
        Internal.ActivateProfile({
            talents = {button.id}
        });
    end
end
function BtWLoadoutsTalentsMixin:OnSidebarItemDragStart(button)
	CloseDropDownMenus()
	if button.isHeader then
		return
	end

	local icon = "INV_Misc_QuestionMark";
	local set = GetTalentSet(button.id);
	local command = format("/btwloadouts activate talents %d", button.id);
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
function BtWLoadoutsTalentsMixin:Update()
    self:GetParent().TitleText:SetText(L["Talents"]);
	local sidebar = BtWLoadoutsFrame.Sidebar

	sidebar:SetSupportedFilters("spec", "class", "role", "character")
	sidebar:SetSets(BtWLoadoutsSets.talents)
	sidebar:SetCollapsed(BtWLoadoutsCollapsed.talents)
	sidebar:SetCategories(BtWLoadoutsCategories.talents)
	sidebar:SetFilters(BtWLoadoutsFilters.talents)
	sidebar:SetSelected(self.set)

	sidebar:Update()
	self.set = sidebar:GetSelected()

    if self.set ~= nil then
        self.Name:SetEnabled(true);
        self.SpecDropDown.Button:SetEnabled(true);
        for _,row in ipairs(self.rows) do
            row:SetShown(true);
        end

        local specID = self.set.specID;

		local set = self.set

		UpdateTalentSetFilters(set)
        sidebar:Update()

        local selected = self.set.talents;

        if not self.Name:HasFocus() then
            self.Name:SetText(self.set.name or "");
        end

        local _, specName, _, icon, _, classID = GetSpecializationInfoByID(specID);
        local className = LOCALIZED_CLASS_NAMES_MALE[classID];
        local classColor = GetClassColor(classID);
        UIDropDownMenu_SetSelectedValue(self.SpecDropDown, specID);
        UIDropDownMenu_SetText(self.SpecDropDown, format("%s: %s", classColor:WrapTextInColorCode(className), specName));

        if self.set.inUse then
            UIDropDownMenu_DisableDropDown(self.SpecDropDown);
        else
            UIDropDownMenu_EnableDropDown(self.SpecDropDown);
        end

        for tier=1,MAX_TALENT_TIERS do
            local row = self.talentIDs[tier]
            wipe(row)
            for column=1,3 do
                row[column] = GetTalentInfoForSpecID(specID, tier, column)
            end

            self.rows[tier]:SetTalents(row);
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
        for _,row in ipairs(self.rows) do
            row:SetShown(false);
        end

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
