-- Define Localization table

local _, Internal = ...

local L = {}
setmetatable(L, {
    __index = function (self, key)
        return key
    end,
})
Internal.L = L

-- Fallbacks for items missing translations
L["Talents"] = TALENTS
L["PvP Talents"] = PVP_TALENTS
L["Equipment"] = BAG_FILTER_EQUIPMENT
L["New Set"] = PAPERDOLL_NEWEQUIPMENTSET
L["Activate"] = TALENT_SPEC_ACTIVATE
L["Delete"] = DELETE
L["Name"] = NAME
L["Specialization"] = SPECIALIZATION
L["None"] = NONE
L["New"] = NEW
L["World"] = WORLD
L["Dungeons"] = DUNGEONS
L["Raids"] = RAIDS
L["Arena"] = ARENA
L["Battlegrounds"] = BATTLEGROUNDS
L["Other"] = OTHER
L["Enabled"] = VIDEO_OPTIONS_ENABLED