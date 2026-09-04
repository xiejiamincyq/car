class_name AudioDirector
extends Node

const CollisionSound = preload("res://scripts/collision_sound.gd")
const SoundEffects = preload("res://scripts/sound_effects.gd")
const MusicDirector = preload("res://scripts/audio/music_director.gd")
const MusicCatalog = preload("res://scripts/audio/music_catalog.gd")

var collision_audio: AudioStreamPlayer
var engine_audio: AudioStreamPlayer
var acceleration_audio: AudioStreamPlayer
var pickup_audio: AudioStreamPlayer
var coin_audio: AudioStreamPlayer
var warning_audio: AudioStreamPlayer
var overdrive_start_audio: AudioStreamPlayer
var overdrive_loop_audio: AudioStreamPlayer
var overdrive_end_audio: AudioStreamPlayer
var ui_audio: AudioStreamPlayer
var event_audio: AudioStreamPlayer
var music: MusicDirector
var cue_catalog: Dictionary = {}
var last_audio_cue := ""
var last_countdown_value := -1
var last_fuel_audio_tier := 0
var last_lane_audio_state := 0
var warning_cooldown := 0.0
var master_volume := 0.65
var music_volume := 0.65
var effects_volume := 0.65
var muted := false
var _overdrive_was_active := false

func _ready() -> void:
	collision_audio = _make_effect_player(CollisionSound.create_stream(), -10.0)
	engine_audio = _make_effect_player(SoundEffects.create_engine_loop(), -18.0)
	acceleration_audio = _make_effect_player(SoundEffects.create_acceleration(), -12.0)
	pickup_audio = _make_effect_player(SoundEffects.create_pickup(), -10.0)
	coin_audio = _make_effect_player(SoundEffects.create_coin_pickup(), -11.0)
	warning_audio = _make_effect_player(SoundEffects.create_warning(), -13.0)
	overdrive_start_audio = _make_effect_player(SoundEffects.create_overdrive_ignition(), -9.0)
	overdrive_loop_audio = _make_effect_player(SoundEffects.create_overdrive_loop(), -16.0)
	overdrive_end_audio = _make_effect_player(SoundEffects.create_overdrive_release(), -11.0)
	cue_catalog = SoundEffects.create_cue_catalog()
	ui_audio = _make_effect_player(cue_catalog.ui_move, -14.0)
	event_audio = _make_effect_player(cue_catalog.near_miss, -12.0)
	music = MusicDirector.new()
	music.name = "MusicDirector"
	add_child(music)

func effect_players() -> Array[AudioStreamPlayer]:
	return [collision_audio, engine_audio, acceleration_audio, pickup_audio, coin_audio, warning_audio, overdrive_start_audio, overdrive_loop_audio, overdrive_end_audio, ui_audio, event_audio]

func apply_bus_settings(new_master_volume: float, new_music_volume: float, new_effects_volume: float, is_muted: bool) -> void:
	master_volume = clampf(new_master_volume, 0.0, 1.0)
	music_volume = clampf(new_music_volume, 0.0, 1.0)
	effects_volume = clampf(new_effects_volume, 0.0, 1.0)
	muted = is_muted
	_apply_bus_volume(&"Master", master_volume)
	_apply_bus_volume(&"Music", music_volume)
	_apply_bus_volume(&"Effects", effects_volume)
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, muted)
	if music != null:
		music.set_muted(muted)
	if muted:
		stop_run_audio()
		if ui_audio != null:
			ui_audio.stop()

func handle_global_input() -> bool:
	var changed := false
	if Input.is_action_just_pressed("toggle_mute"):
		muted = not muted
		changed = true
	if Input.is_action_just_pressed("volume_down"):
		master_volume = maxf(0.0, master_volume - 0.1)
		changed = true
	if Input.is_action_just_pressed("volume_up"):
		master_volume = minf(1.0, master_volume + 0.1)
		changed = true
	if changed:
		apply_bus_settings(master_volume, music_volume, effects_volume, muted)
	return changed

func toggle_mute() -> void:
	apply_bus_settings(master_volume, music_volume, effects_volume, not muted)

func bind_ui_cues(source_root: Node) -> void:
	for node in source_root.find_children("*", "Button", true, false):
		var button := node as Button
		button.focus_entered.connect(play_ui_cue.bind("ui_move"))
		var cue_name := "ui_cancel" if button.name == "BackButton" or button.name == "CancelButton" else "ui_confirm"
		button.pressed.connect(play_ui_cue.bind(cue_name))

func update_driving(delta: float, speed_ratio: float, acceleration_pressed: bool, vehicles: Array) -> void:
	warning_cooldown = maxf(0.0, warning_cooldown - maxf(0.0, delta))
	if _effects_enabled():
		if not engine_audio.playing:
			engine_audio.play()
		engine_audio.pitch_scale = lerpf(0.78, 1.32, clampf(speed_ratio, 0.0, 1.0))
		engine_audio.volume_db = -18.0
	else:
		engine_audio.stop()
	if acceleration_pressed:
		play_effect(acceleration_audio)
	if warning_cooldown > 0.0:
		return
	for vehicle in vehicles:
		if vehicle.lane_change_enabled and vehicle.warning_started and not vehicle.change_started and vehicle.warning_remaining > 0.0:
			play_effect(warning_audio)
			warning_cooldown = 0.70
			break

func update_overdrive(active: bool, strength: float) -> void:
	if active:
		if not _overdrive_was_active:
			play_effect(overdrive_start_audio)
		if _effects_enabled() and not overdrive_loop_audio.playing:
			overdrive_loop_audio.play()
		overdrive_loop_audio.pitch_scale = lerpf(0.88, 1.22, clampf(strength, 0.0, 1.0))
		overdrive_loop_audio.volume_db = lerpf(-20.0, -13.0, clampf(strength, 0.0, 1.0))
	elif _overdrive_was_active:
		overdrive_loop_audio.stop()
		play_effect(overdrive_end_audio)
	elif overdrive_loop_audio.playing:
		overdrive_loop_audio.stop()
	_overdrive_was_active = active

func play_effect(player: AudioStreamPlayer) -> void:
	if not _effects_enabled() or player == null:
		return
	player.play()

func play_coin_pickup(combo_multiplier: int) -> void:
	coin_audio.pitch_scale = 1.0 + 0.06 * float(clampi(combo_multiplier, 1, 3) - 1)
	play_effect(coin_audio)

func play_cue(cue_name: String, player: AudioStreamPlayer = null) -> void:
	if not _effects_enabled() or not cue_catalog.has(cue_name):
		return
	var channel := event_audio if player == null else player
	channel.stream = cue_catalog[cue_name]
	last_audio_cue = cue_name
	channel.play()

func play_ui_cue(cue_name: String) -> void:
	play_cue(cue_name, ui_audio)

func update_countdown_cue(countdown_remaining: float) -> void:
	var value := maxi(1, ceili(countdown_remaining))
	if value != last_countdown_value:
		last_countdown_value = value
		play_cue("countdown")

func update_low_fuel_cue(tier: int, normal_tier: int) -> void:
	if tier == last_fuel_audio_tier:
		return
	last_fuel_audio_tier = tier
	if tier != normal_tier:
		play_cue("low_fuel")

func update_lane_event_cue(state: int, warning_state: int, closed_state: int) -> void:
	if state == last_lane_audio_state:
		return
	last_lane_audio_state = state
	if state == warning_state:
		play_cue("lane_warning")
	elif state == closed_state:
		play_cue("lane_closed")

func reset_run_state(normal_fuel_tier: int, idle_lane_state: int) -> void:
	stop_run_audio()
	_overdrive_was_active = false
	if music != null:
		music.stop()
	last_audio_cue = ""
	last_countdown_value = -1
	last_fuel_audio_tier = normal_fuel_tier
	last_lane_audio_state = idle_lane_state
	warning_cooldown = 0.0

func pause_for_gameplay() -> void:
	stop_run_audio()
	if music != null:
		music.pause()

func stop_run_audio() -> void:
	stop_driving_audio()
	if event_audio != null:
		event_audio.stop()

func stop_driving_audio() -> void:
	for player in [collision_audio, engine_audio, acceleration_audio, pickup_audio, coin_audio, warning_audio, overdrive_start_audio, overdrive_loop_audio, overdrive_end_audio]:
		if player != null:
			player.stop()

func begin_music_countdown(track_id: StringName, stream: AudioStream = null) -> void:
	var selected_stream := stream
	if selected_stream == null:
		selected_stream = MusicCatalog.stream_for(track_id)
	music.begin_countdown(track_id, selected_stream, MusicCatalog.gain_db_for(track_id))

func begin_music_race() -> void:
	music.begin_race()

func pause_music() -> void:
	music.pause()

func resume_music_countdown() -> void:
	music.resume_countdown()

func finish_music() -> void:
	music.finish()

func shutdown() -> void:
	for player in effect_players():
		if player != null:
			player.stop()
			player.stream = null
	if music != null:
		music.shutdown()
	cue_catalog.clear()

func _make_effect_player(stream: AudioStream, base_volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = base_volume_db
	player.bus = &"Effects"
	add_child(player)
	return player

func _apply_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, SoundEffects.volume_db(linear_volume))

func _effects_enabled() -> bool:
	return not muted and master_volume > 0.0 and effects_volume > 0.0
