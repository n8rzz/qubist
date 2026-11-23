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
const SCORE_POP_COLOR := Color("#1B428F")
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
## the number on screen, so the counter never jumps back.
func tick_to(target: int) -> void:
	if target == shown_score:
		_set_shown(target)
		return
	if _tween != null:
		_tween.kill()
	_tween = host.create_tween()
	_tween.tween_method(func(v: float) -> void: _set_shown(roundi(v)),
		float(shown_score), float(target), SCORE_TICK_SECONDS) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Stops any tick and shows the current score at once.
func snap() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_set_shown(host.game.score if host.game != null else 0)


## The running count-up, or null. Tests step it by hand.
func tween() -> Tween:
	return _tween


func _set_shown(value: int) -> void:
	shown_score = value
	host.score_label.text = UI.format_number(value)
	host.best_label.text = "Best %s" % UI.format_number(maxi(host.stats.best_score, value))


## Floating "+points" over the move, and a combo/streak banner when they apply.
## Only line clears score, so a move that clears nothing shows nothing.
func show_gain(result: Dictionary) -> void:
	if int(result.score.total) <= 0:
		return
	var rect: Rect2 = host.viewport_box.get_global_rect()
	var at: Vector2 = rect.position \
		+ host.tower.project_point(ViewMath.cells_center(result.cleared, host.config.grid_size))
	var pop := UI.label("+%s" % UI.format_number(int(result.score.total)), 24, SCORE_POP_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER)
	host.add_child(pop)
	pop.reset_size()
	pop.position = at - pop.size * 0.5
	var pt := pop.create_tween().set_parallel()
	pt.tween_property(pop, "position:y", pop.position.y - SCORE_POP_RISE, SCORE_POP_SECONDS) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	pt.tween_property(pop, "modulate:a", 0.0, SCORE_POP_SECONDS).set_ease(Tween.EASE_IN)
	pt.chain().tween_callback(pop.queue_free)

	var text := banner_text(result)
	if text.is_empty():
		return
	var banner := UI.label(text, 18, UI.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	banner.add_theme_stylebox_override("normal", UI.box(host.ACCENT, host.ACCENT, 18, 0, Vector2(16, 8)))
	host.add_child(banner)
	banner.reset_size()
	banner.position = Vector2(rect.get_center().x - banner.size.x * 0.5, rect.position.y + 56)
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.6, 0.6)
	var bt := banner.create_tween()
	bt.tween_property(banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
