extends Node
## Sound effects and music (#26): a stone clack when a piece lands, a crumble
## and a chime when lines clear, and one soft ambient track on a loop.
##
## The clacks take turns so repeated landings don't sound identical, the two
## crumbles alternate, and the chime climbs a major arpeggio as more lines
## clear at once. `sound_effects` and `music` follow the Settings switches.
## Credits and licenses are in assets/audio/CREDITS.md.

const CLACKS: Array[AudioStream] = [
	preload("res://assets/audio/footstep_concrete_000.ogg"),
	preload("res://assets/audio/footstep_concrete_001.ogg"),
	preload("res://assets/audio/footstep_concrete_002.ogg"),
	preload("res://assets/audio/footstep_concrete_003.ogg"),
	preload("res://assets/audio/footstep_concrete_004.ogg"),
]
const CRUMBLES: Array[AudioStream] = [
	preload("res://assets/audio/569510__sheyvan__stone-impact-rubble-debris-14.wav"),
	preload("res://assets/audio/758582__magnuswaker__rubble-trouble-3.wav"),
]
const CHIME: AudioStream = preload("res://assets/audio/759839__noisyredfox__singleding.ogg")
## Loops: the import has loop on, and the track fades softly at both ends.
const MUSIC: AudioStream = preload("res://assets/audio/velariomusic-tech-ambient-612419.mp3")

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

## Starts one effect player. Tests swap this out, since they run without a tree.
var play: Callable = func(player: AudioStreamPlayer) -> void: player.play()

var clack_player := _player(CLACK_DB, 3)
var crumble_player := _player(CRUMBLE_DB, 2)
var chime_player := _player(CHIME_DB, 2)
var _music: AudioStreamPlayer
var _next_clack := 0
var _next_crumble := 0


## The chime's pitch_scale for clearing `lines` lines at once.
static func chime_pitch(lines: int) -> float:
	var step: int = CHIME_SEMITONES[clampi(lines, 1, CHIME_SEMITONES.size()) - 1]
	return pow(2.0, step / 12.0)


func _init() -> void:
	_music = _player(MUSIC_DB, 1)
	_music.stream = MUSIC
	for player in [clack_player, crumble_player, chime_player, _music]:
		add_child(player)


func _ready() -> void:
	_music.play()
	_music.stream_paused = not music


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


## True while the music track is playing and not paused.
func is_music_playing() -> bool:
	return _music != null and _music.playing and not _music.stream_paused


static func _player(volume_db: float, polyphony: int) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	player.max_polyphony = polyphony
	return player
