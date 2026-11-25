extends RefCounted
## The season and time of day every screen's sky shows (#168), and the
## colours that go with them. One shared view, kept in static vars, so Home,
## the game, Stats and the loading view always agree and a change crossfades
## on all of them at once.
##
## main.gd picks the view (from the clock, or the player's choice in
## Settings) and calls show(); the backdrop, the particles and the island
## read it every frame. Colours follow the "Seasons and time of day" design
## in Notion.

const SkyClock := preload("res://core/sky_clock.gd")
const UI := preload("res://game/ui_style.gd")

## How long a change of season or time of day takes to fade in.
const CROSSFADE_SECONDS := 3.0

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
## Snow on the cubes' tops in winter.
const SNOW_TOP := Color("#F3F7FB")
const SNOW_TOP_INSET := Color.WHITE

## Text that sits on the sky, by day and by night (#168: at night the score
## turns white). Cards keep their own colours.
const NIGHT_INK := Color.WHITE
const NIGHT_MUTED := Color("#C9D8E6")
## Controls whose text sits on the sky (#204), tagged by ink(), muted() or
## on_sky(). The sky backdrop recolours them all through recolor_sky().
const TEXT_GROUP := &"sky_text"
## Each tagged control's [day, night] colours.
const TEXT_META := &"sky_text_colors"

## Cards and buttons on the sky turn midnight navy at night (#219). Each
## day colour they use is swapped for its night colour below: fills are a
## box's background, border and ledge; inks are its text and icons. A colour
## not listed stays as it is, so white text on the teal key stays white.
const NIGHT_CARD := Color("#2A3A66")
const NIGHT_CARD_HOVER := Color("#31426F")
const NIGHT_CARD_PRESSED := Color("#22305A")
const NIGHT_LEDGE := Color("#121A36")
const NIGHT_TRAY_CARD := Color("#26355F")
const NIGHT_SEGMENT_TRACK := Color("#1D2A50")
const NIGHT_SLIDER_RAIL := Color("#42557F")
## The teal key and slider fill, a little brighter so they stand out on navy.
const NIGHT_ACCENT := Color("#237196")
const NIGHT_ACCENT_LEDGE := Color("#0F3446")
## Teal text (Continue, the slice chip), light enough to read on navy.
const NIGHT_ACCENT_INK := Color("#8CCBE6")
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
	"normal", "hover", "pressed", "hover_pressed", "disabled", "focus", "panel",
	"slider", "grabber_area", "grabber_area_highlight",
]
const NIGHT_FILL_PROPS := ["bg_color", "border_color", "shadow_color"]

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
## night_amount() when recolor_sky() last ran, so it only recolours on a
## change.
static var _sky_night := -1.0


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


## Recolours every tagged control in `tree` (sky text, and cards and
## buttons), when the night amount has changed since last time. Every sky
## backdrop calls this each frame; only the first call after a change does
## any work.
static func recolor_sky(tree: SceneTree) -> void:
	var night := night_amount()
	if night == _sky_night:
		return
	_sky_night = night
	recolor(tree.get_nodes_in_group(TEXT_GROUP))
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
