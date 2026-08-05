extends Node2D

const GameConfig = preload("res://scripts/game_config.gd")
const DriveController = preload("res://scripts/drive_controller.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")
const CollisionResponder = preload("res://scripts/collision_responder.gd")
const CollisionSound = preload("res://scripts/collision_sound.gd")
const RunState = preload("res://scripts/run_state.gd")
const FuelPickup = preload("res://scripts/fuel_pickup.gd")
const VisualStyle = preload("res://scripts/visual_style.gd")
const SoundEffects = preload("res://scripts/sound_effects.gd")
const TrackGeometry = preload("res://scripts/track_geometry.gd")
const RunSeedSequence = preload("res://scripts/run_seed_sequence.gd")
const FuelSpawnDirector = preload("res://scripts/fuel_spawn_director.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Progression = preload("res://scripts/progression.gd")
const PassEventResolver = preload("res://scripts/pass_event_resolver.gd")
const GameFeedback = preload("res://scripts/game_feedback.gd")
const LaneEventDirector = preload("res://scripts/lane_event_director.gd")
const DifficultyProfile = preload("res://scripts/difficulty_profile.gd")

const ROAD_MARK_REPEAT_DISTANCE := 92.0

var drive: DriveController
var traffic: TrafficDirector
var collision: CollisionResponder
var run: RunState
var road_scroll := 0.0
var screen_shake := Vector2.ZERO
var collision_audio: AudioStreamPlayer
var engine_audio: AudioStreamPlayer
var acceleration_audio: AudioStreamPlayer
var pickup_audio: AudioStreamPlayer
var warning_audio: AudioStreamPlayer
var audio_volume := 0.65
var audio_muted := false
var fullscreen_enabled := false
var warning_cooldown := 0.0
var fuel_pickups: Array[FuelPickup] = []
var fuel_spawn_director: FuelSpawnDirector
var run_seed_sequence: RunSeedSequence
var current_run_seed: int = 0
var difficulty_index := 1
const DIFFICULTY_NAMES := ["轻松", "标准", "困难"]

var speed_label: Label
var position_label: Label
var controls_hint_label: Label
var score_label: Label
var fuel_label: Label
var run_status_label: Label
var overlay_label: Label
var menu_backdrop: TextureRect
var overlay_shade: ColorRect
var race_hud: Control
var title_screen: Control
var settings_screen: Control
var controls_screen: Control
var countdown_screen: Control
var countdown_label: Label
var start_button: Button
var difficulty_button: Button
var settings_volume_label: Label
var settings_mute_button: Button
var settings_fullscreen_button: Button
var pause_screen: Control
var result_screen: Control
var result_heading: Label
var result_summary: Label
var confirmation_screen: Control
var destructive_action := ""
var submenu_return := "title"
var save_store: SaveStore
var save_data: Dictionary
var persistence_enabled := false
var result_persisted := false
var is_new_record := false
var title_best_scores: Label
var result_best_scores: Label
var new_record_label: Label
var feedback: GameFeedback
var feedback_banner: Label

func _ready() -> void:
	_ensure_input_actions()
	var sequence_seed := hash("%s:%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	run_seed_sequence = RunSeedSequence.new(sequence_seed)
	current_run_seed = run_seed_sequence.next_seed()
	drive = DriveController.new(GameConfig.START_SPEED, GameConfig.MAX_SPEED, GameConfig.ACCELERATION, GameConfig.BRAKING, GameConfig.STEERING_SPEED, GameConfig.ROAD_HALF_WIDTH, 30.0)
	traffic = TrafficDirector.new(current_run_seed, GameConfig.ROAD_LANE_COUNT, GameConfig.MIN_SPAWN_DISTANCE, GameConfig.MIN_TRAFFIC_GAP)
	fuel_spawn_director = FuelSpawnDirector.new(_fuel_seed_for_run(current_run_seed), GameConfig.ROAD_LANE_COUNT, GameConfig.FUEL_PICKUP_INTERVAL)
	collision = CollisionResponder.new(GameConfig.COLLISION_SPEED_PENALTY, GameConfig.COLLISION_INVULNERABILITY_SECONDS)
	run = RunState.new(GameConfig.MAX_FUEL, GameConfig.FUEL_DRAIN_PER_SECOND, GameConfig.FUEL_GRACE_SECONDS)
	feedback = GameFeedback.new(GameConfig.SPARK_MAX_COUNT)
	collision_audio = AudioStreamPlayer.new()
	collision_audio.stream = CollisionSound.create_stream()
	add_child(collision_audio)
	engine_audio = _make_audio_player(SoundEffects.create_engine_loop(), -18.0)
	acceleration_audio = _make_audio_player(SoundEffects.create_acceleration(), -12.0)
	pickup_audio = _make_audio_player(SoundEffects.create_pickup(), -10.0)
	warning_audio = _make_audio_player(SoundEffects.create_warning(), -13.0)
	race_hud = $CanvasLayer/RaceHUD
	speed_label = $CanvasLayer/RaceHUD/Rows/Speed
	position_label = $CanvasLayer/RaceHUD/Rows/Position
	controls_hint_label = $CanvasLayer/RaceHUD/Rows/ControlsHint
	score_label = $CanvasLayer/RaceHUD/Rows/Score
	fuel_label = $CanvasLayer/RaceHUD/Rows/Fuel
	run_status_label = $CanvasLayer/RaceHUD/Rows/RunStatus
	overlay_label = $CanvasLayer/Overlay
	menu_backdrop = $CanvasLayer/MenuBackdrop
	overlay_shade = $CanvasLayer/OverlayShade
	title_screen = $CanvasLayer/TitleScreen
	settings_screen = $CanvasLayer/SettingsScreen
	controls_screen = $CanvasLayer/ControlsScreen
	countdown_screen = $CanvasLayer/CountdownScreen
	countdown_label = $CanvasLayer/CountdownScreen/Label
	start_button = $CanvasLayer/TitleScreen/Center/Card/Content/StartButton
	difficulty_button = $CanvasLayer/TitleScreen/Center/Card/Content/DifficultyButton
	settings_volume_label = $CanvasLayer/SettingsScreen/Center/Card/Content/Volume
	settings_mute_button = $CanvasLayer/SettingsScreen/Center/Card/Content/MuteButton
	settings_fullscreen_button = $CanvasLayer/SettingsScreen/Center/Card/Content/FullscreenButton
	pause_screen = $CanvasLayer/PauseScreen
	result_screen = $CanvasLayer/ResultScreen
	result_heading = $CanvasLayer/ResultScreen/Center/Card/Content/Heading
	result_summary = $CanvasLayer/ResultScreen/Center/Card/Content/Summary
	confirmation_screen = $CanvasLayer/ConfirmationScreen
	title_best_scores = $CanvasLayer/TitleScreen/Center/Card/Content/BestScores
	result_best_scores = $CanvasLayer/ResultScreen/Center/Card/Content/BestScores
	new_record_label = $CanvasLayer/ResultScreen/Center/Card/Content/NewRecord
	feedback_banner = $CanvasLayer/FeedbackBanner
	_bind_ui_actions()
	_configure_persistence(SaveStore.new(), get_tree().current_scene == self)
	start_button.grab_focus()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause_for_focus_loss()

func _pause_for_focus_loss() -> void:
	if run == null or (run.phase != RunState.Phase.RUNNING and run.phase != RunState.Phase.COUNTDOWN):
		return
	run.pause_for_focus_loss()
	_stop_run_audio()
	_update_hud()
	$CanvasLayer/PauseScreen/Center/Card/Content/ResumeButton.grab_focus()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") and confirmation_screen.visible:
		_cancel_confirmation()
		return
	if Input.is_action_just_pressed("ui_cancel") and (settings_screen.visible or controls_screen.visible):
		_close_submenu()
		return
	if Input.is_action_just_pressed("pause_game"):
		if run.phase == RunState.Phase.RUNNING:
			_pause_run()
		elif run.phase == RunState.Phase.PAUSED:
			_resume_run()
	if Input.is_action_just_pressed("toggle_mute"):
		_toggle_audio_mute()
	if Input.is_action_just_pressed("toggle_fullscreen"):
		_toggle_fullscreen()
	var volume_changed := false
	if Input.is_action_just_pressed("volume_down"):
		audio_volume = maxf(0.0, audio_volume - 0.1)
		volume_changed = true
	if Input.is_action_just_pressed("volume_up"):
		audio_volume = minf(1.0, audio_volume + 0.1)
		volume_changed = true
	if volume_changed:
		_save_preferences()
	if run.phase == RunState.Phase.COUNTDOWN:
		run.tick(delta, 0.0, GameConfig.MAX_SPEED)
		_update_hud()
		queue_redraw()
		return
	if run.phase != RunState.Phase.RUNNING:
		_stop_run_audio()
		_update_hud()
		queue_redraw()
		return
	var accelerate_input := Input.get_action_strength("accelerate")
	var brake_input := Input.get_action_strength("brake")
	var steering_input := Input.get_axis("steer_left", "steer_right")
	drive.step(delta, accelerate_input, brake_input, steering_input)
	road_scroll = advance_road_scroll(road_scroll, drive.speed, delta, ROAD_MARK_REPEAT_DISTANCE)
	run.tick(delta, drive.speed, GameConfig.MAX_SPEED)
	feedback.tick(delta, run.fuel, run.difficulty_stage)
	if run.last_checkpoints_crossed > 0:
		feedback.announce_checkpoint(run.difficulty_stage, GameConfig.CHECKPOINT_FUEL_REWARD * run.last_checkpoints_crossed)
	if run.phase != RunState.Phase.RUNNING:
		_stop_run_audio()
		_update_hud()
		queue_redraw()
		return
	traffic.set_difficulty_stage(run.difficulty_stage)
	traffic.set_viewport_height(get_viewport_rect().size.y)
	traffic.tick(delta, drive.speed, _player_lane())
	_update_audio(delta, accelerate_input)
	_update_fuel_pickups(delta)
	collision.advance(delta)
	_check_collisions()
	_award_pass_events()
	screen_shake = screen_shake.move_toward(Vector2.ZERO, 140.0 * delta)
	_update_hud()
	queue_redraw()

func _draw() -> void:
	draw_set_transform(screen_shake)
	var viewport_size := get_viewport_rect().size
	var center_x := viewport_size.x * 0.5
	var road_left := center_x - GameConfig.ROAD_HALF_WIDTH
	var road_right := center_x + GameConfig.ROAD_HALF_WIDTH
	draw_rect(Rect2(Vector2.ZERO, viewport_size), VisualStyle.OCEAN)
	draw_rect(Rect2(road_left - 30.0, 0.0, GameConfig.ROAD_HALF_WIDTH * 2.0 + 60.0, viewport_size.y), VisualStyle.SHOULDER)
	var road_color := VisualStyle.road_color_for_transition(feedback.previous_stage, feedback.current_stage, feedback.stage_transition_mix)
	draw_rect(Rect2(road_left, 0.0, GameConfig.ROAD_HALF_WIDTH * 2.0, viewport_size.y), road_color)
	draw_line(Vector2(road_left, 0.0), Vector2(road_left, viewport_size.y), VisualStyle.EDGE_NEON, 8.0)
	draw_line(Vector2(road_right, 0.0), Vector2(road_right, viewport_size.y), VisualStyle.EDGE_NEON, 8.0)
	for lane_index in range(1, GameConfig.ROAD_LANE_COUNT):
		var lane_x := road_left + GameConfig.ROAD_HALF_WIDTH * 2.0 * lane_index / GameConfig.ROAD_LANE_COUNT
		var dash_y := get_dash_start_y(road_scroll, ROAD_MARK_REPEAT_DISTANCE)
		while dash_y < viewport_size.y:
			draw_rect(Rect2(lane_x - 4.0, dash_y, 8.0, 52.0), VisualStyle.LANE_MARK)
			dash_y += ROAD_MARK_REPEAT_DISTANCE
	_draw_lane_event(road_left, viewport_size.y)
	_draw_traffic(road_left)
	_draw_fuel_pickups(road_left)
	var car_center := Vector2(center_x + drive.lateral_position, TrackGeometry.player_y(viewport_size.y))
	var player_color := VisualStyle.PLAYER_BODY if not _is_player_flashing() else VisualStyle.PLAYER_GLOW
	draw_circle(car_center, 39.0, Color(player_color, 0.16))
	draw_colored_polygon(PackedVector2Array([car_center + Vector2(0.0, -48.0), car_center + Vector2(29.0, 32.0), car_center + Vector2(-29.0, 32.0)]), player_color)
	draw_colored_polygon(PackedVector2Array([car_center + Vector2(0.0, -27.0), car_center + Vector2(15.0, 3.0), car_center + Vector2(-15.0, 3.0)]), Color("0b2a45"))
	draw_rect(Rect2(car_center + Vector2(-22.0, 14.0), Vector2(44.0, 8.0)), VisualStyle.PLAYER_GLOW)
	draw_circle(car_center + Vector2(0.0, 27.0), 5.0, VisualStyle.WARNING)
	_draw_sparks()
	draw_set_transform(Vector2.ZERO)

func _draw_sparks() -> void:
	for spark in feedback.sparks:
		var alpha := clampf(float(spark.life) * 2.0, 0.0, 1.0)
		draw_circle(spark.position, 3.0, Color(VisualStyle.WARNING, alpha))

func _draw_lane_event(road_left: float, viewport_height: float) -> void:
	var blocked_lane := traffic.lane_events.blocked_lane()
	if blocked_lane < 0:
		return
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	var lane_left := road_left + lane_width * blocked_lane
	var is_warning := traffic.lane_events.state == LaneEventDirector.State.WARNING
	var overlay_color := Color(VisualStyle.WARNING, 0.13 if is_warning else 0.28)
	draw_rect(Rect2(lane_left, 0.0, lane_width, viewport_height), overlay_color, true)
	var marker_y := 24.0
	while marker_y < viewport_height:
		draw_line(Vector2(lane_left + 18.0, marker_y), Vector2(lane_left + lane_width - 18.0, marker_y + 42.0), VisualStyle.WARNING, 5.0)
		marker_y += 120.0

func _draw_traffic(road_left: float) -> void:
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	for vehicle in traffic.vehicles:
		var car_center := Vector2(road_left + lane_width * (vehicle.lane_position + 0.5), vehicle.y)
		var body_color := _traffic_color(vehicle.kind)
		draw_circle(car_center, maxf(vehicle.half_width, vehicle.half_length * 0.55), Color(body_color, 0.13))
		draw_rect(Rect2(car_center + Vector2(-vehicle.half_width, -vehicle.half_length), Vector2(vehicle.half_width * 2.0, vehicle.half_length * 2.0)), body_color, true)
		var cabin_y := -vehicle.half_length + 16.0
		draw_rect(Rect2(car_center + Vector2(-vehicle.half_width + 9.0, cabin_y), Vector2((vehicle.half_width - 9.0) * 2.0, 28.0)), Color("111d2d"), true)
		draw_rect(Rect2(car_center + Vector2(-vehicle.half_width + 5.0, vehicle.half_length - 19.0), Vector2((vehicle.half_width - 5.0) * 2.0, 7.0)), Color("ffdbd2"), true)
		if vehicle.kind == TrafficDirector.Kind.SIGNAL_CHANGE and vehicle.warning_remaining > 0.0:
			var direction := signf(vehicle.target_lane - vehicle.lane_position)
			draw_colored_polygon(PackedVector2Array([car_center + Vector2(18.0 * direction, -35.0), car_center + Vector2(4.0 * direction, -42.0), car_center + Vector2(4.0 * direction, -28.0)]), VisualStyle.WARNING)
		if vehicle.kind == TrafficDirector.Kind.FAST_OVERTAKE and vehicle.overtake_warning_remaining > 0.0:
			var warning_y := TrafficDirector.fast_warning_y(vehicle.y)
			draw_line(Vector2(car_center.x - 22.0, warning_y), Vector2(car_center.x + 22.0, warning_y), VisualStyle.FAST_BODY, 5.0)

func _draw_fuel_pickups(road_left: float) -> void:
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	for pickup in fuel_pickups:
		var center := Vector2(road_left + lane_width * (pickup.lane + 0.5), pickup.y)
		draw_circle(center, 28.0, Color(VisualStyle.FUEL_GLOW, 0.20))
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -22), center + Vector2(20, 0), center + Vector2(0, 22), center + Vector2(-20, 0)]), VisualStyle.FUEL_GLOW)
		draw_string(ThemeDB.fallback_font, center + Vector2(-6, 6), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("063526"))

func _traffic_color(kind: int) -> Color:
	match kind:
		TrafficDirector.Kind.STEADY_SLOW: return VisualStyle.SLOW_BODY
		TrafficDirector.Kind.SIGNAL_CHANGE: return VisualStyle.SIGNAL_BODY
		TrafficDirector.Kind.TRUCK: return VisualStyle.TRUCK_BODY
		_: return VisualStyle.FAST_BODY

func _update_fuel_pickups(delta: float) -> void:
	var blocked_lanes := traffic.blocked_lanes_near(FuelSpawnDirector.PICKUP_SPAWN_Y, GameConfig.FUEL_SPAWN_SAFETY_DISTANCE)
	var spawned_pickup := fuel_spawn_director.tick(delta, blocked_lanes, _player_lane())
	if spawned_pickup != null:
		fuel_pickups.append(spawned_pickup)
	var viewport_size := get_viewport_rect().size
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	var player_center := Vector2(viewport_size.x * 0.5 + drive.lateral_position, TrackGeometry.player_y(viewport_size.y))
	var active: Array[FuelPickup] = []
	for pickup in fuel_pickups:
		pickup.y += drive.speed * GameConfig.ROAD_SCROLL_MULTIPLIER * delta
		var pickup_x := viewport_size.x * 0.5 - GameConfig.ROAD_HALF_WIDTH + lane_width * (pickup.lane + 0.5)
		if absf(pickup_x - player_center.x) < 48.0 and absf(pickup.y - player_center.y) < 62.0:
			run.add_fuel(GameConfig.FUEL_PICKUP_AMOUNT)
			_play_effect(pickup_audio)
			continue
		if pickup.y < viewport_size.y + 60.0:
			active.append(pickup)
	fuel_pickups = active

func _check_collisions() -> void:
	var viewport_size := get_viewport_rect().size
	var center_x := viewport_size.x * 0.5
	var road_left := center_x - GameConfig.ROAD_HALF_WIDTH
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	var player_center := Vector2(center_x + drive.lateral_position, TrackGeometry.player_y(viewport_size.y))
	for vehicle in traffic.vehicles:
		var traffic_center := Vector2(road_left + lane_width * (vehicle.lane_position + 0.5), vehicle.y)
		if absf(traffic_center.x - player_center.x) < traffic.collision_lateral_distance_for(vehicle) and absf(traffic_center.y - player_center.y) < traffic.collision_distance_for(vehicle):
			var impact_speed := drive.speed
			var outcome := collision.try_collide(drive.speed)
			if outcome.hit:
				drive.speed = outcome.speed
				vehicle.y = player_center.y + 130.0
				vehicle.collided_with_player = true
				run.break_combo()
				feedback.spawn_collision(player_center, impact_speed, GameConfig.MAX_SPEED)
				var shake := feedback.shake_magnitude_for_speed(impact_speed, GameConfig.MAX_SPEED)
				screen_shake = Vector2(shake, -shake * 0.7)
				_play_effect(collision_audio)

func _toggle_audio_mute() -> void:
	audio_muted = not audio_muted
	if audio_muted:
		_stop_run_audio()
	_update_settings_labels()
	_save_preferences()

func _toggle_fullscreen() -> void:
	fullscreen_enabled = not fullscreen_enabled
	_apply_window_mode()
	_save_preferences()

func _apply_window_mode() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_update_settings_labels()

func _make_audio_player(stream: AudioStream, base_volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = base_volume_db
	add_child(player)
	return player

func _update_audio(delta: float, accelerate_input: float) -> void:
	warning_cooldown = maxf(0.0, warning_cooldown - delta)
	if not audio_muted and audio_volume > 0.0:
		if not engine_audio.playing:
			engine_audio.play()
		engine_audio.pitch_scale = lerpf(0.78, 1.32, drive.speed / GameConfig.MAX_SPEED)
		engine_audio.volume_db = SoundEffects.volume_db(audio_volume) - 18.0
	else:
		engine_audio.stop()
	if accelerate_input > 0.0 and Input.is_action_just_pressed("accelerate"):
		_play_effect(acceleration_audio)
	if warning_cooldown <= 0.0:
		for vehicle in traffic.vehicles:
			if vehicle.kind == TrafficDirector.Kind.SIGNAL_CHANGE and vehicle.warning_remaining > 0.68:
				_play_effect(warning_audio)
				warning_cooldown = 0.55
				break

func _play_effect(player: AudioStreamPlayer) -> void:
	if audio_muted or audio_volume <= 0.0:
		return
	player.volume_db = SoundEffects.volume_db(audio_volume) - 10.0
	player.play()

func _stop_run_audio() -> void:
	collision_audio.stop()
	engine_audio.stop()
	acceleration_audio.stop()
	pickup_audio.stop()
	warning_audio.stop()

func _award_pass_events() -> void:
	var viewport_size := get_viewport_rect().size
	var player_y := TrackGeometry.player_y(viewport_size.y)
	var player_x := viewport_size.x * 0.5 + drive.lateral_position
	var road_left := viewport_size.x * 0.5 - GameConfig.ROAD_HALF_WIDTH
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	for vehicle in traffic.vehicles:
		var vehicle_x := road_left + lane_width * (vehicle.lane_position + 0.5)
		var event := PassEventResolver.observe(vehicle, vehicle.kind, player_y, player_x, vehicle_x)
		if event.overtake:
			var pass_score := GameConfig.OVERTAKE_SCORE + (GameConfig.NEAR_MISS_SCORE if event.near_miss else 0)
			run.award_pass(pass_score, event.near_miss)

static func is_eligible_overtake(kind: int, was_ahead: bool, collided_with_player: bool) -> bool:
	return kind != TrafficDirector.Kind.FAST_OVERTAKE and was_ahead and not collided_with_player

func _is_player_flashing() -> bool:
	return collision.invulnerability_remaining > 0.0 and int(collision.invulnerability_remaining * 14.0) % 2 == 0

func _reset_run(run_seed_override: int = -1) -> void:
	current_run_seed = run_seed_override if run_seed_override >= 0 else run_seed_sequence.next_seed()
	drive.reset()
	road_scroll = 0.0
	traffic.reset(current_run_seed)
	collision = CollisionResponder.new(GameConfig.COLLISION_SPEED_PENALTY, GameConfig.COLLISION_INVULNERABILITY_SECONDS)
	screen_shake = Vector2.ZERO
	collision_audio.stop()
	_stop_run_audio()
	run.reset()
	_apply_difficulty_profile()
	fuel_pickups.clear()
	fuel_spawn_director.reset(_fuel_seed_for_run(current_run_seed))
	feedback.reset()
	result_persisted = false
	is_new_record = false

func _restart_run() -> void:
	_reset_run()
	run.begin_countdown()

func _start_new_run() -> void:
	_reset_run()
	run.begin_countdown()
	_update_hud()

func _show_settings() -> void:
	submenu_return = "title"
	title_screen.visible = false
	controls_screen.visible = false
	settings_screen.visible = true
	_update_settings_labels()
	settings_mute_button.grab_focus()

func _show_controls() -> void:
	submenu_return = "title"
	title_screen.visible = false
	settings_screen.visible = false
	controls_screen.visible = true
	$CanvasLayer/ControlsScreen/Center/Card/Content/BackButton.grab_focus()

func _close_submenu() -> void:
	settings_screen.visible = false
	controls_screen.visible = false
	if submenu_return == "pause" and run.phase == RunState.Phase.PAUSED:
		pause_screen.visible = true
		$CanvasLayer/PauseScreen/Center/Card/Content/ResumeButton.grab_focus()
	else:
		title_screen.visible = true
		start_button.grab_focus()

func _show_pause_settings() -> void:
	submenu_return = "pause"
	pause_screen.visible = false
	settings_screen.visible = true
	_update_settings_labels()
	settings_mute_button.grab_focus()

func _pause_run() -> void:
	if run.phase != RunState.Phase.RUNNING:
		return
	run.toggle_pause()
	_stop_run_audio()
	_update_hud()
	$CanvasLayer/PauseScreen/Center/Card/Content/ResumeButton.grab_focus()

func _resume_run() -> void:
	if run.phase != RunState.Phase.PAUSED:
		return
	pause_screen.visible = false
	run.toggle_pause()
	_update_hud()

func _request_restart() -> void:
	_show_confirmation("restart", "当前比赛进度将丢失，确定重新开始？")

func _request_title() -> void:
	_show_confirmation("title", "当前比赛进度将丢失，确定返回标题？")

func _show_confirmation(action: String, prompt: String) -> void:
	if run.phase != RunState.Phase.PAUSED:
		return
	destructive_action = action
	pause_screen.visible = false
	confirmation_screen.visible = true
	$CanvasLayer/ConfirmationScreen/Center/Card/Content/Prompt.text = prompt
	$CanvasLayer/ConfirmationScreen/Center/Card/Content/CancelButton.grab_focus()

func _cancel_confirmation() -> void:
	destructive_action = ""
	confirmation_screen.visible = false
	pause_screen.visible = run.phase == RunState.Phase.PAUSED
	if pause_screen.visible:
		$CanvasLayer/PauseScreen/Center/Card/Content/ResumeButton.grab_focus()

func _confirm_destructive_action() -> void:
	var action := destructive_action
	destructive_action = ""
	confirmation_screen.visible = false
	if action == "restart":
		_restart_run()
	elif action == "title":
		_return_to_title()
	_update_hud()

func _replay_run() -> void:
	_restart_run()
	_update_hud()

func _return_to_title() -> void:
	_reset_run()
	settings_screen.visible = false
	controls_screen.visible = false
	pause_screen.visible = false
	result_screen.visible = false
	confirmation_screen.visible = false
	title_screen.visible = true
	_update_hud()
	start_button.grab_focus()

func _cycle_difficulty() -> void:
	difficulty_index = (difficulty_index + 1) % DIFFICULTY_NAMES.size()
	difficulty_button.text = "难度：%s" % DIFFICULTY_NAMES[difficulty_index]
	_apply_difficulty_profile()
	_save_preferences()

func _configure_persistence(store: SaveStore, enabled: bool) -> void:
	save_store = store
	persistence_enabled = enabled
	save_data = save_store.load_data() if enabled else SaveStore.default_data()
	_apply_saved_preferences()
	_update_scoreboards()
	_update_hud()

func _apply_saved_preferences() -> void:
	audio_volume = float(save_data.settings.audio_volume)
	audio_muted = bool(save_data.settings.audio_muted)
	difficulty_index = int(save_data.settings.difficulty)
	fullscreen_enabled = bool(save_data.settings.fullscreen)
	difficulty_button.text = "难度：%s" % DIFFICULTY_NAMES[difficulty_index]
	_apply_difficulty_profile()
	_apply_window_mode()
	if audio_muted:
		_stop_run_audio()

func _apply_difficulty_profile() -> void:
	var profile := DifficultyProfile.for_index(difficulty_index)
	run.configure_difficulty(profile)
	traffic.configure_difficulty(profile)

func _save_preferences() -> void:
	if save_data.is_empty():
		return
	save_data.settings.audio_volume = audio_volume
	save_data.settings.audio_muted = audio_muted
	save_data.settings.difficulty = difficulty_index
	save_data.settings.fullscreen = fullscreen_enabled
	if persistence_enabled:
		save_store.save_data(save_data)
	_update_settings_labels()

func _update_settings_labels() -> void:
	if settings_volume_label == null:
		return
	settings_volume_label.text = "主音量：%d%%（- / + 调整）" % roundi(audio_volume * 100.0)
	settings_mute_button.text = "静音：%s" % ("开" if audio_muted else "关")
	settings_fullscreen_button.text = "显示模式：%s" % ("全屏" if fullscreen_enabled else "窗口")

func _bind_ui_actions() -> void:
	start_button.pressed.connect(_start_new_run)
	difficulty_button.pressed.connect(_cycle_difficulty)
	$CanvasLayer/TitleScreen/Center/Card/Content/SettingsButton.pressed.connect(_show_settings)
	$CanvasLayer/TitleScreen/Center/Card/Content/ControlsButton.pressed.connect(_show_controls)
	$CanvasLayer/TitleScreen/Center/Card/Content/QuitButton.pressed.connect(get_tree().quit)
	settings_mute_button.pressed.connect(_toggle_audio_mute)
	settings_fullscreen_button.pressed.connect(_toggle_fullscreen)
	$CanvasLayer/SettingsScreen/Center/Card/Content/BackButton.pressed.connect(_close_submenu)
	$CanvasLayer/ControlsScreen/Center/Card/Content/BackButton.pressed.connect(_close_submenu)
	$CanvasLayer/PauseScreen/Center/Card/Content/ResumeButton.pressed.connect(_resume_run)
	$CanvasLayer/PauseScreen/Center/Card/Content/RestartButton.pressed.connect(_request_restart)
	$CanvasLayer/PauseScreen/Center/Card/Content/SettingsButton.pressed.connect(_show_pause_settings)
	$CanvasLayer/PauseScreen/Center/Card/Content/TitleButton.pressed.connect(_request_title)
	$CanvasLayer/ResultScreen/Center/Card/Content/ReplayButton.pressed.connect(_replay_run)
	$CanvasLayer/ResultScreen/Center/Card/Content/TitleButton.pressed.connect(_return_to_title)
	$CanvasLayer/ConfirmationScreen/Center/Card/Content/ConfirmButton.pressed.connect(_confirm_destructive_action)
	$CanvasLayer/ConfirmationScreen/Center/Card/Content/CancelButton.pressed.connect(_cancel_confirmation)

func _player_lane() -> int:
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	return clampi(int(floor((drive.lateral_position + GameConfig.ROAD_HALF_WIDTH) / lane_width)), 0, GameConfig.ROAD_LANE_COUNT - 1)

func _update_hud() -> void:
	var scale := VisualStyle.hud_scale_for_width(get_viewport_rect().size.x)
	speed_label.text = "SPEED  %03d km/h" % roundi(drive.speed * 0.42)
	position_label.text = ""
	score_label.text = "SCORE  %06d    DIST  %05dm" % [run.score, roundi(run.distance)]
	var fuel_warning := feedback.low_fuel_text() if feedback.is_fuel_warning_visible() else ""
	fuel_label.text = "FUEL  %03d%%  %s" % [roundi(run.fuel), fuel_warning]
	fuel_label.modulate = Color("ff6b6b") if feedback.low_fuel_tier == GameFeedback.FuelTier.CRITICAL else (Color("ffd75a") if feedback.low_fuel_tier == GameFeedback.FuelTier.LOW else Color.WHITE)
	var combo_time := "%.1fs" % run.combo.remaining_seconds if run.combo.event_count > 0 else "READY"
	run_status_label.text = "STAGE %d  |  COMBO x%d %s  |  %s" % [run.difficulty_stage + 1, run.combo.multiplier, combo_time, _phase_text()]
	controls_hint_label.text = "W/S 速度  A/D 转向  Space 暂停  M 静音  |  SEED %d" % current_run_seed
	for label in [speed_label, controls_hint_label, score_label, fuel_label, run_status_label]:
		label.scale = Vector2.ONE * scale
	var result_was_visible := result_screen.visible
	race_hud.visible = run.phase == RunState.Phase.RUNNING or run.phase == RunState.Phase.PAUSED
	countdown_screen.visible = run.phase == RunState.Phase.COUNTDOWN
	var lane_event_text := _lane_event_text()
	feedback_banner.visible = run.phase == RunState.Phase.RUNNING and (not lane_event_text.is_empty() or not feedback.stage_banner_text.is_empty())
	feedback_banner.text = lane_event_text if not lane_event_text.is_empty() else feedback.stage_banner_text
	if countdown_screen.visible:
		countdown_label.text = str(maxi(1, ceili(run.countdown_remaining)))
	pause_screen.visible = run.phase == RunState.Phase.PAUSED and not confirmation_screen.visible and not settings_screen.visible
	result_screen.visible = run.phase == RunState.Phase.GAME_OVER or run.phase == RunState.Phase.RUN_CLEAR
	if result_screen.visible:
		_persist_result_once()
		_update_result_labels()
		if not result_was_visible:
			$CanvasLayer/ResultScreen/Center/Card/Content/ReplayButton.grab_focus()
	menu_backdrop.visible = run.phase == RunState.Phase.TITLE or result_screen.visible or (settings_screen.visible and submenu_return == "title") or controls_screen.visible
	if run.phase == RunState.Phase.TITLE and not settings_screen.visible and not controls_screen.visible:
		title_screen.visible = true
	elif run.phase != RunState.Phase.TITLE:
		title_screen.visible = false
	overlay_shade.visible = false
	overlay_label.visible = false
	_update_settings_labels()

func _persist_result_once() -> void:
	if result_persisted:
		return
	result_persisted = true
	var outcome := Progression.record_run(save_data, {
		"score": run.score,
		"difficulty": difficulty_index,
		"distance": run.distance,
		"survival": run.elapsed_seconds,
		"overtakes": run.overtakes,
		"near_misses": run.near_misses,
		"stage": run.difficulty_stage + 1,
	}, Time.get_date_string_from_system())
	save_data = outcome.data
	is_new_record = outcome.new_record
	if persistence_enabled:
		save_store.save_data(save_data)
	_update_scoreboards()

func _update_scoreboards() -> void:
	if save_data.is_empty():
		return
	var text := _format_top_scores(save_data.top_scores)
	title_best_scores.text = text
	result_best_scores.text = text

func _format_top_scores(scores: Array) -> String:
	if scores.is_empty():
		return "最高成绩：暂无成绩"
	var lines: Array[String] = ["最高成绩"]
	for index in range(scores.size()):
		var item: Dictionary = scores[index]
		lines.append("%d. %06d  %s  %05dm" % [index + 1, item.score, DIFFICULTY_NAMES[item.difficulty], roundi(item.distance)])
	return "\n".join(lines)

func _update_result_labels() -> void:
	var cleared := run.phase == RunState.Phase.RUN_CLEAR
	result_heading.text = "赛程完成" if cleared else "比赛结束"
	new_record_label.visible = is_new_record
	var reason := "抵达终点" if cleared else "燃油耗尽"
	result_summary.text = "%s\n\n得分  %06d\n距离  %05dm\n超车  %d    近失  %d\n到达赛段  %d\n局种子  %d" % [reason, run.score, roundi(run.distance), run.overtakes, run.near_misses, run.difficulty_stage + 1, current_run_seed]

func _phase_text() -> String:
	match run.phase:
		RunState.Phase.TITLE: return "TITLE"
		RunState.Phase.COUNTDOWN: return "COUNTDOWN"
		RunState.Phase.RUNNING: return "RUNNING"
		RunState.Phase.PAUSED: return "PAUSED"
		RunState.Phase.RUN_CLEAR: return "CLEAR"
		_: return "GAME OVER"

func _lane_event_text() -> String:
	var blocked_lane := traffic.lane_events.blocked_lane()
	if blocked_lane < 0:
		return ""
	if traffic.lane_events.state == LaneEventDirector.State.WARNING:
		return "%d 号车道即将封闭" % (blocked_lane + 1)
	return "%d 号车道封闭" % (blocked_lane + 1)

func _overlay_text() -> String:
	match run.phase:
		RunState.Phase.TITLE: return "NEON COAST RUSH"
		RunState.Phase.COUNTDOWN: return str(maxi(1, ceili(run.countdown_remaining)))
		RunState.Phase.PAUSED: return "PAUSED\n\n[ SPACE ]  RESUME     [ R ]  RESTART"
		RunState.Phase.GAME_OVER: return "OUT OF FUEL\n\nSCORE  %06d     DIST  %05dm" % [run.score, roundi(run.distance)]
		_: return ""

func _ensure_input_actions() -> void:
	_register_action("accelerate", [KEY_UP, KEY_W])
	_register_action("brake", [KEY_DOWN, KEY_S])
	_register_action("steer_left", [KEY_LEFT, KEY_A])
	_register_action("steer_right", [KEY_RIGHT, KEY_D])
	_register_action("pause_game", [KEY_SPACE], true)
	_register_action("toggle_mute", [KEY_M])
	_register_action("toggle_fullscreen", [KEY_F11])
	_register_action("volume_down", [KEY_MINUS])
	_register_action("volume_up", [KEY_EQUAL])

func _register_action(action: StringName, keys: Array[int], replace_existing := false) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	elif replace_existing:
		InputMap.action_erase_events(action)
	for keycode in keys:
		var event := InputEventKey.new()
		event.keycode = keycode
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)

static func advance_road_scroll(current_offset: float, speed: float, delta: float, repeat_distance: float) -> float:
	return fmod(current_offset + speed * GameConfig.ROAD_SCROLL_MULTIPLIER * delta, repeat_distance)

static func get_dash_start_y(scroll_offset: float, repeat_distance: float) -> float:
	return scroll_offset - repeat_distance

static func _fuel_seed_for_run(run_seed: int) -> int:
	return run_seed ^ 1597463007
