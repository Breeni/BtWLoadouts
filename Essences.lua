local ADDON_NAME,Internal = ...
local L = Internal.L

local GetMilestoneEssence = C_AzeriteEssence.GetMilestoneEssence;

local HelpTipBox_Anchor = Internal.HelpTipBox_Anchor;
local HelpTipBox_SetText = Internal.HelpTipBox_SetText;

local AddSet = Internal.AddSet

local format = string.format

local function UpdateEssenceSetFilters(set)
	local filters = set.filters or {}
	filters.role = set.role

	-- Rebuild character list
	filters.character = filters.character or {}
	local characters = filters.character
	table.wipe(characters)
	local role = filters.role
	for _,character in Internal.CharacterIterator() do
		if Internal.IsClassRoleValid(Internal.GetCharacterInfo(character).class, role) then
			characters[#characters+1] = character
		end
	end

	set.filters = filters

    return set
end
local function GetEssenceSet(id)
    if type(id) == "table" then
		return id;
	else
		return BtWLoadoutsSets.essences[id];
	end
end
local IsQuestFlaggedCompleted = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
local function CanActivateEssences()
	return IsQuestFlaggedCompleted(55618) -- The Heart Forge quest
end
-- returns isValid and isValidForPlayer
local function EssenceSetIsValid(set)
	local set = GetEssenceSet(set);
	return true, Internal.IsClassRoleValid(select(2, UnitClass("player")), set.role)
end
local function IsEssenceSetActive(set)
	if CanActivateEssences() then
		for milestoneID,essenceID in pairs(set.essences) do
			local info = C_AzeriteEssence.GetMilestoneInfo(milestoneID);
			if info and (info.unlocked or info.canUnlock) and C_AzeriteEssence.GetMilestoneEssence(milestoneID) ~= essenceID then
				return false;
			end
		end
	end

    return true;
end
local function ActivateEssenceSet(set, state)
	local success, complete = true, true;
	if state.heartEquipped or GetInventoryItemID("player", INVSLOT_NECK) == 158075 then
		for milestoneID,essenceID in pairs(set.essences) do
			local info = C_AzeriteEssence.GetEssenceInfo(essenceID)
			local essenceName, essenceRank = info.name, info.rank
			if info and info.valid and info.unlocked then
				local info = C_AzeriteEssence.GetMilestoneInfo(milestoneID);
				if info.canUnlock then
					C_AzeriteEssence.UnlockMilestone(milestoneID);
					complete = false;
				end

				if info.unlocked and C_AzeriteEssence.GetMilestoneEssence(milestoneID) ~= essenceID then
					C_AzeriteEssence.ActivateEssence(essenceID, milestoneID);
					complete = false;

					Internal.LogMessage("Switching essence %d to %s", milestoneID, C_AzeriteEssence.GetEssenceHyperlink(essenceID, essenceRank or 4))
				end
			end
		end
	end

	return complete, not complete;
end
local function RefreshEssenceSet(set)
    local essences = set.essences or {}
    wipe(essences)

    essences[115] = GetMilestoneEssence(115);
    essences[116] = GetMilestoneEssence(116);
    essences[117] = GetMilestoneEssence(117);
	essences[119] = GetMilestoneEssence(119);

    set.essences = essences

    return UpdateEssenceSetFilters(set)
end
local function AddEssenceSet()
    local role = select(5,GetSpecializationInfo(GetSpecialization()));
    return AddSet("essences", RefreshEssenceSet({
		role = role,
		name = format(L["New %s Set"], _G[role]);
		useCount = 0,
        essences = {},
	}))
end
local function GetEssenceSetsByName(name)
	return Internal.GetSetsByName("essences", name)
end
local function GetEssenceSetByName(name)
	return Internal.GetSetByName("essences", name, EssenceSetIsValid)
end
local function GetEssenceSets(id, ...)
	if id ~= nil then
		return BtWLoadoutsSets.essences[id], Internal.GetEssenceSets(...);
	end
end
local function GetEssenceSetIfNeeded(id)
	if id == nil then
		return;
	end

	local set = Internal.GetEssenceSet(id);
	if IsEssenceSetActive(set) then
		return;
	end

    return set;
end
--[[
    Check what is needed to activate this talent set
    return isActive, waitForCooldown
]]
local function EssenceSetRequirements(set)
    local isActive, waitForCooldown = true, false

	for milestoneID,essenceID in pairs(set.essences) do
		if essenceID ~= C_AzeriteEssence.GetMilestoneEssence(milestoneID) then
			isActive = false

			local spellID = C_AzeriteEssence.GetMilestoneSpell(milestoneID)
			if spellID then
				spellID = FindSpellOverrideByID(spellID)
				local start, duration = GetSpellCooldown(spellID)
				if start ~= 0 then -- Milestone spell on cooldown, we need to wait before switching
					Internal.DirtyAfter((start + duration) - GetTime() + 1)
					waitForCooldown = true
					break
				end
			end
		end
	end

    -- for talentID in pairs(set.talents) do
    --     local row = select(8, GetTalentInfoByID(talentID, 1))
    --     local column = select(2, GetTalentTierInfo(row, 1))
    --     local selectedTalentID, _, _, _, _, spellID = GetTalentInfo(row, column, 1)

    --     if selectedTalentID ~= talentID then
    --         isActive = false

    --         if spellID then
    --             spellID = FindSpellOverrideByID(spellID)
    --             local start, duration = GetSpellCooldown(spellID)
    --             if start ~= 0 then -- Talent spell on cooldown, we need to wait before switching
    --                 Internal.DirtyAfter((start + duration) - GetTime() + 1)
    --                 waitForCooldown = true
    --                 break -- We dont actually need to check anything more
    --             end
    --         end
    --     end
    -- end

    return isActive, waitForCooldown
end
local function CombineEssenceSets(result, state, ...)
	result = result or {};

	result.essences = {};
	if CanActivateEssences() and (not state or state.heartEquipped) then -- Check if essences have been unlocked and we will have the heart equipped
		for i=1,select('#', ...) do
			local set = select(i, ...);
			for milestoneID, essenceID in pairs(set.essences) do
				result.essences[milestoneID] = essenceID;
			end
		end

		if state then
			state.noCombatSwap = true
			state.noTaxiSwap = true -- Maybe check for rested area or tomb first?

			if result.essences[115] == nil then
				state.conflictAndStrife = GetMilestoneEssence(115) == 32; -- Conflict is equipped
			else
				state.conflictAndStrife = result.essences[115] == 32
			end

			if not state.customWait or not state.needTome then
				local isActive, waitForCooldown = EssenceSetRequirements(result)

				state.needTome = state.needTome or (not isActive)
				state.customWait = state.customWait or (waitForCooldown and L["Waiting for essence cooldown"])
			end
		end
	end

	return result;
end
local function DeleteEssenceSet(id)
	Internal.DeleteSet(BtWLoadoutsSets.essences, id);

	if type(id) == "table" then
		id = id.setID;
	end
	for _,set in pairs(BtWLoadoutsSets.profiles) do
        if type(set) == "table" then
            for index,setID in ipairs(set.essences) do
                if setID == id then
                    table.remove(set.essences, index)
                end
            end
		end
	end

	local frame = BtWLoadoutsFrame.Essences;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil;-- = select(2,next(BtWLoadoutsSets.essences)) or {};
		BtWLoadoutsFrame:Update();
	end
end
local function EssenceSetDelay(set)
	for milestoneID,essenceID in pairs(set.essences) do
		local spellID = C_AzeriteEssence.GetMilestoneSpell(milestoneID)
		if spellID and essenceID ~= C_AzeriteEssence.GetMilestoneEssence(milestoneID) then
			spellID = FindSpellOverrideByID(spellID)
			local start, duration = GetSpellCooldown(spellID)
			if start ~= 0 then -- Milestone spell on cooldown, we need to wait before switching
				Internal.DirtyAfter((start + duration) - GetTime() + 1)
				return true
			end
		end
	end
	return false
end
local function CheckErrors(errorState, set)
    set = GetEssenceSet(set)

	if errorState.specID then
		errorState.role, errorState.class = select(5, GetSpecializationInfoByID(errorState.specID))
	end
	errorState.role = errorState.role or set.role

    if errorState.role ~= set.role then
        return L["Incompatible Role"]
    end
end

Internal.GetEssenceSets = GetEssenceSets
Internal.GetEssenceSetIfNeeded = GetEssenceSetIfNeeded
Internal.CanActivateEssences = CanActivateEssences
Internal.GetEssenceSet = GetEssenceSet
Internal.GetEssenceSetsByName = GetEssenceSetsByName
Internal.GetEssenceSetByName = GetEssenceSetByName
Internal.EssenceSetDelay = EssenceSetDelay
Internal.AddEssenceSet = AddEssenceSet
Internal.RefreshEssenceSet = RefreshEssenceSet
Internal.DeleteEssenceSet = DeleteEssenceSet
Internal.ActivateEssenceSet = ActivateEssenceSet
Internal.IsEssenceSetActive = IsEssenceSetActive
Internal.CombineEssenceSets = CombineEssenceSets
Internal.GetEssenceSets = GetEssenceSets

local setsFiltered = {};
local function EssencesDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Profiles

    CloseDropDownMenus();
    local set = tab.set;
	local index = arg2 or (#set.essences + 1)

	if set.essences[index] then
		local subset = Internal.GetEssenceSet(set.essences[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	if arg1 == nil then
		table.remove(set.essences, index);
	else
		set.essences[index] = arg1;
	end

	if set.essences[index] then
		local subset = Internal.GetEssenceSet(set.essences[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame:Update();
end
local function EssencesDropDown_NewOnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Profiles

	CloseDropDownMenus();
	local set = tab.set;
	local index = arg2 or (#set.essences + 1)

	if set.essences[index] then
		local subset = Internal.GetEssenceSet(set.essences[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local newSet = Internal.AddEssenceSet();
	set.essences[index] = newSet.setID;

	if set.essences[index] then
		local subset = Internal.GetEssenceSet(set.essences[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end


	BtWLoadoutsFrame.Essences.set = newSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, BtWLoadoutsFrame.Essences:GetID());

	BtWLoadoutsFrame:Update();
end
local function EssencesDropDownInit(self, level, menuList, index)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.essences then
        return;
    end

	local info = UIDropDownMenu_CreateInfo();

	local tab = BtWLoadoutsFrame.Profiles

	local set = tab.set;
	local selected = set and set.essences and set.essences[index];

	info.arg2 = index

	if (level or 1) == 1 then
		info.text = NONE;
		info.func = EssencesDropDown_OnClick;
		info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

		wipe(setsFiltered);
		local sets = BtWLoadoutsSets.essences;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" then
				setsFiltered[subset.role] = true;
			end
		end

		local role = select(5, GetSpecializationInfo(GetSpecialization()));
		if setsFiltered[role] then
			info.text = _G[role];
			info.hasArrow, info.menuList = true, role;
			info.keepShownOnClick = true;
			info.notCheckable = true;
			UIDropDownMenu_AddButton(info, level);
		end

		local playerRole = role;
		for _,role in Internal.Roles() do
			if role ~= playerRole then
				if setsFiltered[role] then
					info.text = _G[role];
					info.hasArrow, info.menuList = true, role;
					info.keepShownOnClick = true;
					info.notCheckable = true;
					UIDropDownMenu_AddButton(info, level);
				end
			end
		end

		info.text = L["New Set"];
		info.func = EssencesDropDown_NewOnClick;
		info.hasArrow, info.menuList = false, nil;
		info.keepShownOnClick = false;
		info.notCheckable = true;
		info.checked = false;
		UIDropDownMenu_AddButton(info, level);
	else
		local role = menuList;

		wipe(setsFiltered);
		local sets = BtWLoadoutsSets.essences;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" and subset.role == role then
				setsFiltered[#setsFiltered+1] = setID;
			end
		end
		sort(setsFiltered, function (a,b)
			return sets[a].name < sets[b].name;
		end)

		for _,setID in ipairs(setsFiltered) do
			info.text = sets[setID].name;
			info.arg1 = setID;
			info.func = EssencesDropDown_OnClick;
			info.checked = selected == setID;
			UIDropDownMenu_AddButton(info, level);
		end
	end
end

Internal.AddLoadoutSegment({
    id = "essences",
    name = L["Essences"],
    after = "equipment",
    events = "AZERITE_ESSENCE_UPDATE",
    get = GetEssenceSets,
    combine = CombineEssenceSets,
    isActive = IsEssenceSetActive,
	activate = ActivateEssenceSet,
	dropdowninit = EssencesDropDownInit,
    checkerrors = CheckErrors,
})

BtWLoadoutsAzeriteMilestoneSlotMixin = {};
function BtWLoadoutsAzeriteMilestoneSlotMixin:OnLoad()
	self.EmptyGlow.Anim:Play();
end
function BtWLoadoutsAzeriteMilestoneSlotMixin:OnEnter()
	if self.id then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetAzeriteEssence(self.id, 4);
		SharedTooltip_SetBackdropStyle(GameTooltip, GAME_TOOLTIP_BACKDROP_STYLE_AZERITE_ITEM);
	end

	if self:GetParent().pending then
		SetCursor("interface/cursor/cast.blp");
	end
end
function BtWLoadoutsAzeriteMilestoneSlotMixin:OnLeave()
	GameTooltip_Hide();
end
function BtWLoadoutsAzeriteMilestoneSlotMixin:OnClick()
	local essences = self:GetParent();
	local selected = essences.set.essences;
	local pendingEssenceID = essences.pending;
	if pendingEssenceID then
		for milestoneID,essenceID in pairs(selected) do
			if essenceID == pendingEssenceID then
				selected[milestoneID] = nil;
			end
		end

		selected[self.milestoneID] = pendingEssenceID;

		essences.pending = nil;
		SetCursor(nil);
	else
		selected[self.milestoneID] = nil;
	end

	BtWLoadoutsFrame:Update();
end

BtWLoadoutsAzeriteEssenceButtonMixin = {};
function BtWLoadoutsAzeriteEssenceButtonMixin:OnClick()
	SetCursor("interface/cursor/cast.blp");
	BtWLoadoutsFrame.Essences.pending = self.id;
	BtWLoadoutsFrame:Update();
end
function BtWLoadoutsAzeriteEssenceButtonMixin:OnEnter()
	if self.id then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetAzeriteEssence(self.id, 4);
	end

	if BtWLoadoutsFrame.Essences.pending then
		SetCursor("interface/cursor/cast.blp");
	end
end

local function RoleDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Essences;

	CloseDropDownMenus();
	local set = tab.set;

	local temp = tab.temp;
	-- @TODO: If we always access talents by set.talents then we can just swap tables in and out of
	-- the temp table instead of copying the talentIDs around

	-- We are going to copy the currently selected talents for the currently selected spec into
	-- a temporary table incase the user switches specs back
	local role = set.role;
	if temp[role] then
		wipe(temp[role]);
	else
		temp[role] = {};
	end
	for milestoneID, essenceID in pairs(set.essences) do
		temp[role][milestoneID] = essenceID;
	end

	-- Clear the current talents and copy back the previously selected talents if they exist
	role = arg1;
	set.role = role;
	wipe(set.essences);
	if temp[role] then
		for milestoneID, essenceID in pairs(temp[role]) do
			set.essences[milestoneID] = essenceID;
		end
	end

	BtWLoadoutsFrame:Update();
end
local function RoleDropDownInit(self, level, menuList)
	local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local selected = set and set.role;

	if (level or 1) == 1 then
		for _,role in Internal.Roles() do
			info.text = _G[role];
			info.arg1 = role;
			info.func = RoleDropDown_OnClick;
			info.checked = selected == role;
			UIDropDownMenu_AddButton(info, level);
		end
	end
end

local EssenceScrollFrameUpdate;
do
	local MAX_ESSENCES = 14;
	function EssenceScrollFrameUpdate(self)
		local pending = self:GetParent().pending;
		local set = self:GetParent().set;
		local buttons = self.buttons;
		if set then
			local role = set.role;
			local selected = set.essences;

			local offset = HybridScrollFrame_GetOffset(self);
			for i,item in ipairs(buttons) do
				local index = offset + i;
				local essence = Internal.GetEssenceInfoForRole(role, index);

				if essence then
					item.id = essence.ID;
					item.Name:SetText(essence.name);
					item.Icon:SetTexture(essence.icon);
					item.ActivatedMarkerMain:SetShown(selected[115] == essence.ID);
					item.ActivatedMarkerPassive:SetShown((selected[116] == essence.ID) or (selected[117] == essence.ID));
					item.PendingGlow:SetShown(pending == essence.ID);

					item:Show();
				else
					item:Hide();
				end
			end
			local totalHeight = MAX_ESSENCES * (41 + 1) + 3 * 2;
			HybridScrollFrame_Update(self, totalHeight, self:GetHeight());
		else
			for i,item in ipairs(buttons) do
				item:Hide();
			end
			HybridScrollFrame_Update(self, 0, self:GetHeight());
		end
	end
end

BtWLoadoutsEssencesMixin = {}
function BtWLoadoutsEssencesMixin:OnLoad()
	self.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
	self.pending = nil;
end
function BtWLoadoutsEssencesMixin:OnShow()
	if not self.initialized then
		UIDropDownMenu_SetWidth(self.RoleDropDown, 170);
		UIDropDownMenu_Initialize(self.RoleDropDown, RoleDropDownInit);
		UIDropDownMenu_JustifyText(self.RoleDropDown, "LEFT");
		self.Slots = {
			[115] = self.MajorSlot,
			[116] = self.MinorSlot1,
			[117] = self.MinorSlot2,
			[119] = self.MinorSlot3,
		};

		HybridScrollFrame_CreateButtons(self.EssenceList, "BtWLoadoutsAzeriteEssenceButtonTemplate", 4, -3, "TOPLEFT", "TOPLEFT", 0, -1, "TOP", "BOTTOM");
		self.EssenceList.update = EssenceScrollFrameUpdate;

		self.initialized = true
	end
end
function BtWLoadoutsEssencesMixin:ChangeSet(set)
    self.set = set
    self:Update()
end
function BtWLoadoutsEssencesMixin:UpdateSetName(value)
	if self.set and self.set.name ~= not value then
		self.set.name = value;
		self:Update();
	end
end
function BtWLoadoutsEssencesMixin:OnButtonClick(button)
	CloseDropDownMenus()
	if button.isAdd then
		self.Name:ClearFocus();
		self:ChangeSet(AddEssenceSet())
		C_Timer.After(0, function ()
			self.Name:HighlightText();
			self.Name:SetFocus();
		end)
	elseif button.isDelete then
		local set = self.set;
		if set.useCount > 0 then
			StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
				set = set,
				func = DeleteEssenceSet,
			});
		else
			StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
				set = set,
				func = DeleteEssenceSet,
			});
		end
	elseif button.isRefresh then
		local set = self.set;
		RefreshEssenceSet(set)
		self:Update()
	elseif button.isActivate then
		Internal.ActivateProfile({
			essences = {self.set.setID}
		});
	end
end
function BtWLoadoutsEssencesMixin:OnSidebarItemClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		button.collapsed[button.id] = not button.collapsed[button.id]
		self:Update()
	else
		if IsModifiedClick("SHIFT") then
			Internal.ActivateProfile({
				essences = {button.id}
			});
		else
			self.Name:ClearFocus();
			self:ChangeSet(GetEssenceSet(button.id))
		end
	end
end
function BtWLoadoutsEssencesMixin:OnSidebarItemDoubleClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		return
	end

	Internal.ActivateProfile({
		essences = {button.id}
	});
end
function BtWLoadoutsEssencesMixin:OnSidebarItemDragStart(button)
	CloseDropDownMenus()
	if button.isHeader then
		return
	end

	local icon = "INV_Misc_QuestionMark";
	local set = GetEssenceSet(button.id);
	local command = format("/btwloadouts activate essences %d", button.id);

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
function BtWLoadoutsEssencesMixin:Update()
	self:GetParent().TitleText:SetText(L["Essences"]);
	local sidebar = BtWLoadoutsFrame.Sidebar

	sidebar:SetSupportedFilters("role", "character")
	sidebar:SetSets(BtWLoadoutsSets.essences)
	sidebar:SetCollapsed(BtWLoadoutsCollapsed.essences)
	sidebar:SetCategories(BtWLoadoutsCategories.essences)
	sidebar:SetFilters(BtWLoadoutsFilters.essences)
	sidebar:SetSelected(self.set)

	sidebar:Update()
	self.set = sidebar:GetSelected()

	if self.set ~= nil then
		local set = self.set

		UpdateEssenceSetFilters(set)
		sidebar:Update()

		self.Name:SetEnabled(true);
		self.RoleDropDown.Button:SetEnabled(true);
		self.MajorSlot:SetEnabled(true);
		self.MinorSlot1:SetEnabled(true);
		self.MinorSlot2:SetEnabled(true);
		self.MinorSlot3:SetEnabled(true);

		local role = self.set.role;
		local selected = self.set.essences;

		UIDropDownMenu_SetText(self.RoleDropDown, _G[self.set.role]);

		if self.set.inUse then
			UIDropDownMenu_DisableDropDown(self.RoleDropDown);
		else
			UIDropDownMenu_EnableDropDown(self.RoleDropDown);
		end

		if not self.Name:HasFocus() then
			self.Name:SetText(self.set.name or "");
		end

		for milestoneID,item in pairs(self.Slots) do
			local essenceID = self.set.essences[milestoneID];
			item.milestoneID = milestoneID;

			if essenceID then
				local info = Internal.GetEssenceInfoByID(essenceID);

				item.id = essenceID;

				item.Icon:Show();
				item.Icon:SetTexture(info.icon);
				item.EmptyGlow:Hide();
				item.EmptyIcon:Hide();
			else
				item.id = nil;

				item.Icon:Hide();
				item.EmptyGlow:Show();
				item.EmptyIcon:Show();
			end
		end

        local playerSpecIndex = GetSpecialization()
		self:GetParent().RefreshButton:SetEnabled(playerSpecIndex and role == select(5, GetSpecializationInfo(playerSpecIndex)))
		
		local activateButton = self:GetParent().ActivateButton;
		activateButton:SetEnabled(role == select(5, GetSpecializationInfo(GetSpecialization())));

		local deleteButton =  self:GetParent().DeleteButton;
		deleteButton:SetEnabled(true);

		local helpTipBox = self:GetParent().HelpTipBox;
		helpTipBox:Hide();

		local addButton = self:GetParent().AddButton;
		addButton.Flash:Hide();
		addButton.FlashAnim:Stop();
	else
		self.Name:SetEnabled(false);
		self.RoleDropDown.Button:SetEnabled(false);
		self.MajorSlot:SetEnabled(false);
		self.MinorSlot1:SetEnabled(false);
		self.MinorSlot2:SetEnabled(false);
		self.MinorSlot3:SetEnabled(false);

		self.MajorSlot.EmptyGlow:Hide();
		self.MinorSlot1.EmptyGlow:Hide();
		self.MinorSlot2.EmptyGlow:Hide();
		self.MinorSlot3.EmptyGlow:Hide();
		self.MajorSlot.EmptyIcon:Hide();
		self.MinorSlot1.EmptyIcon:Hide();
		self.MinorSlot2.EmptyIcon:Hide();
		self.MinorSlot3.EmptyIcon:Hide();
		self.MajorSlot.Icon:Hide();
		self.MinorSlot1.Icon:Hide();
		self.MinorSlot2.Icon:Hide();
		self.MinorSlot3.Icon:Hide();

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

	EssenceScrollFrameUpdate(self.EssenceList);
end
