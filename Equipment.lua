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

local sort = table.sort
local format = string.format

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
local function EmptyInventorySlot(inventorySlotId)
    local itemBagType = GetItemFamily(GetInventoryItemLink("player", inventorySlotId))

    local foundSlot = false
    local containerId, slotId
    for i = NUM_BAG_SLOTS, 0, -1 do
        local numFreeSlot, bagType = GetContainerNumFreeSlots(i)
        if numFreeSlot > 0 and (bit.band(bagType, itemBagType) > 0 or bagType == 0) then
            local freeSlots = GetContainerFreeSlots(i)

            foundSlot = true
            containerId = i
            slotId = freeSlots[1]

            break
        end
    end

	local complete = false;
    if foundSlot then
        ClearCursor()

        PickupInventoryItem(inventorySlotId)
		PickupContainerItem(containerId, slotId)

		-- If the swap succeeded then the cursor should be empty
		if not CursorHasItem() then
			complete = true;
		end

        ClearCursor();
    end

    return complete
end
--[[
local function SwapInventorySlot(inventorySlotId, itemLink, possibles)
    local itemString = string.match(itemLink, "item[%-?%d:]+")
    local _, itemID, enchantId, gemId1, gemId2, gemId3, gemId4, suffixId, uniqueId, _, numBonusIds, bonusId1, bonusId2, upgradeValue = strsplit(':', itemString)

    local match = nil
    for packedLocation, possibleItemID in pairs(possibles) do
        if possibleItemID == tonumber(itemID) then
            local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(packedLocation)

            if not voidStorage and not (player and not bags and slot == inventorySlotId) then
                match = {
                    ["slot"] = slot,
                    ["bag"] = bag,
                }
            end
        end
    end

	local complete = false;
    if match then
        local a, b
        ClearCursor()
        if match.bag == nil then
            PickupInventoryItem(match.slot)
        else
            PickupContainerItem(match.bag, match.slot)
        end

        PickupInventoryItem(inventorySlotId)

		-- If the swap succeeded then the cursor should be empty
		if not CursorHasItem() then
			complete = true;
		end

        ClearCursor();
    end

    return complete
end
]]
local function SwapInventorySlot(inventorySlotId, itemLink, location)
	local complete = false;
	local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location);
	if not voidStorage and not (player and not bags and slot == inventorySlotId) then
        local a, b
        ClearCursor()
        if bag == nil then
            PickupInventoryItem(slot)
        else
            PickupContainerItem(bag, slot)
        end

        PickupInventoryItem(inventorySlotId)

		-- If the swap succeeded then the cursor should be empty
		if not CursorHasItem() then
			complete = true;
		end

        ClearCursor();
    end

    return complete
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
	local gemIDs = {tonumber(linkData[4]), tonumber(linkData[5]), tonumber(linkData[6]), tonumber(linkData[7])};
	local suffixID = tonumber(linkData[8]);
	local uniqueID = tonumber(linkData[9]);
	local upgradeTypeID = tonumber(linkData[12]);

	local index = 14;
	local numBonusIDs = tonumber(linkData[index]) or 0;

	local bonusIDs = {};
	for i=1,numBonusIDs do
		bonusIDs[i] = tonumber(linkData[index + i]);
	end
	index = index + numBonusIDs + 1;

	local upgradeTypeIDs = {};
	if upgradeTypeID and upgradeTypeID ~= 0 then
		upgradeTypeIDs[1] = tonumber(linkData[index + 1]);
		if bit.band(upgradeTypeID, 0x1000000) ~= 0 then
			upgradeTypeIDs[2] = tonumber(linkData[index + 2]);
		end
	end
	index = index + 2;

	local relic1NumBonusIDs = tonumber(linkData[index]) or 0;
	local relic1BonusIDs = {};
	for i=1,relic1NumBonusIDs do
		relic1BonusIDs[i] = tonumber(linkData[index + i]);
	end
	index = index + relic1NumBonusIDs + 1;

	local relic2NumBonusIDs = tonumber(linkData[index]) or 0;
	local relic2BonusIDs = {};
	for i=1,relic2NumBonusIDs do
		relic2BonusIDs[i] = tonumber(linkData[index + i]);
	end
	index = index + relic2NumBonusIDs + 1;

	local relic3NumBonusIDs = tonumber(linkData[index]) or 0;
	local relic3BonusIDs = {};
	for i=1,relic3NumBonusIDs do
		relic3BonusIDs[i] = tonumber(linkData[index + i]);
	end
	index = index + relic3NumBonusIDs + 1;

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
		for i=1,math.max(#gemIDs,#locationGemIDs) do
			match = match + 1;
		end
		for i=1,math.max(#bonusIDs,#locationBonusIDs) do
			match = match + 1;
		end
		for i=1,math.max(#upgradeTypeIDs,#locationUpgradeTypeIDs) do
			match = match + 1;
		end
		for i=1,math.max(#relic1BonusIDs,#locationRelic1BonusIDs) do
			match = match + 1;
		end
		for i=1,math.max(#relic2BonusIDs,#locationRelic2BonusIDs) do
			match = match + 1;
		end
		for i=1,math.max(#relic3BonusIDs,#locationRelic3BonusIDs) do
			match = match + 1;
		end

		if extras and extras.azerite and itemLocation:HasAnyLocation() and C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem(itemLocation) then
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
			return locationMatchValue[a] > locationMatchValue[b];
		end);

		return locationFiltered[1];
	end
end
local IsItemInLocation;
do
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

		if locationItemLink == nil then
			return false
		end

		local itemID, enchantID, gemIDs, suffixID, uniqueID, upgradeTypeID, bonusIDs, upgradeTypeIDs, relic1BonusIDs, relic2BonusIDs, relic3BonusIDs = GetCompareItemInfo(itemLink);
		local locationItemID, locationEnchantID, locationGemIDs, locationSuffixID, locationUniqueID, locationUpgradeTypeID, locationBonusIDs, locationUpgradeTypeIDs, locationRelic1BonusIDs, locationRelic2BonusIDs, locationRelic3BonusIDs = GetCompareItemInfo(locationItemLink);
		-- if itemID == 158075 then
		-- 	print(itemID, enchantID, gemIDs, suffixID, uniqueID, upgradeTypeID, bonusIDs, upgradeTypeIDs, relic1BonusIDs, relic2BonusIDs, relic3BonusIDs);
		-- 	print(locationItemID, locationEnchantID, locationGemIDs, locationSuffixID, locationUniqueID, locationUpgradeTypeID, locationBonusIDs, locationUpgradeTypeIDs, locationRelic1BonusIDs, locationRelic2BonusIDs, locationRelic3BonusIDs);
		-- 	for i=1,math.max(#gemIDs,#locationGemIDs) do
		-- 		print("gemIDs", gemIDs[i], locationGemIDs[i]);
		-- 	end
		-- 	for i=1,math.max(#bonusIDs,#locationBonusIDs) do
		-- 		print("gemIDs", bonusIDs[i], locationBonusIDs[i]);
		-- 	end
		-- 	for i=1,math.max(#relic1BonusIDs,#locationRelic1BonusIDs) do
		-- 		print(relic1BonusIDs[i], locationRelic1BonusIDs[i]);
		-- 	end
		-- 	for i=1,math.max(#relic2BonusIDs,#locationRelic2BonusIDs) do
		-- 		print(relic2BonusIDs[i], locationRelic2BonusIDs[i]);
		-- 	end
		-- 	for i=1,math.max(#relic3BonusIDs,#locationRelic3BonusIDs) do
		-- 		print(relic3BonusIDs[i], locationRelic3BonusIDs[i]);
		-- 	end
		-- end
		if itemID ~= locationItemID or enchantID ~= locationEnchantID or #gemIDs ~= #locationGemIDs or suffixID ~= locationSuffixID or uniqueID ~= locationUniqueID or upgradeTypeID ~= locationUpgradeTypeID or #bonusIDs ~= #bonusIDs or #relic1BonusIDs ~= #locationRelic1BonusIDs or #relic2BonusIDs ~= #locationRelic2BonusIDs or #relic3BonusIDs ~= #locationRelic3BonusIDs then
			return false;
		end
		for i=1,#gemIDs do
			if gemIDs[i] ~= locationGemIDs[i] then
				return false;
			end
		end
		for i=1,#bonusIDs do
			if bonusIDs[i] ~= locationBonusIDs[i] then
				return false;
			end
		end
		for i=1,#upgradeTypeIDs do
			if upgradeTypeIDs[i] ~= locationUpgradeTypeIDs[i] then
				return false;
			end
		end
		for i=1,#relic1BonusIDs do
			if relic1BonusIDs[i] ~= locationRelic1BonusIDs[i] then
				return false;
			end
		end
		for i=1,#relic2BonusIDs do
			if relic2BonusIDs[i] ~= locationRelic2BonusIDs[i] then
				return false;
			end
		end
		for i=1,#relic3BonusIDs do
			if relic3BonusIDs[i] ~= locationRelic3BonusIDs[i] then
				return false;
			end
		end

		if extras and extras.azerite and itemLocation:HasAnyLocation() and C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem(itemLocation) then
			for _,powerID in ipairs(extras.azerite) do
				if not C_AzeriteEmpoweredItem.IsPowerSelected(itemLocation, powerID) then
					return false;
				end
			end
		end

		return true;
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
					if not CompareItemLinks(expected[inventorySlotId], GetInventoryItemLink("player", inventorySlotId)) then
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
	local uniqueFamilies = {};
	function ActivateEquipmentSet(set)
		local ignored = set.ignored;
		local expected = set.equipment;
		local extras = set.extras;
		local locations = set.locations;
		local anyLockedSlots = false;
		wipe(uniqueFamilies);

		local firstEquipped = INVSLOT_FIRST_EQUIPPED
		local lastEquipped = INVSLOT_LAST_EQUIPPED

		-- if combatSwap then
		-- 	firstEquipped = INVSLOT_MAINHAND
		-- 	lastEquipped = INVSLOT_RANGED
		-- end

		for inventorySlotId = firstEquipped, lastEquipped do
			if not ignored[inventorySlotId] then
				if not anyLockedSlots and IsInventoryItemLocked(inventorySlotId) then
					anyLockedSlots = true;
				end
				local itemLink = expected[inventorySlotId];
				if itemLink then
					local location = locations[inventorySlotId];
					if location and location ~= -1 and IsItemInLocation(itemLink, extras[inventorySlotId], location) then
						local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location);
						if player and not bags and slot == inventorySlotId then
							ignored[inventorySlotId] = true;
						else
							bestMatchForSlot[inventorySlotId] = location;
						end
					else
						if IsItemInLocation(itemLink, extras[inventorySlotId], true, false, false, false, inventorySlotId, false) then
							ignored[inventorySlotId] = true;
						else
							location = GetBestMatch(itemLink, extras[inventorySlotId], GetInventoryItemsForSlot(inventorySlotId, possibleItems));
							wipe(possibleItems);
							if location == nil then
								ignored[inventorySlotId] = true;
							else
								local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location);
								if player and not bags and slot == inventorySlotId then
									ignored[inventorySlotId] = true;
								end
								bestMatchForSlot[inventorySlotId] = location;
							end
						end
					end

					if not ignored[inventorySlotId] then
						local itemID = GetItemInfoInstant(itemLink);
						local uniqueFamily, maxEquipped
						if itemUniquenessCache[itemID] then
							uniqueFamily, maxEquipped = unpack(itemUniquenessCache[itemID])
						else
							uniqueFamily, maxEquipped = GetItemUniqueness(itemLink)
						end

						if uniqueFamily == -1 then
							uniqueFamilies[itemID] = maxEquipped
						elseif uniqueFamily ~= nil then
							uniqueFamilies[uniqueFamily] = maxEquipped
						end
					end
				else -- Unequip
					if GetInventoryItemLink("player", inventorySlotId) ~= nil then
						if not IsInventoryItemLocked(inventorySlotId) and EmptyInventorySlot(inventorySlotId) then
							ignored[inventorySlotId] = true;
						end
					else -- Already unequipped
						ignored[inventorySlotId] = true;
					end
				end
			end
		end

		-- Swap currently equipped "unique" items
		for inventorySlotId = firstEquipped, lastEquipped do
			local itemLink = GetInventoryItemLink("player", inventorySlotId)

			if not ignored[inventorySlotId] and not IsInventoryItemLocked(inventorySlotId) and expected[inventorySlotId] and itemLink ~= nil then
				local itemID = GetItemInfoInstant(itemLink);

				local uniqueFamily, maxEquipped
				if itemUniquenessCache[itemID] then
					uniqueFamily, maxEquipped = unpack(itemUniquenessCache[itemID])
				else
					uniqueFamily, maxEquipped = GetItemUniqueness(itemLink)
				end

				if (uniqueFamily == -1 and uniqueFamilies[itemID] ~= nil) or uniqueFamilies[uniqueFamily] ~= nil then
					if SwapInventorySlot(inventorySlotId, expected[inventorySlotId], bestMatchForSlot[inventorySlotId]) then
						ignored[inventorySlotId] = true;
					end
				end
			end
		end

		-- Swap out items
		for inventorySlotId = firstEquipped, lastEquipped do
			if not ignored[inventorySlotId] and not IsInventoryItemLocked(inventorySlotId) and expected[inventorySlotId] then
				if SwapInventorySlot(inventorySlotId, expected[inventorySlotId], bestMatchForSlot[inventorySlotId]) then
					ignored[inventorySlotId] = true;
				end
			end
		end

		-- target.equipPass = target.equipPass or 0;
		-- if not anyLockedSlots then
		-- 	target.equipPass = target.equipPass + 1;
		-- end

		-- Unequip items
		local complete = true
		for inventorySlotId = firstEquipped, lastEquipped do
			if not ignored[inventorySlotId] then
				if expected[inventorySlotId] then
					-- if not IsInventoryItemLocked(inventorySlotId) and target.equipPass >= 5 then
					-- 	print('Cannot equip ' .. expected[inventorySlotId]);
					-- end
					complete = false
				else -- Unequip
					if not EmptyInventorySlot(inventorySlotId) then
						-- if not IsInventoryItemLocked(inventorySlotId) and target.equipPass >= 5 then
						-- 	print('Cannot unequip ' .. GetInventoryItemLink("player", inventorySlotId))
						-- end
						complete = false
					end
				end
			end
		end

		ClearCursor()
		-- If its taken us 5 attempts to equip a set its probably not going to happen
		-- if target.equipPass >= 5 then
		-- 	-- if not complete then
		-- 	-- 	print(format("Failed after %d passes to equip set", target.equipPass));
		-- 	-- end
		-- 	return true;
		-- end
		-- if complete then
		-- 	print(format("Took %d passes to equip set", target.equipPass));
		-- end

		return complete;
	end
end
local function AddEquipmentSet()
    local characterName, characterRealm = UnitFullName("player");
    local name = format(L["New %s Equipment Set"], characterName);
	local equipment = {};
	local ignored = {};

	for inventorySlotId=INVSLOT_FIRST_EQUIPPED,INVSLOT_LAST_EQUIPPED do
		equipment[inventorySlotId] = GetInventoryItemLink("player", inventorySlotId);
		if equipment[inventorySlotId] == nil then
			ignored[inventorySlotId] = true;
		end
	end

    local set = {
		setID = Internal.GetNextSetID(BtWLoadoutsSets.equipment),
        character = characterRealm .. "-" .. characterName,
        name = name,
		equipment = equipment,
		extras = {},
		locations = {},
		ignored = ignored,
		useCount = 0,
    };
    BtWLoadoutsSets.equipment[set.setID] = set;
    return set;
end
-- Adds a blank equipment set for the current character
local function AddBlankEquipmentSet()
    local characterName, characterRealm = UnitFullName("player");
    local set = {
		setID = Internal.GetNextSetID(BtWLoadoutsSets.equipment),
        character = characterRealm .. "-" .. characterName,
        name = "",
		equipment = {},
		extras = {},
		locations = {},
		ignored = {},
		useCount = 0,
    };
    BtWLoadoutsSets.equipment[set.setID] = set;
    return set;
end
function Internal.GetEquipmentSet(id)
    if type(id) == "table" then
		return id;
	else
		return BtWLoadoutsSets.equipment[id];
	end
end
function Internal.GetEquipmentSetByName(name)
	for _,set in pairs(BtWLoadoutsSets.equipment) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
end
function Internal.GetEquipmentSets(id, ...)
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
local function CombineEquipmentSets(result, ...)
	result = result or {};

	result.equipment = {};
	result.extras = {};
	result.locations = {};
	result.ignored = {};
	for slot=INVSLOT_FIRST_EQUIPPED,INVSLOT_LAST_EQUIPPED do
		result.ignored[slot] = true;
	end
	for i=1,select('#', ...) do
		local set = select(i, ...);
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

	return result;
end
local function DeleteEquipmentSet(id)
	Internal.DeleteSet(BtWLoadoutsSets.equipment, id);

	if type(id) == "table" then
		id = id.setID;
	end
	for _,set in pairs(BtWLoadoutsSets.profiles) do
		if type(set) == "table" and set.equipmentSet == id then
			set.equipmentSet = nil;
			set.character = nil;
		end
	end

	local frame = BtWLoadoutsFrame.Equipment;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil;-- = select(2,next(BtWLoadoutsSets.equipment)) or {};
		BtWLoadoutsFrame:Update();
	end
end

Internal.AddEquipmentSet = AddEquipmentSet
Internal.DeleteEquipmentSet = DeleteEquipmentSet
Internal.ActivateEquipmentSet = ActivateEquipmentSet
Internal.IsEquipmentSetActive = IsEquipmentSetActive
Internal.CombineEquipmentSets = CombineEquipmentSets

function Internal.EquipmentTabUpdate(self)
	self:GetParent().TitleText:SetText(L["Equipment"]);
	self.set = Internal.SetsScrollFrame_CharacterFilter(self.set, BtWLoadoutsSets.equipment, BtWLoadoutsCollapsed.equipment);

	if self.set ~= nil then
		local set = self.set;
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