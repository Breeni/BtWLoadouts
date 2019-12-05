local ADDON_NAME,Internal = ...
local L = Internal.L

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
local function AddEssenceSet()
    local role = select(5,GetSpecializationInfo(GetSpecialization()));
    local name = format(L["New %s Set"], _G[role]);
	local selected = {};
	
    selected[115] = C_AzeriteEssence.GetMilestoneEssence(115);
    selected[116] = C_AzeriteEssence.GetMilestoneEssence(116);
    selected[117] = C_AzeriteEssence.GetMilestoneEssence(117);

    local set = {
		setID = GetNextSetID(BtWLoadoutsSets.essences),
        role = role,
        name = name,
        essences = selected,
		useCount = 0,
    };
    BtWLoadoutsSets.essences[set.setID] = set;
    return set;
end
local function GetEssenceSet(id)
    if type(id) == "table" then
		return id;
	else
		return BtWLoadoutsSets.essences[id];
	end
end
local function GetEssenceSetByName(name)
	for _,set in pairs(BtWLoadoutsSets.essences) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
end
local function GetEssenceSets(id, ...)
	if id ~= nil then
		return BtWLoadoutsSets.essences[id], GetEssenceSets(...);
	end
end
local function GetEssenceSetIfNeeded(id)
	if id == nil then
		return;
	end

	local set = GetEssenceSet(id);
	if IsEssenceSetActive(set) then
		return;
	end

    return set;
end
local function CombineEssenceSets(result, ...)
	local result = result or {};

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
	DeleteSet(BtWLoadoutsSets.essences, id);

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

do
    local frame = BtWLoadoutsFrame.Essences
    Internal.AddTab({
        type = "essences",
        name = L["Essences"],
        frame = frame,
        onInit = function ()
        end,
        onUpdate = function (self)
        end,
    })
end