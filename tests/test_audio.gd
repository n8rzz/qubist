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


## The volume sliders (#165) lower every effect together, and the music on
## its own, from their levels; full volume leaves the levels as they are.
func test_volumes_scale_their_own_players() -> void:
	var audio := Audio.new()
	check_eq(audio.clack_player.volume_db, Audio.CLACK_DB, "full volume keeps the level")
	audio.sound_effects_volume = 0.5
	var offset := Audio.volume_offset_db(0.5)
	check(offset < 0.0, "half volume is quieter")
	check(is_equal_approx(audio.clack_player.volume_db, Audio.CLACK_DB + offset), "clack")
	check(is_equal_approx(audio.crumble_player.volume_db, Audio.CRUMBLE_DB + offset), "crumble")
	check(is_equal_approx(audio.chime_player.volume_db, Audio.CHIME_DB + offset), "chime")
	check_eq(audio.music_db(), Audio.MUSIC_DB, "music untouched by the effects volume")
	audio.music_volume = 0.0
	check_eq(audio.music_db(), Audio.MUSIC_DB - 80.0, "silent at zero")
	check(is_equal_approx(audio.clack_player.volume_db, Audio.CLACK_DB + offset), "effects untouched by the music volume")
	audio.sound_effects_volume = 2.0
	check_eq(audio.sound_effects_volume, 1.0, "clamped to full")
	check_eq(audio.chime_player.volume_db, Audio.CHIME_DB, "back to the level")
	audio.free()


func test_volume_offset_rises_with_the_slider() -> void:
	check_eq(Audio.volume_offset_db(1.0), 0.0, "full")
	check_eq(Audio.volume_offset_db(0.0), -80.0, "silent")
	check(Audio.volume_offset_db(0.25) < Audio.volume_offset_db(0.75), "louder further along")


## The music order (#196): random, but never the same track twice in a row.
func test_pick_track_never_repeats_the_last() -> void:
	var roll := RandomNumberGenerator.new()
	roll.seed = 196
	check_eq(Audio.pick_track(1, 0, roll), 0, "one track comes round again")
	check_eq(Audio.pick_track(0, -1, roll), 0, "no tracks still gives an index")
	var seen := {}
	var last := -1
	for i in 200:
		var pick := Audio.pick_track(4, last, roll)
		check(pick >= 0 and pick < 4, "in range")
		check(pick != last, "not the track that just played")
		seen[pick] = true
		last = pick
	check_eq(seen.size(), 4, "every track gets a turn")


func test_next_track_starts_a_track_on_the_music_player() -> void:
	var pair := _recording()
	var audio: Audio = pair[0]
	audio.next_track()
	check_eq(pair[1].size(), 1, "starts one track")
	check_eq(pair[1][0][0], audio._music, "on the music player")
	check(Audio.TRACKS.has(audio.music_track()), "one of the tracks")
	audio._music.finished.emit()
	check_eq(pair[1].size(), 2, "the next starts when one ends")
	audio.free()


## Settings names the track playing (#166): every track has a title and an
## artist, and each new track says so.
func test_every_track_has_a_title_and_artist() -> void:
	check_eq(Audio.TRACK_INFO.size(), Audio.TRACKS.size(), "one entry per track")
	for info in Audio.TRACK_INFO:
		check(info.get("title", "") != "", "a title")
		check(info.get("artist", "") != "", "an artist")


func test_next_track_announces_its_title() -> void:
	var pair := _recording()
	var audio: Audio = pair[0]
	check_eq(audio.track_title(), "", "no title before the first track")
	var heard: Array = []
	audio.track_changed.connect(func(title, artist): heard.append([title, artist]))
	audio.next_track()
	var info: Dictionary = Audio.TRACK_INFO[Audio.TRACKS.find(audio.music_track())]
	check_eq(heard, [[info.title, info.artist]], "announces the track it started")
	check_eq(audio.track_title(), info.title)
	check_eq(audio.track_artist(), info.artist)
	audio.free()

