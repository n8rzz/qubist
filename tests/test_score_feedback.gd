extends "res://tests/q_test.gd"

const ScoreFeedback := preload("res://game/score_feedback.gd")


func _result(combo: int, streak: int, lines: int) -> Dictionary:
	var cleared_lines := []
	for i in range(lines):
		cleared_lines.append(i)
	return {"score": {"total": 100, "combo": combo, "streak": streak}, "lines": cleared_lines}


func test_no_banner_for_a_plain_clear() -> void:
	check_eq(ScoreFeedback.banner_text(_result(1, 1, 1)), "")


func test_banner_shows_combo() -> void:
	check_eq(ScoreFeedback.banner_text(_result(3, 1, 3)), "Combo ×3")


func test_banner_shows_streak() -> void:
	check_eq(ScoreFeedback.banner_text(_result(1, 4, 1)), "Streak 4")


func test_banner_shows_combo_and_streak() -> void:
	check_eq(ScoreFeedback.banner_text(_result(2, 5, 2)), "Combo ×2  ·  Streak 5")


func test_no_streak_without_lines() -> void:
	check_eq(ScoreFeedback.banner_text(_result(1, 4, 0)), "")
