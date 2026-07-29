extends Node2D

const GameConfig = preload("res://scripts/game_config.gd")
const DriveController = preload("res://scripts/drive_controller.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")
const CollisionResponder = preload("res://scripts/collision_responder.gd")
const CollisionSound = preload("res://scripts/collision_sound.gd")
const RunState = preload("res://scripts/run_state.gd")
const FuelPickup = preload("res://scripts/fuel_pickup.gd")
const ROAD_MARK_REPEAT_DISTANCE := 92.0

var drive: DriveController
var traffic: TrafficDirector
var collision: CollisionResponder
var run: RunState
var road_scroll := 0.0
var screen_shake := Vector2.ZERO
var collision_audio: AudioStreamPlayer
var fuel_pickups: Array[FuelPickup] = []
var fuel_spawn_remaining := GameConfig.FUEL_PICKUP_INTERVAL
var pickup_lane_cursor := 0

var speed_label: Label
var position_label: Label
var debug_label: Label
var score_label: Label
var fuel_label: Label
var run_status_label: Label
var overlay_label: Label

func _ready() -> void:
	_ensure_input_actions()
	drive = DriveController.new(GameConfig.START_SPEED, GameConfig.MAX_SPEED, GameConfig.ACCELERATION, GameConfig.BRAKING, GameConfig.STEERING_SPEED, GameConfig.ROAD_HALF_WIDTH, 30.0)
	traffic = TrafficDirector.new(GameConfig.TRAFFIC_RANDOM_SEED, GameConfig.ROAD_LANE_COUNT, GameConfig.MIN_SPAWN_DISTANCE, GameConfig.MIN_TRAFFIC_GAP)
	collision = CollisionResponder.new(GameConfig.COLLISION_SPEED_PENALTY, GameConfig.COLLISION_INVULNERABILITY_SECONDS)
	run = RunState.new(GameConfig.MAX_FUEL, GameConfig.FUEL_DRAIN_PER_SECOND, GameConfig.FUEL_GRACE_SECONDS)
	collision_audio = AudioStreamPlayer.new()
	collision_audio.stream = CollisionSound.create_stream()
	add_child(collision_audio)
	speed_label = $CanvasLayer/DebugHUD/Rows/Speed
	position_label = $CanvasLayer/DebugHUD/Rows/Position
	debug_label = $CanvasLayer/DebugHUD/Rows/Debug
	score_label = $CanvasLayer/DebugHUD/Rows/Score
	fuel_label = $CanvasLayer/DebugHUD/Rows/Fuel
	run_status_label = $CanvasLayer/DebugHUD/Rows/RunStatus
	overlay_label = $CanvasLayer/Overlay
	_update_hud()
	queue_redraw()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("quit_game"):
		get_tree().quit()
	if Input.is_action_just_pressed("restart_prototype"):
		_restart_run()
	if Input.is_action_just_pressed("start_game"):
		run.start()
	if Input.is_action_just_pressed("pause_game"):
		run.toggle_pause()
	if run.phase != RunState.Phase.RUNNING:
		_update_hud()
		queue_redraw()
		return
	var accelerate_input := Input.get_action_strength("accelerate")
	var brake_input := Input.get_action_strength("brake")
	var steering_input := Input.get_axis("steer_left", "steer_right")
	drive.step(delta, accelerate_input, brake_input, steering_input)
	road_scroll = advance_road_scroll(road_scroll, drive.speed, delta, ROAD_MARK_REPEAT_DISTANCE)
	run.tick(delta, drive.speed, GameConfig.MAX_SPEED)
	if run.phase == RunState.Phase.ENDED:
		_update_hud()
		queue_redraw()
		return
	traffic.set_difficulty_stage(run.difficulty_stage)
	traffic.tick(delta, drive.speed, _player_lane())
	_update_fuel_pickups(delta)
	collision.advance(delta)
	_check_collisions()
	_award_completed_overtakes()
	screen_shake = screen_shake.move_toward(Vector2.ZERO, 140.0 * delta)
	_update_hud()
	queue_redraw()

func _draw() -> void:
	draw_set_transform(screen_shake)
	var viewport_size := get_viewport_rect().size
	var center_x := viewport_size.x * 0.5
	var road_left := center_x - GameConfig.ROAD_HALF_WIDTH
	var road_right := center_x + GameConfig.ROAD_HALF_WIDTH
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("16322c"))
	draw_rect(Rect2(road_left - 26.0, 0.0, GameConfig.ROAD_HALF_WIDTH * 2.0 + 52.0, viewport_size.y), Color("d0a65e"))
	draw_rect(Rect2(road_left, 0.0, GameConfig.ROAD_HALF_WIDTH * 2.0, viewport_size.y), Color("292d39"))
	draw_line(Vector2(road_left, 0.0), Vector2(road_left, viewport_size.y), Color("fff2c5"), 7.0)
	draw_line(Vector2(road_right, 0.0), Vector2(road_right, viewport_size.y), Color("fff2c5"), 7.0)
	for lane_index in range(1, GameConfig.ROAD_LANE_COUNT):
		var lane_x := road_left + GameConfig.ROAD_HALF_WIDTH * 2.0 * lane_index / GameConfig.ROAD_LANE_COUNT
		var dash_y := get_dash_start_y(road_scroll, ROAD_MARK_REPEAT_DISTANCE)
		while dash_y < viewport_size.y:
			draw_rect(Rect2(lane_x - 5.0, dash_y, 10.0, 52.0), Color("e7e9e8"))
			dash_y += ROAD_MARK_REPEAT_DISTANCE
	_draw_traffic(center_x, road_left)
	_draw_fuel_pickups(center_x, road_left)
	var car_center := Vector2(center_x + drive.lateral_position, viewport_size.y - 128.0)
	var player_color := Color("48b7e8") if not _is_player_flashing() else Color("f4f1d0")
	draw_colored_polygon(PackedVector2Array([car_center + Vector2(0.0, -44.0), car_center + Vector2(27.0, 34.0), car_center + Vector2(-27.0, 34.0)]), player_color)
	draw_rect(Rect2(car_center + Vector2(-18.0, -10.0), Vector2(36.0, 30.0)), Color("0d4866"))
	draw_circle(car_center + Vector2(0.0, 27.0), 5.0, Color("ffdf66"))
	draw_set_transform(Vector2.ZERO)

func _draw_traffic(center_x: float, road_left: float) -> void:
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	for vehicle in traffic.vehicles:
		var car_center := Vector2(road_left + lane_width * (vehicle.lane_position + 0.5), vehicle.y)
		draw_rect(Rect2(car_center + Vector2(-25.0, -42.0), Vector2(50.0, 82.0)), _traffic_color(vehicle.kind), true)
		draw_rect(Rect2(car_center + Vector2(-16.0, -26.0), Vector2(32.0, 28.0)), Color("17212d"), true)
		draw_circle(car_center + Vector2(-17.0, 27.0), 5.0, Color("17191f"))
		draw_circle(car_center + Vector2(17.0, 27.0), 5.0, Color("17191f"))
		if vehicle.kind == TrafficDirector.Kind.SIGNAL_CHANGE and vehicle.warning_remaining > 0.0:
			var direction := signf(vehicle.target_lane - vehicle.lane_position)
			draw_colored_polygon(PackedVector2Array([car_center + Vector2(18.0 * direction, -35.0), car_center + Vector2(4.0 * direction, -42.0), car_center + Vector2(4.0 * direction, -28.0)]), Color("ffe16a"))
		if vehicle.kind == TrafficDirector.Kind.FAST_OVERTAKE and vehicle.overtake_warning_remaining > 0.0:
			var warning_y := TrafficDirector.fast_warning_y(vehicle.y)
			draw_line(Vector2(car_center.x - 18.0, warning_y), Vector2(car_center.x + 18.0, warning_y), Color("ff70d0"), 4.0)

func _draw_fuel_pickups(center_x: float, road_left: float) -> void:
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	for pickup in fuel_pickups:
		var center := Vector2(road_left + lane_width * (pickup.lane + 0.5), pickup.y)
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -20), center + Vector2(18, 0), center + Vector2(0, 20), center + Vector2(-18, 0)]), Color("65e49a"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-6, 6), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("173a32"))

func _traffic_color(kind: int) -> Color:
	match kind:
		TrafficDirector.Kind.STEADY_SLOW: return Color("e98562")
		TrafficDirector.Kind.SIGNAL_CHANGE: return Color("d9a84b")
		_: return Color("c466d7")

func _update_fuel_pickups(delta: float) -> void:
	fuel_spawn_remaining -= delta
	if fuel_spawn_remaining <= 0.0:
		fuel_pickups.append(FuelPickup.new(pickup_lane_cursor, -90.0))
		pickup_lane_cursor = (pickup_lane_cursor + 2) % GameConfig.ROAD_LANE_COUNT
		fuel_spawn_remaining = GameConfig.FUEL_PICKUP_INTERVAL
	var viewport_size := get_viewport_rect().size
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	var player_center := Vector2(viewport_size.x * 0.5 + drive.lateral_position, viewport_size.y - 128.0)
	var active: Array[FuelPickup] = []
	for pickup in fuel_pickups:
		pickup.y += drive.speed * GameConfig.ROAD_SCROLL_MULTIPLIER * delta
		var pickup_x := viewport_size.x * 0.5 - GameConfig.ROAD_HALF_WIDTH + lane_width * (pickup.lane + 0.5)
		if absf(pickup_x - player_center.x) < 48.0 and absf(pickup.y - player_center.y) < 62.0:
			run.add_fuel(GameConfig.FUEL_PICKUP_AMOUNT)
			continue
		if pickup.y < viewport_size.y + 60.0:
			active.append(pickup)
	fuel_pickups = active

func _check_collisions() -> void:
	var viewport_size := get_viewport_rect().size
	var center_x := viewport_size.x * 0.5
	var road_left := center_x - GameConfig.ROAD_HALF_WIDTH
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	var player_center := Vector2(center_x + drive.lateral_position, viewport_size.y - 128.0)
	for vehicle in traffic.vehicles:
		var traffic_center := Vector2(road_left + lane_width * (vehicle.lane_position + 0.5), vehicle.y)
		if absf(traffic_center.x - player_center.x) < 50.0 and absf(traffic_center.y - player_center.y) < 72.0:
			var outcome := collision.try_collide(drive.speed)
			if outcome.hit:
				drive.speed = outcome.speed
				vehicle.y = player_center.y + 130.0
				vehicle.collided_with_player = true
				screen_shake = Vector2(10.0, -7.0)
				collision_audio.play()

func _award_completed_overtakes() -> void:
	var player_y := get_viewport_rect().size.y - 128.0
	for vehicle in traffic.vehicles:
		if vehicle.y < player_y - 76.0:
			vehicle.was_ahead_of_player = true
		if not vehicle.passed_player and vehicle.y > player_y + 76.0 and is_eligible_overtake(vehicle.kind, vehicle.was_ahead_of_player, vehicle.collided_with_player):
			vehicle.passed_player = true
			run.award_overtake(GameConfig.OVERTAKE_SCORE)

static func is_eligible_overtake(kind: int, was_ahead: bool, collided_with_player: bool) -> bool:
	return kind != TrafficDirector.Kind.FAST_OVERTAKE and was_ahead and not collided_with_player

func _is_player_flashing() -> bool:
	return collision.invulnerability_remaining > 0.0 and int(collision.invulnerability_remaining * 14.0) % 2 == 0

func _reset_run() -> void:
	drive.reset()
	road_scroll = 0.0
	traffic.reset()
	collision = CollisionResponder.new(GameConfig.COLLISION_SPEED_PENALTY, GameConfig.COLLISION_INVULNERABILITY_SECONDS)
	screen_shake = Vector2.ZERO
	collision_audio.stop()
	run.reset()
	fuel_pickups.clear()
	fuel_spawn_remaining = GameConfig.FUEL_PICKUP_INTERVAL
	pickup_lane_cursor = 0

func _restart_run() -> void:
	_reset_run()
	run.start()

func _player_lane() -> int:
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	return clampi(int(floor((drive.lateral_position + GameConfig.ROAD_HALF_WIDTH) / lane_width)), 0, GameConfig.ROAD_LANE_COUNT - 1)

func _update_hud() -> void:
	speed_label.text = "速度  %03d km/h" % roundi(drive.speed * 0.42)
	position_label.text = "横向位置  %+.0f / %.0f" % [drive.lateral_position, GameConfig.ROAD_HALF_WIDTH]
	score_label.text = "得分  %06d    距离  %05dm" % [run.score, roundi(run.distance)]
	fuel_label.text = "燃油  %03d%%" % roundi(run.fuel)
	run_status_label.text = "难度 %d  |  %s" % [run.difficulty_stage + 1, _phase_text()]
	debug_label.text = "W/↑ 加速  S/↓ 制动  A/D/←→ 转向  P 暂停  R 重开  Esc 退出"
	overlay_label.text = _overlay_text()

func _phase_text() -> String:
	match run.phase:
		RunState.Phase.READY: return "准备"
		RunState.Phase.RUNNING: return "行驶中"
		RunState.Phase.PAUSED: return "已暂停"
		_: return "结算"

func _overlay_text() -> String:
	match run.phase:
		RunState.Phase.READY: return "高速突围\n按 空格 开始"
		RunState.Phase.PAUSED: return "已暂停\n按 P 继续"
		RunState.Phase.ENDED: return "燃油耗尽\n得分 %d  |  距离 %dm\n按 R 再来一局" % [run.score, roundi(run.distance)]
		_: return ""

func _ensure_input_actions() -> void:
	_register_action("accelerate", [KEY_UP, KEY_W])
	_register_action("brake", [KEY_DOWN, KEY_S])
	_register_action("steer_left", [KEY_LEFT, KEY_A])
	_register_action("steer_right", [KEY_RIGHT, KEY_D])
	_register_action("restart_prototype", [KEY_R])
	_register_action("start_game", [KEY_SPACE])
	_register_action("pause_game", [KEY_P])
	_register_action("quit_game", [KEY_ESCAPE])

func _register_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keys:
		var event := InputEventKey.new()
		event.keycode = keycode
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)

static func advance_road_scroll(current_offset: float, speed: float, delta: float, repeat_distance: float) -> float:
	return fmod(current_offset + speed * GameConfig.ROAD_SCROLL_MULTIPLIER * delta, repeat_distance)

static func get_dash_start_y(scroll_offset: float, repeat_distance: float) -> float:
	return scroll_offset - repeat_distance
