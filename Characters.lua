--[[
    Character data handling
]]

local _, Internal = ...;

local UnitSex = UnitSex
local UnitRace = UnitRace
local UnitClass = UnitClass
local UnitFullName = UnitFullName
local GetRealmName = GetRealmName
local GetClassInfo = GetClassInfo
local GetNumClasses = GetNumClasses
local GetTalentInfoByID = GetTalentInfoByID
local GetSpecialization = GetSpecialization
local GetPvpTalentSlotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo;
local GetNumSpecializations = GetNumSpecializations
local GetSpecializationInfo = GetSpecializationInfo
local GetTalentInfoBySpecialization = GetTalentInfoBySpecialization
local GetNumSpecializationsForClassID = GetNumSpecializationsForClassID
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID
local GetEssenceInfo = C_AzeriteEssence.GetEssenceInfo;

local roles = {"TANK", "HEALER", "DAMAGER"};
local roleIndexes = {["TANK"] = 1, ["HEALER"] = 2, ["DAMAGER"] = 3};
local classInfo = {};
function Internal.Roles()
    return ipairs(roles)
end
function Internal.IsClassRoleValid(classFile, role)
	return classInfo[classFile][role] and true or false;
end
function Internal.UpdateClassInfo()
    for classIndex=1,GetNumClasses() do
        local className, classFile, classID = GetClassInfo(classIndex);
        classInfo[classFile] = {};
        for specIndex=1,GetNumSpecializationsForClassID(classID) do
            local role = select(5, GetSpecializationInfoForClassID(classID, specIndex));
            classInfo[classFile][role] = true;
        end
    end
end

-- In very niche situations UnitFullName will not correctly respond with the realm
-- but since player realm cant change while logged in we can just reuse the previous value
local playerNameCache, playerRealmCache
function Internal.GetCharacterSlug()
	local name, realm = UnitFullName("player");

	playerNameCache = name or playerNameCache
	playerRealmCache = realm or playerRealmCache

	return playerRealmCache .. "-" .. playerNameCache
end

local GetSpecInfoVersion;
local VerifyTalentForSpec;
local VerifyPvPTalentForSpec;
local GetTalentInfoForSpecID;
local GetPvpTalentSlotInfoForSpecID;
do
	local specInfo = {
		-- Warrior
		[71] = { -- Arms
			talents = {
				{22624, 22360, 22371},
				{19676, 22372, 22789},
				{22380, 22489, 19138},
				{15757, 22627, 22628},
				{22392, 22391, 22362},
				{22394, 22397, 22399},
				{21204, 22407, 21667},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  28,   29,   31,
						  32,   33,   34,
						3522, 3534, 5372,
						5376,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  28,   29,   31,
						  32,   33,   34,
						3522, 3534, 5372,
						5376,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  28,   29,   31,
						  32,   33,   34,
						3522, 3534, 5372,
						5376,
					}
				},
			},
		},
		[72] = { -- Fury
			talents = {
				{22632, 22633, 22491},
				{19676, 22625, 23093},
				{22379, 22381, 23372},
				{23097, 22627, 22382},
				{22383, 22393, 19140},
				{22396, 22398, 22400},
				{22405, 22402, 16037},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  25,  166,  170,
						 172,  177,  179,
						3528, 3533, 3735,
						5373, 5431,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  25,  166,  170,
						 172,  177,  179,
						3528, 3533, 3735,
						5373, 5431,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  25,  166,  170,
						 172,  177,  179,
						3528, 3533, 3735,
						5373, 5431,
					}
				},
			},
		},
		[73] = { -- Protection
			talents = {
				{15760, 15759, 15774},
				{19676, 22629, 22409},
				{22378, 22626, 23260},
				{23096, 22627, 22488},
				{22384, 22631, 22800},
				{22395, 22544, 22401},
				{23455, 22406, 23099},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  24,  167,  168,
						 171,  173,  175,
						 178,  831,  833,
						 845, 5374, 5432,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  24,  167,  168,
						 171,  173,  175,
						 178,  831,  833,
						 845, 5374, 5432,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  24,  167,  168,
						 171,  173,  175,
						 178,  831,  833,
						 845, 5374, 5432,
					}
				},
			},
		},
		-- Paladin
		[65] = { -- Holy
			talents = {
				{17565, 17567, 17569},
				{22176, 17575, 17577},
				{22179, 22180, 21811},
				{22433, 22434, 17593},
				{17597, 17599, 17601},
				{23191, 22190, 22484},
				{21201, 21671, 21203},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  82,   85,   86,
						  87,   88,  640,
						 642,  689,  859,
						3618, 5421,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  82,   85,   86,
						  87,   88,  640,
						 642,  689,  859,
						3618, 5421,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  82,   85,   86,
						  87,   88,  640,
						 642,  689,  859,
						3618, 5421,
					}
				},
			},
		},
		[66] = { -- Protection
			talents = {
				{22428, 22558, 23469},
				{22431, 22604, 23468},
				{22179, 22180, 21811},
				{22433, 22434, 22435},
				{17597, 17599, 17601},
				{22189, 22438, 23087},
				{23457, 21202, 22645},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  90,   91,   92,
						  93,   94,   97,
						 844,  860,  861,
						3474, 3475,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  90,   91,   92,
						  93,   94,   97,
						 844,  860,  861,
						3474, 3475,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  90,   91,   92,
						  93,   94,   97,
						 844,  860,  861,
						3474, 3475,
					}
				},
			},
		},
		[70] = { -- Retribution
			talents = {
				{22590, 22557, 23467},
				{22319, 22592, 23466},
				{22179, 22180, 21811},
				{22433, 22434, 22183},
				{17597, 17599, 17601},
				{23167, 22483, 23086},
				{23456, 22215, 22634},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  81,  641,  751,
						 752,  753,  754,
						 755,  756,  757,
						 858, 5422,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  81,  641,  751,
						 752,  753,  754,
						 755,  756,  757,
						 858, 5422,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  81,  641,  751,
						 752,  753,  754,
						 755,  756,  757,
						 858, 5422,
					}
				},
			},
		},
		-- Hunter
		[253] = { -- Beast Mastery
			talents = {
				{22291, 22280, 22282},
				{22500, 22266, 22290},
				{19347, 19348, 23100},
				{22441, 22347, 22269},
				{22268, 22276, 22499},
				{19357, 22002, 23044},
				{22273, 21986, 22295},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 693,  824,  825,
						1214, 3599, 3600,
						3604, 3605, 3612,
						3730, 5418, 5441,
						5444,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 693,  824,  825,
						1214, 3599, 3600,
						3604, 3605, 3612,
						3730, 5418, 5441,
						5444,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 693,  824,  825,
						1214, 3599, 3600,
						3604, 3605, 3612,
						3730, 5418, 5441,
						5444,
					}
				},
			},
		},
		[254] = { -- Marksmanship
			talents = {
				{22279, 22501, 22289},
				{22495, 22497, 22498},
				{19347, 19348, 23100},
				{22267, 22286, 21998},
				{22268, 22276, 23463},
				{23063, 23104, 22287},
				{22274, 22308, 22288},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 649,  651,  653,
						 656,  657,  658,
						 659,  660, 3614,
						3729, 5419, 5440,
						5442,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 649,  651,  653,
						 656,  657,  658,
						 659,  660, 3614,
						3729, 5419, 5440,
						5442,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 649,  651,  653,
						 656,  657,  658,
						 659,  660, 3614,
						3729, 5419, 5440,
						5442,
					}
				},
			},
		},
		[255] = { -- Survival
			talents = {
				{22275, 22283, 22296},
				{21997, 22769, 22297},
				{19347, 19348, 23100},
				{22277, 19361, 22299},
				{22268, 22276, 22499},
				{22300, 22278, 22271},
				{22272, 22301, 23105},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 661,  662,  663,
						 664,  665,  686,
						3606, 3607, 3609,
						3610, 5420, 5443,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 661,  662,  663,
						 664,  665,  686,
						3606, 3607, 3609,
						3610, 5420, 5443,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 661,  662,  663,
						 664,  665,  686,
						3606, 3607, 3609,
						3610, 5420, 5443,
					}
				},
			},
		},
		-- Rogue
		[259] = { -- Assassination
			talents = {
				{22337, 22338, 22339},
				{22331, 22332, 23022},
				{19239, 19240, 19241},
				{22340, 22122, 22123},
				{19245, 23037, 22115},
				{22343, 23015, 22344},
				{21186, 22133, 23174},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 130,  141,  144,
						 147,  830, 3448,
						3479, 3480, 5405,
						5408,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 130,  141,  144,
						 147,  830, 3448,
						3479, 3480, 5405,
						5408,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 130,  141,  144,
						 147,  830, 3448,
						3479, 3480, 5405,
						5408,
					}
				},
			},
		},
		[260] = { -- Outlaw
			talents = {
				{22118, 22119, 22120},
				{23470, 19237, 19238},
				{19239, 19240, 19241},
				{22121, 22122, 22123},
				{23077, 22114, 22115},
				{21990, 23128, 19250},
				{22125, 23075, 23175},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 129,  135,  138,
						 139,  145,  853,
						1208, 3421, 3483,
						3619, 5412, 5413,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 129,  135,  138,
						 139,  145,  853,
						1208, 3421, 3483,
						3619, 5412, 5413,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 129,  135,  138,
						 139,  145,  853,
						1208, 3421, 3483,
						3619, 5412, 5413,
					}
				},
			},
		},
		[261] = { -- Subtlety
			talents = {
				{19233, 19234, 19235},
				{22331, 22332, 22333},
				{19239, 19240, 19241},
				{22128, 22122, 22123},
				{23078, 23036, 22115},
				{22335, 19249, 22336},
				{22132, 23183, 21188},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 136,  146,  153,
						 846,  856, 1209,
						3447, 3462, 5406,
						5409, 5411,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 136,  146,  153,
						 846,  856, 1209,
						3447, 3462, 5406,
						5409, 5411,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 136,  146,  153,
						 846,  856, 1209,
						3447, 3462, 5406,
						5409, 5411,
					}
				},
			},
		},
		-- Priest
		[256] = { -- Discipline
			talents = {
				{19752, 22313, 22329},
				{22315, 22316, 19758},
				{22440, 22094, 19755},
				{19759, 19769, 19761},
				{22330, 19765, 19766},
				{22161, 19760, 19763},
				{21183, 21184, 22976},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  98,  100,  109,
						 111,  114,  117,
						 123,  126,  855,
						1244, 5403, 5416,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  98,  100,  109,
						 111,  114,  117,
						 123,  126,  855,
						1244, 5403, 5416,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  98,  100,  109,
						 111,  114,  117,
						 123,  126,  855,
						1244, 5403, 5416,
					}
				},
			},
		},
		[257] = { -- Holy
			talents = {
				{22312, 19753, 19754},
				{22325, 22326, 19758},
				{22487, 22095, 22562},
				{21750, 21977, 19761},
				{19764, 22327, 21754},
				{19767, 19760, 19763},
				{21636, 21644, 23145},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 101,  108,  112,
						 115,  118,  124,
						 127, 1242, 1927,
						5365, 5366, 5404,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 101,  108,  112,
						 115,  118,  124,
						 127, 1242, 1927,
						5365, 5366, 5404,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 101,  108,  112,
						 115,  118,  124,
						 127, 1242, 1927,
						5365, 5366, 5404,
					}
				},
			},
		},
		[258] = { -- Shadow
			talents = {
				{22328, 22136, 22314},
				{22315, 23374, 21976},
				{23125, 23126, 23127},
				{23137, 23375, 21752},
				{22310, 22311, 21755},
				{21718, 21719, 21720},
				{21637, 21978, 21979},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 102,  106,  113,
						 128,  739,  763,
						3753, 5380, 5381,
						5446, 5447,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 102,  106,  113,
						 128,  739,  763,
						3753, 5380, 5381,
						5446, 5447,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 102,  106,  113,
						 128,  739,  763,
						3753, 5380, 5381,
						5446, 5447,
					}
				},
			},
		},
		-- Death Knight
		[250] = { -- Blood
			talents = {
				{19165, 19166, 23454},
				{19218, 19219, 19220},
				{19221, 22134, 22135},
				{22013, 22014, 22015},
				{19227, 19226, 19228},
				{19230, 19231, 19232},
				{21207, 21208, 21209},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 204,  205,  206,
						 607,  608,  609,
						 841, 3441, 3511,
						5368, 5425, 5426,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 204,  205,  206,
						 607,  608,  609,
						 841, 3441, 3511,
						5368, 5425, 5426,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 204,  205,  206,
						 607,  608,  609,
						 841, 3441, 3511,
						5368, 5425, 5426,
					}
				},
			},
		},
		[251] = { -- Frost
			talents = {
				{22016, 22017, 22018},
				{22019, 22020, 22021},
				{22515, 22517, 22519},
				{22521, 22523, 22525},
				{22527, 22530, 23373},
				{22531, 22533, 22535},
				{22023, 22109, 22537},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 701,  702,  706,
						3439, 3512, 3743,
						5369, 5424, 5427,
						5429, 5435,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 701,  702,  706,
						3439, 3512, 3743,
						5369, 5424, 5427,
						5429, 5435,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 701,  702,  706,
						3439, 3512, 3743,
						5369, 5424, 5427,
						5429, 5435,
					}
				},
			},
		},
		[252] = { -- Unholy
			talents = {
				{22024, 22025, 22026},
				{22027, 22028, 22029},
				{22516, 22518, 22520},
				{22522, 22524, 22526},
				{22528, 22529, 23373},
				{22532, 22534, 22536},
				{22030, 22110, 22538},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  40,   41,  149,
						 152, 3437, 3746,
						3747, 5367, 5423,
						5428, 5430, 5436,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  40,   41,  149,
						 152, 3437, 3746,
						3747, 5367, 5423,
						5428, 5430, 5436,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  40,   41,  149,
						 152, 3437, 3746,
						3747, 5367, 5423,
						5428, 5430, 5436,
					}
				},
			},
		},
		-- Shaman
		[262] = { -- Elemental
			talents = {
				{22356, 22357, 22358},
				{23108, 23460, 23190},
				{23162, 23163, 23164},
				{19271, 19272, 19273},
				{22144, 22172, 21966},
				{22145, 19266, 23111},
				{21198, 22153, 21675},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 727,  728,  730,
						 731, 3062, 3488,
						3490, 3491, 3620,
						3621, 5415,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 727,  728,  730,
						 731, 3062, 3488,
						3490, 3491, 3620,
						3621, 5415,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 727,  728,  730,
						 731, 3062, 3488,
						3490, 3491, 3620,
						3621, 5415,
					}
				},
			},
		},
		[263] = { -- Enhancement
			talents = {
				{22354, 22355, 22353},
				{22636, 23462, 23109},
				{23165, 19260, 23166},
				{23089, 23090, 22171},
				{22144, 22149, 21966},
				{21973, 22352, 22351},
				{21970, 22977, 21972},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 721,  722,  725,
						1944, 3487, 3489,
						3492, 3519, 3622,
						3623, 5414, 5438,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 721,  722,  725,
						1944, 3487, 3489,
						3492, 3519, 3622,
						3623, 5414, 5438,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 721,  722,  725,
						1944, 3487, 3489,
						3492, 3519, 3622,
						3623, 5414, 5438,
					}
				},
			},
		},
		[264] = { -- Restoration
			talents = {
				{19262, 19263, 19264},
				{19259, 23461, 21963},
				{19275, 23110, 22127},
				{22152, 22322, 22323},
				{22144, 19269, 21966},
				{19265, 21971, 21968},
				{21969, 21199, 22359},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 707,  708,  712,
						 713,  714,  715,
						1930, 3520, 3755,
						3756, 5388, 5437,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 707,  708,  712,
						 713,  714,  715,
						1930, 3520, 3755,
						3756, 5388, 5437,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 707,  708,  712,
						 713,  714,  715,
						1930, 3520, 3755,
						3756, 5388, 5437,
					}
				},
			},
		},
		-- Mage
		[62] = { -- Arcane
			talents = {
				{22458, 22461, 22464},
				{23072, 22443, 16025},
				{22444, 22445, 22447},
				{22453, 22467, 22470},
				{22907, 22448, 22471},
				{22455, 22449, 22474},
				{21630, 21144, 21145},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  61,   62,  635,
						 637, 3442, 3517,
						3529, 3531, 5397,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  61,   62,  635,
						 637, 3442, 3517,
						3529, 3531, 5397,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  61,   62,  635,
						 637, 3442, 3517,
						3529, 3531, 5397,
					}
				},
			},
		},
		[63] = { -- Fire
			talents = {
				{22456, 22459, 22462},
				{23071, 22443, 23074},
				{22444, 22445, 22447},
				{22450, 22465, 22468},
				{22904, 22448, 22471},
				{22451, 23362, 22472},
				{21631, 22220, 21633},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  53,  643,  644,
						 645,  646,  647,
						 648,  828, 5389,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  53,  643,  644,
						 645,  646,  647,
						 648,  828, 5389,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  53,  643,  644,
						 645,  646,  647,
						 648,  828, 5389,
					}
				},
			},
		},
		[64] = { -- Frost
			talents = {
				{22457, 22460, 22463},
				{22442, 22443, 23073},
				{22444, 22445, 22447},
				{22452, 22466, 22469},
				{22446, 22448, 22471},
				{22454, 23176, 22473},
				{21632, 22309, 21634},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  66,   67,   68,
						 632,  633,  634,
						3443, 3532, 5390,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  66,   67,   68,
						 632,  633,  634,
						3443, 3532, 5390,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  66,   67,   68,
						 632,  633,  634,
						3443, 3532, 5390,
					}
				},
			},
		},
		-- Warlock
		[265] = { -- Affliction
			talents = {
				{22039, 23140, 23141},
				{22044, 21180, 22089},
				{19280, 19285, 19286},
				{19279, 19292, 22046},
				{22047, 19291, 23465},
				{23139, 23159, 19295},
				{19284, 19281, 19293},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  11,   12,   15,
						  16,   17,   18,
						  19,   20, 3740,
						5370, 5379, 5386,
						5392,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  11,   12,   15,
						  16,   17,   18,
						  19,   20, 3740,
						5370, 5379, 5386,
						5392,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  11,   12,   15,
						  16,   17,   18,
						  19,   20, 3740,
						5370, 5379, 5386,
						5392,
					}
				},
			},
		},
		[266] = { -- Demonology
			talents = {
				{19290, 22048, 23138},
				{22045, 21694, 23158},
				{19280, 19285, 19286},
				{22477, 22042, 23160},
				{22047, 19291, 23465},
				{23147, 23146, 21717},
				{23161, 22479, 23091},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 156,  158,  162,
						 165, 1213, 3505,
						3506, 3507, 3624,
						3625, 3626, 5394,
						5400,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 156,  158,  162,
						 165, 1213, 3505,
						3506, 3507, 3624,
						3625, 3626, 5394,
						5400,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 156,  158,  162,
						 165, 1213, 3505,
						3506, 3507, 3624,
						3625, 3626, 5394,
						5400,
					}
				},
			},
		},
		[267] = { -- Destruction
			talents = {
				{22038, 22090, 22040},
				{23148, 21695, 23157},
				{19280, 19285, 19286},
				{22480, 22043, 23143},
				{22047, 19291, 23465},
				{23155, 23156, 19295},
				{19284, 23144, 23092},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 157,  159,  164,
						3502, 3504, 3508,
						3509, 3510, 3741,
						5382, 5393, 5401,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 157,  159,  164,
						3502, 3504, 3508,
						3509, 3510, 3741,
						5382, 5393, 5401,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 157,  159,  164,
						3502, 3504, 3508,
						3509, 3510, 3741,
						5382, 5393, 5401,
					}
				},
			},
		},
		-- Monk
		[268] = { -- Brewmaster
			talents = {
				{23106, 19820, 20185},
				{19304, 19818, 19302},
				{22099, 22097, 19992},
				{19993, 19994, 19995},
				{20174, 23363, 20175},
				{19819, 20184, 22103},
				{22106, 22104, 22108},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 666,  667,  668,
						 669,  670,  671,
						 672,  673,  765,
						 843, 1958, 5417,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 666,  667,  668,
						 669,  670,  671,
						 672,  673,  765,
						 843, 1958, 5417,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 666,  667,  668,
						 669,  670,  671,
						 672,  673,  765,
						 843, 1958, 5417,
					}
				},
			},
		},
		[270] = { -- Mistweaver
			talents = {
				{19823, 19820, 20185},
				{19304, 19818, 19302},
				{22168, 22167, 22166},
				{19993, 22219, 19995},
				{23371, 20173, 20175},
				{23107, 22101, 22214},
				{22218, 22169, 22170},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  70,  678,  679,
						 680,  682,  683,
						1928, 3732, 5395,
						5398, 5402,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  70,  678,  679,
						 680,  682,  683,
						1928, 3732, 5395,
						5398, 5402,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  70,  678,  679,
						 680,  682,  683,
						1928, 3732, 5395,
						5398, 5402,
					}
				},
			},
		},
		[269] = { -- Windwalker
			talents = {
				{23106, 19820, 20185},
				{19304, 19818, 19302},
				{22098, 19771, 22096},
				{19993, 23364, 19995},
				{23258, 20173, 20175},
				{22093, 23122, 22102},
				{22107, 22105, 21191},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  77,  675,  852,
						3050, 3052, 3734,
						3737, 3744, 3745,
						5448,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  77,  675,  852,
						3050, 3052, 3734,
						3737, 3744, 3745,
						5448,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  77,  675,  852,
						3050, 3052, 3734,
						3737, 3744, 3745,
						5448,
					}
				},
			},
		},
		-- Druid
		[102] = { -- Balance
			talents = {
				{22385, 22386, 22387},
				{19283, 18570, 18571},
				{22155, 22157, 22159},
				{21778, 18576, 18577},
				{18580, 21706, 21702},
				{22389, 21712, 22165},
				{21648, 21193, 21655},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 180,  182,  184,
						 185,  822,  834,
						 836, 3058, 3728,
						3731, 5383, 5407,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 180,  182,  184,
						 185,  822,  834,
						 836, 3058, 3728,
						3731, 5383, 5407,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 180,  182,  184,
						 185,  822,  834,
						 836, 3058, 3728,
						3731, 5383, 5407,
					}
				},
			},
		},
		[103] = { -- Feral
			talents = {
				{22363, 22364, 22365},
				{19283, 18570, 18571},
				{22163, 22158, 22159},
				{21778, 18576, 18577},
				{21708, 18579, 21704},
				{21714, 21711, 22370},
				{21646, 21649, 21653},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 201,  203,  601,
						 602,  611,  612,
						 620,  820, 3053,
						3751, 5384,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 201,  203,  601,
						 602,  611,  612,
						 620,  820, 3053,
						3751, 5384,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 201,  203,  601,
						 602,  611,  612,
						 620,  820, 3053,
						3751, 5384,
					}
				},
			},
		},
		[104] = { -- Guardian
			talents = {
				{22419, 22418, 22420},
				{19283, 18570, 18571},
				{22163, 22156, 22159},
				{21778, 18576, 18577},
				{21709, 21707, 22388},
				{22423, 21713, 22390},
				{22426, 22427, 22425},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  49,   50,   51,
						  52,  192,  193,
						 194,  195,  196,
						 197,  842, 1237,
						3750, 5410,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  49,   50,   51,
						  52,  192,  193,
						 194,  195,  196,
						 197,  842, 1237,
						3750, 5410,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  49,   50,   51,
						  52,  192,  193,
						 194,  195,  196,
						 197,  842, 1237,
						3750, 5410,
					}
				},
			},
		},
		[105] = { -- Restoration
			talents = {
				{18569, 18574, 18572},
				{19283, 18570, 18571},
				{22366, 22367, 22160},
				{21778, 18576, 18577},
				{21710, 21705, 22421},
				{21716, 18585, 22422},
				{22403, 21651, 22404},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						  59,  691,  692,
						 697,  700,  835,
						 838, 1215, 3048,
						3752, 5387,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						  59,  691,  692,
						 697,  700,  835,
						 838, 1215, 3048,
						3752, 5387,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						  59,  691,  692,
						 697,  700,  835,
						 838, 1215, 3048,
						3752, 5387,
					}
				},
			},
		},
		-- Demon Hunter
		[577] = { -- Havoc
			talents = {
				{21854, 22493, 22416},
				{21857, 22765, 22799},
				{22909, 22494, 21862},
				{21863, 21864, 21865},
				{21866, 21867, 21868},
				{21869, 21870, 22767},
				{21900, 21901, 22547},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 805,  806,  809,
						 810,  811,  812,
						 813, 1204, 1206,
						1218, 5433, 5445,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 805,  806,  809,
						 810,  811,  812,
						 813, 1204, 1206,
						1218, 5433, 5445,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 805,  806,  809,
						 810,  811,  812,
						 813, 1204, 1206,
						1218, 5433, 5445,
					}
				},
			},
		},
		[581] = { -- Vengeance
			talents = {
				{22502, 22503, 22504},
				{22505, 22766, 22507},
				{22324, 22541, 22540},
				{22508, 22509, 22770},
				{22546, 22510, 22511},
				{22512, 22513, 22768},
				{22543, 23464, 21902},
			},
			pvptalentslots = {
				{
					level = 20,
					availableTalentIDs = {
						 814,  815,  816,
						 819, 1220, 1948,
						3423, 3429, 3430,
						3727, 5434, 5439,
					}
				},
				{
					level = 30,
					availableTalentIDs = {
						 814,  815,  816,
						 819, 1220, 1948,
						3423, 3429, 3430,
						3727, 5434, 5439,
					}
				},
				{
					level = 40,
					availableTalentIDs = {
						 814,  815,  816,
						 819, 1220, 1948,
						3423, 3429, 3430,
						3727, 5434, 5439,
					}
				},
			},
		},
	}
	
	function GetSpecInfoVersion()
		return specInfo.version
	end
	function VerifyTalentForSpec(specID, talentID)
		if specInfo[specID] then
			for tier,talents in ipairs(specInfo[specID].talents) do
				for column,talent in ipairs(talents) do
					if talent == talentID then
						return tier, column
					end
				end
			end
		end
	end
	function VerifyPvPTalentForSpec(specID, talentID)
		if specInfo[specID] then
			for _,slot in ipairs(specInfo[specID].pvptalentslots) do
				for _,talent in ipairs(slot.availableTalentIDs) do
					if talent == talentID then
						return true
					end
				end
			end
		end
	end
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
	function GetPvpTalentSlotInfoForSpecID(specID, index)
		local playerSpecID = GetSpecializationInfo(GetSpecialization());
		if playerSpecID == specID then
			local slotInfo = GetPvpTalentSlotInfo(index);
			return slotInfo
		end

		if BtWLoadoutsSpecInfo[specID] and BtWLoadoutsSpecInfo[specID].pvptalentslots and BtWLoadoutsSpecInfo[specID].pvptalentslots[index] then
			return BtWLoadoutsSpecInfo[specID].pvptalentslots[index];
		end

		if specInfo[specID] and specInfo[specID].pvptalentslots and specInfo[specID].pvptalentslots[index] then
			return specInfo[specID].pvptalentslots[index];
		end
	end
	Internal.GetSpecInfoVersion = GetSpecInfoVersion
	Internal.VerifyTalentForSpec = VerifyTalentForSpec
	Internal.VerifyPvPTalentForSpec = VerifyPvPTalentForSpec
	Internal.GetTalentInfoForSpecID = GetTalentInfoForSpecID
	Internal.GetPvpTalentSlotInfoForSpecID = GetPvpTalentSlotInfoForSpecID
end
local GetEssenceInfoByID, GetEssenceInfoForRole;
do
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
		{
			["ID"] = 16,
			["name"] = "Unwavering Ward",
			["icon"] = 3193842,
		}, -- [16]
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
		{
			["ID"] = 24,
			["name"] = "Spirit of Preservation",
			["icon"] = 2967101,
		}, -- [24]
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
		{
			["ID"] = 33,
			["name"] = "Touch of the Everlasting",
			["icon"] = 3193847,
		}, -- [33]
		{
			["ID"] = 34,
			["name"] = "Strength of the Warden",
			["icon"] = 3193846,
		}, -- [34]
		{
			["ID"] = 35,
			["name"] = "Breath of the Dying",
			["icon"] = 3193844,
		}, -- [35]
		{
			["ID"] = 36,
			["name"] = "Spark of Inspiration",
			["icon"] = 3193843,
		}, -- [36]
		{
			["ID"] = 37,
			["name"] = "The Formless Void",
			["icon"] = 3193845,
		}, -- [37]
	}
	local roleInfo = {
		["DAMAGER"] = {
			["essences"] = {
				23, -- [1]
				35, -- [2]
				14, -- [3]
				32, -- [4]
				5, -- [5]
				27, -- [6]
				6, -- [7]
				15, -- [8]
				36, -- [9]
				12, -- [10]
				37, -- [11]
				28, -- [12]
				22, -- [13]
				4, -- [14]
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
				34, -- [9]
				12, -- [10]
				37, -- [11]
				33, -- [12]
				22, -- [13]
				4, -- [14]
			},
		},
		["HEALER"] = {
			["essences"] = {
				18, -- [1]
				32, -- [2]
				20, -- [3]
				27, -- [4]
				15, -- [5]
				24, -- [6]
				12, -- [7]
				17, -- [8]
				37, -- [9]
				19, -- [10]
				16, -- [11]
				22, -- [12]
				21, -- [13]
				4, -- [14]
			},
		},
	};
	function GetEssenceInfoByID(essenceID)
		local essence = GetEssenceInfo(essenceID);
		if not essence then
			essence = BtWLoadoutsEssenceInfo and BtWLoadoutsEssenceInfo[essenceID] or essenceInfo[essenceID];
		end
		return essence;
	end
	function GetEssenceInfoForRole(role, index)
		if BtWLoadoutsRoleInfo[role] and BtWLoadoutsRoleInfo[role].essences and BtWLoadoutsRoleInfo[role].essences[index] then
			return GetEssenceInfoByID(BtWLoadoutsRoleInfo[role].essences[index]);
		end

		if roleInfo[role] and roleInfo[role].essences and roleInfo[role].essences[index] then
			return GetEssenceInfoByID(roleInfo[role].essences[index]);
		end
	end
	Internal.GetEssenceInfoByID = GetEssenceInfoByID
	Internal.GetEssenceInfoForRole = GetEssenceInfoForRole
end
function Internal.GetCharacterInfo(character)
	return BtWLoadoutsCharacterInfo and BtWLoadoutsCharacterInfo[character];
end
function Internal.GetFormattedCharacterName(slug, includeRealm)
	local characterInfo = Internal.GetCharacterInfo(slug)
	if characterInfo then
		local classColor = C_ClassColor.GetClassColor(characterInfo.class)
		if includeRealm then
			return format("%s - %s", classColor:WrapTextInColorCode(characterInfo.name), characterInfo.realm)
		else
			return classColor:WrapTextInColorCode(characterInfo.name)
		end
	end
	return slug
end
local characterIteratorTemp = {}
function Internal.CharacterIterator()
	wipe(characterIteratorTemp);
	for character in pairs(BtWLoadoutsCharacterInfo or {}) do
		characterIteratorTemp[#characterIteratorTemp+1] = character
	end
	table.sort(characterIteratorTemp, function (a, b)
		return a < b
	end)
	return ipairs(characterIteratorTemp)
end
-- EnumerateRealms
do
	local unique, list = {}, {}
	function Internal.EnumerateRealms()
		wipe(unique)
		wipe(list)
		for _,character in pairs(BtWLoadoutsCharacterInfo or {}) do
			unique[character.realm] = true
		end
		for realm in pairs(unique) do
			list[#list+1] = realm
		end
		table.sort(list, function (a, b)
			return a < b
		end)
		return ipairs(list)
	end
end
-- EnumerateCharactersForRealm
do
	local list = {}
	function Internal.EnumerateCharactersForRealm(realm)
		wipe(list)
		for slug,character in pairs(BtWLoadoutsCharacterInfo or {}) do
			if character.realm == realm then
				list[#list+1] = slug
			end
		end
		table.sort(list, function (a, b)
			return a < b
		end)
		return ipairs(list)
	end
end
function Internal.DeleteCharacter(slug)
	if Internal.Call("CHARACTER_DELETE", slug) then
		BtWLoadoutsCharacterInfo[slug] = nil
	end
	BtWLoadoutsFrame:Update();
end
function Internal.UpdatePlayerInfo()
    local name, realm = UnitFullName("player");
    local class = select(2, UnitClass("player"));
    local race = select(3, UnitRace("player"));
    local sex = UnitSex("player") - 2;

    BtWLoadoutsCharacterInfo[realm .. "-" .. name] = {name = name, realm = GetRealmName(), class = class, race = race, sex = sex};
end
-- Checks if the player can switch to specID, used to check if loadouts are valid
function Internal.CanSwitchToSpecialization(specID)
	local playerClass = select(2, UnitClass("player"));
	local specClass = select(6, GetSpecializationInfoByID(specID));
	if playerClass ~= specClass then
		return false
	end
	local specIndex = GetSpecialization()
	if specIndex == nil then
		return false
	end

	if select(2, GetInstanceInfo()) == "arena" then
		-- Can not switch specs in arena
		return GetSpecializationInfo(specIndex) == specID
	elseif select(2, GetInstanceInfo()) == "battleground" then
		-- You can only switch specs in bgs unless you go from or to healer
		local currentRole = GetSpecializationRole(specIndex)
		local targetRole = GetSpecializationRoleByID(specID)

		return (currentRole == targetRole) or not (currentRole == "HEALER" or targetRole == "HEALER")
	end

	return true
end
function Internal.HasJailersChains()
	return GetPlayerAuraBySpellID(338906) ~= nil
end