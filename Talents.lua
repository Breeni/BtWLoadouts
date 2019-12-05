local ADDON_NAME,Internal = ...
local L = Internal.L

local UnitClass = UnitClass;
local GetTalentInfoByID = GetTalentInfoByID
local GetTalentInfoForSpecID = Internal.GetTalentInfoForSpecID;
local GetSpecializationInfoByID = GetSpecializationInfoByID;
local format = string.format

local AddSet = Internal.AddSet;
local DeleteSet = Internal.DeleteSet;

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
local function GetTalentSet(id)
    if type(id) == "table" then
		return id;
	else
		return BtWLoadoutsSets.talents[id];
	end;
end
local function GetTalentSetByName(name)
	for _,set in pairs(BtWLoadoutsSets.talents) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
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

	local set = GetTalentSet(id);
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
		local set = GetTalentSet(select(i, ...));
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

Internal.AddLoadoutSegment({
    type = "spec",
    id = "talent",
    name = L["Talents"],

    get = GetTalentSet,
    combine = CombineTalentSets,
    isActive = IsTalentSetActive,
    activate = ActivateTalentSet,
})


local function TalentsTabUpdate(self)
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
        local classColor = C_ClassColor.GetClassColor(classID);
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
        if not Internal.helpTipIgnored["TUTORIAL_NEW_SET"] then
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

do
    local frame = BtWLoadoutsFrame.Talents
    Internal.AddTab({
        type = "talents",
        name = L["Talents"],
        frame = frame,
        onInit = function (self, frame)
			UIDropDownMenu_SetWidth(frame.SpecDropDown, 170);
			-- UIDropDownMenu_Initialize(frame.SpecDropDown, Internal.SpecDropDownInit);
            UIDropDownMenu_JustifyText(frame.SpecDropDown, "LEFT");
            Internal.DropDownSetOnChange(frame.SpecDropDown, function (...)
                print("OnChange", ...)
            end)

            frame.temp = {}
        end,
        onUpdate = function (self)
            TalentsTabUpdate(frame)
        end,
        onButtonClick = function (self, button)
            if button.isAdd then
                frame.Name:ClearFocus();
                local set = AddTalentSet();
                frame.set = set;
                wipe(frame.temp);
                TalentsTabUpdate(frame)
                C_Timer.After(0, function ()
                    frame.Name:HighlightText();
                    frame.Name:SetFocus();
                end)
            elseif button.isDelete then
                local set = frame.set;
                if set.useCount > 0 then
                    StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
                        set = set,
                        func = DeleteTalentSet,
                    });
                else
                    StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
                        set = set,
                        func = DeleteTalentSet,
                    });
                end
            elseif button.isActivate then
                local set = frame.set;
                if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
                    Internal.ActivateProfile({
                        talentSet = set.setID;
                    });
                end
            elseif button.isHeader then
                BtWLoadoutsCollapsed.talents[button.id] = not BtWLoadoutsCollapsed.talents[button.id] and true or nil;
                TalentsTabUpdate(frame);
            else
                if IsModifiedClick("SHIFT") then
                    local set = GetTalentSet(button.id);
                    if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
                        Internal.ActivateProfile({
                            talentSet = button.id;
                        });
                    end
                else
                    frame.Name:ClearFocus();
                    local set = GetTalentSet(button.id);
                    frame.set = set;
                    wipe(frame.temp);
                    TalentsTabUpdate(frame)
                end
            end
        end,
    })
end