extends RefCounted
## Every colour the game draws, in one place. Scripts that used to define
## their own read Palette.INK, Palette.CUBE_TOP and so on. Derived values
## like Color(Palette.CUBE_EDGE, 0.3) stay where they're used.


# -- UI text and accents --

const INK := Color("#22313F")
const DIM_INK := Color(16 / 255.0, 32 / 255.0, 44 / 255.0)
const MUTED := Color("#3D5568")
const ACCENT := Color("#1F5E7A")
const ACCENT_LEDGE := Color("#123D50")

# -- UI surfaces --

const CARD_SHADOW := Color(36 / 255.0, 72 / 255.0, 96 / 255.0, 0.16)
const CARD_HOVER := Color("#F4F8FA")
const CARD_PRESSED := Color("#E6EEF2")
const SEGMENT_TRACK := Color("#EAF1F5")
const SLIDER_RAIL := Color("#D5E2EA")
const SWITCH_OFF := Color("#C9D5DC")
const TRAY_CARD := Color(1, 1, 1, 0.86)
const TILE := Color("#EEF5F8")
const SHEET_BG := Color("#F3F8FA")
const CHEVRON := Color("#8AA0B0")

# -- Stone cubes --

const CUBE_TOP := Color("#ECE7DD")
const CUBE_TOP_INSET := Color("#F6F2EA")
const CUBE_LEFT := Color("#B7AD9D")
const CUBE_LEFT_INSET := Color("#C2B9AA")
const CUBE_RIGHT := Color("#D3CABB")
const CUBE_RIGHT_INSET := Color("#DCD4C6")
const CUBE_EDGE := Color("#857B6D")
const BLOCK_COLOR := Color("#D9D3C8")
const BEHIND_COLOR := Color("#F3F0EA")
const BEHIND_EDGE_COLOR := Color("#C4BCB0")
const DUST_COLOR := Color("#D9D6CC")

# -- Island --

const EARTH_LEFT := Color("#8E6B4F")
const EARTH_RIGHT := Color("#A47C5B")
const EARTH_EDGE := Color("#6E523C")
const EARTH_STRATA := Color("#7E5E45", 0.55)
const BRICK_LEFT := Color("#C77E54")
const BRICK_RIGHT := Color("#D8956A")
const BRICK_EDGE := Color("#8F5235")
const MORTAR := Color("#F0C9A8", 0.8)
const GRASS_LEFT := Color("#7DB34A")
const GRASS_RIGHT := Color("#8BC152")
const GRASS := Color("#9CCD63")
const GRASS_EDGE := Color("#6E9E3E")
const WATER := Color("#79C6E0")
const WATER_EDGE := Color("#4E9DBB")
const RIPPLE := Color("#E6F7FC")
const FLOOR := Color("#B7DE83")
const FLOOR_EDGE := Color("#7FAE4E")
const FLOOR_LINES := Color(1, 1, 1, 0.55)
const BUSH := Color("#5E9E3A")
const BUSH_LIGHT := Color("#76B84A")
const BUSH_SHADOW := Color(40 / 255.0, 70 / 255.0, 30 / 255.0, 0.25)
const ROCK := Color("#C9C1B3")
const GUIDE_COLOR := Color(0.45, 0.45, 0.45, 0.55)
const GUIDE_NIGHT_COLOR := Color("#8CCBE6", 0.65)
const TREE_SHADOW := Color(40 / 255.0, 60 / 255.0, 30 / 255.0, 0.22)

# -- Placement ghost --

const GHOST_COLOR := Color(64 / 255.0, 201 / 255.0, 135 / 255.0, 0.35)
const GHOST_LINE_COLOR := Color("#2FAE72")

# -- Crown and gold --

const CROWN := Color("#F5C451")
const CROWN_EDGE := Color("#C98A1E")
const GOLD := Color("#FFC94D")
const BANNER_LEDGE := Color("#D99A1E")
const BANNER_TEXT := Color("#4A2E05")
const SCORE_POP_OUTLINE := Color("#B9832A")

# -- Effects --

const SWEEP_COLOR := Color("#2559C9")
const FLASH_COLOR := Color("#FFD23F")
const FLASH_EDGE_COLOR := Color("#B8860B")
const CRACK_COLOR := Color("#7A6F61")
const CRACK_LINE := Color("#5E554A")

# -- Night UI --

const NIGHT_INK := Color.WHITE
const NIGHT_MUTED := Color("#C9D8E6")
const NIGHT_CARD := Color("#2A3A66")
const NIGHT_CARD_HOVER := Color("#31426F")
const NIGHT_CARD_PRESSED := Color("#22305A")
const NIGHT_LEDGE := Color("#121A36")
const NIGHT_TRAY_CARD := Color("#26355F")
const NIGHT_SEGMENT_TRACK := Color("#1D2A50")
const NIGHT_SLIDER_RAIL := Color("#42557F")
const NIGHT_ACCENT := Color("#237196")
const NIGHT_ACCENT_LEDGE := Color("#0F3446")
const NIGHT_ACCENT_INK := Color("#8CCBE6")

# -- Snow --

const SNOW_TOP := Color("#F3F7FB")
const SNOW_TOP_INSET := Color.WHITE

# -- Sky gradients --

const SKY_GRADIENTS := {
	"sunrise":
	[
		[0.0, Color("#7E9CD3")],
		[0.38, Color("#E7B3B4")],
		[0.66, Color("#FFD9AE")],
		[1.0, Color("#FFF1DC")]
	],
	"day": [[0.0, Color("#9FD3EE")], [0.42, Color("#CBE8F6")], [1.0, Color("#F3FAFD")]],
	"sunset":
	[
		[0.0, Color("#48508F")],
		[0.34, Color("#B96A8E")],
		[0.62, Color("#F08A6B")],
		[1.0, Color("#FFC98A")]
	],
	"night": [[0.0, Color("#0B1230")], [0.45, Color("#1C2A57")], [1.0, Color("#34467A")]],
}
const CLOUD_COLORS := {
	"sunrise": Color("#FFE3DA"),
	"day": Color.WHITE,
	"sunset": Color("#F6B1A0"),
	"night": Color("#4A5C8E"),
}
const TINTS := {
	"sunrise": Color(1.0, 0.96, 0.88),
	"day": Color.WHITE,
	"sunset": Color(0.98, 0.83, 0.74),
	"night": Color(0.78, 0.82, 0.94),
}

# -- Season island colour swaps --

const ISLAND_COLORS := {
	"spring":
	{
		"#9CCD63": "#A9DA6E",
		"#6E9E3E": "#73A840",
		"#7DB34A": "#8CC152",
		"#8BC152": "#97CA5B",
		"#B7DE83": "#C3E89A",
		"#5E9E3A": "#F08FB0",
		"#76B84A": "#F9C9D8",
	},
	"summer":
	{
		"#9CCD63": "#8CC152",
		"#6E9E3E": "#5E9233",
		"#7DB34A": "#73A840",
		"#8BC152": "#7DB34A",
		"#B7DE83": "#A8D46F",
		"#7FAE4E": "#6E9E3E",
		"#79C6E0": "#5FBDDC",
		"#4E9DBB": "#3F92B3",
		"#5E9E3A": "#4E8F30",
		"#76B84A": "#66A840",
	},
	"fall":
	{
		"#9CCD63": "#C2B25A",
		"#6E9E3E": "#8F8238",
		"#7DB34A": "#A99A45",
		"#8BC152": "#B5A64E",
		"#B7DE83": "#D6CC7E",
		"#7FAE4E": "#A99A45",
		"#79C6E0": "#6FB3C8",
		"#4E9DBB": "#4A8CA3",
		"#E6F7FC": "#E6F2F5",
		"#5E9E3A": "#D9772B",
		"#76B84A": "#E8A33A",
	},
	"winter":
	{
		"#9CCD63": "#EEF3F8",
		"#6E9E3E": "#B9CAD8",
		"#7DB34A": "#DCE6EF",
		"#8BC152": "#E6EEF5",
		"#B7DE83": "#F7FAFD",
		"#7FAE4E": "#C3D3E0",
		"#79C6E0": "#CFE6F0",
		"#4E9DBB": "#9CC3D4",
		"#E6F7FC": "#FFFFFF",
		"#5E9E3A": "#E9F0F6",
		"#76B84A": "#FFFFFF",
	},
}

# -- Trees --

const TREES := {
	"spring": [Color("#8A6248"), [Color("#F7B6CB"), Color("#FBD3E0"), Color("#F49AB8")]],
	"summer": [Color("#7A5640"), [Color("#4E9A33"), Color("#6BB548"), Color("#3F8A2A")]],
	"fall": [Color("#6E4E3A"), [Color("#E0782E"), Color("#F0A33C"), Color("#C8502A")]],
	"winter": [Color("#6E5A4C"), []],
}

# -- Sky backdrop --

const SUNS := {
	"sunrise": [Vector2(52, 300), 36.0, Color("#FFD27A"), Color("#FFB86B")],
	"day": [Vector2(300, 120), 30.0, Color("#FFE27A"), Color("#FFD24D")],
	"sunset": [Vector2(290, 318), 42.0, Color("#FF9E5E"), Color("#FF7A45")],
}
const MOON := Color("#F4F1DE")
const MOON_CRATER := Color("#DDD8BF")

# -- Santa / Christmas --

const SANTA_RED := Color("#C8312F")
const SANTA_RED_DEEP := Color("#9E2222")
const SANTA_GOLD := Color("#E8B64C")
const SANTA_SKIN := Color("#F2C9A8")
const SANTA_WHITE := Color("#FFFFFF")
const SANTA_SACK := Color("#8A5A3B")
const REINDEER := Color("#8B5E3C")
const REINDEER_DARK := Color("#5E3D26")
const RED_NOSE := Color("#FF3B30")

# -- Weather particles --

const FIREFLY := Color("#FFF3A0")
const FIREFLY_GLOW := Color(1.0, 236 / 255.0, 120 / 255.0, 0.7)
const SEED := Color(1.0, 250 / 255.0, 235 / 255.0, 0.9)
const BUTTERFLY_BODY := Color("#3D3A36")
const EXTRA_LEAF_GOLD := Color("#D9A441")
