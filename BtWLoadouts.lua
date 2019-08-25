--[[@TODO
	Minimap icon should show progress texture and help box
	Profiles need to support multiple sets of the same type
	Equipment popout
	Equipment sets should store location
	Equipment sets should store transmog?
	OPIE intergration
	Profile keybindings
	Talent, equipment, etc. lock checking
	Conditions need to supoort boss, affixes and arena comp
	Localization
	Update new set text button based on tab?
]]

local ADDON_NAME = ...;

local GetCursorItemSource;

local L = {};
setmetatable(L, {
    __index = function (self, key)
        return key;
    end,
});

if GetLocale() == "zhTW" then
	-- Thanks to BNS333 on Curse
	L["Profile"] = "設定檔"
	L["Profiles"] = "設定檔"
	L["Essences"] = "精華"
	L["Conditions"] = "環境"
	L["Classic"] = "經典版"
	L["TBC"] = "燃燒的遠征"
	L["Wrath"] = "巫妖王之怒"
	L["Cata"] = "浩劫與重生"
	L["Panda"] = "潘達利亞之謎"
	L["WoD"] = "德拉諾之霸"
	L["Legion"] = "軍臨天下"
	L["Battle For Azeroth"] = "決戰艾澤拉斯"
	L["Show minimap icon"] = "顯示小地圖按鈕"
	L["Activate profile %s?"] = "啟動設定檔 %s？"
	L["Activate the following profile?\n"] = "啟動以下的設定檔？\n"
	L["Activate spec %s?\nThis set will require a tome or rested to activate"] = "啟動專精 %s？\n此設定需要靜心之卷或休息區域來啟動"
	L["Activate spec %s?\nThis will use a Tome"] = "啟動專精 %s？\n這會用掉一個靜心之卷"
	L["A tome is needed to continue equiping your set."] = "要繼續裝備您的設定一個靜心之卷是需要的。"
	L["Are you sure you wish to delete the set \"%s\". This cannot be reversed."] = "您確定想要刪除設定\"%s\"。這是無法回復的。"
	L["Are you sure you wish to delete the set \"%s\", this set is in use by one or more profiles. This cannot be reversed."] = "您確定想要刪除設定\"%s\"。此設定由一個或多個設定檔使用中。這是無法回復的。"
	L["Any"] = "任何"
	L["To begin, create a new set."] = "要開始前，建立一個新設定。"
	L["Can not equip sets for other characters."] = "無法從其他角色裝備設定。"
	L["Can not edit equipment manager sets."] = "無法編輯換裝管理設定。"
	L["Shift+Left Mouse Button to ignore a slot."] = "Shift+ 滑鼠左鍵來忽略一個部位。"
	L["Cannot create any more macros"] = "無法建立任何更多的巨集"
	L["Cannot create macros while in combat"] = "在戰鬥中無法建立巨集"
	L["Click to open BtWLoadouts.\nRight Click to enable and disable settings."] = "點擊來開啟BtWLoadouts。\n右鍵點擊來啟用與停用設定。"
	L["Could not find a valid set"] = "無法找到有效設定"
	L["New Profile"] = "新設定檔"
	L["Change the name of your new profile."] = "改變您新設定檔的名稱。"
	L["Create a talent set for your new profile."] = "為您的新設定檔建立一套天賦設定。"
	L["Activate your profile."] = "啟動您的設定檔。"
	L["New %s Set"] = "新%s設定"
	L["New %s Equipment Set"] = "新%s裝備設定"
	L["Other"] = "其他"

	-- L["New Condition Set"]
end

L["Talents"] = TALENTS;
L["PvP Talents"] = PVP_TALENTS;
L["Equipment"] = BAG_FILTER_EQUIPMENT;
L["New Set"] = PAPERDOLL_NEWEQUIPMENTSET;
L["Activate"] = TALENT_SPEC_ACTIVATE;
L["Delete"] = DELETE;
L["Name"] = NAME;
L["Specialization"] = SPECIALIZATION;
L["None"] = NONE;
L["New"] = NEW;
L["World"] = WORLD;
L["Dungeons"] = DUNGEONS;
L["Raids"] = RAIDS;
L["Arena"] = ARENA;
L["Battlegrounds"] = BATTLEGROUNDS;
L["Other"] = OTHER;

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

local roles = {"TANK", "HEALER", "DAMAGER"};
local roleIndexes = {["TANK"] = 1, ["HEALER"] = 2, ["DAMAGER"] = 3};
local roleInfo = {
	["DAMAGER"] = {
		["essences"] = {
			23, -- [1]
			14, -- [2]
			32, -- [3]
			5, -- [4]
			27, -- [5]
			6, -- [6]
			15, -- [7]
			12, -- [8]
			28, -- [9]
			22, -- [10]
			4, -- [11]
		},
	},
	["TANK"] = {
		["essences"] = {
			25, -- [1]
			7, -- [2]
			2, -- [3]
			32, -- [4]
			27, -- [5]
			13, -- [6]
			15, -- [7]
			3, -- [8]
			12, -- [9]
			22, -- [10]
			4, -- [11]
		},
	},
	["HEALER"] = {
		["essences"] = {
			18, -- [1]
			32, -- [2]
			20, -- [3]
			27, -- [4]
			15, -- [5]
			12, -- [6]
			17, -- [7]
			19, -- [8]
			22, -- [9]
			21, -- [10]
			4, -- [11]
		},
	},
};
local essenceInfo = {
	nil, -- [1]
	{
		["ID"] = 2,
		["name"] = "Azeroth's Undying Gift",
		["icon"] = 2967107,
	}, -- [2]
	{
		["ID"] = 3,
		["name"] = "Sphere of Suppression",
		["icon"] = 2065602,
	}, -- [3]
	{
		["ID"] = 4,
		["name"] = "Worldvein Resonance",
		["icon"] = 1830317,
	}, -- [4]
	{
		["ID"] = 5,
		["name"] = "Essence of the Focusing Iris",
		["icon"] = 2967111,
	}, -- [5]
	{
		["ID"] = 6,
		["name"] = "Purification Protocol",
		["icon"] = 2967103,
	}, -- [6]
	{
		["ID"] = 7,
		["name"] = "Anima of Life and Death",
		["icon"] = 2967105,
	}, -- [7]
	nil, -- [8]
	nil, -- [9]
	nil, -- [10]
	nil, -- [11]
	{
		["ID"] = 12,
		["name"] = "The Crucible of Flame",
		["icon"] = 3015740,
	}, -- [12]
	{
		["ID"] = 13,
		["name"] = "Nullification Dynamo",
		["icon"] = 3015741,
	}, -- [13]
	{
		["ID"] = 14,
		["name"] = "Condensed Life-Force",
		["icon"] = 2967113,
	}, -- [14]
	{
		["ID"] = 15,
		["name"] = "Ripple in Space",
		["icon"] = 2967109,
	}, -- [15]
	nil, -- [16]
	{
		["ID"] = 17,
		["name"] = "The Ever-Rising Tide",
		["icon"] = 2967108,
	}, -- [17]
	{
		["ID"] = 18,
		["name"] = "Artifice of Time",
		["icon"] = 2967112,
	}, -- [18]
	{
		["ID"] = 19,
		["name"] = "The Well of Existence",
		["icon"] = 516796,
	}, -- [19]
	{
		["ID"] = 20,
		["name"] = "Life-Binder's Invocation",
		["icon"] = 2967106,
	}, -- [20]
	{
		["ID"] = 21,
		["name"] = "Vitality Conduit",
		["icon"] = 2967100,
	}, -- [21]
	{
		["ID"] = 22,
		["name"] = "Vision of Perfection",
		["icon"] = 3015743,
	}, -- [22]
	{
		["ID"] = 23,
		["name"] = "Blood of the Enemy",
		["icon"] = 2032580,
	}, -- [23]
	nil, -- [24]
	{
		["ID"] = 25,
		["name"] = "Aegis of the Deep",
		["icon"] = 2967110,
	}, -- [25]
	nil, -- [26]
	{
		["ID"] = 27,
		["name"] = "Memory of Lucid Dreams",
		["icon"] = 2967104,
	}, -- [27]
	{
		["ID"] = 28,
		["name"] = "The Unbound Force",
		["icon"] = 2967102,
	}, -- [28]
	nil, -- [29]
	nil, -- [30]
	nil, -- [31]
	{
		["ID"] = 32,
		["name"] = "Conflict and Strife",
		["icon"] = 3015742,
	}, -- [32]
}
local classInfo = {};
local dungeonDifficultiesAll = {1,2,23,8};
local raidDifficultiesAll = {17,14,15,16};
-- local raidDifficultiesAll = {3,4,5,6,79,14,15,16,17,33};
local instanceDifficulties = {
	[1763] = dungeonDifficultiesAll,
	[1841] = dungeonDifficultiesAll,
	[1877] = dungeonDifficultiesAll,
	[1594] = dungeonDifficultiesAll,
	[1762] = dungeonDifficultiesAll,
	[1754] = dungeonDifficultiesAll,
	[1864] = dungeonDifficultiesAll,
	[1771] = dungeonDifficultiesAll,
	[1862] = dungeonDifficultiesAll,
	[1822] = dungeonDifficultiesAll,
	[2097] = {23},
	
	[1861] = {17,14,15,16},
	[2070] = {17,14,15,16},
	[2096] = {17,14,15,16},
	[2164] = {17,14,15,16},
};
local dungeonInfo = {
	{
		name = L["Classic"],
		instances = {
		},
	},
	{
		name = L["TBC"],
		instances = {
		},
	},
	{
		name = L["Wrath"],
		instances = {
		},
	},
	{
		name = L["Cata"],
		instances = {
		},
	},
	{
		name = L["Panda"],
		instances = {
		},
	},
	{
		name = L["WoD"],
		instances = {
		},
	},
	{
		name = L["Legion"],
		instances = {
		},
	},
	{
		name = L["Battle For Azeroth"],
		instances = {
			1763,
			1841,
			1877,
			1594,
			1762,
			1754,
			1864,
			1771,
			1862,
			1822,
			2097,
		},
	}
};
local raidInfo = {
	{
		name = L["Classic"],
		instances = {
		},
	},
	{
		name = L["TBC"],
		instances = {
		},
	},
	{
		name = L["Wrath"],
		instances = {
		},
	},
	{
		name = L["Cata"],
		instances = {
		},
	},
	{
		name = L["Panda"],
		instances = {
		},
	},
	{
		name = L["WoD"],
		instances = {
		},
	},
	{
		name = L["Legion"],
		instances = {
		},
	},
	{
		name = L["Battle For Azeroth"],
		instances = {
			1861,
			2070,
			2096,
			2164,
		},
	}
};
-- List of bosses within an instance
local instanceBosses = {
	[1763] = { -- Atal'Dazar
		2082, -- Priestess Alun'za
		2036, -- Vol'kaal
		2083, -- Rezan
		2030, -- Yazma
	},
	[1754] = { -- Freehold
		2102, -- Skycap'n Kragg
		2093, -- Council o' Captains
		2094, -- Ring of Booty
		2095, -- Harlan Sweete
	},
	[1762] = { -- Kings' Rest
		2165, -- The Golden Serpent
		2171, -- Mchimba the Embalmer
		2170, -- The Council of Tribes
		2172, -- Dazar, The First King
	},
	[1864] = { -- Shrine of the Storm
		2153, -- Aqu'sirr
		2154, -- Tidesage Council
		2155, -- Lord Stormsong
		2156, -- Vol'zith the Whisperer
	},
	[1822] = { -- Siege of Boralus
		2132, -- Chopper Redhook
		2133, -- Sergeant Bainbridge
		2173, -- Dread Captain Lockwood
		2134, -- Hadal Darkfathom
		2140, -- Viq'Goth
	},
	[1877] = { -- Temple of Sethraliss
		2142, -- Adderis and Aspix
		2143, -- Merektha
		2144, -- Galvazzt
		2145, -- Avatar of Sethraliss
	},
	[1594] = { -- The MOTHERLODE!!
		2109, -- Coin-Operated Crowd Pummeler
		2114, -- Azerokk
		2115, -- Rixxa Fluxflame
		2116, -- Mogul Razdunk
	},
	[1841] = { -- The Underrot
		2157, -- Elder Leaxa
		2131, -- Cragmaw the Infested
		2130, -- Sporecaller Zancha
		2158, -- Unbound Abomination
	},
	[1771] = { -- Tol Dagor
		2097, -- The Sand Queen
		2098, -- Jes Howlis
		2099, -- Knight Captain Valyri
		2096, -- Overseer Korgus
	},
	[1862] = { -- Waycrest Manor
		2125, -- Heartsbane Triad
		2126, -- Soulbound Goliath
		2127, -- Raal the Gluttonous
		2128, -- Lord and Lady Waycrest
		2129, -- Gorak Tul
	},
	[2097] = { -- Operation: Mechagon
		2357, -- King Gobbamak
		2358, -- Gunker
		2360, -- Trixie & Naeno
		2355, -- HK-8 Aerial Oppression Unit
		2336, -- Tussle Tonks
		2339, -- K.U.-J.0.
		2348, -- Machinist's Garden
		2331, -- King Mechagon
	},

	[1861] = { -- Uldir
		2168, -- Taloc
		2167, -- MOTHER
		2146, -- Fetid Devourer
		2169, -- Zek'voz, Herald of N'zoth
		2166, -- Vectis
		2195, -- Zul, Reborn
		2194, -- Mythrax the Unraveler
		2147, -- G'huun
	},
	[2070] = { -- Battle of Dazar'alor
		2333, -- Champion of the Light
		2323, -- Jadefire Masters
		2325, -- Grong, the Jungle Lord
		2342, -- Opulence
		2330, -- Conclave of the Chosen
		2335, -- King Rastakhan
		2334, -- High Tinker Mekkatorque
		2337, -- Stormwall Blockade
		2343, -- Lady Jaina Proudmoore
	},
	[2096] = { -- Crucible of Storms
		2328, -- The Restless Cabal
		2332, -- Uu'nat, Harbinger of the Void
	},
	[2164] = { -- The Eternal Palace
		2352, -- Abyssal Commander Sivara
		2347, -- Blackwater Behemoth
		2353, -- Radiance of Azshara
		2354, -- Lady Ashvane
		2351, -- Orgozoa
		2359, -- The Queen's Court
		2349, -- Za'qul, Harbinger of Ny'alotha
		2361, -- Queen Azshara
	},
};
-- A map of npc ids to boss ids, this might not be the bosses npc id, just something that signifies the boss
local npcIDToBossID = {
	-- Shrine of the Storm
	[134056] = 2153, -- Aqu'sirr
	[134063] = 2154, -- Tidesage Council
	[134058] = 2154, -- Tidesage Council
	[134060] = 2155, -- Lord Stormsong
	[134069] = 2156, -- Vol'zith the Whisperer

	-- The Eternal Palace
	[155899] = 2353, -- Radiance of Azshara
	[155900] = 2353, -- Radiance of Azshara
	[155859] = 2353, -- Radiance of Azshara
	[152364] = 2353, -- Radiance of Azshara

	[152236] = 2354, -- Lady Ashvane
};
local areaNameToIDMap = {};
_G['BtWLoadoutsAreaMap'] = areaNameToIDMap; -- @TODO Remove
local InstanceAreaIDToBossID = {
	[1822] = {
		[9984] = 2132,
	},
	[2097] = { -- Operation: Mechagon
		[11389] = 2358, -- Gunker
		[11388] = 2357, -- King Gobbamak
		[11387] = 2360, -- Trixie & Naeno
		[11390] = 2355, -- HK-8 Aerial Oppression Unit
		[10497] = 2336, -- Tussle Tonks
		-- [] = 2339, -- K.U.-J.0.
		-- [] = 2348, -- Machinist's Garden
		-- [] = 2331, -- King Mechagon
	},
	[1754] = { -- Freehold
		[9640] = 2102, -- Skycap'n Kragg
		[10039] = 2093, -- Council o' Captains
		[9639] = 2094, -- Ring of Booty
		[10040] = 2095, -- Harlan Sweete
	},
};
local uiMapIDToBossID = {
	-- Operation: Mechagon
	[1491] = 2336, -- Tussle Tonks
	[1494] = 2339, -- K.U.-J.0.

	-- The Eternal Palace
	[1512] = 2352, -- Abyssal Commander Sivara
	[1514] = 2347, -- Blackwater Behemoth
	[1517] = 2351, -- Orgozoa
	[1518] = 2359, -- The Queen's Court
	[1519] = 2349, -- Za'qul, Harbinger of Ny'alotha
	[1520] = 2361, -- Queen Azshara
};

local function GetAffixesName(affixesID)
	local names = {};
	local icons = {};
	while affixesID > 0 do
		local affixID = bit.band(affixesID, 0xFF);
		affixesID = bit.rshift(affixesID, 8);
		
		local name, _, icon = C_ChallengeMode.GetAffixInfo(affixID);
		names[#names+1] = name;
		icons[#icons+1] = format("|T%d:18:18:0:0|t %s", icon, name);
	end

	return affixesID, table.concat(names, " "), table.concat(icons, ", ");
end
local function GetAffixesInfo(...)
	local id = 0;
	local names = {};
	local icons = {};
	for i=1,select('#', ...) do
		local affixID = select(i, ...);
		local name, _, icon = C_ChallengeMode.GetAffixInfo(affixID);

		id = bit.bor(bit.rshift(id, 8), bit.lshift(affixID, 24));
		names[#names+1] = name;
		icons[#icons+1] = format("|T%d:18:18:0:0|t %s", icon, name);
	end
	return {
		id = id,
		name = table.concat(names, ", "),
		fullName = table.concat(icons, ", "),
	};
end
local affixRotation = {
	GetAffixesInfo(10, 7, 12, 119), -- Fortified, 	Bolstering, Grievous, 	Beguiling
	GetAffixesInfo(9, 6, 13, 119), 	-- Tyrannical, 	Raging, 	Explosive, 	Beguiling
	GetAffixesInfo(10, 8, 12, 119), -- Fortified, 	Sanguine, 	Grievous, 	Beguiling
	GetAffixesInfo(9, 5, 3, 119), 	-- Tyrannical, 	Teeming, 	Volcanic, 	Beguiling
	GetAffixesInfo(10, 7, 2, 119), 	-- Fortified, 	Bolstering, Skittish, 	Beguiling
	GetAffixesInfo(9, 11, 4, 119), 	-- Tyrannical, 	Bursting, 	Necrotic, 	Beguiling
	GetAffixesInfo(10, 8, 14, 119),	-- Fortified, 	Sanguine, 	Quaking, 	Beguiling
	
	-- GetAffixesInfo(9, 11, 2, 119),
	-- GetAffixesInfo(10, 8, 4, 119),
	-- GetAffixesInfo(9, 11, 3, 119),
	-- GetAffixesInfo(10, 5, 13, 119),
	-- GetAffixesInfo(9, 6, 14, 119),
};
_G['BtWLoadoutsAffixRotation'] = affixRotation; -- @TODO Remove


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
local GetTalentInfoForSpecID;
local GetPvPTrinketTalentInfo;
local GetPvPTalentInfoForSpecID;
do
	local specInfo = {
		[62] = {
			["talents"] = {
				{
					22458, -- [1]
					22461, -- [2]
					22464, -- [3]
				}, -- [1]
				{
					23072, -- [1]
					22443, -- [2]
					16025, -- [3]
				}, -- [2]
				{
					22444, -- [1]
					22445, -- [2]
					22447, -- [3]
				}, -- [3]
				{
					22453, -- [1]
					22467, -- [2]
					22470, -- [3]
				}, -- [4]
				{
					22907, -- [1]
					22448, -- [2]
					22471, -- [3]
				}, -- [5]
				{
					22455, -- [1]
					22449, -- [2]
					22474, -- [3]
				}, -- [6]
				{
					21630, -- [1]
					21144, -- [2]
					21145, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3580, -- [1]
				3579, -- [2]
				3578, -- [3]
			},
			["pvptalents"] = {
				3442, -- [1]
				61, -- [2]
				635, -- [3]
				636, -- [4]
				3517, -- [5]
				3531, -- [6]
				3523, -- [7]
				3529, -- [8]
				62, -- [9]
				637, -- [10]
			},
		},
		[63] = {
			["talents"] = {
				{
					22456, -- [1]
					22459, -- [2]
					22462, -- [3]
				}, -- [1]
				{
					23071, -- [1]
					22443, -- [2]
					23074, -- [3]
				}, -- [2]
				{
					22444, -- [1]
					22445, -- [2]
					22447, -- [3]
				}, -- [3]
				{
					22450, -- [1]
					22465, -- [2]
					22468, -- [3]
				}, -- [4]
				{
					22904, -- [1]
					22448, -- [2]
					22471, -- [3]
				}, -- [5]
				{
					22451, -- [1]
					23362, -- [2]
					22472, -- [3]
				}, -- [6]
				{
					21631, -- [1]
					22220, -- [2]
					21633, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3583, -- [1]
				3582, -- [2]
				3581, -- [3]
			},
			["pvptalents"] = {
				648, -- [1]
				53, -- [2]
				56, -- [3]
				647, -- [4]
				3530, -- [5]
				646, -- [6]
				3524, -- [7]
				645, -- [8]
				644, -- [9]
				643, -- [10]
				828, -- [11]
			},
		},
		[250] = {
			["talents"] = {
				{
					19165, -- [1]
					19166, -- [2]
					19217, -- [3]
				}, -- [1]
				{
					19218, -- [1]
					19219, -- [2]
					19220, -- [3]
				}, -- [2]
				{
					19221, -- [1]
					22134, -- [2]
					22135, -- [3]
				}, -- [3]
				{
					22013, -- [1]
					22014, -- [2]
					22015, -- [3]
				}, -- [4]
				{
					19227, -- [1]
					19226, -- [2]
					19228, -- [3]
				}, -- [5]
				{
					19230, -- [1]
					19231, -- [2]
					19232, -- [3]
				}, -- [6]
				{
					21207, -- [1]
					21208, -- [2]
					21209, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3467, -- [1]
				3468, -- [2]
				3466, -- [3]
			},
			["pvptalents"] = {
				609, -- [1]
				608, -- [2]
				607, -- [3]
				841, -- [4]
				206, -- [5]
				205, -- [6]
				204, -- [7]
				3436, -- [8]
				3441, -- [9]
				3434, -- [10]
				3511, -- [11]
			},
		},
		[251] = {
			["talents"] = {
				{
					22016, -- [1]
					22017, -- [2]
					22018, -- [3]
				}, -- [1]
				{
					22019, -- [1]
					22020, -- [2]
					22021, -- [3]
				}, -- [2]
				{
					22515, -- [1]
					22517, -- [2]
					22519, -- [3]
				}, -- [3]
				{
					22521, -- [1]
					22523, -- [2]
					22525, -- [3]
				}, -- [4]
				{
					22527, -- [1]
					22530, -- [2]
					23373, -- [3]
				}, -- [5]
				{
					22531, -- [1]
					22533, -- [2]
					22535, -- [3]
				}, -- [6]
				{
					22023, -- [1]
					22109, -- [2]
					22537, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3538, -- [1]
				3539, -- [2]
				3540, -- [3]
			},
			["pvptalents"] = {
				3515, -- [1]
				3512, -- [2]
				3435, -- [3]
				43, -- [4]
				3743, -- [5]
				3439, -- [6]
				3742, -- [7]
				3749, -- [8]
				701, -- [9]
				702, -- [10]
				706, -- [11]
			},
		},
		[252] = {
			["talents"] = {
				{
					22024, -- [1]
					22025, -- [2]
					22026, -- [3]
				}, -- [1]
				{
					22027, -- [1]
					22028, -- [2]
					22029, -- [3]
				}, -- [2]
				{
					22516, -- [1]
					22518, -- [2]
					22520, -- [3]
				}, -- [3]
				{
					22522, -- [1]
					22524, -- [2]
					22526, -- [3]
				}, -- [4]
				{
					22528, -- [1]
					22529, -- [2]
					23373, -- [3]
				}, -- [5]
				{
					22532, -- [1]
					22534, -- [2]
					22536, -- [3]
				}, -- [6]
				{
					22030, -- [1]
					22110, -- [2]
					22538, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3537, -- [1]
				3536, -- [2]
				3535, -- [3]
			},
			["pvptalents"] = {
				152, -- [1]
				3748, -- [2]
				40, -- [3]
				41, -- [4]
				3746, -- [5]
				3437, -- [6]
				42, -- [7]
				149, -- [8]
				163, -- [9]
				3747, -- [10]
				3754, -- [11]
				3440, -- [12]
			},
		},
		[253] = {
			["talents"] = {
				{
					22291, -- [1]
					22280, -- [2]
					22282, -- [3]
				}, -- [1]
				{
					22500, -- [1]
					22266, -- [2]
					22290, -- [3]
				}, -- [2]
				{
					19347, -- [1]
					19348, -- [2]
					23100, -- [3]
				}, -- [3]
				{
					22441, -- [1]
					22347, -- [2]
					22269, -- [3]
				}, -- [4]
				{
					22268, -- [1]
					22276, -- [2]
					22499, -- [3]
				}, -- [5]
				{
					19357, -- [1]
					22002, -- [2]
					23044, -- [3]
				}, -- [6]
				{
					22273, -- [1]
					21986, -- [2]
					22295, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3562, -- [1]
				3561, -- [2]
				3560, -- [3]
			},
			["pvptalents"] = {
				821, -- [1]
				824, -- [2]
				825, -- [3]
				1214, -- [4]
				693, -- [5]
				3730, -- [6]
				3612, -- [7]
				3605, -- [8]
				3604, -- [9]
				3603, -- [10]
				3602, -- [11]
				3600, -- [12]
				3599, -- [13]
			},
		},
		[254] = {
			["talents"] = {
				{
					22279, -- [1]
					22501, -- [2]
					22289, -- [3]
				}, -- [1]
				{
					22495, -- [1]
					22497, -- [2]
					22498, -- [3]
				}, -- [2]
				{
					19347, -- [1]
					19348, -- [2]
					23100, -- [3]
				}, -- [3]
				{
					22267, -- [1]
					22286, -- [2]
					21998, -- [3]
				}, -- [4]
				{
					22268, -- [1]
					22276, -- [2]
					22499, -- [3]
				}, -- [5]
				{
					23063, -- [1]
					23104, -- [2]
					22287, -- [3]
				}, -- [6]
				{
					22274, -- [1]
					22308, -- [2]
					22288, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3564, -- [1]
				3563, -- [2]
				3565, -- [3]
			},
			["pvptalents"] = {
				651, -- [1]
				652, -- [2]
				653, -- [3]
				659, -- [4]
				654, -- [5]
				3614, -- [6]
				658, -- [7]
				649, -- [8]
				660, -- [9]
				656, -- [10]
				3729, -- [11]
				657, -- [12]
			},
		},
		[255] = {
			["talents"] = {
				{
					22275, -- [1]
					22283, -- [2]
					22296, -- [3]
				}, -- [1]
				{
					21997, -- [1]
					22769, -- [2]
					22297, -- [3]
				}, -- [2]
				{
					19347, -- [1]
					19348, -- [2]
					23100, -- [3]
				}, -- [3]
				{
					22277, -- [1]
					19361, -- [2]
					22299, -- [3]
				}, -- [4]
				{
					22268, -- [1]
					22276, -- [2]
					22499, -- [3]
				}, -- [5]
				{
					22300, -- [1]
					22278, -- [2]
					22271, -- [3]
				}, -- [6]
				{
					22272, -- [1]
					22301, -- [2]
					23105, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3568, -- [1]
				3567, -- [2]
				3566, -- [3]
			},
			["pvptalents"] = {
				3607, -- [1]
				3608, -- [2]
				3609, -- [3]
				3610, -- [4]
				665, -- [5]
				3615, -- [6]
				661, -- [7]
				662, -- [8]
				663, -- [9]
				664, -- [10]
				686, -- [11]
				3606, -- [12]
			},
		},
		[66] = {
			["talents"] = {
				{
					22428, -- [1]
					22558, -- [2]
					22430, -- [3]
				}, -- [1]
				{
					22431, -- [1]
					22604, -- [2]
					22594, -- [3]
				}, -- [2]
				{
					22179, -- [1]
					22180, -- [2]
					21811, -- [3]
				}, -- [3]
				{
					22433, -- [1]
					22434, -- [2]
					22435, -- [3]
				}, -- [4]
				{
					22705, -- [1]
					21795, -- [2]
					17601, -- [3]
				}, -- [5]
				{
					22189, -- [1]
					22438, -- [2]
					23087, -- [3]
				}, -- [6]
				{
					21201, -- [1]
					21202, -- [2]
					22645, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3471, -- [1]
				3469, -- [2]
				3470, -- [3]
			},
			["pvptalents"] = {
				93, -- [1]
				94, -- [2]
				97, -- [3]
				3475, -- [4]
				3474, -- [5]
				3472, -- [6]
				860, -- [7]
				861, -- [8]
				92, -- [9]
				91, -- [10]
				90, -- [11]
				844, -- [12]
			},
		},
		[257] = {
			["talents"] = {
				{
					22312, -- [1]
					19753, -- [2]
					19754, -- [3]
				}, -- [1]
				{
					22325, -- [1]
					22326, -- [2]
					19758, -- [3]
				}, -- [2]
				{
					22487, -- [1]
					22095, -- [2]
					22562, -- [3]
				}, -- [3]
				{
					21750, -- [1]
					21977, -- [2]
					19761, -- [3]
				}, -- [4]
				{
					19764, -- [1]
					22327, -- [2]
					21754, -- [3]
				}, -- [5]
				{
					19767, -- [1]
					19760, -- [2]
					19763, -- [3]
				}, -- [6]
				{
					21636, -- [1]
					21644, -- [2]
					23145, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3559, -- [1]
				3558, -- [2]
				3557, -- [3]
			},
			["pvptalents"] = {
				118, -- [1]
				121, -- [2]
				124, -- [3]
				127, -- [4]
				1927, -- [5]
				101, -- [6]
				108, -- [7]
				1242, -- [8]
				112, -- [9]
				115, -- [10]
			},
		},
		[258] = {
			["talents"] = {
				{
					22328, -- [1]
					22136, -- [2]
					22314, -- [3]
				}, -- [1]
				{
					22315, -- [1]
					23374, -- [2]
					21976, -- [3]
				}, -- [2]
				{
					23125, -- [1]
					23126, -- [2]
					23127, -- [3]
				}, -- [3]
				{
					23137, -- [1]
					23375, -- [2]
					21752, -- [3]
				}, -- [4]
				{
					22310, -- [1]
					22311, -- [2]
					21755, -- [3]
				}, -- [5]
				{
					21718, -- [1]
					21719, -- [2]
					21720, -- [3]
				}, -- [6]
				{
					21637, -- [1]
					21978, -- [2]
					21979, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3478, -- [1]
				3477, -- [2]
				3476, -- [3]
			},
			["pvptalents"] = {
				102, -- [1]
				106, -- [2]
				764, -- [3]
				763, -- [4]
				110, -- [5]
				119, -- [6]
				739, -- [7]
				128, -- [8]
				113, -- [9]
				3753, -- [10]
			},
		},
		[259] = {
			["pvpTalents"] = {
				145, -- [1]
				135, -- [2]
				139, -- [3]
				3619, -- [4]
				129, -- [5]
				853, -- [6]
				3483, -- [7]
				1208, -- [8]
				3421, -- [9]
				3451, -- [10]
				150, -- [11]
				3449, -- [12]
				142, -- [13]
				138, -- [14]
			},
			["talents"] = {
				{
					22337, -- [1]
					22338, -- [2]
					22339, -- [3]
				}, -- [1]
				{
					22331, -- [1]
					22332, -- [2]
					23022, -- [3]
				}, -- [2]
				{
					19239, -- [1]
					19240, -- [2]
					19241, -- [3]
				}, -- [3]
				{
					22340, -- [1]
					22122, -- [2]
					22123, -- [3]
				}, -- [4]
				{
					19245, -- [1]
					23037, -- [2]
					22115, -- [3]
				}, -- [5]
				{
					22343, -- [1]
					23015, -- [2]
					22344, -- [3]
				}, -- [6]
				{
					21186, -- [1]
					22133, -- [2]
					23174, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3453, -- [1]
				3456, -- [2]
				3461, -- [3]
			},
			["pvptalents"] = {
				3479, -- [1]
				3448, -- [2]
				131, -- [3]
				130, -- [4]
				137, -- [5]
				147, -- [6]
				830, -- [7]
				132, -- [8]
				144, -- [9]
				141, -- [10]
				3480, -- [11]
			},
		},
		[260] = {
			["talents"] = {
				{
					22118, -- [1]
					22119, -- [2]
					22120, -- [3]
				}, -- [1]
				{
					19236, -- [1]
					19237, -- [2]
					19238, -- [3]
				}, -- [2]
				{
					19239, -- [1]
					19240, -- [2]
					19241, -- [3]
				}, -- [3]
				{
					22121, -- [1]
					22122, -- [2]
					22123, -- [3]
				}, -- [4]
				{
					23077, -- [1]
					22114, -- [2]
					22115, -- [3]
				}, -- [5]
				{
					21990, -- [1]
					23128, -- [2]
					19250, -- [3]
				}, -- [6]
				{
					22125, -- [1]
					23075, -- [2]
					23175, -- [3]
				}, -- [7]
			},
			["pvpTalents"] = {
				145, -- [1]
				135, -- [2]
				139, -- [3]
				3619, -- [4]
				129, -- [5]
				853, -- [6]
				3483, -- [7]
				1208, -- [8]
				3421, -- [9]
				3451, -- [10]
				150, -- [11]
				3449, -- [12]
				142, -- [13]
				138, -- [14]
			},
			["pvptalenttrinkets"] = {
				3455, -- [1]
				3458, -- [2]
				3459, -- [3]
			},
			["pvptalents"] = {
				145, -- [1]
				135, -- [2]
				139, -- [3]
				3619, -- [4]
				129, -- [5]
				853, -- [6]
				3483, -- [7]
				1208, -- [8]
				3421, -- [9]
				3451, -- [10]
				150, -- [11]
				3449, -- [12]
				142, -- [13]
				138, -- [14]
			},
		},
		[261] = {
			["talents"] = {
				{
					19233, -- [1]
					19234, -- [2]
					19235, -- [3]
				}, -- [1]
				{
					22331, -- [1]
					22332, -- [2]
					22333, -- [3]
				}, -- [2]
				{
					19239, -- [1]
					19240, -- [2]
					19241, -- [3]
				}, -- [3]
				{
					22128, -- [1]
					22122, -- [2]
					22123, -- [3]
				}, -- [4]
				{
					23078, -- [1]
					23036, -- [2]
					22115, -- [3]
				}, -- [5]
				{
					22335, -- [1]
					19249, -- [2]
					22336, -- [3]
				}, -- [6]
				{
					22132, -- [1]
					23183, -- [2]
					21188, -- [3]
				}, -- [7]
			},
			["pvpTalents"] = {
				145, -- [1]
				135, -- [2]
				139, -- [3]
				3619, -- [4]
				129, -- [5]
				853, -- [6]
				3483, -- [7]
				1208, -- [8]
				3421, -- [9]
				3451, -- [10]
				150, -- [11]
				3449, -- [12]
				142, -- [13]
				138, -- [14]
			},
			["pvptalents"] = {
				3479, -- [1]
				3448, -- [2]
				131, -- [3]
				130, -- [4]
				137, -- [5]
				147, -- [6]
				830, -- [7]
				132, -- [8]
				144, -- [9]
				141, -- [10]
				3480, -- [11]
				3449, -- [12]
				142, -- [13]
				138, -- [14]
			},
		},
		[262] = {
			["talents"] = {
				{
					22356, -- [1]
					22357, -- [2]
					22358, -- [3]
				}, -- [1]
				{
					23108, -- [1]
					22139, -- [2]
					23190, -- [3]
				}, -- [2]
				{
					23162, -- [1]
					23163, -- [2]
					23164, -- [3]
				}, -- [3]
				{
					19271, -- [1]
					19272, -- [2]
					19273, -- [3]
				}, -- [4]
				{
					22144, -- [1]
					22172, -- [2]
					21966, -- [3]
				}, -- [5]
				{
					22145, -- [1]
					19266, -- [2]
					23111, -- [3]
				}, -- [6]
				{
					21198, -- [1]
					22153, -- [2]
					21675, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3596, -- [1]
				3597, -- [2]
				3598, -- [3]
			},
			["pvptalents"] = {
				3062, -- [1]
				731, -- [2]
				3491, -- [3]
				730, -- [4]
				728, -- [5]
				727, -- [6]
				3488, -- [7]
				3621, -- [8]
				3620, -- [9]
				3490, -- [10]
			},
		},
		[263] = {
			["talents"] = {
				{
					22354, -- [1]
					22355, -- [2]
					22353, -- [3]
				}, -- [1]
				{
					22636, -- [1]
					22150, -- [2]
					23109, -- [3]
				}, -- [2]
				{
					23165, -- [1]
					19260, -- [2]
					23166, -- [3]
				}, -- [3]
				{
					23089, -- [1]
					23090, -- [2]
					22171, -- [3]
				}, -- [4]
				{
					22144, -- [1]
					22149, -- [2]
					21966, -- [3]
				}, -- [5]
				{
					21973, -- [1]
					22352, -- [2]
					22351, -- [3]
				}, -- [6]
				{
					21970, -- [1]
					22977, -- [2]
					21972, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3553, -- [1]
				3552, -- [2]
				3551, -- [3]
			},
			["pvptalents"] = {
				3519, -- [1]
				3492, -- [2]
				725, -- [3]
				1944, -- [4]
				722, -- [5]
				721, -- [6]
				3487, -- [7]
				3489, -- [8]
				3623, -- [9]
				3622, -- [10]
			},
		},
		[264] = {
			["talents"] = {
				{
					19262, -- [1]
					19263, -- [2]
					19264, -- [3]
				}, -- [1]
				{
					19259, -- [1]
					22492, -- [2]
					21963, -- [3]
				}, -- [2]
				{
					19275, -- [1]
					23110, -- [2]
					22127, -- [3]
				}, -- [3]
				{
					22152, -- [1]
					22322, -- [2]
					22323, -- [3]
				}, -- [4]
				{
					22144, -- [1]
					19269, -- [2]
					21966, -- [3]
				}, -- [5]
				{
					19265, -- [1]
					21971, -- [2]
					21968, -- [3]
				}, -- [6]
				{
					21969, -- [1]
					21199, -- [2]
					22359, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3484, -- [1]
				3485, -- [2]
				3486, -- [3]
			},
			["pvptalents"] = {
				3756, -- [1]
				714, -- [2]
				718, -- [3]
				1930, -- [4]
				715, -- [5]
				3755, -- [6]
				707, -- [7]
				708, -- [8]
				712, -- [9]
				3520, -- [10]
				713, -- [11]
			},
		},
		[265] = {
			["talents"] = {
				{
					22039, -- [1]
					23140, -- [2]
					23141, -- [3]
				}, -- [1]
				{
					22044, -- [1]
					21180, -- [2]
					22089, -- [3]
				}, -- [2]
				{
					19280, -- [1]
					19285, -- [2]
					19286, -- [3]
				}, -- [3]
				{
					19279, -- [1]
					19292, -- [2]
					22046, -- [3]
				}, -- [4]
				{
					22047, -- [1]
					19291, -- [2]
					19288, -- [3]
				}, -- [5]
				{
					23139, -- [1]
					23159, -- [2]
					19295, -- [3]
				}, -- [6]
				{
					19284, -- [1]
					19281, -- [2]
					19293, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3498, -- [1]
				3497, -- [2]
				3496, -- [3]
			},
			["pvptalents"] = {
				9, -- [1]
				3740, -- [2]
				19, -- [3]
				20, -- [4]
				13, -- [5]
				10, -- [6]
				11, -- [7]
				12, -- [8]
				18, -- [9]
				17, -- [10]
				16, -- [11]
				15, -- [12]
			},
		},
		[266] = {
			["talents"] = {
				{
					19290, -- [1]
					22048, -- [2]
					23138, -- [3]
				}, -- [1]
				{
					22045, -- [1]
					21694, -- [2]
					23158, -- [3]
				}, -- [2]
				{
					19280, -- [1]
					19285, -- [2]
					19286, -- [3]
				}, -- [3]
				{
					22477, -- [1]
					22042, -- [2]
					23160, -- [3]
				}, -- [4]
				{
					22047, -- [1]
					19291, -- [2]
					19288, -- [3]
				}, -- [5]
				{
					23147, -- [1]
					23146, -- [2]
					21717, -- [3]
				}, -- [6]
				{
					23161, -- [1]
					22479, -- [2]
					23091, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3499, -- [1]
				3500, -- [2]
				3501, -- [3]
			},
			["pvptalents"] = {
				165, -- [1]
				3624, -- [2]
				3625, -- [3]
				3626, -- [4]
				3506, -- [5]
				3505, -- [6]
				3507, -- [7]
				154, -- [8]
				156, -- [9]
				158, -- [10]
				162, -- [11]
				1213, -- [12]
			},
		},
		[267] = {
			["talents"] = {
				{
					22038, -- [1]
					22090, -- [2]
					22040, -- [3]
				}, -- [1]
				{
					23148, -- [1]
					21695, -- [2]
					23157, -- [3]
				}, -- [2]
				{
					19280, -- [1]
					19285, -- [2]
					19286, -- [3]
				}, -- [3]
				{
					22480, -- [1]
					22043, -- [2]
					23143, -- [3]
				}, -- [4]
				{
					22047, -- [1]
					19291, -- [2]
					19288, -- [3]
				}, -- [5]
				{
					23155, -- [1]
					23156, -- [2]
					19295, -- [3]
				}, -- [6]
				{
					19284, -- [1]
					23144, -- [2]
					23092, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3493, -- [1]
				3494, -- [2]
				3495, -- [3]
			},
			["pvptalents"] = {
				155, -- [1]
				157, -- [2]
				161, -- [3]
				3741, -- [4]
				164, -- [5]
				3502, -- [6]
				3503, -- [7]
				3504, -- [8]
				3508, -- [9]
				3509, -- [10]
				3510, -- [11]
				159, -- [12]
			},
		},
		[268] = {
			["talents"] = {
				{
					23106, -- [1]
					19820, -- [2]
					20185, -- [3]
				}, -- [1]
				{
					19304, -- [1]
					19818, -- [2]
					19302, -- [3]
				}, -- [2]
				{
					22099, -- [1]
					22097, -- [2]
					19992, -- [3]
				}, -- [3]
				{
					19993, -- [1]
					19994, -- [2]
					19995, -- [3]
				}, -- [4]
				{
					20174, -- [1]
					23363, -- [2]
					20175, -- [3]
				}, -- [5]
				{
					19819, -- [1]
					20184, -- [2]
					22103, -- [3]
				}, -- [6]
				{
					22106, -- [1]
					22104, -- [2]
					22108, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3569, -- [1]
				3570, -- [2]
				3571, -- [3]
			},
			["pvptalents"] = {
				1958, -- [1]
				673, -- [2]
				672, -- [3]
				670, -- [4]
				669, -- [5]
				765, -- [6]
				668, -- [7]
				667, -- [8]
				666, -- [9]
				843, -- [10]
				671, -- [11]
			},
		},
		[269] = {
			["talents"] = {
				{
					23106, -- [1]
					19820, -- [2]
					20185, -- [3]
				}, -- [1]
				{
					19304, -- [1]
					19818, -- [2]
					19302, -- [3]
				}, -- [2]
				{
					22098, -- [1]
					19771, -- [2]
					22096, -- [3]
				}, -- [3]
				{
					19993, -- [1]
					23364, -- [2]
					19995, -- [3]
				}, -- [4]
				{
					23258, -- [1]
					20173, -- [2]
					20175, -- [3]
				}, -- [5]
				{
					22093, -- [1]
					23122, -- [2]
					22102, -- [3]
				}, -- [6]
				{
					22107, -- [1]
					22105, -- [2]
					21191, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3572, -- [1]
				3573, -- [2]
				3574, -- [3]
			},
			["pvptalents"] = {
				3052, -- [1]
				3734, -- [2]
				3737, -- [3]
				3745, -- [4]
				3744, -- [5]
				852, -- [6]
				3050, -- [7]
				77, -- [8]
				73, -- [9]
				675, -- [10]
			},
		},
		[270] = {
			["talents"] = {
				{
					19823, -- [1]
					19820, -- [2]
					20185, -- [3]
				}, -- [1]
				{
					19304, -- [1]
					19818, -- [2]
					19302, -- [3]
				}, -- [2]
				{
					22168, -- [1]
					22167, -- [2]
					22166, -- [3]
				}, -- [3]
				{
					19993, -- [1]
					22219, -- [2]
					19995, -- [3]
				}, -- [4]
				{
					23371, -- [1]
					20173, -- [2]
					20175, -- [3]
				}, -- [5]
				{
					23107, -- [1]
					22101, -- [2]
					22214, -- [3]
				}, -- [6]
				{
					22218, -- [1]
					22169, -- [2]
					22170, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3575, -- [1]
				3576, -- [2]
				3577, -- [3]
			},
			["pvptalents"] = {
				70, -- [1]
				676, -- [2]
				3732, -- [3]
				680, -- [4]
				683, -- [5]
				681, -- [6]
				678, -- [7]
				1928, -- [8]
				679, -- [9]
				682, -- [10]
			},
		},
		[70] = {
			["talents"] = {
				{
					22590, -- [1]
					22557, -- [2]
					22175, -- [3]
				}, -- [1]
				{
					22319, -- [1]
					22592, -- [2]
					22593, -- [3]
				}, -- [2]
				{
					22896, -- [1]
					22180, -- [2]
					21811, -- [3]
				}, -- [3]
				{
					22375, -- [1]
					22182, -- [2]
					22183, -- [3]
				}, -- [4]
				{
					22595, -- [1]
					22185, -- [2]
					22186, -- [3]
				}, -- [5]
				{
					23167, -- [1]
					22483, -- [2]
					23086, -- [3]
				}, -- [6]
				{
					22591, -- [1]
					22215, -- [2]
					22634, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3446, -- [1]
				3445, -- [2]
				3444, -- [3]
			},
			["pvptalents"] = {
				3055, -- [1]
				858, -- [2]
				641, -- [3]
				757, -- [4]
				756, -- [5]
				751, -- [6]
				752, -- [7]
				753, -- [8]
				754, -- [9]
				755, -- [10]
				81, -- [11]
			},
		},
		[102] = {
			["talents"] = {
				{
					22385, -- [1]
					22386, -- [2]
					22387, -- [3]
				}, -- [1]
				{
					19283, -- [1]
					18570, -- [2]
					18571, -- [3]
				}, -- [2]
				{
					22155, -- [1]
					22157, -- [2]
					22159, -- [3]
				}, -- [3]
				{
					21778, -- [1]
					18576, -- [2]
					18577, -- [3]
				}, -- [4]
				{
					18580, -- [1]
					21706, -- [2]
					21702, -- [3]
				}, -- [5]
				{
					22389, -- [1]
					21712, -- [2]
					22165, -- [3]
				}, -- [6]
				{
					21648, -- [1]
					21193, -- [2]
					21655, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3541, -- [1]
				3542, -- [2]
				3543, -- [3]
			},
			["pvptalents"] = {
				3731, -- [1]
				3728, -- [2]
				836, -- [3]
				822, -- [4]
				834, -- [5]
				3058, -- [6]
				1216, -- [7]
				857, -- [8]
				180, -- [9]
				182, -- [10]
				184, -- [11]
				185, -- [12]
			},
		},
		[71] = {
			["talents"] = {
				{
					22624, -- [1]
					22360, -- [2]
					22371, -- [3]
				}, -- [1]
				{
					19676, -- [1]
					22372, -- [2]
					22789, -- [3]
				}, -- [2]
				{
					22380, -- [1]
					22489, -- [2]
					19138, -- [3]
				}, -- [3]
				{
					15757, -- [1]
					22627, -- [2]
					22628, -- [3]
				}, -- [4]
				{
					22392, -- [1]
					22391, -- [2]
					22362, -- [3]
				}, -- [5]
				{
					22394, -- [1]
					22397, -- [2]
					22399, -- [3]
				}, -- [6]
				{
					21204, -- [1]
					22407, -- [2]
					21667, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3589, -- [1]
				3587, -- [2]
				3588, -- [3]
			},
			["pvptalents"] = {
				31, -- [1]
				34, -- [2]
				3521, -- [3]
				3522, -- [4]
				28, -- [5]
				3534, -- [6]
				29, -- [7]
				32, -- [8]
				33, -- [9]
			},
		},
		[103] = {
			["talents"] = {
				{
					22363, -- [1]
					22364, -- [2]
					22365, -- [3]
				}, -- [1]
				{
					19283, -- [1]
					18570, -- [2]
					18571, -- [3]
				}, -- [2]
				{
					22163, -- [1]
					22158, -- [2]
					22159, -- [3]
				}, -- [3]
				{
					21778, -- [1]
					18576, -- [2]
					18577, -- [3]
				}, -- [4]
				{
					21708, -- [1]
					18579, -- [2]
					21704, -- [3]
				}, -- [5]
				{
					21714, -- [1]
					21711, -- [2]
					22370, -- [3]
				}, -- [6]
				{
					21646, -- [1]
					21649, -- [2]
					21653, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3433, -- [1]
				3431, -- [2]
				3432, -- [3]
			},
			["pvptalents"] = {
				601, -- [1]
				602, -- [2]
				611, -- [3]
				612, -- [4]
				620, -- [5]
				3751, -- [6]
				3053, -- [7]
				820, -- [8]
				203, -- [9]
				202, -- [10]
				201, -- [11]
			},
		},
		[72] = {
			["talents"] = {
				{
					22632, -- [1]
					22633, -- [2]
					22491, -- [3]
				}, -- [1]
				{
					19676, -- [1]
					22625, -- [2]
					23093, -- [3]
				}, -- [2]
				{
					22379, -- [1]
					22381, -- [2]
					23372, -- [3]
				}, -- [3]
				{
					23097, -- [1]
					22627, -- [2]
					22382, -- [3]
				}, -- [4]
				{
					22383, -- [1]
					22393, -- [2]
					19140, -- [3]
				}, -- [5]
				{
					22396, -- [1]
					22398, -- [2]
					22400, -- [3]
				}, -- [6]
				{
					22405, -- [1]
					22402, -- [2]
					16037, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3591, -- [1]
				3592, -- [2]
				3590, -- [3]
			},
			["pvptalents"] = {
				25, -- [1]
				166, -- [2]
				170, -- [3]
				172, -- [4]
				177, -- [5]
				179, -- [6]
				3735, -- [7]
				3533, -- [8]
				3528, -- [9]
				1929, -- [10]
			},
		},
		[104] = {
			["talents"] = {
				{
					22419, -- [1]
					22418, -- [2]
					22420, -- [3]
				}, -- [1]
				{
					19283, -- [1]
					22916, -- [2]
					18571, -- [3]
				}, -- [2]
				{
					22163, -- [1]
					22156, -- [2]
					22159, -- [3]
				}, -- [3]
				{
					21778, -- [1]
					18576, -- [2]
					18577, -- [3]
				}, -- [4]
				{
					21709, -- [1]
					21707, -- [2]
					22388, -- [3]
				}, -- [5]
				{
					22423, -- [1]
					21713, -- [2]
					22390, -- [3]
				}, -- [6]
				{
					22426, -- [1]
					22427, -- [2]
					22425, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3465, -- [1]
				3463, -- [2]
				3464, -- [3]
			},
			["pvptalents"] = {
				193, -- [1]
				192, -- [2]
				50, -- [3]
				51, -- [4]
				52, -- [5]
				3750, -- [6]
				1237, -- [7]
				49, -- [8]
				842, -- [9]
				194, -- [10]
				195, -- [11]
				197, -- [12]
				196, -- [13]
			},
		},
		[73] = {
			["talents"] = {
				{
					15760, -- [1]
					15759, -- [2]
					15774, -- [3]
				}, -- [1]
				{
					22373, -- [1]
					22629, -- [2]
					22409, -- [3]
				}, -- [2]
				{
					22378, -- [1]
					22626, -- [2]
					23260, -- [3]
				}, -- [3]
				{
					23096, -- [1]
					23261, -- [2]
					22488, -- [3]
				}, -- [4]
				{
					22384, -- [1]
					22631, -- [2]
					22800, -- [3]
				}, -- [5]
				{
					22395, -- [1]
					22544, -- [2]
					22401, -- [3]
				}, -- [6]
				{
					21204, -- [1]
					22406, -- [2]
					23099, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3595, -- [1]
				3594, -- [2]
				3593, -- [3]
			},
			["pvptalents"] = {
				833, -- [1]
				167, -- [2]
				168, -- [3]
				171, -- [4]
				173, -- [5]
				845, -- [6]
				178, -- [7]
				831, -- [8]
				175, -- [9]
				24, -- [10]
			},
		},
		[581] = {
			["talents"] = {
				{
					22502, -- [1]
					22503, -- [2]
					22504, -- [3]
				}, -- [1]
				{
					22505, -- [1]
					22766, -- [2]
					22507, -- [3]
				}, -- [2]
				{
					22324, -- [1]
					22541, -- [2]
					22540, -- [3]
				}, -- [3]
				{
					22508, -- [1]
					22509, -- [2]
					22770, -- [3]
				}, -- [4]
				{
					22546, -- [1]
					22510, -- [2]
					22511, -- [3]
				}, -- [5]
				{
					22512, -- [1]
					22513, -- [2]
					22768, -- [3]
				}, -- [6]
				{
					22543, -- [1]
					22548, -- [2]
					21902, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3546, -- [1]
				3545, -- [2]
				3544, -- [3]
			},
			["pvptalents"] = {
				3429, -- [1]
				3423, -- [2]
				814, -- [3]
				815, -- [4]
				816, -- [5]
				3430, -- [6]
				1948, -- [7]
				1220, -- [8]
				802, -- [9]
				3727, -- [10]
				819, -- [11]
			},
		},
		[105] = {
			["talents"] = {
				{
					18569, -- [1]
					18574, -- [2]
					18572, -- [3]
				}, -- [1]
				{
					19283, -- [1]
					18570, -- [2]
					18571, -- [3]
				}, -- [2]
				{
					22366, -- [1]
					22367, -- [2]
					22160, -- [3]
				}, -- [3]
				{
					21778, -- [1]
					18576, -- [2]
					18577, -- [3]
				}, -- [4]
				{
					21710, -- [1]
					21705, -- [2]
					22421, -- [3]
				}, -- [5]
				{
					21716, -- [1]
					18585, -- [2]
					22422, -- [3]
				}, -- [6]
				{
					22403, -- [1]
					21651, -- [2]
					22404, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3, -- [1]
				4, -- [2]
				5, -- [3]
			},
			["pvptalents"] = {
				690, -- [1]
				691, -- [2]
				692, -- [3]
				697, -- [4]
				700, -- [5]
				835, -- [6]
				838, -- [7]
				839, -- [8]
				1215, -- [9]
				1217, -- [10]
				3048, -- [11]
				3752, -- [12]
				59, -- [13]
			},
		},
		[577] = {
			["talents"] = {
				{
					21854, -- [1]
					22493, -- [2]
					22416, -- [3]
				}, -- [1]
				{
					21857, -- [1]
					22765, -- [2]
					22799, -- [3]
				}, -- [2]
				{
					22909, -- [1]
					22494, -- [2]
					21862, -- [3]
				}, -- [3]
				{
					21863, -- [1]
					21864, -- [2]
					21865, -- [3]
				}, -- [4]
				{
					21866, -- [1]
					21867, -- [2]
					21868, -- [3]
				}, -- [5]
				{
					21869, -- [1]
					21870, -- [2]
					22767, -- [3]
				}, -- [6]
				{
					21900, -- [1]
					21901, -- [2]
					22547, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3426, -- [1]
				3427, -- [2]
				3428, -- [3]
			},
			["pvptalents"] = {
				812, -- [1]
				806, -- [2]
				807, -- [3]
				809, -- [4]
				813, -- [5]
				1218, -- [6]
				810, -- [7]
				1206, -- [8]
				1204, -- [9]
				805, -- [10]
				811, -- [11]
			},
		},
		[65] = {
			["talents"] = {
				{
					17565, -- [1]
					17567, -- [2]
					17569, -- [3]
				}, -- [1]
				{
					22176, -- [1]
					17575, -- [2]
					17577, -- [3]
				}, -- [2]
				{
					22179, -- [1]
					22180, -- [2]
					21811, -- [3]
				}, -- [3]
				{
					22181, -- [1]
					17591, -- [2]
					17593, -- [3]
				}, -- [4]
				{
					17597, -- [1]
					17599, -- [2]
					22164, -- [3]
				}, -- [5]
				{
					23191, -- [1]
					22190, -- [2]
					22484, -- [3]
				}, -- [6]
				{
					21668, -- [1]
					21671, -- [2]
					21203, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3549, -- [1]
				3548, -- [2]
				3547, -- [3]
			},
			["pvptalents"] = {
				87, -- [1]
				859, -- [2]
				88, -- [3]
				3618, -- [4]
				640, -- [5]
				689, -- [6]
				642, -- [7]
				82, -- [8]
				85, -- [9]
				86, -- [10]
			},
		},
		[256] = {
			["talents"] = {
				{
					19752, -- [1]
					22313, -- [2]
					22329, -- [3]
				}, -- [1]
				{
					22315, -- [1]
					22316, -- [2]
					19758, -- [3]
				}, -- [2]
				{
					22440, -- [1]
					22094, -- [2]
					19755, -- [3]
				}, -- [3]
				{
					19759, -- [1]
					19769, -- [2]
					19761, -- [3]
				}, -- [4]
				{
					22330, -- [1]
					19765, -- [2]
					19766, -- [3]
				}, -- [5]
				{
					22161, -- [1]
					19760, -- [2]
					19763, -- [3]
				}, -- [6]
				{
					21183, -- [1]
					21184, -- [2]
					22976, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3556, -- [1]
				3554, -- [2]
				3555, -- [3]
			},
			["pvptalents"] = {
				109, -- [1]
				126, -- [2]
				114, -- [3]
				111, -- [4]
				1244, -- [5]
				98, -- [6]
				100, -- [7]
				117, -- [8]
				855, -- [9]
				123, -- [10]
			},
		},
		[64] = {
			["talents"] = {
				{
					22457, -- [1]
					22460, -- [2]
					22463, -- [3]
				}, -- [1]
				{
					22442, -- [1]
					22443, -- [2]
					23073, -- [3]
				}, -- [2]
				{
					22444, -- [1]
					22445, -- [2]
					22447, -- [3]
				}, -- [3]
				{
					22452, -- [1]
					22466, -- [2]
					22469, -- [3]
				}, -- [4]
				{
					22446, -- [1]
					22448, -- [2]
					22471, -- [3]
				}, -- [5]
				{
					22454, -- [1]
					23176, -- [2]
					22473, -- [3]
				}, -- [6]
				{
					21632, -- [1]
					22309, -- [2]
					21634, -- [3]
				}, -- [7]
			},
			["pvptalenttrinkets"] = {
				3584, -- [1]
				3586, -- [2]
				3585, -- [3]
			},
			["pvptalents"] = {
				632, -- [1]
				3532, -- [2]
				3443, -- [3]
				633, -- [4]
				57, -- [5]
				58, -- [6]
				634, -- [7]
				3516, -- [8]
				66, -- [9]
				67, -- [10]
				68, -- [11]
			},
		},
	};
	function GetTalentInfoForSpecID(specID, tier, column)
		for specIndex=1,GetNumSpecializations() do
			local playerSpecID = GetSpecializationInfo(specIndex);
			if playerSpecID == specID then
				return GetTalentInfoBySpecialization(specIndex, tier, column);
			end
		end

		if BtWLoadoutsSpecInfo[specID] then
			return GetTalentInfoByID(BtWLoadoutsSpecInfo[specID].talents[tier][column]);
		end

		if specInfo[specID] then
			return GetTalentInfoByID(specInfo[specID].talents[tier][column]);
		end
	end
	function GetPvPTrinketTalentInfo(specID, index)
		local playerSpecID = GetSpecializationInfo(GetSpecialization());
		if playerSpecID == specID then
			local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(1);
			if slotInfo and slotInfo.availableTalentIDs[index] then
				return GetPvpTalentInfoByID(slotInfo.availableTalentIDs[index]);
			end
		end

		if BtWLoadoutsSpecInfo[specID] and BtWLoadoutsSpecInfo[specID].pvptalenttrinkets and BtWLoadoutsSpecInfo[specID].pvptalenttrinkets[index] then
			return GetPvpTalentInfoByID(BtWLoadoutsSpecInfo[specID].pvptalenttrinkets[index]);
		end

		if specInfo[specID] and specInfo[specID].pvptalenttrinkets and specInfo[specID].pvptalenttrinkets[index] then
			return GetPvpTalentInfoByID(specInfo[specID].pvptalenttrinkets[index]);
		end
	end
	function GetPvPTalentInfoForSpecID(specID, index)
		local playerSpecID = GetSpecializationInfo(GetSpecialization());
		if playerSpecID == specID then
			local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(2);
			if slotInfo and slotInfo.availableTalentIDs[index] then
				return GetPvpTalentInfoByID(slotInfo.availableTalentIDs[index]);
			end
		end

		if BtWLoadoutsSpecInfo[specID] and BtWLoadoutsSpecInfo[specID].pvptalents and BtWLoadoutsSpecInfo[specID].pvptalents[index] then
			return GetPvpTalentInfoByID(BtWLoadoutsSpecInfo[specID].pvptalents[index]);
		end

		if specInfo[specID] and specInfo[specID].pvptalents and specInfo[specID].pvptalents[index] then
			return GetPvpTalentInfoByID(specInfo[specID].pvptalents[index]);
		end
	end
end
local function GetEssenceInfoByID(essenceID)
	local essence = C_AzeriteEssence.GetEssenceInfo(essenceID);
	if not essence then
		essence = BtWLoadoutsEssenceInfo and BtWLoadoutsEssenceInfo[essenceID] or essenceInfo[essenceID];
	end
	return essence;
end
local function GetEssenceInfoForRole(role, index)
	if BtWLoadoutsRoleInfo[role] and BtWLoadoutsRoleInfo[role].essences and BtWLoadoutsRoleInfo[role].essences[index] then
        return GetEssenceInfoByID(BtWLoadoutsRoleInfo[role].essences[index]);
    end

    if roleInfo[role] and roleInfo[role].essences and roleInfo[role].essences[index] then
        return GetEssenceInfoByID(roleInfo[role].essences[index]);
    end
end
local function GetCharacterInfo(character)
	return BtWLoadoutsCharacterInfo and BtWLoadoutsCharacterInfo[character];
end
local function IsClassRoleValid(classFile, role)
	return classInfo[classFile][role] and true or false;
end
local PlayerNeedsTome;
do
	local talentChangeBuffs = {
		[227041] = true,
		[227563] = true,
		[256231] = true,
		[228128] = true,
		[32727] = true,
		[44521] = true,
	};
	local function PlayerCanChangeTalents()
		if IsResting() then
			return true;
		end

		local index = 1;
		local name = UnitAura("player", index, "HELPFUL");
		while name do
			if talentChangeBuffs[spellId] then
				return true;
			end

			index = index + 1;
			name = UnitAura("player", index, "HELPFUL");
		end
		
		return false;
	end
	function PlayerNeedsTome()
		if IsResting() then
			return false;
		end

		local index = 1;
		local name, _, _, _, _, _, _, _, _, spellId = UnitAura("player", index, "HELPFUL");
		while name do
			if talentChangeBuffs[spellId] then
				return false;
			end

			index = index + 1;
			name, _, _, _, _, _, _, _, _, spellId = UnitAura("player", index, "HELPFUL");
		end

		return true;
	end
end
local RequestTome;
do
	local tomes = {
		141446,
		153647
	};
	local function GetBestTome()
		for _,itemId in ipairs(tomes) do
			local count = GetItemCount(itemId);
			if count >= 1 then
				local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemId);
				return itemId, name, link, quality, icon;
			end
		end
	end
	function RequestTome()
		if not StaticPopup_Visible("BTWLOADOUTS_NEEDTOME") then --  and not StaticPopup_Visible("BTWLOADOUTS_NEEDRESTED")
			local itemId, name, link, quality, icon = GetBestTome();
			if name ~= nil then
				local r, g, b = GetItemQualityColor(quality or 2); 
				StaticPopup_Show("BTWLOADOUTS_NEEDTOME", "", nil, {["texture"] = icon, ["name"] = name, ["color"] = {r, g, b, 1}, ["link"] = link, ["count"] = 1});
			elseif itemId == nil then
				-- StaticPopup_Show("BTWLOADOUTS_NEEDRESTED", "", nil, {["texture"] = icon, ["name"] = name, ["color"] = {r, g, b, 1}, ["link"] = link, ["count"] = 1});
			end
		end
	end
end
local function IsChangingSpec()
    local _, _, _, _, _, _, _, _, spellId = UnitCastingInfo("player");
    return spellId == 200749;
end
local function UpdateAreaMap()
	local instanceID = select(8, GetInstanceInfo());
	if instanceID and InstanceAreaIDToBossID[instanceID] then
		areaNameToIDMap[instanceID] = areaNameToIDMap[instanceID] or {};
		local map = areaNameToIDMap[instanceID];
		for areaID in pairs(InstanceAreaIDToBossID[instanceID]) do
			local areaName = C_Map.GetAreaInfo(areaID);
			if areaName then
				map[areaName] = areaID;
			end
		end
	end
end

local eventHandler = CreateFrame("Frame");
eventHandler:Hide();

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

-- Activating a set can take multiple passes, things maybe delayed by switching spec or waiting for the player to use a tome
local target = {};
_G['BtWLoadoutsTarget'] = target; -- @TODO REMOVE
local function CancelActivateProfile()
	wipe(target);
	eventHandler:UnregisterAllEvents();
	eventHandler:Hide();
end

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
UIDropDownMenu_SetWidth(conditionProfilesDropDown, 170);
UIDropDownMenu_Initialize(conditionProfilesDropDown, ConditionProfilesDropDownInit);
UIDropDownMenu_JustifyText(conditionProfilesDropDown, "LEFT");

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
    OnShow = function(self)
        tomeButton:SetParent(self);
        tomeButton:ClearAllPoints();
        tomeButton:SetPoint("TOPLEFT", self.button1, "TOPLEFT", 0, 0);
        tomeButton:SetPoint("BOTTOMRIGHT", self.button1, "BOTTOMRIGHT", 0, 0);
        tomeButton.button = self.button1;

        tomeButton:SetFrameLevel(self.button1:GetFrameLevel() + 1);
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
    OnShow = function(self)
        tomeButton:SetParent(self);
        tomeButton:ClearAllPoints();
        tomeButton:SetPoint("TOPLEFT", self.button1, "TOPLEFT", 0, 0);
        tomeButton:SetPoint("BOTTOMRIGHT", self.button1, "BOTTOMRIGHT", 0, 0);
        tomeButton.button = self.button1;

        tomeButton:SetFrameLevel(self.button1:GetFrameLevel() + 1);
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


local function GetNextSetID(sets)
	local nextID = sets.nextID or 1;
	while sets[nextID] ~= nil do
		nextID = nextID + 1;
	end
	sets.nextID = nextID;
	return nextID;
end
local function DeleteSet(sets, id)
	if type(id) == "table" then
		if id.setID then
			DeleteSet(sets, id.setID);
		else
			for k,v in pairs(BtWLoadoutsSets.profiles) do
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

-- Check if the talents in the table talentIDs are selected
local function IsTalentSetActive(set)
    for talentID in pairs(set.talents) do
		local _, _, _, selected, available = GetTalentInfoByID(talentID, 1);

        if not selected then
            return false;
        end
    end

    return true;
end
local function ActivateTalentSet(set)
	for talentID in pairs(set.talents) do
		local selected, _, _, _, tier = select(4, GetTalentInfoByID(talentID, 1));
		if not selected and GetTalentTierInfo(tier, 1) then
			LearnTalent(talentID);
		end
	end
end
local function AddTalentSet()
    local specID, specName = GetSpecializationInfo(GetSpecialization());
    local name = format(L["New %s Set"], specName);
    local talents = {};
    
	for tier=1,MAX_TALENT_TIERS do
        local _, column = GetTalentTierInfo(tier, 1);
        local talentID = GetTalentInfo(tier, column, 1);
        if talentID then
            talents[talentID] = true;
        end
    end

    local set = {
		setID = GetNextSetID(BtWLoadoutsSets.talents),
        specID = specID,
        name = name,
        talents = talents,
		useCount = 0,
    };
    BtWLoadoutsSets.talents[set.setID] = set;
    return set;
end
local function GetTalentSet(id)
    if type(id) == "table" then
		return id;
	else
		return BtWLoadoutsSets.talents[id];
	end;
end
local function GetTalentSetByName(name)
	for _,set in pairs(BtWLoadoutsSets.talents) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
end
local function GetTalentSets(id, ...)
	if id ~= nil then
		return GetTalentSet(id), GetTalentSets(...);
	end
end
local function GetTalentSetIfNeeded(id)
	if id == nil then
		return;
	end

	local set = GetTalentSet(id);
	if IsTalentSetActive(set) then
		return;
	end

    return set;
end
local talentSetsByTier = {};
local function CombineTalentSets(result, ...)
	local result = result or {};
	result.talents = {};

	wipe(talentSetsByTier);
	for i=1,select('#', ...) do
		local set = select(i, ...);
		for talentID in pairs(set.talents) do
			if result.talents[talentID] == nil then
				local tier = select(8, GetTalentInfoByID(talentID, 1));
				if talentSetsByTier[tier] then
					result.talents[talentSetsByTier[tier]] = nil;
				end

				result.talents[talentID] = true;
				talentSetsByTier[tier] = talentID;
			end
		end
	end

	return result;
end
local function DeleteTalentSet(id)
	DeleteSet(BtWLoadoutsSets.talents, id);

	if type(id) == "table" then
		id = id.setID;
	end
	for _,set in pairs(BtWLoadoutsSets.profiles) do
		if type(set) == "table" and set.talentSet == id then
			set.talentSet = nil;
		end
	end

	local frame = BtWLoadoutsFrame.Talents;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil;-- = select(2,next(BtWLoadoutsSets.talents)) or {};
		BtWLoadoutsFrame:Update();
	end
end

local function IsPvPTalentSetActive(set)
	for talentID in pairs(set.talents) do
        local _, _, _, selected, available = GetPvpTalentInfoByID(talentID, 1);

        if not selected then
            return false;
        end
    end

    return true;
end
local function ActivatePvPTalentSet(set)
	local talents = {};
	local usedSlots = {};

	for talentID in pairs(set.talents) do
		talents[talentID] = true;
	end

	local selectedTalents = C_SpecializationInfo.GetAllSelectedPvpTalentIDs();
	for slot,talentID in pairs(selectedTalents) do
		if talents[talentID] then
			usedSlots[slot] = true;
			talents[talentID] = nil;
		end
	end

	local playerLevel = UnitLevel("player");
	for slot=1,4 do
		if not usedSlots[slot] and C_SpecializationInfo.GetPvpTalentSlotUnlockLevel(slot) <= playerLevel then
			local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slot);

			for _,talentID in ipairs(slotInfo.availableTalentIDs) do
				if talents[talentID] then
					LearnPvpTalent(talentID, slot);

					usedSlots[slot] = true;
					talents[talentID] = nil;

					break;
				end
			end
		end
	end
end
local function AddPvPTalentSet()
    local specID, specName = GetSpecializationInfo(GetSpecialization());
    local name = format(L["New %s Set"], specName);
	local talents = {};
	
    local talentIDs = C_SpecializationInfo.GetAllSelectedPvpTalentIDs();
    for _,talentID in ipairs(talentIDs) do
		talents[talentID] = true;
    end

    local set = {
		setID = GetNextSetID(BtWLoadoutsSets.pvptalents),
        specID = specID,
        name = name,
        talents = talents,
		useCount = 0,
    };
    BtWLoadoutsSets.pvptalents[set.setID] = set;
    return set;
end
local function GetPvPTalentSet(id)
    return BtWLoadoutsSets.pvptalents[id];
end
local function GetPvPTalentSetByName(name)
	for _,set in pairs(BtWLoadoutsSets.pvptalents) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
end
local function GetPvPTalentSets(id, ...)
	if id ~= nil then
		return BtWLoadoutsSets.pvptalents[id], GetPvPTalentSets(...);
	end
end
local function GetPvPTalentSetIfNeeded(id)
	if id == nil then
		return;
	end

	local set = GetPvPTalentSet(id);
	if IsPvPTalentSetActive(set) then
		return;
	end

    return set;
end
local function CombinePvPTalentSets(result, ...)
	local result = result or {};
	result.talents = {};

	wipe(talentSetsByTier);
	for i=1,select('#', ...) do
		local set = select(i, ...);
		for talentID in pairs(set.talents) do
			if result.talents[talentID] == nil then
				result.talents[talentID] = true;
			end
		end
	end

	return result;
end
local function DeletePvPTalentSet(id)
	DeleteSet(BtWLoadoutsSets.pvptalents, id);

	if type(id) == "table" then
		id = id.setID;
	end
	for _,set in pairs(BtWLoadoutsSets.profiles) do
		if type(set) == "table" and set.pvpTalentSet == id then
			set.pvpTalentSet = nil;
		end
	end

	local frame = BtWLoadoutsFrame.PvPTalents;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil;-- = select(2,next(BtWLoadoutsSets.pvptalents)) or {};
		BtWLoadoutsFrame:Update();
	end
end

local function IsEssenceSetActive(set)
    for milestoneID,essenceID in pairs(set.essences) do
        local info = C_AzeriteEssence.GetMilestoneInfo(milestoneID);
        if (info.unlocked or info.canUnlock) and C_AzeriteEssence.GetMilestoneEssence(milestoneID) ~= essenceID then
            return false;
        end
    end

    return true;
end
local function ActivateEssenceSet(set)
	local complete = true;
    for milestoneID,essenceID in pairs(set.essences) do
        local info = C_AzeriteEssence.GetMilestoneInfo(milestoneID);
        if info.canUnlock then
            C_AzeriteEssence.UnlockMilestone(milestoneID);
            info.unlocked = true;
        end

		if info.unlocked then
			if C_AzeriteEssence.GetMilestoneEssence(milestoneID) ~= essenceID then
				complete = false;
			end
            C_AzeriteEssence.ActivateEssence(essenceID, milestoneID);
        end
	end
	-- If its taken us 5 attempts to equip a set its probably not going to happen
	target.essencePass = (target.essencePass or 0) + 1;
	if target.essencePass >= 5 then
		-- if not complete then
		-- 	print(format("Failed after %d passes to essence set", target.essencePass));
		-- end
		return true;
	end
	-- if complete then
	-- 	print(format("Took %d passes to essence set", target.essencePass));
	-- end

	return complete;
end
local function AddEssenceSet()
    local role = select(5,GetSpecializationInfo(GetSpecialization()));
    local name = format(L["New %s Set"], _G[role]);
	local selected = {};
	
    selected[115] = C_AzeriteEssence.GetMilestoneEssence(115);
    selected[116] = C_AzeriteEssence.GetMilestoneEssence(116);
    selected[117] = C_AzeriteEssence.GetMilestoneEssence(117);

    local set = {
		setID = GetNextSetID(BtWLoadoutsSets.essences),
        role = role,
        name = name,
        essences = selected,
		useCount = 0,
    };
    BtWLoadoutsSets.essences[set.setID] = set;
    return set;
end
local function GetEssenceSet(id)
    return BtWLoadoutsSets.essences[id];
end
local function GetEssenceSetByName(name)
	for _,set in pairs(BtWLoadoutsSets.essences) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
end
local function GetEssenceSets(id, ...)
	if id ~= nil then
		return BtWLoadoutsSets.essences[id], GetEssenceSets(...);
	end
end
local function GetEssenceSetIfNeeded(id)
	if id == nil then
		return;
	end

	local set = GetEssenceSet(id);
	if IsEssenceSetActive(set) then
		return;
	end

    return set;
end
local function CombineEssenceSets(result, ...)
	local result = result or {};

	result.essences = {};
	for i=1,select('#', ...) do
		local set = select(i, ...);
		for milestoneID, essenceID in pairs(set.essences) do
			result.essences[milestoneID] = essenceID;
		end
	end

	return result;
end
local function DeleteEssenceSet(id)
	DeleteSet(BtWLoadoutsSets.essences, id);

	if type(id) == "table" then
		id = id.setID;
	end
	for _,set in pairs(BtWLoadoutsSets.profiles) do
		if type(set) == "table" and set.essencesSet == id then
			set.essencesSet = nil;
		end
	end

	local frame = BtWLoadoutsFrame.Essences;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil;-- = select(2,next(BtWLoadoutsSets.essences)) or {};
		BtWLoadoutsFrame:Update();
	end
end

-- A map from the equipment manager ids to our sets
local equipmentSetMap = {};
local function CompareItemLinks(a, b)
	local itemIDA = GetItemInfoInstant(a);
	local itemIDB = GetItemInfoInstant(b);
	
	return itemIDA == itemIDB;
end
local function CompareItems(itemLinkA, itemLinkB)
	return CompareItemLinks(itemLinkA, itemLinkB);
end
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

	if upgradeTypeID and upgradeTypeID ~= 0 then
		error("Unsupported item link");
	end

	local relic1NumBonusIDs = tonumber(linkData[index]) or 0;
	local relic1BonusIDs = {};
	for i=1,relic1NumBonusIDs do
		relic1BonusIDs[i] = tonumber(linkData[index + i]);
	end
	index = index + numBonusIDs + 1;

	local relic2NumBonusIDs = tonumber(linkData[index]) or 0;
	local relic2BonusIDs = {};
	for i=1,relic2NumBonusIDs do
		relic2BonusIDs[i] = tonumber(linkData[index + i]);
	end
	index = index + numBonusIDs + 1;

	local relic3NumBonusIDs = tonumber(linkData[index]) or 0;
	local relic3BonusIDs = {};
	for i=1,relic3NumBonusIDs do
		relic3BonusIDs[i] = tonumber(linkData[index + i]);
	end
	index = index + numBonusIDs + 1;

	return itemID, enchantID, gemIDs, suffixID, uniqueID, upgradeTypeID, bonusIDs, nil, relic1BonusIDs, relic2BonusIDs, relic3BonusIDs;
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

    if combatSwap then
        firstEquipped = INVSLOT_MAINHAND;
        lastEquipped = INVSLOT_RANGED;
	end
	
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

		if combatSwap then
			firstEquipped = INVSLOT_MAINHAND
			lastEquipped = INVSLOT_RANGED 
		end
		
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
		
		target.equipPass = target.equipPass or 0;
		if not anyLockedSlots then
			target.equipPass = target.equipPass + 1;
		end
		
		-- Unequip items
		local complete = true
		for inventorySlotId = firstEquipped, lastEquipped do
			if not ignored[inventorySlotId] then
				if expected[inventorySlotId] then
					if not IsInventoryItemLocked(inventorySlotId) and target.equipPass >= 5 then
						print('Cannot equip ' .. expected[inventorySlotId]);
					end
					complete = false
				else -- Unequip
					if not EmptyInventorySlot(inventorySlotId) then
						if not IsInventoryItemLocked(inventorySlotId) and target.equipPass >= 5 then
							print('Cannot unequip ' .. GetInventoryItemLink("player", inventorySlotId))
						end
						complete = false
					end
				end
			end
		end
		
		ClearCursor()
		-- If its taken us 5 attempts to equip a set its probably not going to happen
		if target.equipPass >= 5 then
			-- if not complete then
			-- 	print(format("Failed after %d passes to equip set", target.equipPass));
			-- end
			return true;
		end
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
		setID = GetNextSetID(BtWLoadoutsSets.equipment),
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
    local characterName, characterRealm = UnitName("player"), GetRealmName();
    local set = {
		setID = GetNextSetID(BtWLoadoutsSets.equipment),
        character = characterRealm .. "-" .. characterName,
        name = name,
		equipment = {},
		extras = {},
		locations = {},
		ignored = {},
		useCount = 0,
    };
    BtWLoadoutsSets.equipment[set.setID] = set;
    return set;
end
local function GetEquipmentSet(id)
    return BtWLoadoutsSets.equipment[id];
end
local function GetEquipmentSetByName(name)
	for _,set in pairs(BtWLoadoutsSets.equipment) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
end
local function GetEquipmentSets(id, ...)
	if id ~= nil then
		return BtWLoadoutsSets.equipment[id], GetEquipmentSets(...);
	end
end
local function GetEquipmentSetIfNeeded(id)
	if id == nil then
		return;
	end

	local set = GetEquipmentSet(id);
	if IsEquipmentSetActive(set) then
		return;
	end

    return set;
end
local function CombineEquipmentSets(result, ...)
	local result = result or {};

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
	DeleteSet(BtWLoadoutsSets.equipment, id);

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

-- Check all the pieces of a profile and make sure they are valid together
local function IsProfileValid(set)
	local class, specID, role, invalidForPlayer;

	local playerClass = select(2, UnitClass("player"));

	if set.equipmentSet then
		local subSet = GetEquipmentSet(set.equipmentSet);
		local characterInfo = GetCharacterInfo(subSet.character);
		if not characterInfo then
			return false, true, false, false, false;
		end
		class = characterInfo.class;
		
		local name, realm = UnitName("player"), GetRealmName();
		local playerCharacter = format("%s-%s", realm, name);
		invalidForPlayer = invalidForPlayer or (subSet.character ~= playerCharacter);
	end

	if set.essencesSet then
		local subSet = GetEssenceSet(set.essencesSet);
		role = subSet.role;
		
		invalidForPlayer = invalidForPlayer or not IsClassRoleValid(playerClass, role);
	end

	if set.talentSet then
		local subSet = GetTalentSet(set.talentSet);

		if specID ~= nil and specID ~= subSet.specID then
			return false, false, true, false, false;
		end

		specID = subSet.specID;
	end
	
	if set.pvpTalentSet then
		local subSet = GetPvPTalentSet(set.pvpTalentSet);
		
		if specID ~= nil and specID ~= subSet.specID then
			return false, false, true, false, false;
		end

		specID = subSet.specID;
	end

	if specID then
		local specClass = select(6, GetSpecializationInfoByID(specID));
		invalidForPlayer = invalidForPlayer or (playerClass ~= specClass);
	end

	if specID and (class ~= nil or role ~= nil) then
		local specRole, specClass = select(5, GetSpecializationInfoByID(specID));

		if class ~= nil and class ~= specClass then
			return false, true, true, false, false;
		end

		if role ~= nil and role ~= specRole then
			return false, false, true, true, false;
		end
	end

	if class and role then
		if not IsClassRoleValid(class, role) then
			return false, true, false, true, false;
		end
	end

	return true, class, specID, role, not invalidForPlayer;
end
local function AddProfile()
    local name = L["New Profile"];

    local set = {
		setID = GetNextSetID(BtWLoadoutsSets.profiles),
        specID = specID,
		name = name,
		useCount = 0,
    };
    BtWLoadoutsSets.profiles[set.setID] = set;
    return set;
end
local function GetProfile(id)
    return BtWLoadoutsSets.profiles[id];
end
local function GetProfileByName(name)
	for _,set in pairs(BtWLoadoutsSets.profiles) do
		if type(set) == "table" and set.name:lower():trim() == name:lower():trim() then
			return set;
		end
	end
end
local function DeleteProfile(id)
	do
		local set = type(id) == "table" and id or GetProfile(id);
		if set.talentSet then
			local subSet = GetTalentSet(set.talentSet);
			subSet.useCount = (subSet.useCount or 1) - 1;
		end
		if set.pvpTalentSet then
			local subSet = GetPvPTalentSet(set.pvpTalentSet);
			subSet.useCount = (subSet.useCount or 1) - 1;
		end
		if set.essences then
			local subSet = GetEssencetSet(set.essences);
			subSet.useCount = (subSet.useCount or 1) - 1;
		end
		if set.equipmentSet then
			local subSet = GetEquipmentSet(set.equipmentSet);
			subSet.useCount = (subSet.useCount or 1) - 1;
		end
	end
	DeleteSet(BtWLoadoutsSets.profiles, id);

	local frame = BtWLoadoutsFrame.Profiles;
	local set = frame.set;
	if set == id or set.setID == id then
		frame.set = nil;--select(2,next(BtWLoadoutsSets.profiles)) or {};
		BtWLoadoutsFrame:Update();
	end
end
local function ActivateProfile(profile)
	local valid, class, specID, role, validForPlayer = IsProfileValid(profile);
	if not valid or not validForPlayer then
		--@TODO display an error
		return;
	end

	target.active = true;

	if specID then
		target.specID = specID or profile.specID;
	end

	if profile.talentSet then
		target.talentSets = target.talentSets or {};
		target.talentSets[#target.talentSets+1] = profile.talentSet;
	end
	if profile.pvpTalentSet then
		target.pvpTalentSets = target.pvpTalentSets or {};
		target.pvpTalentSets[#target.pvpTalentSets+1] = profile.pvpTalentSet;
	end
	if profile.essencesSet then
		target.essencesSets = target.essencesSets or {};
		target.essencesSets[#target.essencesSets+1] = profile.essencesSet;
	end
	if profile.equipmentSet then
		target.equipmentSets = target.equipmentSets or {};
		target.equipmentSets[#target.equipmentSets+1] = profile.equipmentSet;
	end

    target.dirty = true;
	eventHandler:RegisterEvent("GET_ITEM_INFO_RECEIVED");
	eventHandler:RegisterEvent("PLAYER_REGEN_DISABLED");
	eventHandler:RegisterEvent("PLAYER_REGEN_ENABLED");
	eventHandler:RegisterEvent("PLAYER_UPDATE_RESTING");
	eventHandler:RegisterUnitEvent("UNIT_AURA", "player");
	eventHandler:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
	eventHandler:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
	eventHandler:RegisterEvent("ZONE_CHANGED");
	eventHandler:RegisterEvent("ZONE_CHANGED_INDOORS");
	eventHandler:RegisterEvent("ITEM_UNLOCKED");
	eventHandler:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player");
	eventHandler:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player");
	eventHandler:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player");
	eventHandler:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player");
	eventHandler:Show();
end
local function IsProfileActive(set)
	if set.specID then
		local playerSpecID = GetSpecializationInfo(GetSpecialization());
		if set.specID ~= playerSpecID then
			return false;
		end
	end

	if set.talentSet then
		-- local talentSet = CombineTalentSets({}, GetTalentSets(unpack(set.talentSets)));
		local talentSet = GetTalentSet(set.talentSet);
		if not IsTalentSetActive(talentSet) then
			return false;
		end
	end

	if set.pvpTalentSet then
		-- local pvpTalentSet = CombinePvPTalentSets({}, GetPvPTalentSets(unpack(set.pvpTalentSets)));
		local pvpTalentSet = GetPvPTalentSet(set.pvpTalentSet);
		if not IsPvPTalentSetActive(pvpTalentSet) then
			return false;
		end
	end

	if set.essencesSet then
		-- local essencesSet = CombineEssenceSets({}, GetEssenceSets(unpack(set.essencesSets)));
		local essencesSet = GetEssenceSet(set.essencesSet);
		if not IsEssenceSetActive(essencesSet) then
			return false;
		end
	end

	if set.equipmentSet then
		-- local equipmentSet = CombineEquipmentSets({}, GetEquipmentSets(unpack(set.equipmentSets)));
		local equipmentSet = GetEquipmentSet(set.equipmentSet);
		if not IsEquipmentSetActive(equipmentSet) then
			return false;
		end
	end

	return true;
end
local function ContinueActivateProfile()
    local set = target;
	set.dirty = false;

	if InCombatLockdown() then
        return;
    end

	if IsChangingSpec() then
        return;
    end
	
	local specID = set.specID;
	local playerSpecID = GetSpecializationInfo(GetSpecialization());
    if specID ~= playerSpecID then
		for specIndex=1,GetNumSpecializations() do
			if GetSpecializationInfo(specIndex) == specID then
				SetSpecialization(specIndex);
				target.dirty = false;
				return;
			end
		end
    end

	local talentSet;
	if set.talentSets then
		talentSet = CombineTalentSets({}, GetTalentSets(unpack(set.talentSets)));
	end

	local pvpTalentSet;
	if set.pvpTalentSets then
		pvpTalentSet = CombinePvPTalentSets({}, GetPvPTalentSets(unpack(set.pvpTalentSets)));
	end

	local essencesSet;
	if set.essencesSets then
		essencesSet = CombineEssenceSets({}, GetEssenceSets(unpack(set.essencesSets)));
	end

	if talentSet and not IsTalentSetActive(talentSet) and PlayerNeedsTome() then
		RequestTome();
		return;
	end

	if pvpTalentSet and not IsPvPTalentSetActive(pvpTalentSet) and PlayerNeedsTome() then
		RequestTome();
		return;
	end

	if essencesSet and not IsEssenceSetActive(essencesSet) and PlayerNeedsTome() then
		RequestTome();
		return;
	end

	StaticPopup_Hide("BTWLOADOUTS_NEEDTOME");
	-- StaticPopup_Hide("BTWLOADOUTS_NEEDRESTED");

	local complete = true;
    if talentSet then
        ActivateTalentSet(talentSet);
    end

    if pvpTalentSet then
        ActivatePvPTalentSet(pvpTalentSet);
    end

    if essencesSet then
		if not ActivateEssenceSet(essencesSet) then
			complete = false;
			set.dirty = true; -- Just run next frame
		end
    end

	local equipmentSet;
	if set.equipmentSets then
		equipmentSet = CombineEquipmentSets({}, GetEquipmentSets(unpack(set.equipmentSets)));

		if equipmentSet then
			if not ActivateEquipmentSet(equipmentSet) then
				complete = false;
			end
		end
	end

	-- Done
	if complete then
		CancelActivateProfile();
	end
end

-- Maps condition flags to condition groups
local conditionMap = {
	instanceType = {},
	difficultyID = {},
	instanceID = {},
	bossID = {},
	affixesID = {},
};
_G['BtWLoadoutsConditionMap'] = conditionMap; --@TODO Remove
local function ActivateConditionMap(map, key)
	if key ~= nil and map[key] ~= nil then
		local tbl = map[key];
		for k,v in pairs(tbl) do
			tbl[k] = true;
		end
	end
end
local function DeactivateConditionMap(map, key)
	if key ~= nil and map[key] ~= nil then
		local tbl = map[key];
		for k,v in pairs(tbl) do
			tbl[k] = false;
		end
	end
end
local function AddConditionToMap(set)
	if set.profileSet ~= nil then
		local profile = GetProfile(set.profileSet);
		local valid = select(5, IsProfileValid(profile));
		if valid then
			for k,v in pairs(set.map) do
				conditionMap[k][v] = conditionMap[k][v] or {};
				conditionMap[k][v][set] = false;
			end
		end
	end
end
local function RemoveConditionFromMap(set)
	for k,v in pairs(set.map) do
		conditionMap[k][v] = conditionMap[k][v] or {};
		conditionMap[k][v][set] = nil;
	end
end
local function IsConditionActive(condition)
	local matchCount = 0;
	for k,v in pairs(condition.map) do
		if not conditionMap[k][v][condition] then
			return false;
		end
		matchCount = matchCount + 1;
	end

	return matchCount;
end
local function AddConditionSet()
	local name = L["New Condition Set"];
	
    local set = {
		setID = GetNextSetID(BtWLoadoutsSets.conditions),
		name = name,
		type = CONDITION_TYPE_WORLD,
		map = {},
    };
    BtWLoadoutsSets.conditions[set.setID] = set;
    return set;
end
local function GetConditionSet(id)
    return BtWLoadoutsSets.conditions[id];
end
local function DeleteConditionSet(id)
	local set = type(id) == "table" and id or GetProfile(id);
	if set.profileSet then
		local subSet = GetProfile(set.profileSet);
		subSet.useCount = (subSet.useCount or 1) - 1;
	end
	RemoveConditionFromMap(set);

	DeleteSet(BtWLoadoutsSets.conditions, id);

	if type(id) == "table" then
		id = id.setID;
	end

	local frame = BtWLoadoutsFrame.Conditions;
	local set = frame.set;
	if set.setID == id then
		frame.set = nil;
		BtWLoadoutsFrame:Update();
	end
end
local previousConditionInfo = {};
_G['BtWLoadoutsPreviousConditionInfo'] = previousConditionInfo; --@TODO Remove
local function UpdateConditionsForInstance()
	local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo();
	if previousConditionInfo.instanceType ~= instanceType then
		DeactivateConditionMap(conditionMap.instanceType, previousConditionInfo.instanceType);
		ActivateConditionMap(conditionMap.instanceType, instanceType);
		previousConditionInfo.instanceType = instanceType;
	end
	if previousConditionInfo.difficultyID ~= difficultyID then
		DeactivateConditionMap(conditionMap.difficultyID, previousConditionInfo.difficultyID);
		ActivateConditionMap(conditionMap.difficultyID, difficultyID);
		previousConditionInfo.difficultyID = difficultyID;
	end
	if previousConditionInfo.instanceID ~= instanceID then
		DeactivateConditionMap(conditionMap.instanceID, previousConditionInfo.instanceID);
		ActivateConditionMap(conditionMap.instanceID, instanceID);
		previousConditionInfo.instanceID = instanceID;
	end
end
local function UpdateConditionsForBoss(unitId)
	local bossID = previousConditionInfo.bossID;
	local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo();
	if instanceType == "party" or instanceType == "raid" then
		local uiMapID = C_Map.GetBestMapForUnit("player");
		if uiMapID then
			bossID = uiMapIDToBossID[uiMapID] or bossID;
		end
		local areaID = instanceID and areaNameToIDMap[instanceID] and areaNameToIDMap[instanceID][GetSubZoneText()] or nil;
		if areaID then
			bossID = InstanceAreaIDToBossID[instanceID][areaID] or bossID;
		end
		if unitId then
			local unitGUID = UnitGUID(unitId);
			if unitGUID and not UnitIsDead(unitId) then
				local type, zero, serverId, instanceId, zone_uid, npcId, spawn_uid = strsplit("-", unitGUID);
				if type == "Creature" and tonumber(npcId) then
					bossID = npcIDToBossID[tonumber(npcId)] or bossID;
				end
			end
		end
	end

	if previousConditionInfo.bossID ~= bossID then
		DeactivateConditionMap(conditionMap.bossID, previousConditionInfo.bossID);
		ActivateConditionMap(conditionMap.bossID, bossID);
		previousConditionInfo.bossID = bossID;
	end
end
local function UpdateConditionsForAffixes()
	local affixesID;
	local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo();
	if difficultyID == 23 then -- In a mythic dungeon (not M+)
		local affixes = C_MythicPlus.GetCurrentAffixes();
		if affixes then
			affixesID = GetAffixesInfo(affixes[1].id, affixes[2].id, affixes[3].id, affixes[4].id).id;
		end
	end

	if previousConditionInfo.affixesID ~= affixesID then
		DeactivateConditionMap(conditionMap.affixesID, previousConditionInfo.affixesID);
		ActivateConditionMap(conditionMap.affixesID, affixesID);
		previousConditionInfo.affixesID = affixesID;
	end
end
local function CompareConditions(a,b)
	for k,v in pairs(a) do
		if b[k] ~= v then
			return false;
		end
	end
	for k,v in pairs(b) do
		if a[k] ~= v then
			return false;
		end
	end
	return true;
end
-- Loops through conditions and checks if they are active
local conditionMatchCount = {};
local function TriggerConditions()
	-- In a Mythic Plus cant cant change anything anyway
	if select(8,GetInstanceInfo()) == 8 then
		return;
	end
	
	-- Generally speaking people wont want a popup asking to switch stuff if they are editing things
	if BtWLoadoutsFrame:IsShown() or target.active then
		return;
	end

	previousActiveConditions,activeConditions = activeConditions,previousActiveConditions;
	wipe(activeConditions);
	wipe(conditionMatchCount);
	for setID,set in pairs(BtWLoadoutsSets.conditions) do
		if type(set) == "table" and set.profileSet ~= nil then
			local profile = GetProfile(set.profileSet);
			if select(5, IsProfileValid(profile)) then
				local match = IsConditionActive(set);
				if match then
					activeConditions[profile] = set;
					conditionMatchCount[profile] = (conditionMatchCount[profile] or 0) + match;
				end
			end
		end
	end

	if CompareConditions(previousActiveConditions, activeConditions) then
		return
	end

	wipe(sortedActiveConditions);
	for profile,condition in pairs(activeConditions) do
		sortedActiveConditions[#sortedActiveConditions+1] = {
			profile = profile,
			condition = condition,
			match = conditionMatchCount[profile],
		};
	end

	if #sortedActiveConditions == 0 then
		return;
	elseif #sortedActiveConditions == 1 then
		if not IsProfileActive(sortedActiveConditions[1].profile) then
			StaticPopup_Hide("BTWLOADOUTS_REQUESTMULTIACTIVATE");
			StaticPopup_Show("BTWLOADOUTS_REQUESTACTIVATE", sortedActiveConditions[1].condition.name, nil, {
				set = sortedActiveConditions[1].profile,
				func = ActivateProfile,
			});
		end
	else
		sort(sortedActiveConditions, function(a,b)
			return a.match > b.match;
		end);

		activeConditionSelection = sortedActiveConditions[1];
		UIDropDownMenu_SetText(conditionProfilesDropDown, activeConditionSelection.condition.name);
		StaticPopup_Hide("BTWLOADOUTS_REQUESTACTIVATE");
		StaticPopup_Show("BTWLOADOUTS_REQUESTMULTIACTIVATE", nil, nil, {
			func = ActivateProfile,
		}, conditionProfilesDropDown);
	end
end

local NUM_TABS = 6;
local TAB_PROFILES = 1;
local TAB_TALENTS = 2;
local TAB_PVP_TALENTS = 3;
local TAB_ESSENCES = 4;
local TAB_EQUIPMENT = 5;
local TAB_CONDITIONS = 6;
local function GetTabFrame(self, tabID)
	return self.TabFrames[tabID];
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
        for _,role in ipairs(roles) do
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
			info.text = NONE;
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
		for _,role in ipairs(roles) do
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
				local characterInfo = GetCharacterInfo(character);
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

		for _,affixes in ipairs(affixRotation) do
			info.text = affixes.fullName;
			info.arg1 = affixes.id;
			info.func = AffixesDropDown_OnClick;
			info.checked = selected == affixes.id;
			UIDropDownMenu_AddButton(info, level);
		end
	end
end


local NUM_SCROLL_ITEMS_TO_DISPLAY = 18;
local SCROLL_ROW_HEIGHT = 21;
local setScrollItems = {};
local profilesCollapsedBySpecID = {};
local talentSetsCollapsedBySpecID = {};
local pvpTalentSetsCollapsedBySpecID = {};
local essenceSetsCollapsedByRole = {};
local equipmentSetsCollapsedByCharacter = {};
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
				-- local classColor = C_ClassColor.GetClassColor(characterInfo.class);
				-- name = format("%s |cFFD5D5D5(%s|cFFD5D5D5 - %s)|r", item.name, classColor:WrapTextInColorCode(characterInfo.name), characterInfo.realm);
				
				if characterInfo then
					name = format("%s |cFFD5D5D5(%s - %s)|r", item.name, characterInfo.name, characterInfo.realm);
				else
					name = format("%s |cFFD5D5D5(%s - %s)|r", item.name, item.character);
				end
				-- button.name:SetText(format("%s |cFFD5D5D5(%s)|r", item.name, item.character));
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
local function SetsScrollFrame_SpecFilter(selected, sets, collapsed)
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
local function SetsScrollFrame_RoleFilter(selected, sets, collapsed)
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
	for _,role in ipairs(roles) do
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
local function SetsScrollFrame_CharacterFilter(selected, sets, collapsed)
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
local function SetsScrollFrame_NoFilter(selected, sets)
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

local function ProfilesTabUpdate(self)
	self:GetParent().TitleText:SetText(L["Profiles"]);
	self.set = SetsScrollFrame_SpecFilter(self.set, BtWLoadoutsSets.profiles, profilesCollapsedBySpecID);

	self.Name:SetEnabled(self.set ~= nil);
	self.SpecDropDown.Button:SetEnabled(self.set ~= nil);
	self.TalentsDropDown.Button:SetEnabled(self.set ~= nil);
	self.PvPTalentsDropDown.Button:SetEnabled(self.set ~= nil);
	self.EssencesDropDown.Button:SetEnabled(self.set ~= nil);
	self.EquipmentDropDown.Button:SetEnabled(self.set ~= nil);

	if self.set ~= nil then
		local valid, class, specID, role, validForPlayer = IsProfileValid(self.set);
		if type(specID) == "number" then
			self.set.specID = specID;
		end

		specID = self.set.specID;

		if specID == nil or specID == 0 then
			UIDropDownMenu_SetText(self.SpecDropDown, NONE);
		else
			local _, specName, _, icon, _, classID = GetSpecializationInfoByID(specID);
			local className = LOCALIZED_CLASS_NAMES_MALE[classID];
			local classColor = C_ClassColor.GetClassColor(classID);
			UIDropDownMenu_SetText(self.SpecDropDown, format("%s: %s", classColor:WrapTextInColorCode(className), specName));
		end
		
		local talentSetID = self.set.talentSet;
		if talentSetID == nil then
			UIDropDownMenu_SetText(self.TalentsDropDown, NONE);
		else
			local talentSet = GetTalentSet(talentSetID);
			UIDropDownMenu_SetText(self.TalentsDropDown, talentSet.name);
		end

		local pvpTalentSetID = self.set.pvpTalentSet;
		if pvpTalentSetID == nil then
			UIDropDownMenu_SetText(self.PvPTalentsDropDown, NONE);
		else
			local pvpTalentSet = GetPvPTalentSet(pvpTalentSetID);
			UIDropDownMenu_SetText(self.PvPTalentsDropDown, pvpTalentSet.name);
		end

		local essencesSetID = self.set.essencesSet;
		if essencesSetID == nil then
			UIDropDownMenu_SetText(self.EssencesDropDown, NONE);
		else
			local essencesSet = GetEssenceSet(essencesSetID);
			UIDropDownMenu_SetText(self.EssencesDropDown, essencesSet.name);
		end

		local equipmentSetID = self.set.equipmentSet;
		if equipmentSetID == nil then
			UIDropDownMenu_SetText(self.EquipmentDropDown, NONE);
		else
			local equipmentSet = GetEquipmentSet(equipmentSetID);
			UIDropDownMenu_SetText(self.EquipmentDropDown, equipmentSet.name);
		end

		self.Name:SetText(self.set.name or "");

		local activateButton = self:GetParent().ActivateButton;
		activateButton:SetEnabled(validForPlayer);

		local deleteButton =  self:GetParent().DeleteButton;
		deleteButton:SetEnabled(true);
		
		local addButton = self:GetParent().AddButton;
		addButton.Flash:Hide();
		addButton.FlashAnim:Stop();
	
		local helpTipBox = self:GetParent().HelpTipBox;
		-- Tutorial stuff
		if not helpTipIgnored["TUTORIAL_RENAME_SET"] then
			helpTipBox.closeFlag = "TUTORIAL_RENAME_SET";

			HelpTipBox_Anchor(helpTipBox, "TOP", self.Name);
			
			helpTipBox:Show();
			HelpTipBox_SetText(helpTipBox, L["Change the name of your new profile."]);
		elseif not helpTipIgnored["TUTORIAL_CREATE_TALENT_SET"] then
			helpTipBox.closeFlag = "TUTORIAL_CREATE_TALENT_SET";

			HelpTipBox_Anchor(helpTipBox, "TOP", self.TalentsDropDown);
			
			helpTipBox:Show();
			HelpTipBox_SetText(helpTipBox, L["Create a talent set for your new profile."]);
		elseif not helpTipIgnored["TUTORIAL_ACTIVATE_SET"] then
			helpTipBox.closeFlag = "TUTORIAL_ACTIVATE_SET";

			HelpTipBox_Anchor(helpTipBox, "TOP", activateButton);
			
			helpTipBox:Show();
			HelpTipBox_SetText(helpTipBox, L["Activate your profile."]);
		else
			helpTipBox.closeFlag = nil;
			helpTipBox:Hide();
		end
	else
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
local function TalentsTabUpdate(self)
	self:GetParent().TitleText:SetText(L["Talents"]);
	self.set = SetsScrollFrame_SpecFilter(self.set, BtWLoadoutsSets.talents, talentSetsCollapsedBySpecID);

	if self.set ~= nil then
		self.Name:SetEnabled(true);
		self.SpecDropDown.Button:SetEnabled(true);
		for _,row in ipairs(self.rows) do
			row:SetShown(true);
		end

		local specID = self.set.specID;
		local selected = self.set.talents;

		self.Name:SetText(self.set.name or "");

		local _, specName, _, icon, _, classID = GetSpecializationInfoByID(specID);
		local className = LOCALIZED_CLASS_NAMES_MALE[classID];
		local classColor = C_ClassColor.GetClassColor(classID);
		UIDropDownMenu_SetText(self.SpecDropDown, format("%s: %s", classColor:WrapTextInColorCode(className), specName));

		if self.set.inUse then
			UIDropDownMenu_DisableDropDown(self.SpecDropDown);
		else
			UIDropDownMenu_EnableDropDown(self.SpecDropDown);
		end

		for tier=1,MAX_TALENT_TIERS do
			for column=1,3 do
				local item = self.rows[tier].talents[column];
				local talentID, name, texture, _, _, spellID = GetTalentInfoForSpecID(specID, tier, column);

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
		for _,row in ipairs(self.rows) do
			row:SetShown(false);
		end

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
local MAX_PVP_TALENTS = 15;
local function PvPTalentsTabUpdate(self)
	self:GetParent().TitleText:SetText(L["PvP Talents"]);
	self.set = SetsScrollFrame_SpecFilter(self.set, BtWLoadoutsSets.pvptalents, pvpTalentSetsCollapsedBySpecID);

	if self.set ~= nil then
		self.Name:SetEnabled(true);
		self.SpecDropDown.Button:SetEnabled(true);
		self.trinkets:SetShown(true);
		self.others:SetShown(true);

		local specID = self.set.specID;
		local selected = self.set.talents;

		self.Name:SetText(self.set.name or "");

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
	self.set = SetsScrollFrame_RoleFilter(self.set, BtWLoadoutsSets.essences, essenceSetsCollapsedByRole);

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

		self.Name:SetText(self.set.name or "");

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
	self.set = SetsScrollFrame_CharacterFilter(self.set, BtWLoadoutsSets.equipment, equipmentSetsCollapsedByCharacter);

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
		
		self.Name:SetText(set.name or "");
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
		self.Name:SetText(set.name or "");

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

BtWLoadoutsFrameMixin = {};
function BtWLoadoutsFrameMixin:OnLoad()
    tinsert(UISpecialFrames, self:GetName());
    self:RegisterForDrag("LeftButton");
    
    -- self.Profiles.set = {};
    
    self.Talents.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
    -- self.Talents.set = {talents = {}};

    self.PvPTalents.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
    -- self.PvPTalents.set = {talents = {}};

    self.Essences.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
	-- self.Essences.set = {essences = {}};
	self.Essences.pending = nil;

	-- self.Equipment.set = {equipment = {}, ignored = {}};

	PanelTemplates_SetNumTabs(self, NUM_TABS);
    PanelTemplates_SetTab(self, TAB_PROFILES);

	self.TitleText:SetText(PROFILES);
	self.TitleText:SetHeight(24);

	self.Profiles.SpecDropDown.includeNone = true;
    UIDropDownMenu_SetWidth(self.Profiles.SpecDropDown, 300);
    UIDropDownMenu_Initialize(self.Profiles.SpecDropDown, SpecDropDownInit);
    UIDropDownMenu_JustifyText(self.Profiles.SpecDropDown, "LEFT");

    UIDropDownMenu_SetWidth(self.Profiles.TalentsDropDown, 300);
    UIDropDownMenu_Initialize(self.Profiles.TalentsDropDown, TalentsDropDownInit);
    UIDropDownMenu_JustifyText(self.Profiles.TalentsDropDown, "LEFT");

    UIDropDownMenu_SetWidth(self.Profiles.PvPTalentsDropDown, 300);
    UIDropDownMenu_Initialize(self.Profiles.PvPTalentsDropDown, PvPTalentsDropDownInit);
    UIDropDownMenu_JustifyText(self.Profiles.PvPTalentsDropDown, "LEFT");

    UIDropDownMenu_SetWidth(self.Profiles.EssencesDropDown, 300);
    UIDropDownMenu_Initialize(self.Profiles.EssencesDropDown, EssencesDropDownInit);
    UIDropDownMenu_JustifyText(self.Profiles.EssencesDropDown, "LEFT");

    UIDropDownMenu_SetWidth(self.Profiles.EquipmentDropDown, 300);
    UIDropDownMenu_Initialize(self.Profiles.EquipmentDropDown, EquipmentDropDownInit);
    UIDropDownMenu_JustifyText(self.Profiles.EquipmentDropDown, "LEFT");
    

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
	};
	
	HybridScrollFrame_CreateButtons(self.Essences.EssenceList, "BtWLoadoutsAzeriteEssenceButtonTemplate", 4, -3, "TOPLEFT", "TOPLEFT", 0, -1, "TOP", "BOTTOM");
	self.Essences.EssenceList.update = EssenceScrollFrameUpdate;

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
    UIDropDownMenu_Initialize(self.Conditions.AffixesDropDown, AffixesDropDownInit);
	UIDropDownMenu_JustifyText(self.Conditions.AffixesDropDown, "LEFT");
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
        ProfilesTabUpdate(self.Profiles);
    elseif selectedTab == TAB_TALENTS then
        TalentsTabUpdate(self.Talents);
    elseif selectedTab == TAB_PVP_TALENTS then
        PvPTalentsTabUpdate(self.PvPTalents);
    elseif selectedTab == TAB_ESSENCES then
        EssencesTabUpdate(self.Essences);
    elseif selectedTab == TAB_EQUIPMENT then
		EquipmentTabUpdate(self.Equipment);
	elseif selectedTab == TAB_CONDITIONS then
		ConditionsTabUpdate(self.Conditions);
    end
end
function BtWLoadoutsFrameMixin:ScrollItemClick(button)
    CloseDropDownMenus();
    local selectedTab = PanelTemplates_GetSelectedTab(self) or 1;
    if selectedTab == TAB_PROFILES then
        local frame = self.Profiles;
		if button.isAdd then
			helpTipIgnored["TUTORIAL_NEW_SET"] = true;

            self:SetProfile(AddProfile());
            C_Timer.After(0, function ()
                frame.Name:HighlightText();
                frame.Name:SetFocus();
            end)
		elseif button.isDelete then
			local set = frame.set;
			if set.useCount > 0 then
				StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
					set = set,
					func = DeleteProfile,
				});
			else
				StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
					set = set,
					func = DeleteProfile,
				});
			end
        elseif button.isActivate then
			helpTipIgnored["TUTORIAL_ACTIVATE_SET"] = true;

			local set = frame.set;
			ActivateProfile(set);

			ProfilesTabUpdate(frame);
        elseif button.isHeader then
            profilesCollapsedBySpecID[button.id] = not profilesCollapsedBySpecID[button.id] and true or nil;
            ProfilesTabUpdate(frame);
        else
			if IsModifiedClick("SHIFT") then
				ActivateProfile(GetProfile(button.id));
			else
				self:SetProfile(GetProfile(button.id));
				frame.Name:ClearFocus();
			end
        end
    elseif selectedTab == TAB_TALENTS then
        local frame = self.Talents;
        if button.isAdd then
            self:SetTalentSet(AddTalentSet());
            C_Timer.After(0, function ()
                frame.Name:HighlightText();
                frame.Name:SetFocus();
            end)
		elseif button.isDelete then
			local set = frame.set;
			if set.useCount > 0 then
				StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
					set = set,
					func = DeleteTalentSet,
				});
			else
				StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
					set = set,
					func = DeleteTalentSet,
				});
			end
        elseif button.isActivate then
			local set = frame.set;
			if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
				ActivateProfile({
					talentSet = set.setID;
				});
			end
        elseif button.isHeader then
            talentSetsCollapsedBySpecID[button.id] = not talentSetsCollapsedBySpecID[button.id] and true or nil;
            TalentsTabUpdate(frame);
        else
			if IsModifiedClick("SHIFT") then
				local set = GetTalentSet(button.id);
				if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
					ActivateProfile({
						talentSet = button.id;
					});
				end
			else 
				self:SetTalentSet(GetTalentSet(button.id));
				frame.Name:ClearFocus();
			end
        end
    elseif selectedTab == TAB_PVP_TALENTS then
        local frame = self.PvPTalents;
        if button.isAdd then
            self:SetPvPTalentSet(AddPvPTalentSet());
            C_Timer.After(0, function ()
                frame.Name:HighlightText();
                frame.Name:SetFocus();
            end)
		elseif button.isDelete then
			local set = frame.set;
			if set.useCount > 0 then
				StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
					set = set,
					func = DeletePvPTalentSet,
				});
			else
				StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
					set = set,
					func = DeletePvPTalentSet,
				});
			end
        elseif button.isActivate then
			local set = frame.set;
			if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
				ActivateProfile({
					pvpTalentSet = set.setID;
				});
			end
        elseif button.isHeader then
            pvpTalentSetsCollapsedBySpecID[button.id] = not pvpTalentSetsCollapsedBySpecID[button.id] and true or nil;
            PvPTalentsTabUpdate(self.PvPTalents);
        else
			if IsModifiedClick("SHIFT") then
				local set = GetPvPTalentSet(button.id);
				if select(6, GetSpecializationInfoByID(set.specID)) == select(2, UnitClass("player")) then
					ActivateProfile({
						pvpTalentSet = button.id;
					});
				end
			else 
				self:SetPvPTalentSet(GetPvPTalentSet(button.id));
				frame.Name:ClearFocus();
			end
        end
    elseif selectedTab == TAB_ESSENCES then
        local frame = self.Essences;
        if button.isAdd then
            self:SetEssenceSet(AddEssenceSet());
            C_Timer.After(0, function ()
                frame.Name:HighlightText();
                frame.Name:SetFocus();
            end)
		elseif button.isDelete then
			local set = frame.set;
			if set.useCount > 0 then
				StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
					set = set,
					func = DeleteEssenceSet,
				});
			else
				StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
					set = set,
					func = DeleteEssenceSet,
				});
			end
        elseif button.isActivate then
			ActivateProfile({
				essencesSet = frame.set.setID;
			});
        elseif button.isHeader then
            essenceSetsCollapsedByRole[button.id] = not essenceSetsCollapsedByRole[button.id] and true or nil;
            EssencesTabUpdate(frame);
		else
			if IsModifiedClick("SHIFT") then
				ActivateProfile({
					essencesSet = button.id;
				});
			else 
				self:SetEssenceSet(GetEssenceSet(button.id));
				frame.Name:ClearFocus();
			end
        end
    elseif selectedTab == TAB_EQUIPMENT then
        local frame = self.Equipment;
        if button.isAdd then
            self:SetEquipmentSet(AddEquipmentSet());
            C_Timer.After(0, function ()
                frame.Name:HighlightText();
                frame.Name:SetFocus();
            end);
		elseif button.isDelete then
			local set = frame.set;
			if set.useCount > 0 then
				StaticPopup_Show("BTWLOADOUTS_DELETEINUSESET", set.name, nil, {
					set = set,
					func = DeleteEquipmentSet,
				});
			else
				StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
					set = set,
					func = DeleteEquipmentSet,
				});
			end
        elseif button.isActivate then
			ActivateProfile({
				equipmentSet = frame.set.setID;
			});
        elseif button.isHeader then
            equipmentSetsCollapsedByCharacter[button.id] = not equipmentSetsCollapsedByCharacter[button.id] and true or nil;
            EquipmentTabUpdate(frame);
        else
			if IsModifiedClick("SHIFT") then
				ActivateProfile({
					equipmentSet = button.id;
				});
			else 
				self:SetEquipmentSet(GetEquipmentSet(button.id));
				frame.Name:ClearFocus();
			end
        end
    elseif selectedTab == TAB_CONDITIONS then
        local frame = self.Conditions;
        if button.isAdd then
            self:SetConditionSet(AddConditionSet());
            C_Timer.After(0, function ()
                frame.Name:HighlightText();
                frame.Name:SetFocus();
            end);
		elseif button.isDelete then
			local set = frame.set;
			StaticPopup_Show("BTWLOADOUTS_DELETESET", set.name, nil, {
				set = set,
				func = DeleteConditionSet,
			});
        else
			self:SetConditionSet(GetConditionSet(button.id));
			frame.Name:ClearFocus();
        end
    end
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
	local tab = GetTabFrame(BtWLoadoutsFrame, selectedTab);
	if tab.set and tab.set.name ~= text then
		tab.set.name = text;
		helpTipIgnored["TUTORIAL_RENAME_SET"] = true;
		self:Update();
	end
end
function BtWLoadoutsFrameMixin:OnShow()
	helpTipIgnored["MINIMAP_ICON"] = true;
	StaticPopup_Hide("BTWLOADOUTS_REQUESTACTIVATE");
	StaticPopup_Hide("BTWLOADOUTS_REQUESTMULTIACTIVATE");
end
function BtWLoadoutsFrameMixin:OnHide()
	-- When hiding the main window we are going to assume that something has dramatically changed and completely redo everything
	wipe(previousConditionInfo);
	wipe(activeConditions);
	UpdateConditionsForInstance();
	UpdateConditionsForBoss();
	UpdateConditionsForAffixes();
    TriggerConditions();
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
	local GetMinimapShape = GetMinimapShape;
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
		self:RegisterEvent("ADDON_LOADED");
	end
	function BtWLoadoutsMinimapMixin:OnEvent(event, ...)
		if ... == "BtWLoadouts" then
			self:SetShown(Settings.minimapShown);
			self:Reposition(Settings.minimapAngle or 195);
		end
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
		local radius = 80;
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

		local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND";
		local quadTable = minimapShapes[minimapShape];
		if quadTable[q] then
			x = cos*radius;
			y = sin*radius;
		else
			local diagRadius = sqrt(2*(radius)^2)-rounding;
			x = max(-radius, min(cos*diagRadius, radius));
			y = max(-radius, min(sin*diagRadius, radius));
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
	function BtWLoadoutsMinimapMenu_Init(self, level)
		local info = UIDropDownMenu_CreateInfo();
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

local function PlayerNeedsTomeNowForSet(set)
    return;

    -- local specIndex = GetSpecialization()
    -- if specIndex ~= set.specIndex then
    --     return false;
    -- end

    -- return PlayerNeedsTome();
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
SlashCmdList["BTWLOADOUTS"] = function(msg)
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

do
	local frame = CreateFrame("Frame");
	frame:SetScript("OnEvent", function (self, event, ...)
		self[event](self, ...);
	end);
	function frame:ADDON_LOADED(...)
		if ... == ADDON_NAME then
			BtWLoadoutsSettings = BtWLoadoutsSettings or {};
			Settings(BtWLoadoutsSettings);
			
			BtWLoadoutsSets = BtWLoadoutsSets or {
				profiles = {},
				talents = {},
				pvptalents = {},
				essences = {},
				equipment = {},
				conditions = {},
			};
			
			for _,sets in pairs(BtWLoadoutsSets) do
				for setID,set in pairs(sets) do
					if type(set) == "table" then
						set.setID = setID;
						set.useCount = 0;
					end
				end
			end
			for setID,set in pairs(BtWLoadoutsSets.equipment) do
				if type(set) == "table" then
					set.extras = set.extras or {};
					set.locations = set.locations or {};
				end
			end
			for setID,set in pairs(BtWLoadoutsSets.profiles) do
				if type(set) == "table" then
					if set.talentSet then
						BtWLoadoutsSets.talents[set.talentSet].useCount = BtWLoadoutsSets.talents[set.talentSet].useCount + 1;
					end

					if set.pvpTalentSet then
						BtWLoadoutsSets.pvptalents[set.pvpTalentSet].useCount = BtWLoadoutsSets.pvptalents[set.pvpTalentSet].useCount + 1;
					end

					if set.essencesSet then
						BtWLoadoutsSets.essences[set.essencesSet].useCount = BtWLoadoutsSets.essences[set.essencesSet].useCount + 1;
					end

					if set.equipmentSet then
						BtWLoadoutsSets.equipment[set.equipmentSet].useCount = BtWLoadoutsSets.equipment[set.equipmentSet].useCount + 1;
					end
				end
			end

			BtWLoadoutsSpecInfo = BtWLoadoutsSpecInfo or {};
			BtWLoadoutsRoleInfo = BtWLoadoutsRoleInfo or {};
			BtWLoadoutsEssenceInfo = BtWLoadoutsEssenceInfo or {};
			BtWLoadoutsCharacterInfo = BtWLoadoutsCharacterInfo or {};

			for classIndex=1,GetNumClasses() do
				local className, classFile, classID = GetClassInfo(classIndex);
				classInfo[classFile] = {};
				for specIndex=1,GetNumSpecializationsForClassID(classID) do
					local role = select(5, GetSpecializationInfoForClassID(classID, specIndex));
					classInfo[classFile][role] = true;
				end
			end

			do
				local name, realm = UnitName("player"), GetRealmName();
				local character = format("%s-%s", realm, name);
				for setID,set in pairs(BtWLoadoutsSets.equipment) do
					if type(set) == "table" and set.character == character and set.managerID ~= nil then
						equipmentSetMap[set.managerID] = set;
					end
				end
			end

			BtWLoadoutsHelpTipFlags = BtWLoadoutsHelpTipFlags or {};
			for k in pairs(helpTipIgnored) do
				BtWLoadoutsHelpTipFlags[k] = true;
			end
			helpTipIgnored = BtWLoadoutsHelpTipFlags;

			for _,set in pairs(BtWLoadoutsSets.conditions) do
				if type(set) == "table" then
					if set.map.difficultyID ~= 8 then
						set.map.affixesID = nil;
					end

					AddConditionToMap(set);
				end
			end

			if not helpTipIgnored["MINIMAP_ICON"] then
				BtWLoadoutsMinimapButton.PulseAlpha:Play();
			end
		end
	end
	function frame:PLAYER_LOGIN(...)
		self:EQUIPMENT_SETS_CHANGED();
	end
	function frame:PLAYER_ENTERING_WORLD()
		for specIndex=1,GetNumSpecializations() do
			local specID = GetSpecializationInfo(specIndex);
			local spec = BtWLoadoutsSpecInfo[specID] or {talents = {}};
			spec.talents = spec.talents or {};
			local talents = spec.talents;
			for tier=1,MAX_TALENT_TIERS do
				local tierItems = talents[tier] or {};

				for column=1,3 do
					local talentID = GetTalentInfoBySpecialization(specIndex, tier, column);
					tierItems[column] = talentID;
				end

				talents[tier] = tierItems;
			end

			BtWLoadoutsSpecInfo[specID] = spec;
		end
		
		do
			local specID = GetSpecializationInfo(GetSpecialization());
			local spec = BtWLoadoutsSpecInfo[specID] or {};
			spec.pvptalenttrinkets = spec.pvptalenttrinkets or {};
			wipe(spec.pvptalenttrinkets);
			local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(1);
			if slotInfo then
				local availableTalentIDs = slotInfo.availableTalentIDs;
				for index,talentID in ipairs(availableTalentIDs) do
					spec.pvptalenttrinkets[index] = talentID;
				end
			end
				
			spec.pvptalents = spec.pvptalents or {};
			wipe(spec.pvptalents);
			local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(2);
			if slotInfo then
				local availableTalentIDs = slotInfo.availableTalentIDs;
				for index,talentID in ipairs(availableTalentIDs) do
					spec.pvptalents[index] = talentID;
				end
			end

			BtWLoadoutsSpecInfo[specID] = spec;
		end

		do
			local roleID = select(5, GetSpecializationInfo(GetSpecialization()));
			local role = BtWLoadoutsRoleInfo[roleID] or {};
			
			role.essences = role.essences or {};
			wipe(role.essences);
			local essences = C_AzeriteEssence.GetEssences();
			sort(essences, function (a,b)
				return a.name < b.name;
			end);
			for _,essence in ipairs(essences) do
				if essence.valid then
					role.essences[#role.essences+1] = essence.ID;
				end

				local essenceInfo = BtWLoadoutsEssenceInfo[essence.ID] or {};
				wipe(essenceInfo);
				essenceInfo.ID = essence.ID;
				essenceInfo.name = essence.name;
				essenceInfo.icon = essence.icon;

				BtWLoadoutsEssenceInfo[essence.ID] = essenceInfo;
			end

			BtWLoadoutsRoleInfo[roleID] = role;
		end

		do
			local name, realm = UnitFullName("player");
			local class = select(2, UnitClass("player"));
			local race = select(3, UnitRace("player"));
			local sex = UnitSex("player") - 2;

			BtWLoadoutsCharacterInfo[realm .. "-" .. name] = {name = name, realm = realm, class = class, race = race, sex = sex};
		end

		UpdateAreaMap();

		-- Run conditions for instance info
		do
			UpdateConditionsForInstance();
			UpdateConditionsForBoss();
			UpdateConditionsForAffixes();
			TriggerConditions();
		end
	end
	function frame:EQUIPMENT_SETS_CHANGED(...)
		-- Update our saved equipment sets to match the built in equipment sets
		local oldEquipmentSetMap = equipmentSetMap;
		equipmentSetMap = {};

		local managerIDs = C_EquipmentSet.GetEquipmentSetIDs();
		for _,managerID in ipairs(managerIDs) do
			local set = oldEquipmentSetMap[managerID];
			if set == nil then
				set = AddBlankEquipmentSet();
			end

			set.managerID = managerID;
			set.name = C_EquipmentSet.GetEquipmentSetInfo(managerID);

			local ignored = C_EquipmentSet.GetIgnoredSlots(managerID);
			local locations = C_EquipmentSet.GetItemLocations(managerID);
			for inventorySlotId=INVSLOT_FIRST_EQUIPPED,INVSLOT_LAST_EQUIPPED do
				set.ignored[inventorySlotId] = ignored[inventorySlotId] and true or nil;

				local location = locations[inventorySlotId] or 0;
				if location > -1 then -- If location is -1 we ignore it as we cant get the item link for the item
					set.equipment[inventorySlotId] = GetItemLinkByLocation(location);
				end
			end

			equipmentSetMap[managerID] = set;
			oldEquipmentSetMap[managerID] = nil;
		end

		for managerID,set in pairs(oldEquipmentSetMap) do
			if set.managerID == managerID then
				set.managerID = nil;
			end
		end

		BtWLoadoutsFrame:Update();
	end
	function frame:PLAYER_SPECIALIZATION_CHANGED(...)
		do
			local specID = GetSpecializationInfo(GetSpecialization());
			local spec = BtWLoadoutsSpecInfo[specID] or {};

			spec.pvptalenttrinkets = spec.pvptalenttrinkets or {};
			wipe(spec.pvptalenttrinkets);
			local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(1);
			if slotInfo then
				local availableTalentIDs = slotInfo.availableTalentIDs;
				for index,talentID in ipairs(availableTalentIDs) do
					spec.pvptalenttrinkets[index] = talentID;
				end
			end
				
			spec.pvptalents = spec.pvptalents or {};
			wipe(spec.pvptalents);
			local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(2);
			if slotInfo then
				local availableTalentIDs = slotInfo.availableTalentIDs;
				for index,talentID in ipairs(availableTalentIDs) do
					spec.pvptalents[index] = talentID;
				end
			end

			BtWLoadoutsSpecInfo[specID] = spec;
		end
	end
	function frame:ZONE_CHANGED(...)
		UpdateConditionsForBoss();
		TriggerConditions();
	end
	function frame:UPDATE_MOUSEOVER_UNIT(...)
		UpdateConditionsForBoss("mouseover");
		TriggerConditions();
	end
	function frame:NAME_PLATE_UNIT_ADDED(...)
		UpdateConditionsForBoss(...);
		TriggerConditions();
	end
	function frame:PLAYER_TARGET_CHANGED(...)
		UpdateConditionsForBoss("player");
		TriggerConditions();
	end
	frame:RegisterEvent("ADDON_LOADED");
	frame:RegisterEvent("PLAYER_LOGIN");
	frame:RegisterEvent("PLAYER_ENTERING_WORLD");
	frame:RegisterEvent("EQUIPMENT_SETS_CHANGED");
	frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
	frame:RegisterEvent("ZONE_CHANGED");
	frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
	frame:RegisterEvent("NAME_PLATE_UNIT_ADDED");
	frame:RegisterEvent("PLAYER_TARGET_CHANGED");
end

eventHandler:SetScript("OnEvent", function (self, event, ...)
    self[event](self, ...);
end);
function eventHandler:GET_ITEM_INFO_RECEIVED()
    target.dirty = true;
end
function eventHandler:PLAYER_REGEN_DISABLED()
    StaticPopup_Hide("BTWLOADOUTS_NEEDTOME");
end
function eventHandler:PLAYER_REGEN_ENABLED()
    target.dirty = true;
end
function eventHandler:PLAYER_UPDATE_RESTING()
	target.dirty = true;
    -- if AreTalentsLocked() then
    --     StaticPopup_Hide("BTWLOADOUTS_REQUESTACTIVATETOME");
    --     StaticPopup_Hide("BTWLOADOUTS_REQUESTACTIVATE");
    --     return;
    -- end

    -- local _, eventHandler = StaticPopup_Visible("BTWLOADOUTS_REQUESTACTIVATETOME");
    -- if eventHandler then
    --     if not PlayerNeedsTomeNowForSet(eventHandler.data) then
    --         StaticPopup_Hide("BTWLOADOUTS_REQUESTACTIVATETOME");
    --         StaticPopup_Show("BTWLOADOUTS_REQUESTACTIVATE");
    --     end

    --     return;
    -- end

    -- local _, eventHandler = StaticPopup_Visible("BTWLOADOUTS_REQUESTACTIVATE");
    -- if eventHandler then
    --     if PlayerNeedsTomeNowForSet(eventHandler.data) then
    --         StaticPopup_Hide("BTWLOADOUTS_REQUESTACTIVATE");
    --         StaticPopup_Show("BTWLOADOUTS_REQUESTACTIVATETOME");
    --     end

    --     return;
    -- end

    -- local _, eventHandler = StaticPopup_Visible("BTWLOADOUTS_NEEDTOME");
    -- if eventHandler then
    --     if not PlayerNeedsTomeNowForSet(eventHandler.data) then
    --         target.dirty = true;
    --     end

    --     return;
    -- end
end
function eventHandler:UNIT_AURA()
	C_Timer.After(1, function()
		target.dirty = true;
	end);
end
function eventHandler:PLAYER_SPECIALIZATION_CHANGED(...)
	-- Added delay just to be safe
	C_Timer.After(1, function()
		target.dirty = true;
	end);
end
function eventHandler:ACTIVE_TALENT_GROUP_CHANGED(...)
end
function eventHandler:ZONE_CHANGED(...)
	target.dirty = true;
end
eventHandler.ZONE_CHANGED_INDOORS = eventHandler.ZONE_CHANGED;
function eventHandler:ITEM_UNLOCKED(...)
	target.dirty = true;
end
function eventHandler:UNIT_SPELLCAST_STOP(...)
	if IsChangingSpec() then
		CancelActivateProfile();
	end
end
function eventHandler:UNIT_SPELLCAST_FAILED(...)
	if IsChangingSpec() then
		CancelActivateProfile();
	end
end
function eventHandler:UNIT_SPELLCAST_FAILED_QUIET(...)
	if IsChangingSpec() then
		CancelActivateProfile();
	end
end
function eventHandler:UNIT_SPELLCAST_INTERRUPTED(...)
	if IsChangingSpec() then
		CancelActivateProfile();
	end
end

eventHandler:SetScript("OnUpdate", function (self)
    if target.dirty then
		ContinueActivateProfile();
    end
end)