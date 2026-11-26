extends "res://tests/q_test.gd"
## Lifetime stats (#32) and the save file they live in.

const Stats := preload("res://core/stats.gd")
const SaveFile := preload("res://core/save_file.gd")
const Game := preload("res://core/game.gd")

const TEST_PATH := "user://test_saves/stats.json"


func test_starts_at_zero() -> void:
	var stats := Stats.new()
	check_eq(stats.games_played, 0)
	check_eq(stats.best_score, 0)
	check_eq(stats.average_score(), 0)


func test_has_best_after_a_finished_game() -> void:
	var stats := Stats.new()
	check(not stats.has_best(), "no finished game yet")
	stats.record(0, 0, 0, 0)
	check(stats.has_best(), "a finished game counts, even with no points")


func test_record_adds_up_games() -> void:
	var stats := Stats.new()
	stats.record(1000, 5, 2, 3)
	stats.record(3000, 10, 1, 4)
	stats.record(500, 0, 0, 0)
	check_eq(stats.games_played, 3)
	check_eq(stats.total_score, 4500)
	check_eq(stats.best_score, 3000)
	check_eq(stats.lines_cleared, 15)
	check_eq(stats.best_combo, 2)
	check_eq(stats.longest_streak, 4)
	check_eq(stats.average_score(), 1500)


func test_average_rounds_to_whole_number() -> void:
	var stats := Stats.new()
	stats.record(100, 0, 0, 0)
	stats.record(101, 0, 0, 0)
	check_eq(stats.average_score(), 101, "100.5 rounds up")
	stats.record(100, 0, 0, 0)
	check_eq(stats.average_score(), 100, "100.33 rounds down")


func test_record_game_reads_the_game() -> void:
	var game := Game.new(null, 7)
	game.start()
	game.score = 2400
	game.lines_cleared_total = 9
	game.best_combo = 3
	game.longest_streak = 5
	var stats := Stats.new()
	stats.record_game(game)
	check_eq(stats.games_played, 1)
	check_eq(stats.best_score, 2400)
	check_eq(stats.lines_cleared, 9)
	check_eq(stats.best_combo, 3)
	check_eq(stats.longest_streak, 5)


func test_dict_round_trip() -> void:
	var stats := Stats.new()
	stats.record(1234, 6, 2, 3)
	stats.record(5678, 12, 4, 7)
	var copy := Stats.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(stats.to_dict())))
	check_eq(copy.to_dict(), stats.to_dict())
	check_eq(copy.average_score(), stats.average_score())


func test_bad_fields_read_as_zero() -> void:
	var stats := Stats.new()
	stats.from_dict({"games_played": "lots", "best_score": -5, "lines_cleared": 12.0})
	check_eq(stats.games_played, 0)
	check_eq(stats.best_score, 0)
	check_eq(stats.lines_cleared, 12)


func test_save_file_round_trip() -> void:
	SaveFile.remove(TEST_PATH)
	check_eq(SaveFile.read(TEST_PATH), {}, "missing file reads as empty")
	var stats := Stats.new()
	stats.record(900, 4, 2, 2)
	check(SaveFile.write(TEST_PATH, stats.to_dict()), "write succeeds")
	var loaded := Stats.new()
	loaded.from_dict(SaveFile.read(TEST_PATH))
	check_eq(loaded.to_dict(), stats.to_dict())
	check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "temp file is cleaned up")
	SaveFile.remove(TEST_PATH)


func test_save_file_ignores_garbage() -> void:
	var file := (
		FileAccess.open(TEST_PATH, FileAccess.WRITE)
		if DirAccess.make_dir_recursive_absolute(TEST_PATH.get_base_dir()) == OK
		else null
	)
	check(file != null, "can create test file")
	if file == null:
		return
	file.store_string("not json [")
	file.close()
	check_eq(SaveFile.read(TEST_PATH), {})
	SaveFile.remove(TEST_PATH)
