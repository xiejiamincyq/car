extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const STEP := 1.0 / 60.0
var failures: Array[String] = []

func _init() -> void:
	for height in [720.0, 1080.0]:
		for speed in [0.0, 200.0, 760.0, 820.0]:
			_sample(height, speed)
	var host := Traffic.new(611)
	host.lane_events.enabled = false
	var ordinary = host.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 100.0)
	ordinary.actual_world_speed = 0.0
	host.vehicles.append(ordinary)
	host.update_vehicle(ordinary, STEP, 200.0)
	_check(is_equal_approx(ordinary.actual_world_speed, 140.0 * STEP), "ordinary acceleration remains unchanged")
	for failure in failures: push_error("FAST_SPRINT " + failure)
	print("FAST_SPRINT failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_fast_sprint.gd")
	quit(0 if failures.is_empty() else 1)

func _sample(height: float, speed: float) -> void:
	var host := Traffic.new(611)
	host.set_viewport_height(height)
	host.lane_events.enabled = false
	host._spawn_cooldown = 1000.0
	var red = host.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 0, height - 42.0)
	red.actual_world_speed = speed
	host.vehicles.append(red)
	_check(is_equal_approx(red.cruise_speed * Config.HUD_SPEED_SCALE, 400.0), "red cruise is 400 km/h in displayed units")
	var elapsed := 0.0
	var warned := 0.0
	var passed := false
	while elapsed < 3.0:
		var old_speed: float = red.actual_world_speed
		var old_y: float = red.y
		if red.arrival_warning_started and red.overtake_warning_remaining > 0.0 and host._is_lane_change_visible(red): warned += STEP
		host.tick(STEP, speed, 2)
		elapsed += STEP
		var rate := 420.0 if red.actual_world_speed < old_speed else 360.0
		_check(absf(red.actual_world_speed - old_speed) <= rate * STEP + 0.00001, "red has bounded 360/420 acceleration and braking")
		_check(absf(red.y - old_y - (speed - red.actual_world_speed) * Config.ROAD_SCROLL_MULTIPLIER * STEP) < 0.00001, "red never teleports")
		_check(not host.has_vehicle_overlap() and not host.has_full_lane_wall(), "red keeps body and escape safety")
		if red.y + red.half_length < Geometry.player_y(height):
			passed = true
			break
	print("FAST_SPRINT_WITNESS ", JSON.stringify({"height":height,"player_speed":speed,"seconds":elapsed,"warning":warned,"red_speed_kmh":red.actual_world_speed * Config.HUD_SPEED_SCALE,"passed":passed}))
	_check(passed and elapsed <= 2.0 + STEP, "clear-road red fully passes player within 2s of full visible entry at height=%s speed=%s" % [height,speed])
	_check(warned >= 1.0 - STEP - 0.00001, "full visible arrival warning remains before passing")

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
