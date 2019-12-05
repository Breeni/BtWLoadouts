local ADDON_NAME,Internal = ...
local L = Internal.L

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
	local complete = true;
	local talents = {};
	local usedSlots = {};

	for talentID in pairs(set.talents) do
		talents[talentID] = true;
	end

	for slot=1,4 do
		local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slot);
		local talentID = slotInfo.selectedTalentID;
		if talentID and talents[talentID] then
			usedSlots[slot] = true;
			talents[talentID] = nil;
		end
	end

	if checkExtraTalents then
		local talentIDs = C_SpecializationInfo.GetAllSelectedPvpTalentIDs()
		for _,talentID in pairs(talentIDs) do
			if talents[talentID] then
				talents[talentID] = nil;
			end
		end
	end

	for slot=1,4 do
		local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slot);
		if not usedSlots[slot] and slotInfo.enabled then
			for _,talentID in ipairs(slotInfo.availableTalentIDs) do
				if talents[talentID] then
					complete = LearnPvpTalent(talentID, slot) and complete;

					usedSlots[slot] = true;
					talents[talentID] = nil;

					break;
				end
			end
		end
	end

	return complete
end
local function AddPvPTalentSet()
    local specID, specName = GetSpecializationInfo(GetSpecialization());
    local name = format(L["New %s Set"], specName);
	local talents = {};
	
    local talentIDs = C_SpecializationInfo.GetAllSelectedPvpTalentIDs();
    for _,talentID in ipairs(talentIDs) do
		talents[talentID] = true;
    end

    local set = {
		setID = GetNextSetID(BtWLoadoutsSets.pvptalents),
        specID = specID,
        name = name,
        talents = talents,
		useCount = 0,
    };
    BtWLoadoutsSets.pvptalents[set.setID] = set;
    return set;
end
local function GetPvPTalentSet(id)
    if type(id) == "table" then
		return id;
	else
		return BtWLoadoutsSets.pvptalents[id];
	end
end
local function GetPvPTalentSetByName(name)
	for _,set in pairs(BtWLoadoutsSets.pvptalents) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
end
local function GetPvPTalentSets(id, ...)
	if id ~= nil then
		return BtWLoadoutsSets.pvptalents[id], GetPvPTalentSets(...);
	end
end
local function GetPvPTalentSetIfNeeded(id)
	if id == nil then
		return;
	end

	local set = GetPvPTalentSet(id);
	if IsPvPTalentSetActive(set) then
		return;
	end

    return set;
end
local function CombinePvPTalentSets(result, ...)
	local result = result or {};
	result.talents = {};

	wipe(talentSetsByTier);
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
	DeleteSet(BtWLoadoutsSets.pvptalents, id);

	if type(id) == "table" then
		id = id.setID;
	end
	for _,set in pairs(BtWLoadoutsSets.profiles) do
		if type(set) == "table" and set.pvpTalentSet == id then
			set.pvpTalentSet = nil;
		end
	end

	local frame = BtWLoadoutsFrame.PvPTalents;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil;-- = select(2,next(BtWLoadoutsSets.pvptalents)) or {};
		BtWLoadoutsFrame:Update();
	end
end

do
    local frame = BtWLoadoutsFrame.PvPTalents
    Internal.AddTab({
        type = "pvptalents",
        name = L["PvP Talents"],
        frame = frame,
        onInit = function ()
        end,
        onUpdate = function (self)
        end,
    })
end