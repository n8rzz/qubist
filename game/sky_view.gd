extends RefCounted
## The season and time of day every screen's sky shows (#168), and the
## colours that go with them. One shared view, kept in static vars, so Home,
## the game, Stats and the loading view always agree and a change crossfades
## on all of them at once.
##
## The loading view and main.gd call start() with the player's settings;
## main.gd then calls follow_clock() each frame and follow() when Settings
## change. The backdrop, the particles and the island read it every frame.
## Colours follow the "Seasons and time of day" design in Notion.

const Palette := preload("res://game/palette.gd")
const SkyClock := preload("res://core/sky_clock.gd")
const UI := preload("res://game/ui_style.gd")

## How long a change of season or time of day takes to fade in.
const CROSSFADE_SECONDS := 3.0
## How often, in seconds, a sky that follows the day checks the clock for a
## new season or time of day (#168).
const CLOCK_CHECK_SECONDS := 30.0

## Sky gradients, top to bottom, as [stop, colour] pairs.
const GRADIENTS := Palette.SKY_GRADIENTS
## Cloud colour, and how opaque clouds are compared with the day's.
const CLOUD_COLORS := Palette.CLOUD_COLORS
const CLOUD_OPACITY := {"sunrise": 0.94, "day": 1.0, "sunset": 0.88, "night": 0.65}
const TINTS := Palette.TINTS

const ISLAND_COLORS := Palette.ISLAND_COLORS
const TREES := Palette.TREES
## The tree's shape (#207), shared by Home's 2D tree (island_art.gd, which
## flips y) and the game's 3D one (floating_island.gd). In points from the
## foot of the trunk, x to the right and y up.
const TREE_TRUNK_HEIGHT := 34.0
## Canopy puffs as [x, y, radius, index into the season's canopy colours].
const TREE_PUFFS := [[-9, 38, 13.0, 0], [9, 40, 12.0, 2], [0, 50, 13.0, 1], [0, 38, 10.0, 1]]
## Winter's bare branches as [from, to], and the snow on them as
## [x, y, radius].
const TREE_BRANCHES := [
	[Vector2(0, 24), Vector2(-12, 38)],
	[Vector2(0, 30), Vector2(10, 42)],
	[Vector2(-6, 32), Vector2(-14, 41)],
	[Vector2(5, 36), Vector2(12, 44)],
]
const TREE_SNOW_LUMPS := [[-12, 38, 4.0], [10, 42, 4.5], [-8, 42, 3.0], [7, 44, 3.0], [0, 36, 3.5]]
## Fall's leaves on the ground are this canopy colour (the deepest red).
const TREE_FALLEN_LEAF := 2
## Snow on the cubes' tops in winter.
const SNOW_TOP := Palette.SNOW_TOP
const SNOW_TOP_INSET := Palette.SNOW_TOP_INSET

const NIGHT_INK := Palette.NIGHT_INK
const NIGHT_MUTED := Palette.NIGHT_MUTED
## Controls whose text sits on the sky (#204), tagged by ink(), muted() or
## on_sky(). The sky backdrop recolours them all through recolor_sky().
const TEXT_GROUP := &"sky_text"
## Each tagged control's [day, night] colours.
const TEXT_META := &"sky_text_colors"
## How far sky text takes its night colours at each time of day. Sunset's
## sky is dark enough at the top that dark ink is hard to read (#254), so
## it takes them too.
const LIGHT_TEXT := {"sunrise": 0.0, "day": 0.0, "sunset": 1.0, "night": 1.0}

## Cards and buttons on the sky turn midnight navy at night (#219). Each
## day colour they use is swapped for its night colour below: fills are a
## box's background, border and ledge; inks are its text and icons. A colour
## not listed stays as it is, so white text on the teal key stays white.
const NIGHT_CARD := Palette.NIGHT_CARD
const NIGHT_CARD_HOVER := Palette.NIGHT_CARD_HOVER
const NIGHT_CARD_PRESSED := Palette.NIGHT_CARD_PRESSED
const NIGHT_LEDGE := Palette.NIGHT_LEDGE
const NIGHT_TRAY_CARD := Palette.NIGHT_TRAY_CARD
const NIGHT_SEGMENT_TRACK := Palette.NIGHT_SEGMENT_TRACK
const NIGHT_SLIDER_RAIL := Palette.NIGHT_SLIDER_RAIL
const NIGHT_ACCENT := Palette.NIGHT_ACCENT
const NIGHT_ACCENT_LEDGE := Palette.NIGHT_ACCENT_LEDGE
const NIGHT_ACCENT_INK := Palette.NIGHT_ACCENT_INK
## [day, night] fills.
const NIGHT_FILLS := [
	[UI.WHITE, NIGHT_CARD],
	[UI.CARD_HOVER, NIGHT_CARD_HOVER],
	[UI.CARD_PRESSED, NIGHT_CARD_PRESSED],
	# Home's raised white buttons, pressed (white darkened by 8%).
	[Color(0.92, 0.92, 0.92), NIGHT_CARD_PRESSED],
	[UI.CARD_SHADOW, NIGHT_LEDGE],
	[UI.TRAY_CARD, NIGHT_TRAY_CARD],
	[UI.SEGMENT_TRACK, NIGHT_SEGMENT_TRACK],
	[UI.SLIDER_RAIL, NIGHT_SLIDER_RAIL],
	[UI.SKY_ACCENT, NIGHT_ACCENT],
	[UI.ACCENT_LEDGE, NIGHT_ACCENT_LEDGE],
	# An empty tray slot's faint fill and outline, an axis under the finger,
	# and Home's best-score pill.
	[Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.08)],
	[Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.3)],
	[Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.1)],
	[Color(1, 1, 1, 0.85), Color("#2A3A66D9")],
]
## [day, night] inks.
const NIGHT_INKS := [
	[UI.SKY_INK, NIGHT_INK],
	[UI.SKY_MUTED, NIGHT_MUTED],
	[UI.SKY_ACCENT, NIGHT_ACCENT_INK],
]
## Controls tagged by by_night(). The sky backdrop recolours them, and all
## inside them, through recolor_sky().
const NIGHT_GROUP := &"sky_night"
## On a control or a box: {property: [day, night]} for each colour it swaps.
const NIGHT_META := &"night_colors"
## The colour properties by_night() looks at on a control, and the boxes.
const NIGHT_INK_PROPS := [
	"icon_color",
	"theme_override_colors/font_color",
	"theme_override_colors/font_hover_color",
	"theme_override_colors/font_pressed_color",
	"theme_override_colors/font_hover_pressed_color",
	"theme_override_colors/font_focus_color",
	"theme_override_colors/font_disabled_color",
]
const NIGHT_BOXES := [
	"normal",
	"hover",
	"pressed",
	"hover_pressed",
	"disabled",
	"focus",
	"panel",
	"slider",
	"grabber_area",
	"grabber_area_highlight",
]
const NIGHT_FILL_PROPS := ["bg_color", "border_color", "shadow_color"]

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
## night_amount() and light_text_amount() when recolor_sky() last ran, so
## it only recolours on a change.
static var _sky_night := -1.0
static var _sky_light_text := -1.0


## Starts the sky for a screen (#205): Reduce Motion from the device, and the
## view `settings` asks for, shown at once. follow_clock() then keeps it in
## step with the clock.
static func start(settings) -> void:
	still = UI.reduce_motion()
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
	var t := clampf(
		(Time.get_ticks_msec() - _changed_msec) / (CROSSFADE_SECONDS * 1000.0), 0.0, 1.0
	)
	return smoothstep(0.0, 1.0, t)


static func is_fading() -> bool:
	return blend() < 1.0


## One view to draw: a season and time of day, and how much of it shows.
class Layer:
	var season: String
	var time: String
	## How opaque this view is, 0 to 1; the layers' weights add to 1.
	var weight: float

	func _init(for_season: String, for_time: String, for_weight: float) -> void:
		season = for_season
		time = for_time
		weight = for_weight


## The views to draw, with weights adding to 1: the outgoing one first, while
## a crossfade runs.
static func layers() -> Array[Layer]:
	var b := blend()
	if b >= 1.0:
		return [Layer.new(season, time_of_day, 1.0)]
	return [Layer.new(_from_season, _from_time, 1.0 - b), Layer.new(season, time_of_day, b)]


## What the view for `for_season` and `for_time` shows, from FEATURES.
static func features(for_season: String, for_time: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(FEATURES.get("%s %s" % [for_season, for_time], []))
	return out


## Seconds on the animation clock: stopped under Reduce Motion.
static func seconds() -> float:
	return 0.0 if still else Time.get_ticks_msec() / 1000.0


## Mixes `pick` (a Callable from [season, time] to a Color or a float)
## across the crossfade, starting from `zero` (`UI.CLEAR` or `0.0`).
static func _mix(pick: Callable, zero: Variant) -> Variant:
	var out: Variant = zero
	for layer in layers():
		out += pick.call(layer.season, layer.time) * layer.weight
	return out


## 1 at night, 0 by day, in between while fading.
static func night_amount() -> float:
	return _mix(func(_s, t): return 1.0 if t == "night" else 0.0, 0.0)


## 1 when sky text takes its night colours (sunset and night), 0 when it
## keeps its day colours, in between while fading.
static func light_text_amount() -> float:
	return _mix(func(_s, t): return LIGHT_TEXT[t], 0.0)


## 1 in winter (snow on the cubes), 0 otherwise.
static func snow_amount() -> float:
	return _mix(func(s, _t): return 1.0 if s == "winter" else 0.0, 0.0)


## A cube's top `color`, blended towards snow as far as it's winter (#206).
static func snowy_top(color: Color) -> Color:
	return color.lerp(SNOW_TOP, snow_amount())


## A cube top's inset `color`, blended towards snow as far as it's winter.
static func snowy_top_inset(color: Color) -> Color:
	return color.lerp(SNOW_TOP_INSET, snow_amount())


## Colour for text on the sky: `day` by day and at sunrise, `night` at
## sunset and night.
static func text_color(day: Color, night: Color) -> Color:
	return day.lerp(night, light_text_amount())


## Colours a label (or a flat button's text) that sits on the sky: `day`
## by day and at sunrise, `night` at sunset and night.
static func color_text(control: Control, day: Color, night: Color) -> void:
	var color := text_color(day, night)
	if control is Button:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			control.add_theme_color_override(state, color)
	else:
		control.add_theme_color_override("font_color", color)


## Tags `control` as sky text in SKY_INK by day and NIGHT_INK at sunset
## and night.
## Returns it, so it can wrap UI.label().
static func ink(control: Control) -> Control:
	return on_sky(control, UI.SKY_INK, NIGHT_INK)


## Tags `control` as sky text in SKY_MUTED by day and NIGHT_MUTED at
## sunset and night.
static func muted(control: Control) -> Control:
	return on_sky(control, UI.SKY_MUTED, NIGHT_MUTED)


## Tags `control` as sky text in `day` by day and `night` at sunset and
## night, and
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


## Tags `control` (a card or button on the sky) so it and everything inside
## it turn to night colours at night (#219), and colours them now. A box
## swapped in later takes its night colours at the next paint_night().
## Returns the control.
static func by_night(control: Control) -> Control:
	if not control.is_in_group(NIGHT_GROUP):
		# The sky may have changed while it was out of the tree.
		control.tree_entered.connect(_on_night_entered.bind(control))
		control.add_to_group(NIGHT_GROUP)
	paint_night(control)
	return control


static func _on_night_entered(control: Control) -> void:
	paint_night(control)


## Colours `node`, its boxes and everything inside it for the sky as it is
## now.
static func paint_night(node: Node) -> void:
	_paint_night(node, night_amount())


static func _paint_night(node: Node, night: float) -> void:
	if node is Control:
		if not node.has_meta(NIGHT_META):
			node.set_meta(NIGHT_META, _night_swaps(node, NIGHT_INK_PROPS, NIGHT_INKS))
		_apply_night(node, night)
		for box_name in NIGHT_BOXES:
			if node.has_theme_stylebox_override(box_name):
				var box: StyleBox = node.get_theme_stylebox(box_name)
				if box is StyleBoxFlat:
					if not box.has_meta(NIGHT_META):
						box.set_meta(NIGHT_META, _night_swaps(box, NIGHT_FILL_PROPS, NIGHT_FILLS))
					_apply_night(box, night)
	for child in node.get_children():
		_paint_night(child, night)


## {property: [day, night]} for each of `target`'s `props` whose colour now
## is a day colour in `swaps`.
static func _night_swaps(target: Object, props: Array, swaps: Array) -> Dictionary:
	var out := {}
	for prop in props:
		var day = target.get(prop)
		if not day is Color:
			continue
		for pair in swaps:
			if (pair[0] as Color).is_equal_approx(day):
				out[prop] = [day, pair[1]]
				break
	return out


static func _apply_night(target: Object, night: float) -> void:
	var swaps: Dictionary = target.get_meta(NIGHT_META, {})
	for prop in swaps:
		target.set(prop, (swaps[prop][0] as Color).lerp(swaps[prop][1], night))


## Recolours every tagged control in `tree`: sky text when the light text
## amount has changed since last time, and cards and buttons when the
## night amount has. Every sky backdrop calls this each frame; only the
## first call after a change does any work.
static func recolor_sky(tree: SceneTree) -> void:
	var light_text := light_text_amount()
	if light_text != _sky_light_text:
		_sky_light_text = light_text
		recolor(tree.get_nodes_in_group(TEXT_GROUP))
	var night := night_amount()
	if night != _sky_night:
		_sky_night = night
		recolor(tree.get_nodes_in_group(NIGHT_GROUP))


## Colours each tagged control in `controls` for the sky as it is now.
static func recolor(controls: Array) -> void:
	var night := night_amount()
	for control in controls:
		# get_meta() complains when its default is null, so check first.
		if control.has_meta(TEXT_META):
			var colors: Array = control.get_meta(TEXT_META)
			color_text(control, colors[0], colors[1])
		if control.is_in_group(NIGHT_GROUP):
			_paint_night(control, night)


## The light on the island and tower.
static func tint() -> Color:
	return _mix(func(_s, t): return TINTS[t], UI.CLEAR)


## `color` from island_art.gd as this season paints it, before the tint.
static func island_color(color: Color) -> Color:
	return _mix(func(s, _t): return season_color(s, color), UI.CLEAR)


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
	return _mix(func(_s, tm): return gradient_color(tm, t), UI.CLEAR)


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
	return _mix(func(_s, t): return CLOUD_COLORS[t], UI.CLEAR)


static func cloud_opacity() -> float:
	return _mix(func(_s, t): return CLOUD_OPACITY[t], 0.0)
