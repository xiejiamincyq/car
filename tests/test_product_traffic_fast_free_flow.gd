extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Config = preload("res://scripts/game_config.gd")
const STEPS := [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 0.1, 0.25]
class FastTraffic extends Traffic:
	func _kind_for_next_spawn() -> int:
		return Kind.FAST_OVERTAKE

func _init() -> void:
	var okay := true
	for delta in STEPS:
		for speed in [0.0, 200.0, 760.0]:
			okay = _sample(delta, speed) and okay
	print("TEST_COMPLETE test_product_traffic_fast_free_flow.gd")
	quit(0 if okay else 1)

func _sample(delta: float, player_speed: float) -> bool:
	var traffic := FastTraffic.new(611)
	traffic.lane_events.enabled = false
	traffic._spawn_cooldown = 0.0
	traffic.tick(delta, player_speed, 2)
	traffic._spawn_cooldown = 1000.0
	var warning_seen := false
	var warning_seconds := 0.0
	var warning_lane := -1
	for frame in ceili(3.0/delta):
		var notice := traffic.fast_entry_warning()
		if notice.active:
			warning_seen = true
			warning_seconds += delta
			warning_lane = notice.lane
		traffic.tick(delta, player_speed, 2)
		if not traffic.vehicles.is_empty(): break
	if traffic.vehicles.size() != 1:
		print("FAIL: empty-road fast arrival must be admitted after its visible pre-entry warning")
		return false
	var vehicle = traffic.vehicles[0]
	var admitted: bool = vehicle.spawn_was_fair
	var visible_seconds := 0.0
	var passed_player := false
	var elapsed := 0.0
	var no_jump := true
	while elapsed < 15.0 and traffic.vehicles.has(vehicle):
		var old_y: float = vehicle.y
		var old_actual: float = vehicle.actual_world_speed
		traffic.tick(delta, player_speed, 2)
		elapsed += delta
		if absf(vehicle.actual_world_speed - old_actual) > Traffic.NPC_BRAKING * delta + 0.0001:
			no_jump = false
		if delta <= 1.0 / 60.0 and absf(vehicle.y - old_y - (player_speed - vehicle.actual_world_speed) * Config.ROAD_SCROLL_MULTIPLIER * delta) > 0.0001:
			no_jump = false
		if traffic._is_lane_change_visible(vehicle):
			visible_seconds += delta
		if vehicle.y < Geometry.player_y(720.0) - vehicle.half_length:
			passed_player = true
			break
	var okay: bool = admitted and no_jump and warning_seen and warning_seconds >= 1.0-0.00001 and warning_lane == vehicle.lane and visible_seconds > 0.0 and passed_player and is_equal_approx(vehicle.actual_world_speed * Config.HUD_SPEED_SCALE, 450.0)
	print("FAST_FREE_FLOW ", JSON.stringify({"dt":delta,"player_speed":player_speed,"admitted":admitted,"no_jump":no_jump,"warning_seconds":warning_seconds,"visible_seconds":visible_seconds,"passed_player":passed_player,"elapsed":elapsed,"actual":vehicle.actual_world_speed,"okay":okay}))
	return okay
