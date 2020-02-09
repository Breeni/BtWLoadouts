local ADDON_NAME,Internal = ...
local L = Internal.L

local GetMilestoneEssence = C_AzeriteEssence.GetMilestoneEssence;

local HelpTipBox_Anchor = Internal.HelpTipBox_Anchor;
local HelpTipBox_SetText = Internal.HelpTipBox_SetText;

local format = string.format

local function IsEssenceSetActive(set)
    for milestoneID,essenceID in pairs(set.essences) do
        local info = C_AzeriteEssence.GetMilestoneInfo(milestoneID);
        if (info.unlocked or info.canUnlock) and C_AzeriteEssence.GetMilestoneEssence(milestoneID) ~= essenceID then
            return false;
        end
    end

    return true;
end
local function ActivateEssenceSet(set)
	local complete = true;
	for milestoneID,essenceID in pairs(set.essences) do
		local info = C_AzeriteEssence.GetEssenceInfo(essenceID)
		if info and info.valid and info.unlocked then
			local info = C_AzeriteEssence.GetMilestoneInfo(milestoneID);
			if info.canUnlock then
				C_AzeriteEssence.UnlockMilestone(milestoneID);
				complete = false;
			end

			if info.unlocked and C_AzeriteEssence.GetMilestoneEssence(milestoneID) ~= essenceID then
				C_AzeriteEssence.ActivateEssence(essenceID, milestoneID);
				complete = false;
			end
		end
	end

	return complete;
end
local function RefreshEssenceSet(set)
    local essences = set.essences or {}
    wipe(essences)

    essences[115] = GetMilestoneEssence(115);
    essences[116] = GetMilestoneEssence(116);
    essences[117] = GetMilestoneEssence(117);
	essences[119] = GetMilestoneEssence(119);

    set.essences = essences

    return set
end
local function AddEssenceSet()
    local role = select(5,GetSpecializationInfo(GetSpecialization()));
    local name = format(L["New %s Set"], _G[role]);
	local selected = {};

    selected[115] = C_AzeriteEssence.GetMilestoneEssence(115);
    selected[116] = C_AzeriteEssence.GetMilestoneEssence(116);
    selected[117] = C_AzeriteEssence.GetMilestoneEssence(117);
    selected[119] = C_AzeriteEssence.GetMilestoneEssence(119);

    local set = {
		setID = Internal.GetNextSetID(BtWLoadoutsSets.essences),
        role = role,
        name = name,
        essences = selected,
		useCount = 0,
    };
    BtWLoadoutsSets.essences[set.setID] = set;
    return set;
end
function Internal.GetEssenceSet(id)
    if type(id) == "table" then
		return id;
	else
		return BtWLoadoutsSets.essences[id];
	end
end
function Internal.GetEssenceSetByName(name)
	for _,set in pairs(BtWLoadoutsSets.essences) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
end
function Internal.GetEssenceSets(id, ...)
	if id ~= nil then
		return BtWLoadoutsSets.essences[id], Internal.GetEssenceSets(...);
	end
end
function Internal.GetEssenceSetIfNeeded(id)
	if id == nil then
		return;
	end

	local set = Internal.GetEssenceSet(id);
	if IsEssenceSetActive(set) then
		return;
	end

    return set;
end
local function CombineEssenceSets(result, ...)
	result = result or {};

	result.essences = {};
	for i=1,select('#', ...) do
		local set = select(i, ...);
		for milestoneID, essenceID in pairs(set.essences) do
			result.essences[milestoneID] = essenceID;
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
		if type(set) == "table" and set.essencesSet == id then
			set.essencesSet = nil;
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

Internal.EssenceSetDelay = EssenceSetDelay
Internal.AddEssenceSet = AddEssenceSet
Internal.RefreshEssenceSet = RefreshEssenceSet
Internal.DeleteEssenceSet = DeleteEssenceSet
Internal.ActivateEssenceSet = ActivateEssenceSet
Internal.IsEssenceSetActive = IsEssenceSetActive
Internal.CombineEssenceSets = CombineEssenceSets

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
Internal.EssenceScrollFrameUpdate = EssenceScrollFrameUpdate
function Internal.EssencesTabUpdate(self)
	self:GetParent().TitleText:SetText(L["Essences"]);
	self.set = Internal.SetsScrollFrame_RoleFilter(self.set, BtWLoadoutsSets.essences, BtWLoadoutsCollapsed.essences);

	if self.set ~= nil then
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