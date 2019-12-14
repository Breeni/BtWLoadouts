--[[
    Generic Set handling functions
]]

local _,Internal = ...

local function GetNextSetID(sets)
    if type(sets) == "string" then
        sets = BtWLoadoutsSets[sets]
    end

	local nextID = sets.nextID or 1
	while sets[nextID] ~= nil do
		nextID = nextID + 1
	end
	sets.nextID = nextID
	return nextID;
end
local function GetSet(sets, id)
	if type(id) == "table" then
		return id
	end
	if type(sets) == "string" then
        sets = BtWLoadoutsSets[sets]
    end

    return sets[id]
end
local function GetSetByName(sets, name)
    if type(sets) == "string" then
        sets = BtWLoadoutsSets[sets]
    end

	for _,set in pairs(sets) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
end
local function AddSet(sets, set)
    if type(sets) == "string" then
        sets = BtWLoadoutsSets[sets]
    end

    if not set.setID then
        set.setID = GetNextSetID(sets)
    end
    sets[set.setID] = set
    return set
end
local function DeleteSet(sets, id)
    if type(sets) == "string" then
        sets = BtWLoadoutsSets[sets]
    end

	if type(id) == "table" then
		if id.setID then
			DeleteSet(sets, id.setID);
		else
			for k,v in pairs(sets) do
				if v == id then
					sets[k] = nil;
					break;
				end
			end
		end
	else
		sets[id] = nil;
		if sets.nextID == nil or id < sets.nextID then
			sets.nextID = id;
		end
	end
end
Internal.GetNextSetID = GetNextSetID;
Internal.GetSet = GetSet;
Internal.GetSetByName = GetSetByName;
Internal.AddSet = AddSet;
Internal.DeleteSet = DeleteSet;