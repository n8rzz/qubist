extends "res://tests/q_test.gd"

const Audio := preload("res://game/audio.gd")


## An Audio that records the players it starts instead of playing them.
func _recording() -> Array:
	var started: Array = []
	var audio := Audio.new()
	audio.play = func(player: AudioStreamPlayer) -> void: started.append([player, player.stream])
	return [audio, started]


func test_chime_rises_with_combo_size() -> void:
	check_eq(Audio.chime_pitch(1), 1.0, "one line plays the chime as recorded")
	var last := 0.0
	for lines in range(1, Audio.CHIME_SEMITONES.size() + 1):
		var pitch := Audio.chime_pitch(lines)
		check(pitch > last, "%d lines rings higher than %d" % [lines, lines - 1])
		last = pitch
	check_eq(Audio.chime_pitch(3), pow(2.0, 7 / 12.0), "three lines is a fifth up")
	check_eq(Audio.chime_pitch(99), Audio.chime_pitch(Audio.CHIME_SEMITONES.size()), "huge combos stay on the top note")
	check_eq(Audio.chime_pitch(0), 1.0, "out of range falls back to the base note")


func test_clacks_take_turns() -> void:
	var pair := _recording()
	var audio: Audio = pair[0]
	for i in Audio.CLACKS.size() + 1:
		audio.land()
	var heard: Array = pair[1].map(func(e): return e[1])
	check_eq(heard.slice(0, Audio.CLACKS.size()), Array(Audio.CLACKS), "each clack in order")
	check_eq(heard[-1], Audio.CLACKS[0], "then back to the first")
	check(pair[1].all(func(e): return e[0] == audio.clack_player), "on the clack player")
	audio.free()


func test_clear_alternates_crumbles_and_pitches_the_chime() -> void:
	var pair := _recording()
	var audio: Audio = pair[0]
	var started: Array = pair[1]
	audio.clear(1)
	check_eq(started.size(), 2, "a crumble and a chime")
	check_eq(started[0], [audio.crumble_player, Audio.CRUMBLES[0]])
	check_eq(started[1], [audio.chime_player, Audio.CHIME])
	check(is_equal_approx(audio.chime_player.pitch_scale, Audio.chime_pitch(1)), "base chime for one line")
	audio.clear(3)
	check_eq(started[2], [audio.crumble_player, Audio.CRUMBLES[1]], "the other crumble")
	check(is_equal_approx(audio.chime_player.pitch_scale, Audio.chime_pitch(3)), "higher chime for a bigger combo")
	audio.clear(0)
	check_eq(started.size(), 4, "no lines, no sound")
	audio.free()


func test_sound_effects_switch_silences_effects() -> void:
	var pair := _recording()
	var audio: Audio = pair[0]
	audio.sound_effects = false
	audio.land()
	audio.clear(2)
	check_eq(pair[1], [], "nothing plays while off")
	audio.sound_effects = true
	audio.land()
	check_eq(pair[1].size(), 1, "plays again once back on")
	audio.free()
