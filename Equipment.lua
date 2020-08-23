local ADDON_NAME,Internal = ...
local L = Internal.L

local ClearCursor = ClearCursor
local PickupInventoryItem = PickupInventoryItem
local PickupContainerItem = PickupContainerItem
local GetContainerFreeSlots = GetContainerFreeSlots
local EquipmentManager_UnpackLocation = EquipmentManager_UnpackLocation
local GetInventoryItemLink = GetInventoryItemLink
local GetContainerItemLink = GetContainerItemLink
local GetVoidItemHyperlinkString = GetVoidItemHyperlinkString
local GetItemUniqueness = GetItemUniqueness

local HelpTipBox_Anchor = Internal.HelpTipBox_Anchor;
local HelpTipBox_SetText = Internal.HelpTipBox_SetText;

local AddSet = Internal.AddSet

local sort = table.sort
local format = string.format

local GetCharacterSlug = Internal.GetCharacterSlug

--[[
    GetItemUniqueness will sometimes return Unique-Equipped info instead of Legion Legendary info,
    this is a cache of items with that or similar issues
]]
local itemUniquenessCache = {
    [144259] = {357, 2},
    [144258] = {357, 2},
    [144249] = {357, 2},
    [152626] = {357, 2},
    [151650] = {357, 2},
    [151649] = {357, 2},
    [151647] = {357, 2},
    [151646] = {357, 2},
    [151644] = {357, 2},
    [151643] = {357, 2},
    [151642] = {357, 2},
    [151641] = {357, 2},
    [151640] = {357, 2},
    [151639] = {357, 2},
    [151636] = {357, 2},
    [150936] = {357, 2},
    [138854] = {357, 2},
    [137382] = {357, 2},
    [137276] = {357, 2},
    [137223] = {357, 2},
    [137220] = {357, 2},
    [137055] = {357, 2},
    [137054] = {357, 2},
    [137052] = {357, 2},
    [137051] = {357, 2},
    [137050] = {357, 2},
    [137049] = {357, 2},
    [137048] = {357, 2},
    [137047] = {357, 2},
    [137046] = {357, 2},
    [137045] = {357, 2},
    [137044] = {357, 2},
    [137043] = {357, 2},
    [137042] = {357, 2},
    [137041] = {357, 2},
    [137040] = {357, 2},
    [137039] = {357, 2},
    [137038] = {357, 2},
    [137037] = {357, 2},
    [133974] = {357, 2},
    [133973] = {357, 2},
    [132460] = {357, 2},
    [132452] = {357, 2},
    [132449] = {357, 2},
    [132410] = {357, 2},
    [132378] = {357, 2},
    [132369] = {357, 2},
}
-- Returns the same as GetItemUniqueness except uses the above cache, also converts -1 family to itemID
local function GetItemUniquenessCached(itemLink)
	local itemID = GetItemInfoInstant(itemLink)
	local uniqueFamily, maxEquipped

	if itemUniquenessCache[itemID] then
		uniqueFamily, maxEquipped = unpack(itemUniquenessCache[itemID])
	else
		uniqueFamily, maxEquipped = GetItemUniqueness(itemLink)
	end

	if uniqueFamily == -1 then
		uniqueFamily = -itemID
	end

	return uniqueFamily, maxEquipped
end
local freeSlotsCache = {}
local function GetContainerItemLocked(bag, slot)
	local locked = select(3, GetContainerItemInfo(bag, slot))
	return locked and true or false
end
local function IsLocationLocked(location)
	local player, bank, bags, voidStorage, slot, bag, tab, voidSlot = EquipmentManager_UnpackLocation(location);
	if not player and not bank and not bags and not voidStorage then -- Invalid location
		return;
	end

	local locked;
	if voidStorage then
		locked = select(3, GetVoidItemInfo(tab, voidSlot))
	elseif not bags then -- and (player or bank)
		locked = IsInventoryItemLocked(slot)
	else -- bags
		locked = select(3, GetContainerItemInfo(bag, slot))
	end

	return locked;
end
local function EmptyInventorySlot(inventorySlotId)
    local itemBagType = GetItemFamily(GetInventoryItemLink("player", inventorySlotId))

    local foundSlot = false
    local containerId, slotId
	for i = NUM_BAG_SLOTS, 0, -1 do
        local _, bagType = GetContainerNumFreeSlots(i)
		local freeSlots = freeSlotsCache[i]
		if #freeSlots > 0 and (bit.band(bagType, itemBagType) > 0 or bagType == 0) then
            foundSlot = true
			containerId = i
			slotId = freeSlots[#freeSlots]
			freeSlots[#freeSlots] = nil

            break
        end
    end

	local complete = false;
	if foundSlot then
        ClearCursor()

        PickupInventoryItem(inventorySlotId)
		if CursorHasItem() then
			PickupContainerItem(containerId, slotId)

			-- If the swap succeeded then the cursor should be empty
			if not CursorHasItem() then
				complete = true;
			end
		end

        ClearCursor();
    end

    return complete, foundSlot
end
-- Modified version of EquipmentManager_GetItemInfoByLocation but gets the item link instead
local function GetItemLinkByLocation(location)
	local player, bank, bags, voidStorage, slot, bag, tab, voidSlot = EquipmentManager_UnpackLocation(location);
	if not player and not bank and not bags and not voidStorage then -- Invalid location
		return;
	end

	local itemLink;
	if voidStorage then
		itemLink = GetVoidItemHyperlinkString(tab, voidSlot);
	elseif not bags then -- and (player or bank)
		itemLink = GetInventoryItemLink("player", slot);
	else -- bags
		itemLink = GetContainerItemLink(bag, slot);
	end

	return itemLink;
end
local function SwapInventorySlot(inventorySlotId, itemLink, location)
	local complete = false;
	local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location);
	if not voidStorage and not (player and not bags and slot == inventorySlotId) and not IsLocationLocked(location) then
        ClearCursor()
        if bag == nil then
            PickupInventoryItem(slot)
        else
			PickupContainerItem(bag, slot)
		end

		if CursorHasItem() then
			PickupInventoryItem(inventorySlotId)

			-- If the swap succeeded then the cursor should be empty
			if not CursorHasItem() then
				complete = true;
			end
		end

		Internal.LogMessage("Switching inventory slot %d to %s (%s)", inventorySlotId, GetItemLinkByLocation(location), complete and "true" or "false")

		ClearCursor();
    end

    return complete
end
Internal.GetItemLinkByLocation = GetItemLinkByLocation;
local function CompareItemLinks(a, b)
	local itemIDA = GetItemInfoInstant(a);
	local itemIDB = GetItemInfoInstant(b);

	return itemIDA == itemIDB;
end
local function CompareItems(itemLinkA, itemLinkB)
	return CompareItemLinks(itemLinkA, itemLinkB);
end
-- item:127454::::::::120::::1:0:
-- item:127454::::::::120::512::1:5473:120
-- item:127454::::::::120:268:512:22:2:6314:6313:120:::
local function GetCompareItemInfo(itemLink)
	local itemString = string.match(itemLink, "item[%-?%d:]+");
	local linkData = {strsplit(":", itemString)};

	local itemID = tonumber(linkData[2]);
	local enchantID = tonumber(linkData[3]);
	local gemIDs = {n = 4, [tonumber(linkData[4]) or 0] = true, [tonumber(linkData[5]) or 0] = true, [tonumber(linkData[6]) or 0] = true, [tonumber(linkData[7]) or 0] = true};
	local suffixID = tonumber(linkData[8]);
	local uniqueID = tonumber(linkData[9]);
	local upgradeTypeID = tonumber(linkData[12]);

	local index = 14;
	local numBonusIDs = tonumber(linkData[index]) or 0;

	local bonusIDs = {n = numBonusIDs};
	for i=1,numBonusIDs do
		local id = tonumber(linkData[index + i])
		if id then
			bonusIDs[id] = true;
		end
	end
	index = index + numBonusIDs + 1;

	local upgradeTypeIDs = {n = 2};
	if upgradeTypeID and upgradeTypeID ~= 0 then
		local id = tonumber(linkData[index + 1]);
		if id then
			upgradeTypeIDs[id] = true
		end
		if bit.band(upgradeTypeID, 0x1000000) ~= 0 then
			id = tonumber(linkData[index + 2]);
			if id then
				upgradeTypeIDs[id] = true
			end
		end
	end
	index = index + 2;

	local relic1NumBonusIDs = tonumber(linkData[index]) or 0;
	local relic1BonusIDs = {n = relic1NumBonusIDs};
	for i=1,relic1NumBonusIDs do
		local id = tonumber(linkData[index + i])
		if id then
			relic1BonusIDs[id] = true;
		end
	end
	index = index + relic1NumBonusIDs + 1;

	local relic2NumBonusIDs = tonumber(linkData[index]) or 0;
	local relic2BonusIDs = {n = relic2NumBonusIDs};
	for i=1,relic2NumBonusIDs do
		local id = tonumber(linkData[index + i])
		if id then
			relic2BonusIDs[id] = true;
		end
	end
	index = index + relic2NumBonusIDs + 1;

	local relic3NumBonusIDs = tonumber(linkData[index]) or 0;
	local relic3BonusIDs = {n = relic3NumBonusIDs};
	for i=1,relic3NumBonusIDs do
		local id = tonumber(linkData[index + i])
		if id then
			relic3BonusIDs[id] = true;
		end
	end
	-- index = index + relic3NumBonusIDs + 1;

	return itemID, enchantID, gemIDs, suffixID, uniqueID, upgradeTypeID, bonusIDs, upgradeTypeIDs, relic1BonusIDs, relic2BonusIDs, relic3BonusIDs;
end
local GetBestMatch;
do
	local itemLocation = ItemLocation:CreateEmpty();
	local function GetMatchValue(itemLink, extras, location)
		local player, bank, bags, voidStorage, slot, bag, tab, voidSlot = EquipmentManager_UnpackLocation(location);
		if not player and not bank and not bags and not voidStorage then -- Invalid location
			return 0;
		end

		local locationItemLink;
		if voidStorage then
			locationItemLink = GetVoidItemHyperlinkString(tab, voidSlot);
			itemLocation:Clear();
		elseif not bags then -- and (player or bank)
			locationItemLink = GetInventoryItemLink("player", slot);
			itemLocation:SetEquipmentSlot(slot);
		else -- bags
			locationItemLink = GetContainerItemLink(bag, slot);
			itemLocation:SetBagAndSlot(bag, slot);
		end

		local match = 0;
		local itemID, enchantID, gemIDs, suffixID, uniqueID, upgradeTypeID, bonusIDs, upgradeTypeIDs, relic1BonusIDs, relic2BonusIDs, relic3BonusIDs = GetCompareItemInfo(itemLink);
		local locationItemID, locationEnchantID, locationGemIDs, locationSuffixID, locationUniqueID, locationUpgradeTypeID, locationBonusIDs, locationUpgradeTypeIDs, locationRelic1BonusIDs, locationRelic2BonusIDs, locationRelic3BonusIDs = GetCompareItemInfo(locationItemLink);

		if enchantID == locationEnchantID then
			match = match + 1;
		end
		if suffixID == suffixID then
			match = match + 1;
		end
		if uniqueID == locationUniqueID then
			match = match + 1;
		end
		if upgradeTypeID == locationUpgradeTypeID then
			match = match + 1;
		end
		local id = nil
		for i=1,math.max(gemIDs.n,locationGemIDs.n) do
			id = next(gemIDs, id)
			if id and locationGemIDs[id] then
				match = match + 1;
			end
		end
		id = nil
		for i=1,math.max(bonusIDs.n,locationBonusIDs.n) do
			id = next(bonusIDs, id)
			if id and locationBonusIDs[id] then
				match = match + 1;
			end
		end
		id = nil
		for i=1,math.max(upgradeTypeIDs.n,locationUpgradeTypeIDs.n) do
			id = next(upgradeTypeIDs, id)
			if id and locationUpgradeTypeIDs[id] then
				match = match + 1;
			end
		end
		id = nil
		for i=1,math.max(relic1BonusIDs.n,locationRelic1BonusIDs.n) do
			id = next(relic1BonusIDs, id)
			if id and locationRelic1BonusIDs[id] then
				match = match + 1;
			end
		end
		id = nil
		for i=1,math.max(relic2BonusIDs.n,locationRelic2BonusIDs.n) do
			id = next(relic2BonusIDs, id)
			if id and locationRelic2BonusIDs[id] then
				match = match + 1;
			end
		end
		id = nil
		for i=1,math.max(relic3BonusIDs.n,locationRelic3BonusIDs.n) do
			id = next(relic3BonusIDs, id)
			if id and locationRelic3BonusIDs[id] then
				match = match + 1;
			end
		end

		if extras and extras.azerite and itemLocation:HasAnyLocation() and itemLocation:IsValid() and C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem(itemLocation) then
			for _,powerID in ipairs(extras.azerite) do
				if C_AzeriteEmpoweredItem.IsPowerSelected(itemLocation, powerID) then
					match = match + 1;
				end
			end
		end

		return match;
	end

	local locationMatchValue, locationFiltered = {}, {};
	function GetBestMatch(itemLink, extras, locations)
		local itemID = GetItemInfoInstant(itemLink);
		wipe(locationMatchValue);
		wipe(locationFiltered);
		for location,locationItemID in pairs(locations) do
			if itemID == locationItemID then
				locationMatchValue[location] = GetMatchValue(itemLink, extras, location);
				locationFiltered[#locationFiltered+1] = location;
			end
		end
		sort(locationFiltered, function (a,b)
			if locationMatchValue[a] == locationMatchValue[b] then
				return a > b
			end
			return locationMatchValue[a] > locationMatchValue[b];
		end);

		return locationFiltered[1];
	end
end
local IsItemInLocation;
do
	local function CompareTables(a, b)
		if a.n ~= b.n then
			return false
		end
		for k in pairs(a) do
			if not b[k] then
				return false
			end
		end
		return true
	end
	local itemLocation = ItemLocation:CreateEmpty();
	function IsItemInLocation(itemLink, extras, player, bank, bags, voidStorage, slot, bag, tab, voidSlot)
		if type(player) == "number" then
			player, bank, bags, voidStorage, slot, bag, tab, voidSlot = EquipmentManager_UnpackLocation(player);
		end

		if not player and not bank and not bags and not voidStorage then -- Invalid location
			return false;
		end

		local locationItemLink;
		if voidStorage then
			locationItemLink = GetVoidItemHyperlinkString(tab, voidSlot);
			itemLocation:Clear();
		elseif not bags then -- and (player or bank)
			locationItemLink = GetInventoryItemLink("player", slot);
			itemLocation:SetEquipmentSlot(slot);
		else -- bags
			locationItemLink = GetContainerItemLink(bag, slot);
			itemLocation:SetBagAndSlot(slot);
		end

		if itemLink ~= nil and locationItemLink == nil then
			return false;
		end
		if itemLink == nil and locationItemLink ~= nil then
			return false;
		end

		local itemID, enchantID, gemIDs, suffixID, uniqueID, upgradeTypeID, bonusIDs, upgradeTypeIDs, relic1BonusIDs, relic2BonusIDs, relic3BonusIDs = GetCompareItemInfo(itemLink);
		local locationItemID, locationEnchantID, locationGemIDs, locationSuffixID, locationUniqueID, locationUpgradeTypeID, locationBonusIDs, locationUpgradeTypeIDs, locationRelic1BonusIDs, locationRelic2BonusIDs, locationRelic3BonusIDs = GetCompareItemInfo(locationItemLink);
		if itemID ~= locationItemID or enchantID ~= locationEnchantID or #gemIDs ~= #locationGemIDs or suffixID ~= locationSuffixID or uniqueID ~= locationUniqueID or upgradeTypeID ~= locationUpgradeTypeID or #bonusIDs ~= #bonusIDs or #relic1BonusIDs ~= #locationRelic1BonusIDs or #relic2BonusIDs ~= #locationRelic2BonusIDs or #relic3BonusIDs ~= #locationRelic3BonusIDs then
			return false;
		end
		if not CompareTables(gemIDs, locationGemIDs) then
			return false
		end
		if not CompareTables(bonusIDs, locationBonusIDs) then
			return false
		end
		if not CompareTables(upgradeTypeIDs, locationUpgradeTypeIDs) then
			return false
		end
		if not CompareTables(relic1BonusIDs, locationRelic1BonusIDs) then
			return false
		end
		if not CompareTables(relic2BonusIDs, locationRelic2BonusIDs) then
			return false
		end
		if not CompareTables(relic3BonusIDs, locationRelic3BonusIDs) then
			return false
		end

		if extras and extras.azerite and itemLocation:HasAnyLocation() and itemLocation:IsValid() and C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem(itemLocation) then
			for _,powerID in ipairs(extras.azerite) do
				if not C_AzeriteEmpoweredItem.IsPowerSelected(itemLocation, powerID) then
					return false;
				end
			end
		end

		return true;
	end
end
local CheckEquipmentSetForIssues
do
	local uniqueFamilies = {}
	local uniqueFamilyItems = {}
	function CheckEquipmentSetForIssues(set)
		local ignored = set.ignored
		local expected = set.equipment
		local errors = set.errors or {}
		wipe(uniqueFamilies)
		wipe(uniqueFamilyItems)

		local firstEquipped = INVSLOT_FIRST_EQUIPPED
		local lastEquipped = INVSLOT_LAST_EQUIPPED

		for inventorySlotId = firstEquipped, lastEquipped do
			errors[inventorySlotId] = nil

			if not ignored[inventorySlotId] and expected[inventorySlotId] then
				local itemLink = expected[inventorySlotId]
				local uniqueFamily, maxEquipped = GetItemUniquenessCached(itemLink)

				if uniqueFamily ~= nil then
					uniqueFamilies[uniqueFamily] = (uniqueFamilies[uniqueFamily] or maxEquipped) - 1

					if uniqueFamilyItems[uniqueFamily] then
						uniqueFamilyItems[uniqueFamily][#uniqueFamilyItems[uniqueFamily]+1] = inventorySlotId
					else
						uniqueFamilyItems[uniqueFamily] = {inventorySlotId}
					end
				end

				local index = 1
				local gemName, gemLink = GetItemGem(itemLink, index)
				while gemName do
					uniqueFamily, maxEquipped = GetItemUniquenessCached(gemLink)

					if uniqueFamily ~= nil then
						uniqueFamilies[uniqueFamily] = (uniqueFamilies[uniqueFamily] or maxEquipped) - 1

						if uniqueFamilyItems[uniqueFamily] then
							uniqueFamilyItems[uniqueFamily][#uniqueFamilyItems[uniqueFamily]+1] = inventorySlotId
						else
							uniqueFamilyItems[uniqueFamily] = {inventorySlotId}
						end
					end

					index = index + 1
					gemName, gemLink = GetItemGem(itemLink, index)
				end
			end
		end

		for uniqueFamily, maxEquipped in pairs(uniqueFamilies) do
			if maxEquipped < 0 then
				for _,inventorySlotId in ipairs(uniqueFamilyItems[uniqueFamily]) do
					if errors[inventorySlotId] then
						errors[inventorySlotId] = format("%s\n%s", errors[inventorySlotId], ERR_ITEM_UNIQUE_EQUIPPABLE)
					elseif uniqueFamily < 0 then -- Item
						errors[inventorySlotId] = ERR_ITEM_UNIQUE_EQUIPPABLE
					else
						errors[inventorySlotId] = ERR_ITEM_UNIQUE_EQUIPPABLE
					end
				end
			end
		end

		set.errors = errors
		return errors
	end
end
local function IsEquipmentSetActive(set)
	local expected = set.equipment;
	local extras = set.extras;
	local locations = set.locations;
	local ignored = set.ignored;

    local firstEquipped = INVSLOT_FIRST_EQUIPPED;
    local lastEquipped = INVSLOT_LAST_EQUIPPED;

    -- if combatSwap then
    --     firstEquipped = INVSLOT_MAINHAND;
    --     lastEquipped = INVSLOT_RANGED;
	-- end

	for inventorySlotId=firstEquipped,lastEquipped do
		if not ignored[inventorySlotId] then
			if expected[inventorySlotId] then
				if locations[inventorySlotId] then
					local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(locations[inventorySlotId]);
					if not (player and not bags and slot == inventorySlotId) then
						return false;
					end
				else
					local itemLink = GetInventoryItemLink("player", inventorySlotId)
					if not itemLink or not CompareItemLinks(itemLink, expected[inventorySlotId]) then
						return false;
					end
				end
			elseif GetInventoryItemLink("player", inventorySlotId) ~= nil then
				return false;
			end
		end
	end
    return true;
end
local ActivateEquipmentSet;
do
	local possibleItems = {};
	local bestMatchForSlot = {};
	local uniqueFamiliesTemp = {};
	local uniqueFamilies = {};
	-- This function is destructive to the set
	function ActivateEquipmentSet(set)
		local ignored = set.ignored;
		local expected = set.equipment;
		local extras = set.extras;
		local locations = set.locations;
		local errors = set.errors;
		local anyLockedSlots, anyFoundFreeSlots, anyChangedSlots = nil, nil, nil
		wipe(uniqueFamilies)

		local firstEquipped = INVSLOT_FIRST_EQUIPPED
		local lastEquipped = INVSLOT_LAST_EQUIPPED

		-- if combatSwap then
		-- 	firstEquipped = INVSLOT_MAINHAND
		-- 	lastEquipped = INVSLOT_RANGED
		-- end

		-- Store a list of all available empty slots
		local totalFreeSlots = 0
		for i=BACKPACK_CONTAINER,NUM_BAG_SLOTS do
			if not freeSlotsCache[i] then
				freeSlotsCache[i] = {}
			else
				wipe(freeSlotsCache[i])
			end

			if GetContainerFreeSlots(i, freeSlotsCache[i]) then
				totalFreeSlots = totalFreeSlots + #freeSlotsCache[i]
			end
		end

		-- Loop through and empty slots that should be empty, also store locations for other slots
		for inventorySlotId = firstEquipped, lastEquipped do
			if errors and errors[inventorySlotId] then -- If there is an error in a slot, normally due to unique-equipped items then just ignore it
				ignored[inventorySlotId] = true
			end

			if not ignored[inventorySlotId] and locations[inventorySlotId] and locations[inventorySlotId] ~= -1 and not expected[inventorySlotId] then
				expected[inventorySlotId] = GetItemLinkByLocation(locations[inventorySlotId])

				if not expected[inventorySlotId] then
					ignored[inventorySlotId] = true
				end
			end

			if not ignored[inventorySlotId] then
				local slotLocked = IsInventoryItemLocked(inventorySlotId)
				anyLockedSlots = anyLockedSlots or slotLocked

				local itemLink = expected[inventorySlotId];
				if itemLink then
					local location = locations[inventorySlotId];
					if location and location ~= -1 and IsItemInLocation(itemLink, extras[inventorySlotId], location) then
						local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location);
						if player and not bags and slot == inventorySlotId then -- The item is already in the desired location
							ignored[inventorySlotId] = true;
						else
							bestMatchForSlot[inventorySlotId] = location;
						end
					else
						-- The item is already in the desired location
						if IsItemInLocation(itemLink, extras[inventorySlotId], true, false, false, false, inventorySlotId, false) then
							ignored[inventorySlotId] = true;
						else
							location = GetBestMatch(itemLink, extras[inventorySlotId], GetInventoryItemsForSlot(inventorySlotId, possibleItems));
							wipe(possibleItems);
							if location == nil then -- Could not find the requested item @TODO Error
								ignored[inventorySlotId] = true;
							else
								local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location);
								if player and not bags and slot == inventorySlotId then -- The item is already in the desired location, this shouldnt happen
									ignored[inventorySlotId] = true;
								end
								bestMatchForSlot[inventorySlotId] = location;
							end
						end
					end
				else -- Unequip
					if GetInventoryItemLink("player", inventorySlotId) ~= nil then
						if not IsInventoryItemLocked(inventorySlotId) then
							local complete, foundSlot = EmptyInventorySlot(inventorySlotId)
							anyChangedSlots = anyChangedSlots or complete
							anyFoundFreeSlots = anyFoundFreeSlots or foundSlot
						end
					else -- Already unequipped
						ignored[inventorySlotId] = true;
					end
				end
			end

			-- If we arent swapping an item out and its in some way unique we may need to skip swapping another unique item in
			if ignored[inventorySlotId] then
				local itemLink = GetInventoryItemLink("player", inventorySlotId)
				if itemLink then
					local itemID = GetItemInfoInstant(itemLink)
					local uniqueFamily, maxEquipped = GetItemUniquenessCached(itemLink)

					if uniqueFamily ~= nil then
						uniqueFamilies[uniqueFamily] = (uniqueFamilies[uniqueFamily] or maxEquipped) - 1
					end

					local index = 1
					local gemName, gemLink = GetItemGem(itemLink, index)
					while gemName do
						itemID = GetItemInfoInstant(gemLink)
						uniqueFamily, maxEquipped = GetItemUniquenessCached(gemLink)

						if uniqueFamily ~= nil then
							uniqueFamilies[uniqueFamily] = (uniqueFamilies[uniqueFamily] or maxEquipped) - 1
						end

						index = index + 1
						gemName, gemLink = GetItemGem(itemLink, index)
					end
				end
			end
		end

		-- Check expected items uniqueness
		for inventorySlotId = firstEquipped, lastEquipped do
			if not ignored[inventorySlotId] and expected[inventorySlotId] then
				local itemLink = expected[inventorySlotId];
				local itemID = GetItemInfoInstant(itemLink);
				local uniqueFamily, maxEquipped = GetItemUniquenessCached(itemLink)

				if uniqueFamily then
					if uniqueFamilies[uniqueFamily] then
						if uniqueFamilies[uniqueFamily] <= 0 then
							-- print(format("%s cannot be equipped because it is unique", itemLink))
							ignored[inventorySlotId] = true -- To many of the unique items already equipped
						else
							uniqueFamiliesTemp[uniqueFamily] = true
						end

						uniqueFamilies[uniqueFamily] = uniqueFamilies[uniqueFamily] - 1
					end
				end

				if not ignored[inventorySlotId] then
					local index = 1
					local gemName, gemLink = GetItemGem(itemLink, index)
					while gemName do
						itemID = GetItemInfoInstant(gemLink);
						uniqueFamily, maxEquipped = GetItemUniquenessCached(gemLink)

						if uniqueFamily and uniqueFamilies[uniqueFamily] then
							uniqueFamiliesTemp[uniqueFamily] = true

							if uniqueFamilies[uniqueFamily] <= 0 then
								-- print(format("%s cannot be equipped because its gem is unique", itemLink))
								ignored[inventorySlotId] = true -- To many of the unique items already equipped
								break
							else
								uniqueFamiliesTemp[uniqueFamily] = true
							end

							uniqueFamilies[uniqueFamily] = uniqueFamilies[uniqueFamily] - 1
						end

						index = index + 1
						gemName, gemLink = GetItemGem(itemLink, index)
					end
				end

				if ignored[inventorySlotId] then
					-- uniqueFamiliesTemp is a list of all the unique families that were non-blocking
					-- because we found 1 that was blocking we will unblock the others
					for uniqueFamily in pairs(uniqueFamiliesTemp) do
						uniqueFamilies[uniqueFamily] = uniqueFamilies[uniqueFamily] + 1
					end
					wipe(uniqueFamiliesTemp)
				end
			end
		end

		-- Swap currently equipped "unique" items that need to be swapped out before others can be swapped in
		for inventorySlotId = firstEquipped, lastEquipped do
			local itemLink = GetInventoryItemLink("player", inventorySlotId)

			if not ignored[inventorySlotId] and not IsInventoryItemLocked(inventorySlotId) and expected[inventorySlotId] and itemLink ~= nil then
				local itemID = GetItemInfoInstant(itemLink);
				local uniqueFamily, maxEquipped = GetItemUniquenessCached(itemLink)

				local swapSlot = (uniqueFamily == -1 and uniqueFamilies[itemID] ~= nil) or uniqueFamilies[uniqueFamily] ~= nil

				if not swapSlot then
					local index = 1
					local gemName, gemLink = GetItemGem(itemLink, index)
					while gemName do
						itemID = GetItemInfoInstant(gemLink)
						uniqueFamily, maxEquipped = GetItemUniquenessCached(gemLink)

						swapSlot = (uniqueFamily == -1 and uniqueFamilies[itemID] ~= nil) or uniqueFamilies[uniqueFamily] ~= nil

						if swapSlot then
							break
						end

						index = index + 1
						gemName, gemLink = GetItemGem(itemLink, index)
					end
				end

				if swapSlot then
					if SwapInventorySlot(inventorySlotId, expected[inventorySlotId], bestMatchForSlot[inventorySlotId]) then
						anyChangedSlots = true
					end
				end
			end
		end

		-- Swap out items
		for inventorySlotId = firstEquipped, lastEquipped do
			if not ignored[inventorySlotId] and not IsInventoryItemLocked(inventorySlotId) and expected[inventorySlotId] then
				if SwapInventorySlot(inventorySlotId, expected[inventorySlotId], bestMatchForSlot[inventorySlotId]) then
					anyChangedSlots = true
				end
			end
		end

		ClearCursor()

		-- We assume that if we have any locked slots or any changed slots we are not complete yet
		local complete = not anyLockedSlots and not anyChangedSlots
		if complete then
			-- If there are no locked slots and not changed slots and we never found a free slot
			-- to remove an item, we will consider ourselves complete but with an error
			if anyFoundFreeSlots == false then
				return complete, L["Failed to change equipment set"]
			end
			for inventorySlotId = firstEquipped, lastEquipped do
				-- We mark slots as ignored when they are finished
				if not ignored[inventorySlotId] then
					complete = false
				end
			end
		end

		return complete, false;
	end
end
local function UpdateEquipmentSetFilters(set)
	local filters = set.filters or {}
	filters.character = set.character
	set.filters = filters

    return set
end
local function GetEquipmentSet(id)
    if type(id) == "table" then
		return id;
	else
		return BtWLoadoutsSets.equipment[id];
	end
end
-- returns isValid and isValidForPlayer
local function EquipmentSetIsValid(set)
	local set = GetEquipmentSet(set);
	local isValidForPlayer = (set.character == GetCharacterSlug())
	return true, isValidForPlayer
end
-- Adds a blank equipment set for the current character
local function AddBlankEquipmentSet()
    local set = {
		setID = Internal.GetNextSetID(BtWLoadoutsSets.equipment),
        character = GetCharacterSlug(),
        name = "",
		equipment = {},
		extras = {},
		locations = {},
		ignored = {},
		filters = {character = GetCharacterSlug()},
		useCount = 0,
    };
    BtWLoadoutsSets.equipment[set.setID] = set;
    return set;
end
-- Update an equipment set with the currently equipped gear
local function RefreshEquipmentSet(set)
	if set.character ~= GetCharacterSlug() then
		return
	end

	for inventorySlotId=INVSLOT_FIRST_EQUIPPED,INVSLOT_LAST_EQUIPPED do
		set.equipment[inventorySlotId] = GetInventoryItemLink("player", inventorySlotId);

		local itemLocation = ItemLocation:CreateFromEquipmentSlot(inventorySlotId);
		if itemLocation and itemLocation:HasAnyLocation() and itemLocation:IsValid() and C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem(itemLocation) then
			set.extras[inventorySlotId] = set.extras[inventorySlotId] or {};
			local extras = set.extras[inventorySlotId];
			extras.azerite = extras.azerite or {};
			wipe(extras.azerite);

			local tiers = C_AzeriteEmpoweredItem.GetAllTierInfo(itemLocation);
			for index,tier in ipairs(tiers) do
				for _,powerID in ipairs(tier.azeritePowerIDs) do
					if C_AzeriteEmpoweredItem.IsPowerSelected(itemLocation, powerID) then
						extras.azerite[index] = powerID;
						break;
					end
				end
			end
		else
			set.extras[inventorySlotId] = nil;
		end
	end

	-- Need to update the built in manager too
	if set.managerID then
		C_EquipmentSet.SaveEquipmentSet(set.managerID)
	end

	return UpdateEquipmentSetFilters(set)
end
local function AddEquipmentSet()
    local characterName, characterRealm = UnitFullName("player");
    return AddSet("equipment", RefreshEquipmentSet({
		character = characterRealm .. "-" .. characterName,
		name = format(L["New %s Equipment Set"], characterName),
		useCount = 0,
        equipment = {},
        ignored = {
			[INVSLOT_BODY] = true,
			[INVSLOT_TABARD] = true,
		},
		extras = {},
		locations = {},
	}))
end
local function GetEquipmentSetsByName(name)
	return Internal.GetSetsByName("equipment", name)
end
local function GetEquipmentSetByName(name)
	return Internal.GetSetByName("equipment", name, EquipmentSetIsValid)
end
local function GetEquipmentSets(id, ...)
	if id ~= nil then
		return BtWLoadoutsSets.equipment[id], Internal.GetEquipmentSets(...);
	end
end
function Internal.GetEquipmentSetIfNeeded(id)
	if id == nil then
		return;
	end

	local set = Internal.GetEquipmentSet(id);
	if IsEquipmentSetActive(set) then
		return;
	end

    return set;
end
local function CombineEquipmentSets(result, state, ...)
	result = result or {};

	local playerCharacter = GetCharacterSlug()

	result.equipment = {};
	result.extras = {};
	result.locations = {};
	result.ignored = {};
	for slot=INVSLOT_FIRST_EQUIPPED,INVSLOT_LAST_EQUIPPED do
		result.ignored[slot] = true;
	end
	for i=1,select('#', ...) do
		local set = select(i, ...);
		if set.character == playerCharacter then -- Skip other characters
			if set.managerID then -- Just making sure everything is up to date
				local ignored = C_EquipmentSet.GetIgnoredSlots(set.managerID);
				local locations = C_EquipmentSet.GetItemLocations(set.managerID);
				for inventorySlotId=INVSLOT_FIRST_EQUIPPED,INVSLOT_LAST_EQUIPPED do
					set.ignored[inventorySlotId] = ignored[inventorySlotId] and true or nil;

					local location = locations[inventorySlotId] or 0;
					if location > -1 then -- If location is -1 we ignore it as we cant get the item link for the item
						set.equipment[inventorySlotId] = GetItemLinkByLocation(location);
					end
					set.locations[inventorySlotId] = location;
					if set.extras[inventorySlotId] then
						wipe(set.extras[inventorySlotId])
					end
				end
			end
			for inventorySlotId=INVSLOT_FIRST_EQUIPPED,INVSLOT_LAST_EQUIPPED do
				if not set.ignored[inventorySlotId] then
					result.ignored[inventorySlotId] = nil;
					result.equipment[inventorySlotId] = set.equipment[inventorySlotId];
					result.extras[inventorySlotId] = set.extras[inventorySlotId] or nil;
					result.locations[inventorySlotId] = set.locations[inventorySlotId] or nil;
				end
			end
		end
	end

	CheckEquipmentSetForIssues(result)

    if state then
		state.combatSwap = false

		if result.ignored[INVSLOT_NECK] then
			state.heartEquipped = GetInventoryItemID("player", INVSLOT_NECK) == 158075
		elseif result.equipment[INVSLOT_NECK] then
			state.heartEquipped = GetItemInfoInstant(result.equipment[INVSLOT_NECK]) == 158075
		else
			state.heartEquipped = false
		end
    end

	return result;
end
local function DeleteEquipmentSet(id)
	Internal.DeleteSet(BtWLoadoutsSets.equipment, id);

	if type(id) == "table" then
		id = id.setID;
	end
	for _,set in pairs(BtWLoadoutsSets.profiles) do
        if type(set) == "table" then
            for index,setID in ipairs(set.equipment) do
                if setID == id then
                    table.remove(set.equipment, index)
                end
			end
			set.character = nil
		end
	end

	local frame = BtWLoadoutsFrame.Equipment;
	local set = frame.set;
	if set and set.setID == id then
		frame.set = nil;
		BtWLoadoutsFrame:Update();
	end
end

Internal.GetEquipmentSet = GetEquipmentSet
Internal.GetEquipmentSetsByName = GetEquipmentSetsByName
Internal.GetEquipmentSetByName = GetEquipmentSetByName
Internal.AddBlankEquipmentSet = AddBlankEquipmentSet
Internal.AddEquipmentSet = AddEquipmentSet
Internal.RefreshEquipmentSet = RefreshEquipmentSet
Internal.DeleteEquipmentSet = DeleteEquipmentSet
Internal.ActivateEquipmentSet = ActivateEquipmentSet
Internal.IsEquipmentSetActive = IsEquipmentSetActive
Internal.CombineEquipmentSets = CombineEquipmentSets
Internal.CheckEquipmentSetForIssues = CheckEquipmentSetForIssues
Internal.GetEquipmentSets = GetEquipmentSets

local function EquipmentDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Profiles

    CloseDropDownMenus();
    local set = tab.set;
	local index = arg2 or (#set.equipment + 1)

	if set.equipment[index] then
		local subset = Internal.GetEquipmentSet(set.equipment[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	if arg1 == nil then
		table.remove(set.equipment, index);
	else
		set.equipment[index] = arg1;
	end

	if set.equipment[index] then
		local subset = Internal.GetEquipmentSet(set.equipment[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame:Update();
end
local function EquipmentDropDown_NewOnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Profiles

	CloseDropDownMenus();
	local set = tab.set;
	local index = arg2 or (#set.equipment + 1)

	if set.equipment[index] then
		local subset = Internal.GetEquipmentSet(set.equipment[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local newSet = Internal.AddEquipmentSet();
	set.equipment[index] = newSet.setID;

	if set.equipment[index] then
		local subset = Internal.GetEquipmentSet(set.equipment[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame.Equipment.set = newSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, TAB_EQUIPMENT);

	BtWLoadoutsFrame:Update();
end
local function EquipmentDropDownInit(self, level, menuList, index)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.equipment then
        return;
    end

	local info = UIDropDownMenu_CreateInfo();

	local tab = BtWLoadoutsFrame.Profiles

	local set = tab.set;
	local selected = set and set.equipment and set.equipment[index];

	info.arg2 = index

	if (level or 1) == 1 then
		info.text = NONE;
		info.func = EquipmentDropDown_OnClick;
		info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

		wipe(setsFiltered);
		local sets = BtWLoadoutsSets.equipment;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" then
				setsFiltered[subset.character] = true;
			end
		end

		local characters = {};
		for character in pairs(setsFiltered) do
			characters[#characters+1] = character;
		end
		sort(characters, function (a,b)
			return a < b;
		end)

		local character = GetCharacterSlug();
		if setsFiltered[character] then
			local name = character;
			local characterInfo = GetCharacterInfo(character);
			if characterInfo then
				local classColor = C_ClassColor.GetClassColor(characterInfo.class);
				name = format("%s - %s", classColor:WrapTextInColorCode(characterInfo.name), characterInfo.realm);
			end

			info.text = name;
			info.hasArrow, info.menuList = true, character;
			info.keepShownOnClick = true;
			info.notCheckable = true;
			UIDropDownMenu_AddButton(info, level);
		end

		local playerCharacter = character;
		for _,character in ipairs(characters) do
			if character ~= playerCharacter then
				if setsFiltered[character] then
					local name = character;
					local characterInfo = GetCharacterInfo(character);
					if characterInfo then
						local classColor = C_ClassColor.GetClassColor(characterInfo.class);
						name = format("%s - %s", classColor:WrapTextInColorCode(characterInfo.name), characterInfo.realm);
					end

					info.text = name;
					info.hasArrow, info.menuList = true, character;
					info.keepShownOnClick = true;
					info.notCheckable = true;
					UIDropDownMenu_AddButton(info, level);
				end
			end
		end

		info.text = L["New Set"];
		info.func = EquipmentDropDown_NewOnClick;
		info.hasArrow, info.menuList = false, nil;
		info.keepShownOnClick = false;
		info.notCheckable = true;
		info.checked = false;
		UIDropDownMenu_AddButton(info, level);
	else
		local character = menuList;

		wipe(setsFiltered);
		local sets = BtWLoadoutsSets.equipment;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" and subset.character == character then
				setsFiltered[#setsFiltered+1] = setID;
			end
		end
		sort(setsFiltered, function (a,b)
			return sets[a].name < sets[b].name;
		end)

        for _,setID in ipairs(setsFiltered) do
            info.text = sets[setID].name .. (sets[setID].managerID ~= nil and " (*)" or "");
            info.arg1 = setID;
            info.func = EquipmentDropDown_OnClick;
            info.checked = selected == setID;
            UIDropDownMenu_AddButton(info, level);
		end
	end
end

Internal.AddLoadoutSegment({
    id = "equipment",
    name = L["Equipment"],
    events = "PLAYER_EQUIPMENT_CHANGED",
    get = GetEquipmentSets,
    combine = CombineEquipmentSets,
    isActive = IsEquipmentSetActive,
	activate = ActivateEquipmentSet,
	dropdowninit = EquipmentDropDownInit,
})

local GetCursorItemSource
do
	local currentCursorSource = {};
	local function Hook_PickupContainerItem(bag, slot)
		if CursorHasItem() then
			currentCursorSource.bag = bag;
			currentCursorSource.slot = slot;
		else
			wipe(currentCursorSource);
		end
	end
	hooksecurefunc("PickupContainerItem", Hook_PickupContainerItem);
	local function Hook_PickupInventoryItem(slot)
		if CursorHasItem() then
			currentCursorSource.slot = slot;
		else
			wipe(currentCursorSource);
		end
	end
	hooksecurefunc("PickupInventoryItem", Hook_PickupInventoryItem);
	function GetCursorItemSource()
		return currentCursorSource.bag or false, currentCursorSource.slot or false;
	end
end

local gameTooltipErrorLink;
local gameTooltipErrorText;

BtWLoadoutsItemSlotButtonMixin = {};
function BtWLoadoutsItemSlotButtonMixin:OnLoad()
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	-- self:RegisterEvent("GET_ITEM_INFO_RECEIVED");

	local id, textureName, checkRelic = GetInventorySlotInfo(self:GetSlot());
	self:SetID(id);
	self.icon:SetTexture(textureName);
	self.backgroundTextureName = textureName;
	self.ignoreTexture:Hide();

	local popoutButton = self.popoutButton;
	if ( popoutButton ) then
		if ( self.verticalFlyout ) then
			popoutButton:SetHeight(16);
			popoutButton:SetWidth(38);

			popoutButton:GetNormalTexture():SetTexCoord(0.15625, 0.84375, 0.5, 0);
			popoutButton:GetHighlightTexture():SetTexCoord(0.15625, 0.84375, 1, 0.5);
			popoutButton:ClearAllPoints();
			popoutButton:SetPoint("TOP", self, "BOTTOM", 0, 4);
		else
			popoutButton:SetHeight(38);
			popoutButton:SetWidth(16);

			popoutButton:GetNormalTexture():SetTexCoord(0.15625, 0.5, 0.84375, 0.5, 0.15625, 0, 0.84375, 0);
			popoutButton:GetHighlightTexture():SetTexCoord(0.15625, 1, 0.84375, 1, 0.15625, 0.5, 0.84375, 0.5);
			popoutButton:ClearAllPoints();
			popoutButton:SetPoint("LEFT", self, "RIGHT", -8, 0);
		end

		-- popoutButton:Show();
	end
end
function BtWLoadoutsItemSlotButtonMixin:OnClick()
	local cursorType, _, itemLink = GetCursorInfo();
	if cursorType == "item" then
		if self:SetItem(itemLink, GetCursorItemSource()) then
			ClearCursor();
		end
	elseif IsModifiedClick("SHIFT") then
		local set = self:GetParent().set;
		self:SetIgnored(not set.ignored[self:GetID()]);
	else
		self:SetItem(nil);
	end
end
function BtWLoadoutsItemSlotButtonMixin:OnReceiveDrag()
	local cursorType, _, itemLink = GetCursorInfo();
	if self:GetParent().set and cursorType == "item" then
		if self:SetItem(itemLink, GetCursorItemSource()) then
			ClearCursor();
		end
	end
end
function BtWLoadoutsItemSlotButtonMixin:OnEvent(event, itemID, success)
	if success then
		local set = self:GetParent().set;
		local slot = self:GetID();
		local itemLink = set.equipment[slot];

		if itemLink and itemID == GetItemInfoInstant(itemLink) then
			self:Update();
			self:UnregisterEvent("GET_ITEM_INFO_RECEIVED");
		end
	end
end
function BtWLoadoutsItemSlotButtonMixin:OnEnter()
	local set = self:GetParent().set;
	local slot = self:GetID();
	local itemLink = set.equipment[slot];

	if itemLink then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetHyperlink(itemLink);
		if self.errors then
			gameTooltipErrorLink = itemLink
			gameTooltipErrorText = self.errors
		else
			gameTooltipErrorLink = nil
			gameTooltipErrorText = nil
		end
	end
end
function BtWLoadoutsItemSlotButtonMixin:OnLeave()
	gameTooltipErrorLink = nil
	gameTooltipErrorText = nil
	GameTooltip:Hide();
end
function BtWLoadoutsItemSlotButtonMixin:OnUpdate()
	if GameTooltip:IsOwned(self) then
		self:OnEnter();
	end
end
function BtWLoadoutsItemSlotButtonMixin:GetSlot()
	return self.slot;
end
function BtWLoadoutsItemSlotButtonMixin:SetItem(itemLink, bag, slot)
	local set = self:GetParent().set;
	if itemLink == nil then -- Clearing slot
		set.equipment[self:GetID()] = nil;

		self:Update();
		return true;
	else
		local _, _, quality, _, _, _, _, _, itemEquipLoc, texture, _, itemClassID, itemSubClassID = GetItemInfo(itemLink);
		if self.invType == itemEquipLoc then
			set.equipment[self:GetID()] = itemLink;

			local itemLocation;
			if bag and slot then
				itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot);
			elseif slot then
				itemLocation = ItemLocation:CreateFromEquipmentSlot(slot);
			end

			if itemLocation and C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem(itemLocation) then
				set.extras[self:GetID()] = set.extras[self:GetID()] or {};
				local extras = set.extras[self:GetID()];
				extras.azerite = extras.azerite or {};
				wipe(extras.azerite);

				local tiers = C_AzeriteEmpoweredItem.GetAllTierInfo(itemLocation);
				for index,tier in ipairs(tiers) do
					for _,powerID in ipairs(tier.azeritePowerIDs) do
						if C_AzeriteEmpoweredItem.IsPowerSelected(itemLocation, powerID) then
							extras.azerite[index] = powerID;
							break;
						end
					end
				end
			else
				set.extras[self:GetID()] = nil;
			end

			BtWLoadoutsFrame:Update(); -- Refresh everything, this'll update the error handling too
			return true;
		end
	end
	return false;
end
function BtWLoadoutsItemSlotButtonMixin:SetIgnored(ignored)
	local set = self:GetParent().set;
	set.ignored[self:GetID()] = ignored and true or nil;
	BtWLoadoutsFrame:Update(); -- Refresh everything, this'll update the error handling too
end
function BtWLoadoutsItemSlotButtonMixin:Update()
	local set = self:GetParent().set;
	local slot = self:GetID();
	local ignored = set.ignored[slot];
	local errors = set.errors[slot];
	local itemLink = set.equipment[slot];
	if itemLink then
		local itemID = GetItemInfoInstant(itemLink);
		local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemLink);
		if quality == nil or texture == nil then
			self:RegisterEvent("GET_ITEM_INFO_RECEIVED");
		end

		SetItemButtonTexture(self, texture);
		SetItemButtonQuality(self, quality, itemID);
	else
		SetItemButtonTexture(self, self.backgroundTextureName);
		SetItemButtonQuality(self, nil, nil);
	end

	self.errors = errors -- For tooltip display
	self.ErrorBorder:SetShown(errors ~= nil)
	self.ErrorOverlay:SetShown(errors ~= nil)
	self.ignoreTexture:SetShown(ignored);
end
GameTooltip:HookScript("OnTooltipSetItem", function (self)
	local name, link = self:GetItem()
	if gameTooltipErrorLink == link and gameTooltipErrorText then
		self:AddLine(format("\n|cffff0000%s|r", gameTooltipErrorText))
	end
end)

BtWLoadoutsEquipmentMixin = {}
function BtWLoadoutsEquipmentMixin:ChangeSet(set)
    self.set = set
    self:Update()
end
function BtWLoadoutsEquipmentMixin:UpdateSetName(value)
	if self.set and self.set.name ~= not value then
		self.set.name = value;
		self:Update();
	end
end
function BtWLoadoutsEquipmentMixin:OnButtonClick(button)
	CloseDropDownMenus()
	if button.isAdd then
		self.Name:ClearFocus();
		self:ChangeSet(AddEquipmentSet())
		C_Timer.After(0, function ()
			self.Name:HighlightText();
			self.Name:SetFocus();
		end);
	elseif button.isDelete then
		local set = self.set;
		if set.useCount > 0 then
			StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
				set = set,
				func = Internal.DeleteEquipmentSet,
			});
		else
			StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
				set = set,
				func = Internal.DeleteEquipmentSet,
			});
		end
	elseif button.isRefresh then
		local set = self.set;
		RefreshEquipmentSet(set)
		self:Update()
	elseif button.isActivate then
		Internal.ActivateProfile({
			equipment = {self.set.setID}
		});
	end
end
function BtWLoadoutsEquipmentMixin:OnSidebarItemClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		button.collapsed[button.id] = not button.collapsed[button.id]
		self:Update()
	else
		if IsModifiedClick("SHIFT") then
			Internal.ActivateProfile({
				equipment = {button.id}
			});
		else
			self.Name:ClearFocus();
			self:ChangeSet(GetEquipmentSet(button.id))
		end
	end
end
function BtWLoadoutsEquipmentMixin:OnSidebarItemDoubleClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		return
	end

	Internal.ActivateProfile({
		equipment = {button.id}
	});
end
function BtWLoadoutsEquipmentMixin:OnSidebarItemDragStart(button)
	CloseDropDownMenus()
	if button.isHeader then
		return
	end

	local icon = "INV_Misc_QuestionMark";
	local set = GetEquipmentSet(button.id);
	local command = format("/btwloadouts activate equipment %d", button.id);
	if set.managerID then
		icon = select(2, C_EquipmentSet.GetEquipmentSetInfo(set.managerID))
	end

	if command then
		local macroId;
		local numMacros = GetNumMacros();
		for i=1,numMacros do
			if GetMacroBody(i):trim() == command then
				macroId = i;
				break;
			end
		end

		if not macroId then
			if numMacros == MAX_ACCOUNT_MACROS then
				print(L["Cannot create any more macros"]);
				return;
			end
			if InCombatLockdown() then
				print(L["Cannot create macros while in combat"]);
				return;
			end

			macroId = CreateMacro(set.name, icon, command, false);
			if MacroFrame_Update then
				MacroFrame_Update()
			end
		else
			-- Rename the macro while not in combat
			if not InCombatLockdown() then
				icon = select(2,GetMacroInfo(macroId))
				EditMacro(macroId, set.name, icon, command)
			end
		end

		if macroId then
			PickupMacro(macroId);
		end
	end
end
function BtWLoadoutsEquipmentMixin:Update()
	self:GetParent().TitleText:SetText(L["Equipment"]);
	local sidebar = BtWLoadoutsFrame.Sidebar

	sidebar:SetSupportedFilters("character")
	sidebar:SetSets(BtWLoadoutsSets.equipment)
	sidebar:SetCollapsed(BtWLoadoutsCollapsed.equipment)
	sidebar:SetCategories(BtWLoadoutsCategories.equipment)
	sidebar:SetFilters(BtWLoadoutsFilters.equipment)
	sidebar:SetSelected(self.set)

	sidebar:Update()
	self.set = sidebar:GetSelected()

	if self.set ~= nil then
		local set = self.set

		UpdateEquipmentSetFilters(set)
		sidebar:Update()

		local errors = CheckEquipmentSetForIssues(set)

		local character = set.character;
		local characterInfo = Internal.GetCharacterInfo(character);
		local equipment = set.equipment;

		local characterName, characterRealm = UnitFullName("player");
		local playerCharacter = characterRealm .. "-" .. characterName;

		-- Update the name for the built in equipment set, but only for the current player
		if set.character == playerCharacter and set.managerID then
			local managerName = C_EquipmentSet.GetEquipmentSetInfo(set.managerID);
			if managerName ~= set.name then
				C_EquipmentSet.ModifyEquipmentSet(set.managerID, set.name);
			end
		end

		if not self.Name:HasFocus() then
			self.Name:SetText(self.set.name or "");
		end
		self.Name:SetEnabled(set.managerID == nil or set.character == playerCharacter);

		local model = self.Model;
		if not characterInfo or character == playerCharacter then
			model:SetUnit("player");
		else
			model:SetCustomRace(characterInfo.race, characterInfo.sex);
		end
		model:Undress();

		for _,item in pairs(self.Slots) do
			if equipment[item:GetID()] then
				model:TryOn(equipment[item:GetID()]);
			end

			item:Update();
			item:SetEnabled(character == playerCharacter and set.managerID == nil);
		end

		self:GetParent().RefreshButton:SetEnabled(set.character == GetCharacterSlug())

		local activateButton = self:GetParent().ActivateButton;
		activateButton:SetEnabled(character == playerCharacter);

		local deleteButton =  self:GetParent().DeleteButton;
		deleteButton:SetEnabled(set.managerID == nil);

		local addButton = self:GetParent().AddButton;
		addButton.Flash:Hide();
		addButton.FlashAnim:Stop();

		local helpTipBox = self:GetParent().HelpTipBox;
		if character ~= playerCharacter then
			if not BtWLoadoutsHelpTipFlags["INVALID_PLAYER"] then
				helpTipBox.closeFlag = "INVALID_PLAYER";

				HelpTipBox_Anchor(helpTipBox, "TOP", activateButton);

				helpTipBox:Show();
				HelpTipBox_SetText(helpTipBox, L["Can not equip sets for other characters."]);
			else
				helpTipBox.closeFlag = nil;
				helpTipBox:Hide();
			end
		elseif set.managerID ~= nil then
			if not BtWLoadoutsHelpTipFlags["EQUIPMENT_MANAGER_BLOCK"] then
				helpTipBox.closeFlag = "EQUIPMENT_MANAGER_BLOCK";

				HelpTipBox_Anchor(helpTipBox, "RIGHT", self.HeadSlot);

				helpTipBox:Show();
				HelpTipBox_SetText(helpTipBox, L["Can not edit equipment manager sets."]);
			else
				helpTipBox.closeFlag = nil;
				helpTipBox:Hide();
			end
		else
			if not BtWLoadoutsHelpTipFlags["EQUIPMENT_IGNORE"] then
				helpTipBox.closeFlag = "EQUIPMENT_IGNORE";

				HelpTipBox_Anchor(helpTipBox, "RIGHT", self.HeadSlot);

				helpTipBox:Show();
				HelpTipBox_SetText(helpTipBox, L["Shift+Left Mouse Button to ignore a slot."]);
			else
				helpTipBox.closeFlag = nil;
				helpTipBox:Hide();
			end
		end
	else
		self.Name:SetEnabled(false);
		self.Name:SetText("");

		for _,item in pairs(self.Slots) do
			item:SetEnabled(false);
		end

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