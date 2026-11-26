extends RefCounted
## Score feedback on the game screen: the floating "+points" over a clear, the
## combo/streak banner, and the header score counting up to the new total.
##
## Reads the screen's game, stats, tower and header labels through `host`,
## since the game is replaced on every new game. The pop and banner are added
## to `host` and free themselves when their tween ends.

const ViewMath := preload("res://game/view_math.gd")
const UI := preload("res://game/ui_style.gd")

# Placeholder feedback (#47).
## The "+points" pop: white Fredoka with a gold outline, as in the designs'
## Line clear artboard.
const SCORE_POP_COLOR := Color.WHITE
const SCORE_POP_OUTLINE := Color("#B9832A")
## The combo/streak banner: sunny yellow, kept for celebrations.
const BANNER_FILL := Color("#FFC94D")
const BANNER_LEDGE := Color("#D99A1E")
const BANNER_TEXT := Color("#4A2E05")
const SCORE_POP_RISE := 56.0
const SCORE_POP_SECONDS := 0.9
const BANNER_SECONDS := 1.2
## The score counter counts up to the new total over this long (#25).
const SCORE_TICK_SECONDS := 0.5

## The game screen (game/main.gd).
var host
## The score the header shows; trails game.score while the counter ticks up.
var shown_score := 0
var _tween: Tween


func _init(screen) -> void:
	host = screen


## Counts the header score up to `target`. A new gain mid-tick carries on from
## the number on screen, so the counter never jumps back. Under Reduce Motion
## it shows `target` at once.
func tick_to(target: int) -> void:
	if _tween != null and target != shown_score:
		_tween.kill()
		_tween = null
	if target == shown_score or UI.reduce_motion():
		_set_shown(target)
		return
	_tween = host.create_tween()
	(
		_tween
		. tween_method(
			func(v: float) -> void: _set_shown(roundi(v)),
			float(shown_score),
			float(target),
			SCORE_TICK_SECONDS
		)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_CUBIC)
	)


## Stops any tick and shows the current score at once.
func snap() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_set_shown(host.game.score if host.game != null else 0)


## Updates the header's best score, which stays hidden until a game has
## finished (#118).
func refresh_best() -> void:
	host.best_row.visible = host.stats.has_best()
	host.best_label.text = "BEST %s" % UI.format_number(maxi(host.stats.best_score, shown_score))


## The running count-up, or null. Tests step it by hand.
func tween() -> Tween:
	return _tween


func _set_shown(value: int) -> void:
	shown_score = value
	host.score_label.text = UI.format_number(value)
	refresh_best()


## Floating "+points" over the move, and a combo/streak banner when they apply.
## Only line clears score, so a move that clears nothing shows nothing. Under
## Reduce Motion both fade out where they appear.
func show_gain(result: Dictionary) -> void:
	if int(result.score.total) <= 0:
		return
	var rect: Rect2 = host.viewport_box.get_global_rect()
	var at: Vector2 = (
		rect.position
		+ host.tower.project_point(ViewMath.cells_center(result.cleared, host.config.grid_size))
	)
	var pop := UI.label(
		"+%s" % UI.format_number(int(result.score.total)),
		30,
		SCORE_POP_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	pop.add_theme_font_override("font", UI.title_font(700))
	pop.add_theme_color_override("font_outline_color", SCORE_POP_OUTLINE)
	pop.add_theme_constant_override("outline_size", 5)
	host.add_child(pop)
	pop.reset_size()
	pop.position = at - pop.size * 0.5
	var pt := pop.create_tween().set_parallel()
	if not UI.reduce_motion():
		(
			pt
			. tween_property(pop, "position:y", pop.position.y - SCORE_POP_RISE, SCORE_POP_SECONDS)
			. set_ease(Tween.EASE_OUT)
			. set_trans(Tween.TRANS_CUBIC)
		)
	pt.tween_property(pop, "modulate:a", 0.0, SCORE_POP_SECONDS).set_ease(Tween.EASE_IN)
	pt.chain().tween_callback(pop.queue_free)

	var text := banner_text(result)
	if text.is_empty():
		return
	var banner := UI.label(text, 24, BANNER_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	banner.add_theme_font_override("font", UI.title_font(700))
	var style := UI.box(BANNER_FILL, 16, Vector2(20, 8))
	style.shadow_color = BANNER_LEDGE
	style.shadow_size = 1
	style.shadow_offset = Vector2(0, 4)
	banner.add_theme_stylebox_override("normal", style)
	host.add_child(banner)
	banner.reset_size()
	banner.position = Vector2(rect.get_center().x - banner.size.x * 0.5, rect.position.y + 56)
	banner.pivot_offset = banner.size * 0.5
	banner.rotation = deg_to_rad(-3.0)
	var bt := banner.create_tween()
	if not UI.reduce_motion():
		banner.scale = Vector2(0.6, 0.6)
		bt.tween_property(banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(
			Tween.EASE_OUT
		)
	bt.tween_interval(BANNER_SECONDS)
	bt.tween_property(banner, "modulate:a", 0.0, 0.3)
	bt.tween_callback(banner.queue_free)


## The banner's words for a move, or "" when there is no combo or streak.
static func banner_text(result: Dictionary) -> String:
	var parts: Array[String] = []
	if int(result.score.combo) > 1:
		parts.append("Combo ×%d" % int(result.score.combo))
	if result.lines.size() > 0 and int(result.score.streak) > 1:
		parts.append("Streak %d" % int(result.score.streak))
	return "  ·  ".join(parts)
