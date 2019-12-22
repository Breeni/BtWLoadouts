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
	local complete = true;
	for talentID in pairs(set.talents) do
		local selected, _, _, _, tier = select(4, GetTalentInfoByID(talentID, 1));
		if not selected and GetTalentTierInfo(tier, 1) then
			complete = LearnTalent(talentID) and complete;
		end
	end
	return complete;
end
local function AddTalentSet()
    local specID, specName = GetSpecializationInfo(GetSpecialization());
    local talents = {};

	for tier=1,MAX_TALENT_TIERS do
        local _, column = GetTalentTierInfo(tier, 1);
        local talentID = GetTalentInfo(tier, column, 1);
        if talentID then
            talents[talentID] = true;
        end
    end

    return AddSet("talents", {
        specID = specID,
		name = format(L["New %s Set"], specName),
		useCount = 0,
        talents = talents,
    })
    -- local set = {
	-- 	setID = GetNextSetID(BtWLoadoutsSets.talents),
    --     specID = specID,
    --     name = name,
    --     talents = talents,
	-- 	useCount = 0,
    -- };
    -- BtWLoadoutsSets.talents[set.setID] = set;
    -- return set;
end
function Internal.GetTalentSet(id)
    if type(id) == "table" then
		return id;
	else
		return BtWLoadoutsSets.talents[id];
	end;
end
function Internal.GetTalentSetByName(name)
	for _,set in pairs(BtWLoadoutsSets.talents) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
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
		if type(set) == "table" and set.talentSet == id then
			set.talentSet = nil;
		end
	end

	local frame = BtWLoadoutsFrame.Talents;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil;-- = select(2,next(BtWLoadoutsSets.talents)) or {};
		BtWLoadoutsFrame:Update();
	end
end

Internal.AddTalentSet = AddTalentSet
Internal.DeleteTalentSet = DeleteTalentSet
Internal.ActivateTalentSet = ActivateTalentSet
Internal.IsTalentSetActive = IsTalentSetActive
Internal.CombineTalentSets = CombineTalentSets

function Internal.TalentsTabUpdate(self)
    self:GetParent().TitleText:SetText(L["Talents"]);
    self.set = Internal.SetsScrollFrame_SpecFilter(self.set, BtWLoadoutsSets.talents, BtWLoadoutsCollapsed.talents);

    if self.set ~= nil then
        self.Name:SetEnabled(true);
        self.SpecDropDown.Button:SetEnabled(true);
        for _,row in ipairs(self.rows) do
            row:SetShown(true);
        end

        local specID = self.set.specID;
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
