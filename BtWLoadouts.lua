--[[@TODO
	Minimap icon should show progress texture and help box
	Loadouts need to support multiple sets of the same type, watch for issues with unique items
	Equipment flyout
	Equipment sets should store location? Check what events are fired with upgrading items
	Equipment sets should store transmog?
	Loadout keybindings
	Conditions need to supoort boss, affixes and arena comp
	Localization
	Update new set text button based on tab?
	What to do when the player has no tome
	External API
	Configurable sidebar filtering?
	New user UI, each tab should have a cleaner ui before creaitng a set
	Set icons
	Import/Export and custom links
	Better info for why a profile is disabled
	Delay using a tome when talents/essences are on CD
	When combining sets, adjust sets for the current player,
	  eg moving essences because the character missing a ring/essence 
	Better condition loadout list display, show specs
	Better issue handling
	Set save button?
	Refresh set from currently equipped
	Show changes for the conditions
]]

local ADDON_NAME, Internal = ...;
local L = Internal.L;

local External = {}
_G[ADDON_NAME] = External

local GetCharacterInfo = Internal.GetCharacterInfo
local GetCharacterSlug = Internal.GetCharacterSlug

BTWLOADOUTS_PROFILE = L["Profile"];
BTWLOADOUTS_PROFILES = L["Profiles"];
BTWLOADOUTS_TALENTS = L["Talents"];
BTWLOADOUTS_PVP_TALENTS = L["PvP Talents"];
BTWLOADOUTS_ESSENCES = L["Essences"];
BTWLOADOUTS_EQUIPMENT = L["Equipment"];
BTWLOADOUTS_ACTION_BARS = L["Action Bars"];
BTWLOADOUTS_CONDITIONS = L["Conditions"];
BTWLOADOUTS_NEW_SET = L["New Set"];
BTWLOADOUTS_ACTIVATE = L["Activate"];
BTWLOADOUTS_DELETE = L["Delete"];
BTWLOADOUTS_NAME = L["Name"];
BTWLOADOUTS_SPECIALIZATION = L["Specialization"];
BTWLOADOUTS_ENABLED = L["Enabled"]
BTWLOADOUTS_UPDATE = L["Update"]
BTWLOADOUTS_LOG = L["Log"]

BINDING_HEADER_BTWLOADOUTS = L["BtWLoadouts"]
BINDING_NAME_TOGGLE_BTWLOADOUTS = L["Toggle BtWLoadouts"]


local function SettingsCreate(options)
	local optionsByKey = {};
	local defaults = {};
	for _,option in ipairs(options) do
		optionsByKey[option.key] = option;
		defaults[option.key] = option.default;
	end

	local result = Mixin({}, options);
	local mt = {};
	function mt:__call (tbl)
		setmetatable(tbl, {__index = defaults});
		-- local mt = getmetatable(self);
		mt.__index = tbl;
	end
	function mt:__newindex (key, value)
		-- local mt = getmetatable(self);
		mt.__index[key] = value;

		local option = optionsByKey[key];
		if option then
			local func = option.onChange;
			if func then
				func(key, value);
			end
		end
	end
	setmetatable(result, mt);
	result({});

	return result;
end
local Settings = SettingsCreate({
    {
        name = L["Show minimap icon"],
        key = "minimapShown",
        onChange = function (id, value)
			if value then
				Internal.ShowMinimap()
			else
				Internal.HideMinimap()
			end
        end,
        default = true,
    },
    {
        name = L["Limit condition suggestions"],
        key = "limitConditions",
        default = false,
    },
    {
        name = L["Filter chat spam while changing loadouts"],
        key = "filterChatSpam",
        default = false,
    },
});
Internal.Settings = Settings;

local tomeButton = CreateFrame("BUTTON", "BtWLoadoutsTomeButton", UIParent, "SecureActionButtonTemplate,SecureHandlerAttributeTemplate");
tomeButton:SetFrameStrata("DIALOG");
tomeButton:SetAttribute("*type1", "item");
tomeButton:SetAttribute("unit", "player");
tomeButton:SetAttribute("item", "Tome of the Tranquil Mind");
RegisterStateDriver(tomeButton, "combat", "[combat] hide; show")
tomeButton:SetAttribute("_onattributechanged", [[ -- (self, name, value)
	if name == "active" and value == false then
		self:Hide();
	elseif name == "state-combat" and value == "hide" then
		self:Hide();
	elseif name ~= "statehidden" and self:GetAttribute("active") and self:GetAttribute("state-combat") == "show" then
		self:Show();
	end
]]);
tomeButton:SetAttribute("active", false);
tomeButton:HookScript("OnEnter", function (self, ...)
	self.button:LockHighlight()
	local handler = self.button:GetScript("OnEnter")
	if handler then
		handler(self.button, ...)
	end
end);
tomeButton:HookScript("OnLeave", function (self, ...)
	self.button:UnlockHighlight()
	local handler = self.button:GetScript("OnLeave")
	if handler then
		handler(self.button, ...)
	end
end);
tomeButton:HookScript("OnMouseDown", function (self, ...)
	self.button:SetButtonState("PUSHED")
end);
tomeButton:HookScript("OnMouseUp", function (self, ...)
	self.button:SetButtonState("NORMAL")
end);
tomeButton:HookScript("OnClick", function (self, ...)
	self.button:GetScript("OnClick")(self.button, ...);
end);

local setsFiltered = {};

StaticPopupDialogs["BTWLOADOUTS_REQUESTACTIVATE"] = {
	text = L["Activate profile %s?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		data.func(data.set);
	end,
	timeout = 0,
	hideOnEscape = 1
};
StaticPopupDialogs["BTWLOADOUTS_REQUESTMULTIACTIVATE"] = {
	text = L["Activate the following profile?\n"],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		data.func(Internal.GetAciveConditionSelection().profile);
	end,
	timeout = 0,
	hideOnEscape = 1
};
StaticPopupDialogs["BTWLOADOUTS_REQUESTACTIVATERESTED"] = {
	text = "Activate spec %s?\nThis set will require a tome or rested to activate",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
	end,
	OnShow = function(self)
		--
	end,
	hasItemFrame = 1,
	timeout = 0,
	hideOnEscape = 1
};
StaticPopupDialogs["BTWLOADOUTS_REQUESTACTIVATETOME"] = {
	text = "Activate spec %s?\nThis will use a Tome",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)

	end,
	OnShow = function(self, data)
		tomeButton:SetParent(self);
		tomeButton:ClearAllPoints();
		tomeButton:SetPoint("TOPLEFT", self.button1, "TOPLEFT", 0, 0);
		tomeButton:SetPoint("BOTTOMRIGHT", self.button1, "BOTTOMRIGHT", 0, 0);
		tomeButton.button = self.button1;

		tomeButton:SetFrameLevel(self.button1:GetFrameLevel() + 1);
		tomeButton:SetAttribute("item", data.name);
		tomeButton:SetAttribute("active", true);
	end,
	OnHide = function(self)
		tomeButton:SetParent(UIParent);
		tomeButton:ClearAllPoints();
		tomeButton.button = nil;
		tomeButton:SetAttribute("active", false);
	end,
	hasItemFrame = 1,
	timeout = 0,
	hideOnEscape = 1
};
StaticPopupDialogs["BTWLOADOUTS_NEEDTOME"] = {
	text = L["A tome is needed to continue equiping your set."],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
	end,
	OnCancel = function(self, data, reason)
		if reason == "clicked" then
			Internal.CancelActivateProfile();
		end
	end,
	OnShow = function(self, data)
		tomeButton:SetParent(self);
		tomeButton:ClearAllPoints();
		tomeButton:SetPoint("TOPLEFT", self.button1, "TOPLEFT", 0, 0);
		tomeButton:SetPoint("BOTTOMRIGHT", self.button1, "BOTTOMRIGHT", 0, 0);
		tomeButton.button = self.button1;

		tomeButton:SetFrameLevel(self.button1:GetFrameLevel() + 1);
		tomeButton:SetAttribute("item", data.name);
		tomeButton:SetAttribute("active", true);
	end,
	OnHide = function(self)
		tomeButton:SetParent(UIParent);
		tomeButton:ClearAllPoints();
		tomeButton.button = nil;
		tomeButton:SetAttribute("active", false);
	end,
	hasItemFrame = 1,
	timeout = 0,
	hideOnEscape = 1
};
StaticPopupDialogs["BTWLOADOUTS_DELETESET"] = {
	text = L["Are you sure you wish to delete the set \"%s\". This cannot be reversed."],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		data.func(data.set);
	end,
	timeout = 0,
	whileDead = 1,
	showAlert = 1
};
StaticPopupDialogs["BTWLOADOUTS_DELETEINUSESET"] = {
	text = L["Are you sure you wish to delete the set \"%s\", this set is in use by one or more profiles. This cannot be reversed."],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		data.func(data.set);
	end,
	timeout = 0,
	whileDead = 1,
	showAlert = 1
};


function Internal.HelpTipBox_Anchor(self, anchorPoint, frame, offset)
	local offset = offset or 0;

	self.Arrow:ClearAllPoints();
	self:ClearAllPoints();
	self.Arrow.Glow:ClearAllPoints();
	self:ClearAllPoints();

	self.CloseButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", 4, 6);

	if anchorPoint == "RIGHT" then
		self:SetPoint("LEFT", frame, "RIGHT", 30, 0);

		self.Arrow.Arrow:SetRotation(-math.pi / 2);
		self.Arrow.Glow:SetRotation(-math.pi / 2);

		self.Arrow:SetPoint("RIGHT", self, "LEFT", 17, 0);
		self.Arrow.Glow:SetPoint("CENTER", self.Arrow.Arrow, "CENTER", -3, 0);
		self.CloseButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", 6, 6);
	elseif anchorPoint == "LEFT" then
		self:SetPoint("RIGHT", frame, "LEFT", -30, 0);

		self.Arrow.Arrow:SetRotation(math.pi / 2);
		self.Arrow.Glow:SetRotation(math.pi / 2);

		self.Arrow:SetPoint("LEFT", self, "RIGHT", -17, 0);
		self.Arrow.Glow:SetPoint("CENTER", self.Arrow.Arrow, "CENTER", 4, 0);
		self.CloseButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", 4, 6);
	elseif anchorPoint == "TOP" then
		self:SetPoint("BOTTOM", frame, "TOP", 0, 20 + offset);

		self.Arrow.Arrow:SetRotation(0);
		self.Arrow.Glow:SetRotation(0);

		self.Arrow:SetPoint("TOP", self, "BOTTOM", 0, 4);
		self.Arrow.Glow:SetPoint("TOP", self.Arrow.Arrow, "TOP", 0, 0);
		self.CloseButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", 4, 6);
	elseif anchorPoint == "BOTTOM" then
		self:SetPoint("TOP", frame, "BOTTOM", 0, -20 - offset);

		self.Arrow.Arrow:SetRotation(math.pi);
		self.Arrow.Glow:SetRotation(math.pi);

		self.Arrow:SetPoint("BOTTOM", self, "TOP", 0, -3);
		self.Arrow.Glow:SetPoint("BOTTOM", self.Arrow.Arrow, "BOTTOM", 0, 0);
		self.CloseButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", 4, 6);
	end
end
function Internal.HelpTipBox_SetText(self, text)
	self.Text:SetText(text);
	self:SetHeight(self.Text:GetHeight() + 34);
end

local NUM_TABS = 7;
local TAB_PROFILES = 1;
local TAB_TALENTS = 2;
local TAB_PVP_TALENTS = 3;
local TAB_ESSENCES = 4;
local TAB_EQUIPMENT = 5;
local TAB_ACTION_BARS = 6;
local TAB_CONDITIONS = 7;
local function GetTabFrame(self, tabID)
	return self.TabFrames[tabID]
end

function Internal.DropDownSetOnChange(self, func)
	self.OnChange = func;
end

local function SpecDropDown_OnClick(self, arg1, arg2, checked)
	local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
	local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

	CloseDropDownMenus();
	local set = tab.set;

	if selectedTab == TAB_PROFILES then
		set.specID = arg1;
	elseif selectedTab == TAB_TALENTS or selectedTab == TAB_PVP_TALENTS then
		local temp = tab.temp;
		-- @TODO: If we always access talents by set.talents then we can just swap tables in and out of
		-- the temp table instead of copying the talentIDs around

		-- We are going to copy the currently selected talents for the currently selected spec into
		-- a temporary table incase the user switches specs back
		local specID = set.specID;
		if temp[specID] then
			wipe(temp[specID]);
		else
			temp[specID] = {};
		end
		for talentID in pairs(set.talents) do
			temp[specID][talentID] = true;
		end

		-- Clear the current talents and copy back the previously selected talents if they exist
		specID = arg1;
		set.specID = specID;
		wipe(set.talents);
		if temp[specID] then
			for talentID in pairs(temp[specID]) do
				set.talents[talentID] = true;
			end
		end
	end
	BtWLoadoutsFrame:Update();
end
local function SpecDropDownInit(self, level, menuList)
	local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local selected = set and set.specID;

	if (level or 1) == 1 then
		if self.includeNone then
			info.text = L["None"];
			info.func = SpecDropDown_OnClick;
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);
		end

		for classIndex=1,GetNumClasses() do
			local className, classFile = GetClassInfo(classIndex);
			local classColor = C_ClassColor.GetClassColor(classFile);
			info.text = classColor and classColor:WrapTextInColorCode(className) or className;
			info.hasArrow, info.menuList = true, classIndex;
			info.keepShownOnClick = true;
			info.notCheckable = true;
			UIDropDownMenu_AddButton(info, level);
		end
	else
		local classID = menuList;
		for specIndex=1,GetNumSpecializationsForClassID(classID) do
			local specID, name, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
			info.text = name;
			info.icon = icon;
			info.arg1 = specID;
			info.func = SpecDropDown_OnClick;
			info.checked = selected == specID;
			UIDropDownMenu_AddButton(info, level);
		end
	end
end

BtWLoadoutsSpecDropDownMixin = {}
function BtWLoadoutsSpecDropDownMixin:OnShow()
	if not self.initialized then
		UIDropDownMenu_Initialize(self, SpecDropDownInit);
		self.initialized = true
	end
end

--[[
	BtWLoadoutsSidebarMixin, sidebar display with filtering
]]
do
	local function OrganiseSetsByFilter(result, sets, filter)
		if filter == nil then
			for _,set in pairs(sets) do
				if type(set) == "table" then
					result[#result+1] = set;
				end
			end
	
			return result
		else
			for setID,set in pairs(sets) do
				if type(set) == "table" then
					local value = set.filters and set.filters[filter] or 0
					if type(value) == "table" then
						for _,v in pairs(value) do
							result[v] = result[v] or {};
							result[v][#result[v] + 1] = set;
						end
					else
						result[value] = result[value] or {};
						result[value][#result[value] + 1] = set;
					end
				end
			end
			return result
		end
	end
	--[[
		... is a list of filters, eg spec, role, class, character, instanceType, etc.
	]]
	local function CategoriesSets(sets, ...)
		local tbl = OrganiseSetsByFilter({}, sets, ...)
		if select('#', ...) > 1 then
			for k,v in pairs(tbl) do
				tbl[k] = CategoriesSets(v, select(2, ...))
			end
		end
		return tbl
	end
	local function FilterSetsBySearch(result, query, sets)
		for _,set in pairs(sets) do
			if type(set) == "table" then
				if query == nil or set.name:lower():find(query) ~= nil then
					result[#result+1] = set;
				end
			end
		end

		return result
	end
	local function ContainsOrMatches(tbl, value)
		if type(tbl) == "table" then
			for _,v in pairs(tbl) do
				if v == value then
					return true
				end
			end
		elseif tbl == value then
			return true
		end
		return false
	end
	local function FiltersMatch(filters, setFilters)
		for filter,value in pairs(filters) do
			if not ContainsOrMatches(setFilters[filter], value) then
				return false
			end
		end
		return true
	end
	local function FilterSets(result, filters, sets)
		for _,set in pairs(sets) do
			if type(set) == "table" and FiltersMatch(filters, set.filters) then
				result[#result+1] = set;
			end
		end

		return result
	end
	local SpecFilterEnumerator
	do
		local specEnumertorList
		function SpecFilterEnumerator()
			if specEnumertorList == nil then
				specEnumertorList = {}
				_G['BtWLoadouts_SpecEnumertorList'] = specEnumertorList -- @TODO REMOVE

				local className, classFile, classID = UnitClass("player");
				local classColor = C_ClassColor.GetClassColor(classFile);
				className = classColor and classColor:WrapTextInColorCode(className) or className;

				for specIndex=1,GetNumSpecializationsForClassID(classID) do
					local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
					specEnumertorList[#specEnumertorList+1] = {
						id = specID,
						name = format("%s: %s", className, specName),
					}
				end

				local playerClassID = classID;
				for classID=1,GetNumClasses() do
					if classID ~= playerClassID then
						local className, classFile = GetClassInfo(classID);
						local classColor = C_ClassColor.GetClassColor(classFile);
						className = classColor and classColor:WrapTextInColorCode(className) or className;

						for specIndex=1,GetNumSpecializationsForClassID(classID) do
							local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
							specEnumertorList[#specEnumertorList+1] = {
								id = specID,
								name = format("%s: %s", className, specName),
							}
						end
					end
				end
				
				specEnumertorList[#specEnumertorList+1] = {
					id = 0,
					name = L["Other"],
				}
			end

			return ipairs(specEnumertorList)
		end
	end
	local ClassFilterEnumerator
	do
		local classEnumertorList
		function ClassFilterEnumerator()
			if classEnumertorList == nil then
				classEnumertorList = {}
				_G['BtWLoadouts_ClassEnumertorList'] = classEnumertorList -- @TODO REMOVE

				local className, classFile, classID = UnitClass("player");
				local classColor = C_ClassColor.GetClassColor(classFile);
				className = classColor and classColor:WrapTextInColorCode(className) or className;
				classEnumertorList[#classEnumertorList+1] = {
					id = classFile,
					name = className,
				}

				local playerClassID = classID;
				for classID=1,GetNumClasses() do
					if classID ~= playerClassID then
						local className, classFile = GetClassInfo(classID);
						local classColor = C_ClassColor.GetClassColor(classFile);
						className = classColor and classColor:WrapTextInColorCode(className) or className;
						classEnumertorList[#classEnumertorList+1] = {
							id = classFile,
							name = className,
						}
					end
				end
				
				classEnumertorList[#classEnumertorList+1] = {
					id = 0,
					name = L["Other"],
				}
			end

			return ipairs(classEnumertorList)
		end
	end
	local RoleFilterEnumerator
	do
		local roleEnumertorList
		function RoleFilterEnumerator()
			if roleEnumertorList == nil then
				roleEnumertorList = {}

				local role = select(5, GetSpecializationInfo(GetSpecialization()));
				roleEnumertorList[#roleEnumertorList+1] = {
					id = role,
					name = _G[role],
				}

				local playerRole = role;
				for _,role in Internal.Roles() do
					if role ~= playerRole then
						roleEnumertorList[#roleEnumertorList+1] = {
							id = role,
							name = _G[role],
						}
					end
				end
				
				roleEnumertorList[#roleEnumertorList+1] = {
					id = 0,
					name = L["Other"],
				}
			end

			return ipairs(roleEnumertorList)
		end
	end
	local CharacterFilterEnumerator
	do
		local charaterEnumertorList = {}
		function CharacterFilterEnumerator()
			wipe(charaterEnumertorList)

			local name = UnitName("player")
			local character = GetCharacterSlug();
			local characterInfo = GetCharacterInfo(character);
			if characterInfo then
				local classColor = C_ClassColor.GetClassColor(characterInfo.class);
				name = format("%s - %s", classColor:WrapTextInColorCode(characterInfo.name), characterInfo.realm);
			end
			charaterEnumertorList[#charaterEnumertorList+1] = {
				id = character,
				name = name,
			};

			local playerCharacter = character
			for _,character in Internal.CharacterIterator() do
				if playerCharacter ~= character then
					local characterInfo = GetCharacterInfo(character);
					if characterInfo then
						local classColor = C_ClassColor.GetClassColor(characterInfo.class);
						name = format("%s - %s", classColor:WrapTextInColorCode(characterInfo.name), characterInfo.realm);
					end
					charaterEnumertorList[#charaterEnumertorList+1] = {
						id = character,
						name = name,
					};
				end
			end

			charaterEnumertorList[#charaterEnumertorList+1] = {
				id = 0,
				name = L["Other"],
			};

			return ipairs(charaterEnumertorList)
		end
	end
	local function FilterEnumerator(filter)
		if filter == "spec" then
			return SpecFilterEnumerator()
		elseif filter == "class" then
			return ClassFilterEnumerator()
		elseif filter == "role" then
			return RoleFilterEnumerator()
		elseif filter == "character" then
			return CharacterFilterEnumerator()
		else -- @TODO Character, role
			error(format("Unsupported filter type %s", filter))
		end
	end
	local function alphanumsort(o)
		local function padnum(d)
			local dec, n = string.match(d, "(%.?)0*(.+)")
			return #dec > 0 and ("%.12f"):format(d) or ("%s%03d%s"):format(dec, #n, n)
		end
		table.sort(o, function(a,b)
		  	return tostring(a.name):gsub("%.?%d+", padnum)..("%3d"):format(#b.name)
			     < tostring(b.name):gsub("%.?%d+", padnum)..("%3d"):format(#a.name)
		end)
		return o
	  end
	local function BuildList(items, depth, selected, filtered, collapsed, ...)
		if select('#', ...) == 0 then
			alphanumsort(filtered)

			for _,set in ipairs(filtered) do
				selected = selected or set
				items[#items+1] = {
					id = set.setID,
					name = (set.name == nil or set.name == "") and L["Unnamed"] or set.name,
					disabled = set.disabled,
					selected = set == selected,
					builtin = set.managerID ~= nil,
					depth = depth,
				};
			end
		else
			local filter = ...
			collapsed.children = collapsed.children or {}
			for _,filterItem in FilterEnumerator(filter) do
				if filtered[filterItem.id] then
					local isCollapsed = collapsed[filterItem.id] and true or false
					items[#items+1] = {
						id = filterItem.id,
						type = filter,
						isHeader = true,
						isCollapsed = isCollapsed,
						collapsed = collapsed,
						name = filterItem.name,
						depth = depth,
					};
					if not isCollapsed then
						selected = BuildList(items, depth + 1, selected, filtered[filterItem.id], collapsed.children, select(2, ...))
					end
				end
			end
		end

		return selected
	end
	local function Scroll_Update(self)
		local buttons = self.buttons;
		local items = self.items;
		if not buttons then
			return
		end

		local totalHeight, displayedHeight = #items * (buttons[1]:GetHeight() + 1), self:GetHeight()
		-- local hasScrollBar = totalHeight > displayedHeight

		local offset = HybridScrollFrame_GetOffset(self);
		for i,button in ipairs(buttons) do
			-- button:SetWidth(223)
			-- button:SetWidth(hasScrollBar and 200 or 223)

			local item = items[i+offset]
			if item then
				button.isAdd = item.isAdd;
				if item.isAdd then
					button.SelectedBar:Hide();
					button.BuiltinIcon:Hide();
				end

				button.isHeader = item.isHeader;
				if item.isHeader then
					button.id = item.id;
					button.collapsed = item.collapsed;

					button.SelectedBar:Hide();

					if item.isCollapsed then
						button.ExpandedIcon:Hide();
						button.CollapsedIcon:Show();
					else
						button.ExpandedIcon:Show();
						button.CollapsedIcon:Hide();
					end
					button.BuiltinIcon:Hide();

					button.ExpandedIcon:SetPoint("LEFT", (item.depth * 15) + 4, 0)
					button.CollapsedIcon:SetPoint("LEFT", (item.depth * 15) + 4, 0)
					button.Name:SetPoint("LEFT", (item.depth * 15) + 15, 0)
				else
					if not item.isAdd then
						button.id = item.id;

						button.SelectedBar:SetShown(item.selected);
						button.BuiltinIcon:SetShown(item.builtin);
					end

					button.ExpandedIcon:Hide();
					button.CollapsedIcon:Hide();

					button.Name:SetPoint("LEFT", (item.depth * 15) + 4, 0)
				end

				local name;
				-- if item.character then
				-- 	local characterInfo = GetCharacterInfo(item.character);
				-- 	if characterInfo then
				-- 		name = format("%s |cFFD5D5D5(%s - %s)|r", item.name, characterInfo.name, characterInfo.realm);
				-- 	else
				-- 		name = format("%s |cFFD5D5D5(%s)|r", item.name, item.character);
				-- 	end
				-- else
					name = item.name;
				-- end
				if item.disabled then
					name = format("|cFF999999%s|r", name)
				end
				button.Name:SetText(name or L["Unnamed"]);
				button:Show();
			else
				button:Hide();
			end
		end
		HybridScrollFrame_Update(self, totalHeight, displayedHeight);
	end
	local function DropDown_Initialize(self, level)
		local sidebar = self:GetParent()

		local info = UIDropDownMenu_CreateInfo()
		info.keepShownOnClick = true
		info.isNotRadio = true
		
		if level == 1 then
			-- Own only?
			local active = {}

			self.MovePool:ReleaseAll()

			info.isTitle = false
			info.disabled = false
			info.func = function (self, arg1, arg2)
				sidebar:SetFilter(arg1, sidebar:GetFilter(arg1) ~= arg2 and arg2 or nil)
				CloseDropDownMenus()
				ToggleDropDownMenu(1, nil, sidebar.FilterDropDown, sidebar.FilterButton, 74, 15)
			end
			
			if sidebar:SupportsFilters("character") then
				local character = GetCharacterSlug()
				info.checked = sidebar:GetFilter("character") == character
				info.arg1 = "character"
				info.arg2 = character
				info.text = L["Current Character Only"]
				UIDropDownMenu_AddButton(info, level)
			end

			if sidebar:GetSupportedFilters() then
				info.isTitle = true
				info.isCheckable = false
				info.checked = false
				info.text = L["Categories"]
				UIDropDownMenu_AddButton(info, level)

				info.isTitle = false
				info.disabled = false
				info.isCheckable = true
				info.checked = true
				info.func = function (self, arg1)
					sidebar:RemoveCategory(arg1)
					CloseDropDownMenus()
					ToggleDropDownMenu(1, nil, sidebar.FilterDropDown, sidebar.FilterButton, 74, 15)
				end

				for index,value in ipairs({sidebar:GetCategories()}) do
					info.text = sidebar:GetFilterName(value)
					info.arg1 = value
					info.arg2 = index
					-- info.customFrame = self.MovePool:Acquire()
					active[value] = true
					UIDropDownMenu_AddButton(info, level);
				end

				info.checked = false
				info.customFrame = nil
				info.func = function (self, arg1)
					sidebar:AddCategory(arg1)
					CloseDropDownMenus()
					ToggleDropDownMenu(1, nil, sidebar.FilterDropDown, sidebar.FilterButton, 74, 15)
				end

				for _,value in ipairs({sidebar:GetSupportedFilters()}) do
					if not active[value] then
						info.text = sidebar:GetFilterName(value)
						info.arg1 = value
						active[value] = true
						UIDropDownMenu_AddButton(info, level);
					end
				end
			end
		end
	end
	BtWLoadoutsSidebarMixin = {}
	function BtWLoadoutsSidebarMixin:OnLoad()
		self.names = {
			["spec"] = L["Specialization"],
			["class"] = L["Class"],
			["role"] = L["Role"],
			["character"] = L["Character"],
		}
		self.supportedFilters = {}
	end
	function BtWLoadoutsSidebarMixin:Init()
		self.Scroll.items = {}
		self.Scroll.ScrollBar.doNotHide = true;
		HybridScrollFrame_CreateButtons(self.Scroll, "BtWLoadoutsSidebarScrollItemTemplate", 0, 0, "TOPLEFT", "TOPLEFT", 0, -1, "TOP", "BOTTOM");
		self.Scroll.update = Scroll_Update

		UIDropDownMenu_Initialize(self.FilterDropDown, DropDown_Initialize, "MENU");
		self.FilterDropDown.MovePool = CreateFramePool("FRAME", self, "BtWLoadoutsSidebarFilterEntryTemplate", FramePool_HideAndClearAnchors);
	end
	function BtWLoadoutsSidebarMixin:OnShow()
		if not self.initialized then
			self.initialized = true
			self:Init()
		end
	end

	function BtWLoadoutsSidebarMixin:SetSupportedFilters(...)
		wipe(self.supportedFilters)
		for i=1,select('#', ...) do
			self.supportedFilters[i] = select(i, ...)
		end
	end
	function BtWLoadoutsSidebarMixin:SupportsFilters(value)
		for _,filter in ipairs(self.supportedFilters) do
			if filter == value then
				return true
			end
		end

		return false
	end
	function BtWLoadoutsSidebarMixin:GetSupportedFilters(...)
		return unpack(self.supportedFilters)
	end
	function BtWLoadoutsSidebarMixin:GetFilterName(key)
		return self.names[key] or key
	end
	
	function BtWLoadoutsSidebarMixin:SetSets(value)
		self.sets = value
	end
	function BtWLoadoutsSidebarMixin:SetCollapsed(value)
		self.collapsed = value
	end
	function BtWLoadoutsSidebarMixin:SetCategories(value)
		self.categories = value
	end
	function BtWLoadoutsSidebarMixin:SetFilters(value)
		self.filters = value
	end
	function BtWLoadoutsSidebarMixin:SetSelected(selected)
		self.selected = selected
	end
	function BtWLoadoutsSidebarMixin:GetSelected()
		return self.selected
	end

	function BtWLoadoutsSidebarMixin:GetCategories()
		return unpack(self.categories)
	end
	function BtWLoadoutsSidebarMixin:GetFilters()
		local temp = {}
		for k in pairs(self.filters) do
			temp[#temp+1] = k
		end
		return unpack(temp)
	end
	function BtWLoadoutsSidebarMixin:GetFilter(name)
		return self.filters[name]
	end
	function BtWLoadoutsSidebarMixin:SetFilter(name, value)
		self.filters[name] = value
		self:Update()
	end

	function BtWLoadoutsSidebarMixin:AddCategory(filter)
		self.categories[#self.categories+1] = filter
		self:Update()
	end
	function BtWLoadoutsSidebarMixin:RemoveCategory(filter)
		for i=1,#self.categories do
			if self.categories[i] == filter then
				table.remove(self.categories, i)
				break
			end
		end
		self:Update()
	end
	function BtWLoadoutsSidebarMixin:OnSearchChanged()
		self.query = self.SearchBox:GetText():lower()
		self:Update()
	end
	function BtWLoadoutsSidebarMixin:Update()
		if not self.initialized then return end

		self.FilterButton:SetEnabled(#self.supportedFilters > 0)
		
		local filtered = FilterSetsBySearch({}, self.query, self.sets)
		filtered = FilterSets({}, self.filters, filtered)
		filtered = CategoriesSets(filtered, unpack(self.categories))

		wipe(self.Scroll.items);
		self.selected = BuildList(self.Scroll.items, 0, self.selected, filtered, self.collapsed, unpack(self.categories))
		self.Scroll:update();
	end
end


local SetsScrollFrame_Update
do
	function BtWLoadoutsTabFrame_OnLoad(self)
		local frame = self:GetParent()
		local Tabs = frame.Tabs

		local previous = Tabs[#Tabs]
		local tab = frame.TabPool:Acquire()
		local id = #Tabs

		tab:SetID(id)
		tab:SetText(self.name)

		if previous then
			tab:SetPoint("LEFT", previous, "RIGHT", -16, 0)
		else
			tab:SetPoint("BOTTOMLEFT", 7, -30)
		end

		tab:Show()

		PanelTemplates_SetNumTabs(frame, id);
		if id == 1 then
			PanelTemplates_SetTab(frame, id);
		end
		PanelTemplates_UpdateTabs(frame);
	end

	local NUM_SCROLL_ITEMS_TO_DISPLAY = 18;
	local SCROLL_ROW_HEIGHT = 21;
	function Internal.SetsScrollFrame_SpecFilter(selected, sets, collapsed)
		wipe(setScrollItems);
		wipe(setsFiltered);
		for setID,set in pairs(sets) do
			if type(set) == "table" then
				setsFiltered[set.specID or 0] = setsFiltered[set.specID or 0] or {};
				setsFiltered[set.specID or 0][#setsFiltered[set.specID or 0]+1] = setID;
			end
		end

		local className, classFile, classID = UnitClass("player");
		local classColor = C_ClassColor.GetClassColor(classFile);
		className = classColor and classColor:WrapTextInColorCode(className) or className;

		for specIndex=1,GetNumSpecializationsForClassID(classID) do
			local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
			local isCollapsed = collapsed[specID] and true or false;
			if setsFiltered[specID] then
				setScrollItems[#setScrollItems+1] = {
					id = specID,
					isHeader = true,
					isCollapsed = isCollapsed,
					name = format("%s: %s", classColor:WrapTextInColorCode(className), specName),
				};
				if not isCollapsed then
					sort(setsFiltered[specID], function (a,b)
						return sets[a].name < sets[b].name;
					end)
					selected = selected or sets[select(2, next(setsFiltered[specID]))];
					for _,setID in ipairs(setsFiltered[specID]) do
						setScrollItems[#setScrollItems+1] = {
							id = setID,
							name = sets[setID].name,
							character = sets[setID].character,
							disabled = sets[setID].disabled,
							selected = sets[setID] == selected,
						};
					end
				end
			end
		end

		local playerClassID = classID;
		for classID=1,GetNumClasses() do
			if classID ~= playerClassID then
				local className, classFile = GetClassInfo(classID);
				local classColor = C_ClassColor.GetClassColor(classFile);
				className = classColor and classColor:WrapTextInColorCode(className) or className;

				for specIndex=1,GetNumSpecializationsForClassID(classID) do
					local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
					local isCollapsed = collapsed[specID] and true or false;
					if setsFiltered[specID] then
						setScrollItems[#setScrollItems+1] = {
							id = specID,
							isHeader = true,
							isCollapsed = isCollapsed,
							name = format("%s: %s", classColor:WrapTextInColorCode(className), specName),
						};
						if not isCollapsed then
							sort(setsFiltered[specID], function (a,b)
								return sets[a].name < sets[b].name;
							end)
							selected = selected or sets[select(2, next(setsFiltered[specID]))];
							for _,setID in ipairs(setsFiltered[specID]) do
								setScrollItems[#setScrollItems+1] = {
									id = setID,
									name = sets[setID].name,
									character = sets[setID].character,
									disabled = sets[setID].disabled,
									selected = sets[setID] == selected,
								};
							end
						end
					end
				end
			end
		end

		local specID = 0;
		local isCollapsed = collapsed[specID] and true or false;
		if setsFiltered[specID] then
			setScrollItems[#setScrollItems+1] = {
				id = specID,
				isHeader = true,
				isCollapsed = isCollapsed,
				name = L["Other"],
			};
			if not isCollapsed then
				sort(setsFiltered[specID], function (a,b)
					return sets[a].name < sets[b].name;
				end)
				selected = selected or sets[select(2, next(setsFiltered[specID]))];
				for _,setID in ipairs(setsFiltered[specID]) do
					setScrollItems[#setScrollItems+1] = {
						id = setID,
						name = sets[setID].name,
						character = sets[setID].character,
						disabled = sets[setID].disabled,
						selected = sets[setID] == selected,
					};
				end
			end
		end

		SetsScrollFrame_Update();

		return selected;
	end
	function Internal.SetsScrollFrame_RoleFilter(selected, sets, collapsed)
		wipe(setScrollItems);
		wipe(setsFiltered);
		for setID,set in pairs(sets) do
			if type(set) == "table" then
				setsFiltered[set.role] = setsFiltered[set.role] or {};
				setsFiltered[set.role][#setsFiltered[set.role]+1] = setID;
			end
		end

		local role = select(5, GetSpecializationInfo(GetSpecialization()));
		local isCollapsed = collapsed[role] and true or false;
		if setsFiltered[role] then
			setScrollItems[#setScrollItems+1] = {
				id = role,
				isHeader = true,
				isCollapsed = isCollapsed,
				name = _G[role],
			};
			if not isCollapsed then
				sort(setsFiltered[role], function (a,b)
					return sets[a].name < sets[b].name;
				end)
				selected = selected or sets[select(2, next(setsFiltered[role]))];
				for _,setID in ipairs(setsFiltered[role]) do
					setScrollItems[#setScrollItems+1] = {
						id = setID,
						name = sets[setID].name,
						disabled = sets[setID].disabled,
						selected = sets[setID] == selected,
					};
				end
			end
		end

		local playerRole = role;
		for _,role in Internal.Roles() do
			if role ~= playerRole then
				local isCollapsed = collapsed[role] and true or false;
				if setsFiltered[role] then
					setScrollItems[#setScrollItems+1] = {
						id = role,
						isHeader = true,
						isCollapsed = isCollapsed,
						name = _G[role],
					};
					if not isCollapsed then
						sort(setsFiltered[role], function (a,b)
							return sets[a].name < sets[b].name;
						end)
						selected = selected or sets[select(2, next(setsFiltered[role]))];
						for _,setID in ipairs(setsFiltered[role]) do
							setScrollItems[#setScrollItems+1] = {
								id = setID,
								name = sets[setID].name,
								disabled = sets[setID].disabled,
								selected = sets[setID] == selected,
							};
						end
					end
				end
			end
		end

		SetsScrollFrame_Update();

		return selected;
	end
	function Internal.SetsScrollFrame_CharacterFilter(selected, sets, collapsed)
		wipe(setScrollItems);
		wipe(setsFiltered);
		for setID,set in pairs(sets) do
			if type(set) == "table" then
				setsFiltered[set.character] = setsFiltered[set.character] or {};
				setsFiltered[set.character][#setsFiltered[set.character]+1] = setID;
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
			local isCollapsed = collapsed[character] and true or false;
			local name = character;
			local characterInfo = GetCharacterInfo(character);
			if characterInfo then
				local classColor = C_ClassColor.GetClassColor(characterInfo.class);
				name = format("%s - %s", classColor:WrapTextInColorCode(characterInfo.name), characterInfo.realm);
			end
			setScrollItems[#setScrollItems+1] = {
				id = character,
				isHeader = true,
				isCollapsed = isCollapsed,
				name = name,
			};
			if not isCollapsed then
				sort(setsFiltered[character], function (a,b)
					return sets[a].name < sets[b].name;
				end)
				selected = selected or sets[select(2, next(setsFiltered[character]))];
				for _,setID in ipairs(setsFiltered[character]) do
					setScrollItems[#setScrollItems+1] = {
						id = setID,
						name = sets[setID].name,
						selected = sets[setID] == selected,
						disabled = sets[setID].disabled,
						builtin = sets[setID].managerID ~= nil,
					};
				end
			end
		end

		local playerCharacter = character;
		for _,character in ipairs(characters) do
			if character ~= playerCharacter then
				if setsFiltered[character] then
					local isCollapsed = collapsed[character] and true or false;
					local name = character;
					local characterInfo = GetCharacterInfo(character);
					if characterInfo then
						local classColor = C_ClassColor.GetClassColor(characterInfo.class);
						name = format("%s - %s", classColor:WrapTextInColorCode(characterInfo.name), characterInfo.realm);
					end
					setScrollItems[#setScrollItems+1] = {
						id = character,
						isHeader = true,
						isCollapsed = isCollapsed,
						name = name,
					};
					if not isCollapsed then
						sort(setsFiltered[character], function (a,b)
							return sets[a].name < sets[b].name;
						end)
						selected = selected or sets[select(2, next(setsFiltered[character]))];
						for _,setID in ipairs(setsFiltered[character]) do
							setScrollItems[#setScrollItems+1] = {
								id = setID,
								name = sets[setID].name,
								selected = sets[setID] == selected,
								disabled = sets[setID].disabled,
								builtin = sets[setID].managerID ~= nil,
							};
						end
					end
				end
			end
		end

		SetsScrollFrame_Update();

		return selected;
	end
	function Internal.SetsScrollFrame_NoFilter(selected, sets)
		wipe(setScrollItems);
		wipe(setsFiltered);
		for setID,set in pairs(sets) do
			if type(set) == "table" then
				setsFiltered[#setsFiltered+1] = setID;
			end
		end
		sort(setsFiltered, function (a,b)
			return sets[a].name < sets[b].name;
		end)
		selected = selected or sets[select(2, next(setsFiltered))];
		for _,setID in ipairs(setsFiltered) do
			setScrollItems[#setScrollItems+1] = {
				id = setID,
				name = sets[setID].name,
				disabled = sets[setID].disabled,
				selected = sets[setID] == selected,
			};
		end

		SetsScrollFrame_Update();

		return selected;
	end

	BtWLoadoutsFrameMixin = {};
	function BtWLoadoutsFrameMixin:OnLoad()
		tinsert(UISpecialFrames, self:GetName());
		self:RegisterForDrag("LeftButton");

		self.Tabs = {}
		self.TabPool = CreateFramePool("Button", self, "BtWLoadoutsTabTemplate")

		self.TitleText:SetText(PROFILES)
		self.TitleText:SetHeight(24)
	end
	function BtWLoadoutsFrameMixin:OnDragStart()
		self:StartMoving();
	end
	function BtWLoadoutsFrameMixin:OnDragStop()
		self:StopMovingOrSizing();
	end
	function BtWLoadoutsFrameMixin:OnMouseUp()
		-- if self.Essences.pending ~= nil then
		-- 	self.Essences.pending = nil
		-- 	SetCursor(nil);
		-- 	self:Update();
		-- end
	end
	function BtWLoadoutsFrameMixin:OnEnter()
		-- if self.Essences.pending ~= nil then
		-- 	SetCursor("interface/cursor/cast.blp");
		-- end
	end
	function BtWLoadoutsFrameMixin:OnLeave()
		SetCursor(nil);
	end
	function BtWLoadoutsFrameMixin:SetProfile(set)
		self.Profiles.set = set;
		self:Update();
	end
	function BtWLoadoutsFrameMixin:SetTalentSet(set)
		self.Talents.set = set;
		wipe(self.Talents.temp);
		self:Update();
	end
	function BtWLoadoutsFrameMixin:SetPvPTalentSet(set)
		self.PvPTalents.set = set;
		wipe(self.PvPTalents.temp);
		self:Update();
	end
	function BtWLoadoutsFrameMixin:SetEssenceSet(set)
		self.Essences.set = set;
		wipe(self.Essences.temp);
		self:Update();
	end
	function BtWLoadoutsFrameMixin:SetEquipmentSet(set)
		self.Equipment.set = set;
		self:Update();
	end
	function BtWLoadoutsFrameMixin:SetActionBarSet(set)
		self.ActionBars.set = set;
		self:Update();
	end
	function BtWLoadoutsFrameMixin:SetConditionSet(set)
		self.Conditions.set = set;
		self:Update();
	end
	function BtWLoadoutsFrameMixin:Update()
		local selectedTab = PanelTemplates_GetSelectedTab(self) or 1;
		for id,frame in ipairs(self.TabFrames) do
			frame:SetShown(id == selectedTab);
		end

		if selectedTab == TAB_PROFILES then
			Internal.ProfilesTabUpdate(self.Profiles);
		elseif selectedTab == TAB_TALENTS then
			Internal.TalentsTabUpdate(self.Talents);
		elseif selectedTab == TAB_PVP_TALENTS then
			Internal.PvPTalentsTabUpdate(self.PvPTalents);
		elseif selectedTab == TAB_ESSENCES then
			Internal.EssencesTabUpdate(self.Essences);
		elseif selectedTab == TAB_EQUIPMENT then
			Internal.EquipmentTabUpdate(self.Equipment);
		elseif selectedTab == TAB_ACTION_BARS then
			Internal.ActionBarsTabUpdate(self.ActionBars);
		elseif selectedTab == TAB_CONDITIONS then
			Internal.ConditionsTabUpdate(self.Conditions);
		end
	end
	function BtWLoadoutsFrameMixin:ScrollItemClick(button)
		CloseDropDownMenus();
		local selectedTab = PanelTemplates_GetSelectedTab(self) or 1;
		if selectedTab == TAB_PROFILES then
			local frame = self.Profiles;
			if button.isAdd then
				BtWLoadoutsHelpTipFlags["TUTORIAL_NEW_SET"] = true;

				frame.Name:ClearFocus();
				self:SetProfile(Internal.AddProfile());
				C_Timer.After(0, function ()
					frame.Name:HighlightText();
					frame.Name:SetFocus();
				end)
			elseif button.isDelete then
				local set = frame.set;
				if set.useCount > 0 then
					StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
						set = set,
						func = Internal.DeleteProfile,
					});
				else
					StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
						set = set,
						func = Internal.DeleteProfile,
					});
				end
			elseif button.isRefresh then
				-- Do nothing
			elseif button.isActivate then
				BtWLoadoutsHelpTipFlags["TUTORIAL_ACTIVATE_SET"] = true;

				local set = frame.set;
				Internal.ActivateProfile(set);

				Internal.ProfilesTabUpdate(frame);
			elseif button.isHeader then
				button.collapsed[button.id] = not button.collapsed[button.id]
				-- BtWLoadoutsCollapsed.profiles[button.id] = not BtWLoadoutsCollapsed.profiles[button.id] and true or nil;
				Internal.ProfilesTabUpdate(frame);
			else
				if IsModifiedClick("SHIFT") then
					Internal.ActivateProfile(Internal.GetProfile(button.id));
				else
					frame.Name:ClearFocus();
					self:SetProfile(Internal.GetProfile(button.id));
				end
			end
		elseif selectedTab == TAB_TALENTS then
			local frame = self.Talents;
			if button.isAdd then
				frame.Name:ClearFocus();
				self:SetTalentSet(Internal.AddTalentSet());
				C_Timer.After(0, function ()
					frame.Name:HighlightText();
					frame.Name:SetFocus();
				end)
			elseif button.isDelete then
				local set = frame.set;
				if set.useCount > 0 then
					StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
						set = set,
						func = Internal.DeleteTalentSet,
					});
				else
					StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
						set = set,
						func = Internal.DeleteTalentSet,
					});
				end
			elseif button.isRefresh then
				local set = frame.set;
				Internal.RefreshTalentSet(set)
				Internal.TalentsTabUpdate(frame);
			elseif button.isActivate then
				local set = frame.set;
				if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
					Internal.ActivateProfile({
						talents = {set.setID}
					});
				end
			elseif button.isHeader then
				BtWLoadoutsCollapsed.talents[button.id] = not BtWLoadoutsCollapsed.talents[button.id] and true or nil;
				Internal.TalentsTabUpdate(frame);
			else
				if IsModifiedClick("SHIFT") then
					local set = Internal.GetTalentSet(button.id);
					if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
						Internal.ActivateProfile({
							talents = {button.id}
						});
					end
				else
					frame.Name:ClearFocus();
					self:SetTalentSet(Internal.GetTalentSet(button.id));
				end
			end
		elseif selectedTab == TAB_PVP_TALENTS then
			local frame = self.PvPTalents;
			if button.isAdd then
				frame.Name:ClearFocus();
				self:SetPvPTalentSet(Internal.AddPvPTalentSet());
				C_Timer.After(0, function ()
					frame.Name:HighlightText();
					frame.Name:SetFocus();
				end)
			elseif button.isDelete then
				local set = frame.set;
				if set.useCount > 0 then
					StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
						set = set,
						func = Internal.DeletePvPTalentSet,
					});
				else
					StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
						set = set,
						func = Internal.DeletePvPTalentSet,
					});
				end
			elseif button.isRefresh then
				local set = frame.set;
				Internal.RefreshPvPTalentSet(set)
				Internal.PvPTalentsTabUpdate(frame);
			elseif button.isActivate then
				local set = frame.set;
				if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
					Internal.ActivateProfile({
						pvptalents = {set.setID}
					});
				end
			elseif button.isHeader then
				BtWLoadoutsCollapsed.pvptalents[button.id] = not BtWLoadoutsCollapsed.pvptalents[button.id] and true or nil;
				Internal.PvPTalentsTabUpdate(self.PvPTalents);
			else
				if IsModifiedClick("SHIFT") then
					local set = Internal.GetPvPTalentSet(button.id);
					if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
						Internal.ActivateProfile({
							pvptalents = {button.id}
						});
					end
				else
					frame.Name:ClearFocus();
					self:SetPvPTalentSet(Internal.GetPvPTalentSet(button.id));
				end
			end
		elseif selectedTab == TAB_ESSENCES then
			local frame = self.Essences;
			if button.isAdd then
				frame.Name:ClearFocus();
				self:SetEssenceSet(Internal.AddEssenceSet());
				C_Timer.After(0, function ()
					frame.Name:HighlightText();
					frame.Name:SetFocus();
				end)
			elseif button.isDelete then
				local set = frame.set;
				if set.useCount > 0 then
					StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
						set = set,
						func = Internal.DeleteEssenceSet,
					});
				else
					StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
						set = set,
						func = Internal.DeleteEssenceSet,
					});
				end
			elseif button.isRefresh then
				local set = frame.set;
				Internal.RefreshEssenceSet(set)
				Internal.EssencesTabUpdate(frame);
			elseif button.isActivate then
				Internal.ActivateProfile({
					essences = {frame.set.setID}
				});
			elseif button.isHeader then
				BtWLoadoutsCollapsed.essences[button.id] = not BtWLoadoutsCollapsed.essences[button.id] and true or nil;
				Internal.EssencesTabUpdate(frame);
			else
				if IsModifiedClick("SHIFT") then
					Internal.ActivateProfile({
						essences = {button.id}
					});
				else
					frame.Name:ClearFocus();
					self:SetEssenceSet(Internal.GetEssenceSet(button.id));
				end
			end
		elseif selectedTab == TAB_EQUIPMENT then
			local frame = self.Equipment;
			if button.isAdd then
				frame.Name:ClearFocus();
				self:SetEquipmentSet(Internal.AddEquipmentSet());
				C_Timer.After(0, function ()
					frame.Name:HighlightText();
					frame.Name:SetFocus();
				end);
			elseif button.isDelete then
				local set = frame.set;
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
				local set = frame.set;
				Internal.RefreshEquipmentSet(set)
				Internal.EquipmentTabUpdate(frame);
			elseif button.isActivate then
				Internal.ActivateProfile({
					equipment = {frame.set.setID}
				});
			elseif button.isHeader then
				BtWLoadoutsCollapsed.equipment[button.id] = not BtWLoadoutsCollapsed.equipment[button.id] and true or nil;
				Internal.EquipmentTabUpdate(frame);
			else
				if IsModifiedClick("SHIFT") then
					Internal.ActivateProfile({
						equipment = {button.id}
					});
				else
					frame.Name:ClearFocus();
					self:SetEquipmentSet(Internal.GetEquipmentSet(button.id));
				end
			end
		elseif selectedTab == TAB_ACTION_BARS then
			local frame = self.ActionBars;
			if button.isAdd then
				frame.Name:ClearFocus();
				self:SetActionBarSet(Internal.AddActionBarSet());
				C_Timer.After(0, function ()
					frame.Name:HighlightText();
					frame.Name:SetFocus();
				end);
			elseif button.isDelete then
				local set = frame.set;
				if set.useCount > 0 then
					StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
						set = set,
						func = Internal.DeleteActionBarSet,
					});
				else
					StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
						set = set,
						func = Internal.DeleteActionBarSet,
					});
				end
			elseif button.isRefresh then
				local set = frame.set;
				Internal.RefreshActionBarSet(set)
				Internal.ActionBarsTabUpdate(frame);
			elseif button.isActivate then
				Internal.ActivateProfile({
					actionbars = {frame.set.setID}
				});
			elseif button.isHeader then
				BtWLoadoutsCollapsed.actionbars[button.id] = not BtWLoadoutsCollapsed.actionbars[button.id] and true or nil;
				Internal.ActionBarsTabUpdate(frame);
			else
				if IsModifiedClick("SHIFT") then
					Internal.ActivateProfile({
						actionbars = {button.id}
					});
				else
					frame.Name:ClearFocus();
					self:SetActionBarSet(Internal.GetActionBarSet(button.id));
				end
			end
		elseif selectedTab == TAB_CONDITIONS then
			local frame = self.Conditions;
			if button.isAdd then
				frame.Name:ClearFocus();
				self:SetConditionSet(Internal.AddConditionSet());
				C_Timer.After(0, function ()
					frame.Name:HighlightText();
					frame.Name:SetFocus();
				end);
			elseif button.isDelete then
				local set = frame.set;
				StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
					set = set,
					func = Internal.DeleteConditionSet,
				});
			elseif button.isRefresh then
				local set = frame.set;
				Internal.RefreshConditionSet(set)
				Internal.ConditionsTabUpdate(frame);
			else
				frame.Name:ClearFocus();
				self:SetConditionSet(Internal.GetConditionSet(button.id));
			end
		end
	end
	function BtWLoadoutsFrameMixin:ScrollItemDoubleClick(button)
		CloseDropDownMenus();
		if button.isHeader then
			return
		end

		local selectedTab = PanelTemplates_GetSelectedTab(self) or 1;
		if selectedTab == TAB_PROFILES then
			Internal.ActivateProfile(Internal.GetProfile(button.id));
		elseif selectedTab == TAB_TALENTS then
			local set = Internal.GetTalentSet(button.id);
			if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
				Internal.ActivateProfile({
					talents = {button.id}
				});
			end
		elseif selectedTab == TAB_PVP_TALENTS then
			local set = Internal.GetPvPTalentSet(button.id);
			if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
				Internal.ActivateProfile({
					pvptalents = {button.id}
				});
			end
		elseif selectedTab == TAB_ESSENCES then
			Internal.ActivateProfile({
				essences = {button.id}
			});
		elseif selectedTab == TAB_EQUIPMENT then
			Internal.ActivateProfile({
				equipment = {button.id}
			});
		elseif selectedTab == TAB_ACTION_BARS then
			Internal.ActivateProfile({
				actionbars = {button.id}
			});
		end
	end
	function BtWLoadoutsFrameMixin:ScrollItemOnDragStart(button)
		CloseDropDownMenus();
		local command, set;
		local icon = "INV_Misc_QuestionMark";
		local selectedTab = PanelTemplates_GetSelectedTab(self) or 1;
		if selectedTab == TAB_PROFILES then
			if not button.isHeader then
				set = Internal.GetProfile(button.id);
				command = format("/btwloadouts activate profile %d", button.id);
				if set.specID then
					icon = select(4, GetSpecializationInfoByID(set.specID));
				end
			end
		elseif selectedTab == TAB_TALENTS then
			if not button.isHeader then
				set = Internal.GetTalentSet(button.id);
				command = format("/btwloadouts activate talents %d", button.id);
				if set.specID then
					icon = select(4, GetSpecializationInfoByID(set.specID));
				end
			end
		elseif selectedTab == TAB_PVP_TALENTS then
			if not button.isHeader then
				set = Internal.GetPvPTalentSet(button.id);
				command = format("/btwloadouts activate pvptalents %d", button.id);
				if set.specID then
					icon = select(4, GetSpecializationInfoByID(set.specID));
				end
			end
		elseif selectedTab == TAB_ESSENCES then
			if not button.isHeader then
				set = Internal.GetEssenceSet(button.id);
				command = format("/btwloadouts activate essences %d", button.id);
			end
		elseif selectedTab == TAB_EQUIPMENT then
			if not button.isHeader then
				set = Internal.GetEquipmentSet(button.id);
				if set.managerID then
					icon = select(2, C_EquipmentSet.GetEquipmentSetInfo(set.managerID))
				end
				command = format("/btwloadouts activate equipment %d", button.id);
			end
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
	function BtWLoadoutsFrameMixin:OnHelpTipManuallyClosed(closeFlag)
		BtWLoadoutsHelpTipFlags[closeFlag] = true;
		self:Update();
	end
	function BtWLoadoutsFrameMixin:OnNameChanged(text)
		local selectedTab = PanelTemplates_GetSelectedTab(self) or 1;
		local tab = GetTabFrame(self, selectedTab);
		if tab.set and tab.set.name ~= text then
			tab.set.name = text;
			BtWLoadoutsHelpTipFlags["TUTORIAL_RENAME_SET"] = true;
			self:Update();
		end
	end
	function BtWLoadoutsFrameMixin:SetEnabled(value)
		local selectedTab = PanelTemplates_GetSelectedTab(self) or 1;
		if selectedTab ~= TAB_PROFILES and selectedTab ~= TAB_CONDITIONS then -- Other tabs dont support enabling/disabling
			return
		end
		local tab = GetTabFrame(self, selectedTab);
		if tab.set and tab.set.disabled ~= not value then
			tab.set.disabled = not value;
			self:Update();
		end
	end
	function BtWLoadoutsFrameMixin:OnShow()
		if not self.initialized then
			-- self.Equipment.flyoutSettings = {
			-- 	onClickFunc = PaperDollFrameItemFlyoutButton_OnClick,
			-- 	getItemsFunc = PaperDollFrameItemFlyout_GetItems,
			-- 	-- postGetItemsFunc = PaperDollFrameItemFlyout_PostGetItems,
			-- 	hasPopouts = true,
			-- 	parent = self.Equipment,
			-- 	anchorX = 0,
			-- 	anchorY = -3,
			-- 	verticalAnchorX = 0,
			-- 	verticalAnchorY = 0,
			-- };

			self.initialized = true;
		end

		BtWLoadoutsHelpTipFlags["MINIMAP_ICON"] = true;
		StaticPopup_Hide("BTWLOADOUTS_REQUESTACTIVATE");
		StaticPopup_Hide("BTWLOADOUTS_REQUESTMULTIACTIVATE");

		self:Update();
	end
	function BtWLoadoutsFrameMixin:OnHide()
		-- When hiding the main window we are going to assume that something has dramatically changed and completely redo everything
		Internal.ClearConditions()
		Internal.UpdateConditionsForInstance();
		local bossID = Internal.UpdateConditionsForBoss();
		Internal.UpdateConditionsForAffixes();
		-- Boss is unavailable so dont trigger conditions
		if bossID and not Internal.BossAvailable(bossID) then
			return
		end
		Internal.TriggerConditions();
	end
end

BtWLoadoutsTalentButtonMixin = {};
function BtWLoadoutsTalentButtonMixin:OnLoad()
	self:RegisterForClicks("LeftButtonUp");
end
function BtWLoadoutsTalentButtonMixin:OnClick()
	local row = self:GetParent();
	local talents = row:GetParent();
	local talentID = self.id;

	if talents.set.talents[talentID] then
		talents.set.talents[talentID] = nil;

		self.knownSelection:Hide();
		self.icon:SetDesaturated(true);
	else
		talents.set.talents[talentID] = true;

		self.knownSelection:Show();
		self.icon:SetDesaturated(false);

		for _,item in ipairs(row.talents) do
			if item ~= self then
				talents.set.talents[item.id] = nil;

				item.knownSelection:Hide();
				item.icon:SetDesaturated(true);
			end
		end
	end
end
function BtWLoadoutsTalentButtonMixin:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	if self.isPvP then
		GameTooltip:SetPvpTalent(self.id, true);
	else
		GameTooltip:SetTalent(self.id, true);
	end
end
function BtWLoadoutsTalentButtonMixin:OnLeave()
	GameTooltip_Hide();
end

BtWLoadoutsTalentGridButtonMixin = CreateFromMixins(BtWLoadoutsTalentButtonMixin);
function BtWLoadoutsTalentGridButtonMixin:OnClick()
	local grid = self:GetParent();
	local talents = grid:GetParent();
	local talentID = self.id;

	if talents.set.talents[talentID] then
		talents.set.talents[talentID] = nil;

		self.knownSelection:Hide();
		self.icon:SetDesaturated(true);
	else
		talents.set.talents[talentID] = true;

		self.knownSelection:Show();
		self.icon:SetDesaturated(false);
	end

	talents:GetParent():Update();
end


-- [[ LOG ]]
BtWLoadoutsLogFrameMixin = {}
function BtWLoadoutsLogFrameMixin:OnLoad()
	tinsert(UISpecialFrames, self:GetName());
	self:RegisterForDrag("LeftButton");

	self.TitleText:SetText(BTWLOADOUTS_LOG)
	self.TitleText:SetHeight(24)
end
function BtWLoadoutsLogFrameMixin:OnDragStart()
	self:StartMoving();
end
function BtWLoadoutsLogFrameMixin:OnDragStop()
	self:StopMovingOrSizing();
end

function Internal.ClearLog()
	BtWLoadoutsLogFrame.Scroll.EditBox:SetText("")
end
function Internal.LogMessage(...)
	BtWLoadoutsLogFrame.Scroll.EditBox:Insert(string.format("[%.03f] %s\n", GetTime(), string.format(...):gsub("|", "||")))
end

local eventHandlers = {}
function Internal.OnEvent(event, callback)
	if not eventHandlers[event] then
		eventHandlers[event] = {}
	end

	eventHandlers[event][callback] = true
end
function Internal.Call(event, ...)
	local callbacks = eventHandlers[event]
	if callbacks then
		for callback in pairs(callbacks) do
			callback(event, ...)
		end
	end
end

-- [[ Slash Command ]]
-- /btwloadouts activate profile Raid
-- /btwloadouts activate talents Outlaw: Mythic Plus
SLASH_BTWLOADOUTS1 = "/btwloadouts"
SLASH_BTWLOADOUTS2 = "/btwl"
SlashCmdList["BTWLOADOUTS"] = function (msg)
	local command, rest = msg:match("^[%s]*([^%s]+)(.*)");
	if command == "activate" or command == "a" then
		local aType, rest = rest:match("^[%s]*([^%s]+)(.*)");
		local set;
		if aType == "profile" or aType == "loadout" then
			if tonumber(rest) then
				set = Internal.GetProfile(tonumber(rest));
			else
				set = Internal.GetProfileByName(rest);
			end
		elseif aType == "talents" then
			local subset;
			if tonumber(rest) then
				subset = Internal.GetTalentSet(tonumber(rest));
			else
				subset = Internal.GetTalentSetByName(rest);
			end
			if subset then
				set = {
					talents = {subset.setID}
				}
			end
		elseif aType == "pvptalents" then
			local subset;
			if tonumber(rest) then
				subset = Internal.GetPvPTalentSet(tonumber(rest));
			else
				subset = Internal.GetPvPTalentSetByName(rest);
			end
			if subset then
				set = {
					pvptalents = {subset.setID}
				}
			end
		elseif aType == "essences" then
			local subset;
			if tonumber(rest) then
				subset = Internal.GetEssenceSet(tonumber(rest));
			else
				subset = Internal.GetEssenceSetByName(rest);
			end
			if subset then
				set = {
					essences = {subset.setID}
				}
			end
		elseif aType == "equipment" then
			local subset;
			if tonumber(rest) then
				subset = Internal.GetEquipmentSet(tonumber(rest));
			else
				subset = Internal.GetEquipmentSetByName(rest);
			end
			if subset then
				set = {
					equipment = {subset.setID}
				}
			end
		elseif aType == "action-bars" or aType == "actionbars" then
			local subset;
			if tonumber(rest) then
				subset = Internal.GetActionBarSet(tonumber(rest));
			else
				subset = Internal.GetActionBarSetByName(rest);
			end
			if subset then
				set = {
					actionbars = {subset.setID}
				}
			end
		else
			-- Assume profile
			rest = aType .. rest;
			if tonumber(rest) then
				set = Internal.GetProfile(tonumber(rest));
			else
				set = Internal.GetProfileByName(rest);
			end
		end
		if set and Internal.IsLoadoutActivatable(set) then
			Internal.ActivateProfile(set);
		else
			print(L["Could not find a valid set"]);
		end
	elseif command == "minimap" or command == "m" then
		Settings.minimapShown = not Settings.minimapShown;
	elseif command == "log" or command == "l" then
        if BtWLoadoutsLogFrame:IsShown() then
            BtWLoadoutsLogFrame:Hide()
        else
            BtWLoadoutsLogFrame:Show()
		end
	elseif command == nil then
		if BtWLoadoutsFrame:IsShown() then
			BtWLoadoutsFrame:Hide()
		else
			BtWLoadoutsFrame:Show()
		end
	else
		-- Usage
	end
end

if OneRingLib then
	local AB = assert(OneRingLib.ext.ActionBook:compatible(2, 14), "A compatible version of ActionBook is required")

	AB:AugmentCategory("BtWLoadouts", function (category, add)
		local items = {}
		do
			for id, set in pairs(BtWLoadoutsSets.profiles) do
				if type(set) == "table" then
					if Internal.IsLoadoutActivatable(set) then
						items[#items+1] = set
					end
				end
			end
			table.sort(items, function (a, b)
				if a.specID ~= b.specID then
					return (a.specID or 1000) < (b.specID or 1000)
				end

				return a.name < b.name
			end)
			for _,set in ipairs(items) do
				add("btwloadoutprofile", set.setID)
			end
		end

		do
			wipe(items)
			for id, set in pairs(BtWLoadoutsSets.talents) do
				if type(set) == "table" then
					if Internal.IsLoadoutActivatable({
						talents = {set.setID}
					}) then
						items[#items+1] = set
					end
				end
			end
			table.sort(items, function (a, b)
				if a.specID ~= b.specID then
					return a.specID < b.specID
				end

				return a.name < b.name
			end)
			for _,set in ipairs(items) do
				add("btwloadouttalent", set.setID)
			end
		end

		do
			wipe(items)
			for id, set in pairs(BtWLoadoutsSets.pvptalents) do
				if type(set) == "table" then
					if Internal.IsLoadoutActivatable({
						pvptalents = {set.setID}
					}) then
						items[#items+1] = set
					end
				end
			end
			table.sort(items, function (a, b)
				if a.specID ~= b.specID then
					return a.specID < b.specID
				end

				return a.name < b.name
			end)
			for _,set in ipairs(items) do
				add("btwloadoutpvptalent", set.setID)
			end
		end

		do
			wipe(items)
			for id, set in pairs(BtWLoadoutsSets.essences) do
				if type(set) == "table" then
					if Internal.IsLoadoutActivatable({
						essences = {set.setID}
					}) then
						items[#items+1] = set
					end
				end
			end
			table.sort(items, function (a, b)
				if a.role ~= b.role then
					return a.role < b.role
				end

				return a.name < b.name
			end)
			for _,set in ipairs(items) do
				add("btwloadoutessences", set.setID)
			end
		end

		do
			wipe(items)
			for id, set in pairs(BtWLoadoutsSets.equipment) do
				if type(set) == "table" then
					if Internal.IsLoadoutActivatable({
						equipment = {set.setID}
					}) then
						items[#items+1] = set
					end
				end
			end
			table.sort(items, function (a, b)
				return a.name < b.name
			end)
			for _,set in ipairs(items) do
				add("btwloadoutequipment", set.setID)
			end
		end
	end)

	do
		local function hint(id)
			local set = BtWLoadoutsSets.profiles[id]
			local usable = Internal.IsLoadoutActivatable(set)
			return usable, false, nil, set.name
		end
		local function activate(id)
			local set = BtWLoadoutsSets.profiles[id]
			if set then
				Internal.ActivateProfile(set)
			end
		end
		local map = {}
		AB:RegisterActionType("btwloadoutprofile", function(id)
			if not map[id] then
				map[id] = AB:CreateActionSlot(hint, id, "func", activate, id)
			end
			return map[id]
		end, function(id)
			local set = BtWLoadoutsSets.profiles[id]

			local category
			if set.specID then
				local _, specName, _, _, _, classFile = GetSpecializationInfoByID(set.specID)
				local classColor = C_ClassColor.GetClassColor(classFile);
				category = format("%s - %s", L["Profile"], classColor:WrapTextInColorCode(specName))
			else
				category = L["Profile"]
			end

			return category, set.name, nil
		end)
	end

	do
		local function hint(id)
			local set = BtWLoadoutsSets.talents[id]
			local usable = Internal.IsLoadoutActivatable({
				talents = {set.setID}
			})
			return usable, false, nil, set.name
		end
		local function activate(id)
			local set = BtWLoadoutsSets.talents[id]
			if set then
				Internal.ActivateProfile({
					talents = {set.setID}
				});
			end
		end
		local map = {}
		AB:RegisterActionType("btwloadouttalent", function(id)
			if not map[id] then
				map[id] = AB:CreateActionSlot(hint, id, "func", activate, id)
			end
			return map[id]
		end, function(id)
			local set = BtWLoadoutsSets.talents[id]

			local category
			if set.specID then
				local _, specName, _, _, _, classFile = GetSpecializationInfoByID(set.specID)
				local classColor = C_ClassColor.GetClassColor(classFile);
				category = format("%s - %s", L["Talents"], classColor:WrapTextInColorCode(specName))
			else
				category = L["Talents"]
			end

			return category, set.name, nil
		end)
	end

	do
		local function hint(id)
			local set = BtWLoadoutsSets.pvptalents[id]
			local usable = Internal.IsLoadoutActivatable({
				pvptalents = {set.setID}
			})
			return usable, false, nil, set.name
		end
		local function activate(id)
			local set = BtWLoadoutsSets.pvptalents[id]
			if set then
				Internal.ActivateProfile({
					pvptalents = {set.setID}
				});
			end
		end
		local map = {}
		AB:RegisterActionType("btwloadoutpvptalent", function(id)
			if not map[id] then
				map[id] = AB:CreateActionSlot(hint, id, "func", activate, id)
			end
			return map[id]
		end, function(id)
			local set = BtWLoadoutsSets.pvptalents[id]

			local category
			if set.specID then
				local _, specName, _, _, _, classFile = GetSpecializationInfoByID(set.specID)
				local classColor = C_ClassColor.GetClassColor(classFile);
				category = format("%s - %s", L["PvP Talents"], classColor:WrapTextInColorCode(specName))
			else
				category = L["PvP Talents"]
			end

			return category, set.name, nil
		end)
	end

	do
		local function hint(id)
			local set = BtWLoadoutsSets.essences[id]
			local usable = Internal.IsLoadoutActivatable({
				essences = {set.setID}
			})
			return usable, false, nil, set.name
		end
		local function activate(id)
			local set = BtWLoadoutsSets.essences[id]
			if set then
				Internal.ActivateProfile({
					essences = {set.setID}
				});
			end
		end
		local map = {}
		AB:RegisterActionType("btwloadoutessences", function(id)
			if not map[id] then
				map[id] = AB:CreateActionSlot(hint, id, "func", activate, id)
			end
			return map[id]
		end, function(id)
			local set = BtWLoadoutsSets.essences[id]

			local category
			if set.role then
				category = format("%s - %s", L["Essences"], _G[set.role])
			else
				category = L["Essences"]
			end

			return category, set.name, nil
		end)
	end

	do
		local function hint(id)
			local set = BtWLoadoutsSets.equipment[id]
			local usable = Internal.IsLoadoutActivatable({
				equipment = {set.setID}
			})
			return usable, false, nil, set.name
		end
		local function activate(id)
			local set = BtWLoadoutsSets.equipment[id]
			if set then
				Internal.ActivateProfile({
					equipment = {set.setID}
				});
			end
		end
		local map = {}
		AB:RegisterActionType("btwloadoutequipment", function(id)
			if not map[id] then
				map[id] = AB:CreateActionSlot(hint, id, "func", activate, id)
			end
			return map[id]
		end, function(id)
			local set = BtWLoadoutsSets.equipment[id]

			local category = L["Equipment"]

			return category, set.name, nil
		end)
	end
end
