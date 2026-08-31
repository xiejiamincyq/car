class_name MusicDirector
extends Node

enum Phase { STOPPED, FADING_IN, PLAYING, PAUSED, FADING_OUT }

const FADE_IN_SECONDS := 0.75
const FADE_OUT_SECONDS := 0.60
const SILENT_DB := -80.0

var player: AudioStreamPlayer
var current_track_id: StringName = &""
var phase: Phase = Phase.STOPPED
var phase_before_pause: Phase = Phase.STOPPED
var muted := false
var _fade_elapsed := 0.0
var _fade_start_db := SILENT_DB

func _ready() -> void:
	_ensure_player()

func _process(delta: float) -> void:
	tick(delta)

func begin_countdown(track_id: StringName, stream: AudioStream = null) -> void:
	_ensure_player()
	if current_track_id != track_id or player.stream != stream:
		player.stop()
		player.stream = stream
	current_track_id = track_id
	phase = Phase.FADING_IN
	phase_before_pause = Phase.STOPPED
	_fade_elapsed = 0.0
	_fade_start_db = SILENT_DB
	player.stream_paused = muted
	player.volume_db = SILENT_DB
	if not muted and player.stream != null and not player.playing:
		player.play()

func begin_race() -> void:
	if current_track_id == &"":
		return
	_ensure_player()
	phase = Phase.PLAYING
	player.stream_paused = muted
	player.volume_db = 0.0
	if not muted and player.stream != null and not player.playing:
		player.play()

func pause() -> void:
	if phase == Phase.STOPPED or phase == Phase.PAUSED:
		return
	phase_before_pause = phase
	phase = Phase.PAUSED
	if player != null:
		player.stream_paused = true

func resume_countdown() -> void:
	if current_track_id == &"":
		return
	_ensure_player()
	phase = Phase.FADING_IN
	_fade_elapsed = 0.0
	_fade_start_db = player.volume_db
	player.stream_paused = muted
	if not muted and player.stream != null and not player.playing:
		player.play()

func set_muted(value: bool) -> void:
	muted = value
	_ensure_player()
	player.stream_paused = muted or phase == Phase.PAUSED
	if not player.stream_paused and phase != Phase.STOPPED and player.stream != null and not player.playing:
		player.play()

func finish() -> void:
	if current_track_id == &"":
		stop()
		return
	_ensure_player()
	phase = Phase.FADING_OUT
	_fade_elapsed = 0.0
	_fade_start_db = player.volume_db

func tick(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	if phase == Phase.FADING_IN:
		_fade_elapsed = minf(FADE_IN_SECONDS, _fade_elapsed + safe_delta)
		player.volume_db = lerpf(_fade_start_db, 0.0, _fade_elapsed / FADE_IN_SECONDS)
	elif phase == Phase.FADING_OUT:
		_fade_elapsed = minf(FADE_OUT_SECONDS, _fade_elapsed + safe_delta)
		player.volume_db = lerpf(_fade_start_db, SILENT_DB, _fade_elapsed / FADE_OUT_SECONDS)
		if is_equal_approx(_fade_elapsed, FADE_OUT_SECONDS):
			stop()

func stop() -> void:
	if player != null:
		player.stop()
		player.stream_paused = false
		player.volume_db = SILENT_DB
	phase = Phase.STOPPED
	phase_before_pause = Phase.STOPPED
	_fade_elapsed = 0.0

func shutdown() -> void:
	stop()
	current_track_id = &""
	if player != null:
		player.stream = null

func _ensure_player() -> void:
	if player != null:
		return
	player = AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.bus = &"Music"
	player.volume_db = SILENT_DB
	add_child(player)
