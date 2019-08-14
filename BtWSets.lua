--[[

    Profiles should be stored by character
    Talents and PvPTalent sets should be stored by classId.specIndex
    Essence sets should be stored by roleId
    Equipment sets should be stored by character
]]

local ADDON_NAME = ...;


local roles = {"TANK", "HEALER", "DAMAGER"};
local roleIndexes = {["TANK"] = 1, ["HEALER"] = 2, ["DAMAGER"] = 3};
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
	},
	[259] = {
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
	},
};
local roleInfo = {
	[1] = {
		essences = {},
	},
	[2] = {
		essences = {},
	},
	[3] = {
		essences = {},
	},
};
local MAX_PVP_TALENTS = 15;
local function GetTalentInfoForSpecID(specID, tier, column)
    for specIndex=1,GetNumSpecializations() do
        local playerSpecID = GetSpecializationInfo(specIndex);
        if playerSpecID == specID then
            return GetTalentInfoBySpecialization(specIndex, tier, column);
        end
    end

    if BtWSetsSpecInfo[specID] then
        return GetTalentInfoByID(BtWSetsSpecInfo[specID].talents[tier][column]);
    end

    if specInfo[specID] then
        return GetTalentInfoByID(specInfo[specID].talents[tier][column]);
    end
end
local function GetPvPTrinketTalentInfo(specID, index)
	local playerSpecID = GetSpecializationInfo(GetSpecialization());
	if playerSpecID == specID then
		local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(1);
		if slotInfo and slotInfo.availableTalentIDs[index] then
			return GetPvpTalentInfoByID(slotInfo.availableTalentIDs[index]);
		end
	end

    if BtWSetsSpecInfo[specID] and BtWSetsSpecInfo[specID].pvptalenttrinkets and BtWSetsSpecInfo[specID].pvptalenttrinkets[index] then
        return GetPvpTalentInfoByID(BtWSetsSpecInfo[specID].pvptalenttrinkets[index]);
    end

    if specInfo[specID] and specInfo[specID].pvptalenttrinkets and specInfo[specID].pvptalenttrinkets[index] then
        return GetPvpTalentInfoByID(specInfo[specID].pvptalenttrinkets[index]);
    end
end
local function GetPvPTalentInfoForSpecID(specID, index)
	local playerSpecID = GetSpecializationInfo(GetSpecialization());
	if playerSpecID == specID then
		local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(2);
		if slotInfo and slotInfo.availableTalentIDs[index] then
			return GetPvpTalentInfoByID(slotInfo.availableTalentIDs[index]);
		end
	end

    if BtWSetsSpecInfo[specID] and BtWSetsSpecInfo[specID].pvptalents and BtWSetsSpecInfo[specID].pvptalents[index] then
        return GetPvpTalentInfoByID(BtWSetsSpecInfo[specID].pvptalents[index]);
    end

    if specInfo[specID] and specInfo[specID].pvptalents and specInfo[specID].pvptalents[index] then
        return GetPvpTalentInfoByID(specInfo[specID].pvptalents[index]);
    end
end
local MAX_ESSENCES = 11;
local function GetEssenceInfoForRole(role, index)
    if BtWSetsRoleInfo[role] and BtWSetsRoleInfo[role].essences and BtWSetsRoleInfo[role].essences[index] then
        return C_AzeriteEssence.GetEssenceInfo(BtWSetsRoleInfo[role].essences[index]);
    end

    if roleInfo[role] and roleInfo[role].essences and roleInfo[role].essences[index] then
        return C_AzeriteEssence.GetEssenceInfo(roleInfo[role].essences[index]);
    end
end

local function AddProfile()
    local specID, specName = GetSpecializationInfo(GetSpecialization());
    local name = format("New %s Profile", specName);

    local set = {
        specID = specID,
        name = name,
        talents = talents,
    };
    BtWSetsSets.profiles[#BtWSetsSets.profiles+1] = set;
    return set;
end
local function GetProfile(id)
    return BtWSetsSets.profiles[id];
end

-- Check if the talents in the table talentIDs are selected
local function IsTalentSetActive(talentIDs)
    for talentID in ipairs(talentIDs) do
        local _, _, _, selected, available = GetTalentInfoByID(talentID, 1);

        if not selected then
            return false;
        end
    end

    return true;
end
local function ActivateTalentSet(talentIDs)
    LearnTalents(unpack(talentIDs));
end
local function AddTalentSet()
    local specID, specName = GetSpecializationInfo(GetSpecialization());
    local name = format("New %s Set", specName);
    local talents = {};
    
    for tier=1,MAX_TALENT_TIERS do
        local _, column = GetTalentTierInfo(tier, 1);
        local talentID = GetTalentInfo(tier, column, 1);
        if talentID then
            talents[talentID] = true;
        end
    end

    local set = {
        specID = specID,
        name = name,
        talents = talents,
    };
    BtWSetsSets.talents[#BtWSetsSets.talents+1] = set;
    return set;
end
local function GetTalentSet(id)
    return BtWSetsSets.talents[id];
end

local function IsPvPTalentSetActive(talentIDs)
    for talentID in ipairs(talentIDs) do
        local _, _, _, selected, available = GetTalentInfoByID(talentID, 1);

        if not selected then
            return false;
        end
    end

    return true;
end
local function AddPvPTalentSet()
    local specID, specName = GetSpecializationInfo(GetSpecialization());
    local name = format("New %s Set", specName);
	local talents = {};
	
    local talentIDs = C_SpecializationInfo.GetAllSelectedPvpTalentIDs();
    for _,talentID in ipairs(talentIDs) do
		talents[talentID] = true;
    end

    local set = {
        specID = specID,
        name = name,
        talents = talents,
    };
    BtWSetsSets.pvptalents[#BtWSetsSets.pvptalents+1] = set;
    return set;
end
local function GetPvPTalentSet(id)
    return BtWSetsSets.pvptalents[id];
end
local function ActivatePvPTalentSet(talentIDs)
    LearnPvPTalents(unpack(talentIDs));
end

local function IsEssenceSetActive(essenceIDs)
    for milestoneID,essenceID in pairs(essenceIDs) do
        print(milestoneID,essenceID);
        local info = C_AzeriteEssence.GetMilestoneInfo(milestoneID);
        if (info.unlocked or info.canUnlock) and C_AzeriteEssence.GetMilestoneEssence(milestoneID) ~= essenceID then
            return false;
        end
    end

    return true;
end
local function AddEssenceSet()
    local role = select(5,GetSpecializationInfo(GetSpecialization()));
    local name = format("New %s Set", _G[role]);
	local selected = {};
	
    selected[115] = C_AzeriteEssence.GetMilestoneEssence(115);
    selected[116] = C_AzeriteEssence.GetMilestoneEssence(116);
    selected[117] = C_AzeriteEssence.GetMilestoneEssence(117);

    local set = {
        role = roleIndexes[role],
        name = name,
        essences = selected,
    };
    BtWSetsSets.essences[#BtWSetsSets.essences+1] = set;
    return set;
end
local function GetEssenceSet(id)
    return BtWSetsSets.essences[id];
end
local function ActivateEssenceSet(essenceIDs)
    for milestoneID,essenceID in pairs(essenceIDs) do
        local info = C_AzeriteEssence.GetMilestoneInfo(milestoneID);
        if info.canUnlock then
            C_AzeriteEssence.UnlockMilestone(milestoneID);
            info.unlocked = true;
        end

        if info.unlocked then
            C_AzeriteEssence.ActivateEssence(essenceID, milestoneID);
        end
    end
end

local function IsEquipmentSetActive(set)

    return true;
end
local function GetEquipmentSet(id)
    return BtWSetsSets.equipments[id];
end
local function ActivateEquipmentSet(set)
end

local setsFiltered = {};

local NUM_TABS = 5;
local TAB_PROFILES = 1;
local TAB_TALENTS = 2;
local TAB_PVP_TALENTS = 3;
local TAB_ESSENCES = 4;
local TAB_EQUIPMENT = 5;
local function GetTabFrame(self, tabID)
	if tabID == TAB_PROFILES then
        return self.Profiles;
    elseif tabID == TAB_TALENTS then
        return self.Talents;
    elseif tabID == TAB_PVP_TALENTS then
        return self.PvPTalents;
    elseif tabID == TAB_ESSENCES then
        return self.Essences;
    elseif tabID == TAB_EQUIPMENT then
        return self.Equipment;
    end
end

local function SpecDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWSetsFrame) or 1;
    local tab = GetTabFrame(BtWSetsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;

    if selectedTab == TAB_PROFILES then
        set.specID = arg1;
        set.talentSet = nil;
        set.pvpTalentSet = nil;
        set.essencesSet = nil;
        set.equipmentSEt = nil;
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
    BtWSetsFrame:Update();
end
local function SpecDropDownInit(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo();
    
    if (level or 1) == 1 then
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
            info.checked = self:GetParent().set.specID == specID;
            UIDropDownMenu_AddButton(info, level);
        end
    end
end

local function TalentsDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWSetsFrame) or 1;
    local tab = GetTabFrame(BtWSetsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;
    set.talentSet = arg1;

    BtWSetsFrame:Update();
end
local function TalentsDropDownInit(self, level, menuList)
    if not BtWSetsSets or not BtWSetsSets.talents then
        return;
    end

    if (level or 1) == 1 then
        local frame = self:GetParent():GetParent();
        local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
        local tab = GetTabFrame(frame, selectedTab);
        
        local set = tab.set;
    
        wipe(setsFiltered);
        local sets = BtWSetsSets.talents;
        for setID,talentSet in pairs(sets) do
            if talentSet.specID == set.specID then
                setsFiltered[#setsFiltered+1] = setID;
            end
        end
        sort(setsFiltered, function (a,b)
            return sets[a].name < sets[b].name;
        end)

        local info = UIDropDownMenu_CreateInfo();
        info.text = NONE;
        info.func = TalentsDropDown_OnClick;
        info.checked = set.talentSet == nil;
        UIDropDownMenu_AddButton(info, level);
        
        for _,setID in ipairs(setsFiltered) do
            info.text = sets[setID].name;
            info.arg1 = setID;
            info.func = TalentsDropDown_OnClick;
            info.checked = set.talentSet == setID;
            UIDropDownMenu_AddButton(info, level);
        end
    end
end

local function PvPTalentsDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWSetsFrame) or 1;
    local tab = GetTabFrame(BtWSetsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;
    set.pvpTalentSet = arg1;

    BtWSetsFrame:Update();
end
local function PvPTalentsDropDownInit(self, level, menuList)
    if not BtWSetsSets or not BtWSetsSets.pvptalents then
        return;
    end

    if (level or 1) == 1 then
        local frame = self:GetParent():GetParent();
        local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
        local tab = GetTabFrame(frame, selectedTab);
        
        local set = tab.set;
    
        wipe(setsFiltered);
        local sets = BtWSetsSets.pvptalents;
        for setID,talentSet in pairs(sets) do
            if talentSet.specID == set.specID then
                setsFiltered[#setsFiltered+1] = setID;
            end
        end
        sort(setsFiltered, function (a,b)
            return sets[a].name < sets[b].name;
        end)

        local info = UIDropDownMenu_CreateInfo();
        info.text = NONE;
        info.func = PvPTalentsDropDown_OnClick;
        info.checked = set.pvpTalentSet == nil;
        UIDropDownMenu_AddButton(info, level);
        
        for _,setID in ipairs(setsFiltered) do
            info.text = sets[setID].name;
            info.arg1 = setID;
            info.func = PvPTalentsDropDown_OnClick;
            info.checked = set.pvpTalentSet == setID;
            UIDropDownMenu_AddButton(info, level);
        end
    end
end

local function EssencesDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWSetsFrame) or 1;
    local tab = GetTabFrame(BtWSetsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;
    set.essencesSet = arg1;

    BtWSetsFrame:Update();
end
local function EssencesDropDownInit(self, level, menuList)
    if not BtWSetsSets or not BtWSetsSets.essences then
        return;
    end

    if (level or 1) == 1 then
        local frame = self:GetParent():GetParent();
        local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
        local tab = GetTabFrame(frame, selectedTab);
        
        local set = tab.set;

        local role = roleIndexes[select(5, GetSpecializationInfoByID(set.specID))];
    
        wipe(setsFiltered);
        local sets = BtWSetsSets.essences;
        for setID,talentSet in pairs(sets) do
            if talentSet.role == role then
                setsFiltered[#setsFiltered+1] = setID;
            end
        end
        sort(setsFiltered, function (a,b)
            return sets[a].name < sets[b].name;
        end)

        local info = UIDropDownMenu_CreateInfo();
        info.text = NONE;
        info.func = EssencesDropDown_OnClick;
        info.checked = set.essencesSet == nil;
        UIDropDownMenu_AddButton(info, level);
        
        for _,setID in ipairs(setsFiltered) do
            info.text = sets[setID].name;
            info.arg1 = setID;
            info.func = EssencesDropDown_OnClick;
            info.checked = set.essencesSet == setID;
            UIDropDownMenu_AddButton(info, level);
        end
    end
end

local function EquipmentDropDown_OnClick(self, arg1, arg2, checked)
    local selectedTab = PanelTemplates_GetSelectedTab(BtWSetsFrame) or 1;
    local tab = GetTabFrame(BtWSetsFrame, selectedTab);

    CloseDropDownMenus();
    local set = tab.set;
    set.essencesSet = arg1;

    BtWSetsFrame:Update();
end
local function EquipmentDropDownInit(self, level, menuList)
    if not BtWSetsSets or not BtWSetsSets.essences then
        return;
    end

    if (level or 1) == 1 then
        local frame = self:GetParent():GetParent();
        local selectedTab = PanelTemplates_GetSelectedTab(frame) or 1;
        local tab = GetTabFrame(frame, selectedTab);
        
        local set = tab.set;
    
        wipe(setsFiltered);
        local sets = BtWSetsSets.essences;
        for setID,talentSet in pairs(sets) do
            if talentSet.specID == set.specID then
                setsFiltered[#setsFiltered+1] = setID;
            end
        end
        sort(setsFiltered, function (a,b)
            return sets[a].name < sets[b].name;
        end)

        local info = UIDropDownMenu_CreateInfo();
        info.text = NONE;
        info.func = EssencesDropDown_OnClick;
        info.checked = set.essencesSet == nil;
        UIDropDownMenu_AddButton(info, level);
        
        for _,setID in ipairs(setsFiltered) do
            info.text = sets[setID].name;
            info.arg1 = setID;
            info.func = EssencesDropDown_OnClick;
            info.checked = set.essencesSet == setID;
            UIDropDownMenu_AddButton(info, level);
        end
    end
end


local NUM_SCROLL_ITEMS_TO_DISPLAY = 18;
local SCROLL_ROW_HEIGHT = 22;
local setScrollItems = {};
local profilesCollapsedBySpecID = {};
local talentSetsCollapsedBySpecID = {};
local pvpTalentSetsCollapsedBySpecID = {};
local essenceSetsCollapsedByRole = {};
function BtWSetsSetsScrollFrame_Update()
    local Talents = BtWSetsFrame.Talents;

    local offset = FauxScrollFrame_GetOffset(BtWSetsFrame.Scroll);
    
	local hasScrollBar = #setScrollItems > NUM_SCROLL_ITEMS_TO_DISPLAY;
    for index=1,NUM_SCROLL_ITEMS_TO_DISPLAY do
        local button = BtWSetsFrame.ScrollButtons[index];
        button:SetWidth(hasScrollBar and 160 or 180);
        
        local item = setScrollItems[index + offset];
        if item then
            button.isAdd = item.isAdd;
            if item.isAdd then
                button.SelectedBar:Hide();
            end

            button.isHeader = item.isHeader;
			if item.isHeader then
                button:SetID(item.id);

                button.SelectedBar:Hide();

                if item.isCollapsed then
                    button.ExpandedIcon:Hide();
                    button.CollapsedIcon:Show();
                else
                    button.ExpandedIcon:Show();
                    button.CollapsedIcon:Hide();
                end
            else
                if not item.isAdd then
                    button:SetID(item.id);
                
                    button.SelectedBar:SetShown(item.selected);
                end

                button.ExpandedIcon:Hide();
                button.CollapsedIcon:Hide();
            end

            button.name:SetText(item.name);
            button:Show();
        else
            button:Hide();
        end
    end
    FauxScrollFrame_Update(BtWSetsFrame.Scroll, #setScrollItems, NUM_SCROLL_ITEMS_TO_DISPLAY, SCROLL_ROW_HEIGHT);
end
local function SetsScrollFrame_SpecFilter(selected, sets, collapsed)
    wipe(setScrollItems);
    wipe(setsFiltered);
    for setID,set in pairs(sets) do
        setsFiltered[set.specID] = setsFiltered[set.specID] or {};
        setsFiltered[set.specID][#setsFiltered[set.specID]+1] = setID;
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
                for _,setID in ipairs(setsFiltered[specID]) do
                    setScrollItems[#setScrollItems+1] = {
                        id = setID,
                        name = sets[setID].name,
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
                        for _,setID in ipairs(setsFiltered[specID]) do
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
	end
	
    setScrollItems[#setScrollItems+1] = {
        isAdd = true,
        name = "Add New",
    };
    BtWSetsSetsScrollFrame_Update();
end
local function SetsScrollFrame_RoleFilter(selected, sets, collapsed)
    wipe(setScrollItems);
    wipe(setsFiltered);
    for setID,set in pairs(sets) do
        setsFiltered[set.role] = setsFiltered[set.role] or {};
        setsFiltered[set.role][#setsFiltered[set.role]+1] = setID;
    end

	local role = roleIndexes[select(5, GetSpecializationInfo(GetSpecialization()))];
	local isCollapsed = collapsed[role] and true or false;
	if setsFiltered[role] then
		setScrollItems[#setScrollItems+1] = {
			id = role,
			isHeader = true,
			isCollapsed = isCollapsed,
			name = _G[roles[role]],
		};
		if not isCollapsed then
			sort(setsFiltered[role], function (a,b)
				return sets[a].name < sets[b].name;
			end)
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
	for role=1,3 do
		if role ~= playerRole then
			local isCollapsed = collapsed[role] and true or false;
			if setsFiltered[role] then
				setScrollItems[#setScrollItems+1] = {
					id = role,
					isHeader = true,
					isCollapsed = isCollapsed,
					name = _G[roles[role]],
				};
				if not isCollapsed then
					sort(setsFiltered[role], function (a,b)
						return sets[a].name < sets[b].name;
					end)
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

    setScrollItems[#setScrollItems+1] = {
        isAdd = true,
        name = "Add New",
    };
    BtWSetsSetsScrollFrame_Update();
end
local function SetsScrollFrame_CharacterFilter(selected, sets, collapsed)
    wipe(setScrollItems);
    wipe(setsFiltered);
    for setID,set in pairs(sets) do
        setsFiltered[set.character] = setsFiltered[set.character] or {};
        setsFiltered[set.character][#setsFiltered[set.character]+1] = setID;
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
		setScrollItems[#setScrollItems+1] = {
			character = character,
			isHeader = true,
			isCollapsed = isCollapsed,
			name = character,
		};
		if not isCollapsed then
			sort(setsFiltered[character], function (a,b)
				return sets[a].name < sets[b].name;
			end)
			for _,setID in ipairs(setsFiltered[character]) do
				setScrollItems[#setScrollItems+1] = {
					setID = setID,
					name = sets[setID].name,
					selected = sets[setID] == selected,
				};
			end
		end
	end

	local playerCharacter = character;
	for _,character in ipairs(characters) do
		if character ~= playerCharacter then
			if setsFiltered[character] then
				local isCollapsed = collapsed[character] and true or false;
				setScrollItems[#setScrollItems+1] = {
					character = character,
					isHeader = true,
					isCollapsed = isCollapsed,
					name = character,
				};
				if not isCollapsed then
					sort(setsFiltered[character], function (a,b)
						return sets[a].name < sets[b].name;
					end)
					for _,setID in ipairs(setsFiltered[character]) do
						setScrollItems[#setScrollItems+1] = {
							setID = setID,
							name = sets[setID].name,
							selected = sets[setID] == selected,
						};
					end
				end
			end
		end
	end

    setScrollItems[#setScrollItems+1] = {
        isAdd = true,
        name = "Add New",
    };
    BtWSetsSetsScrollFrame_Update();
end

local function ProfilesTabUpdate(self)
    if not self.set.specID then
        self.set.specID = GetSpecializationInfo(GetSpecialization());
    end

    local specID = self.set.specID;

    local _, specName, _, icon, _, classID = GetSpecializationInfoByID(specID);
    local className = LOCALIZED_CLASS_NAMES_MALE[classID];
    local classColor = C_ClassColor.GetClassColor(classID);
    UIDropDownMenu_SetText(self.SpecDropDown, format("%s: %s", classColor:WrapTextInColorCode(className), specName));

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

	SetsScrollFrame_SpecFilter(self.set, BtWSetsSets.profiles, profilesCollapsedBySpecID);

    -- wipe(setScrollItems);
    -- wipe(setsFiltered);
    -- local sets = BtWSetsSets.profiles;
    -- for setID,set in pairs(sets) do
    --     setsFiltered[set.specID] = setsFiltered[set.specID] or {};
    --     setsFiltered[set.specID][#setsFiltered[set.specID]+1] = setID;
    -- end

    -- local className, classFile, classID = UnitClass("player");
    -- local classColor = C_ClassColor.GetClassColor(classFile);
    -- className = classColor and classColor:WrapTextInColorCode(className) or className;

    -- for specIndex=1,GetNumSpecializationsForClassID(classID) do
    --     local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
    --     local isCollapsed = profilesCollapsedBySpecID[specID] and true or false;
    --     if setsFiltered[specID] then
    --         setScrollItems[#setScrollItems+1] = {
    --             specID = specID,
    --             isHeader = true,
    --             isCollapsed = isCollapsed,
    --             name = format("%s: %s", classColor:WrapTextInColorCode(className), specName),
    --         };
    --         if not isCollapsed then
    --             sort(setsFiltered[specID], function (a,b)
    --                 return sets[a].name < sets[b].name;
    --             end)
    --             for _,setID in ipairs(setsFiltered[specID]) do
    --                 setScrollItems[#setScrollItems+1] = {
    --                     setID = setID,
    --                     name = sets[setID].name,
    --                     selected = sets[setID] == self.set,
    --                 };
    --             end
    --         end
    --     end
    -- end
    -- local playerClassID = classID;
    -- for classID=1,GetNumClasses() do
    --     if classID ~= playerClassID then
    --         local className, classFile = GetClassInfo(classID);
    --         local classColor = C_ClassColor.GetClassColor(classFile);
    --         className = classColor and classColor:WrapTextInColorCode(className) or className;

    --         for specIndex=1,GetNumSpecializationsForClassID(classID) do
    --             local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
    --             local isCollapsed = profilesCollapsedBySpecID[specID] and true or false;
    --             if setsFiltered[specID] then
    --                 setScrollItems[#setScrollItems+1] = {
    --                     specID = specID,
    --                     isHeader = true,
    --                     isCollapsed = isCollapsed,
    --                     name = format("%s: %s", classColor:WrapTextInColorCode(className), specName),
    --                 };
    --                 if not isCollapsed then
    --                     sort(setsFiltered[specID], function (a,b)
    --                         return sets[a].name < sets[b].name;
    --                     end)
    --                     for _,setID in ipairs(setsFiltered[specID]) do
    --                         setScrollItems[#setScrollItems+1] = {
    --                             setID = setID,
    --                             name = sets[setID].name,
    --                             selected = sets[setID] == self.set,
    --                         };
    --                     end
    --                 end
    --             end
    --         end
    --     end
    -- end
    -- setScrollItems[#setScrollItems+1] = {
    --     isAdd = true,
    --     name = "Add New",
    -- };
    -- BtWSetsSetsScrollFrame_Update();
end
local function TalentsTabUpdate(self)
    if not self.set.specID then
        self.set.specID = GetSpecializationInfo(GetSpecialization());
    end

    local specID = self.set.specID;
    local selected = self.set.talents;

    local _, specName, _, icon, _, classID = GetSpecializationInfoByID(specID);
    local className = LOCALIZED_CLASS_NAMES_MALE[classID];
    local classColor = C_ClassColor.GetClassColor(classID);
    UIDropDownMenu_SetText(self.SpecDropDown, format("%s: %s", classColor:WrapTextInColorCode(className), specName));

    if self.set.inUse then
        UIDropDownMenu_DisableDropDown(self.SpecDropDown);
    else
        UIDropDownMenu_EnableDropDown(self.SpecDropDown);
    end

    self.Name:SetText(self.set.name or "");

    for tier=1,MAX_TALENT_TIERS do
        for column=1,3 do
            local item = self.rows[tier].talents[column];
            local talentID, name, texture, _, _, spellID = GetTalentInfoForSpecID(specID, tier, column);

            item:SetID(talentID);
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

	SetsScrollFrame_SpecFilter(self.set, BtWSetsSets.talents, talentSetsCollapsedBySpecID);

    -- wipe(setScrollItems);
    -- wipe(setsFiltered);
    -- local sets = BtWSetsSets.talents;
    -- for setID,set in pairs(sets) do
    --     setsFiltered[set.specID] = setsFiltered[set.specID] or {};
    --     setsFiltered[set.specID][#setsFiltered[set.specID]+1] = setID;
    -- end

    -- local className, classFile, classID = UnitClass("player");
    -- local classColor = C_ClassColor.GetClassColor(classFile);
    -- className = classColor and classColor:WrapTextInColorCode(className) or className;

    -- for specIndex=1,GetNumSpecializationsForClassID(classID) do
    --     local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
    --     local isCollapsed = talentSetsCollapsedBySpecID[specID] and true or false;
    --     if setsFiltered[specID] then
    --         setScrollItems[#setScrollItems+1] = {
    --             specID = specID,
    --             isHeader = true,
    --             isCollapsed = isCollapsed,
    --             name = format("%s: %s", classColor:WrapTextInColorCode(className), specName),
    --         };
    --         if not isCollapsed then
    --             sort(setsFiltered[specID], function (a,b)
    --                 return sets[a].name < sets[b].name;
    --             end)
    --             for _,setID in ipairs(setsFiltered[specID]) do
    --                 setScrollItems[#setScrollItems+1] = {
    --                     setID = setID,
    --                     name = sets[setID].name,
    --                     selected = sets[setID] == self.set,
    --                 };
    --             end
    --         end
    --     end
    -- end
    -- local playerClassID = classID;

    -- for classID=1,GetNumClasses() do
    --     if classID ~= playerClassID then
    --         local className, classFile = GetClassInfo(classID);
    --         local classColor = C_ClassColor.GetClassColor(classFile);
    --         className = classColor and classColor:WrapTextInColorCode(className) or className;

    --         for specIndex=1,GetNumSpecializationsForClassID(classID) do
    --             local specID, specName, _, icon, role = GetSpecializationInfoForClassID(classID, specIndex);
    --             local isCollapsed = talentSetsCollapsedBySpecID[specID] and true or false;
    --             if setsFiltered[specID] then
    --                 setScrollItems[#setScrollItems+1] = {
    --                     specID = specID,
    --                     isHeader = true,
    --                     isCollapsed = isCollapsed,
    --                     name = format("%s: %s", classColor:WrapTextInColorCode(className), specName),
    --                 };
    --                 if not isCollapsed then
    --                     sort(setsFiltered[specID], function (a,b)
    --                         return sets[a].name < sets[b].name;
    --                     end)
    --                     for _,setID in ipairs(setsFiltered[specID]) do
    --                         setScrollItems[#setScrollItems+1] = {
    --                             setID = setID,
    --                             name = sets[setID].name,
    --                             selected = sets[setID] == self.set,
    --                         };
    --                     end
    --                 end
    --             end
    --         end
    --     end
    -- end
    -- setScrollItems[#setScrollItems+1] = {
    --     isAdd = true,
    --     name = "Add New",
    -- };

    -- BtWSetsSetsScrollFrame_Update();
end
local function PvPTalentsTabUpdate(self)
    if not self.set.specID then
        self.set.specID = GetSpecializationInfo(GetSpecialization());
    end

    local specID = self.set.specID;
    local selected = self.set.talents;

    local _, specName, _, icon, _, classID = GetSpecializationInfoByID(specID);
    local className = LOCALIZED_CLASS_NAMES_MALE[classID];
    local classColor = C_ClassColor.GetClassColor(classID);
    UIDropDownMenu_SetText(self.SpecDropDown, format("%s: %s", classColor:WrapTextInColorCode(className), specName));

    if self.set.inUse then
        UIDropDownMenu_DisableDropDown(self.SpecDropDown);
    else
        UIDropDownMenu_EnableDropDown(self.SpecDropDown);
    end

    self.Name:SetText(self.set.name or "");

    local trinkets = self.trinkets;
    for column=1,3 do
        local item = trinkets.talents[column];
        local talentID, name, texture, _, _, spellID = GetPvPTrinketTalentInfo(specID, column);

		item.isPvP = true;
        item:SetID(talentID);
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
			item:SetID(talentID);
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

	SetsScrollFrame_SpecFilter(self.set, BtWSetsSets.pvptalents, pvpTalentSetsCollapsedBySpecID);
end
local function EssenceScrollFrameUpdate(self)
    local pending = self:GetParent().pending;
    local role = self:GetParent().set.role;
	local selected = self:GetParent().set.essences;
	
	local offset = HybridScrollFrame_GetOffset(self);
	local buttons = self.buttons;
	for i,item in ipairs(buttons) do
		local index = offset + i;
		local essence = GetEssenceInfoForRole(role, index);
		
		if essence then
			item:SetID(essence.ID);
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
end
local function EssencesTabUpdate(self)
    if not self.set.role then
        self.set.role = roleIndexes[select(5, GetSpecializationInfo(GetSpecialization()))];
	end

    local role = self.set.role;
    local selected = self.set.essences;
	
    -- UIDropDownMenu_SetText(self.SpecDropDown, format("%s: %s", classColor:WrapTextInColorCode(className), specName));

    -- if self.set.inUse then
    --     UIDropDownMenu_DisableDropDown(self.SpecDropDown);
    -- else
    --     UIDropDownMenu_EnableDropDown(self.SpecDropDown);
    -- end

	-- self.Name:SetText(self.set.name or "");

    for milestoneID,item in pairs(self.Slots) do
		local essenceID = self.set.essences[milestoneID];
		item.milestoneID = milestoneID;

		if essenceID then
			local info = C_AzeriteEssence.GetEssenceInfo(essenceID);

			item:SetID(essenceID);
			
			item.Icon:Show();
			item.Icon:SetTexture(info.icon);
			item.EmptyGlow:Hide();
			item.EmptyIcon:Hide();
		else
			item.Icon:Hide();
			item.EmptyGlow:Show();
			item.EmptyIcon:Show();
		end
        -- item.name:SetText(name);
        -- item.icon:SetTexture(texture);
        
        -- if selected[talentID] then
        --     item.knownSelection:Show();
        --     item.icon:SetDesaturated(false);
        -- else
        --     item.knownSelection:Hide();
        --     item.icon:SetDesaturated(true);
        -- end
	end
	
	EssenceScrollFrameUpdate(self.EssenceList);
	SetsScrollFrame_RoleFilter(self.set, BtWSetsSets.essences, essenceSetsCollapsedByRole);
end
local function EquipmentTabUpdate(self)
    wipe(setScrollItems);
    wipe(setsFiltered);
    BtWSetsSetsScrollFrame_Update();
end

BtWSetsFrameMixin = {};
function BtWSetsFrameMixin:OnLoad()
    tinsert(UISpecialFrames, self:GetName());
    self:RegisterForDrag("LeftButton");
    
    self.Profiles.set = {};
    
    self.Talents.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
    self.Talents.set = {talents = {}};

    self.PvPTalents.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
    self.PvPTalents.set = {talents = {}};

    self.Essences.temp = {}; -- Stores talents for currently unselected specs incase the user switches to them
	self.Essences.set = {essences = {}};
	self.Essences.pending = nil;

	PanelTemplates_SetNumTabs(self, NUM_TABS);
    PanelTemplates_SetTab(self, TAB_PROFILES);


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
	

	self.Essences.Slots = {
		[115] = self.Essences.MajorSlot,
		[116] = self.Essences.MinorSlot1,
		[117] = self.Essences.MinorSlot2,
	};
	
	HybridScrollFrame_CreateButtons(self.Essences.EssenceList, "BtWSetsAzeriteEssenceButtonTemplate", 4, -3, "TOPLEFT", "TOPLEFT", 0, -1, "TOP", "BOTTOM");
	self.Essences.EssenceList.update = EssenceScrollFrameUpdate;
end
function BtWSetsFrameMixin:OnDragStart()
    self:StartMoving();
end
function BtWSetsFrameMixin:OnDragStop()
	self:StopMovingOrSizing();
end
function BtWSetsFrameMixin:OnMouseUp()
	if self.Essences.pending ~= nil then
		self.Essences.pending = nil
		SetCursor(nil);
		self:Update();
	end
end
function BtWSetsFrameMixin:OnEnter()
	if self.Essences.pending ~= nil then
		SetCursor("interface/cursor/cast.blp");
	end
end
function BtWSetsFrameMixin:OnLeave()
	SetCursor(nil);
end
function BtWSetsFrameMixin:SetProfile(set)
    self.Profiles.set = set;
    self:Update();
end
function BtWSetsFrameMixin:SetTalentSet(set)
    self.Talents.set = set;
    wipe(self.Talents.temp);
    self:Update();
end
function BtWSetsFrameMixin:SetPvPTalentSet(set)
    self.PvPTalents.set = set;
    wipe(self.PvPTalents.temp);
    self:Update();
end
function BtWSetsFrameMixin:SetEssenceSet(set)
    self.Essences.set = set;
    wipe(self.Essences.temp);
    self:Update();
end
function BtWSetsFrameMixin:Update()
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
    end
end
function BtWSetsFrameMixin:ScrollItemClick(button)
    CloseDropDownMenus();
    local selectedTab = PanelTemplates_GetSelectedTab(self) or 1;
    if selectedTab == TAB_PROFILES then
        local frame = self.Profiles;
        if button.isAdd then
            self:SetProfile(AddProfile());
            C_Timer.After(0, function ()
                frame.Name:HighlightText();
                frame.Name:SetFocus();
            end)
        elseif button.isHeader then
            profilesCollapsedBySpecID[button:GetID()] = not profilesCollapsedBySpecID[button:GetID()] and true or nil;
            ProfilesTabUpdate(frame);
        else
            self:SetProfile(GetProfile(button:GetID()));
            frame.Name:ClearFocus();
        end
    elseif selectedTab == TAB_TALENTS then
        local Talents = self.Talents;
        if button.isAdd then
            self:SetTalentSet(AddTalentSet());
            C_Timer.After(0, function ()
                Talents.Name:HighlightText();
                Talents.Name:SetFocus();
            end)
        elseif button.isHeader then
            talentSetsCollapsedBySpecID[button:GetID()] = not talentSetsCollapsedBySpecID[button:GetID()] and true or nil;
            TalentsTabUpdate(self.Talents);
        else
            self:SetTalentSet(GetTalentSet(button:GetID()));
            Talents.Name:ClearFocus();
        end
    elseif selectedTab == TAB_PVP_TALENTS then
        local PvPTalents = self.PvPTalents;
        if button.isAdd then
            self:SetPvPTalentSet(AddPvPTalentSet());
            C_Timer.After(0, function ()
                PvPTalents.Name:HighlightText();
                PvPTalents.Name:SetFocus();
            end)
        elseif button.isHeader then
            pvpTalentSetsCollapsedBySpecID[button:GetID()] = not pvpTalentSetsCollapsedBySpecID[button:GetID()] and true or nil;
            PvPTalentsTabUpdate(self.PvPTalents);
        else
            self:SetPvPTalentSet(GetPvPTalentSet(button:GetID()));
            PvPTalents.Name:ClearFocus();
        end
    elseif selectedTab == TAB_ESSENCES then
        local frame = self.Essences;
        if button.isAdd then
            self:SetEssenceSet(AddEssenceSet());
            C_Timer.After(0, function ()
                frame.Name:HighlightText();
                frame.Name:SetFocus();
            end)
        elseif button.isHeader then
            essenceSetsCollapsedByRole[button:GetID()] = not essenceSetsCollapsedByRole[button:GetID()] and true or nil;
            EssencesTabUpdate(frame);
        else
            self:SetEssenceSet(GetEssenceSet(button:GetID()));
            frame.Name:ClearFocus();
        end
    end
end

BtWSetsTalentButtonMixin = {};
function BtWSetsTalentButtonMixin:OnLoad()
    self:RegisterForClicks("LeftButtonUp");
end
function BtWSetsTalentButtonMixin:OnClick()
    local row = self:GetParent();
    local talents = row:GetParent();
    local talentID = self:GetID();

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
                talents.set.talents[item:GetID()] = nil;

			    item.knownSelection:Hide();
                item.icon:SetDesaturated(true);
            end
        end
    end
end
function BtWSetsTalentButtonMixin:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	if self.isPvP then
		GameTooltip:SetPvpTalent(self:GetID(), true);
	else
		GameTooltip:SetTalent(self:GetID(), true);
	end
end
function BtWSetsTalentButtonMixin:OnLeave()
	GameTooltip_Hide();
end

BtWSetsTalentGridButtonMixin = CreateFromMixins(BtWSetsTalentButtonMixin);
function BtWSetsTalentGridButtonMixin:OnClick()
    local grid = self:GetParent();
    local talents = grid:GetParent();
    local talentID = self:GetID();

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

BtWSetsAzeriteMilestoneSlotMixin = {};
function BtWSetsAzeriteMilestoneSlotMixin:OnLoad()
	self.EmptyGlow.Anim:Play();
end
function BtWSetsAzeriteMilestoneSlotMixin:OnEnter()
	if self:GetID() then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetAzeriteEssence(self:GetID(), 4);
		GameTooltip_SetBackdropStyle(GameTooltip, GAME_TOOLTIP_BACKDROP_STYLE_AZERITE_ITEM);
	end

	if self:GetParent().pending then
		SetCursor("interface/cursor/cast.blp");
	end
end
function BtWSetsAzeriteMilestoneSlotMixin:OnLeave()
	GameTooltip_Hide();
end
function BtWSetsAzeriteMilestoneSlotMixin:OnClick()
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

	BtWSetsFrame:Update();
end

BtWSetsAzeriteEssenceButtonMixin = {};
function BtWSetsAzeriteEssenceButtonMixin:OnClick()
	SetCursor("interface/cursor/cast.blp");
	BtWSetsFrame.Essences.pending = self:GetID();
	BtWSetsFrame:Update();
end
function BtWSetsAzeriteEssenceButtonMixin:OnEnter()
	if self:GetID() then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetAzeriteEssence(self:GetID(), 4);
	end

	if BtWSetsFrame.Essences.pending then
		SetCursor("interface/cursor/cast.blp");
	end
end

local tomeButton = CreateFrame("BUTTON", "BtWSetsTomeButton", UIParent, "SecureActionButtonTemplate,SecureHandlerAttributeTemplate");
tomeButton:SetFrameStrata("DIALOG");
tomeButton:SetAttribute("*type1", "item");
tomeButton:SetAttribute("unit", "player");
tomeButton:SetAttribute("item", "Tome of the Tranquil Mind");
RegisterStateDriver(tomeButton, "combat", "[combat] hide; show")
tomeButton:SetAttribute("_onattributechanged", [[ -- (self, name, value)
    print(name);
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

StaticPopupDialogs["BTWSETS_REQUESTACTIVATE"] = {
	text = "Activate spec %s?",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
	end,
	OnShow = function(self)
	end,
	timeout = 0,
	hideOnEscape = 1
};
StaticPopupDialogs["BTWSETS_REQUESTACTIVATERESTED"] = {
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
StaticPopupDialogs["BTWSETS_REQUESTACTIVATETOME"] = {
	text = "Activate spec %s?\nThis will use a Tome",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
        print("OnAccept");
	end,
    OnShow = function(self)
        print("OnShow");
        tomeButton:SetParent(self);
        tomeButton:ClearAllPoints();
        tomeButton:SetPoint("TOPLEFT", self.button1, "TOPLEFT", 0, 0);
        tomeButton:SetPoint("BOTTOMRIGHT", self.button1, "BOTTOMRIGHT", 0, 0);
        tomeButton.button = self.button1;

        tomeButton:SetFrameLevel(self.button1:GetFrameLevel() + 1);
        tomeButton:SetAttribute("active", true);
	end,
    OnHide = function(self)
        print("OnHide");
        tomeButton:SetParent(UIParent);
        tomeButton:ClearAllPoints();
        tomeButton.button = nil;
        tomeButton:SetAttribute("active", false);
	end,
	hasItemFrame = 1,
	timeout = 0,
	hideOnEscape = 1
};
-- /run StaticPopup_Show("BTWSETS_NEEDTOME")
-- 
StaticPopupDialogs["BTWSETS_NEEDTOME"] = {
	text = "A tome is needed to continue equiping your set.",
	button1 = YES,
	button2 = NO,
    OnAccept = function(self)
        print("OnAccept");
	end,
    OnShow = function(self)
        print("OnShow");
        tomeButton:SetParent(self);
        tomeButton:ClearAllPoints();
        tomeButton:SetPoint("TOPLEFT", self.button1, "TOPLEFT", 0, 0);
        tomeButton:SetPoint("BOTTOMRIGHT", self.button1, "BOTTOMRIGHT", 0, 0);
        tomeButton.button = self.button1;

        tomeButton:SetFrameLevel(self.button1:GetFrameLevel() + 1);
        tomeButton:SetAttribute("active", true);
	end,
    OnHide = function(self)
        print("OnHide");
        tomeButton:SetParent(UIParent);
        tomeButton:ClearAllPoints();
        tomeButton.button = nil;
        tomeButton:SetAttribute("active", false);
	end,
	-- hasItemFrame = 1,
	timeout = 0,
	hideOnEscape = 1
};

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
local function PlayerNeedsTome()
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

local function IsSetActive(set)
    local specIndex = GetSpecialization()
    if not specIndex then
        return false;
    end
    
    local specID = GetSpecializationInfo(specIndex)
    if set.specID ~= specID then
        return false;
    end

    if set.talentSet and not IsTalentSetActive(GetTalentSet(set.talentSet)) then
        return false;
    end

    if set.pvpTalentSet and not IsPvPTalentSetActive(GetPvPTalentSet(set.talentSet)) then
        return false;
    end

    if set.essencesSet and not IsEssenceSetActive(GetEssenceSet(set.essencesSet)) then
        return false;
    end

    if set.equipmentSet and not IsEquipmentSetActive(GetEquipmentSet(set.equipmentSet)) then
        return false;
    end

    return true;
end


local function IsChangingSpec()
    local _, _, _, _, _, _, _, _, spellId = UnitCastingInfo("player");
    return spellId == 200749;
end

local function RequestTome()
    StaticPopup_Show("BTWSETS_NEEDTOME", nil, nil, nil, tomeButton);
end
-- Ask the user if we should active this set
local function RequestActivateSet(set)
    if IsSetActive(set) then
        return;
    end

    BtWSetsRequestFrame.set = set;
    BtWSetsRequestFrame:Show();
end
-- Activating a set can take multiple passes, things maybe delayed by switching spec or waiting for the player to use a tome
local targetSet = nil
local targetDirty = false;
local function ContinueActivateSet()
    local set = targetSet;

    -- Should check if we are currently changing spec

    if IsChangingSpec() then
        return;
    end

    local specIndex = GetSpecialization()
    if set.specIndex ~= specIndex then
        SetSpecialization(set.specIndex);
        return;
    end


    if set.talentSet and not IsTalentSetActive(GetTalentSet(set.talentSet)) and PlayerNeedsTome() then
        RequestTome();
        return;
    end

    if set.pvpTalentSet and not IsPvPTalentSetActive(GetPvPTalentSet(set.pvpTalentSet)) and PlayerNeedsTome() then
        RequestTome();
        return;
    end

    if set.essencesSet and not IsEssenceSetActive(GetEssenceSet(set.essencesSet)) and PlayerNeedsTome() then
        RequestTome();
        return;
    end


    if set.talentSet then
        ActivateTalentSet(GetTalentSet(set.talentSet));
    end

    if set.pvpTalentSet then
        ActivatePvPTalentSet(GetPvPTalentSet(set.pvpTalentSet));
    end

    if set.essencesSet then
        ActivateEssenceSet(GetEssenceSet(set.essencesSet));
    end


    if set.equipmentSet then
        ActiveEquipmentSet(GetEquipmentSet(set.equipmentSet));
    end

    targetSet = nil;
end
local function BeginActivateSet(set)
    targetSet = set;
    targetDirty = true;
end

local function PlayerNeedsTomeNowForSet(set)
    return;

    -- local specIndex = GetSpecialization()
    -- if specIndex ~= set.specIndex then
    --     return false;
    -- end

    -- return PlayerNeedsTome();
end

local tomes = {
    141446
};
local function GetBestTome()
    for _,itemId in ipairs(tomes) do
        print(itemId);
        local count = GetItemCount(itemId);
        print(itemId, count);
        if count >= 1 then
            local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemId);
            print(itemId, name, link, quality, icon);
            return name, link, quality, icon;
        end
    end
end

local frame = CreateFrame("Frame");
-- /run BtWSets_ActivateSet("Outlaw M+")
function BtWSets_ActivateSet(id)
    local profile = BtWSetsSets.profiles[id];
    assert(profile);
    BeginActivateSet(profile);
    frame:Show();

    -- local name, link, quality, icon = GetBestTome();
    -- local r, g, b = GetItemQualityColor(quality); 
    -- StaticPopup_Show("BTWSETS_REQUESTACTIVATETOME", "", nil, {["texture"] = icon, ["name"] = name, ["color"] = {r, g, b, 1}, ["link"] = link, ["count"] = 1});
end


frame:SetScript("OnEvent", function (self, event, ...)
    self[event](self, ...);
end);
function frame:ADDON_LOADED(...)
    if ... == ADDON_NAME then
        BtWSetsSets = BtWSetsSets or {
            profiles = {
                [1] = {
                    name = "Outlaw M+",
                    specID = 251,
                    talentSet = 1,
                    essencesSet = 1,
                },
            },
            talents = {
                [1] = {
                    specID = 260,
                    name = "Outlaw M+",
                    talents = {
                        [22119] = true,
                        [19236] = true,
                        [19240] = true,
                        [22122] = true,
                        [22115] = true,
                        [23128] = true,
                        [22125] = true,
                    }
                },
            },
            pvptalents = {

            },
            essences = {
                [1] = {
                    role = 3,
                    name = "Outlaw M+",
                    essences = {
                        [115] = 5,
                        [116] = 27,
                    }
                },
            },
            equipment = {

            },
        };

        BtWSetsSpecInfo = BtWSetsSpecInfo or {};
        BtWSetsRoleInfo = BtWSetsRoleInfo or {};
    end
end
function frame:PLAYER_ENTERING_WORLD()
    for specIndex=1,GetNumSpecializations() do
        local specID = GetSpecializationInfo(specIndex);
        local spec = BtWSetsSpecInfo[specID] or {};
		local talents = spec.talents;
		
		spec.talents = spec.talents or {};
        for tier=1,MAX_TALENT_TIERS do
            local tierItems = talents[tier] or {};

            for column=1,3 do
                local talentID = GetTalentInfoBySpecialization(specIndex, tier, column);
                tierItems[column] = talentID;
            end

            talents[tier] = tierItems;
		end

        BtWSetsSpecInfo[specID] = spec;
	end
	
	do
		local specID = GetSpecializationInfo(GetSpecialization());
		local spec = BtWSetsSpecInfo[specID] or {};

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

		BtWSetsSpecInfo[specID] = spec;
	end

	do
		local roleID = roleIndexes[select(5, GetSpecializationInfo(GetSpecialization()))];
		local role = BtWSetsRoleInfo[roleID] or {};
		
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
		end

		BtWSetsRoleInfo[roleID] = role;
	end
end
function frame:PLAYER_ENTER_COMBAT()
    StaticPopup_Hide("BTWSETS_NEEDTOME");
end
function frame:PLAYER_UPDATE_RESTING()
    if AreTalentsLocked() then
        StaticPopup_Hide("BTWSETS_REQUESTACTIVATETOME");
        StaticPopup_Hide("BTWSETS_REQUESTACTIVATE");
        return;
    end

    local _, frame = StaticPopup_Visible("BTWSETS_REQUESTACTIVATETOME");
    if frame then
        if not PlayerNeedsTomeNowForSet(frame.data) then
            StaticPopup_Hide("BTWSETS_REQUESTACTIVATETOME");
            StaticPopup_Show("BTWSETS_REQUESTACTIVATE");
        end

        return;
    end

    local _, frame = StaticPopup_Visible("BTWSETS_REQUESTACTIVATE");
    if frame then
        if PlayerNeedsTomeNowForSet(frame.data) then
            StaticPopup_Hide("BTWSETS_REQUESTACTIVATE");
            StaticPopup_Show("BTWSETS_REQUESTACTIVATETOME");
        end

        return;
    end

    local _, frame = StaticPopup_Visible("BTWSETS_NEEDTOME");
    if frame then
        if not PlayerNeedsTomeNowForSet(frame.data) then
            targetDirty = true;
        end

        return;
    end
end
frame.UNIT_AURA = frame.PLAYER_UPDATE_RESTING;
function frame:PLAYER_SPECIALIZATION_CHANGED(...)
    print("PLAYER_SPECIALIZATION_CHANGED", GetTime(), ...);
    if targetSet then
        targetDirty = true;
    end
end
function frame:ACTIVE_TALENT_GROUP_CHANGED(...)
    print("ACTIVE_TALENT_GROUP_CHANGED", GetTime(), ...);
end
function frame:ZONE_CHANGED(...)
end
frame.ZONE_CHANGED_INDOORS = frame.ZONE_CHANGED;
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("PLAYER_ENTER_COMBAT");
frame:RegisterEvent("PLAYER_UPDATE_RESTING");
frame:RegisterUnitEvent("UNIT_AURA", player);
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
frame:RegisterEvent("ZONE_CHANGED");
frame:RegisterEvent("ZONE_CHANGED_INDOORS");
frame:SetScript("OnUpdate", function (self)
    if targetSet then
        if targetDirty then
            ContinueActivateSet();
        end
    else
        self:Hide();
    end
end)