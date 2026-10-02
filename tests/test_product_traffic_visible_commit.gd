extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
const STEP := 1.0 / 60.0

func _init() -> void:
	var traffic := Traffic.new(618)
	traffic.set_viewport_height(720.0)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	var vehicle = traffic.acquire_vehicle(Traffic.Kind.SIGNAL_CHANGE, 0, 130.0, 200.0)
	vehicle.target_lane = 1
	traffic.vehicles.append(vehicle)
	traffic.tick(STEP, 100.0, 1)
	var warning_observed: bool = vehicle.warning_started
	var speed := 100.0
	var resolved := false
	for step in range(120):
		var previous_x: float = vehicle.lane_position
		var previous_y: float = vehicle.y
		speed = move_toward(speed, 0.0, Config.BRAKING * STEP)
		traffic.tick(STEP, speed, 1)
		if not is_equal_approx(vehicle.lane_position, previous_x):
			print("VISIBLE_COMMIT_EVIDENCE ", JSON.stringify({"seed":618, "seconds":(step + 2) * STEP, "warning_observed":warning_observed, "start_y":previous_y, "end_y":vehicle.y, "player_speed":speed, "dx_lanes":vehicle.lane_position - previous_x}))
			var visible: bool = previous_y >= Traffic.LANE_CHANGE_WARNING_ENTRY_Y and previous_y <= 720.0 - vehicle.half_length
			_finish(warning_observed and visible, "a warned NPC must recheck actual visibility before beginning lateral motion")
			return
		if warning_observed and not vehicle.lane_change_enabled:
			resolved = true
			break
	print("VISIBLE_COMMIT_EVIDENCE ", JSON.stringify({"warning_observed":warning_observed, "cancelled_without_movement":resolved, "last_y":vehicle.y}))
	_finish(warning_observed and resolved, "the mid-warning braking exposure must occur and resolve without offscreen lateral motion")

func _finish(passed: bool, description: String) -> void:
	if not passed:
		print("FAIL: ", description)
	print("TEST_COMPLETE test_product_traffic_visible_commit.gd")
	quit(0 if passed else 1)
