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
local function GetSetsByName(tbl, sets, name)
	name = name:lower():trim()
    if type(sets) == "string" then
        sets = BtWLoadoutsSets[sets]
    end

	for _,set in pairs(sets) do
		if type(set) == "table" and set.name:lower():trim() == name then
			tbl[#tbl+1] = set;
		end
	end
	return tbl
end
local GetSetByName
do
	local comparisons = {}
	function GetSetByName(sets, name, validCallback)
		if type(sets) == "string" then
			sets = BtWLoadoutsSets[sets]
		end

		if validCallback then
			local sets = GetSetsByName({}, sets, name)

			wipe(comparisons)
			for _,set in ipairs(sets) do
				local valid, validForClass, validForSpec = validCallback(set)
				comparisons[set] = (valid and 1 or 0) + (validForClass and 1 or 0) + (validForSpec and 1 or 0)
			end

			sort(sets, function (a,b)
				if comparisons[a] == comparisons[b] then
					-- Would do name, but they all have the same name, and this should be the most consistent
					return a.setID < b.setID
				end

				return comparisons[a] > comparisons[b]
			end)

			return sets[1]
		else -- When we cant compare the validity of the sets we just return the first one we encounter
			name = name:lower():trim()
			for _,set in pairs(sets) do
				if type(set) == "table" and set.name:lower():trim() == name then
					return set;
				end
			end
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
	set.useCount = set.useCount or 0
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
Internal.GetSetsByName = GetSetsByName;
Internal.AddSet = AddSet;
Internal.DeleteSet = DeleteSet;