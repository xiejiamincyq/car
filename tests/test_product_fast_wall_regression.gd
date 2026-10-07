extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const Difficulty = preload("res://scripts/difficulty_profile.gd")
const Config = preload("res://scripts/game_config.gd")
var failures: Array[String] = []

class ObservedTraffic extends Traffic:
	var substep_count := 0
	var first_wall_substep := -1
	var history: Array[Dictionary] = []
	var wall_witness: Array[Dictionary] = []
	var physical_failures: Array[String] = []
	func _tick_step(delta: float, player_speed: float, player_lane: int, frame_start: Dictionary) -> void:
		var before := _snapshot()
		super._tick_step(delta, player_speed, player_lane, frame_start)
		var after := _snapshot()
		for current in after:
			for previous in before:
				if current.id != previous.id or current.generation != previous.generation:
					continue
				var rate: float = NPC_BRAKING if current.speed < previous.speed else NPC_ACCELERATION
				if absf(current.speed - previous.speed) > rate * delta + 0.00001:
					physical_failures.append("nonphysical acceleration at substep %d" % substep_count)
				var expected_y: float = previous.y + (player_speed - current.speed) * Config.ROAD_SCROLL_MULTIPLIER * delta
				if absf(current.y - expected_y) > 0.00001:
					physical_failures.append("nonphysical position at substep %d" % substep_count)
		var sample := {"substep":substep_count,"player_speed":player_speed,"player_lane":player_lane,"dt":delta,"before":before,"after":after,"wall":has_full_lane_wall(),"overlap":has_vehicle_overlap()}
		history.append(sample)
		if history.size() > 7:
			history.pop_front()
		if first_wall_substep < 0 and sample.wall:
			first_wall_substep = substep_count
			wall_witness = history.duplicate(true)
		substep_count += 1
	func _snapshot() -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for vehicle in vehicles:
			result.append({"id":vehicle.get_instance_id(),"generation":vehicle.motion_generation,"kind":vehicle.kind,"lane":vehicle.lane,"pos":vehicle.lane_position,"target":vehicle.target_lane,"y":vehicle.y,"speed":vehicle.actual_world_speed,"cruise":vehicle.cruise_speed,"warning":vehicle.warning_started,"remaining":vehicle.warning_remaining,"moving":vehicle.change_started,"wall_target":_wall_following_target(vehicle)})
		return result

func _init() -> void:
	var traffic := ObservedTraffic.new(8, Config.ROAD_LANE_COUNT, Config.MIN_SPAWN_DISTANCE, Config.MIN_TRAFFIC_GAP)
	traffic.set_viewport_height(720.0)
	traffic.set_difficulty_stage(3)
	traffic.configure_difficulty(Difficulty.for_index(2))
	for step in 90:
		var lane: int = (8 + int(step / 90)) % Config.ROAD_LANE_COUNT
		traffic.tick(0.1, 560.0, lane)
		if traffic.has_vehicle_overlap():
			failures.append("NPC body overlap at outer step %d" % step)
		if traffic.first_wall_substep >= 0:
			break
	if traffic.first_wall_substep >= 0:
		for sample in traffic.wall_witness:
			print("FAST_WALL_WITNESS ", JSON.stringify(sample))
		failures.append("Seed 8/player 560/hard must preserve wall120 at substep %d" % traffic.first_wall_substep)
	failures.append_array(traffic.physical_failures)
	for failure in failures:
		push_error("FAST_WALL_REGRESSION " + failure)
	print("FAST_WALL_REGRESSION failures=%d substeps=%d" % [failures.size(), traffic.substep_count])
	print("TEST_COMPLETE test_product_fast_wall_regression.gd")
	quit(0 if failures.is_empty() else 1)
