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

local GetNextSetID = Internal.GetNextSetID;
local DeleteSet = Internal.DeleteSet;
local GetCharacterInfo = Internal.GetCharacterInfo;

local GetCursorItemSource;

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

local dungeonDifficultiesAll = Internal.dungeonDifficultiesAll;
local raidDifficultiesAll = Internal.raidDifficultiesAll;
local instanceDifficulties = Internal.instanceDifficulties;
local dungeonInfo = Internal.dungeonInfo;
local raidInfo = Internal.raidInfo;
local scenarioInfo = Internal.scenarioInfo;
local instanceBosses = Internal.instanceBosses;
local npcIDToBossID = Internal.npcIDToBossID;
local InstanceAreaIDToBossID = Internal.InstanceAreaIDToBossID;
local uiMapIDToBossID = Internal.uiMapIDToBossID;

local CONDITION_TYPE_WORLD = "none";
local CONDITION_TYPE_DUNGEONS = "party";
local CONDITION_TYPE_RAIDS = "raid";
local CONDITION_TYPE_ARENA = "arena";
local CONDITION_TYPE_BATTLEGROUND = "pvp";
local CONDITION_TYPE_SCENARIO = "scenario";
local CONDITION_TYPES = {
	CONDITION_TYPE_WORLD,
	CONDITION_TYPE_DUNGEONS,
	CONDITION_TYPE_RAIDS,
	CONDITION_TYPE_ARENA,
	CONDITION_TYPE_BATTLEGROUND,
	CONDITION_TYPE_SCENARIO
}
local CONDITION_TYPE_NAMES = {
	[CONDITION_TYPE_WORLD] = L["World"],
	[CONDITION_TYPE_DUNGEONS] = L["Dungeons"],
	[CONDITION_TYPE_RAIDS] = L["Raids"],
	[CONDITION_TYPE_ARENA] = L["Arena"],
	[CONDITION_TYPE_BATTLEGROUND] = L["Battlegrounds"],
	[CONDITION_TYPE_SCENARIO] = L["Scenarios"]
}
Internal.CONDITION_TYPES = CONDITION_TYPES;
Internal.CONDITION_TYPE_NAMES = CONDITION_TYPE_NAMES;

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
            BtWLoadoutsMinimapButton:SetShown(value);
        end,
        default = true,
    },
    {
        name = L["Limit condition suggestions"],
        key = "limitConditions",
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

local function RoleDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;

    if selectedTab == TAB_ESSENCES then
        local temp = tab.temp;
        -- @TODO: If we always access talents by set.talents then we can just swap tables in and out of
        -- the temp table instead of copying the talentIDs around

        -- We are going to copy the currently selected talents for the currently selected spec into
        -- a temporary table incase the user switches specs back
        local role = set.role;
        if temp[role] then
            wipe(temp[role]);
        else
            temp[role] = {};
        end
        for milestoneID, essenceID in pairs(set.essences) do
            temp[role][milestoneID] = essenceID;
        end

        -- Clear the current talents and copy back the previously selected talents if they exist
        role = arg1;
        set.role = role;
        wipe(set.essences);
        if temp[role] then
            for milestoneID, essenceID in pairs(temp[role]) do
                set.essences[milestoneID] = essenceID;
            end
        end
    end
    BtWLoadoutsFrame:Update();
end
local function RoleDropDownInit(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local selected = set and set.role;

    if (level or 1) == 1 then
        for _,role in Internal.Roles() do
            info.text = _G[role];
            info.arg1 = role;
            info.func = RoleDropDown_OnClick;
            info.checked = selected == role;
            UIDropDownMenu_AddButton(info, level);
        end
    end
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
	end
end

local function TalentsDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;
	local index = arg2 or (#set.talents + 1)

	if set.talents[index] then
		local subset = Internal.GetTalentSet(set.talents[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	if arg1 == nil then
		table.remove(set.talents, index);
	else
		set.talents[index] = arg1;
	end

	if set.talents[index] then
		local subset = Internal.GetTalentSet(set.talents[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

    BtWLoadoutsFrame:Update();
end
local function TalentsDropDown_NewOnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;
	local index = arg2 or (#set.talents + 1)

	if set.talents[index] then
		local subset = Internal.GetTalentSet(set.talents[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local talentSet = Internal.AddTalentSet();
	set.talents[index] = talentSet.setID;

	if set.talents[index] then
		local subset = Internal.GetTalentSet(set.talents[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame.Talents.set = talentSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, TAB_TALENTS);

	BtWLoadoutsHelpTipFlags["TUTORIAL_CREATE_TALENT_SET"] = true;
    BtWLoadoutsFrame:Update();
end
local function TalentsDropDownInit(self, level, menuList, index)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.talents then
        return;
	end
    local info = UIDropDownMenu_CreateInfo();

	local frame = BtWLoadoutsFrame -- self:GetParent():GetParent();
	local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
	local tab = GetTabFrame(frame, selectedTab);

	local set = tab.set;
	local selected = set and set.talents and set.talents[index];

	info.arg2 = index

	if (level or 1) == 1 then
        info.text = L["None"];
        info.func = TalentsDropDown_OnClick;
        info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

        wipe(setsFiltered);
        local sets = BtWLoadoutsSets.talents;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" then
				setsFiltered[subset.specID] = true;
			end
		end

		local className, classFile, classID = UnitClass("player");
		local classColor = C_ClassColor.GetClassColor(classFile);
		className = classColor and classColor:WrapTextInColorCode(className) or className;

		for specIndex=1,GetNumSpecializationsForClassID(classID) do
			local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
			if setsFiltered[specID] then
				info.text = format("%s: %s", className, specName);
				info.hasArrow, info.menuList = true, specID;
				info.keepShownOnClick = true;
				info.notCheckable = true;
				UIDropDownMenu_AddButton(info, level);
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
					if setsFiltered[specID] then
						info.text = format("%s: %s", className, specName);
						info.hasArrow, info.menuList = true, specID;
						info.keepShownOnClick = true;
						info.notCheckable = true;
						UIDropDownMenu_AddButton(info, level);
					end
				end
			end
        end

        info.text = L["New Set"];
        info.func = TalentsDropDown_NewOnClick;
		info.hasArrow, info.menuList = false, nil;
		info.keepShownOnClick = false;
		info.notCheckable = true;
        info.checked = false;
		UIDropDownMenu_AddButton(info, level);
	else
		local specID = menuList;

        wipe(setsFiltered);
        local sets = BtWLoadoutsSets.talents;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" and subset.specID == specID then
				setsFiltered[#setsFiltered+1] = setID;
			end
		end
        sort(setsFiltered, function (a,b)
            return sets[a].name < sets[b].name;
		end)

        for _,setID in ipairs(setsFiltered) do
            info.text = sets[setID].name;
			info.arg1 = setID;
            info.func = TalentsDropDown_OnClick;
            info.checked = selected == setID;
            UIDropDownMenu_AddButton(info, level);
        end
    end
end

local function PvPTalentsDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;
	local index = arg2 or (#set.pvptalents + 1)

	if set.pvptalents[index] then
		local subset = Internal.GetPvPTalentSet(set.pvptalents[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	if arg1 == nil then
		table.remove(set.pvptalents, index);
	else
		set.pvptalents[index] = arg1;
	end

	if set.pvptalents[index] then
		local subset = Internal.GetPvPTalentSet(set.pvptalents[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

    BtWLoadoutsFrame:Update();
end
local function PvPTalentsDropDown_NewOnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;
	local index = arg2 or (#set.pvptalents + 1)

	if set.pvptalents[index] then
		local subset = Internal.GetPvPTalentSet(set.pvptalents[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local newSet = Internal.AddPvPTalentSet();
	set.pvptalents[index] = newSet.setID;

	if set.pvptalents[index] then
		local subset = Internal.GetPvPTalentSet(set.pvptalents[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame.PvPTalents.set = newSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, TAB_PVP_TALENTS);

    BtWLoadoutsFrame:Update();
end
local function PvPTalentsDropDownInit(self, level, menuList, index)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.pvptalents then
        return;
	end

    local info = UIDropDownMenu_CreateInfo();

	local frame = BtWLoadoutsFrame -- self:GetParent():GetParent();
	local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
	local tab = GetTabFrame(frame, selectedTab);

	local set = tab.set;
	local selected = set and set.pvptalents and set.pvptalents[index];

	info.arg2 = index

    if (level or 1) == 1 then
        info.text = NONE;
        info.func = PvPTalentsDropDown_OnClick;
        info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

        wipe(setsFiltered);
        local sets = BtWLoadoutsSets.pvptalents;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" then
				setsFiltered[subset.specID] = true;
			end
        end

		local className, classFile, classID = UnitClass("player");
		local classColor = C_ClassColor.GetClassColor(classFile);
		className = classColor and classColor:WrapTextInColorCode(className) or className;

		for specIndex=1,GetNumSpecializationsForClassID(classID) do
			local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
			if setsFiltered[specID] then
				info.text = format("%s: %s", className, specName);
				info.hasArrow, info.menuList = true, specID;
				info.keepShownOnClick = true;
				info.notCheckable = true;
				UIDropDownMenu_AddButton(info, level);
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
					if setsFiltered[specID] then
						info.text = format("%s: %s", className, specName);
						info.hasArrow, info.menuList = true, specID;
						info.keepShownOnClick = true;
						info.notCheckable = true;
						UIDropDownMenu_AddButton(info, level);
					end
				end
			end
		end

        info.text = L["New Set"];
        info.func = PvPTalentsDropDown_NewOnClick;
		info.hasArrow, info.menuList = false, nil;
		info.keepShownOnClick = false;
		info.notCheckable = true;
        info.checked = false;
		UIDropDownMenu_AddButton(info, level);
	else
		local specID = menuList;

        wipe(setsFiltered);
        local sets = BtWLoadoutsSets.pvptalents;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" and subset.specID == specID then
				setsFiltered[#setsFiltered+1] = setID;
			end
		end
        sort(setsFiltered, function (a,b)
            return sets[a].name < sets[b].name;
		end)

        for _,setID in ipairs(setsFiltered) do
            info.text = sets[setID].name;
            info.arg1 = setID;
            info.func = PvPTalentsDropDown_OnClick;
            info.checked = selected == setID;
            UIDropDownMenu_AddButton(info, level);
        end
    end
end

local function EssencesDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;
	local index = arg2 or (#set.essences + 1)

	if set.essences[index] then
		local subset = Internal.GetEssenceSet(set.essences[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	if arg1 == nil then
		table.remove(set.essences, index);
	else
		set.essences[index] = arg1;
	end

	if set.essences[index] then
		local subset = Internal.GetEssenceSet(set.essences[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

    BtWLoadoutsFrame:Update();
end
local function EssencesDropDown_NewOnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;
	local index = arg2 or (#set.essences + 1)

	if set.essences[index] then
		local subset = Internal.GetEssenceSet(set.essences[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local newSet = Internal.AddEssenceSet();
	set.essences[index] = newSet.setID;

	if set.essences[index] then
		local subset = Internal.GetEssenceSet(set.essences[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end


	BtWLoadoutsFrame.Essences.set = newSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, TAB_ESSENCES);

    BtWLoadoutsFrame:Update();
end
local function EssencesDropDownInit(self, level, menuList, index)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.essences then
        return;
    end

    local info = UIDropDownMenu_CreateInfo();

	local frame = BtWLoadoutsFrame -- self:GetParent():GetParent();
	local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
	local tab = GetTabFrame(frame, selectedTab);

	local set = tab.set;
	local selected = set and set.essences and set.essences[index];

	info.arg2 = index

    if (level or 1) == 1 then
        info.text = NONE;
        info.func = EssencesDropDown_OnClick;
        info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

        wipe(setsFiltered);
        local sets = BtWLoadoutsSets.essences;
        for setID,subset in pairs(sets) do
			if type(subset) == "table" then
				setsFiltered[subset.role] = true;
			end
		end

		local role = select(5, GetSpecializationInfo(GetSpecialization()));
		if setsFiltered[role] then
			info.text = _G[role];
			info.hasArrow, info.menuList = true, role;
			info.keepShownOnClick = true;
			info.notCheckable = true;
			UIDropDownMenu_AddButton(info, level);
		end

		local playerRole = role;
		for _,role in Internal.Roles() do
			if role ~= playerRole then
				if setsFiltered[role] then
					info.text = _G[role];
					info.hasArrow, info.menuList = true, role;
					info.keepShownOnClick = true;
					info.notCheckable = true;
					UIDropDownMenu_AddButton(info, level);
				end
			end
        end

        info.text = L["New Set"];
        info.func = EssencesDropDown_NewOnClick;
		info.hasArrow, info.menuList = false, nil;
		info.keepShownOnClick = false;
		info.notCheckable = true;
        info.checked = false;
		UIDropDownMenu_AddButton(info, level);
	else
		local role = menuList;

        wipe(setsFiltered);
        local sets = BtWLoadoutsSets.essences;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" and subset.role == role then
				setsFiltered[#setsFiltered+1] = setID;
			end
		end
        sort(setsFiltered, function (a,b)
            return sets[a].name < sets[b].name;
		end)

        for _,setID in ipairs(setsFiltered) do
            info.text = sets[setID].name;
            info.arg1 = setID;
            info.func = EssencesDropDown_OnClick;
            info.checked = selected == setID;
            UIDropDownMenu_AddButton(info, level);
		end
    end
end

local function EquipmentDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

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
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

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

	local frame = BtWLoadoutsFrame -- self:GetParent():GetParent();
	local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
	local tab = GetTabFrame(frame, selectedTab);

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

		local name, realm = UnitFullName("player");
		local character = realm .. "-" .. name;
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
            info.text = sets[setID].name;
            info.arg1 = setID;
            info.func = EquipmentDropDown_OnClick;
            info.checked = selected == setID;
            UIDropDownMenu_AddButton(info, level);
		end
    end
end

local function ActionBarDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;
	local index = arg2 or (#set.actionbars + 1)

	if set.actionbars[index] then
		local subset = Internal.GetActionBarSet(set.actionbars[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	if arg1 == nil then
		table.remove(set.actionbars, index);
	else
		set.actionbars[index] = arg1;
	end

	if set.actionbars[index] then
		local subset = Internal.GetActionBarSet(set.actionbars[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

    BtWLoadoutsFrame:Update();
end
local function ActionBarDropDown_NewOnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;
	local index = arg2 or (#set.actionbars + 1)

	if set.actionbars[index] then
		local subset = Internal.GetActionBarSet(set.actionbars[index]);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local newSet = Internal.AddActionBarSet();
	set.actionbars[index] = newSet.setID;

	if set.actionbars[index] then
		local subset = Internal.GetActionBarSet(set.actionbars[index]);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame.ActionBars.set = newSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, TAB_ACTION_BARS);

    BtWLoadoutsFrame:Update();
end
local function ActionBarDropDownInit(self, level, menuList, index)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.actionbars then
        return;
    end

    local info = UIDropDownMenu_CreateInfo();

	local frame = BtWLoadoutsFrame -- self:GetParent():GetParent();
	local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
	local tab = GetTabFrame(frame, selectedTab);

	local set = tab.set;
	local selected = set and set.actionbars and set.actionbars[index];

	info.arg2 = index
	
    if (level or 1) == 1 then
        info.text = NONE;
        info.func = ActionBarDropDown_OnClick;
        info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

        wipe(setsFiltered);
        local sets = BtWLoadoutsSets.actionbars;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" then
				setsFiltered[#setsFiltered+1] = setID;
			end
		end
        sort(setsFiltered, function (a,b)
            return sets[a].name < sets[b].name;
		end)

        for _,setID in ipairs(setsFiltered) do
            info.text = sets[setID].name;
            info.arg1 = setID;
            info.func = ActionBarDropDown_OnClick;
            info.checked = selected == setID;
            UIDropDownMenu_AddButton(info, level);
		end

        info.text = L["New Set"];
        info.func = ActionBarDropDown_NewOnClick;
		info.hasArrow, info.menuList = false, nil;
		info.keepShownOnClick = false;
		info.notCheckable = true;
        info.checked = false;
		UIDropDownMenu_AddButton(info, level);
    end
end

local function ProfilesDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;

	if set.profileSet then
		local subset = Internal.GetProfile(set.profileSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	set.profileSet = arg1;

	if set.profileSet then
		local subset = Internal.GetProfile(set.profileSet);
		subset.useCount = (subset.useCount or 0) + 1;
	end

    BtWLoadoutsFrame:Update();
end
local function ProfilesDropDown_NewOnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;

	if set.profileSet then
		local subset = Internal.GetProfile(set.profileSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local newSet = Internal.AddProfile();
	set.profileSet = newSet.setID;

	if set.profileSet then
		local subset = Internal.GetProfile(set.profileSet);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame.Profiles.set = newSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, TAB_PROFILES);

    BtWLoadoutsFrame:Update();
end
local function ProfilesDropDownInit(self, level, menuList)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.profiles then
        return;
    end

    local info = UIDropDownMenu_CreateInfo();

	local frame = BtWLoadoutsFrame -- self:GetParent():GetParent();
	local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
	local tab = GetTabFrame(frame, selectedTab);

	local set = tab.set;
	local selected = set and set.profileSet;

    if (level or 1) == 1 then
        info.text = NONE;
        info.func = ProfilesDropDown_OnClick;
        info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

        wipe(setsFiltered);
        local sets = BtWLoadoutsSets.profiles;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" then
				setsFiltered[subset.specID or 0] = true;
			end
        end

		local className, classFile, classID = UnitClass("player");
		local classColor = C_ClassColor.GetClassColor(classFile);
		className = classColor and classColor:WrapTextInColorCode(className) or className;

		for specIndex=1,GetNumSpecializationsForClassID(classID) do
			local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
			if setsFiltered[specID] then
				info.text = format("%s: %s", className, specName);
				info.hasArrow, info.menuList = true, specID;
				info.keepShownOnClick = true;
				info.notCheckable = true;
				UIDropDownMenu_AddButton(info, level);
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
					if setsFiltered[specID] then
						info.text = format("%s: %s", className, specName);
						info.hasArrow, info.menuList = true, specID;
						info.keepShownOnClick = true;
						info.notCheckable = true;
						UIDropDownMenu_AddButton(info, level);
					end
				end
			end
		end

		local specID = 0;
		if setsFiltered[specID] then
			info.text = L["Other"];
			info.hasArrow, info.menuList = true, nil;
			info.keepShownOnClick = true;
			info.notCheckable = true;
			UIDropDownMenu_AddButton(info, level);
		end

        info.text = L["New Set"];
        info.func = ProfilesDropDown_NewOnClick;
		info.hasArrow, info.menuList = false, nil;
		info.keepShownOnClick = false;
		info.notCheckable = true;
        info.checked = false;
		UIDropDownMenu_AddButton(info, level);
	else
		local specID = menuList;

        wipe(setsFiltered);
        local sets = BtWLoadoutsSets.profiles;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" and subset.specID == specID then
				setsFiltered[#setsFiltered+1] = setID;
			end
		end
        sort(setsFiltered, function (a,b)
            return sets[a].name < sets[b].name;
		end)

        for _,setID in ipairs(setsFiltered) do
            info.text = sets[setID].name;
            info.arg1 = setID;
            info.func = ProfilesDropDown_OnClick;
            info.checked = selected == setID;
            UIDropDownMenu_AddButton(info, level);
        end
    end
end

local function ConditionTypeDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;

	set.type = arg1;
	set.instanceID = nil;
	set.difficultyID = nil;
	set.bossID = nil;
	set.affixesID = nil;

    BtWLoadoutsFrame:Update();
end
local function ConditionTypeDropDownInit(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local selected = set and set.type;

	if (level or 1) == 1 then
		for _,conditionType in ipairs(Internal.CONDITION_TYPES) do
			info.text = Internal.CONDITION_TYPE_NAMES[conditionType];
			info.arg1 = conditionType;
			info.func = ConditionTypeDropDown_OnClick;
			info.checked = selected == conditionType;
			UIDropDownMenu_AddButton(info, level);
		end
    end
end


local function InstanceDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;

	set.instanceID = arg1;
	set.bossID = nil;
	if set.difficultyID ~= nil then
		local supportsDifficulty = (set.instanceID == nil);
		if not supportsDifficulty then
			for _,difficultyID in ipairs(instanceDifficulties[set.instanceID]) do
				if difficultyID == set.difficultyID then
					supportsDifficulty = true;
					break;
				end
			end
		end

		if not supportsDifficulty then
			set.difficultyID = nil;
		end

		if set.difficultyID ~= 8 then
			set.affixesID = nil;
		end
	else
		set.affixesID = nil;
	end

    BtWLoadoutsFrame:Update();
end
local function InstanceDropDownInit(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local dungeonType = set and set.type;
	local selected = set and set.instanceID;

	if dungeonType == CONDITION_TYPE_DUNGEONS then
		if (level or 1) == 1 then
			info.text = L["Any"];
			info.func = InstanceDropDown_OnClick;
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);

		-- 	for expansion,expansionData in ipairs(dungeonInfo) do
		-- 		info.text = expansionData.name;
		-- 		info.hasArrow, info.menuList = true, expansion;
		-- 		info.keepShownOnClick = true;
		-- 		info.notCheckable = true;
		-- 		UIDropDownMenu_AddButton(info, level);
		-- 	end
		-- else
			local expansion = 8;
			for _,instanceID in ipairs(dungeonInfo[expansion].instances) do
				info.text = GetRealZoneText(instanceID);
				info.arg1 = instanceID;
				info.func = InstanceDropDown_OnClick;
				info.checked = selected == instanceID;
				UIDropDownMenu_AddButton(info, level);
			end
		end
	elseif dungeonType == CONDITION_TYPE_RAIDS then
		if (level or 1) == 1 then
			info.text = L["Any"];
			info.func = InstanceDropDown_OnClick;
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);

		-- 	for expansion,expansionData in ipairs(dungeonInfo) do
		-- 		info.text = expansionData.name;
		-- 		info.hasArrow, info.menuList = true, expansion;
		-- 		info.keepShownOnClick = true;
		-- 		info.notCheckable = true;
		-- 		UIDropDownMenu_AddButton(info, level);
		-- 	end
		-- else
			local expansion = 8;
			for _,instanceID in ipairs(raidInfo[expansion].instances) do
				info.text = GetRealZoneText(instanceID);
				info.arg1 = instanceID;
				info.func = InstanceDropDown_OnClick;
				info.checked = selected == instanceID;
				UIDropDownMenu_AddButton(info, level);
			end
		end
	end
end


local function DifficultyDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;

	set.difficultyID = arg1;
	if arg1 == 8 then
		set.bossID = nil;
	else
		set.affixesID = nil;
	end

    BtWLoadoutsFrame:Update();
end
local function DifficultyDropDownInit(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local conditionType = set and set.type;
	local instanceID = set and set.instanceID;
	local selected = set and set.difficultyID;

	if instanceID == nil then
		if conditionType == CONDITION_TYPE_DUNGEONS then
			info.text = L["Any"];
			info.func = DifficultyDropDown_OnClick;
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);

			for _,difficultyID in ipairs(Internal.dungeonDifficultiesAll) do
				info.text = GetDifficultyInfo(difficultyID);
				info.arg1 = difficultyID;
				info.func = DifficultyDropDown_OnClick;
				info.checked = selected == difficultyID;
				UIDropDownMenu_AddButton(info, level);
			end
		elseif conditionType == CONDITION_TYPE_RAIDS then
			info.text = L["Any"];
			info.func = DifficultyDropDown_OnClick;
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);

			for _,difficultyID in ipairs(Internal.raidDifficultiesAll) do
				info.text = GetDifficultyInfo(difficultyID);
				info.arg1 = difficultyID;
				info.func = DifficultyDropDown_OnClick;
				info.checked = selected == difficultyID;
				UIDropDownMenu_AddButton(info, level);
			end
		end
	else
		if (level or 1) == 1 then
			info.text = L["Any"];
			info.func = DifficultyDropDown_OnClick;
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);

			for _,difficultyID in ipairs(instanceDifficulties[instanceID]) do
				info.text = GetDifficultyInfo(difficultyID);
				info.arg1 = difficultyID;
				info.func = DifficultyDropDown_OnClick;
				info.checked = selected == difficultyID;
				UIDropDownMenu_AddButton(info, level);
			end
		end
	end
end


local function BossDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;

	set.bossID = arg1;

    BtWLoadoutsFrame:Update();
end
local function BossDropDownInit(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local instanceID = set and set.instanceID;
	local selected = set and set.bossID;

	if (level or 1) == 1 then
		info.text = L["Any"];
		info.func = BossDropDown_OnClick;
		info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

		if instanceBosses[instanceID] then
			for _,bossID in ipairs(instanceBosses[instanceID]) do
				info.text = EJ_GetEncounterInfo(bossID);
				info.arg1 = bossID;
				info.func = BossDropDown_OnClick;
				info.checked = selected == bossID;
				UIDropDownMenu_AddButton(info, level);
			end
		end
	end
end

local function AffixesDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;

	set.affixesID = arg1;

    BtWLoadoutsFrame:Update();
end
local function AffixesDropDownInit(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local selected = set and set.affixesID;

	if (level or 1) == 1 then
		info.text = L["Any"];
		info.func = AffixesDropDown_OnClick;
		info.checked = selected == nil;
		UIDropDownMenu_AddButton(info, level);

		for _,affixes in Internal.AffixRotation() do
			info.text = affixes.fullName;
			info.arg1 = affixes.id;
			info.func = AffixesDropDown_OnClick;
			info.checked = selected == affixes.id;
			UIDropDownMenu_AddButton(info, level);
		end
	end
end

local function ScenarioDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;

    set.instanceID = arg1;
    set.difficultyID = arg2;

    BtWLoadoutsFrame:Update();
end

local function ScenarioDropDownInit(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local instanceID = set and set.instanceID;
	local difficultyID = set and set.difficultyID;

	if (level or 1) == 1 then
		info.text = L["Any"];
		info.func = ScenarioDropDown_OnClick;
		info.checked = (instanceID == nil) and (difficultyID == nil);
		UIDropDownMenu_AddButton(info, level);

	-- 	for expansion,expansionData in ipairs(dungeonInfo) do
	-- 		info.text = expansionData.name;
	-- 		info.hasArrow, info.menuList = true, expansion;
	-- 		info.keepShownOnClick = true;
	-- 		info.notCheckable = true;
	-- 		UIDropDownMenu_AddButton(info, level);
	-- 	end
	-- else
		local expansion = 8;
		for _,details in ipairs(scenarioInfo[expansion].instances) do
			info.text = details[3];
			info.arg1 = details[1];
			info.arg2 = details[2];
			info.func = ScenarioDropDown_OnClick;
			info.checked = (instanceID == details[1]) and (difficultyID == details[2]);
			UIDropDownMenu_AddButton(info, level);
		end
	end
end

local function AffixDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;

	if set.affixesID ~= nil and bit.band(set.affixesID, arg2) == arg2 then
		set.affixesID = bit.band(set.affixesID, arg1);
	else
		set.affixesID = bit.bor(bit.band(set.affixesID or 0, arg1), arg2);
	end
	if set.affixesID == 0 then
		set.affixesID = nil
	end

    BtWLoadoutsFrame:Update();
end

do
	BtWLoadoutsConditionsAffixesMixin = {}
	function BtWLoadoutsConditionsAffixesMixin:OnLoad()
		self.Buttons = {}
		for index,level in Internal.AffixesLevels() do
			local x = ((index - 1) * 90) + 20
			local y = -17
			local relativeTo
			for _,affix in Internal.Affixes(level) do
				local name = self:GetName() .. "Button" .. affix
				local button = CreateFrame("Button", name, self, "BtWLoadoutsConditionsAffixesDropDownButton", affix);
				button:SetWidth(85);
				if relativeTo then
					button:SetPoint("TOP", relativeTo, "BOTTOM", 0, -5);
				else
					button:SetPoint("TOPLEFT", x, y);
				end

				local fullname, icons, mask = select(2, Internal.GetAffixesName(affix));
				_G[name .. "NormalText"]:SetText(icons);
				button.mask = mask;

				button.keepShownOnClick = true
				button.notCheckable = true
				button.arg1 = bit.bxor(0xffffffff, bit.lshift(0xff, 8*(index-1)))
				button.arg2 = bit.lshift(affix, 8*(index-1))
				button.func = AffixDropDown_OnClick

				self.Buttons[#self.Buttons+1] = button
				
				button:Show();
				relativeTo = button;
			end
		end
		hooksecurefunc("CloseDropDownMenus", function ()
			if not MouseIsOver(self) then
				self:Hide();
			end
		end)
	end
	-- Changes the buttons based on mask
	function BtWLoadoutsConditionsAffixesMixin:Update(affixesID)
		local a, b, c, d = Internal.GetAffixesForID(affixesID)
		local mask = Internal.GetExclusiveAffixes(affixesID)
		for _,button in ipairs(self.Buttons) do
			button:SetEnabled(bit.band(button.mask, mask) == button.mask);
			local affixID = button:GetID()
			button.Selection:SetShown(affixID == a or affixID == b or affixID == c or affixID == d);
		end
	end
end

do
	BtWLoadoutsSetsScrollListItemMixin = {}
	function BtWLoadoutsSetsScrollListItemMixin:OnLoad()
		self:RegisterForDrag("LeftButton");
	end
	function BtWLoadoutsSetsScrollListItemMixin:OnClick()
		if self.isHeader then
			local frame = self:GetParent():GetParent():GetParent()
			frame.Collapsed[self.type] = not frame.Collapsed[self.type]
			Internal.ProfilesTabUpdate(frame)
		elseif self.isAdd then
			self:Add(self)
		else
			local DropDown = self:GetParent():GetParent().DropDown
			local index = self.index

			if self.type == "talents" then
				UIDropDownMenu_SetInitializeFunction(DropDown, function (self, level, menuList)
					return TalentsDropDownInit(self, level, menuList, index)
				end)
			elseif self.type == "pvptalents" then
			elseif self.type == "essences" then
				UIDropDownMenu_SetInitializeFunction(DropDown, function (self, level, menuList)
					return EssencesDropDownInit(self, level, menuList, index)
				end)
			elseif self.type == "equipment" then
				UIDropDownMenu_SetInitializeFunction(DropDown, function (self, level, menuList)
					return EquipmentDropDownInit(self, level, menuList, index)
				end)
			elseif self.type == "actionbars" then
				UIDropDownMenu_SetInitializeFunction(DropDown, function (self, level, menuList)
					return ActionBarDropDownInit(self, level, menuList, index)
				end)
			end
	
			ToggleDropDownMenu(nil, nil, DropDown, self, 0, 0)
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end
	end
	function BtWLoadoutsSetsScrollListItemMixin:OnEnter()
		if self.error then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.name, 1, 1, 1)
			GameTooltip:AddLine(format("\n|cffff0000%s|r", self.error))
			GameTooltip:Show()
		end
	end
	function BtWLoadoutsSetsScrollListItemMixin:OnLeave()
		GameTooltip:Hide()
	end
	function BtWLoadoutsSetsScrollListItemMixin:Add(button)
		local DropDown = self:GetParent():GetParent().DropDown
		
		if self.type == "talents" then
			UIDropDownMenu_SetInitializeFunction(DropDown, TalentsDropDownInit)
		elseif self.type == "pvptalents" then
			UIDropDownMenu_SetInitializeFunction(DropDown, PvPTalentsDropDownInit)
		elseif self.type == "essences" then
			UIDropDownMenu_SetInitializeFunction(DropDown, EssencesDropDownInit)
		elseif self.type == "equipment" then
			UIDropDownMenu_SetInitializeFunction(DropDown, EquipmentDropDownInit)
		elseif self.type == "actionbars" then
			UIDropDownMenu_SetInitializeFunction(DropDown, ActionBarDropDownInit)
		end

		ToggleDropDownMenu(nil, nil, DropDown, button, 0, 0)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
	function BtWLoadoutsSetsScrollListItemMixin:Remove()
		local tab = self:GetParent():GetParent():GetParent()
		local set = tab.set

		local index = self.index
		assert(type(set[self.type]) == "table" and index ~= nil and index >= 1 and index <= #set[self.type])
		table.remove(set[self.type], index);

		Internal.ProfilesTabUpdate(tab)
	end
	function BtWLoadoutsSetsScrollListItemMixin:MoveUp()
		local tab = self:GetParent():GetParent():GetParent()
		local set = tab.set

		local index = self.index
		assert(type(set[self.type]) == "table" and index > 1 and index <= #set[self.type])
		set[self.type][index-1], set[self.type][index] = set[self.type][index], set[self.type][index-1]

		Internal.ProfilesTabUpdate(tab)
	end
	function BtWLoadoutsSetsScrollListItemMixin:MoveDown()
		local tab = self:GetParent():GetParent():GetParent()
		local set = tab.set

		local index = self.index
		assert(type(set[self.type]) == "table" and index >= 1 and index < #set[self.type])
		set[self.type][index+1], set[self.type][index] = set[self.type][index], set[self.type][index+1]

		Internal.ProfilesTabUpdate(tab)
	end
end

local SetsScrollFrame_Update
do
	local NUM_SCROLL_ITEMS_TO_DISPLAY = 18;
	local SCROLL_ROW_HEIGHT = 21;
	local setScrollItems = {};
	function SetsScrollFrame_Update()
		local self = BtWLoadoutsFrame.Scroll
		local buttons = self.buttons;
		local items = setScrollItems;
		if not buttons then
			return
		end

		local totalHeight, displayedHeight = #items * (buttons[1]:GetHeight() + 1), self:GetHeight()
		local hasScrollBar = totalHeight > displayedHeight

		local offset = HybridScrollFrame_GetOffset(self);
		for i,button in ipairs(buttons) do
			button:SetWidth(hasScrollBar and 200 or 223)

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

					button.SelectedBar:Hide();

					if item.isCollapsed then
						button.ExpandedIcon:Hide();
						button.CollapsedIcon:Show();
					else
						button.ExpandedIcon:Show();
						button.CollapsedIcon:Hide();
					end
					button.BuiltinIcon:Hide();
				else
					if not item.isAdd then
						button.id = item.id;

						button.SelectedBar:SetShown(item.selected);
						button.BuiltinIcon:SetShown(item.builtin);
					end

					button.ExpandedIcon:Hide();
					button.CollapsedIcon:Hide();
				end

				local name;
				if item.character then
					local characterInfo = GetCharacterInfo(item.character);
					if characterInfo then
						name = format("%s |cFFD5D5D5(%s - %s)|r", item.name, characterInfo.name, characterInfo.realm);
					else
						name = format("%s |cFFD5D5D5(%s)|r", item.name, item.character);
					end
				else
					name = item.name;
				end
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

		local name, realm = UnitFullName("player");
		local character = realm .. "-" .. name;
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

		self.Talents.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them

		self.PvPTalents.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them

		self.Essences.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
		self.Essences.pending = nil;

		PanelTemplates_SetNumTabs(self, NUM_TABS);
		PanelTemplates_SetTab(self, TAB_PROFILES);

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
				BtWLoadoutsCollapsed.profiles[button.id] = not BtWLoadoutsCollapsed.profiles[button.id] and true or nil;
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
			HybridScrollFrame_CreateButtons(self.Scroll, "BtWLoadoutsScrollListItem", 0, 0, "TOPLEFT", "TOPLEFT", 0, -1, "TOP", "BOTTOM");
			self.Scroll.update = SetsScrollFrame_Update;

			self.Profiles.SpecDropDown.includeNone = true;
			UIDropDownMenu_SetWidth(self.Profiles.SpecDropDown, 300);
			UIDropDownMenu_Initialize(self.Profiles.SpecDropDown, SpecDropDownInit);
			UIDropDownMenu_JustifyText(self.Profiles.SpecDropDown, "LEFT");

			HybridScrollFrame_CreateButtons(self.Profiles.SetsScroll, "BtWLoadoutsSetsScrollListItemTemplate", 4, -3, "TOPLEFT", "TOPLEFT", 0, -1, "TOP", "BOTTOM");
			self.Profiles.SetsScroll.update = Internal.SetsScrollFrameUpdate;

			UIDropDownMenu_SetWidth(self.Talents.SpecDropDown, 170);
			UIDropDownMenu_Initialize(self.Talents.SpecDropDown, SpecDropDownInit);
			UIDropDownMenu_JustifyText(self.Talents.SpecDropDown, "LEFT");


			UIDropDownMenu_SetWidth(self.PvPTalents.SpecDropDown, 170);
			UIDropDownMenu_Initialize(self.PvPTalents.SpecDropDown, SpecDropDownInit);
			UIDropDownMenu_JustifyText(self.PvPTalents.SpecDropDown, "LEFT");


			UIDropDownMenu_SetWidth(self.Essences.RoleDropDown, 170);
			UIDropDownMenu_Initialize(self.Essences.RoleDropDown, RoleDropDownInit);
			UIDropDownMenu_JustifyText(self.Essences.RoleDropDown, "LEFT");
			self.Essences.Slots = {
				[115] = self.Essences.MajorSlot,
				[116] = self.Essences.MinorSlot1,
				[117] = self.Essences.MinorSlot2,
				[119] = self.Essences.MinorSlot3,
			};

			HybridScrollFrame_CreateButtons(self.Essences.EssenceList, "BtWLoadoutsAzeriteEssenceButtonTemplate", 4, -3, "TOPLEFT", "TOPLEFT", 0, -1, "TOP", "BOTTOM");
			self.Essences.EssenceList.update = Internal.EssenceScrollFrameUpdate;

			self.Equipment.flyoutSettings = {
				onClickFunc = PaperDollFrameItemFlyoutButton_OnClick,
				getItemsFunc = PaperDollFrameItemFlyout_GetItems,
				-- postGetItemsFunc = PaperDollFrameItemFlyout_PostGetItems,
				hasPopouts = true,
				parent = self.Equipment,
				anchorX = 0,
				anchorY = -3,
				verticalAnchorX = 0,
				verticalAnchorY = 0,
			};

			UIDropDownMenu_SetWidth(self.Conditions.ProfileDropDown, 400);
			UIDropDownMenu_Initialize(self.Conditions.ProfileDropDown, ProfilesDropDownInit);
			UIDropDownMenu_JustifyText(self.Conditions.ProfileDropDown, "LEFT");

			UIDropDownMenu_SetWidth(self.Conditions.ConditionTypeDropDown, 400);
			UIDropDownMenu_Initialize(self.Conditions.ConditionTypeDropDown, ConditionTypeDropDownInit);
			UIDropDownMenu_JustifyText(self.Conditions.ConditionTypeDropDown, "LEFT");

			UIDropDownMenu_SetWidth(self.Conditions.InstanceDropDown, 175);
			UIDropDownMenu_Initialize(self.Conditions.InstanceDropDown, InstanceDropDownInit);
			UIDropDownMenu_JustifyText(self.Conditions.InstanceDropDown, "LEFT");

			UIDropDownMenu_SetWidth(self.Conditions.DifficultyDropDown, 175);
			UIDropDownMenu_Initialize(self.Conditions.DifficultyDropDown, DifficultyDropDownInit);
			UIDropDownMenu_JustifyText(self.Conditions.DifficultyDropDown, "LEFT");

			UIDropDownMenu_SetWidth(self.Conditions.BossDropDown, 400);
			UIDropDownMenu_Initialize(self.Conditions.BossDropDown, BossDropDownInit);
			UIDropDownMenu_JustifyText(self.Conditions.BossDropDown, "LEFT");

			UIDropDownMenu_SetWidth(self.Conditions.AffixesDropDown, 400);
			-- UIDropDownMenu_Initialize(self.Conditions.AffixesDropDown, AffixesDropDownInit);
			UIDropDownMenu_JustifyText(self.Conditions.AffixesDropDown, "LEFT");

			self.Conditions.AffixesDropDown.Button:SetScript("OnClick", function ()
				BtWLoadoutsConditionsAffixesDropDownList:SetShown(not BtWLoadoutsConditionsAffixesDropDownList:IsShown());
			end)

			UIDropDownMenu_SetWidth(self.Conditions.ScenarioDropDown, 400);
			UIDropDownMenu_Initialize(self.Conditions.ScenarioDropDown, ScenarioDropDownInit);
			UIDropDownMenu_JustifyText(self.Conditions.ScenarioDropDown, "LEFT");
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

BtWLoadoutsAzeriteMilestoneSlotMixin = {};
function BtWLoadoutsAzeriteMilestoneSlotMixin:OnLoad()
	self.EmptyGlow.Anim:Play();
end
function BtWLoadoutsAzeriteMilestoneSlotMixin:OnEnter()
	if self.id then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetAzeriteEssence(self.id, 4);
		GameTooltip_SetBackdropStyle(GameTooltip, GAME_TOOLTIP_BACKDROP_STYLE_AZERITE_ITEM);
	end

	if self:GetParent().pending then
		SetCursor("interface/cursor/cast.blp");
	end
end
function BtWLoadoutsAzeriteMilestoneSlotMixin:OnLeave()
	GameTooltip_Hide();
end
function BtWLoadoutsAzeriteMilestoneSlotMixin:OnClick()
	local essences = self:GetParent();
	local selected = essences.set.essences;
	local pendingEssenceID = essences.pending;
	if pendingEssenceID then
		for milestoneID,essenceID in pairs(selected) do
			if essenceID == pendingEssenceID then
				selected[milestoneID] = nil;
			end
		end

		selected[self.milestoneID] = pendingEssenceID;

		essences.pending = nil;
		SetCursor(nil);
	else
		selected[self.milestoneID] = nil;
	end

	BtWLoadoutsFrame:Update();
end

BtWLoadoutsAzeriteEssenceButtonMixin = {};
function BtWLoadoutsAzeriteEssenceButtonMixin:OnClick()
	SetCursor("interface/cursor/cast.blp");
	BtWLoadoutsFrame.Essences.pending = self.id;
	BtWLoadoutsFrame:Update();
end
function BtWLoadoutsAzeriteEssenceButtonMixin:OnEnter()
	if self.id then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetAzeriteEssence(self.id, 4);
	end

	if BtWLoadoutsFrame.Essences.pending then
		SetCursor("interface/cursor/cast.blp");
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

BtWLoadoutsActionButtonMixin = {}
function BtWLoadoutsActionButtonMixin:OnClick()
	local cursorType = GetCursorInfo()
	if cursorType then
		self:SetActionToCursor(GetCursorInfo())
	elseif IsModifiedClick("SHIFT") then
		local set = self:GetParent().set;
		self:SetIgnored(not set.ignored[self:GetID()]);
	else
		self:SetAction(nil);
	end
end
function BtWLoadoutsActionButtonMixin:OnReceiveDrag()
	local cursorType = GetCursorInfo()
	if self:GetParent().set and cursorType then
		self:SetActionToCursor(GetCursorInfo())
	end
end
function BtWLoadoutsActionButtonMixin:SetActionToCursor(...)
	local cursorType = ...
	if cursorType then
		if cursorType == "battlepet" then
			local id = select(2, ...)
			self:SetAction("summonpet", id)
		elseif cursorType == "mount" then
			local id = select(2, ...)
			self:SetAction("summonmount", id)
		elseif cursorType == "petaction" then
			local id = select(2, ...)
			self:SetAction("spell", id, "pet")
		elseif cursorType == "spell" then
			local subType, id = select(3, ...)
			id = FindBaseSpellByID(id) or id
			self:SetAction("spell", id, subType)
		elseif cursorType == "equipmentset" then
			local id = select(2, ...)
			local icon, name
			do
				local id = C_EquipmentSet.GetEquipmentSetID(id)
				name, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
			end
			self:SetAction("equipmentset", id, nil, icon, name)
		elseif cursorType == "macro" then
			local id = select(2, ...)
			local macroText = GetMacroBody(id)
			local name, icon = GetMacroInfo(id)
			self:SetAction("macro", id, nil, icon, name, macroText)
		elseif cursorType == "flyout" then
			local id, icon = select(2, ...)
			self:SetAction("flyout", id, nil, icon)
		elseif cursorType == "item" then
			self:SetAction(cursorType, (select(2, ...)))
		-- else -- Anything else isnt supported
		end
		ClearCursor()
	end
end
function BtWLoadoutsActionButtonMixin:SetAction(actionType, ...)
	local set = self:GetParent().set;
	if actionType == nil then -- Clearing slot
		set.actions[self:GetID()] = nil;

		self:Update();
		return true;
	else
		local tbl = set.actions[self:GetID()] or {}

		tbl.type, tbl.id, tbl.subType, tbl.icon, tbl.name, tbl.macroText = actionType, ...

		set.actions[self:GetID()] = tbl;
		self:Update()
	end
end
function BtWLoadoutsActionButtonMixin:SetIgnored(ignored)
	local set = self:GetParent().set;
	set.ignored[self:GetID()] = ignored and true or nil;
	self:Update();
end
function BtWLoadoutsActionButtonMixin:Update()
	local set = self:GetParent().set;
	local slot = self:GetID();
	local ignored = set.ignored[slot];
	local tbl = set.actions[slot];
	if tbl and tbl.type ~= nil then
		local icon, name = tbl.icon, tbl.name
		if tbl.type == "item" then
			icon = select(5, GetItemInfoInstant(tbl.id))
		elseif tbl.type == "spell" then
			icon = select(3, GetSpellInfo(tbl.id))
		elseif tbl.type == "summonmount" then
			if tbl.id == 0xFFFFFFF then
				icon = 413588
			else
				icon = select(3, C_MountJournal.GetMountInfoByID(tbl.id))
			end
		elseif tbl.type == "summonpet" then
			icon = select(9, C_PetJournal.GetPetInfoByPetID(tbl.id))
		elseif tbl.type == "macro" then
			local index = Internal.GetMacroByText(tbl.macroText)
			if index then
				name, icon = GetMacroInfo(index)
			end
		elseif tbl.type == "equipmentset" then
			local id = C_EquipmentSet.GetEquipmentSetID(tbl.id)
			if id then
				name, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
			end
		else
			-- print(tbl.type, tbl.id)
		end

		if not icon then
			icon = 134400
		end
		
		self.Name:SetText(name)
		self.Icon:SetTexture(icon)
	else
		self.Name:SetText(nil)
		self.Icon:SetTexture(nil)
	end

	self.ignoreTexture:SetShown(ignored);
end

BtWLoadoutsIgnoreActionBarMixin = {}
function BtWLoadoutsIgnoreActionBarMixin:OnClick()
	local set = self:GetParent().set;
	local setIgnored = true
	for id=self.startID,self.endID do
		if set.ignored[id] then
			setIgnored = false
			break
		end
	end
	for id=self.startID,self.endID do
		set.ignored[id] = setIgnored
		self:GetParent().Slots[id]:Update()
	end
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
