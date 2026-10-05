extends Node

## Sound effects pool plus looping background music and ambience.

const SOUNDS := {
	"chop": ["chop.ogg", "impactWood_medium_000.ogg", "impactWood_medium_001.ogg"],
	"tree_fall": ["impactWood_heavy_000.ogg"],
	"wood": ["impactPlank_medium_000.ogg", "impactPlank_medium_001.ogg", "impactPlank_medium_002.ogg"],
	"place": ["bookPlace1.ogg", "bookPlace2.ogg", "bookPlace3.ogg"],
	"coin": ["chip-lay-1.ogg", "chip-lay-2.ogg"],
	"coins": ["handleCoins.ogg", "handleCoins2.ogg"],
	"pay": ["chips-stack-1.ogg", "chips-stack-2.ogg"],
	"pop": ["drop_001.ogg", "drop_002.ogg"],
	"unlock": ["confirmation_002.ogg"],
	"upgrade": ["maximize_006.ogg"],
	"click": ["click_002.ogg"],
	"open": ["select_001.ogg"],
	"step": ["footstep00.ogg", "footstep01.ogg"],
	"bell": ["bong_001.ogg"],
	"machine": ["impactWood_light_000.ogg", "impactWood_light_001.ogg"],
}

## Loop levels (2026-10-05). music.ogg is a 150 s loop at about -12.6 dB RMS voiced for phone
## speakers (tools/make_music.py), so -16 lands near -29 dB RMS in game: low, under the effects,
## but audible. Ambience (about -22 dB RMS) sits under the music.
const MUSIC_DB := -16.0
const AMBIENCE_DB := -18.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer


func _ready() -> void:
	for key in SOUNDS:
		var list: Array = []
		for f in SOUNDS[key]:
			list.append(load("res://games/timber-valley/assets/audio/" + f))
		_streams[key] = list
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = AMBIENCE_DB
	add_child(_ambience)
	var music_path := "res://games/timber-valley/assets/audio/music.ogg"
	if ResourceLoader.exists(music_path):
		var m: AudioStream = load(music_path)
		if m is AudioStreamOggVorbis:
			(m as AudioStreamOggVorbis).loop = true
		_music.stream = m
	var amb_path := "res://games/timber-valley/assets/audio/ambience.ogg"
	if ResourceLoader.exists(amb_path):
		var a: AudioStream = load(amb_path)
		if a is AudioStreamOggVorbis:
			(a as AudioStreamOggVorbis).loop = true
		_ambience.stream = a
	apply_sound_setting()


func apply_sound_setting() -> void:
	# Inside a host app (MWM Play) the host's switches decide: never mute its Master bus,
	# ignore this game's saved mute and always play.
	var shell := TimberGame.in_shell()
	if not shell:
		AudioServer.set_bus_mute(0, not TimberGame.sound_on)
	if shell or TimberGame.sound_on:
		if _ambience.stream and not _ambience.playing:
			_ambience.play()
	# Music has its own switch (menu), under the main sound switch.
	if shell or (TimberGame.sound_on and TimberGame.music_on):
		if _music.stream and not _music.playing:
			_music.play()
	elif _music.playing:
		_music.stop()


func play(key: String, volume_db: float = 0.0, pitch: float = 1.0, min_gap: float = 0.035) -> void:
	if not _streams.has(key):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(key, -10.0)) < min_gap:
		return
	_last_played[key] = now
	var list: Array = _streams[key]
	for p in _players:
		if not p.playing:
			p.stream = list[randi() % list.size()]
			p.volume_db = volume_db
			p.pitch_scale = pitch * randf_range(0.93, 1.07)
			p.play()
			return
