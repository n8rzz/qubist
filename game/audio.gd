extends Node
## Sound effects and music (#26): a stone clack when a piece lands, a crumble
## and a chime when lines clear, and soft ambient music.
##
## The clacks take turns so repeated landings don't sound identical, the two
## takes of the stone tumble crumble alternate (#170), and the chime climbs a
## major arpeggio as more lines clear at once. The music plays TRACKS in a
## random order, never the same one twice in a row (#196); Settings shows the
## one playing and can skip to the next (#166). `sound_effects` and
## `music` follow the Settings switches,
## and `sound_effects_volume` and `music_volume` follow its sliders (#165).
## Credits and licenses are in assets/audio/CREDITS.md.

const CLACKS: Array[AudioStream] = [
	preload("res://assets/audio/footstep_concrete_000.ogg"),
	preload("res://assets/audio/footstep_concrete_001.ogg"),
	preload("res://assets/audio/footstep_concrete_002.ogg"),
	preload("res://assets/audio/footstep_concrete_003.ogg"),
	preload("res://assets/audio/footstep_concrete_004.ogg"),
]
const CRUMBLES: Array[AudioStream] = [
	preload("res://assets/audio/stone_tumble_a.wav"),
	preload("res://assets/audio/stone_tumble_b.wav"),
]
const CHIME: AudioStream = preload("res://assets/audio/759839__noisyredfox__singleding.ogg")
## The music, picked at random when one ends (#196). Each import has loop off,
## so the player's `finished` signal moves on to the next track. Add a row to
## CREDITS.md for each new track.
const TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/velariomusic-tech-ambient-612419.mp3"),
]
## Each track's title and artist, in TRACKS order, for Settings (#166).
const TRACK_INFO: Array[Dictionary] = [
	{"title": "Tech Ambient", "artist": "VelarioMusic"},
]

## A new track started: `title` and `artist` are from TRACK_INFO.
signal track_changed(title: String, artist: String)

## Semitones above the chime's own pitch for 1, 2, 3… lines cleared at once
## (a major arpeggio). Bigger combos stay on the top note.
const CHIME_SEMITONES := [0, 4, 7, 12, 16, 19]

## Levels in dB. The music sits well under the effects.
const CLACK_DB := -4.0
const CRUMBLE_DB := -2.0
const CHIME_DB := -6.0
const MUSIC_DB := -14.0

## Plays landing, crumble and chime sounds. Off with the Sound effects switch.
var sound_effects := true
## Off with the Music switch: the track pauses and picks up where it left off.
var music := true:
	set(on):
		music = on
		if _music:
			_music.stream_paused = not on

## 0 (silent) to 1 (full): scales the effects below their levels above.
var sound_effects_volume := 1.0:
	set(value):
		sound_effects_volume = clampf(value, 0.0, 1.0)
		var offset := volume_offset_db(sound_effects_volume)
		clack_player.volume_db = CLACK_DB + offset
		crumble_player.volume_db = CRUMBLE_DB + offset
		chime_player.volume_db = CHIME_DB + offset
## 0 (silent) to 1 (full): scales the music below MUSIC_DB.
var music_volume := 1.0:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_music.volume_db = MUSIC_DB + volume_offset_db(music_volume)

## Starts one player. Tests swap this out, since they run without a tree.
var play: Callable = func(player: AudioStreamPlayer) -> void: player.play()

var clack_player := _player(CLACK_DB, 3)
var crumble_player := _player(CRUMBLE_DB, 2)
var chime_player := _player(CHIME_DB, 2)
var _music: AudioStreamPlayer
var _next_clack := 0
var _next_crumble := 0
## Index into TRACKS of the track playing, or -1 before the first.
var _track := -1
## Picks the music order. Tests seed it.
var rng := RandomNumberGenerator.new()


## The chime's pitch_scale for clearing `lines` lines at once.
static func chime_pitch(lines: int) -> float:
	var step: int = CHIME_SEMITONES[clampi(lines, 1, CHIME_SEMITONES.size()) - 1]
	return pow(2.0, step / 12.0)


func _init() -> void:
	rng.randomize()
	_music = _player(MUSIC_DB, 1)
	_music.finished.connect(next_track)
	for player in [clack_player, crumble_player, chime_player, _music]:
		add_child(player)


func _ready() -> void:
	next_track()


## A random index into `count` tracks other than `last` (any if `last` is -1).
## With one track there is nothing else, so it comes round again.
static func pick_track(count: int, last: int, roll: RandomNumberGenerator) -> int:
	if count <= 1:
		return 0
	if last < 0 or last >= count:
		return roll.randi_range(0, count - 1)
	var pick := roll.randi_range(0, count - 2)
	return pick + 1 if pick >= last else pick


## Starts a randomly picked track, other than the one that just played.
## Also Settings' skip button (#166). With the Music switch off the new track
## waits, paused, at its start.
func next_track() -> void:
	_track = pick_track(TRACKS.size(), _track, rng)
	_music.stream = TRACKS[_track]
	play.call(_music)
	_music.stream_paused = not music
	track_changed.emit(track_title(), track_artist())


## The title of the track playing now, or "" before the first.
func track_title() -> String:
	return TRACK_INFO[_track].title if _track >= 0 else ""


## The artist of the track playing now, or "" before the first.
func track_artist() -> String:
	return TRACK_INFO[_track].artist if _track >= 0 else ""


## The track playing now.
func music_track() -> AudioStream:
	return _music.stream


## Stops everything, so no sound outlives the screen (or leaks at quit).
func _exit_tree() -> void:
	for player in get_children():
		(player as AudioStreamPlayer).stop()


## A piece landed on the tower.
func land() -> void:
	if not sound_effects:
		return
	clack_player.stream = CLACKS[_next_clack]
	_next_clack = (_next_clack + 1) % CLACKS.size()
	play.call(clack_player)


## `lines` lines cleared together: they crumble and the chime rings, higher
## for bigger combos.
func clear(lines: int) -> void:
	if not sound_effects or lines <= 0:
		return
	crumble_player.stream = CRUMBLES[_next_crumble]
	_next_crumble = (_next_crumble + 1) % CRUMBLES.size()
	play.call(crumble_player)
	chime_player.stream = CHIME
	chime_player.pitch_scale = chime_pitch(lines)
	play.call(chime_player)


## The music player's level in dB, after the music volume.
func music_db() -> float:
	return _music.volume_db


## True while the music track is playing and not paused.
func is_music_playing() -> bool:
	return _music != null and _music.playing and not _music.stream_paused


## dB to add to a player's level for a 0–1 slider volume. Squared, so the
## slider sounds even across its length; 0 is as quiet as Godot plays.
static func volume_offset_db(volume: float) -> float:
	return maxf(linear_to_db(volume * volume), -80.0)


static func _player(volume_db: float, polyphony: int) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	player.max_polyphony = polyphony
	return player
