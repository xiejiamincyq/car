extends Node2D

const GameConfig = preload("res://scripts/game_config.gd")
const DriveController = preload("res://scripts/drive_controller.gd")
const ROAD_MARK_REPEAT_DISTANCE: float = 92.0

var drive: DriveController
var road_scroll: float = 0.0
var speed_label: Label
var position_label: Label
var debug_label: Label

func _ready() -> void:
	_ensure_input_actions()
	drive = DriveController.new(
		GameConfig.START_SPEED,
		GameConfig.MAX_SPEED,
		GameConfig.ACCELERATION,
		GameConfig.BRAKING,
		GameConfig.STEERING_SPEED,
		GameConfig.ROAD_HALF_WIDTH,
		30.0
	)
	speed_label = $CanvasLayer/DebugHUD/Rows/Speed
	position_label = $CanvasLayer/DebugHUD/Rows/Position
	debug_label = $CanvasLayer/DebugHUD/Rows/Debug
	queue_redraw()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("quit_game"):
		get_tree().quit()
	if Input.is_action_just_pressed("restart_prototype"):
		drive.reset()
		road_scroll = 0.0

	var accelerate_input := Input.get_action_strength("accelerate")
	var brake_input := Input.get_action_strength("brake")
	var steering_input := Input.get_axis("steer_left", "steer_right")
	drive.step(delta, accelerate_input, brake_input, steering_input)
	road_scroll = advance_road_scroll(road_scroll, drive.speed, delta, ROAD_MARK_REPEAT_DISTANCE)
	_update_hud()
	queue_redraw()

func _draw() -> void:
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

	var car_center := Vector2(center_x + drive.lateral_position, viewport_size.y - 128.0)
	draw_colored_polygon(PackedVector2Array([
		car_center + Vector2(0.0, -44.0),
		car_center + Vector2(27.0, 34.0),
		car_center + Vector2(-27.0, 34.0)
	]), Color("48b7e8"))
	draw_rect(Rect2(car_center + Vector2(-18.0, -10.0), Vector2(36.0, 30.0)), Color("0d4866"))
	draw_circle(car_center + Vector2(0.0, 27.0), 5.0, Color("ffdf66"))

func _update_hud() -> void:
	speed_label.text = "速度  %03d km/h" % roundi(drive.speed * 0.42)
	position_label.text = "横向位置  %+.0f / %.0f" % [drive.lateral_position, GameConfig.ROAD_HALF_WIDTH]
	debug_label.text = "FPS %d  |  加速 %.0f  制动 %.0f  转向 %.0f\n↑/W 加速  ↓/S 制动  ←→/A D 转向  R 重置  Esc 退出" % [
		Engine.get_frames_per_second(), GameConfig.ACCELERATION, GameConfig.BRAKING, GameConfig.STEERING_SPEED
	]

func _ensure_input_actions() -> void:
	_register_action("accelerate", [KEY_UP, KEY_W])
	_register_action("brake", [KEY_DOWN, KEY_S])
	_register_action("steer_left", [KEY_LEFT, KEY_A])
	_register_action("steer_right", [KEY_RIGHT, KEY_D])
	_register_action("restart_prototype", [KEY_R])
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
