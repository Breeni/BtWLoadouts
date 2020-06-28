local ADDON_NAME,Internal = ...
local L = Internal.L

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
		local _, _, _, selected, available = GetTalentInfoByID(talentID, 1);

        if not selected then
            return false;
        end
    end

    return true;
end
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
	return complete;
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

    return set
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
local function GetTalentSetsByName(name)
	return Internal.GetSetsByName("talents", name)
end
local function GetTalentSetByName(name)
	return Internal.GetSetByName("talents", name, TalentSetIsValid)
end
function Internal.GetTalentSets(id, ...)
	if id ~= nil then
		return Internal.GetTalentSet(id), Internal.GetTalentSets(...);
	end
end
function Internal.GetTalentSetIfNeeded(id)
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
local function CombineTalentSets(result, ...)
	result = result or {};
	result.talents = {};

	wipe(talentSetsByTier);
	for i=1,select('#', ...) do
		local set = Internal.GetTalentSet(select(i, ...));
		for talentID in pairs(set.talents) do
			if result.talents[talentID] == nil then
				local tier = select(8, GetTalentInfoByID(talentID, 1));
				if talentSetsByTier[tier] then
					result.talents[talentSetsByTier[tier]] = nil;
				end

				result.talents[talentID] = true;
				talentSetsByTier[tier] = talentID;
			end
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

Internal.GetTalentSet = GetTalentSet
Internal.GetTalentSetsByName = GetTalentSetsByName
Internal.GetTalentSetByName = GetTalentSetByName
Internal.TalentSetDelay = TalentSetDelay
Internal.AddTalentSet = AddTalentSet
Internal.RefreshTalentSet = RefreshTalentSet
Internal.DeleteTalentSet = DeleteTalentSet
Internal.ActivateTalentSet = ActivateTalentSet
Internal.IsTalentSetActive = IsTalentSetActive
Internal.CombineTalentSets = CombineTalentSets

function Internal.TalentsTabUpdate(self)
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
    -- self.set = Internal.SetsScrollFrame_SpecFilter(self.set, BtWLoadoutsSets.talents, BtWLoadoutsCollapsed.talents);

    if self.set ~= nil then
        self.Name:SetEnabled(true);
        self.SpecDropDown.Button:SetEnabled(true);
        for _,row in ipairs(self.rows) do
            row:SetShown(true);
        end

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
			local class = set.filters.class
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
        UIDropDownMenu_SetSelectedValue(self.SpecDropDown, specID);
        UIDropDownMenu_SetText(self.SpecDropDown, format("%s: %s", classColor:WrapTextInColorCode(className), specName));

        if self.set.inUse then
            UIDropDownMenu_DisableDropDown(self.SpecDropDown);
        else
            UIDropDownMenu_EnableDropDown(self.SpecDropDown);
        end

        for tier=1,MAX_TALENT_TIERS do
            for column=1,3 do
                local item = self.rows[tier].talents[column];
                local talentID, name, texture, _, _, spellID = GetTalentInfoForSpecID(specID, tier, column);

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
