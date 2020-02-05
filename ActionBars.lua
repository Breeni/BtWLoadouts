--[[
]]

local ADDON_NAME,Internal = ...
local L = Internal.L

local UnitClass = UnitClass
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetActionInfo = GetActionInfo
local GetMacroBody = GetMacroBody

local HelpTipBox_Anchor = Internal.HelpTipBox_Anchor;
local HelpTipBox_SetText = Internal.HelpTipBox_SetText;

local function GetActionInfoTable(slot, tbl)
    local actionType, id, subType = GetActionInfo(slot)
    if not actionType and not tbl then -- If no action and tbl is missing just return
        return
    end

    tbl = tbl or {}

    -- If we use the base version of the spell it should always work
    if actionType == "spell" then
        id = FindBaseSpellByID(id) or id
    end

    tbl.type, tbl.id, tbl.subType, tbl.macroText = actionType, id, subType, nil
    tbl.icon = GetActionTexture(slot)
    tbl.name = GetActionText(slot)

    if actionType == "macro" then
        tbl.macroText = GetMacroBody(id)
    end

    return tbl
end
local function CompareSlot(slot, tbl)
    local actionType, id, subType = GetActionInfo(slot)
    if actionType == "spell" then
        id = FindBaseSpellByID(id) or id
    end

    if tbl == nil then
        return actionType == nil
    elseif actionType == "macro" and tbl.type == "macro" then
        local macroText = GetMacroBody(id)
        return macroText == tbl.macroText or id == GetMacroIndexByName(tbl.name)
    elseif actionType == "companion" and subType == "MOUNT" and tbl.type == "summonmount" then
        return id == select(2, C_MountJournal.GetDisplayedMountInfo(tbl.id))
    elseif tbl.type == "companion" and tbl.subType == "MOUNT" and actionType == "summonmount" then
        return tbl.id == select(2, C_MountJournal.GetDisplayedMountInfo(id))
    else
        return tbl.type == actionType and tbl.id == id and tbl.subType == subType
    end
end
local function GetMacroByText(text)
    local global, character = GetNumMacros()
    for i=1,global do
        if GetMacroBody(i) == text then
            return i
        end
    end
    for i=MAX_ACCOUNT_MACROS+1,MAX_ACCOUNT_MACROS+character do
        if GetMacroBody(i) == text then
            return i
        end
    end
end
Internal.GetMacroByText = GetMacroByText
local function PickupMacroByText(text)
    local index = GetMacroByText(text)
    if index then
        PickupMacro(index)
        return true
    end
    return false
end
local function SetActon(slot, tbl)
    local success = true

    ClearCursor()
    if tbl == nil or tbl.type == nil then -- Clear the slot
        ClearCursor()
        PickupAction(slot)
        ClearCursor()
        return true, true
    elseif tbl.type == "macro" then
        if not PickupMacroByText(tbl.macroText) then
            PickupMacro(tbl.id)
        end
    elseif tbl.type == "spell" then
        -- If we use the base version of the spell it should always work
        tbl.id = FindBaseSpellByID(tbl.id) or tbl.id

        local foundSpell = false
        local index
        if tbl.subType == "spell" then
            for tabIndex = 1,min(2,GetNumSpellTabs()) do
                local offset, numEntries = select(2, GetSpellTabInfo(tabIndex))
                for spellIndex = offset,offset+numEntries do
                    local skillType, id = GetSpellBookItemInfo(spellIndex, "spell")
                    if skillType == "SPELL" and id == tbl.id then
                        index = spellIndex
                        break
                    end
                end
            end
        else
            local spellIndex = 1
            local skillType, id = GetSpellBookItemInfo(spellIndex, tbl.subType)
            while skillType do
                if skillType == "SPELL" and id == tbl.id then
                    index = spellIndex
                    break
                end

                spellIndex = spellIndex + 1
                skillType, id = GetSpellBookItemInfo(spellIndex, tbl.subType)
            end
        end
        if index then
            PickupSpellBookItem(index, tbl.subType)
            foundSpell = true
        end

        if not foundSpell then
            -- In cases where we need a pvp talent but they arent active
            -- we have to pickup the talent, not the spell
            local pvptalents = C_SpecializationInfo.GetAllSelectedPvpTalentIDs()
            for _,talentId in ipairs(pvptalents) do
                if select(6, GetPvpTalentInfoByID(talentId)) == tbl.id then
                    PickupPvpTalent(talentId)
                    foundSpell = true
                end
            end
        end

        if not foundSpell then
            if tbl.subType == "pet" then
                if not IsSpellKnown(tbl.id, true) then
                    return false, true
                end

                PickupPetSpell(tbl.id)
            elseif tbl.subType == "spell" then
                if not IsSpellKnown(tbl.id, false) then
                    return false, true
                end

                PickupSpell(tbl.id)
            end
        end
    elseif tbl.type == "item" then
        PickupItem(tbl.id)
    elseif tbl.type == "summonmount" then
        if tbl.id == 0xFFFFFFF then -- Random Favourite
            C_MountJournal.Pickup(0)
        else
            if not select(11, C_MountJournal.GetMountInfoByID(tbl.id)) then
                return false, true
            end

            -- We will attempt to pickup the mount using the latest way, if that
            -- fails because of pet filtering we will pickup the spell instead
            local index = nil
            for i=1,C_MountJournal.GetNumDisplayedMounts() do
                if select(12,C_MountJournal.GetDisplayedMountInfo(i)) == tbl.id then
                    index = i
                    break
                end
            end
            if index then
                C_MountJournal.Pickup(index)
            else
                PickupSpell((select(2, C_MountJournal.GetMountInfoByID(tbl.id))))
            end
        end
    elseif tbl.type == "summonpet" then
        if not C_PetJournal.GetPetInfoByPetID(tbl.id) then
            return false, false
        end

        C_PetJournal.PickupPet(tbl.id)
    elseif tbl.type == "companion" then -- This is the old way of handling mounts and pets
        if tbl.subType == "MOUNT" then
            PickupSpell(tbl.id)
        end
    elseif tbl.type == "equipmentset" then
        local id = C_EquipmentSet.GetEquipmentSetID(tbl.id)
        if not id then
            return false, true -- Equipment set missing
        end
        C_EquipmentSet.PickupEquipmentSet(id)
    elseif tbl.type == "flyout" then
        if not GetFlyoutInfo(tbl.id) then
            return false, true
        end

        -- Find the spell book index for the flyout
        local index
        for tabIndex = 1,min(2,GetNumSpellTabs()) do
            local offset, numEntries = select(2, GetSpellTabInfo(tabIndex))
            for spellIndex = offset,offset+numEntries do
                local skillType, id = GetSpellBookItemInfo(spellIndex, "spell")
                if skillType == "FLYOUT" and id == tbl.id then
                    index = spellIndex
                    break
                end
            end
        end
        if not index then -- Couldn't find the flyout in the spell book
            return false, true
        end

        PickupSpellBookItem(index, "spell")
    else
        -- Unknown type so we cant pick it up but we dont want to fail and keep trying
        return false, true
    end

    if GetCursorInfo() then
        PlaceAction(slot)

        if GetCursorInfo() then -- Cursor should be empty now
            success = false
        end
    else
        success = false
    end

    ClearCursor()
    return success, success
end

local function IsActionBarSetActive(set)
    for slot=1,120 do
        if not set.ignored[slot] and not CompareSlot(slot, set.actions[slot]) then
            return false
        end
    end

    return true;
end
local function ActivateActionBarSet(set)
    local complete = true
    for slot=1,120 do
        local tbl = set.actions[slot]
        if not set.ignored[slot] and not CompareSlot(slot, tbl) then
            local success, done = SetActon(slot, tbl)
            if not done then
                complete = false
            end
        end
    end
    return complete
end
local function AddActionBarSet()
    local classFile = select(2, UnitClass("player"))
    local name = format(L["New Set"]);

    local actions, ignored = {}, {}
    for slot=1,120 do
        actions[slot] = GetActionInfoTable(slot)
    end

    local ignoredStart = 73
    if classFile == "ROGUE" then
        ignoredStart = 85 -- After Stealth Bar
    elseif classFile == "DRUID" then
        ignoredStart = 121 -- After Form Bars
    end
    for slot=ignoredStart,120 do
        ignored[slot] = true
    end

    return Internal.AddSet(BtWLoadoutsSets.actionbars, {
        name = name,
        ignored = ignored,
        actions = actions,
    })
end
local function GetActionBarSet(id)
    return Internal.GetSet(BtWLoadoutsSets.actionbars, id)
end
local function GetActionBarSetByName(id)
    return Internal.GetSetByName(BtWLoadoutsSets.actionbars, id)
end
local function GetActionBarSets(id, ...)
	if id ~= nil then
		return GetActionBarSet(id), GetActionBarSets(...);
	end
end
-- Do not change the results action tables, that'll mess with the original sets
local function CombineActionBarSets(result, ...)
    result = result or {};
    result.actions = result.actions or {}
    result.ignored = result.ignored or {}

    wipe(result.actions)
    for slot=1,120 do
        result.ignored[slot] = true
    end

	for i=1,select('#', ...) do
		local set = select(i, ...);
		for slot=1,120 do
            if not set.ignored[slot] then
                result.ignored[slot] = false
                result.actions[slot] = set.actions[slot]
            end
		end
    end

	return result;
end
local function DeleteActionBarSet(id)
	Internal.DeleteSet(BtWLoadoutsSets.actionbars, id);

	if type(id) == "table" then
		id = id.setID;
	end
	for _,set in pairs(BtWLoadoutsSets.profiles) do
		if type(set) == "table" and set.actionBarSet == id then
			set.actionBarSet = nil;
		end
	end

	local frame = BtWLoadoutsFrame.ActionBars;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil
		BtWLoadoutsFrame:Update()
	end
end

Internal.IsActionBarSetActive = IsActionBarSetActive
Internal.ActivateActionBarSet = ActivateActionBarSet
Internal.AddActionBarSet = AddActionBarSet
Internal.GetActionBarSet = GetActionBarSet
Internal.GetActionBarSetByName = GetActionBarSetByName
Internal.GetActionBarSets = GetActionBarSets
Internal.CombineActionBarSets = CombineActionBarSets
Internal.DeleteActionBarSet = DeleteActionBarSet

function Internal.ActionBarsTabUpdate(self)
	self:GetParent().TitleText:SetText(L["Action Bars"]);
	self.set = Internal.SetsScrollFrame_NoFilter(self.set, BtWLoadoutsSets.actionbars, BtWLoadoutsCollapsed.actionbars);

	if self.set ~= nil then
		local set = self.set;
		local slots = set.actions;

		self.Name:SetEnabled(true);
		if not self.Name:HasFocus() then
			self.Name:SetText(self.set.name or "");
		end

        for slot,item in pairs(self.Slots) do
            item:SetID(slot)
            item:Update();
			item:SetEnabled(true);
            
            local icon = item.Icon:GetTexture()
            if icon ~= nil and icon ~= 134400 then
                slots[slot].icon = icon
            end
		end
        for i=1,10 do
            local item = self["IgnoreBar" .. i]
			item:SetEnabled(true);
		end

		local activateButton = self:GetParent().ActivateButton;
		activateButton:SetEnabled(true);

		local deleteButton =  self:GetParent().DeleteButton;
		deleteButton:SetEnabled(true);

		local addButton = self:GetParent().AddButton;
		addButton.Flash:Hide();
		addButton.FlashAnim:Stop();

		local helpTipBox = self:GetParent().HelpTipBox;
        if not BtWLoadoutsHelpTipFlags["ACTIONBAR_IGNORE"] then
            helpTipBox.closeFlag = "ACTIONBAR_IGNORE";

            HelpTipBox_Anchor(helpTipBox, "RIGHT", self.Bar1Slot1);

            helpTipBox:Show();
            HelpTipBox_SetText(helpTipBox, L["Shift+Left Mouse Button to ignore a slot."]);
        else
            helpTipBox.closeFlag = nil;
            helpTipBox:Hide();
        end
	else
		self.Name:SetEnabled(false);
		self.Name:SetText("");

		for _,item in pairs(self.Slots) do
			item:SetEnabled(false);
		end
        for i=1,10 do
            local item = self["IgnoreBar" .. i]
			item:SetEnabled(true);
		end

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