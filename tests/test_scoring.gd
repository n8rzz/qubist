extends "res://tests/q_test.gd"
## The examples from the PRD's scoring table, plus streaks.

const Config := preload("res://core/config.gd")
const Scoring := preload("res://core/scoring.gd")

var scoring := Scoring.new()


func test_no_lines_scores_nothing() -> void:
	var s := scoring.score_placement([], 0)
	check_eq(s.total, 0)
	check_eq(s.line_points, 0)
	check_eq(s.streak_bonus, 0)


func test_one_horizontal_line() -> void:
	check_eq(scoring.score_placement([6], 1).line_points, 60)


func test_one_vertical_line_is_worth_double() -> void:
	check_eq(scoring.score_placement([12], 1).line_points, 120)


func test_two_lines_together() -> void:
	var s := scoring.score_placement([6, 6], 1)
	check_eq(s.combo, 2)
	check_eq(s.line_points, 240)


func test_three_lines_together() -> void:
	check_eq(scoring.score_placement([6, 6, 12], 1).line_points, 720)


func test_first_clear_has_no_streak_bonus() -> void:
	check_eq(scoring.score_placement([6], 1).total, 60)


func test_streak_bonus_grows() -> void:
	check_eq(scoring.score_placement([6], 2).streak_bonus, 50)
	check_eq(scoring.score_placement([6], 4).streak_bonus, 150)
	check_eq(scoring.score_placement([6], 4).total, 60 + 150)


func test_streak_bonus_needs_a_clear() -> void:
	check_eq(scoring.score_placement([], 3).streak_bonus, 0)


func test_uses_the_config_numbers() -> void:
	var cfg := Config.new({"scoring": {"points_per_cube_cleared": 7, "streak_bonus": 20}})
	var s := Scoring.new(cfg).score_placement([6, 6], 3)
	check_eq(s.line_points, 7 * 12 * 2)
	check_eq(s.streak_bonus, 20 * 2)
	check_eq(s.total, 168 + 40)
