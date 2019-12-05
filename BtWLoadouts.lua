--[[@TODO
	Minimap icon should show progress texture and help box
	Profiles need to support multiple sets of the same type
	Equipment popout
	Equipment sets should store location
	Equipment sets should store transmog?
	Profile keybindings
	Talent, equipment, etc. lock checking
	Conditions need to supoort boss, affixes and arena comp
	Localization
	Update new set text button based on tab?
	What to do when the player has no tome
	Acton Bar Support
	External API
]]

local ADDON_NAME, Internal = ...;
local L = Internal.L;

local External = {}
_G[ADDON_NAME] = External

local GetNextSetID = Internal.GetNextSetID;
local DeleteSet = Internal.DeleteSet;

local GetCursorItemSource;

BTWLOADOUTS_PROFILE = L["Profile"];
BTWLOADOUTS_PROFILES = L["Profiles"];
BTWLOADOUTS_TALENTS = L["Talents"];
BTWLOADOUTS_PVP_TALENTS = L["PvP Talents"];
BTWLOADOUTS_ESSENCES = L["Essences"];
BTWLOADOUTS_EQUIPMENT = L["Equipment"];
BTWLOADOUTS_CONDITIONS = L["Conditions"];
BTWLOADOUTS_NEW_SET = L["New Set"];
BTWLOADOUTS_ACTIVATE = L["Activate"];
BTWLOADOUTS_DELETE = L["Delete"];
BTWLOADOUTS_NAME = L["Name"];
BTWLOADOUTS_SPECIALIZATION = L["Specialization"];

local instanceDifficulties = Internal.instanceDifficulties;
local dungeonInfo = Internal.dungeonInfo;
local raidInfo = Internal.raidInfo;
local instanceBosses = Internal.instanceBosses;
local npcIDToBossID = Internal.npcIDToBossID;
local InstanceAreaIDToBossID = Internal.InstanceAreaIDToBossID;
local uiMapIDToBossID = Internal.uiMapIDToBossID;


local CONDITION_TYPES, CONDITION_TYPE_NAMES;
local CONDITION_TYPE_WORLD = "none";
local CONDITION_TYPE_DUNGEONS = "party";
local CONDITION_TYPE_RAIDS = "raid";
local CONDITION_TYPE_ARENA = "arena";
local CONDITION_TYPE_BATTLEGROUND = "pvp";
CONDITION_TYPES = {
	CONDITION_TYPE_WORLD,
	CONDITION_TYPE_DUNGEONS,
	CONDITION_TYPE_RAIDS,
	CONDITION_TYPE_ARENA,
	CONDITION_TYPE_BATTLEGROUND
}
CONDITION_TYPE_NAMES = {
	[CONDITION_TYPE_WORLD] = L["World"],
	[CONDITION_TYPE_DUNGEONS] = L["Dungeons"],
	[CONDITION_TYPE_RAIDS] = L["Raids"],
	[CONDITION_TYPE_ARENA] = L["Arena"],
	[CONDITION_TYPE_BATTLEGROUND] = L["Battlegrounds"],
}

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
local activeConditionSelection;
local previousActiveConditions = {}; -- List of the previously active conditions
local activeConditions = {}; -- List of the currently active conditions profiles
local sortedActiveConditions = {};
local conditionProfilesDropDown = CreateFrame("FRAME", "BtWLoadoutsConditionProfilesDropDown", UIParent, "UIDropDownMenuTemplate");
local function ConditionProfilesDropDown_OnClick(self, arg1, arg2, checked)
	activeConditionSelection = arg1;
	UIDropDownMenu_SetText(conditionProfilesDropDown, arg1.condition.name);
end
local function ConditionProfilesDropDownInit(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo();

    if (level or 1) == 1 then
		for _,set in ipairs(sortedActiveConditions) do
            info.text = set.condition.name;
            info.arg1 = set;
            info.func = ConditionProfilesDropDown_OnClick;
            info.checked = activeConditionSelection == set;
            UIDropDownMenu_AddButton(info, level);
        end
    end
end

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
		data.func(activeConditionSelection.profile);
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
			CancelActivateProfile();
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


local helpTipIgnored = {};
Internal.helpTipIgnored = helpTipIgnored;
local function HelpTipBox_Anchor(self, anchorPoint, frame, offset)
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
local function HelpTipBox_SetText(self, text)
	self.Text:SetText(text);
	self:SetHeight(self.Text:GetHeight() + 34);
end

-- local NUM_TABS = 6;
-- local TAB_PROFILES = 1;
-- local TAB_TALENTS = 2;
-- local TAB_PVP_TALENTS = 3;
-- local TAB_ESSENCES = 4;
-- local TAB_EQUIPMENT = 5;
-- local TAB_CONDITIONS = 6;
local tabs = {}
function Internal.AddTab(details)
	local tabID = #tabs+1
	details.tabID = tabID

	local button = CreateFrame("Button", format("BtWLoadoutsFrame%sTab", details.type), BtWLoadoutsFrame, "BtWLoadoutsFrameTabTemplate")
	if tabID == 1 then
		button:SetPoint("BOTTOMLEFT", 7, -30)
	else
		button:SetPoint("LEFT", tabs[tabID - 1].tab, "RIGHT", -16, 0)
	end
	button:SetText(details.name)
	button:SetID(tabID)
	button:Show();
	details.tab = button

	tabs[tabID] = details
	
	PanelTemplates_SetNumTabs(BtWLoadoutsFrame, #tabs);
end
local function GetTabDetails(tabID)
	return tabs[tabID];
end
local function ShowTab(tabID)
	PanelTemplates_SetTab(BtWLoadoutsFrame, tabID);
	for id,details in ipairs(tabs) do
		details.frame:SetShown(id == tabID);
	end
end
local function GetTabFrame(tabID)
	return tabs[tabID].frame;
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

local function SpecDropDown_OnClick(self, specID, _, _)
	CloseDropDownMenus();

	local _, specName, _, icon, _, classID = GetSpecializationInfoByID(specID);
	local className = LOCALIZED_CLASS_NAMES_MALE[classID];
	local classColor = C_ClassColor.GetClassColor(classID);
	UIDropDownMenu_SetSelectedValue(self, specID);
	UIDropDownMenu_SetText(self, format("%s: %s", classColor:WrapTextInColorCode(className), specName));
	if self.OnChange then
		self:OnChange(specID)
	end

    -- local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    -- local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    -- CloseDropDownMenus();
    -- local set = tab.set;

    -- if selectedTab == TAB_PROFILES then
    --     set.specID = arg1;
    -- elseif selectedTab == TAB_TALENTS or selectedTab == TAB_PVP_TALENTS then
    --     local temp = tab.temp;
    --     -- @TODO: If we always access talents by set.talents then we can just swap tables in and out of
    --     -- the temp table instead of copying the talentIDs around

    --     -- We are going to copy the currently selected talents for the currently selected spec into
    --     -- a temporary table incase the user switches specs back
    --     local specID = set.specID;
    --     if temp[specID] then
    --         wipe(temp[specID]);
    --     else
    --         temp[specID] = {};
    --     end
    --     for talentID in pairs(set.talents) do
    --         temp[specID][talentID] = true;
    --     end

    --     -- Clear the current talents and copy back the previously selected talents if they exist
    --     specID = arg1;
    --     set.specID = specID;
    --     wipe(set.talents);
    --     if temp[specID] then
    --         for talentID in pairs(temp[specID]) do
    --             set.talents[talentID] = true;
    --         end
    --     end
    -- end
    -- BtWLoadoutsFrame:Update();
end
local function SpecDropDownInit(self, level, menuList)
	print("SpecDropDownInit", self)
	local info = UIDropDownMenu_CreateInfo();
	
	local selected = UIDropDownMenu_GetSelectedValue(self)
	-- local set = self:GetParent().set;
	-- local selected = set and set.specID;
	-- print(UIDropDownMenu_GetSelectedID(self), UIDropDownMenu_GetSelectedName(self), UIDropDownMenu_GetSelectedValue(self), selected)

	if (level or 1) == 1 then
		if self.includeNone then
			info.text = L["None"];
			info.func = SpecDropDown_OnClick;
			info.checked = selected == nil;
			info.value = nil;
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
			info.value = specID;
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
	
	if set.talentSet then
		local subset = GetTalentSet(set.talentSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	set.talentSet = arg1;
	
	if set.talentSet then
		local subset = GetTalentSet(set.talentSet);
		subset.useCount = (subset.useCount or 0) + 1;
	end

    BtWLoadoutsFrame:Update();
end
local function TalentsDropDown_NewOnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;
	
	if set.talentSet then
		local subset = GetTalentSet(set.talentSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local talentSet = AddTalentSet();
	set.talentSet = talentSet.setID;
	
	if set.talentSet then
		local subset = GetTalentSet(set.talentSet);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame.Talents.set = talentSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, TAB_TALENTS);

	helpTipIgnored["TUTORIAL_CREATE_TALENT_SET"] = true;
    BtWLoadoutsFrame:Update();
end
local function TalentsDropDownInit(self, level, menuList)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.talents then
        return;
    end
    local info = UIDropDownMenu_CreateInfo();
		
	local frame = self:GetParent():GetParent();
	local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
	local tab = GetTabFrame(frame, selectedTab);
	
	local set = tab.set;
	local selected = set and set.TalentSet;

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
		
        -- local frame = self:GetParent():GetParent();
        -- local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
        -- local tab = GetTabFrame(frame, selectedTab);
        
        -- local set = tab.set;
    
        -- wipe(setsFiltered);
        -- local sets = BtWLoadoutsSets.talents;
        -- for setID,talentSet in pairs(sets) do
        --     -- if talentSet.specID == set.specID then
		-- 	setsFiltered[#setsFiltered+1] = setID;
        --     -- end
        -- end
        -- sort(setsFiltered, function (a,b)
        --     return sets[a].name < sets[b].name;
        -- end)

        -- local info = UIDropDownMenu_CreateInfo();
        -- info.text = NONE;
        -- info.func = TalentsDropDown_OnClick;
        -- info.checked = set.talentSet == nil;
        -- UIDropDownMenu_AddButton(info, level);
        
        -- for _,setID in ipairs(setsFiltered) do
        --     info.text = sets[setID].name;
        --     info.arg1 = setID;
        --     info.func = TalentsDropDown_OnClick;
        --     info.checked = set.talentSet == setID;
        --     UIDropDownMenu_AddButton(info, level);
        -- end
    end
end

local function PvPTalentsDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;
	
	if set.pvpTalentSet then
		local subset = GetPvPTalentSet(set.pvpTalentSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	set.pvpTalentSet = arg1;
	
	if set.pvpTalentSet then
		local subset = GetPvPTalentSet(set.pvpTalentSet);
		subset.useCount = (subset.useCount or 0) + 1;
	end

    BtWLoadoutsFrame:Update();
end
local function PvPTalentsDropDown_NewOnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;
	
	if set.pvpTalentSet then
		local subset = GetPvPTalentSet(set.pvpTalentSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local newSet = AddPvPTalentSet();
	set.pvpTalentSet = newSet.setID;
	
	if set.pvpTalentSet then
		local subset = GetPvPTalentSet(set.pvpTalentSet);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame.PvPTalents.set = newSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, TAB_PVP_TALENTS);

    BtWLoadoutsFrame:Update();
end
local function PvPTalentsDropDownInit(self, level, menuList)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.pvptalents then
        return;
	end
	
    local info = UIDropDownMenu_CreateInfo();
	
	local frame = self:GetParent():GetParent();
	local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
	local tab = GetTabFrame(frame, selectedTab);
	
	local set = tab.set;
	local selected = set and set.pvpTalentSet;

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
		

        -- local frame = self:GetParent():GetParent();
        -- local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
        -- local tab = GetTabFrame(frame, selectedTab);
        
        -- local set = tab.set;
    
        -- wipe(setsFiltered);
        -- local sets = BtWLoadoutsSets.pvptalents;
        -- for setID,talentSet in pairs(sets) do
        --     -- if talentSet.specID == set.specID then
		-- 	setsFiltered[#setsFiltered+1] = setID;
        --     -- end
        -- end
        -- sort(setsFiltered, function (a,b)
        --     return sets[a].name < sets[b].name;
        -- end)

        -- local info = UIDropDownMenu_CreateInfo();
        -- info.text = NONE;
        -- info.func = PvPTalentsDropDown_OnClick;
        -- info.checked = set.pvpTalentSet == nil;
        -- UIDropDownMenu_AddButton(info, level);
        
        -- for _,setID in ipairs(setsFiltered) do
        --     info.text = sets[setID].name;
        --     info.arg1 = setID;
        --     info.func = PvPTalentsDropDown_OnClick;
        --     info.checked = set.pvpTalentSet == setID;
        --     UIDropDownMenu_AddButton(info, level);
        -- end
    end
end

local function EssencesDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;
	
	if set.essencesSet then
		local subset = GetEssenceSet(set.essencesSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

    set.essencesSet = arg1;
	
	if set.essencesSet then
		local subset = GetEssenceSet(set.essencesSet);
		subset.useCount = (subset.useCount or 0) + 1;
	end

    BtWLoadoutsFrame:Update();
end
local function EssencesDropDown_NewOnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;
	
	if set.essencesSet then
		local subset = GetEssenceSet(set.essencesSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local newSet = AddEssenceSet();
	set.essencesSet = newSet.setID;
	
	if set.essencesSet then
		local subset = GetEssenceSet(set.essencesSet);
		subset.useCount = (subset.useCount or 0) + 1;
	end


	BtWLoadoutsFrame.Essences.set = newSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, TAB_ESSENCES);

    BtWLoadoutsFrame:Update();
end
local function EssencesDropDownInit(self, level, menuList)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.essences then
        return;
    end

    local info = UIDropDownMenu_CreateInfo();
		
	local frame = self:GetParent():GetParent();
	local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
	local tab = GetTabFrame(frame, selectedTab);
	
	local set = tab.set;
	local selected = set and set.essencesSet;

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
		
        -- local frame = self:GetParent():GetParent();
        -- local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
        -- local tab = GetTabFrame(frame, selectedTab);
        
        -- local set = tab.set;

        -- -- local role = select(5, GetSpecializationInfoByID(set.specID));
    
        -- wipe(setsFiltered);
        -- local sets = BtWLoadoutsSets.essences;
        -- for setID,talentSet in pairs(sets) do
        --     -- if talentSet.role == role then
		-- 	setsFiltered[#setsFiltered+1] = setID;
        --     -- end
        -- end
        -- sort(setsFiltered, function (a,b)
        --     return sets[a].name < sets[b].name;
        -- end)

        -- local info = UIDropDownMenu_CreateInfo();
        -- info.text = NONE;
        -- info.func = EssencesDropDown_OnClick;
        -- info.checked = set.essencesSet == nil;
        -- UIDropDownMenu_AddButton(info, level);
        
        -- for _,setID in ipairs(setsFiltered) do
        --     info.text = sets[setID].name;
        --     info.arg1 = setID;
        --     info.func = EssencesDropDown_OnClick;
        --     info.checked = set.essencesSet == setID;
        --     UIDropDownMenu_AddButton(info, level);
        -- end
    end
end

local function EquipmentDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;
	
	if set.equipmentSet then
		local subset = GetEquipmentSet(set.equipmentSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	set.equipmentSet = arg1;
	set.character = arg2;
	
	if set.equipmentSet then
		local subset = GetEquipmentSet(set.equipmentSet);
		subset.useCount = (subset.useCount or 0) + 1;
	end

    BtWLoadoutsFrame:Update();
end
local function EquipmentDropDown_NewOnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
	local set = tab.set;
	
	if set.equipmentSet then
		local subset = GetEquipmentSet(set.equipmentSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local newSet = AddEquipmentSet();
	set.equipmentSet = newSet.setID;
	set.character = newSet.character;
	
	if set.equipmentSet then
		local subset = GetEquipmentSet(set.equipmentSet);
		subset.useCount = (subset.useCount or 0) + 1;
	end

	BtWLoadoutsFrame.Equipment.set = newSet;
	PanelTemplates_SetTab(BtWLoadoutsFrame, TAB_EQUIPMENT);

    BtWLoadoutsFrame:Update();
end
local function EquipmentDropDownInit(self, level, menuList)
    if not BtWLoadoutsSets or not BtWLoadoutsSets.equipment then
        return;
    end

    local info = UIDropDownMenu_CreateInfo();
		
	local frame = self:GetParent():GetParent();
	local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
	local tab = GetTabFrame(frame, selectedTab);
	
	local set = tab.set;
	local selected = set and set.equipmentSet;

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
			info.arg2 = sets[setID].character;
            info.func = EquipmentDropDown_OnClick;
            info.checked = selected == setID;
            UIDropDownMenu_AddButton(info, level);
		end
        -- local frame = self:GetParent():GetParent();
        -- local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
        -- local tab = GetTabFrame(frame, selectedTab);
        
		-- local set = tab.set;
		-- -- local class = select(6, GetSpecializationInfoByID(set.specID));
    
        -- wipe(setsFiltered);
        -- local sets = BtWLoadoutsSets.equipment;
		-- for setID,equipmentSet in pairs(sets) do
		-- 	-- local characterInfo = GetCharacterInfo(equipmentSet.character)
        --     -- if characterInfo.class == class then
		-- 	setsFiltered[#setsFiltered+1] = setID;
        --     -- end
        -- end
        -- sort(setsFiltered, function (a,b)
        --     return sets[a].name < sets[b].name;
        -- end)

        -- local info = UIDropDownMenu_CreateInfo();
        -- info.text = NONE;
        -- info.func = EquipmentDropDown_OnClick;
        -- info.checked = set.equipmentSet == nil;
        -- UIDropDownMenu_AddButton(info, level);
        
        -- for _,setID in ipairs(setsFiltered) do
        --     info.text = sets[setID].name;
        --     info.arg1 = setID;
        --     info.arg2 = sets[setID].character;
        --     info.func = EquipmentDropDown_OnClick;
        --     info.checked = set.equipmentSet == setID;
        --     UIDropDownMenu_AddButton(info, level);
        -- end
    end
end

local function ProfilesDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
    local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;
	
	if set.profileSet then
		local subset = GetProfile(set.profileSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	set.profileSet = arg1;
	
	if set.profileSet then
		local subset = GetProfile(set.profileSet);
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
		local subset = GetProfile(set.profileSet);
		subset.useCount = (subset.useCount or 1) - 1;
	end

	local newSet = AddProfile();
	set.equipmenprofileSettSet = newSet.setID;
	
	if set.profileSet then
		local subset = GetProfile(set.profileSet);
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
		
	local frame = self:GetParent():GetParent();
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
		for _,conditionType in ipairs(CONDITION_TYPES) do
			info.text = CONDITION_TYPE_NAMES[conditionType];
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

			for _,difficultyID in ipairs(dungeonDifficultiesAll) do
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

			for _,difficultyID in ipairs(raidDifficultiesAll) do
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

do
	local NUM_SCROLL_ITEMS_TO_DISPLAY = 18;
	local SCROLL_ROW_HEIGHT = 21;
	local setScrollItems = {};
	function BtWLoadoutsSetsScrollFrame_Update()
		local offset = FauxScrollFrame_GetOffset(BtWLoadoutsFrame.Scroll);
		
		local hasScrollBar = #setScrollItems > NUM_SCROLL_ITEMS_TO_DISPLAY;
		for index=1,NUM_SCROLL_ITEMS_TO_DISPLAY do
			local button = BtWLoadoutsFrame.ScrollButtons[index];
			button:SetWidth(hasScrollBar and 153 or 175);
			
			local item = setScrollItems[index + offset];
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
				button.Name:SetText(name or L["Unnamed"]);
				button:Show();
			else
				button:Hide();
			end
		end
		FauxScrollFrame_Update(BtWLoadoutsFrame.Scroll, #setScrollItems, NUM_SCROLL_ITEMS_TO_DISPLAY, SCROLL_ROW_HEIGHT, nil, nil, nil, nil, nil, nil, false);
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
						selected = sets[setID] == selected,
					};
				end
			end
		end
		
		BtWLoadoutsSetsScrollFrame_Update();
		
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
								selected = sets[setID] == selected,
							};
						end
					end
				end
			end
		end

		BtWLoadoutsSetsScrollFrame_Update();
		
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
								builtin = sets[setID].managerID ~= nil,
							};
						end
					end
				end
			end
		end

		BtWLoadoutsSetsScrollFrame_Update();
		
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
				selected = sets[setID] == selected,
			};
		end

		BtWLoadoutsSetsScrollFrame_Update();
		
		return selected;
	end
--[[
	local function ProfilesTabUpdate(self)
	end
	local MAX_PVP_TALENTS = 15;
	local function PvPTalentsTabUpdate(self)
		self:GetParent().TitleText:SetText(L["PvP Talents"]);
		self.set = SetsScrollFrame_SpecFilter(self.set, BtWLoadoutsSets.pvptalents, setScrollFrameCollapsed.pvptalents);

		if self.set ~= nil then
			self.Name:SetEnabled(true);
			self.SpecDropDown.Button:SetEnabled(true);
			self.trinkets:SetShown(true);
			self.others:SetShown(true);

			local specID = self.set.specID;
			local selected = self.set.talents;

			if not self.Name:HasFocus() then
				self.Name:SetText(self.set.name or "");
			end

			local _, specName, _, icon, _, classID = GetSpecializationInfoByID(specID);
			local className = LOCALIZED_CLASS_NAMES_MALE[classID];
			local classColor = C_ClassColor.GetClassColor(classID);
			UIDropDownMenu_SetText(self.SpecDropDown, format("%s: %s", classColor:WrapTextInColorCode(className), specName));

			if self.set.inUse then
				UIDropDownMenu_DisableDropDown(self.SpecDropDown);
			else
				UIDropDownMenu_EnableDropDown(self.SpecDropDown);
			end

			local trinkets = self.trinkets;
			for column=1,3 do
				local item = trinkets.talents[column];
				local talentID, name, texture, _, _, spellID = GetPvPTrinketTalentInfo(specID, column);

				item.isPvP = true;
				item.id = talentID;
				item.name:SetText(name);
				item.icon:SetTexture(texture);
				
				if selected[talentID] then
					item.knownSelection:Show();
					item.icon:SetDesaturated(false);
				else
					item.knownSelection:Hide();
					item.icon:SetDesaturated(true);
				end
			end
			
			local count = 0;
			for index=1,MAX_PVP_TALENTS do
				local talentID, name, texture, _, _, spellID = GetPvPTalentInfoForSpecID(specID, index);
				if talentID and selected[talentID] then
					count = count + 1;
				end
			end
			
			local others = self.others;
			for index=1,MAX_PVP_TALENTS do
				local item = others.talents[index];
				local talentID, name, texture, _, _, spellID = GetPvPTalentInfoForSpecID(specID, index);
				
				if talentID then
					item.isPvP = true;
					item.id = talentID;
					item.name:SetText(name);
					item.icon:SetTexture(texture);
					
					if selected[talentID] then
						item.Cover:SetShown(false);
						item:SetEnabled(true);

						item.knownSelection:Show();
						item.icon:SetDesaturated(false);
					else
						item.Cover:SetShown(count >= 3);
						item:SetEnabled(count < 3);

						item.knownSelection:Hide();
						item.icon:SetDesaturated(true);
					end

					item:Show();
				else
					item:Hide();
				end
			end

			local activateButton = self:GetParent().ActivateButton;
			activateButton:SetEnabled(classID == select(2, UnitClass("player")));

			local deleteButton =  self:GetParent().DeleteButton;
			deleteButton:SetEnabled(true);
			
			local helpTipBox = self:GetParent().HelpTipBox;
			helpTipBox:Hide();

			local addButton = self:GetParent().AddButton;
			addButton.Flash:Hide();
			addButton.FlashAnim:Stop();
		else
			self.Name:SetEnabled(false);
			self.SpecDropDown.Button:SetEnabled(false);
			self.trinkets:SetShown(false);
			self.others:SetShown(false);

			self.Name:SetText("");

			local activateButton = self:GetParent().ActivateButton;
			activateButton:SetEnabled(false);

			local deleteButton =  self:GetParent().DeleteButton;
			deleteButton:SetEnabled(false);

			local addButton = self:GetParent().AddButton;
			addButton.Flash:Show();
			addButton.FlashAnim:Play();
			
			local helpTipBox = self:GetParent().HelpTipBox;
			-- Tutorial stuff
			if not helpTipIgnored["TUTORIAL_NEW_SET"] then
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
	local EssenceScrollFrameUpdate;
	do
		local MAX_ESSENCES = 11;
		function EssenceScrollFrameUpdate(self)
			local pending = self:GetParent().pending;
			local set = self:GetParent().set;
			local buttons = self.buttons;
			if set then
				local role = set.role;
				local selected = set.essences;
				
				local offset = HybridScrollFrame_GetOffset(self);
				for i,item in ipairs(buttons) do
					local index = offset + i;
					local essence = GetEssenceInfoForRole(role, index);
					
					if essence then
						item.id = essence.ID;
						item.Name:SetText(essence.name);
						item.Icon:SetTexture(essence.icon);
						item.ActivatedMarkerMain:SetShown(selected[115] == essence.ID);
						item.ActivatedMarkerPassive:SetShown((selected[116] == essence.ID) or (selected[117] == essence.ID));
						item.PendingGlow:SetShown(pending == essence.ID);
						
						item:Show();
					else
						item:Hide();
					end
				end
				local totalHeight = MAX_ESSENCES * (41 + 1) + 3 * 2;
				HybridScrollFrame_Update(self, totalHeight, self:GetHeight());
			else
				for i,item in ipairs(buttons) do
					item:Hide();
				end
				HybridScrollFrame_Update(self, 0, self:GetHeight());
			end
		end
	end
	local function EssencesTabUpdate(self)
		self:GetParent().TitleText:SetText(L["Essences"]);
		self.set = SetsScrollFrame_RoleFilter(self.set, BtWLoadoutsSets.essences, setScrollFrameCollapsed.essences);

		if self.set ~= nil then
			self.Name:SetEnabled(true);
			self.RoleDropDown.Button:SetEnabled(true);
			self.MajorSlot:SetEnabled(true);
			self.MinorSlot1:SetEnabled(true);
			self.MinorSlot2:SetEnabled(true);

			local role = self.set.role;
			local selected = self.set.essences;
			
			UIDropDownMenu_SetText(self.RoleDropDown, _G[self.set.role]);

			if self.set.inUse then
				UIDropDownMenu_DisableDropDown(self.RoleDropDown);
			else
				UIDropDownMenu_EnableDropDown(self.RoleDropDown);
			end

			if not self.Name:HasFocus() then
				self.Name:SetText(self.set.name or "");
			end

			for milestoneID,item in pairs(self.Slots) do
				local essenceID = self.set.essences[milestoneID];
				item.milestoneID = milestoneID;

				if essenceID then
					local info = GetEssenceInfoByID(essenceID);

					item.id = essenceID;
					
					item.Icon:Show();
					item.Icon:SetTexture(info.icon);
					item.EmptyGlow:Hide();
					item.EmptyIcon:Hide();
				else
					item.id = nil;

					item.Icon:Hide();
					item.EmptyGlow:Show();
					item.EmptyIcon:Show();
				end
			end

			local activateButton = self:GetParent().ActivateButton;
			activateButton:SetEnabled(role == select(5, GetSpecializationInfo(GetSpecialization())));

			local deleteButton =  self:GetParent().DeleteButton;
			deleteButton:SetEnabled(true);
			
			local helpTipBox = self:GetParent().HelpTipBox;
			helpTipBox:Hide();

			local addButton = self:GetParent().AddButton;
			addButton.Flash:Hide();
			addButton.FlashAnim:Stop();
		else
			self.Name:SetEnabled(false);
			self.RoleDropDown.Button:SetEnabled(false);
			self.MajorSlot:SetEnabled(false);
			self.MinorSlot1:SetEnabled(false);
			self.MinorSlot2:SetEnabled(false);

			self.MajorSlot.EmptyGlow:Hide();
			self.MinorSlot1.EmptyGlow:Hide();
			self.MinorSlot2.EmptyGlow:Hide();
			self.MajorSlot.EmptyIcon:Hide();
			self.MinorSlot1.EmptyIcon:Hide();
			self.MinorSlot2.EmptyIcon:Hide();
			self.MajorSlot.Icon:Hide();
			self.MinorSlot1.Icon:Hide();
			self.MinorSlot2.Icon:Hide();

			self.Name:SetText("");

			local activateButton = self:GetParent().ActivateButton;
			activateButton:SetEnabled(false);

			local deleteButton =  self:GetParent().DeleteButton;
			deleteButton:SetEnabled(false);

			local addButton = self:GetParent().AddButton;
			addButton.Flash:Show();
			addButton.FlashAnim:Play();
			
			local helpTipBox = self:GetParent().HelpTipBox;
			-- Tutorial stuff
			if not helpTipIgnored["TUTORIAL_NEW_SET"] then
				helpTipBox.closeFlag = "TUTORIAL_NEW_SET";

				HelpTipBox_Anchor(helpTipBox, "TOP", addButton);
				
				helpTipBox:Show();
				HelpTipBox_SetText(helpTipBox, L["To begin, create a new set."]);
			else
				helpTipBox.closeFlag = nil;
				helpTipBox:Hide();
			end
		end

		EssenceScrollFrameUpdate(self.EssenceList);
	end
	local function EquipmentTabUpdate(self)
		self:GetParent().TitleText:SetText(L["Equipment"]);
		self.set = SetsScrollFrame_CharacterFilter(self.set, BtWLoadoutsSets.equipment, setScrollFrameCollapsed.equipment);

		if self.set ~= nil then
			local set = self.set;
			local character = set.character;
			local characterInfo = GetCharacterInfo(character);
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
				if not helpTipIgnored["INVALID_PLAYER"] then
					helpTipBox.closeFlag = "INVALID_PLAYER";

					HelpTipBox_Anchor(helpTipBox, "TOP", activateButton);
					
					helpTipBox:Show();
					HelpTipBox_SetText(helpTipBox, L["Can not equip sets for other characters."]);
				else
					helpTipBox.closeFlag = nil;
					helpTipBox:Hide();
				end
			elseif set.managerID ~= nil then
				if not helpTipIgnored["EQUIPMENT_MANAGER_BLOCK"] then
					helpTipBox.closeFlag = "EQUIPMENT_MANAGER_BLOCK";

					HelpTipBox_Anchor(helpTipBox, "RIGHT", self.HeadSlot);
					
					helpTipBox:Show();
					HelpTipBox_SetText(helpTipBox, L["Can not edit equipment manager sets."]);
				else
					helpTipBox.closeFlag = nil;
					helpTipBox:Hide();
				end
			else
				if not helpTipIgnored["EQUIPMENT_IGNORE"] then
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
			if not helpTipIgnored["TUTORIAL_NEW_SET"] then
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
	local function ConditionsTabUpdate(self)
		self:GetParent().TitleText:SetText(L["Conditions"]);
		self.set = SetsScrollFrame_NoFilter(self.set, BtWLoadoutsSets.conditions);

		if self.set ~= nil then
			local set = self.set;

			-- 8 is M+ and 23 is Mythic, since we cant change specs inside a M+ we need to check trigger within the mythic but still,
			-- show in the editor as Mythic Keystone whatever.
			if set.difficultyID == 8 then
				set.mapDifficultyID = 23;
			else
				set.mapDifficultyID = set.difficultyID;
			end

			if set.map.instanceType ~= set.type or set.map.instanceID ~= set.instanceID or set.map.difficultyID ~= set.mapDifficultyID or set.map.bossID ~= set.bossID or set.map.affixesID ~= set.affixesID or set.mapProfileSet ~= set.profileSet then
				RemoveConditionFromMap(set);

				set.mapProfileSet = set.profileSet; -- Used to check if we should handle the condition

				wipe(set.map);
				set.map.instanceType = set.type;
				set.map.instanceID = set.instanceID;
				set.map.difficultyID = set.mapDifficultyID;
				set.map.bossID = set.bossID;
				set.map.affixesID = set.affixesID;

				AddConditionToMap(set);
			end

			self.Name:SetEnabled(true);
			if not self.Name:HasFocus() then
				self.Name:SetText(self.set.name or "");
			end

			self.ProfileDropDown.Button:SetEnabled(true);
			self.ConditionTypeDropDown.Button:SetEnabled(true);
			self.InstanceDropDown.Button:SetEnabled(true);
			self.DifficultyDropDown.Button:SetEnabled(true);
			
			if set.profileSet == nil then
				UIDropDownMenu_SetText(self.ProfileDropDown, NONE);
			else
				local subset = GetProfile(set.profileSet);
				UIDropDownMenu_SetText(self.ProfileDropDown, subset.name);
			end
			
			UIDropDownMenu_SetText(self.ConditionTypeDropDown, CONDITION_TYPE_NAMES[self.set.type]);
			self.InstanceDropDown:SetShown(set.type == CONDITION_TYPE_DUNGEONS or set.type == CONDITION_TYPE_RAIDS);
			if set.instanceID == nil then
				UIDropDownMenu_SetText(self.InstanceDropDown, L["Any"]);
			else
				UIDropDownMenu_SetText(self.InstanceDropDown, GetRealZoneText(set.instanceID));
			end
			self.DifficultyDropDown:SetShown(set.type == CONDITION_TYPE_DUNGEONS or set.type == CONDITION_TYPE_RAIDS);
			if set.difficultyID == nil then
				UIDropDownMenu_SetText(self.DifficultyDropDown, L["Any"]);
			else
				UIDropDownMenu_SetText(self.DifficultyDropDown, GetDifficultyInfo(set.difficultyID));
			end

			-- With no instance selected, no bosses for that instance, or when M+ is selected, hide the boss drop down
			if set.instanceID == nil or instanceBosses[set.instanceID] == nil or set.difficultyID == 8 then
				self.BossDropDown:SetShown(false);
			else
				self.BossDropDown:SetShown(true);
				self.BossDropDown.Button:SetEnabled(true);

				if set.bossID == nil then
					UIDropDownMenu_SetText(self.BossDropDown, L["Any"]);
				else
					UIDropDownMenu_SetText(self.BossDropDown, EJ_GetEncounterInfo(set.bossID));
				end
			end
			if set.difficultyID ~= 8 then
				self.AffixesDropDown:SetShown(false);
			else
				self.AffixesDropDown:SetShown(true);
				self.AffixesDropDown.Button:SetEnabled(true);

				if set.affixesID == nil then
					UIDropDownMenu_SetText(self.AffixesDropDown, L["Any"]);
				else
					UIDropDownMenu_SetText(self.AffixesDropDown, select(3, GetAffixesName(set.affixesID)));
				end
			end

			local activateButton = self:GetParent().ActivateButton;
			activateButton:SetEnabled(false);

			local deleteButton =  self:GetParent().DeleteButton;
			deleteButton:SetEnabled(true);
			
			local helpTipBox = self:GetParent().HelpTipBox;
			helpTipBox:Hide();
			
			local addButton = self:GetParent().AddButton;
			addButton.Flash:Hide();
			addButton.FlashAnim:Stop();
		else
			self.Name:SetEnabled(false);
			self.Name:SetText("");

			self.ProfileDropDown.Button:SetEnabled(false);
			self.ConditionTypeDropDown.Button:SetEnabled(false);
			self.InstanceDropDown.Button:SetEnabled(false);
			self.DifficultyDropDown.Button:SetEnabled(false);
			self.BossDropDown.Button:SetEnabled(false);
			self.AffixesDropDown:Hide();

			local activateButton = self:GetParent().ActivateButton;
			activateButton:SetEnabled(false);

			local deleteButton =  self:GetParent().DeleteButton;
			deleteButton:SetEnabled(false);
			
			local helpTipBox = self:GetParent().HelpTipBox;
			helpTipBox:Hide();
			
			local addButton = self:GetParent().AddButton;
			addButton.Flash:Show();
			addButton.FlashAnim:Play();
		end
	end
]]
	BtWLoadoutsFrameMixin = {};
	function BtWLoadoutsFrameMixin:OnLoad()
		tinsert(UISpecialFrames, self:GetName());
		self:RegisterForDrag("LeftButton");
		
		-- self.Profiles.set = {};
		
		-- self.Talents.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
		-- self.Talents.set = {talents = {}};

		-- self.PvPTalents.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
		-- self.PvPTalents.set = {talents = {}};

		-- self.Essences.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
		-- self.Essences.set = {essences = {}};
		-- self.Essences.pending = nil;

		-- self.Equipment.set = {equipment = {}, ignored = {}};

		-- PanelTemplates_SetNumTabs(self, NUM_TABS);
		-- PanelTemplates_SetTab(self, 1);

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
		-- SetCursor(nil);
	end
	-- function BtWLoadoutsFrameMixin:SetProfile(set)
	-- 	self.Profiles.set = set;
	-- 	self:Update();
	-- end
	-- function BtWLoadoutsFrameMixin:SetTalentSet(set)
	-- 	self.Talents.set = set;
	-- 	wipe(self.Talents.temp);
	-- 	self:Update();
	-- end
	-- function BtWLoadoutsFrameMixin:SetPvPTalentSet(set)
	-- 	self.PvPTalents.set = set;
	-- 	wipe(self.PvPTalents.temp);
	-- 	self:Update();
	-- end
	-- function BtWLoadoutsFrameMixin:SetEssenceSet(set)
	-- 	self.Essences.set = set;
	-- 	wipe(self.Essences.temp);
	-- 	self:Update();
	-- end
	-- function BtWLoadoutsFrameMixin:SetEquipmentSet(set)
	-- 	self.Equipment.set = set;
	-- 	self:Update();
	-- end
	-- function BtWLoadoutsFrameMixin:SetConditionSet(set)
	-- 	self.Conditions.set = set;
	-- 	self:Update();
	-- end
	function BtWLoadoutsFrameMixin:Update()
		local selectedTab = PanelTemplates_GetSelectedTab(self) or 1;
		local details = GetTabDetails(selectedTab)
		ShowTab(selectedTab)
		details.onUpdate(self)

		-- if selectedTab == TAB_PROFILES then
		-- 	ProfilesTabUpdate(self.Profiles);
		-- elseif selectedTab == TAB_TALENTS then
		-- 	TalentsTabUpdate(self.Talents);
		-- elseif selectedTab == TAB_PVP_TALENTS then
		-- 	PvPTalentsTabUpdate(self.PvPTalents);
		-- elseif selectedTab == TAB_ESSENCES then
		-- 	EssencesTabUpdate(self.Essences);
		-- elseif selectedTab == TAB_EQUIPMENT then
		-- 	EquipmentTabUpdate(self.Equipment);
		-- elseif selectedTab == TAB_CONDITIONS then
		-- 	ConditionsTabUpdate(self.Conditions);
		-- end
	end
	function BtWLoadoutsFrameMixin:ScrollItemClick(button)
		CloseDropDownMenus();		
		local selectedTab = PanelTemplates_GetSelectedTab(self) or 1;
		local details = GetTabDetails(selectedTab)
		details.onButtonClick(self, button)

		-- if selectedTab == TAB_PROFILES then
		-- 	local frame = self.Profiles;
		-- 	if button.isAdd then
		-- 		helpTipIgnored["TUTORIAL_NEW_SET"] = true;

		-- 		frame.Name:ClearFocus();
		-- 		self:SetProfile(AddProfile());
		-- 		C_Timer.After(0, function ()
		-- 			frame.Name:HighlightText();
		-- 			frame.Name:SetFocus();
		-- 		end)
		-- 	elseif button.isDelete then
		-- 		local set = frame.set;
		-- 		if set.useCount > 0 then
		-- 			StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
		-- 				set = set,
		-- 				func = DeleteProfile,
		-- 			});
		-- 		else
		-- 			StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
		-- 				set = set,
		-- 				func = DeleteProfile,
		-- 			});
		-- 		end
		-- 	elseif button.isActivate then
		-- 		helpTipIgnored["TUTORIAL_ACTIVATE_SET"] = true;

		-- 		local set = frame.set;
		-- 		ActivateProfile(set);

		-- 		ProfilesTabUpdate(frame);
		-- 	elseif button.isHeader then
		-- 		setScrollFrameCollapsed.profiles[button.id] = not setScrollFrameCollapsed.profiles[button.id] and true or nil;
		-- 		ProfilesTabUpdate(frame);
		-- 	else
		-- 		if IsModifiedClick("SHIFT") then
		-- 			ActivateProfile(GetProfile(button.id));
		-- 		else
		-- 			frame.Name:ClearFocus();
		-- 			self:SetProfile(GetProfile(button.id));
		-- 		end
		-- 	end
		-- elseif selectedTab == TAB_TALENTS then
		-- 	local frame = self.Talents;
		-- 	if button.isAdd then
		-- 		frame.Name:ClearFocus();
		-- 		self:SetTalentSet(AddTalentSet());
		-- 		C_Timer.After(0, function ()
		-- 			frame.Name:HighlightText();
		-- 			frame.Name:SetFocus();
		-- 		end)
		-- 	elseif button.isDelete then
		-- 		local set = frame.set;
		-- 		if set.useCount > 0 then
		-- 			StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
		-- 				set = set,
		-- 				func = DeleteTalentSet,
		-- 			});
		-- 		else
		-- 			StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
		-- 				set = set,
		-- 				func = DeleteTalentSet,
		-- 			});
		-- 		end
		-- 	elseif button.isActivate then
		-- 		local set = frame.set;
		-- 		if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
		-- 			ActivateProfile({
		-- 				talentSet = set.setID;
		-- 			});
		-- 		end
		-- 	elseif button.isHeader then
		-- 		setScrollFrameCollapsed.talents[button.id] = not setScrollFrameCollapsed.talents[button.id] and true or nil;
		-- 		TalentsTabUpdate(frame);
		-- 	else
		-- 		if IsModifiedClick("SHIFT") then
		-- 			local set = GetTalentSet(button.id);
		-- 			if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
		-- 				ActivateProfile({
		-- 					talentSet = button.id;
		-- 				});
		-- 			end
		-- 		else
		-- 			frame.Name:ClearFocus(); 
		-- 			self:SetTalentSet(GetTalentSet(button.id));
		-- 		end
		-- 	end
		-- elseif selectedTab == TAB_PVP_TALENTS then
		-- 	local frame = self.PvPTalents;
		-- 	if button.isAdd then
		-- 		frame.Name:ClearFocus();
		-- 		self:SetPvPTalentSet(AddPvPTalentSet());
		-- 		C_Timer.After(0, function ()
		-- 			frame.Name:HighlightText();
		-- 			frame.Name:SetFocus();
		-- 		end)
		-- 	elseif button.isDelete then
		-- 		local set = frame.set;
		-- 		if set.useCount > 0 then
		-- 			StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
		-- 				set = set,
		-- 				func = DeletePvPTalentSet,
		-- 			});
		-- 		else
		-- 			StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
		-- 				set = set,
		-- 				func = DeletePvPTalentSet,
		-- 			});
		-- 		end
		-- 	elseif button.isActivate then
		-- 		local set = frame.set;
		-- 		if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
		-- 			ActivateProfile({
		-- 				pvpTalentSet = set.setID;
		-- 			});
		-- 		end
		-- 	elseif button.isHeader then
		-- 		setScrollFrameCollapsed.pvptalents[button.id] = not setScrollFrameCollapsed.pvptalents[button.id] and true or nil;
		-- 		PvPTalentsTabUpdate(self.PvPTalents);
		-- 	else
		-- 		if IsModifiedClick("SHIFT") then
		-- 			local set = GetPvPTalentSet(button.id);
		-- 			if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
		-- 				ActivateProfile({
		-- 					pvpTalentSet = button.id;
		-- 				});
		-- 			end
		-- 		else 
		-- 			frame.Name:ClearFocus();
		-- 			self:SetPvPTalentSet(GetPvPTalentSet(button.id));
		-- 		end
		-- 	end
		-- elseif selectedTab == TAB_ESSENCES then
		-- 	local frame = self.Essences;
		-- 	if button.isAdd then
		-- 		frame.Name:ClearFocus();
		-- 		self:SetEssenceSet(AddEssenceSet());
		-- 		C_Timer.After(0, function ()
		-- 			frame.Name:HighlightText();
		-- 			frame.Name:SetFocus();
		-- 		end)
		-- 	elseif button.isDelete then
		-- 		local set = frame.set;
		-- 		if set.useCount > 0 then
		-- 			StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
		-- 				set = set,
		-- 				func = DeleteEssenceSet,
		-- 			});
		-- 		else
		-- 			StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
		-- 				set = set,
		-- 				func = DeleteEssenceSet,
		-- 			});
		-- 		end
		-- 	elseif button.isActivate then
		-- 		ActivateProfile({
		-- 			essencesSet = frame.set.setID;
		-- 		});
		-- 	elseif button.isHeader then
		-- 		setScrollFrameCollapsed.essences[button.id] = not setScrollFrameCollapsed.essences[button.id] and true or nil;
		-- 		EssencesTabUpdate(frame);
		-- 	else
		-- 		if IsModifiedClick("SHIFT") then
		-- 			ActivateProfile({
		-- 				essencesSet = button.id;
		-- 			});
		-- 		else
		-- 			frame.Name:ClearFocus();
		-- 			self:SetEssenceSet(GetEssenceSet(button.id));
		-- 		end
		-- 	end
		-- elseif selectedTab == TAB_EQUIPMENT then
		-- 	local frame = self.Equipment;
		-- 	if button.isAdd then
		-- 		frame.Name:ClearFocus();
		-- 		self:SetEquipmentSet(AddEquipmentSet());
		-- 		C_Timer.After(0, function ()
		-- 			frame.Name:HighlightText();
		-- 			frame.Name:SetFocus();
		-- 		end);
		-- 	elseif button.isDelete then
		-- 		local set = frame.set;
		-- 		if set.useCount > 0 then
		-- 			StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
		-- 				set = set,
		-- 				func = DeleteEquipmentSet,
		-- 			});
		-- 		else
		-- 			StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
		-- 				set = set,
		-- 				func = DeleteEquipmentSet,
		-- 			});
		-- 		end
		-- 	elseif button.isActivate then
		-- 		ActivateProfile({
		-- 			equipmentSet = frame.set.setID;
		-- 		});
		-- 	elseif button.isHeader then
		-- 		setScrollFrameCollapsed.equipment[button.id] = not setScrollFrameCollapsed.equipment[button.id] and true or nil;
		-- 		EquipmentTabUpdate(frame);
		-- 	else
		-- 		if IsModifiedClick("SHIFT") then
		-- 			ActivateProfile({
		-- 				equipmentSet = button.id;
		-- 			});
		-- 		else 
		-- 			frame.Name:ClearFocus();
		-- 			self:SetEquipmentSet(GetEquipmentSet(button.id));
		-- 		end
		-- 	end
		-- elseif selectedTab == TAB_CONDITIONS then
		-- 	local frame = self.Conditions;
		-- 	if button.isAdd then
		-- 		frame.Name:ClearFocus();
		-- 		self:SetConditionSet(AddConditionSet());
		-- 		C_Timer.After(0, function ()
		-- 			frame.Name:HighlightText();
		-- 			frame.Name:SetFocus();
		-- 		end);
		-- 	elseif button.isDelete then
		-- 		local set = frame.set;
		-- 		StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
		-- 			set = set,
		-- 			func = DeleteConditionSet,
		-- 		});
		-- 	else
		-- 		frame.Name:ClearFocus();
		-- 		self:SetConditionSet(GetConditionSet(button.id));
		-- 	end
		-- end
	end
	function BtWLoadoutsFrameMixin:ScrollItemDoubleClick(button)
		CloseDropDownMenus();
		local selectedTab = PanelTemplates_GetSelectedTab(self) or 1;
		if selectedTab == TAB_PROFILES then
			ActivateProfile(GetProfile(button.id));
		elseif selectedTab == TAB_TALENTS then
			local set = GetTalentSet(button.id);
			if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
				ActivateProfile({
					talentSet = button.id;
				});
			end
		elseif selectedTab == TAB_PVP_TALENTS then
			local set = GetPvPTalentSet(button.id);
			if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
				ActivateProfile({
					pvpTalentSet = button.id;
				});
			end
		elseif selectedTab == TAB_ESSENCES then
			ActivateProfile({
				essencesSet = button.id;
			});
		elseif selectedTab == TAB_EQUIPMENT then
			ActivateProfile({
				equipmentSet = button.id;
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
				set = GetProfile(button.id);
				command = format("/btwloadouts activate profile %d", button.id);
				if set.specID then
					icon = select(4, GetSpecializationInfoByID(set.specID));
				end
			end
		elseif selectedTab == TAB_TALENTS then
			if not button.isHeader then
				set = GetTalentSet(button.id);
				command = format("/btwloadouts activate talents %d", button.id);
				if set.specID then
					icon = select(4, GetSpecializationInfoByID(set.specID));
				end
			end
		elseif selectedTab == TAB_PVP_TALENTS then
			if not button.isHeader then
				set = GetPvPTalentSet(button.id);
				command = format("/btwloadouts activate pvptalents %d", button.id);
				if set.specID then
					icon = select(4, GetSpecializationInfoByID(set.specID));
				end
			end
		elseif selectedTab == TAB_ESSENCES then
			if not button.isHeader then
				set = GetEssenceSet(button.id);
				command = format("/btwloadouts activate essences %d", button.id);
			end
		elseif selectedTab == TAB_EQUIPMENT then
			if not button.isHeader then
				set = GetEquipmentSet(button.id);
				if set.managerID then
					C_EquipmentSet.PickupEquipmentSet(set.managerID);
					return;
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
			end

			if macroId then
				PickupMacro(macroId);
			end
		end
	end
	function BtWLoadoutsFrameMixin:OnHelpTipManuallyClosed(closeFlag)
		helpTipIgnored[closeFlag] = true;
		self:Update();
	end
	function BtWLoadoutsFrameMixin:OnNameChanged(text)
		local selectedTab = PanelTemplates_GetSelectedTab(BtWLoadoutsFrame) or 1;
		local tab = GetTabFrame(selectedTab);
		if tab.set and tab.set.name ~= text then
			tab.set.name = text;
			helpTipIgnored["TUTORIAL_RENAME_SET"] = true;
			self:Update();
		end
	end
	function BtWLoadoutsFrameMixin:OnShow()
		if not self.initialized then
			ShowTab(1)
			for _,details in ipairs(tabs) do
				details.onInit(self, details.frame);
			end
			
	
	
	
			-- UIDropDownMenu_SetWidth(self.PvPTalents.SpecDropDown, 170);
			-- UIDropDownMenu_Initialize(self.PvPTalents.SpecDropDown, SpecDropDownInit);
			-- UIDropDownMenu_JustifyText(self.PvPTalents.SpecDropDown, "LEFT");
	
	
			-- UIDropDownMenu_SetWidth(self.Essences.RoleDropDown, 170);
			-- UIDropDownMenu_Initialize(self.Essences.RoleDropDown, RoleDropDownInit);
			-- UIDropDownMenu_JustifyText(self.Essences.RoleDropDown, "LEFT");
			-- self.Essences.Slots = {
			-- 	[115] = self.Essences.MajorSlot,
			-- 	[116] = self.Essences.MinorSlot1,
			-- 	[117] = self.Essences.MinorSlot2,
			-- };
			
			-- HybridScrollFrame_CreateButtons(self.Essences.EssenceList, "BtWLoadoutsAzeriteEssenceButtonTemplate", 4, -3, "TOPLEFT", "TOPLEFT", 0, -1, "TOP", "BOTTOM");
			-- self.Essences.EssenceList.update = EssenceScrollFrameUpdate;
	
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
			
			-- UIDropDownMenu_SetWidth(self.Conditions.ProfileDropDown, 400);
			-- UIDropDownMenu_Initialize(self.Conditions.ProfileDropDown, ProfilesDropDownInit);
			-- UIDropDownMenu_JustifyText(self.Conditions.ProfileDropDown, "LEFT");
			
			-- UIDropDownMenu_SetWidth(self.Conditions.ConditionTypeDropDown, 400);
			-- UIDropDownMenu_Initialize(self.Conditions.ConditionTypeDropDown, ConditionTypeDropDownInit);
			-- UIDropDownMenu_JustifyText(self.Conditions.ConditionTypeDropDown, "LEFT");
			
			-- UIDropDownMenu_SetWidth(self.Conditions.InstanceDropDown, 175);
			-- UIDropDownMenu_Initialize(self.Conditions.InstanceDropDown, InstanceDropDownInit);
			-- UIDropDownMenu_JustifyText(self.Conditions.InstanceDropDown, "LEFT");
			
			-- UIDropDownMenu_SetWidth(self.Conditions.DifficultyDropDown, 175);
			-- UIDropDownMenu_Initialize(self.Conditions.DifficultyDropDown, DifficultyDropDownInit);
			-- UIDropDownMenu_JustifyText(self.Conditions.DifficultyDropDown, "LEFT");
			
			-- UIDropDownMenu_SetWidth(self.Conditions.BossDropDown, 400);
			-- UIDropDownMenu_Initialize(self.Conditions.BossDropDown, BossDropDownInit);
			-- UIDropDownMenu_JustifyText(self.Conditions.BossDropDown, "LEFT");
			
			-- UIDropDownMenu_SetWidth(self.Conditions.AffixesDropDown, 400);
			-- UIDropDownMenu_Initialize(self.Conditions.AffixesDropDown, AffixesDropDownInit);
			-- UIDropDownMenu_JustifyText(self.Conditions.AffixesDropDown, "LEFT");
			self.initialized = true;
		end

		helpTipIgnored["MINIMAP_ICON"] = true;
		StaticPopup_Hide("BTWLOADOUTS_REQUESTACTIVATE");
		StaticPopup_Hide("BTWLOADOUTS_REQUESTMULTIACTIVATE");

		self:Update();
	end
	function BtWLoadoutsFrameMixin:OnHide()
		-- When hiding the main window we are going to assume that something has dramatically changed and completely redo everything
		-- wipe(previousConditionInfo);
		-- wipe(activeConditions);
		-- UpdateConditionsForInstance();
		-- UpdateConditionsForBoss();
		-- UpdateConditionsForAffixes();
		-- TriggerConditions();
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
	if cursorType == "item" then
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
	end
end
function BtWLoadoutsItemSlotButtonMixin:OnLeave()
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

			self:Update();
			return true;
		end
	end
	return false;
end
function BtWLoadoutsItemSlotButtonMixin:SetIgnored(ignored)
	local set = self:GetParent().set;
	set.ignored[self:GetID()] = ignored and true or nil;
	self:Update();
end
function BtWLoadoutsItemSlotButtonMixin:Update()
	local set = self:GetParent().set;
	local slot = self:GetID();
	local ignored = set.ignored[slot];
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

	self.ignoreTexture:SetShown(ignored);
end

do
	local GetCursorPosition = GetCursorPosition;
	-- This is very important, the global functions gives different responses than the math functions
	local cos, sin = math.cos, math.sin;
	local min, max = math.min, math.max;
	local deg, rad = math.deg, math.rad;
	local sqrt = math.sqrt;
	local atan2 = math.atan2;

	local minimapShapes = {
		-- quadrant booleans (same order as SetTexCoord)
		-- {bottom-right, bottom-left, top-right, top-left}
		-- true = rounded, false = squared
		["ROUND"] 			= {true,  true,  true,  true },
		["SQUARE"] 			= {false, false, false, false},
		["CORNER-TOPLEFT"] 		= {false, false, false, true },
		["CORNER-TOPRIGHT"] 		= {false, false, true,  false},
		["CORNER-BOTTOMLEFT"] 		= {false, true,  false, false},
		["CORNER-BOTTOMRIGHT"]	 	= {true,  false, false, false},
		["SIDE-LEFT"] 			= {false, true,  false, true },
		["SIDE-RIGHT"] 			= {true,  false, true,  false},
		["SIDE-TOP"] 			= {false, false, true,  true },
		["SIDE-BOTTOM"] 		= {true,  true,  false, false},
		["TRICORNER-TOPLEFT"] 		= {false, true,  true,  true },
		["TRICORNER-TOPRIGHT"] 		= {true,  false, true,  true },
		["TRICORNER-BOTTOMLEFT"] 	= {true,  true,  false, true },
		["TRICORNER-BOTTOMRIGHT"] 	= {true,  true,  true,  false},
	};

	BtWLoadoutsMinimapMixin = {};
	function BtWLoadoutsMinimapMixin:OnLoad()
		self:RegisterForClicks("anyUp");
		self:RegisterForDrag("LeftButton");
		self:RegisterEvent("PLAYER_LOGIN");
	end
	function BtWLoadoutsMinimapMixin:OnEvent(event, ...)
		self:SetShown(Settings.minimapShown);
		self:Reposition(Settings.minimapAngle or 195);

		local button = self;
		Minimap:HookScript("OnSizeChanged", function ()
			button:Reposition(Settings.minimapAngle or 195);
		end)
	end
	function BtWLoadoutsMinimapMixin:OnDragStart()
		self:LockHighlight();
		self:SetScript("OnUpdate", self.OnUpdate);
	end
	function BtWLoadoutsMinimapMixin:OnDragStop()
		self:UnlockHighlight();
		self:SetScript("OnUpdate", nil);
	end
	function BtWLoadoutsMinimapMixin:Reposition(degrees)
		local rounding = 10;
		local angle = rad(degrees or 195);
		local x, y;
		local cos = cos(angle);
		local sin = sin(angle);
		local q = 1;
		if cos < 0 then
			q = q + 1;	-- lower
		end
		if sin > 0 then
			q = q + 2;	-- right
		end

		local hRadius = Minimap:GetWidth() / 2 + 5
		local vRadius = Minimap:GetHeight() / 2 + 5

		local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND";
		local quadTable = minimapShapes[minimapShape];
		if quadTable[q] then
			x = cos * hRadius;
			y = sin * vRadius;
		else
			local hDiagRadius = sqrt(2*(hRadius)^2) - rounding
			local vDiagRadius = sqrt(2*(vRadius)^2) - rounding

			x = max(-hRadius, min(cos * hDiagRadius, hRadius));
			y = max(-vRadius, min(sin * vDiagRadius, vRadius));
		end
		
		self:SetPoint("CENTER", "$parent", "CENTER", x, y);
	end
	function BtWLoadoutsMinimapMixin:OnUpdate()
		local px,py = GetCursorPosition();
		local mx,my = Minimap:GetCenter();
		
		local scale = Minimap:GetEffectiveScale();
		px, py = px / scale, py / scale;
		
		local angle = deg(atan2(py - my, px - mx));

		Settings.minimapAngle = angle;

		self:Reposition(angle);
	end
	function BtWLoadoutsMinimapMixin:OnClick(button)
		if button == "LeftButton" then
			BtWLoadoutsFrame:SetShown(not BtWLoadoutsFrame:IsShown());
		elseif button == "RightButton" then
			if not self.Menu then
				self.Menu = CreateFrame("Frame", self:GetName().."Menu", self, "UIDropDownMenuTemplate");
				UIDropDownMenu_Initialize(self.Menu, BtWLoadoutsMinimapMenu_Init, "MENU");
			end
			
			ToggleDropDownMenu(1, nil, self.Menu, self, 0, 0);
		end
	end
	function BtWLoadoutsMinimapMixin:OnEnter()
		helpTipIgnored["MINIMAP_ICON"] = true;
		self.PulseAlpha:Stop();

		GameTooltip:SetOwner(self, "ANCHOR_LEFT");
		GameTooltip:SetText(L["BtWLoadouts"], 1, 1, 1);
		GameTooltip:AddLine(L["Click to open BtWLoadouts.\nRight Click to enable and disable settings."], nil, nil, nil, true);
		GameTooltip:Show();
	end
	function BtWLoadoutsMinimapMixin:OnLeave()
		GameTooltip:Hide();
	end
	local items = {}
	function BtWLoadoutsMinimapMenu_Init(self, level, menuList)
		if level == 1 then
			wipe(items)
			for id, set in pairs(BtWLoadoutsSets.profiles) do
				if type(set) == "table" then
					if select(5, IsProfileValid(set)) then
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

			local info = UIDropDownMenu_CreateInfo();

			if #items > 0 then
				info.isTitle, info.disabled, info.notCheckable = true, true, true;
				info.text = L["Profiles"];

				UIDropDownMenu_AddButton(info, level);
				
				info.isTitle, info.disabled, info.notCheckable = false, false, false;
				info.func = function (self, id)
					local set = BtWLoadoutsSets.profiles[id]
					if set then
						ActivateProfile(set)
					end
				end
				for _,set in ipairs(items) do
					info.text = set.name;
					info.arg1 = set.setID;
					info.checked = IsProfileActive(set)
		
					UIDropDownMenu_AddButton(info, level);
				end
				
				info.isTitle, info.disabled, info.notCheckable = true, true, true;
				info.func, info.arg1 = nil, nil;
				info.text = L["Settings"];

				UIDropDownMenu_AddButton(info, level);
			end
			
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
		end
	end
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

-- [[ Slash Command ]]
-- /btwloadouts activate profile Raid
-- /btwloadouts activate talents Outlaw: Mythic Plus
SLASH_BTWLOADOUTS1 = "/btwloadouts"
SlashCmdList["BTWLOADOUTS"] = function (msg)
	local command, rest = msg:match("^[%s]*([^%s]+)(.*)");
	if command == "activate" then
		local aType, rest = rest:match("^[%s]*([^%s]+)(.*)");
		local set;
		if aType == "profile" then
			if tonumber(rest) then
				set = GetProfile(tonumber(rest));
			else
				set = GetProfileByName(rest);
			end
		elseif aType == "talents" then
			local subset;
			if tonumber(rest) then
				subset = GetTalentSet(tonumber(rest));
			else
				subset = GetTalentSetByName(rest);
			end
			if subset then
				set = {
					talentSet = subset.setID;
				}
			end
		elseif aType == "pvptalents" then
			local subset;
			if tonumber(rest) then
				subset = GetPvPTalentSet(tonumber(rest));
			else
				subset = GetPvPTalentSetByName(rest);
			end
			if subset then
				set = {
					pvpTalentSet = subset.setID;
				}
			end
		elseif aType == "essences" then
			local subset;
			if tonumber(rest) then
				subset = GetEssenceSet(tonumber(rest));
			else
				subset = GetEssenceSetByName(rest);
			end
			if subset then
				set = {
					essencesSet = subset.setID;
				}
			end
		elseif aType == "equipment" then
			local subset;
			if tonumber(rest) then
				subset = GetEquipmentSet(tonumber(rest));
			else
				subset = GetEquipmentSetByName(rest);
			end
			if subset then
				set = {
					equipmentSet = subset.setID;
				}
			end
		else
			-- Assume profile
			rest = aType .. rest;
			if tonumber(rest) then
				set = GetProfile(tonumber(rest));
			else
				set = GetProfileByName(rest);
			end
		end
		if set and select(5,IsProfileValid(set)) then
			if not IsProfileActive(set) then
				ActivateProfile(set);
			end
		else
			print(L["Could not find a valid set"]);
		end
	elseif command == "minimap" then
		Settings.minimapShown = not Settings.minimapShown;
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
					if select(5, IsProfileValid(set)) then
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
				add("btwloadoutprofile", set.setID)
			end
		end
		
		do
			wipe(items)
			for id, set in pairs(BtWLoadoutsSets.talents) do
				if type(set) == "table" then
					if select(5, IsProfileValid({
						talentSet = set
					})) then
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
					if select(5, IsProfileValid({
						pvpTalentSet = set
					})) then
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
					if select(5, IsProfileValid({
						essencesSet = set
					})) then
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
					if select(5, IsProfileValid({
						equipmentSet = set
					})) then
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
			local usable = select(5, IsProfileValid(set))
			return usable, false, nil, set.name
		end
		local function activate(id)
			local set = BtWLoadoutsSets.profiles[id]
			if set then
				ActivateProfile(set)
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
			local usable = select(5, IsProfileValid({
				talentSet = set.setID;
			}))
			return usable, false, nil, set.name
		end
		local function activate(id)
			local set = BtWLoadoutsSets.talents[id]
			if set then
				ActivateProfile({
					talentSet = set.setID;
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
			local usable = select(5, IsProfileValid({
				pvpTalentSet = set.setID;
			}))
			return usable, false, nil, set.name
		end
		local function activate(id)
			local set = BtWLoadoutsSets.pvptalents[id]
			if set then
				ActivateProfile({
					pvpTalentSet = set.setID;
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
			local usable = select(5, IsProfileValid({
				essencesSet = set.setID;
			}))
			return usable, false, nil, set.name
		end
		local function activate(id)
			local set = BtWLoadoutsSets.essences[id]
			if set then
				ActivateProfile({
					essencesSet = set.setID;
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
			local usable = select(5, IsProfileValid({
				equipmentSet = set.setID;
			}))
			return usable, false, nil, set.name
		end
		local function activate(id)
			local set = BtWLoadoutsSets.equipment[id]
			if set then
				ActivateProfile({
					equipmentSet = set.setID;
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
