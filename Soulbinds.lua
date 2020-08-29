local ADDON_NAME,Internal = ...
local L = Internal.L

local AddSet = Internal.AddSet
local DeleteSet = Internal.DeleteSet

local format = string.format

local GetActiveCovenantID = C_Covenants.GetActiveCovenantID
local GetCovenantIDs = C_Covenants.GetCovenantIDs
local GetCovenantData = C_Covenants.GetCovenantData
local ActivateSoulbind = C_Soulbinds.ActivateSoulbind
local GetActiveSoulbindID = C_Soulbinds.GetActiveSoulbindID
local GetSoulbindData = C_Soulbinds.GetSoulbindData

local function GetSet(id)
    if type(id) == "table" then
		return id;
    else
        return GetSoulbindData(id)
	end
end
local function GetSets(id, ...)
	if id ~= nil then
		return GetSoulbindData(id), GetSets(...);
	end
end
local function CombineSets(result, state, ...)
	result = result or {};

    local covenantID = GetActiveCovenantID()
    if covenantID then
        for i=1,select('#', ...) do
            local soulbind = select(i, ...);
            if soulbind.covenantID == covenantID and soulbind.unlocked then
                result.ID = soulbind.ID
                result.unlocked = soulbind.unlocked
                result.covenantID = soulbind.covenantID
            end
        end

        local soulbindID = GetActiveSoulbindID()
        if state and (result.ID ~= soulbindID) then
            state.combatSwap = false
            state.taxiSwap = false -- Maybe check for rested area or tomb first?
            state.needTome = true
        end
    end

	return result;
end
local function IsSetActive(set)
    local covenantID = GetActiveCovenantID()
    if covenantID then
        local soulbindID = GetActiveSoulbindID()
        -- The target soulbind is unlocked, is for the players covenant, so is valid for the character
        if set.unlocked and set.covenantID == covenantID then
            return set.ID == soulbindID
        end
    end

    return true;
end
local function ActivateSet(set)
    local complete = true;

    if not IsSetActive(set) then
        ActivateSoulbind(set.ID)
        complete = false

        local soulbindData = GetSoulbindData(set.ID)
        Internal.LogMessage("Switching soulbind to %s", soulbindData.name)
    end

	return complete
end

local function DropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Profiles

    CloseDropDownMenus();
    local set = tab.set;
    set.soulbinds = set.soulbinds or {}

    local index = arg2 or (#set.soulbinds + 1)

	if arg1 == nil then
		table.remove(set.soulbinds, index);
	else
		set.soulbinds[index] = arg1;
	end

	BtWLoadoutsFrame:Update();
end
local function DropDownInit(self, level, menuList, index)
	local info = UIDropDownMenu_CreateInfo();

	local tab = BtWLoadoutsFrame.Profiles

	local set = tab.set;
	local selected = set and set.soulbinds and set.soulbinds[index];

    info.arg2 = index

    if (level or 1) == 1 then
		info.text = NONE;
        info.func = DropDown_OnClick;
		info.checked = selected == nil;
        UIDropDownMenu_AddButton(info, level);

        for _,covenantID in ipairs(GetCovenantIDs()) do
            local covenantData = GetCovenantData(covenantID)

            info.text = covenantData.name;
            info.hasArrow, info.menuList = true, covenantData.ID;
            info.keepShownOnClick = true;
            info.notCheckable = true;
            UIDropDownMenu_AddButton(info, level);
        end
    else
        local covenantData = GetCovenantData(menuList)
        for _,soulbindID in ipairs(covenantData.soulbindIDs) do
            local soulbindData = GetSoulbindData(soulbindID)

            info.text = soulbindData.name;
			info.arg1 = soulbindData.ID;
            info.func = DropDown_OnClick;
            info.checked = selected == soulbindData.ID;
            UIDropDownMenu_AddButton(info, level);
        end
    end
end

Internal.AddLoadoutSegment({
    id = "soulbinds",
    name = L["Soulbinds"],
    events = "SOULBIND_ACTIVATED",
    get = GetSets,
    combine = CombineSets,
    isActive = IsSetActive,
	activate = ActivateSet,
	dropdowninit = DropDownInit,
})