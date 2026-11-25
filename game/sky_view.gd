extends RefCounted
## The season and time of day every screen's sky shows (#168), and the
## colours that go with them. One shared view, kept in static vars, so Home,
## the game, Stats and the loading view always agree and a change crossfades
## on all of them at once.
##
## The loading view and main.gd call start() with the player's settings;
## main.gd then calls follow_clock() each frame and follow() when Settings
## change. The backdrop, the particles and the island read it every frame. Colours follow the "Seasons and time of day" design
## in Notion.

const SkyClock := preload("res://core/sky_clock.gd")
const UI := preload("res://game/ui_style.gd")

## How long a change of season or time of day takes to fade in.
const CROSSFADE_SECONDS := 3.0
## How often, in seconds, a sky that follows the day checks the clock for a
## new season or time of day (#168).
const CLOCK_CHECK_SECONDS := 30.0

## Sky gradients, top to bottom, as [stop, colour] pairs.
const GRADIENTS := {
	"sunrise": [[0.0, Color("#7E9CD3")], [0.38, Color("#E7B3B4")], [0.66, Color("#FFD9AE")], [1.0, Color("#FFF1DC")]],
	"day": [[0.0, Color("#9FD3EE")], [0.42, Color("#CBE8F6")], [1.0, Color("#F3FAFD")]],
	"sunset": [[0.0, Color("#48508F")], [0.34, Color("#B96A8E")], [0.62, Color("#F08A6B")], [1.0, Color("#FFC98A")]],
	"night": [[0.0, Color("#0B1230")], [0.45, Color("#1C2A57")], [1.0, Color("#34467A")]],
}
## Cloud colour, and how opaque clouds are compared with the day's.
const CLOUD_COLORS := {
	"sunrise": Color("#FFE3DA"),
	"day": Color.WHITE,
	"sunset": Color("#F6B1A0"),
	"night": Color("#4A5C8E"),
}
const CLOUD_OPACITY := {"sunrise": 0.94, "day": 1.0, "sunset": 0.88, "night": 0.65}
## Light on the island and tower: multiplied over them, as the design's
## filters warm, dim and cool them. Night stays light enough that the
## tower's blocks read clearly (#214).
const TINTS := {
	"sunrise": Color(1.0, 0.96, 0.88),
	"day": Color.WHITE,
	"sunset": Color(0.98, 0.83, 0.74),
	"night": Color(0.78, 0.82, 0.94),
}

## Island colours (as in island_art.gd) swapped for each season. Colours a
## season doesn't list stay as they are.
const ISLAND_COLORS := {
	"spring": {
		"#9CCD63": "#A9DA6E", "#6E9E3E": "#73A840", "#7DB34A": "#8CC152", "#8BC152": "#97CA5B",
		"#B7DE83": "#C3E89A", "#5E9E3A": "#F08FB0", "#76B84A": "#F9C9D8",
	},
	"summer": {
		"#9CCD63": "#8CC152", "#6E9E3E": "#5E9233", "#7DB34A": "#73A840", "#8BC152": "#7DB34A",
		"#B7DE83": "#A8D46F", "#7FAE4E": "#6E9E3E", "#79C6E0": "#5FBDDC", "#4E9DBB": "#3F92B3",
		"#5E9E3A": "#4E8F30", "#76B84A": "#66A840",
	},
	"fall": {
		"#9CCD63": "#C2B25A", "#6E9E3E": "#8F8238", "#7DB34A": "#A99A45", "#8BC152": "#B5A64E",
		"#B7DE83": "#D6CC7E", "#7FAE4E": "#A99A45", "#79C6E0": "#6FB3C8", "#4E9DBB": "#4A8CA3",
		"#E6F7FC": "#E6F2F5", "#5E9E3A": "#D9772B", "#76B84A": "#E8A33A",
	},
	"winter": {
		"#9CCD63": "#EEF3F8", "#6E9E3E": "#B9CAD8", "#7DB34A": "#DCE6EF", "#8BC152": "#E6EEF5",
		"#B7DE83": "#F7FAFD", "#7FAE4E": "#C3D3E0", "#79C6E0": "#CFE6F0", "#4E9DBB": "#9CC3D4",
		"#E6F7FC": "#FFFFFF", "#5E9E3A": "#E9F0F6", "#76B84A": "#FFFFFF",
	},
}
## The tree beside the island: trunk and three canopy colours. Winter's tree
## is bare, with snow on its branches.
const TREES := {
	"spring": [Color("#8A6248"), [Color("#F7B6CB"), Color("#FBD3E0"), Color("#F49AB8")]],
	"summer": [Color("#7A5640"), [Color("#4E9A33"), Color("#6BB548"), Color("#3F8A2A")]],
	"fall": [Color("#6E4E3A"), [Color("#E0782E"), Color("#F0A33C"), Color("#C8502A")]],
	"winter": [Color("#6E5A4C"), []],
}
## The tree's shape (#207), shared by Home's 2D tree (island_art.gd, which
## flips y) and the game's 3D one (floating_island.gd). In points from the
## foot of the trunk, x to the right and y up.
const TREE_TRUNK_HEIGHT := 34.0
## Canopy puffs as [x, y, radius, index into the season's canopy colours].
const TREE_PUFFS := [[-9, 38, 13.0, 0], [9, 40, 12.0, 2], [0, 50, 13.0, 1], [0, 38, 10.0, 1]]
## Winter's bare branches as [from, to], and the snow on them as
## [x, y, radius].
const TREE_BRANCHES := [
	[Vector2(0, 24), Vector2(-12, 38)], [Vector2(0, 30), Vector2(10, 42)],
	[Vector2(-6, 32), Vector2(-14, 41)], [Vector2(5, 36), Vector2(12, 44)],
]
const TREE_SNOW_LUMPS := [[-12, 38, 4.0], [10, 42, 4.5], [-8, 42, 3.0], [7, 44, 3.0], [0, 36, 3.5]]
## Fall's leaves on the ground are this canopy colour (the deepest red).
const TREE_FALLEN_LEAF := 2
## Snow on the cubes' tops in winter.
const SNOW_TOP := Color("#F3F7FB")
const SNOW_TOP_INSET := Color.WHITE

## Text that sits on the sky, by day and by night (#168: at night the score
## turns white). Cards keep their own colours.
const NIGHT_INK := Color.WHITE
const NIGHT_MUTED := Color("#C9D8E6")
## Controls whose text sits on the sky (#204), tagged by ink(), muted() or
## on_sky(). The sky backdrop recolours them all through recolor_text().
const TEXT_GROUP := &"sky_text"
## Each tagged control's [day, night] colours.
const TEXT_META := &"sky_text_colors"

## What each of the 16 views shows besides its colours (#209), in the order
## they're drawn. Every renderer checks this table:
## - the backdrop: "sun" or "stars", "aurora", "moon"; "birds" or "geese";
##   "mist"
## - the weather: "petal", "leaf", "snow", "seed", "firefly", "butterfly"
## - the tree: "blossom" (white dots), "fallen_leaves" (leaves at its foot)
const FEATURES := {
	"spring sunrise": ["sun", "birds", "mist", "petal", "blossom"],
	"spring day": ["sun", "birds", "petal", "blossom"],
	"spring sunset": ["sun", "petal", "blossom"],
	"spring night": ["stars", "moon", "petal", "blossom"],
	"summer sunrise": ["sun", "butterfly"],
	"summer day": ["sun", "birds", "butterfly"],
	"summer sunset": ["sun", "birds", "seed"],
	"summer night": ["stars", "moon", "firefly"],
	"fall sunrise": ["sun", "geese", "mist", "leaf", "fallen_leaves"],
	"fall day": ["sun", "geese", "leaf", "fallen_leaves"],
	"fall sunset": ["sun", "leaf", "fallen_leaves"],
	"fall night": ["stars", "moon", "leaf", "fallen_leaves"],
	"winter sunrise": ["sun", "snow"],
	"winter day": ["sun", "snow"],
	"winter sunset": ["sun", "snow"],
	"winter night": ["stars", "aurora", "moon", "snow"],
}

static var season := "spring"
static var time_of_day := "day"
## The view fading out, during a crossfade.
static var _from_season := "spring"
static var _from_time := "day"
static var _changed_msec := -1000000
## Bumped on every change, so things that rebuild on a change can tell.
static var version := 0
## Reduce Motion: the sky stands still (clouds, sun, particles).
static var still := false
## Christmas (#198): Santa's sleigh flies across the sky. Set from the date,
## or from the player's Christmas switch while the sky doesn't follow the day.
static var christmas := false
## The settings start() was given, which follow_clock() reads.
static var _settings = null
## Seconds until follow_clock() next checks the clock.
static var _clock_check_in := CLOCK_CHECK_SECONDS
## night_amount() when recolor_text() last ran, so it only recolours on a
## change.
static var _text_night := -1.0


## Starts the sky for a screen (#205): Reduce Motion from the device, and the
## view `settings` asks for, shown at once. follow_clock() then keeps it in
## step with the clock.
static func start(settings) -> void:
	# 1 is on; 0 is off and -1 is unknown, which shouldn't freeze it.
	still = DisplayServer.accessibility_should_reduce_animation() == 1
	_settings = settings
	_clock_check_in = CLOCK_CHECK_SECONDS
	follow(settings, true)


## Call every frame: every CLOCK_CHECK_SECONDS, if the settings start() was
## given follow the day, shows the clock's view. While `hold` (a piece being
## dragged, say) the check waits, and runs as soon as `hold` clears.
static func follow_clock(delta: float, hold := false) -> void:
	_clock_check_in -= delta
	if _clock_check_in > 0.0 or hold or _settings == null:
		return
	_clock_check_in = CLOCK_CHECK_SECONDS
	if _settings.sky_follows_day:
		follow(_settings)


## Shows this season and time of day, fading from the current one unless
## `instant`. Showing the current view again does nothing.
static func show(next_season: String, next_time: String, instant := false) -> void:
	if not SkyClock.SEASONS.has(next_season) or not SkyClock.TIMES.has(next_time):
		return
	if next_season == season and next_time == time_of_day:
		if instant:
			_changed_msec = -1000000
		return
	if instant:
		_from_season = next_season
		_from_time = next_time
		_changed_msec = -1000000
	else:
		# Mid-fade, the outgoing view is whichever is showing more.
		var b := blend()
		_from_season = season if b >= 0.5 else _from_season
		_from_time = time_of_day if b >= 0.5 else _from_time
		_changed_msec = Time.get_ticks_msec()
	season = next_season
	time_of_day = next_time
	version += 1


## The view `settings` asks for: the clock's, or the player's own pick.
static func view_for(settings) -> Array[String]:
	if settings.sky_follows_day:
		return SkyClock.now()
	return [settings.sky_season, settings.sky_time]


## Whether `settings` puts Santa in the sky: the date's call, or the
## player's own.
static func christmas_for(settings) -> bool:
	if settings.sky_follows_day:
		return SkyClock.christmas_now()
	return settings.sky_christmas


## Shows what `settings` asks for, and Santa at Christmas.
static func follow(settings, instant := false) -> void:
	christmas = christmas_for(settings)
	var view := view_for(settings)
	show(view[0], view[1], instant)


## How far the current crossfade has got, 0 to 1 (1 when none is running),
## eased.
static func blend() -> float:
	var t := clampf((Time.get_ticks_msec() - _changed_msec) / (CROSSFADE_SECONDS * 1000.0), 0.0, 1.0)
	return smoothstep(0.0, 1.0, t)


static func is_fading() -> bool:
	return blend() < 1.0


## The views to draw, as [season, time, weight] with weights adding to 1:
## the outgoing one first, while a crossfade runs.
static func layers() -> Array:
	var b := blend()
	if b >= 1.0:
		return [[season, time_of_day, 1.0]]
	return [[_from_season, _from_time, 1.0 - b], [season, time_of_day, b]]


## What the view for `for_season` and `for_time` shows, from FEATURES.
static func features(for_season: String, for_time: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(FEATURES.get("%s %s" % [for_season, for_time], []))
	return out


## Seconds on the animation clock: stopped under Reduce Motion.
static func seconds() -> float:
	return 0.0 if still else Time.get_ticks_msec() / 1000.0


## Mixes `pick` (a Callable from [season, time] to a Color) across the
## crossfade.
static func _mix(pick: Callable) -> Color:
	var out := Color(0, 0, 0, 0)
	for layer in layers():
		out += pick.call(layer[0], layer[1]) * layer[2]
	return out


## Mixes `pick` (a Callable from [season, time] to a float) across the
## crossfade.
static func _mixf(pick: Callable) -> float:
	var out := 0.0
	for layer in layers():
		out += pick.call(layer[0], layer[1]) * layer[2]
	return out


## 1 at night, 0 by day, in between while fading.
static func night_amount() -> float:
	return _mixf(func(_s, t): return 1.0 if t == "night" else 0.0)


## 1 in winter (snow on the cubes), 0 otherwise.
static func snow_amount() -> float:
	return _mixf(func(s, _t): return 1.0 if s == "winter" else 0.0)


## A cube's top `color`, blended towards snow as far as it's winter (#206).
static func snowy_top(color: Color) -> Color:
	return color.lerp(SNOW_TOP, snow_amount())


## A cube top's inset `color`, blended towards snow as far as it's winter.
static func snowy_top_inset(color: Color) -> Color:
	return color.lerp(SNOW_TOP_INSET, snow_amount())


## Colour for text on the sky: `day` by day, `night` at night.
static func text_color(day: Color, night: Color) -> Color:
	return day.lerp(night, night_amount())


## Colours a label (or a flat button's text) that sits on the sky: `day`
## by day, `night` at night.
static func color_text(control: Control, day: Color, night: Color) -> void:
	var color := text_color(day, night)
	if control is Button:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			control.add_theme_color_override(state, color)
	else:
		control.add_theme_color_override("font_color", color)


## Tags `control` as sky text in SKY_INK by day and NIGHT_INK at night.
## Returns it, so it can wrap UI.label().
static func ink(control: Control) -> Control:
	return on_sky(control, UI.SKY_INK, NIGHT_INK)


## Tags `control` as sky text in SKY_MUTED by day and NIGHT_MUTED at night.
static func muted(control: Control) -> Control:
	return on_sky(control, UI.SKY_MUTED, NIGHT_MUTED)


## Tags `control` as sky text in `day` by day and `night` at night, and
## colours it now and whenever it enters the tree. The sky backdrop keeps it
## in step from then on.
static func on_sky(control: Control, day: Color, night: Color) -> Control:
	if not control.has_meta(TEXT_META):
		# The sky may have changed while it was out of the tree.
		control.tree_entered.connect(_on_sky_text_entered.bind(control))
	control.set_meta(TEXT_META, [day, night])
	control.add_to_group(TEXT_GROUP)
	color_text(control, day, night)
	return control


static func _on_sky_text_entered(control: Control) -> void:
	recolor([control])


## Recolours every tagged control in `tree`, when the night amount has
## changed since last time. Every sky backdrop calls this each frame; only
## the first call after a change does any work.
static func recolor_text(tree: SceneTree) -> void:
	var night := night_amount()
	if night == _text_night:
		return
	_text_night = night
	recolor(tree.get_nodes_in_group(TEXT_GROUP))


## Colours each tagged control in `controls` for the sky as it is now.
static func recolor(controls: Array) -> void:
	for control in controls:
		var colors = control.get_meta(TEXT_META, null)
		if colors is Array:
			color_text(control, colors[0], colors[1])


## The light on the island and tower.
static func tint() -> Color:
	return _mix(func(_s, t): return TINTS[t])


## `color` from island_art.gd as this season paints it, before the tint.
static func island_color(color: Color) -> Color:
	return _mix(func(s, _t): return season_color(s, color))


## `color` as `for_season` paints it.
static func season_color(for_season: String, color: Color) -> Color:
	var swaps: Dictionary = ISLAND_COLORS.get(for_season, {})
	var key := "#" + color.to_html(false).to_upper()
	if swaps.has(key):
		return Color(swaps[key], color.a)
	return color


## The sky's colour at `t` (0 at the top, 1 at the bottom) for one time of day.
static func gradient_color(for_time: String, t: float) -> Color:
	var stops: Array = GRADIENTS[for_time]
	t = clampf(t, 0.0, 1.0)
	for i in range(1, stops.size()):
		if t <= stops[i][0]:
			var a: Array = stops[i - 1]
			var b: Array = stops[i]
			return (a[1] as Color).lerp(b[1], (t - a[0]) / (b[0] - a[0]))
	return stops[-1][1]


## The sky's colour at `t`, across the crossfade.
static func sky_color(t: float) -> Color:
	return _mix(func(_s, tm): return gradient_color(tm, t))


## Every stop used by any gradient, so drawing bands between them shows each
## gradient (and any mix of two) exactly.
static func gradient_stops() -> PackedFloat32Array:
	var stops := {}
	for key in GRADIENTS:
		for stop in GRADIENTS[key]:
			stops[stop[0]] = true
	var out := PackedFloat32Array(stops.keys())
	out.sort()
	return out


static func cloud_color() -> Color:
	return _mix(func(_s, t): return CLOUD_COLORS[t])


static func cloud_opacity() -> float:
	return _mixf(func(_s, t): return CLOUD_OPACITY[t])
