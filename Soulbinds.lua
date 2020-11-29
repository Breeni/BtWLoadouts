-- if not C_Covenants or GetExpansionLevel() ~= 8 then -- Skip for pre-Shadowlands
--     return
-- end
BTWLOADOUTS_SOULBINDS_ACTIVE = GetExpansionLevel() == 8

local ADDON_NAME,Internal = ...
local L = Internal.L

local GetActiveCovenantID = C_Covenants.GetActiveCovenantID
local GetCovenantIDs = C_Covenants.GetCovenantIDs
local GetCovenantData = C_Covenants.GetCovenantData
local ActivateSoulbind = C_Soulbinds.ActivateSoulbind
local GetActiveSoulbindID = C_Soulbinds.GetActiveSoulbindID
local GetSoulbindData = C_Soulbinds.GetSoulbindData
local GetSoulbindNode = C_Soulbinds.GetNode
local SelectSoulbindNode = C_Soulbinds.SelectNode

--[[ SOULBIND DROPDOWN ]]

local function SoulbindDropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Soulbinds;

	CloseDropDownMenus();
	local set = tab.set;

    local temp = tab.temp;
    local soulbindID = set.soulbindID;
    if temp[soulbindID] then
        wipe(temp[soulbindID]);
    else
        temp[soulbindID] = {};
    end
    for nodeID in pairs(set.nodes) do
        temp[soulbindID][nodeID] = true;
    end

    -- Clear the current talents and copy back the previously selected talents if they exist
    soulbindID = arg1;
    set.soulbindID = soulbindID;
    wipe(set.nodes);
    if temp[soulbindID] then
        for nodeID in pairs(temp[soulbindID]) do
            set.nodes[nodeID] = true;
        end
    end
	BtWLoadoutsFrame:Update();
end
local function SoulbindDropDownInit(self, level, menuList)
	local info = UIDropDownMenu_CreateInfo();

	local set = self:GetParent().set;
	local selected = set and set.soulbindID;

	if (level or 1) == 1 then
		if self.includeNone then
			info.text = L["None"];
			info.func = SoulbindDropDown_OnClick;
			info.checked = selected == nil;
			UIDropDownMenu_AddButton(info, level);
		end

        for _,covenantID in ipairs(GetCovenantIDs()) do
            local covenantData = GetCovenantData(covenantID)

            info.text = covenantData.name;
            info.hasArrow, info.menuList = true, covenantData.ID;
            info.keepShownOnClick = true;
            info.notCheckable = true;
            UIDropDownMenu_AddButton(info, level);
        end
	else
        local covenantData = GetCovenantData(menuList)
        for _,soulbindID in ipairs(covenantData.soulbindIDs) do
            local soulbindData = GetSoulbindData(soulbindID)

            info.text = soulbindData.name;
			info.arg1 = soulbindData.ID;
            info.func = SoulbindDropDown_OnClick;
            info.checked = selected == soulbindData.ID;
            UIDropDownMenu_AddButton(info, level);
        end
	end
end
BtWLoadoutsSoulbindDropDownMixin = {}
function BtWLoadoutsSoulbindDropDownMixin:OnShow()
	if not self.initialized then
		UIDropDownMenu_Initialize(self, SoulbindDropDownInit);
		self.initialized = true
	end
end

--[[ SET HANDLING ]]

local function UpdateSetFilters(set)
    set.filters = set.filters or {}
    wipe(set.filters)

    return set
end
local function RefreshSet(set)
    local nodes = set.nodes or {}
    wipe(nodes)
    local soulbindData = GetSoulbindData(set.soulbindID)
    for _,node in ipairs(soulbindData.tree.nodes) do
        if node.state == Enum.SoulbindNodeState.Selected then
            nodes[node.ID] = true
        end
    end
    set.nodes = nodes

    return UpdateSetFilters(set)
end
local function AddSet()
    local soulbindID = GetActiveSoulbindID() or 7 -- Default to pelagos because why not
    local soulbindData = GetSoulbindData(soulbindID)
    return Internal.AddSet("soulbinds", RefreshSet({
        soulbindID = soulbindID,
		name = format(L["New %s Set"], soulbindData.name),
		useCount = 0,
        nodes = {},
    }))
end
local function DeleteSet(id)
	Internal.DeleteSet(BtWLoadoutsSets.soulbinds, id);

	if type(id) == "table" then
		id = id.setID;
	end
	for _,set in pairs(BtWLoadoutsSets.profiles) do
        if type(set) == "table" then
            for index,setID in ipairs(set.soulbinds) do
                if setID == id then
                    table.remove(set.soulbinds, index)
                end
            end
		end
	end

	local frame = BtWLoadoutsFrame.Soulbinds;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil
		BtWLoadoutsFrame:Update();
	end
end
local function GetSet(id)
    if type(id) == "table" then
		return id;
    elseif id < 0 then -- Fake a soulbind set
        local set = GetSoulbindData(math.abs(id))
        set.soulbindID = set.ID
        set.setID = -set.ID
        set.ID = nil
        return set
    else
		return BtWLoadoutsSets.soulbinds[id]
	end
end
local function GetSets(id, ...)
    if id ~= nil then
		return GetSet(id), GetSets(...);
	end
end
local function IsSetActive(set)
    if set.soulbindID then
        local covenantID = GetActiveCovenantID()
        if covenantID then
            local soulbindID = GetActiveSoulbindID()
            local soulbindData = GetSoulbindData(set.soulbindID)
            -- The target soulbind is unlocked, is for the players covenant, so is valid for the character
            if soulbindData.unlocked and soulbindData.covenantID == covenantID then
                if set.soulbindID == soulbindID then
                    if set.nodes then
                        for nodeID in pairs(set.nodes) do
                            local node = GetSoulbindNode(nodeID)
                            if node.state ~= Enum.SoulbindNodeState.Selected and node.state ~= Enum.SoulbindNodeState.Unavailable then
                                return false
                            end
                        end
                        return true
                    else
                        return true
                    end
                else
                    return false
                end
            end
        end
    end

    return true;
end
local function CombineSets(result, state, ...)
	result = result or {};

    local covenantID = GetActiveCovenantID()
    if covenantID then
        for i=1,select('#', ...) do
            local set = select(i, ...);
            local soulbindData = GetSoulbindData(set.soulbindID)
            if soulbindData.covenantID == covenantID and soulbindData.unlocked then
                result.soulbindID = set.soulbindID
                result.nodes = set.nodes
            end
        end

        local soulbindID = GetActiveSoulbindID()
        if state and not IsSetActive(result) then
            state.combatSwap = false
            state.taxiSwap = false -- Maybe check for rested area or tomb first?
            state.needTome = true
        end
    end

	return result;
end
local function ActivateSet(set)
    local complete = true;

    if not IsSetActive(set) then
        local soulbindData = GetSoulbindData(set.soulbindID)
        Internal.LogMessage("Switching soulbind to %s", soulbindData.name)

        ActivateSoulbind(set.soulbindID)
        if set.nodes then
            for nodeID in pairs(set.nodes) do
                local node = GetSoulbindNode(nodeID)
                if node.state ~= Enum.SoulbindNodeState.Selected and node.state ~= Enum.SoulbindNodeState.Unavailable then
                    SelectSoulbindNode(nodeID)
                end
            end
        end

        complete = false
    end

	return complete
end

local function DropDown_OnClick(self, arg1, arg2, checked)
	local tab = BtWLoadoutsFrame.Profiles

    CloseDropDownMenus();
    local set = tab.set;
    set.soulbinds = set.soulbinds or {}

    local index = arg2 or (#set.soulbinds + 1)

	if arg1 == nil then
		table.remove(set.soulbinds, index);
	else
		set.soulbinds[index] = arg1;
	end

	BtWLoadoutsFrame:Update();
end
local setsFiltered = {}
local function DropDownInit(self, level, menuList, index)
	local info = UIDropDownMenu_CreateInfo();

	local tab = BtWLoadoutsFrame.Profiles

	local set = tab.set;
	local selected = set and set.soulbinds and set.soulbinds[index];

    info.arg2 = index

    if (level or 1) == 1 then
		info.text = NONE;
        info.func = DropDown_OnClick;
		info.checked = selected == nil;
        UIDropDownMenu_AddButton(info, level);

        for _,covenantID in ipairs(GetCovenantIDs()) do
            local covenantData = GetCovenantData(covenantID)

            info.text = covenantData.name;
            info.hasArrow, info.menuList = true, covenantData.ID;
            info.keepShownOnClick = true;
            info.notCheckable = true;
            UIDropDownMenu_AddButton(info, level);
        end
    else
        local covenantData = GetCovenantData(menuList)
        for _,soulbindID in ipairs(covenantData.soulbindIDs) do
            local soulbindData = GetSoulbindData(soulbindID)

            info.text = soulbindData.name;
			info.arg1 = -soulbindData.ID;
            info.func = DropDown_OnClick;
            info.checked = selected == -soulbindData.ID;
            UIDropDownMenu_AddButton(info, level);
        end

		wipe(setsFiltered);
		local sets = BtWLoadoutsSets.soulbinds;
		for setID,subset in pairs(sets) do
			if type(subset) == "table" and GetSoulbindData(subset.soulbindID).covenantID == menuList then
				setsFiltered[#setsFiltered+1] = setID;
			end
		end
		sort(setsFiltered, function (a,b)
			return sets[a].name < sets[b].name;
        end)

        if #setsFiltered > 0 then
            UIDropDownMenu_AddSeparator(level)

            for _,setID in ipairs(setsFiltered) do
                info.text = sets[setID].name;
                info.arg1 = setID;
                info.func = DropDown_OnClick;
                info.checked = selected == setID;
                UIDropDownMenu_AddButton(info, level);
            end
        end
    end
end

Internal.AddLoadoutSegment({
    id = "soulbinds",
    name = L["Soulbinds"],
    events = "SOULBIND_ACTIVATED",
    enabled = BTWLOADOUTS_SOULBINDS_ACTIVE,
    get = GetSets,
    combine = CombineSets,
    isActive = IsSetActive,
	activate = ActivateSet,
	dropdowninit = DropDownInit,
})

-- [[ TAB UI ]]

local function GetConduitEmblemAtlas(conduitType)
	if conduitType == Enum.SoulbindConduitType.Potency then
		return "Soulbinds_Tree_Conduit_Icon_Attack";
	elseif conduitType == Enum.SoulbindConduitType.Endurance then
		return "Soulbinds_Tree_Conduit_Icon_Protect";
	elseif conduitType == Enum.SoulbindConduitType.Finesse then
		return "Soulbinds_Tree_Conduit_Icon_Utility";
	end
end
BtWLoadoutsSoulbindNodeMixin = {}
function BtWLoadoutsSoulbindNodeMixin:SetNode(node)
    self.node = node
    self.Icon:SetTexture(node.icon)

    if node.conduitType ~= nil then
        local atlas = GetConduitEmblemAtlas(node.conduitType);

        self.Emblem:Show()
        self.EmblemBg:Show()
        self.Emblem:SetAtlas(atlas);
        self.EmblemBg:SetAtlas(atlas)
        self.EmblemBg:SetVertexColor(0, 0, 0);

		self.Icon:Hide();
		self.Ring:SetAtlas("Soulbinds_Tree_Conduit_Ring", false);
		self.MouseOverlay:SetAtlas("Soulbinds_Tree_Conduit_Ring", false);
    else
        self.Emblem:Hide()
        self.EmblemBg:Hide()
		self.Icon:Show();
		self.Ring:SetAtlas("Soulbinds_Tree_Ring", false);
		self.MouseOverlay:SetAtlas("Soulbinds_Tree_Ring", false);
	end
end
function BtWLoadoutsSoulbindNodeMixin:SetSelected(selected)
    if not selected then
		self.Icon:SetDesaturated(false);
		self.IconOverlay:Show();
		self.Ring:SetDesaturated(true);
		self.MouseOverlay:SetDesaturated(true);
	else
		self.Icon:SetDesaturated(false);
		self.IconOverlay:Hide();
		self.Ring:SetDesaturated(false);
		self.MouseOverlay:SetDesaturated(false);
	end
end
function BtWLoadoutsSoulbindNodeMixin:OnClick()
    local container = self:GetParent()
    local node = self.node
    local nodes = container.set.nodes
    local selected = not nodes[node.ID]

    while node.childNodeIDs and #node.childNodeIDs == 1 do
        local childID = node.childNodeIDs[1]

        if #container.nodesByID[childID].node.parentNodeIDs ~= 1 then
            break
        end

        node = container.nodesByID[childID].node
    end

    for _,frame in pairs(container.nodesByID) do
        if frame.node.row == node.row then
            nodes[frame.node.ID] = nil
        end
    end
    nodes[node.ID] = selected and true or nil

    while #node.parentNodeIDs == 1 do
        local parentID = node.parentNodeIDs[1]
        node = container.nodesByID[parentID].node

        if not node.childNodeIDs or #node.childNodeIDs ~= 1 then
            break
        end

        for _,frame in pairs(container.nodesByID) do
            if frame.node.row == node.row then
                nodes[frame.node.ID] = nil
            end
        end
        nodes[node.ID] = selected and true or nil
    end

    container:Update()
end
function BtWLoadoutsSoulbindNodeMixin:OnEnter()
	self.MouseOverlay:Show();
end
function BtWLoadoutsSoulbindNodeMixin:OnLeave()
	self.MouseOverlay:Hide();
end

local SoulbindTreeLinkDirections = {
	Vertical = 1,
	Converge = 2,
	Diverge = 3,
};

BtWLoadoutsSoulbindTreeNodeLinkMixin = {}
function BtWLoadoutsSoulbindTreeNodeLinkMixin:Init(direction, angle)
	if direction == SoulbindTreeLinkDirections.Vertical then
		self.Background:SetAtlas("Soulbinds_Tree_Connector_Vertical", true);
		self.FillMask:SetAtlas("Soulbinds_Tree_Connector_Vertical_Mask", true);
	elseif direction == SoulbindTreeLinkDirections.Converge then
		self.Background:SetAtlas("Soulbinds_Tree_Connector_Diagonal_Close", true);
		self.FillMask:SetAtlas("Soulbinds_Tree_Connector_Diagonal_Close_Mask", true);
	elseif direction == SoulbindTreeLinkDirections.Diverge then
		self.Background:SetAtlas("Soulbinds_Tree_Connector_Diagonal_Far", true);
		self.FillMask:SetAtlas("Soulbinds_Tree_Connector_Diagonal_Far_Mask", true);
	end

	self:RotateTextures(angle);
end
function BtWLoadoutsSoulbindTreeNodeLinkMixin:OnHide()
	self.FlowAnim1:Stop();
	self.FlowAnim2:Stop();
	self.FlowAnim3:Stop();
	self.FlowAnim4:Stop();
	self.FlowAnim5:Stop();
	self.FlowAnim6:Stop();
end
function BtWLoadoutsSoulbindTreeNodeLinkMixin:Reset()
	self:SetState(Enum.SoulbindNodeState.Unselected);
end
function BtWLoadoutsSoulbindTreeNodeLinkMixin:SetState(state)
	self.state = state;

	if state == Enum.SoulbindNodeState.Unselected or state == Enum.SoulbindNodeState.Unavailable then
		self:DesaturateHierarchy(1);
		for _, foreground in ipairs(self.foregrounds) do
			foreground:SetShown(false);
		end
		self.FlowAnim1:Stop();
		self.FlowAnim2:Stop();
		self.FlowAnim3:Stop();
		self.FlowAnim4:Stop();
		self.FlowAnim5:Stop();
		self.FlowAnim6:Stop();
	elseif state == Enum.SoulbindNodeState.Selectable then
		self:DesaturateHierarchy(0);
		for _, foreground in ipairs(self.foregrounds) do
			foreground:SetShown(true);
			foreground:SetVertexColor(.3, .3, .3);
		end
		self.FlowAnim1:Play();
		self.FlowAnim2:Play();
		self.FlowAnim3:Play();
		self.FlowAnim4:Play();
		self.FlowAnim5:Play();
		self.FlowAnim6:Play();
	elseif state == Enum.SoulbindNodeState.Selected then
		self:DesaturateHierarchy(0);
		for _, foreground in ipairs(self.foregrounds) do
			foreground:SetShown(true);
			foreground:SetVertexColor(.192, .686, .941);
		end
		self.FlowAnim1:Play();
		self.FlowAnim2:Play();
		self.FlowAnim3:Play();
		self.FlowAnim4:Play();
		self.FlowAnim5:Play();
		self.FlowAnim6:Play();
	end
end
function BtWLoadoutsSoulbindTreeNodeLinkMixin:GetState()
	return self.state;
end

BtWLoadoutsSoulbindsMixin = {}
function BtWLoadoutsSoulbindsMixin:OnLoad()
    self.temp = {}
    self.nodes = CreateFramePool("BUTTON", self, "BtWLoadoutsSoulbindNodeTemplate");
    self.links = CreateFramePool("FRAME", self, "BtWLoadoutsSoulbindTreeNodeLinkTemplate");
    self.nodesByID = {}
end
function BtWLoadoutsSoulbindsMixin:OnShow()
    if not self.initialized then
        UIDropDownMenu_SetWidth(self.SoulbindDropDown, 170);
        UIDropDownMenu_JustifyText(self.SoulbindDropDown, "LEFT");

        self.initialized = true;
    end
end
function BtWLoadoutsSoulbindsMixin:ChangeSet(set)
    self.set = set
    self:Update()
end
function BtWLoadoutsSoulbindsMixin:UpdateSetName(value)
	if self.set and self.set.name ~= not value then
		self.set.name = value;
		self:Update();
	end
end
function BtWLoadoutsSoulbindsMixin:OnButtonClick(button)
	CloseDropDownMenus()
	if button.isAdd then
		BtWLoadoutsHelpTipFlags["TUTORIAL_NEW_SET"] = true;

		self.Name:ClearFocus()
        self:ChangeSet(AddSet())
		C_Timer.After(0, function ()
			self.Name:HighlightText()
			self.Name:SetFocus()
		end)
	elseif button.isDelete then
		local set = self.set
		if set.useCount > 0 then
			StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
				set = set,
				func = DeleteSet,
			})
		else
			StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
				set = set,
				func = DeleteSet,
			})
		end
	elseif button.isRefresh then
        local set = self.set;
        RefreshSet(set)
        self:Update()
	elseif button.isActivate then
        local set = self.set;
        Internal.ActivateProfile({
            soulbinds = {set.setID}
        });
	end
end
function BtWLoadoutsSoulbindsMixin:OnSidebarItemClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		button.collapsed[button.id] = not button.collapsed[button.id]
		self:Update()
	else
        if IsModifiedClick("SHIFT") then
            local set = GetSet(button.id);
            Internal.ActivateProfile({
                soulbinds = {button.id}
            });
        else
            self.Name:ClearFocus();
            self:ChangeSet(GetSet(button.id))
        end
	end
end
function BtWLoadoutsSoulbindsMixin:OnSidebarItemDoubleClick(button)
	CloseDropDownMenus()
	if button.isHeader then
		return
	end

    local set = GetSet(button.id);
    Internal.ActivateProfile({
        soulbinds = {button.id}
    });
end
function BtWLoadoutsSoulbindsMixin:OnSidebarItemDragStart(button)
	CloseDropDownMenus()
	if button.isHeader then
		return
	end

	local icon = "INV_Misc_QuestionMark";
	local set = GetSet(button.id);
	local command = format("/btwloadouts activate soulbinds %d", button.id);
	if set.specID then
		icon = select(4, GetSpecializationInfoByID(set.specID));
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
function BtWLoadoutsSoulbindsMixin:Update()
    self:GetParent().TitleText:SetText(L["Soulbinds"]);
	local sidebar = BtWLoadoutsFrame.Sidebar

	sidebar:SetSupportedFilters()
	sidebar:SetSets(BtWLoadoutsSets.soulbinds)
	sidebar:SetCollapsed(BtWLoadoutsCollapsed.soulbinds)
	sidebar:SetCategories(BtWLoadoutsCategories.soulbinds)
	sidebar:SetFilters(BtWLoadoutsFilters.soulbinds)
	sidebar:SetSelected(self.set)

	sidebar:Update()
	self.set = sidebar:GetSelected()

    if self.set ~= nil then
        self.Name:SetEnabled(true);

        local soulbindID = self.set.soulbindID;
        local soulbindData = GetSoulbindData(soulbindID)

		local set = self.set

		UpdateSetFilters(set)
        sidebar:Update()

        if not self.Name:HasFocus() then
            self.Name:SetText(self.set.name or "");
        end

        UIDropDownMenu_SetSelectedValue(self.SoulbindDropDown, soulbindID);
        UIDropDownMenu_SetText(self.SoulbindDropDown, soulbindData.name);
        UIDropDownMenu_EnableDropDown(self.SoulbindDropDown);
        
        local selected = self.set.nodes;
        self.nodes:ReleaseAll()
        self.links:ReleaseAll()
        -- wipe(self.nodesByRow)
        for _,node in ipairs(soulbindData.tree.nodes) do
            local nodeFrame = self.nodes:Acquire()
            nodeFrame:SetFrameLevel(4)
            nodeFrame:SetPoint("TOP", self.Inset, "TOP", (node.column - 1) * (nodeFrame:GetWidth() + 30), -node.row * (nodeFrame:GetHeight() + 12) - 17)
            nodeFrame:SetNode(node)
            nodeFrame:SetSelected(selected[node.ID])
            nodeFrame:Show()

            self.nodesByID[node.ID] = nodeFrame
        end
		for _, linkFromFrame in pairs(self.nodesByID) do
            if linkFromFrame.node.row > 0 then
                for _,parentID in ipairs(linkFromFrame.node.parentNodeIDs) do
                    local linkToFrame = self.nodesByID[parentID]
                    linkToFrame.node.childNodeIDs = linkToFrame.node.childNodeIDs or {}
                    linkToFrame.node.childNodeIDs[#linkToFrame.node.childNodeIDs+1] = linkFromFrame.node.ID

                    local linkFrame = self.links:Acquire()

					local toColumn = linkToFrame.node.column;
					local fromColumn = linkFromFrame.node.column;
                    local offset = toColumn - fromColumn;
					
					if offset < 0 then
						linkFrame:SetPoint("BOTTOMRIGHT", linkFromFrame, "CENTER");
						linkFrame:SetPoint("TOPLEFT", linkToFrame, "CENTER");
					elseif offset > 0 then
						linkFrame:SetPoint("BOTTOMLEFT", linkFromFrame, "CENTER");
						linkFrame:SetPoint("TOPRIGHT", linkToFrame, "CENTER");
					else
						linkFrame:SetPoint("BOTTOM", linkFromFrame, "CENTER");
						linkFrame:SetPoint("TOP", linkToFrame, "CENTER");
					end

					local direction;
					local diagonal = toColumn ~= fromColumn;
                    if diagonal then
                        direction = SoulbindTreeLinkDirections.Converge
					else
						direction = SoulbindTreeLinkDirections.Vertical;
					end

					local quarter = (math.pi * 0.5);
					local angle = RegionUtil.CalculateAngleBetween(linkToFrame, linkFromFrame) - quarter;

                    linkFrame:Init(direction, angle);
                    linkFrame:SetState((selected[linkToFrame.node.ID] and selected[linkFromFrame.node.ID]) and Enum.SoulbindNodeState.Selected or Enum.SoulbindNodeState.Unselected);
					linkFrame:Show();
                end
            end
        end

        local playerCovenantID = GetActiveCovenantID()
        local playerSoulbindID = GetActiveSoulbindID()
        self:GetParent().RefreshButton:SetEnabled(soulbindID == playerSoulbindID)

        local activateButton = self:GetParent().ActivateButton;
        activateButton:SetEnabled(soulbindData.covenantID == playerCovenantID and soulbindData.unlocked);

        local deleteButton =  self:GetParent().DeleteButton;
        deleteButton:SetEnabled(true);

        local helpTipBox = self:GetParent().HelpTipBox;
        helpTipBox:Hide();

        local addButton = self:GetParent().AddButton;
        addButton.Flash:Hide();
        addButton.FlashAnim:Stop();
    else
        self.nodes:ReleaseAll()
        self.links:ReleaseAll()
        self.Name:SetEnabled(false);
        UIDropDownMenu_DisableDropDown(self.SoulbindDropDown);
        -- self.SoulbindDropDown.Button:SetEnabled(false);
        -- for _,row in ipairs(self.rows) do
        --     row:SetShown(false);
        -- end

        self.Name:SetText("");

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
