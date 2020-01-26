-- Create and update LDB launcher
local ADDON_NAME, Internal = ...;
local L = Internal.L;

local launcher
function Internal.CreateLauncher()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if LDB then
        launcher = LDB:NewDataObject("BtWLoadOuts", {
            type = "data source",
            label = L["BtWLoadouts"],
            icon = [[Interface\ICONS\Ability_marksmanship]],
            OnClick = function(clickedframe, button)
                if button == "LeftButton" then
                    BtWLoadoutsFrame:SetShown(not BtWLoadoutsFrame:IsShown());
                elseif button == "RightButton" then
                    if not BtWLoadoutsMinimapButton.Menu then
                        BtWLoadoutsMinimapButton.Menu = CreateFrame("Frame", BtWLoadoutsMinimapButton:GetName().."Menu", BtWLoadoutsMinimapButton, "UIDropDownMenuTemplate");
                        UIDropDownMenu_Initialize(BtWLoadoutsMinimapButton.Menu, BtWLoadoutsMinimapMenu_Init, "MENU");
                    end

                    ToggleDropDownMenu(1, nil, BtWLoadoutsMinimapButton.Menu, clickedframe, 0, -5);
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:SetText(L["BtWLoadouts"], 1, 1, 1);
                tooltip:AddLine(L["Click to open BtWLoadouts.\nRight Click to enable and disable settings."], nil, nil, nil, true);
            end,
        })
    end
end

function Internal.UpdateLauncher(text)
    if launcher then
        launcher.text = text
    end
end
