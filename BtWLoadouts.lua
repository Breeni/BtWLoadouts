--[[@TODO
	Loadout and condition restrictions like character
	Update condition filtering
	Update set dropdowns to use sidebar filtering
	New user UI, each tab should have a cleaner ui before creaitng a set
	-- 1.0.0 breakpoint
	Show restrictions for subsets within the loadout list?
	Equipment flyout
	Equipment sets should store transmog?
	Loadout keybindings
	Conditions need to support arena comp?
	Update new set text button based on tab?
	Set icons
	Import/Export and custom links
	When combining sets, adjust sets for the current player,
	  eg moving essences because the character missing a ring/essence
	Set save button?
	Show what will change when activating a condition
	Zone Specific conditions
	Conditions should support multiple bosses/affix combos?
	Conditions level support
	Option to show minimap menu on mouse over
	Trigger system for changing loadouts, run custom code when a set is changed?
]]

local ADDON_NAME, Internal = ...;
local L = Internal.L;

local External = {}
_G[ADDON_NAME] = External

local GetCharacterInfo = Internal.GetCharacterInfo
local GetCharacterSlug = Internal.GetCharacterSlug

BTWLOADOUTS = ADDON_NAME
BTWLOADOUTS_LOADOUT = L["Loadout"]
BTWLOADOUTS_LOADOUTS = L["Loadouts"]
BTWLOADOUTS_TALENTS = L["Talents"]
BTWLOADOUTS_PVP_TALENTS = L["PvP Talents"]
BTWLOADOUTS_ESSENCES = L["Essences"]
BTWLOADOUTS_SOULBINDS = L["Soulbinds"]
BTWLOADOUTS_EQUIPMENT = L["Equipment"]
BTWLOADOUTS_ACTION_BARS = L["Action Bars"]
BTWLOADOUTS_CONDITIONS = L["Conditions"]
BTWLOADOUTS_NEW_SET = L["New Set"]
BTWLOADOUTS_ACTIVATE = L["Activate"]
BTWLOADOUTS_DELETE = L["Delete"]
BTWLOADOUTS_NAME = L["Name"]
BTWLOADOUTS_SPECIALIZATION = L["Specialization"]
BTWLOADOUTS_ENABLED = L["Enabled"]
BTWLOADOUTS_UPDATE = L["Update"]
BTWLOADOUTS_LOG = L["Log"]
BTWLOADOUTS_CHARACTER_RESTRICTIONS = L["Character Restrictions"]
BTWLOADOUTS_RESTRICTIONS = L["Restrictions"]
BTWLOADOUTS_IMPORT = L["Import"]
BTWLOADOUTS_EXPORT = L["Export"]
BTWLOADOUTS_ZONE_NAME = L["Zone Name"]

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
		mt.__index = tbl;
	end
	function mt:__newindex (key, value)
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
        name = L["Dont offer conditions of different specialization"],
        key = "noSpecSwitch",
        default = false,
    },
    {
        name = L["Filter chat spam while changing loadouts"],
        key = "filterChatSpam",
        default = false,
    },
    {
        name = L["Enable Essences"],
        key = "essences",
        onChange = function (id, value)
			BtWLoadoutsFrame.Essences:SetEnabled(value)
			Internal.SetLoadoutSegmentEnabled(id, value)
			BtWLoadoutsFrame:Update()
        end,
        default = true,
    },
    {
        name = L["Sort classes by name"],
        key = "sortClassesByName",
        onChange = function (id, value)
			if value then
				Internal.SortClassesByName()
			else
				Internal.SortClassesByID()
			end
			BtWLoadoutsFrame:Update()
        end,
        default = true,
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

StaticPopupDialogs["BTWLOADOUTS_REQUESTACTIVATE"] = {
	preferredIndex = STATICPOPUP_NUMDIALOGS,
	text = L["Activate loadout %s?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		data.func(data.set);
	end,
	timeout = 0,
	hideOnEscape = 1
};
StaticPopupDialogs["BTWLOADOUTS_REQUESTMULTIACTIVATE"] = {
	preferredIndex = STATICPOPUP_NUMDIALOGS,
	text = L["Activate the following loadout?\n"],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		data.func(Internal.GetAciveConditionSelection().profile);
	end,
	OnShow = function(self)
		-- Something is changing the frame strata causing issues with the dropdown
		-- box so we will change it to defgault
		if self:GetFrameStrata() ~= "DIALOG" then
			self:SetFrameStrata("DIALOG")
		end
	end,
	timeout = 0,
	hideOnEscape = 1
};
StaticPopupDialogs["BTWLOADOUTS_REQUESTACTIVATERESTED"] = {
	preferredIndex = STATICPOPUP_NUMDIALOGS,
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
	preferredIndex = STATICPOPUP_NUMDIALOGS,
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
	preferredIndex = STATICPOPUP_NUMDIALOGS,
	text = L["A tome or rested area is required to fully apply your loadout, do you wish to use a tome or partially continue without one?"],
	button1 = YES,
	button2 = NO,
	button3 = CONTINUE,
	selectCallbackByIndex = true,
	OnButton1 = function(self, ...)
	end,
	OnCancel = function(self, data, reason, ...)
		if reason == "clicked" then
			Internal.CancelActivateProfile();
		end
	end,
	OnButton3 = function (self, data, reason, ...)
		if reason == "clicked" then
			Internal.ContinueWithoutTomeActivateProfile();
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
	OnHide = function(self, ...)
		tomeButton:SetParent(UIParent);
		tomeButton:ClearAllPoints();
		tomeButton.button = nil;
		tomeButton:SetAttribute("active", false);
	end,
	hasItemFrame = 1,
	timeout = 0,
	hideOnEscape = 1,
	noCancelOnReuse = 1,
};
StaticPopupDialogs["BTWLOADOUTS_JAILERSCHAINS"] = {
	preferredIndex = STATICPOPUP_NUMDIALOGS,
	text = L["Cannot fully apply your loadout while under the effects of the Jailer's Chains, do you wish to partially continue instead?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, ...)
		Internal.ContinueIgnoreChainsActivateProfile();
	end,
	OnCancel = function(self, data, reason, ...)
		if reason == "clicked" then
			Internal.CancelActivateProfile();
		end
	end,
	timeout = 0,
	hideOnEscape = 1
};
StaticPopupDialogs["BTWLOADOUTS_NEEDRESTED"] = {
	preferredIndex = STATICPOPUP_NUMDIALOGS,
	text = L["A rested area or tome is needed to fully apply your loadout, do you wish to partially continue instead?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, ...)
		Internal.ContinueWithoutTomeActivateProfile();
	end,
	OnCancel = function(self, data, reason, ...)
		if reason == "clicked" then
			Internal.CancelActivateProfile();
		end
	end,
	timeout = 0,
	hideOnEscape = 1
};
StaticPopupDialogs["BTWLOADOUTS_DELETESET"] = {
	preferredIndex = STATICPOPUP_NUMDIALOGS,
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
	preferredIndex = STATICPOPUP_NUMDIALOGS,
	text = L["Are you sure you wish to delete the set \"%s\", this set is in use by one or more loadouts. This cannot be reversed."],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		data.func(data.set);
	end,
	timeout = 0,
	whileDead = 1,
	showAlert = 1
};
StaticPopupDialogs["BTWLOADOUTS_DELETECHARACTER"] = {
	preferredIndex = STATICPOPUP_NUMDIALOGS,
	text = L["Are you sure you wish to delete the character data for \"%s\", this will also irreversibly delete any equipment sets for the character."],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, slug)
		Internal.DeleteCharacter(slug)
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
local TAB_LOADOUTS = 1;
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

local function shallowcopy(tbl)
	local result = {}
	for k,v in pairs(tbl) do
		result[k] = v
	end
	return result
end

local function SpecDropDown_OnClick(self, arg1, arg2, checked)
	local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
	local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

	CloseDropDownMenus();
	local set = tab.set;

	if selectedTab == TAB_LOADOUTS then
		local classFile = set.specID and select(6, GetSpecializationInfoByID(set.specID))
		tab.temp[classFile or "NONE"] = set.character

		set.specID = arg1;

		classFile = set.specID and select(6, GetSpecializationInfoByID(set.specID))
		set.character = tab.temp[classFile or "NONE"] or shallowcopy(set.character)
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

-- Restrictions Drop Down, used by sets to handle limit activation
do
	local function DropDownInit(self, level, menuList)
		local function OnClick(_, arg1, arg2, checked)
			self:ToggleSelected(arg1, arg2)
		end

		local info = UIDropDownMenu_CreateInfo()
		if (level or 1) == 1 then
			local hasSelected = false

			info.func = OnClick
			info.checked = true
			info.keepShownOnClick = true
			for _,type,key,name, restricted in self:EnumerateSelected() do
				info.text = restricted and string.format("|CFFFF8080%s|r", name) or name
				info.arg1 = type
				info.arg2 = key

				info.tooltipOnButton = restricted
				if restricted then
					info.tooltipTitle = name
					info.tooltipText = L["Incompatible Restrictions"]
				else
					info.tooltipTitle = nil
					info.tooltipText = nil
				end

				UIDropDownMenu_AddButton(info, level)

				hasSelected = true
			end
			
			info.tooltipOnButton = false
			info.tooltipTitle = nil
			info.tooltipText = nil

			if hasSelected then
				UIDropDownMenu_AddSeparator()
			end
			
			info.func = nil
			info.checked = nil
			for _,type,name in self:EnumerateSupportedTypes() do
				info.text = name
				info.hasArrow, info.menuList = true, type
				info.notCheckable = true
				UIDropDownMenu_AddButton(info, level)
			end
		else
			info.func = OnClick
			info.keepShownOnClick = true
			for _,key,name in self:EnumerateType(menuList) do
				info.text = name
				info.arg1 = menuList
				info.arg2 = key
				info.checked = self:IsSelected(menuList, key)
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end

	BtWLoadoutsRestrictionsDropDownMixin = {}
	function BtWLoadoutsRestrictionsDropDownMixin:OnLoad()
		self.selected = {}
		self.supportedTypes = {}
		self.limitations = {}
	end
	function BtWLoadoutsRestrictionsDropDownMixin:OnShow()
		if not self.initialized then
			UIDropDownMenu_Initialize(self, DropDownInit, "MENU")
			self.initialized = true
		end
	end
	function BtWLoadoutsRestrictionsDropDownMixin:EnumerateSelected()
		local selected = {}

		for _,type,typeName in self:EnumerateSupportedTypes() do
			if self.selected[type] and next(self.selected[type]) then
				for _,key,name,restricted in self:EnumerateType(type, true) do
					if self:IsSelected(type, key) then
						selected[#selected+1] = {type, key, string.format("%s: %s", typeName, name), restricted}
					end
				end
			end
		end

		return function (tbl, index)
			index = index + 1
			if tbl[index] then
				return index, unpack(tbl[index])
			end
		end, selected, 0
	end
	local selectionTemp = {}
	function BtWLoadoutsRestrictionsDropDownMixin:SetSelections(tbl)
		assert(type(tbl) == "table", "Expected table")

		-- Clean up tbl based on available types
		wipe(selectionTemp)
		for _,t in ipairs(self.supportedTypes) do
			selectionTemp[t] = tbl[t]
		end
		wipe(tbl)
		for k,v in pairs(selectionTemp) do
			tbl[k] = v
		end

		self.selected = tbl
	end
	function BtWLoadoutsRestrictionsDropDownMixin:ClearSelected()
		wipe(self.selected)
	end
	function BtWLoadoutsRestrictionsDropDownMixin:IsSelected(type, key)
		return self.selected[type] and self.selected[type][key]
	end
	function BtWLoadoutsRestrictionsDropDownMixin:ToggleSelected(type, key)
		self.selected[type] = self.selected[type] or {}
		if self.selected[type][key] then
			self.selected[type][key] = nil
		else
			self.selected[type][key] = true
		end

		if self.onchange then
			self:onchange(type, key)
		end
	end
	function BtWLoadoutsRestrictionsDropDownMixin:SetSupportedTypes(...)
		wipe(self.supportedTypes)
		for i=1,select('#', ...) do
			local type = strlower(select(i, ...))
			assert(Internal.Filters[type] ~= nil, "Unavailable type " .. type)
			self.supportedTypes[i] = type
		end
	end
	-- Allow limiting some supported types, like characters to limit spec or role to limit spec.
	function BtWLoadoutsRestrictionsDropDownMixin:SetLimitations(...)
		wipe(self.limitations)

		for i=1,select('#', ...),2 do
			local k,v = select(i, ...)
			self.limitations[k] = v
		end
	end
	function BtWLoadoutsRestrictionsDropDownMixin:EnumerateSupportedTypes()
		return function (tbl, index)
			index = index + 1
			local type = tbl[index]
			if type then
				return index, type, Internal.Filters[type].name
			end
		end, self.supportedTypes, 0
	end
	function BtWLoadoutsRestrictionsDropDownMixin:EnumerateType(type, includeLimitations)
		return Internal.Filters[type].enumerate(self.limitations, includeLimitations)
	end
	function BtWLoadoutsRestrictionsDropDownMixin:SetScript(scriptType, handler)
		if scriptType == "OnChange" then
			self.onchange = handler
		else
			getmetatable(self).SetScript(self, scriptType, handler)
		end
	end

	function Internal.UpdateRestrictionFilters(set)
		if set.restrictions then
			local filters = set.filters or {}
			
			-- Covenant
			if set.restrictions.covenant and next(set.restrictions.covenant) then
				filters.covenant = wipe(filters.covenant or {})
				local tbl = filters.covenant
				for covenant in pairs(set.restrictions.covenant) do
					tbl[#tbl+1] = covenant
				end
			else
				filters.covenant = nil
			end
			
			-- Specialization
			local roles = {}
			local classes = {}
			if set.restrictions.spec and next(set.restrictions.spec) then
				if filters.spec == nil or type(filters.spec) == "table" then
					filters.spec = wipe(filters.spec or {})
					local tbl = filters.spec
					for spec in pairs(set.restrictions.spec) do
						local role, class = select(5, GetSpecializationInfoByID(spec))

						roles[role] = true
						classes[class] = true

						tbl[#tbl+1] = spec
					end
				end

				if filters.role == nil or type(filters.role) == "table" then
					filters.role = wipe(filters.role or {})
					local tbl = filters.role
					for role in pairs(roles) do
						tbl[#tbl+1] = role
					end
				end

				if filters.class == nil or type(filters.class) == "table" then
					filters.class = wipe(filters.class or {})
					local tbl = filters.class
					for class in pairs(classes) do
						tbl[#tbl+1] = class
					end
				end
			else
				filters.spec = nil
				filters.role = nil
				filters.class = nil
			end
			
			-- Race
			if set.restrictions.race and next(set.restrictions.race) then
				filters.race = wipe(filters.race or {})
				local tbl = filters.race
				for race in pairs(set.restrictions.race) do
					tbl[#tbl+1] = race
				end
			else
				filters.race = nil
			end
		end
	end
	function Internal.AreRestrictionsValidFor(restrictions, specID, covenantID, raceID)
		if restrictions then
			if restrictions.spec and next(restrictions.spec) and specID ~= nil then
				if not restrictions.spec[specID] then
					return false
				end
			end
			
			if restrictions.covenant and next(restrictions.covenant) and covenantID ~= nil then
				if not restrictions.covenant[covenantID] then
					return false
				end
			end
			
			if restrictions.race and next(restrictions.race) and raceID ~= nil then
				if not restrictions.race[raceID] then
					return false
				end
			end
		end
	
		return true
	end
	-- Used by combine functions to check set restrictions
	function Internal.AreRestrictionsValidForPlayer(restrictions)
		local specID = GetSpecializationInfo(GetSpecialization()) or false
		local covenantID = C_Covenants.GetActiveCovenantID() or false
		local raceID = select(3, UnitRace("player")) or false
	
		return Internal.AreRestrictionsValidFor(restrictions, specID, covenantID, raceID)
	end
end

--[[
	Character selection drop down menu
]]
do
	BtWLoadoutsCharacterDropDownMixin = {}
	function BtWLoadoutsCharacterDropDownMixin:OnShow()
		if not self.initialized then
			UIDropDownMenu_Initialize(self, self.Init);
			self.initialized = true
		end
	end
	function BtWLoadoutsCharacterDropDownMixin:Init(level)
		if not self.GetValue then
			return
		end

		local info = UIDropDownMenu_CreateInfo();
		local selected = self:GetValue()

		info.keepShownOnClick = true
		info.func = function (button, arg1, arg2, checked)
			self:SetValue(button, arg1, arg2, checked)
			CloseDropDownMenus()
			ToggleDropDownMenu(nil, nil, self)
		end

		if self.includeAny then
			info.text = L["Any"];
			info.arg1 = nil
			if self.multiple then
				info.checked = next(selected) == nil
			else
				info.checked = selected == nil
			end
			UIDropDownMenu_AddButton(info, level);
		end
		if self.includeInherit then
			info.text = L["Inherit"];
			info.arg1 = "inherit"
			if self.multiple then
				info.checked = selected["inherit"];
			else
				info.checked = selected == "inherit"
			end
			UIDropDownMenu_AddButton(info, level);
		end

		local character = Internal.GetCharacterSlug()
		local classFile = select(2, UnitClass("player"));
		if self.classFile == nil or self.classFile == classFile then
			local name, realm = UnitFullName("player")
			local characterInfo = GetCharacterInfo(character)
			if characterInfo then
				local classColor = C_ClassColor.GetClassColor(characterInfo.class)
				name = format("%s - %s", classColor:WrapTextInColorCode(characterInfo.name), characterInfo.realm)
			end

			info.text = name
			info.arg1 = character
			if self.multiple then
				info.checked = selected[character]
			else
				info.checked = selected == character;
			end

			UIDropDownMenu_AddButton(info, level);
		end

		local playerCharacter = character
		for _,character in Internal.CharacterIterator() do
			if playerCharacter ~= character then
				local name
				local characterInfo = GetCharacterInfo(character)
				if self.classFile == nil or self.classFile == characterInfo.class then
					if characterInfo then
						local classColor = C_ClassColor.GetClassColor(characterInfo.class)
						name = format("%s - %s", classColor:WrapTextInColorCode(characterInfo.name), characterInfo.realm)
					end

					info.text = name
					info.arg1 = character
					if self.multiple then
						info.checked = selected[character]
					else
						info.checked = selected == character;
					end
					
					UIDropDownMenu_AddButton(info, level);
				end
			end
		end
	end
	function BtWLoadoutsCharacterDropDownMixin:SetClass(classFile)
		self.classFile = classFile
	end
	function BtWLoadoutsCharacterDropDownMixin:UpdateName()
		if not self.GetValue then
			return
		end

		local character = self:GetValue()

		if self.multiple then
			local first = next(character)
			if first == nil then
				UIDropDownMenu_SetText(self, L["Any"]);
			elseif first == "inherit" then
				UIDropDownMenu_SetText(self, L["Inherit"]);
			elseif next(character, first) == nil then
				local characterInfo = Internal.GetCharacterInfo(first);
				if characterInfo then
					local classColor = C_ClassColor.GetClassColor(characterInfo.class)
					first = format("%s - %s", classColor:WrapTextInColorCode(characterInfo.name), characterInfo.realm)
				end
				UIDropDownMenu_SetText(self, first);
			else
				UIDropDownMenu_SetText(self, L["Multiple"]);
			end
		else
			if character == nil then
				UIDropDownMenu_SetText(self, L["None"]);
			elseif character == "inherit" then
				UIDropDownMenu_SetText(self, L["Inherit"]);
			else
				local characterInfo = Internal.GetCharacterInfo(character);
				if characterInfo then
					local classColor = C_ClassColor.GetClassColor(characterInfo.class)
					character = format("%s - %s", classColor:WrapTextInColorCode(characterInfo.name), characterInfo.realm)
				end
				UIDropDownMenu_SetText(self, character);
			end
		end
	end
end

-- Sets Drop Down menu
do
	-- local filtered
	local function DropDownInit(self, level, menuList)
		local function OnClick(_, arg1, arg2, checked)
			self:callback(arg1)
		end
		
		local info = UIDropDownMenu_CreateInfo()

		local selected = self:GetSelected()

		if (level or 1) == 1 and self:IncludeNone() then
			info.text = NONE;
			info.func = OnClick;
			info.arg1 = "none";
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);
		end

		if not menuList then
			menuList = Internal.FilterSets({}, self.filters, self:GetSets())
			menuList = Internal.CategoriesSets(menuList, self:GetCategories())
		end
		
		local filter = self.categories[level or 1]
		if filter then
			info.func = nil;
			info.hasArrow = true;
			info.keepShownOnClick = true;
			info.notCheckable = true;

			for _,key,name,restricted in Internal.Filters[filter].enumerate(nil, false, true) do
				if menuList[key] then
					info.text = name
					info.menuList = menuList[key]--(menuList and (menuList .. ".") or "") .. key
					UIDropDownMenu_AddButton(info, level);
				end
			end
		else
			info.func = OnClick;
			Internal.SortSets(menuList)

			local hasPreItems = false
			for k,set in pairs(menuList) do
				if hasPreItems and (set.order or 0) >= 0 then
					UIDropDownMenu_AddSeparator(level)
					hasPreItems = false
				elseif not hasPreItems and set.order and set.order < 0 then
					hasPreItems = true
				end

				info.text = set.name ~= "" and set.name or L["Unnamed"];
				info.arg1 = set.setID;
				info.func = OnClick;
				info.checked = selected == set.setID;
				
				UIDropDownMenu_AddButton(info, level);
			end
		end

		if (level or 1) == 1 and self:IncludeNewSet() then
			info.text = L["New Set"];
			info.func = OnClick;
			info.arg1 = "new";
			info.hasArrow, info.menuList = false, nil;
			info.keepShownOnClick = false;
			info.notCheckable = true;
			info.checked = false;

			UIDropDownMenu_AddButton(info, level);
		end
	end

	BtWLoadoutsSetDropDownMixin = {}
	function BtWLoadoutsSetDropDownMixin:OnLoad()
		self.categories = {}
		self.sets = {}
	end
	function BtWLoadoutsSetDropDownMixin:Init()
		UIDropDownMenu_Initialize(self, DropDownInit, "MENU");
	end
	function BtWLoadoutsSetDropDownMixin:OnShow()
		if not self.initialized then
			self.initialized = true
			self:Init()
		end
	end
	function BtWLoadoutsSetDropDownMixin:SetSelected(value)
		self.selected = value
	end
	function BtWLoadoutsSetDropDownMixin:SetSets(value)
		self.sets = value
	end
	function BtWLoadoutsSetDropDownMixin:SetCategories(value)
		self.categories = value
	end
	function BtWLoadoutsSetDropDownMixin:GetCategories()
		return unpack(self.categories)
	end
	function BtWLoadoutsSetDropDownMixin:SetFilters(value)
		self.filters = value
	end
	function BtWLoadoutsSetDropDownMixin:GetFilters()
		local temp = {}
		for k in pairs(self.filters) do
			temp[#temp+1] = k
		end
		return unpack(temp)
	end
	function BtWLoadoutsSetDropDownMixin:GetSets()
		return self.sets
	end
	function BtWLoadoutsSetDropDownMixin:GetSelected()
		return self.selected
	end
	function BtWLoadoutsSetDropDownMixin:IncludeNewSet()
		return true
	end
	function BtWLoadoutsSetDropDownMixin:IncludeNone()
		return self.includeNone
	end
	function BtWLoadoutsSetDropDownMixin:SetIncludeNone(value)
		self.includeNone = not not value
	end
	function BtWLoadoutsSetDropDownMixin:OnItemClick(callback)
		self.callback = callback
	end
end

--[[
	BtWLoadoutsSidebarMixin, sidebar display with filtering
]]
do
	local FilterSetsBySearch = Internal.FilterSetsBySearch
	local FilterSets = Internal.FilterSets
	local CategoriesSets = Internal.CategoriesSets
	local SortSets = Internal.SortSets
	local function BuildList(items, depth, selected, filtered, collapsed, ...)
		if select('#', ...) == 0 then
			SortSets(filtered)

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
			for _,key,name,restricted in Internal.Filters[filter].enumerate(nil, nil, true) do
				if filtered[key] then
					local isCollapsed = collapsed[key] and true or false
					items[#items+1] = {
						id = key,
						type = filter,
						isHeader = true,
						isCollapsed = isCollapsed,
						collapsed = collapsed,
						name = name,
						depth = depth,
					};
					if not isCollapsed then
						selected = BuildList(items, depth + 1, selected, filtered[key], collapsed.children, select(2, ...))
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
			if sidebar:SupportsFilters("disabled") then
				info.checked = sidebar:GetFilter("disabled") == 0
				info.arg1 = "disabled"
				info.arg2 = 0
				info.text = L["Enabled Sets Only"]
				UIDropDownMenu_AddButton(info, level)
			end

			if sidebar:GetSupportedFilters() then
				info.isTitle = true
				info.notCheckable = true
				info.checked = false
				info.text = L["Categories"]
				UIDropDownMenu_AddButton(info, level)

				info.isTitle = false
				info.disabled = false
				info.notCheckable = false
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
		return Internal.Filters[key].name or key
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
		for k in pairs(value) do
			if not self:SupportsFilters(k) then
				value[k] = nil
			end
		end

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

		wipe(self.Scroll.items)
		self.selected = BuildList(self.Scroll.items, 0, self.selected, filtered, self.collapsed, unpack(self.categories))
		if not self.selected then -- Fallback in case everything is hidden
			for _,set in pairs(self.sets) do
				if type(set) == "table" then
					self.selected = set
					break
				end
			end
		end

		self.Scroll:update();
		self:Show()
	end
end

do
	function BtWLoadoutsTabFrame_OnLoad(self)
		local frame = self:GetParent()
		local Tabs = frame.Tabs

		local index = #Tabs
		local previous = Tabs[index]
		while previous and not previous:IsShown() do
			index = index - 1
			previous = Tabs[index]
		end

		local tab = frame.TabPool:Acquire()
		local id = #Tabs

		self:SetID(id)
		tab:SetID(id)
		tab:SetText(self.name)

		if previous then
			tab:SetPoint("LEFT", previous, "RIGHT", -16, 0)
		else
			tab:SetPoint("BOTTOMLEFT", 7, -30)
		end

		tab:SetShown(self.enabled ~= false)

		if self.segment then
			frame.TabSegments[self.segment] = self
		end

		PanelTemplates_SetNumTabs(frame, id);
		if id == 1 then
			PanelTemplates_SetTab(frame, id);
		end
		PanelTemplates_UpdateTabs(frame);
	end
	function BtWLoadoutsTabFrame_SetEnabled(self, value)
		self.enabled = value and true or false
		BtWLoadoutsTabFrame_ReanchorTabs(self)
	end
	function BtWLoadoutsTabFrame_ReanchorTabs(self)
		local frame = self:GetParent()
		local Tabs = frame.Tabs
		local TabFrames = frame.TabFrames

		local index = self:GetID() - 1
		local previous = Tabs[index]
		while previous and not previous:IsShown() do
			index = index - 1
			previous = Tabs[index]
		end
		for i=self:GetID(),#Tabs do
			local tab = Tabs[i]
			local tabFrame = TabFrames[i]

			tab:SetShown(tabFrame.enabled ~= false)
			if tabFrame.enabled ~= false then
				if previous then
					tab:SetPoint("LEFT", previous, "RIGHT", -16, 0)
				else
					tab:SetPoint("BOTTOMLEFT", 7, -30)
				end
				previous = tab
			end
		end
	end

	BtWLoadoutsFrameMixin = {};
	function BtWLoadoutsFrameMixin:OnLoad()
		tinsert(UISpecialFrames, self:GetName());
		self:RegisterForDrag("LeftButton");

		self.Tabs = {}
		self.TabSegments = {}
		self.TabPool = CreateFramePool("Button", self, "BtWLoadoutsTabTemplate")

		self.TitleText:SetText(BTWLOADOUTS_LOADOUTS)
		self.TitleText:SetHeight(24)
	end
	function BtWLoadoutsFrameMixin:OnDragStart()
		self:StartMoving();
	end
	function BtWLoadoutsFrameMixin:OnDragStop()
		self:StopMovingOrSizing();
	end
	function BtWLoadoutsFrameMixin:OnMouseUp()
		if self.Essences.pending ~= nil then
			self.Essences.pending = nil
			SetCursor(nil);
			self:Update();
		end
	end
	function BtWLoadoutsFrameMixin:OnEnter()
		if self.Essences.pending ~= nil then
			SetCursor("interface/cursor/cast.blp");
		end
	end
	function BtWLoadoutsFrameMixin:OnLeave()
		SetCursor(nil);
	end
	function BtWLoadoutsFrameMixin:SetLoadout(set)
		self.Loadouts.set = set;
		wipe(self.Loadouts.temp);
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
		wipe(self.Conditions.temp);
		self:Update();
	end
	function BtWLoadoutsFrameMixin:SetSetByID(setType, setID)
		local frame = setType == "loadout" and self.TabFrames[1] or self.TabSegments[setType]
		if frame then
			PanelTemplates_SetTab(self, frame:GetID())
			frame:SetSetByID(setID)
			self:Update()
		end
	end
	function BtWLoadoutsFrameMixin:GetCurrentTab()
		local selectedTab = PanelTemplates_GetSelectedTab(self) or 1
		return self.TabFrames[selectedTab]
	end
	function BtWLoadoutsFrameMixin:Update()
		local selectedTab = PanelTemplates_GetSelectedTab(self) or 1
		if self.TabFrames[selectedTab].enabled == false then
			selectedTab = 1
			PanelTemplates_SetTab(self, selectedTab)
		end

		self.Export:Hide()
		for id,frame in ipairs(self.TabFrames) do
			frame:SetShown(id == selectedTab)
		end

		self.TabFrames[selectedTab]:Update(self)
	end
	function BtWLoadoutsFrameMixin:OnButtonClick(button)
		self:GetCurrentTab():OnButtonClick(button)
	end
	function BtWLoadoutsFrameMixin:OnSidebarItemClick(button)
		self:GetCurrentTab():OnSidebarItemClick(button)
	end
	function BtWLoadoutsFrameMixin:OnSidebarItemDoubleClick(button)
		self:GetCurrentTab():OnSidebarItemDoubleClick(button)
	end
	function BtWLoadoutsFrameMixin:OnSidebarItemDragStart(button)
		self:GetCurrentTab():OnSidebarItemDragStart(button)
	end
	function BtWLoadoutsFrameMixin:OnHelpTipManuallyClosed(closeFlag)
		BtWLoadoutsHelpTipFlags[closeFlag] = true;
		self:Update();
	end
	local function OptionsMenu_Init(self, level, menuList)
		if level == 1 then
			local info = UIDropDownMenu_CreateInfo();
			info.isTitle, info.disabled, info.notCheckable = false, false, false;
			info.func = function (self, key)
				Settings[key] = not Settings[key];
			end
			for i, entry in ipairs(Settings) do
				info.text = entry.name;
				info.arg1 = entry.key;
				info.checked = Settings[entry.key];
	
				UIDropDownMenu_AddButton(info, level);
			end
	
			UIDropDownMenu_AddSeparator()
			
			info.func = nil
			info.text = L["Delete Character Data"]
			info.notCheckable = true
			info.keepShownOnClick = true
			info.hasArrow, info.menuList = true, "delete"
	
			UIDropDownMenu_AddButton(info, level);
		elseif level == 2 and menuList == "delete" then
			local info = UIDropDownMenu_CreateInfo()
			info.notCheckable = true
			info.keepShownOnClick = true
			for _,realm in Internal.EnumerateRealms() do
				info.text = realm
				info.hasArrow, info.menuList = true, realm
	
				UIDropDownMenu_AddButton(info, level)
			end
		elseif level == 3 then
			local info = UIDropDownMenu_CreateInfo()
			info.notCheckable = true
			info.func = function (self, slug)
				StaticPopup_Show("BTWLOADOUTS_DELETECHARACTER", Internal.GetFormattedCharacterName(slug, true), nil, slug)
			end
			local playerSlug = Internal.GetCharacterSlug()
			for _,character in Internal.EnumerateCharactersForRealm(menuList) do
				if character ~= playerSlug then
					local name = character
					local characterInfo = Internal.GetCharacterInfo(character)
					if characterInfo then
						local classColor = C_ClassColor.GetClassColor(characterInfo.class)
						name = classColor:WrapTextInColorCode(characterInfo.name)
					end
	
					info.text = name
					info.arg1 = character
	
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end
	end
	function BtWLoadoutsFrameMixin:OnOptionsClick(button)
		if not self.OptionsMenu then
			self.OptionsMenu = CreateFrame("Frame", self:GetName().."OptionsMenu", self, "UIDropDownMenuTemplate");
			UIDropDownMenu_Initialize(self.OptionsMenu, OptionsMenu_Init, "MENU");
		end

		ToggleDropDownMenu(1, nil, self.OptionsMenu, button, 0, 0);
	end
	function BtWLoadoutsFrameMixin:SetExport(value)
		PanelTemplates_SetTab(self, 0);
		self.TitleText:SetText(L["Export"]);
	
		self.Sidebar:Hide()
		for id,frame in ipairs(self.TabFrames) do
			frame:SetShown(false);
		end
		self.Export:Show()

		self.AddButton:Hide();
		self.ActivateButton:Hide();
		self.RefreshButton:Hide();
		self.ExportButton:Hide();
		self.DeleteButton:Hide();

		self.Export.Scroll.EditBox.text = value:gsub("|", "||")
		self.Export.Scroll.EditBox:SetText(value:gsub("|", "||"))
		self.Export.Scroll.EditBox:HighlightText()
		self.Export.Scroll.EditBox:SetFocus()
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
	function BtWLoadoutsFrameMixin:SetNPEShown(show, title, message)
		show = not not show
		
		self.AddButton:SetShown(not show)
		self.RefreshButton:SetShown(not show)
		self.ExportButton:SetShown(not show)
		self.ActivateButton:SetShown(not show)
		self.DeleteButton:SetShown(not show)

		self.NPE:SetShown(show)

		if show then
			self.NPE.Title:SetText(title)
			self.NPE.Message:SetText(message)
			self.NPE.AddButton.FlashAnim:Play()
		end

		return show
	end
end

BtWLoadoutsTalentButtonMixin = {};
function BtWLoadoutsTalentButtonMixin:OnLoad()
	self:RegisterForClicks("LeftButtonUp");
end
function BtWLoadoutsTalentButtonMixin:SetTalent(id, isPvP)
	self.id, self.isPvP = id, isPvP
end
function BtWLoadoutsTalentButtonMixin:Update()
	local id, isPvP = self.id, self.isPvP

	self:SetShown(id ~= nil)
	if not id then
		return
	end

	local grid = self:GetParent();
	local frame = grid:GetParent();
	local set = frame.set

	local func = isPvP and GetPvpTalentInfoByID or GetTalentInfoByID
	local _, name, texture = func(id)
	
	self.Name:SetText(name);
	self.Icon:SetTexture(texture);

	if set and set.talents[id] then
		self.KnownSelection:Show();
		self.Icon:SetDesaturated(false);
		self.Cover:Hide()
		self:SetEnabled(true)
	else
		self.KnownSelection:Hide();
		self.Icon:SetDesaturated(true);

		if grid:GetMaxSelections() == 1 then
			self.Cover:Hide()
			self:SetEnabled(true)
		else
			self.Cover:SetShown(grid:IsMaxSelections())
			self:SetEnabled(not grid:IsMaxSelections())
		end
	end
end
function BtWLoadoutsTalentButtonMixin:OnClick()
	local grid = self:GetParent();
	local frame = grid:GetParent();
	local selected = frame.set and frame.set.talents
	local talentID = self.id;

	if not selected then
		return
	end

	if selected[talentID] then
		selected[talentID] = nil;
	else
		if grid:GetMaxSelections() == 1 then
			for _,talentID in ipairs(grid.talents) do
				selected[talentID] = nil;
			end
		end

		selected[talentID] = true;
	end

	grid:Update()
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

local TALENT_ROW_HEIGHT = 51
BtWLoadoutsTalentSelectionMixin = {}
function BtWLoadoutsTalentSelectionMixin:OnLoad()
	self.talents = {}
	self.maxSelection = 1
	self.Buttons = {}

	self.BackgroundPool = CreateTexturePool(self, "BACKGROUND", 0, "BtWLoadoutsTalentRowBackgroundTemplate")
	self.SeparatorPool = CreateTexturePool(self, "BORDER", 0, "BtWLoadoutsTalentRowSeparatorTemplate")
	self.ButtonPool = CreateFramePool("BUTTON", self, "BtWLoadoutsTalentButtonTemplate")
end
function BtWLoadoutsTalentSelectionMixin:OnShow()
	self:Update()
end
function BtWLoadoutsTalentSelectionMixin:Update()
	local rows = math.ceil(#self.talents / 3)
	if self.BackgroundPool:GetNumActive() ~= rows then
		self.BackgroundPool:ReleaseAll()
		self.SeparatorPool:ReleaseAll()
		self.ButtonPool:ReleaseAll()

		table.wipe(self.Buttons)

		local index = 1
		local previous = nil
		for i=1,rows do
			local background = self.BackgroundPool:Acquire()
			background:SetPoint("TOPLEFT", 0, -51 * (i - 1))
			background:SetPoint("TOPRIGHT", 0, -51 * (i - 1))
			background:Show()

			do
				local separator = self.SeparatorPool:Acquire()
				separator:SetSize(34, 50)
				separator:SetTexCoord(0.5, 1, 0, 1)
				separator:SetPoint("LEFT", background, "LEFT", 0, 0)
				separator:Show()
			end

			do
				local separator = self.SeparatorPool:Acquire()
				separator:SetSize(34, 50)
				separator:SetTexCoord(0, 0.5, 0, 1)
				separator:SetPoint("RIGHT", background, "RIGHT", 0, 0)
				separator:Show()
			end

			do
				local separator = self.SeparatorPool:Acquire()
				separator:SetPoint("CENTER", background, "LEFT", 190, 0)
				separator:Show()
			end

			do
				local separator = self.SeparatorPool:Acquire()
				separator:SetPoint("CENTER", background, "RIGHT", -190, 0)
				separator:Show()
			end

			
			do
				local button = self.ButtonPool:Acquire()
				button:SetPoint("LEFT", background, "LEFT", 0, 0)
				button:SetID(index)

				self.Buttons[index] = button

				index = index + 1
			end

			do
				local button = self.ButtonPool:Acquire()
				button:SetPoint("LEFT", background, "LEFT", 190, 0)
				button:SetID(index)

				self.Buttons[index] = button

				index = index + 1
			end

			do
				local button = self.ButtonPool:Acquire()
				button:SetPoint("LEFT", background, "LEFT", 190 * 2, 0)
				button:SetID(index)

				self.Buttons[index] = button

				index = index + 1
			end
		end

		self:SetHeight(rows * TALENT_ROW_HEIGHT)
	end

	for index,button in ipairs(self.Buttons) do
		button:SetTalent(self.talents[index], self.isPvP)
		button:Update()
	end
end
function BtWLoadoutsTalentSelectionMixin:SetMaxSelections(value)
	self.maxSelection = value
	self:Update()
end
function BtWLoadoutsTalentSelectionMixin:GetMaxSelections()
	return self.maxSelection
end
function BtWLoadoutsTalentSelectionMixin:IsMaxSelections()
	local frame = self:GetParent()
	local selected = frame.set and frame.set.talents
	if not selected then
		return false
	end

	local count = 0
	for _,talentID in ipairs(self.talents) do
		if selected[talentID] then
			count = count + 1
			if count == self.maxSelection then
				return true
			end
		end
	end

	return false
end
function BtWLoadoutsTalentSelectionMixin:SetTalents(tbl, isPvP)
	self.talents, self.isPvP = tbl, (isPvP and true or false)
	self:Update()
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
local lastPass = false
function Internal.LogNewPass()
	if not lastPass then
		BtWLoadoutsLogFrame.Scroll.EditBox:Insert(string.format("[%.03f] %s\n", GetTime(), "--- NEW PASS ---"))
		lastPass = true
	end
end
function Internal.LogMessage(...)
	BtWLoadoutsLogFrame.Scroll.EditBox:Insert(string.format("[%.03f] %s\n", GetTime(), string.format(...):gsub("|", "||")))
	lastPass = false
end

-- [[ CUSTOM EVENT HANDLING ]]

local eventHandlers = {}
function Internal.OnEvent(event, callback)
	if not eventHandlers[event] then
		eventHandlers[event] = {}
	end

	eventHandlers[event][callback] = true
end
function Internal.Call(event, ...)
	local callbacks = eventHandlers[event]
	local result = true
	if callbacks then
		for callback in pairs(callbacks) do
			if callback(event, ...) == false then
				result = false
			end
		end
	end
	return result
end

-- [[ Slash Command ]]
-- /btwloadouts activate loadout Raid
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
				category = format("%s - %s", L["Loadout"], classColor:WrapTextInColorCode(specName))
			else
				category = L["Loadout"]
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
