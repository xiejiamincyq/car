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
const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")
const TrackRuntimeProfile = preload("res://scripts/track_runtime_profile.gd")
const PlayerVehicleProfile = preload("res://scripts/player_vehicle_profile.gd")
const PassEventResolver = preload("res://scripts/pass_event_resolver.gd")
const GameFeedback = preload("res://scripts/game_feedback.gd")
const LaneEventDirector = preload("res://scripts/lane_event_director.gd")
const DifficultyProfile = preload("res://scripts/difficulty_profile.gd")
const GameText = preload("res://scripts/game_text.gd")
const VehicleVisualAnimation = preload("res://scripts/vehicle_visual_animation.gd")
const EnvironmentScroller = preload("res://scripts/environment_scroller.gd")
const RaceEffectRenderer = preload("res://scripts/race_effect_renderer.gd")
const TRAFFIC_SEDAN_TEXTURE: Texture2D = preload("res://assets/vehicles/traffic_sedan.png")
const TRAFFIC_VAN_TEXTURE: Texture2D = preload("res://assets/vehicles/traffic_van.png")
const TRAFFIC_HATCHBACK_TEXTURE: Texture2D = preload("res://assets/vehicles/traffic_hatchback.png")
const TRAFFIC_SPORTS_TEXTURE: Texture2D = preload("res://assets/vehicles/traffic_sports.png")
const TRAFFIC_TRUCK_TEXTURE: Texture2D = preload("res://assets/vehicles/traffic_truck.png")
const FUEL_PICKUP_TEXTURE: Texture2D = preload("res://assets/pickups/fuel_pickup.png")
const COAST_LEFT_TEXTURE: Texture2D = preload("res://assets/environment_sequences/neon_coast/left_00.png")
const COAST_RIGHT_TEXTURE: Texture2D = preload("res://assets/environment_sequences/neon_coast/right_00.png")
const HUD_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/hud_frame.png")
const EVENT_PLATE_TEXTURE: Texture2D = preload("res://assets/ui/event_plate.png")
const ROAD_BARRIER_TEXTURE: Texture2D = preload("res://assets/ui/road_barrier.png")
const RESULT_EMBLEM_TEXTURE: Texture2D = preload("res://assets/ui/result_emblem.png")
const FINISH_BURST_TEXTURE: Texture2D = preload("res://assets/effects/finish_burst.png")

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
var ui_audio: AudioStreamPlayer
var event_audio: AudioStreamPlayer
var cue_catalog: Dictionary
var last_audio_cue := ""
var last_countdown_value := -1
var last_fuel_audio_tier := GameFeedback.FuelTier.NORMAL
var last_lane_audio_state := LaneEventDirector.State.IDLE
var audio_volume := 0.65
var audio_muted := false
var fullscreen_enabled := false
var warning_cooldown := 0.0
var fuel_pickups: Array[FuelPickup] = []
var fuel_spawn_director: FuelSpawnDirector
var run_seed_sequence: RunSeedSequence
var current_run_seed: int = 0
var difficulty_index := 1
var language_preference := GameText.LANGUAGE_SYSTEM
var language := GameText.LANGUAGE_EN
var high_contrast_enabled := false
var reduced_flashing_enabled := false
var screen_shake_enabled := true
var visual_animation_time := 0.0
var acceleration_visual_strength := 0.0
var brake_visual_strength := 0.0
var steering_visual_strength := 0.0
var collision_visual_remaining := 0.0
var collision_visual_direction := 1.0
var current_vehicle: Dictionary = PlayerVehicleProfile.resolve(&"pulse_gt")
var current_player_texture: Texture2D = PlayerVehicleProfile.texture_for(current_vehicle)
var current_track: Dictionary = TrackRuntimeProfile.resolve(&"neon_coast")
var current_environment_left: Array[Texture2D] = [COAST_LEFT_TEXTURE]
var current_environment_right: Array[Texture2D] = [COAST_RIGHT_TEXTURE]

var speed_label: Label
var position_label: Label
var controls_hint_label: Label
var score_label: Label
var fuel_label: Label
var run_status_label: Label
var fuel_gauge: ProgressBar
var progress_gauge: ProgressBar
var event_plate: TextureRect
var overlay_label: Label
var menu_backdrop: TextureRect
var overlay_shade: ColorRect
var race_hud: Control
var title_screen: Control
var tour_map_screen
var vehicle_select_screen
var settings_screen: Control
var controls_screen: Control
var countdown_screen: Control
var countdown_label: Label
var start_button: Button
var difficulty_button: Button
var settings_volume_label: Label
var settings_mute_button: Button
var settings_fullscreen_button: Button
var settings_language_button: Button
var settings_high_contrast_button: Button
var settings_reduced_flashing_button: Button
var settings_screen_shake_button: Button
var pause_screen: Control
var result_screen: Control
var result_heading: Label
var result_summary: Label
var result_emblem: TextureRect
var finish_burst: TextureRect
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_input_actions()
	var sequence_seed := hash("%s:%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	run_seed_sequence = RunSeedSequence.new(sequence_seed)
	current_run_seed = run_seed_sequence.next_seed()
	drive = DriveController.new(GameConfig.START_SPEED, GameConfig.MAX_SPEED, GameConfig.ACCELERATION, GameConfig.BRAKING, GameConfig.STEERING_SPEED, GameConfig.ROAD_HALF_WIDTH, 30.0)
	traffic = TrafficDirector.new(current_run_seed, GameConfig.ROAD_LANE_COUNT, GameConfig.MIN_SPAWN_DISTANCE, GameConfig.MIN_TRAFFIC_GAP)
	fuel_spawn_director = FuelSpawnDirector.new(_fuel_seed_for_run(current_run_seed), GameConfig.ROAD_LANE_COUNT, GameConfig.FUEL_PICKUP_INTERVAL)
	collision = CollisionResponder.new(GameConfig.COLLISION_SPEED_PENALTY, GameConfig.COLLISION_INVULNERABILITY_SECONDS)
	run = RunState.new(GameConfig.MAX_FUEL, GameConfig.FUEL_DRAIN_PER_SECOND, GameConfig.FUEL_GRACE_SECONDS)
	run.configure_track(current_track)
	traffic.configure_track(current_track)
	feedback = GameFeedback.new(GameConfig.SPARK_MAX_COUNT)
	collision_audio = AudioStreamPlayer.new()
	collision_audio.stream = CollisionSound.create_stream()
	collision_audio.bus = &"Effects"
	collision_audio.volume_db = -10.0
	add_child(collision_audio)
	engine_audio = _make_audio_player(SoundEffects.create_engine_loop(), -18.0)
	acceleration_audio = _make_audio_player(SoundEffects.create_acceleration(), -12.0)
	pickup_audio = _make_audio_player(SoundEffects.create_pickup(), -10.0)
	warning_audio = _make_audio_player(SoundEffects.create_warning(), -13.0)
	cue_catalog = SoundEffects.create_cue_catalog()
	ui_audio = _make_audio_player(cue_catalog.ui_move, -14.0)
	event_audio = _make_audio_player(cue_catalog.near_miss, -12.0)
	race_hud = $CanvasLayer/RaceHUD
	speed_label = $CanvasLayer/RaceHUD/Rows/Speed
	position_label = $CanvasLayer/RaceHUD/Rows/Position
	controls_hint_label = $CanvasLayer/RaceHUD/Rows/ControlsHint
	score_label = $CanvasLayer/RaceHUD/Rows/Score
	fuel_label = $CanvasLayer/RaceHUD/Rows/Fuel
	run_status_label = $CanvasLayer/RaceHUD/Rows/RunStatus
	fuel_gauge = $CanvasLayer/RaceHUD/Rows/FuelGauge
	progress_gauge = $CanvasLayer/RaceHUD/Rows/ProgressGauge
	event_plate = $CanvasLayer/EventPlate
	fuel_gauge.max_value = GameConfig.MAX_FUEL
	overlay_label = $CanvasLayer/Overlay
	menu_backdrop = $CanvasLayer/MenuBackdrop
	overlay_shade = $CanvasLayer/OverlayShade
	title_screen = $CanvasLayer/TitleScreen
	tour_map_screen = $CanvasLayer/TourMapScreen
	vehicle_select_screen = $CanvasLayer/VehicleSelectScreen
	settings_screen = $CanvasLayer/SettingsScreen
	controls_screen = $CanvasLayer/ControlsScreen
	countdown_screen = $CanvasLayer/CountdownScreen
	countdown_label = $CanvasLayer/CountdownScreen/Label
	start_button = $CanvasLayer/TitleScreen/Center/Card/Content/StartButton
	difficulty_button = $CanvasLayer/TitleScreen/Center/Card/Content/DifficultyButton
	settings_volume_label = $CanvasLayer/SettingsScreen/Center/Card/Content/Volume
	settings_mute_button = $CanvasLayer/SettingsScreen/Center/Card/Content/MuteButton
	settings_fullscreen_button = $CanvasLayer/SettingsScreen/Center/Card/Content/FullscreenButton
	settings_language_button = $CanvasLayer/SettingsScreen/Center/Card/Content/LanguageButton
	settings_high_contrast_button = $CanvasLayer/SettingsScreen/Center/Card/Content/HighContrastButton
	settings_reduced_flashing_button = $CanvasLayer/SettingsScreen/Center/Card/Content/ReducedFlashingButton
	settings_screen_shake_button = $CanvasLayer/SettingsScreen/Center/Card/Content/ScreenShakeButton
	pause_screen = $CanvasLayer/PauseScreen
	result_screen = $CanvasLayer/ResultScreen
	result_heading = $CanvasLayer/ResultScreen/Center/Card/Content/Heading
	result_summary = $CanvasLayer/ResultScreen/Center/Card/Content/Summary
	result_emblem = $CanvasLayer/ResultScreen/Center/Card/Content/ResultEmblem
	finish_burst = $CanvasLayer/ResultScreen/FinishBurst
	confirmation_screen = $CanvasLayer/ConfirmationScreen
	title_best_scores = $CanvasLayer/TitleScreen/Center/Card/Content/BestScores
	result_best_scores = $CanvasLayer/ResultScreen/Center/Card/Content/BestScores
	new_record_label = $CanvasLayer/ResultScreen/Center/Card/Content/NewRecord
	feedback_banner = $CanvasLayer/FeedbackBanner
	_bind_ui_cues()
	_bind_ui_actions()
	_configure_persistence(SaveStore.new(), get_tree().current_scene == self)
	start_button.grab_focus()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause_for_focus_loss()

func _exit_tree() -> void:
	if ui_audio != null:
		ui_audio.stop()
		ui_audio.stream = null
	if event_audio != null:
		event_audio.stop()
		event_audio.stream = null
	if not cue_catalog.is_empty():
		cue_catalog.clear()

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
	if Input.is_action_just_pressed("restart_run"):
		if _handle_restart_shortcut():
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
		acceleration_visual_strength = 0.0
		brake_visual_strength = 0.0
		steering_visual_strength = move_toward(steering_visual_strength, 0.0, delta * 7.0)
		run.tick(delta, 0.0, drive.max_speed)
		if run.phase == RunState.Phase.RUNNING:
			last_countdown_value = 0
			_play_cue("countdown_go")
		else:
			_update_countdown_cue()
		_update_hud()
		queue_redraw()
		return
	if run.phase != RunState.Phase.RUNNING:
		acceleration_visual_strength = 0.0
		brake_visual_strength = 0.0
		steering_visual_strength = move_toward(steering_visual_strength, 0.0, delta * 7.0)
		_stop_driving_audio()
		if run.phase == RunState.Phase.RUN_CLEAR:
			visual_animation_time += delta
			feedback.tick(delta, run.fuel, run.difficulty_stage)
		else:
			event_audio.stop()
		_update_hud()
		queue_redraw()
		return
	var accelerate_input := Input.get_action_strength("accelerate")
	var brake_input := Input.get_action_strength("brake")
	var steering_input := Input.get_axis("steer_left", "steer_right")
	drive.step(delta, accelerate_input, brake_input, steering_input)
	visual_animation_time += delta
	acceleration_visual_strength = move_toward(acceleration_visual_strength, accelerate_input, delta * 5.0)
	brake_visual_strength = move_toward(brake_visual_strength, brake_input, delta * 8.0)
	steering_visual_strength = move_toward(steering_visual_strength, steering_input, delta * 7.0)
	collision_visual_remaining = maxf(0.0, collision_visual_remaining - delta)
	road_scroll = advance_road_scroll(road_scroll, drive.speed, delta, ROAD_MARK_REPEAT_DISTANCE)
	var phase_before_tick := run.phase
	run.tick(delta, drive.speed, drive.max_speed, accelerate_input)
	feedback.tick(delta, run.fuel, run.difficulty_stage)
	_update_low_fuel_cue()
	if run.last_checkpoints_crossed > 0:
		feedback.announce_checkpoint(run.difficulty_stage, GameConfig.CHECKPOINT_FUEL_REWARD * run.last_checkpoints_crossed)
		_play_cue("checkpoint")
	if run.phase != RunState.Phase.RUNNING:
		_stop_run_audio()
		if phase_before_tick == RunState.Phase.RUNNING and run.phase == RunState.Phase.RUN_CLEAR:
			feedback.start_finish()
			_play_cue("run_clear")
		_update_hud()
		queue_redraw()
		return
	traffic.set_difficulty_stage(run.difficulty_stage)
	traffic.set_viewport_height(get_viewport_rect().size.y)
	traffic.set_spawn_exclusion_zones(_fuel_spawn_exclusion_zones())
	traffic.tick(delta, drive.speed, _player_lane())
	_update_lane_event_cue()
	_enforce_lane_closure()
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
	var ocean_color := VisualStyle.HIGH_CONTRAST_OCEAN if high_contrast_enabled else VisualStyle.OCEAN
	var shoulder_color := VisualStyle.HIGH_CONTRAST_SHOULDER if high_contrast_enabled else VisualStyle.SHOULDER
	var edge_color := VisualStyle.HIGH_CONTRAST_EDGE if high_contrast_enabled else VisualStyle.EDGE_NEON
	var lane_color := VisualStyle.HIGH_CONTRAST_LANE if high_contrast_enabled else VisualStyle.LANE_MARK
	draw_rect(Rect2(Vector2.ZERO, viewport_size), ocean_color)
	_draw_track_environment(road_left, road_right, viewport_size)
	draw_rect(Rect2(road_left - 30.0, 0.0, GameConfig.ROAD_HALF_WIDTH * 2.0 + 60.0, viewport_size.y), shoulder_color)
	var road_color := VisualStyle.road_color_for_transition(feedback.previous_stage, feedback.current_stage, feedback.stage_transition_mix, high_contrast_enabled)
	draw_rect(Rect2(road_left, 0.0, GameConfig.ROAD_HALF_WIDTH * 2.0, viewport_size.y), road_color)
	RaceEffectRenderer.draw_speed_lines(self, viewport_size, drive.speed, drive.max_speed, visual_animation_time)
	draw_line(Vector2(road_left, 0.0), Vector2(road_left, viewport_size.y), edge_color, 8.0)
	draw_line(Vector2(road_right, 0.0), Vector2(road_right, viewport_size.y), edge_color, 8.0)
	for lane_index in range(1, GameConfig.ROAD_LANE_COUNT):
		var lane_x := road_left + GameConfig.ROAD_HALF_WIDTH * 2.0 * lane_index / GameConfig.ROAD_LANE_COUNT
		var dash_y := get_dash_start_y(road_scroll, ROAD_MARK_REPEAT_DISTANCE)
		while dash_y < viewport_size.y:
			draw_rect(Rect2(lane_x - 4.0, dash_y, 8.0, 52.0), lane_color)
			dash_y += ROAD_MARK_REPEAT_DISTANCE
	_draw_lane_event(road_left, viewport_size.y)
	_draw_traffic(road_left)
	_draw_fuel_pickups(road_left)
	RaceEffectRenderer.draw_pass_streaks(self, feedback, _warning_color())
	var car_center := Vector2(center_x + drive.lateral_position, TrackGeometry.player_y(viewport_size.y))
	var player_body := VisualStyle.HIGH_CONTRAST_PLAYER if high_contrast_enabled else VisualStyle.PLAYER_BODY
	var player_glow := VisualStyle.HIGH_CONTRAST_PLAYER_GLOW if high_contrast_enabled else VisualStyle.PLAYER_GLOW
	var player_color := player_body if not _is_player_flashing() else player_glow
	draw_circle(car_center, 39.0, Color(player_color, 0.16))
	RaceEffectRenderer.draw_acceleration(self, car_center, visual_animation_time, acceleration_visual_strength)
	var fuel_effect_color := VisualStyle.HIGH_CONTRAST_FUEL if high_contrast_enabled else VisualStyle.FUEL_GLOW
	RaceEffectRenderer.draw_pickup_bursts(self, feedback, fuel_effect_color)
	var player_size := VehicleVisualAnimation.corrected_vehicle_size(current_player_texture.get_size())
	var player_rect := Rect2(-player_size * 0.5, player_size)
	var player_modulate := Color(1.0, 1.0, 1.0, 0.45) if _is_player_flashing() else Color.WHITE
	var impact_rotation := VehicleVisualAnimation.collision_rotation(collision_visual_remaining, collision_visual_direction)
	var steering_rotation := VehicleVisualAnimation.steering_rotation(steering_visual_strength)
	var impact_scale := VehicleVisualAnimation.collision_scale(collision_visual_remaining)
	draw_set_transform(screen_shake + car_center, impact_rotation + steering_rotation, impact_scale)
	draw_texture_rect(current_player_texture, player_rect, false, player_modulate)
	draw_set_transform(screen_shake)
	RaceEffectRenderer.draw_braking(self, car_center, visual_animation_time, brake_visual_strength, drive.speed, drive.max_speed)
	RaceEffectRenderer.draw_collision_ring(self, car_center, collision_visual_remaining, _warning_color())
	_draw_sparks()
	draw_set_transform(Vector2.ZERO)

func _draw_track_environment(road_left: float, road_right: float, viewport_size: Vector2) -> void:
	var side_modulate := Color(0.58, 0.58, 0.58, 1.0) if high_contrast_enabled else Color.WHITE
	var left_width := maxf(0.0, road_left - 30.0)
	var right_start := road_right + 30.0
	var right_width := maxf(0.0, viewport_size.x - right_start)
	if current_environment_left.is_empty() or current_environment_right.is_empty():
		return
	var tile_height := float(current_environment_left[0].get_height())
	var finish_distance := run.progression.finish_distance
	var sequence_tiles := EnvironmentScroller.sequence_tiles(run.distance, finish_distance, viewport_size.y, tile_height, current_environment_left.size())
	for tile in sequence_tiles:
		var tile_y := float(tile.y)
		var texture_index := int(tile.index)
		var left_texture := current_environment_left[texture_index]
		var right_texture := current_environment_right[mini(texture_index, current_environment_right.size() - 1)]
		if left_width > 0.0:
			var left_source_width := minf(left_width, float(left_texture.get_width()))
			var left_source := Rect2(left_texture.get_width() - left_source_width, 0.0, left_source_width, tile_height)
			draw_texture_rect_region(left_texture, Rect2(left_width - left_source_width, tile_y, left_source_width, tile_height), left_source, side_modulate)
		if right_width > 0.0:
			var right_source_width := minf(right_width, float(right_texture.get_width()))
			var right_source := Rect2(0.0, 0.0, right_source_width, tile_height)
			draw_texture_rect_region(right_texture, Rect2(right_start, tile_y, right_source_width, tile_height), right_source, side_modulate)

func _draw_sparks() -> void:
	for spark in feedback.sparks:
		var alpha := clampf(float(spark.life) * 2.0, 0.0, 1.0)
		draw_circle(spark.position, 3.0, Color(_warning_color(), alpha))

func _draw_lane_event(road_left: float, viewport_height: float) -> void:
	var blocked_lane := traffic.lane_events.blocked_lane()
	if blocked_lane < 0:
		return
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	var lane_left := road_left + lane_width * blocked_lane
	var is_warning := traffic.lane_events.state == LaneEventDirector.State.WARNING
	var overlay_color := Color(_warning_color(), 0.13 if is_warning else 0.28)
	draw_rect(Rect2(lane_left, 0.0, lane_width, viewport_height), overlay_color, true)
	var marker_y := 24.0
	while marker_y < viewport_height:
		if is_warning:
			draw_line(Vector2(lane_left + 18.0, marker_y), Vector2(lane_left + lane_width - 18.0, marker_y + 42.0), _warning_color(), 5.0)
		else:
			var lane_right := lane_left + lane_width
			var barrier_size := ROAD_BARRIER_TEXTURE.get_size()
			var barrier_position := Vector2(lane_left + (lane_width - barrier_size.x) * 0.5, marker_y - barrier_size.y * 0.5)
			var barrier_rect := Rect2(barrier_position, barrier_size)
			draw_texture_rect(ROAD_BARRIER_TEXTURE, barrier_rect, false)
			draw_line(Vector2(lane_left + 24.0, marker_y - 22.0), Vector2(lane_right - 24.0, marker_y + 22.0), Color("10131c"), 7.0)
			draw_line(Vector2(lane_right - 24.0, marker_y - 22.0), Vector2(lane_left + 24.0, marker_y + 22.0), Color("10131c"), 7.0)
		marker_y += 120.0

func _enforce_lane_closure() -> void:
	var previous_position := drive.lateral_position
	drive.lateral_position = traffic.lane_events.constrain_lateral_position(previous_position, drive.player_half_width, GameConfig.ROAD_HALF_WIDTH)
	if is_equal_approx(previous_position, drive.lateral_position):
		return
	var impact_speed := drive.speed
	var outcome := collision.try_collide(impact_speed)
	if not outcome.hit:
		return
	drive.speed = outcome.speed
	run.break_combo()
	var viewport_size := get_viewport_rect().size
	var player_center := Vector2(viewport_size.x * 0.5 + drive.lateral_position, TrackGeometry.player_y(viewport_size.y))
	feedback.spawn_collision(player_center, impact_speed, drive.max_speed)
	if screen_shake_enabled:
		var shake := feedback.shake_magnitude_for_speed(impact_speed, drive.max_speed)
		screen_shake = Vector2(shake, -shake * 0.7)
	_play_effect(collision_audio)
	_start_collision_animation(signf(previous_position - drive.lateral_position))

func _draw_traffic(road_left: float) -> void:
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	for vehicle in traffic.vehicles:
		var car_center := Vector2(road_left + lane_width * (vehicle.lane_position + 0.5), vehicle.y)
		var body_color := _traffic_color(vehicle.kind)
		draw_circle(car_center, maxf(vehicle.half_width, vehicle.half_length * 0.55), Color(body_color, 0.13))
		var traffic_texture := _traffic_texture_for_kind(vehicle.kind, vehicle.visual_variant)
		var traffic_size := VehicleVisualAnimation.corrected_vehicle_size(traffic_texture.get_size())
		var texture_rect := Rect2(-traffic_size * 0.5, traffic_size)
		draw_set_transform(screen_shake + car_center, VehicleVisualAnimation.traffic_facing_rotation())
		draw_texture_rect(traffic_texture, texture_rect, false)
		draw_set_transform(screen_shake)
		draw_circle(car_center, 12.0, Color(body_color, 0.92))
		draw_string(ThemeDB.fallback_font, car_center + Vector2(-6.0, 7.0), VisualStyle.traffic_marker_for_kind(vehicle.kind), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("081018"))
		if vehicle.lane_change_enabled and vehicle.warning_remaining > 0.0:
			var direction := signf(vehicle.target_lane - vehicle.lane_position)
			draw_colored_polygon(PackedVector2Array([car_center + Vector2(18.0 * direction, -35.0), car_center + Vector2(4.0 * direction, -42.0), car_center + Vector2(4.0 * direction, -28.0)]), _warning_color())
		if vehicle.kind == TrafficDirector.Kind.FAST_OVERTAKE and vehicle.overtake_warning_remaining > 0.0:
			var warning_y := TrafficDirector.fast_warning_y(vehicle.y)
			draw_line(Vector2(car_center.x - 22.0, warning_y), Vector2(car_center.x + 22.0, warning_y), _traffic_color(TrafficDirector.Kind.FAST_OVERTAKE), 5.0)

func _draw_fuel_pickups(road_left: float) -> void:
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	for pickup in fuel_pickups:
		var center := Vector2(road_left + lane_width * (pickup.lane + 0.5), pickup.y)
		var fuel_color := VisualStyle.HIGH_CONTRAST_FUEL if high_contrast_enabled else VisualStyle.FUEL_GLOW
		draw_circle(center, 28.0, Color(fuel_color, 0.20))
		var pickup_rect := Rect2(center - FUEL_PICKUP_TEXTURE.get_size() * 0.5, FUEL_PICKUP_TEXTURE.get_size())
		draw_texture_rect(FUEL_PICKUP_TEXTURE, pickup_rect, false)

func _traffic_texture_for_kind(kind: int, visual_variant: int = 0) -> Texture2D:
	match kind:
		TrafficDirector.Kind.TRUCK:
			return TRAFFIC_TRUCK_TEXTURE
		TrafficDirector.Kind.FAST_OVERTAKE:
			return TRAFFIC_SPORTS_TEXTURE
		TrafficDirector.Kind.SIGNAL_CHANGE:
			return TRAFFIC_HATCHBACK_TEXTURE
		_:
			return TRAFFIC_VAN_TEXTURE if visual_variant % 2 == 1 else TRAFFIC_SEDAN_TEXTURE

func _start_collision_animation(direction: float) -> void:
	collision_visual_remaining = VehicleVisualAnimation.COLLISION_DURATION
	collision_visual_direction = direction if not is_zero_approx(direction) else -collision_visual_direction

func _traffic_color(kind: int) -> Color:
	return VisualStyle.traffic_color(kind, high_contrast_enabled)

func _warning_color() -> Color:
	return VisualStyle.HIGH_CONTRAST_WARNING if high_contrast_enabled else VisualStyle.WARNING

func _event_plate_color() -> Color:
	match traffic.lane_events.state:
		LaneEventDirector.State.CLOSED:
			return Color("ff6565")
		LaneEventDirector.State.WARNING:
			return Color("ffd75a")
		_:
			return Color("42e8df")

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
			feedback.spawn_pickup(player_center)
			_play_effect(pickup_audio)
			continue
		if pickup.y < viewport_size.y + 60.0:
			active.append(pickup)
	fuel_pickups = active

func _fuel_spawn_exclusion_zones() -> Array[Vector2]:
	var zones: Array[Vector2] = []
	for pickup in fuel_pickups:
		zones.append(Vector2(pickup.lane, pickup.y))
	return zones

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
				feedback.spawn_collision(player_center, impact_speed, drive.max_speed)
				if screen_shake_enabled:
					var shake := feedback.shake_magnitude_for_speed(impact_speed, drive.max_speed)
					screen_shake = Vector2(shake, -shake * 0.7)
				_play_effect(collision_audio)
				_start_collision_animation(signf(player_center.x - traffic_center.x))

func _toggle_audio_mute() -> void:
	audio_muted = not audio_muted
	if audio_muted:
		_stop_run_audio()
		ui_audio.stop()
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
	player.bus = &"Effects"
	add_child(player)
	return player

func _update_audio(delta: float, accelerate_input: float) -> void:
	warning_cooldown = maxf(0.0, warning_cooldown - delta)
	if not audio_muted and audio_volume > 0.0:
		if not engine_audio.playing:
			engine_audio.play()
		engine_audio.pitch_scale = lerpf(0.78, 1.32, drive.speed / drive.max_speed)
		engine_audio.volume_db = -18.0
	else:
		engine_audio.stop()
	if accelerate_input > 0.0 and Input.is_action_just_pressed("accelerate"):
		_play_effect(acceleration_audio)
	if warning_cooldown <= 0.0:
		for vehicle in traffic.vehicles:
			if vehicle.lane_change_enabled and vehicle.warning_remaining > 0.68:
				_play_effect(warning_audio)
				warning_cooldown = 0.55
				break

func _play_effect(player: AudioStreamPlayer) -> void:
	if audio_muted or audio_volume <= 0.0:
		return
	player.play()

func _play_cue(cue_name: String, player: AudioStreamPlayer = null) -> void:
	if audio_muted or audio_volume <= 0.0 or not cue_catalog.has(cue_name):
		return
	var channel := event_audio if player == null else player
	channel.stream = cue_catalog[cue_name]
	last_audio_cue = cue_name
	channel.play()

func _play_ui_cue(cue_name: String) -> void:
	_play_cue(cue_name, ui_audio)

func _update_countdown_cue() -> void:
	if run.phase != RunState.Phase.COUNTDOWN:
		return
	var value := maxi(1, ceili(run.countdown_remaining))
	if value != last_countdown_value:
		last_countdown_value = value
		_play_cue("countdown")

func _update_low_fuel_cue() -> void:
	if feedback.low_fuel_tier != last_fuel_audio_tier:
		last_fuel_audio_tier = feedback.low_fuel_tier
		if last_fuel_audio_tier != GameFeedback.FuelTier.NORMAL:
			_play_cue("low_fuel")

func _update_lane_event_cue() -> void:
	var state := traffic.lane_events.state
	if state != last_lane_audio_state:
		last_lane_audio_state = state
		if state == LaneEventDirector.State.WARNING:
			_play_cue("lane_warning")
		elif state == LaneEventDirector.State.CLOSED:
			_play_cue("lane_closed")

func _apply_master_audio_settings() -> void:
	var master_index := AudioServer.get_bus_index("Master")
	if master_index < 0:
		return
	AudioServer.set_bus_volume_db(master_index, SoundEffects.volume_db(audio_volume))
	AudioServer.set_bus_mute(master_index, audio_muted)

func _stop_run_audio() -> void:
	_stop_driving_audio()
	event_audio.stop()

func _stop_driving_audio() -> void:
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
			var multiplier_before := run.combo.multiplier
			run.award_pass(pass_score, event.near_miss)
			feedback.spawn_pass(Vector2(vehicle_x, vehicle.y), event.near_miss)
			if event.near_miss:
				_play_cue("near_miss")
			elif run.combo.multiplier > multiplier_before:
				_play_cue("combo")

static func is_eligible_overtake(kind: int, was_ahead: bool, collided_with_player: bool) -> bool:
	return kind != TrafficDirector.Kind.FAST_OVERTAKE and was_ahead and not collided_with_player

func _is_player_flashing() -> bool:
	return not reduced_flashing_enabled and collision.invulnerability_remaining > 0.0 and int(collision.invulnerability_remaining * 14.0) % 2 == 0

func _reset_run(run_seed_override: int = -1) -> void:
	current_run_seed = run_seed_override if run_seed_override >= 0 else run_seed_sequence.next_seed()
	drive.reset()
	road_scroll = 0.0
	traffic.reset(current_run_seed)
	collision = CollisionResponder.new(float(current_vehicle.collision_speed_penalty), GameConfig.COLLISION_INVULNERABILITY_SECONDS)
	screen_shake = Vector2.ZERO
	visual_animation_time = 0.0
	acceleration_visual_strength = 0.0
	brake_visual_strength = 0.0
	steering_visual_strength = 0.0
	collision_visual_remaining = 0.0
	collision_audio.stop()
	_stop_run_audio()
	run.reset()
	_apply_difficulty_profile()
	fuel_pickups.clear()
	fuel_spawn_director.reset(_fuel_seed_for_run(current_run_seed))
	feedback.reset()
	last_audio_cue = ""
	last_countdown_value = -1
	last_fuel_audio_tier = GameFeedback.FuelTier.NORMAL
	last_lane_audio_state = LaneEventDirector.State.IDLE
	result_persisted = false
	is_new_record = false

func _restart_run() -> void:
	_reset_run()
	run.begin_countdown()

func _start_new_run() -> void:
	_apply_selected_vehicle()
	_apply_selected_track()
	_reset_run()
	run.begin_countdown()
	_update_hud()

func _apply_selected_vehicle() -> void:
	var selected_id := StringName(save_data.get("tour", {}).get("selected_vehicle_id", &"pulse_gt"))
	current_vehicle = PlayerVehicleProfile.resolve(selected_id)
	current_player_texture = _player_texture_for_id(StringName(current_vehicle.id))
	PlayerVehicleProfile.apply_to_drive(current_vehicle, drive)

func _player_texture_for_id(vehicle_id: StringName) -> Texture2D:
	return PlayerVehicleProfile.texture_for(PlayerVehicleProfile.resolve(vehicle_id))

func _apply_selected_track() -> void:
	var selected_id := StringName(save_data.get("tour", {}).get("selected_track_id", &"neon_coast"))
	current_track = TrackRuntimeProfile.resolve(selected_id)
	current_environment_left = TrackRuntimeProfile.textures_for(current_track, "left", COAST_LEFT_TEXTURE)
	current_environment_right = TrackRuntimeProfile.textures_for(current_track, "right", COAST_RIGHT_TEXTURE)
	TrackRuntimeProfile.apply(current_track, drive, run, traffic)

func _open_tour_map() -> void:
	title_screen.visible = false
	result_screen.visible = false
	vehicle_select_screen.visible = false
	tour_map_screen.setup(save_data.tour, language)
	tour_map_screen.open()
	menu_backdrop.visible = true

func _open_vehicle_select(_track_id: StringName = &"") -> void:
	_save_tour_selection()
	tour_map_screen.visible = false
	vehicle_select_screen.setup(save_data.tour, language)
	vehicle_select_screen.open()

func _start_selected_run(_vehicle_id: StringName = &"") -> void:
	_save_tour_selection()
	vehicle_select_screen.visible = false
	_start_new_run()

func _return_to_tour_map() -> void:
	_reset_run()
	settings_screen.visible = false
	controls_screen.visible = false
	pause_screen.visible = false
	result_screen.visible = false
	confirmation_screen.visible = false
	_update_hud()
	_open_tour_map()

func _back_to_title_from_tour() -> void:
	tour_map_screen.visible = false
	vehicle_select_screen.visible = false
	title_screen.visible = true
	menu_backdrop.visible = true
	start_button.grab_focus()

func _back_to_tour_from_garage() -> void:
	vehicle_select_screen.visible = false
	_open_tour_map()

func _save_tour_selection() -> void:
	if persistence_enabled:
		save_store.save_data(save_data)

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
	last_countdown_value = -1
	run.toggle_pause()
	_update_hud()

func _request_restart() -> void:
	_show_confirmation("restart", _text("confirm.restart"))

func _handle_restart_shortcut() -> bool:
	if confirmation_screen.visible:
		return false
	if run.phase == RunState.Phase.RUNNING:
		_pause_run()
	elif run.phase == RunState.Phase.COUNTDOWN:
		run.pause_for_focus_loss()
		_stop_run_audio()
		_update_hud()
	if run.phase == RunState.Phase.PAUSED:
		_request_restart()
		return true
	if run.phase == RunState.Phase.GAME_OVER or run.phase == RunState.Phase.RUN_CLEAR:
		_replay_run()
		return true
	return false

func _request_title() -> void:
	_show_confirmation("title", _text("confirm.title"))

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
	tour_map_screen.visible = false
	vehicle_select_screen.visible = false
	title_screen.visible = true
	_update_hud()
	start_button.grab_focus()

func _cycle_difficulty() -> void:
	difficulty_index = (difficulty_index + 1) % 3
	difficulty_button.text = _text("title.difficulty", [_difficulty_name(difficulty_index)])
	_apply_difficulty_profile()
	_save_preferences()

func _cycle_language() -> void:
	var index := GameText.LANGUAGE_PREFERENCES.find(language_preference)
	_set_language_preference(GameText.LANGUAGE_PREFERENCES[(index + 1) % GameText.LANGUAGE_PREFERENCES.size()])

func _set_language_preference(preference: String) -> void:
	if not preference in GameText.LANGUAGE_PREFERENCES:
		preference = GameText.LANGUAGE_SYSTEM
	language_preference = preference
	language = GameText.resolve_language(language_preference, TranslationServer.get_locale())
	feedback.set_language(language)
	_save_preferences()
	_apply_localized_texts()
	_update_scoreboards()
	_update_hud()

func _toggle_high_contrast() -> void:
	high_contrast_enabled = not high_contrast_enabled
	_save_preferences()
	queue_redraw()

func _toggle_reduced_flashing() -> void:
	reduced_flashing_enabled = not reduced_flashing_enabled
	feedback.flashing_enabled = not reduced_flashing_enabled
	_save_preferences()
	queue_redraw()

func _toggle_screen_shake() -> void:
	screen_shake_enabled = not screen_shake_enabled
	if not screen_shake_enabled:
		screen_shake = Vector2.ZERO
	_save_preferences()
	queue_redraw()

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
	language_preference = String(save_data.settings.language)
	high_contrast_enabled = bool(save_data.settings.high_contrast)
	reduced_flashing_enabled = bool(save_data.settings.reduced_flashing)
	screen_shake_enabled = bool(save_data.settings.screen_shake)
	language = GameText.resolve_language(language_preference, TranslationServer.get_locale())
	feedback.set_language(language)
	feedback.flashing_enabled = not reduced_flashing_enabled
	_apply_localized_texts()
	_apply_difficulty_profile()
	_apply_window_mode()
	if audio_muted:
		_stop_run_audio()
	_apply_master_audio_settings()

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
	save_data.settings.language = language_preference
	save_data.settings.high_contrast = high_contrast_enabled
	save_data.settings.reduced_flashing = reduced_flashing_enabled
	save_data.settings.screen_shake = screen_shake_enabled
	if persistence_enabled:
		save_store.save_data(save_data)
	_apply_master_audio_settings()
	_update_settings_labels()

func _text(key: String, values: Array = []) -> String:
	return GameText.get_text(key, language, values)

func _difficulty_name(index: int) -> String:
	return _text(["difficulty.easy", "difficulty.normal", "difficulty.hard"][clampi(index, 0, 2)])

func _fuel_warning_text() -> String:
	match feedback.low_fuel_tier:
		GameFeedback.FuelTier.LOW: return _text("hud.fuel.low")
		GameFeedback.FuelTier.CRITICAL: return _text("hud.fuel.critical")
		_: return ""

func _apply_localized_texts() -> void:
	$CanvasLayer/TitleScreen/Center/Card/Content/Subtitle.text = _text("title.subtitle")
	$CanvasLayer/TitleScreen/Center/Card/Content/Goal.text = _text("title.objective")
	start_button.text = _text("title.start")
	difficulty_button.text = _text("title.difficulty", [_difficulty_name(difficulty_index)])
	$CanvasLayer/TitleScreen/Center/Card/Content/SettingsButton.text = _text("title.settings")
	$CanvasLayer/TitleScreen/Center/Card/Content/ControlsButton.text = _text("title.controls")
	$CanvasLayer/TitleScreen/Center/Card/Content/QuitButton.text = _text("title.quit")
	$CanvasLayer/SettingsScreen/Center/Card/Content/Heading.text = _text("settings.heading")
	$CanvasLayer/SettingsScreen/Center/Card/Content/BackButton.text = _text("settings.back")
	$CanvasLayer/ControlsScreen/Center/Card/Content/Heading.text = _text("controls.heading")
	$CanvasLayer/ControlsScreen/Center/Card/Content/Instructions.text = _text("controls.body")
	$CanvasLayer/ControlsScreen/Center/Card/Content/BackButton.text = _text("settings.back")
	$CanvasLayer/PauseScreen/Center/Card/Content/Heading.text = _text("pause.heading")
	$CanvasLayer/PauseScreen/Center/Card/Content/ResumeButton.text = _text("pause.resume")
	$CanvasLayer/PauseScreen/Center/Card/Content/RestartButton.text = _text("pause.restart")
	$CanvasLayer/PauseScreen/Center/Card/Content/SettingsButton.text = _text("pause.settings")
	$CanvasLayer/PauseScreen/Center/Card/Content/TitleButton.text = _text("pause.title")
	new_record_label.text = _text("result.new_record")
	$CanvasLayer/ResultScreen/Center/Card/Content/ReplayButton.text = _text("result.replay")
	$CanvasLayer/ResultScreen/Center/Card/Content/TitleButton.text = _text("result.title")
	$CanvasLayer/ConfirmationScreen/Center/Card/Content/ConfirmButton.text = _text("confirm.yes")
	$CanvasLayer/ConfirmationScreen/Center/Card/Content/CancelButton.text = _text("confirm.no")
	if confirmation_screen.visible and not destructive_action.is_empty():
		$CanvasLayer/ConfirmationScreen/Center/Card/Content/Prompt.text = _text("confirm.%s" % destructive_action)
	_update_settings_labels()

func _update_settings_labels() -> void:
	if settings_volume_label == null:
		return
	settings_volume_label.text = _text("settings.volume", [roundi(audio_volume * 100.0)])
	settings_mute_button.text = _text("settings.mute", [_text("common.on" if audio_muted else "common.off")])
	settings_fullscreen_button.text = _text("settings.display", [_text("common.fullscreen" if fullscreen_enabled else "common.windowed")])
	settings_language_button.text = _text("settings.language", [_text("settings.language.%s" % language_preference)])
	settings_high_contrast_button.text = _text("settings.high_contrast", [_text("common.on" if high_contrast_enabled else "common.off")])
	settings_reduced_flashing_button.text = _text("settings.reduced_flashing", [_text("common.on" if reduced_flashing_enabled else "common.off")])
	settings_screen_shake_button.text = _text("settings.screen_shake", [_text("common.on" if screen_shake_enabled else "common.off")])

func _bind_ui_actions() -> void:
	start_button.pressed.connect(_open_tour_map)
	difficulty_button.pressed.connect(_cycle_difficulty)
	$CanvasLayer/TitleScreen/Center/Card/Content/SettingsButton.pressed.connect(_show_settings)
	$CanvasLayer/TitleScreen/Center/Card/Content/ControlsButton.pressed.connect(_show_controls)
	$CanvasLayer/TitleScreen/Center/Card/Content/QuitButton.pressed.connect(get_tree().quit)
	settings_mute_button.pressed.connect(_toggle_audio_mute)
	settings_fullscreen_button.pressed.connect(_toggle_fullscreen)
	settings_language_button.pressed.connect(_cycle_language)
	settings_high_contrast_button.pressed.connect(_toggle_high_contrast)
	settings_reduced_flashing_button.pressed.connect(_toggle_reduced_flashing)
	settings_screen_shake_button.pressed.connect(_toggle_screen_shake)
	$CanvasLayer/SettingsScreen/Center/Card/Content/BackButton.pressed.connect(_close_submenu)
	$CanvasLayer/ControlsScreen/Center/Card/Content/BackButton.pressed.connect(_close_submenu)
	$CanvasLayer/PauseScreen/Center/Card/Content/ResumeButton.pressed.connect(_resume_run)
	$CanvasLayer/PauseScreen/Center/Card/Content/RestartButton.pressed.connect(_request_restart)
	$CanvasLayer/PauseScreen/Center/Card/Content/SettingsButton.pressed.connect(_show_pause_settings)
	$CanvasLayer/PauseScreen/Center/Card/Content/TitleButton.pressed.connect(_request_title)
	$CanvasLayer/ResultScreen/Center/Card/Content/ReplayButton.pressed.connect(_return_to_tour_map)
	$CanvasLayer/ResultScreen/Center/Card/Content/TitleButton.pressed.connect(_return_to_title)
	$CanvasLayer/ConfirmationScreen/Center/Card/Content/ConfirmButton.pressed.connect(_confirm_destructive_action)
	$CanvasLayer/ConfirmationScreen/Center/Card/Content/CancelButton.pressed.connect(_cancel_confirmation)
	tour_map_screen.track_confirmed.connect(_open_vehicle_select)
	tour_map_screen.back_requested.connect(_back_to_title_from_tour)
	vehicle_select_screen.vehicle_confirmed.connect(_start_selected_run)
	vehicle_select_screen.back_requested.connect(_back_to_tour_from_garage)

func _bind_ui_cues() -> void:
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		button.focus_entered.connect(_play_ui_cue.bind("ui_move"))
		var cue_name := "ui_cancel" if button.name == "BackButton" or button.name == "CancelButton" else "ui_confirm"
		button.pressed.connect(_play_ui_cue.bind(cue_name))

func _player_lane() -> int:
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	return clampi(int(floor((drive.lateral_position + GameConfig.ROAD_HALF_WIDTH) / lane_width)), 0, GameConfig.ROAD_LANE_COUNT - 1)

func _update_hud() -> void:
	var scale := VisualStyle.hud_scale_for_width(get_viewport_rect().size.x)
	speed_label.text = _text("hud.speed", ["%03d" % roundi(drive.speed * 0.42)])
	position_label.text = ""
	score_label.text = _text("hud.score", ["%06d" % run.score, "%05d" % roundi(run.distance)])
	var fuel_warning := _fuel_warning_text() if feedback.is_fuel_warning_visible() else ""
	fuel_label.text = _text("hud.fuel", ["%03d" % roundi(run.fuel), fuel_warning])
	fuel_label.modulate = Color("ff6b6b") if feedback.low_fuel_tier == GameFeedback.FuelTier.CRITICAL else (Color("ffd75a") if feedback.low_fuel_tier == GameFeedback.FuelTier.LOW else Color.WHITE)
	fuel_gauge.value = clampf(run.fuel, 0.0, GameConfig.MAX_FUEL)
	fuel_gauge.modulate = fuel_label.modulate
	progress_gauge.value = clampf(run.distance / GameConfig.RACE_FINISH_DISTANCE * 100.0, 0.0, 100.0)
	var combo_time := "%.1fs" % run.combo.remaining_seconds if run.combo.event_count > 0 else _text("hud.ready")
	run_status_label.text = _text("hud.status", [run.difficulty_stage + 1, run.combo.multiplier, combo_time, _phase_text()])
	controls_hint_label.text = _text("hud.controls", [current_run_seed])
	for label in [speed_label, controls_hint_label, score_label, fuel_label, run_status_label]:
		label.scale = Vector2.ONE * scale
	var result_was_visible := result_screen.visible
	race_hud.visible = run.phase == RunState.Phase.RUNNING or run.phase == RunState.Phase.PAUSED
	countdown_screen.visible = run.phase == RunState.Phase.COUNTDOWN
	var lane_event_text := _lane_event_text()
	feedback_banner.visible = run.phase == RunState.Phase.RUNNING and (not lane_event_text.is_empty() or not feedback.stage_banner_text.is_empty())
	feedback_banner.text = lane_event_text if not lane_event_text.is_empty() else feedback.stage_banner_text
	event_plate.visible = feedback_banner.visible
	event_plate.modulate = _event_plate_color()
	if countdown_screen.visible:
		countdown_label.text = str(maxi(1, ceili(run.countdown_remaining)))
	pause_screen.visible = run.phase == RunState.Phase.PAUSED and not confirmation_screen.visible and not settings_screen.visible
	result_screen.visible = run.phase == RunState.Phase.GAME_OVER or run.phase == RunState.Phase.RUN_CLEAR
	finish_burst.visible = run.phase == RunState.Phase.RUN_CLEAR and feedback.finish_remaining > 0.0
	var finish_elapsed := GameFeedback.FINISH_DURATION - feedback.finish_remaining
	if run.phase == RunState.Phase.RUN_CLEAR:
		var emblem_scale := VehicleVisualAnimation.finish_emblem_scale(finish_elapsed)
		result_emblem.pivot_offset = result_emblem.size * 0.5
		result_emblem.scale = Vector2.ONE * emblem_scale
		result_emblem.rotation = VehicleVisualAnimation.finish_emblem_rotation(finish_elapsed)
		finish_burst.pivot_offset = finish_burst.size * 0.5
		finish_burst.rotation = visual_animation_time * 0.16
		finish_burst.modulate.a = clampf(feedback.finish_remaining / GameFeedback.FINISH_DURATION, 0.0, 1.0)
	else:
		result_emblem.scale = Vector2.ONE
		result_emblem.rotation = 0.0
	if result_screen.visible:
		_persist_result_once()
		_update_result_labels()
		if not result_was_visible:
			$CanvasLayer/ResultScreen/Center/Card/Content/ReplayButton.grab_focus()
	menu_backdrop.visible = run.phase == RunState.Phase.TITLE or result_screen.visible or tour_map_screen.visible or vehicle_select_screen.visible or (settings_screen.visible and submenu_return == "title") or controls_screen.visible
	if run.phase == RunState.Phase.TITLE and not settings_screen.visible and not controls_screen.visible and not tour_map_screen.visible and not vehicle_select_screen.visible:
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
		"track_id": StringName(save_data.tour.selected_track_id),
		"cleared": run.phase == RunState.Phase.RUN_CLEAR,
		"medal": _tour_medal_for_result(),
	}, Time.get_date_string_from_system())
	save_data = outcome.data
	is_new_record = outcome.new_record
	if persistence_enabled:
		save_store.save_data(save_data)
	_update_scoreboards()

func _tour_medal_for_result() -> int:
	if run.phase != RunState.Phase.RUN_CLEAR:
		return 0
	var track := TrackCatalog.get_by_id(StringName(save_data.tour.selected_track_id))
	if track.is_empty():
		return 1
	if run.score >= int(track.gold_score):
		return 3
	if run.score >= int(track.silver_score):
		return 2
	return 1

func _update_scoreboards() -> void:
	if save_data.is_empty():
		return
	var text := _format_top_scores(save_data.top_scores)
	title_best_scores.text = text
	result_best_scores.text = text

func _format_top_scores(scores: Array) -> String:
	if scores.is_empty():
		return _text("scores.none")
	var lines: Array[String] = [_text("scores.heading")]
	for index in range(scores.size()):
		var item: Dictionary = scores[index]
		lines.append(_text("scores.entry", [index + 1, "%06d" % item.score, _difficulty_name(item.difficulty), "%05d" % roundi(item.distance)]))
	return "\n".join(lines)

func _update_result_labels() -> void:
	var cleared := run.phase == RunState.Phase.RUN_CLEAR
	result_heading.text = _text("result.clear" if cleared else "result.over")
	new_record_label.visible = is_new_record
	var reason := _text("result.reason.clear" if cleared else "result.reason.fuel")
	result_summary.text = _text("result.summary", [reason, "%06d" % run.score, "%05d" % roundi(run.distance), run.overtakes, run.near_misses, run.difficulty_stage + 1, current_run_seed])

func _phase_text() -> String:
	match run.phase:
		RunState.Phase.TITLE: return _text("phase.title")
		RunState.Phase.COUNTDOWN: return _text("phase.countdown")
		RunState.Phase.RUNNING: return _text("phase.running")
		RunState.Phase.PAUSED: return _text("phase.paused")
		RunState.Phase.RUN_CLEAR: return _text("phase.clear")
		_: return _text("phase.over")

func _lane_event_text() -> String:
	var blocked_lane := traffic.lane_events.blocked_lane()
	if blocked_lane < 0:
		return ""
	if traffic.lane_events.state == LaneEventDirector.State.WARNING:
		return _text("lane.warning", [blocked_lane + 1])
	return _text("lane.closed", [blocked_lane + 1])

func _overlay_text() -> String:
	match run.phase:
		RunState.Phase.TITLE: return "NEON COAST RUSH"
		RunState.Phase.COUNTDOWN: return str(maxi(1, ceili(run.countdown_remaining)))
		RunState.Phase.PAUSED: return _text("overlay.paused")
		RunState.Phase.GAME_OVER: return _text("overlay.game_over", ["%06d" % run.score, "%05d" % roundi(run.distance)])
		_: return ""

func _ensure_input_actions() -> void:
	_register_action("accelerate", [KEY_UP, KEY_W])
	_register_action("brake", [KEY_DOWN, KEY_S])
	_register_action("steer_left", [KEY_LEFT, KEY_A])
	_register_action("steer_right", [KEY_RIGHT, KEY_D])
	_register_action("pause_game", [KEY_SPACE], true)
	_register_action("restart_run", [KEY_R], true)
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
