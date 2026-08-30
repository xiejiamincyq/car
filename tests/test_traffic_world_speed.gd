extends SceneTree

const GameConfig = preload("res://scripts/game_config.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	var director := TrafficDirector.new(611)
	var npc = director.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 1, 300.0, 200.0)
	var starting_y: float = npc.y
	director.update_vehicle(npc, 1.0, 100.0)
	assert(is_equal_approx(npc.y, starting_y + (100.0 - 200.0) * GameConfig.ROAD_SCROLL_MULTIPLIER), "Braking below an NPC's world speed must make the player fall behind it")
	var y_after_braking: float = npc.y
	director.update_vehicle(npc, 1.0, 500.0)
	assert(is_equal_approx(npc.y, y_after_braking + (500.0 - 200.0) * GameConfig.ROAD_SCROLL_MULTIPLIER), "Accelerating above an NPC's world speed must let the player catch and pass it")
	assert(is_equal_approx(npc.cruise_speed, 200.0), "An NPC's assigned world speed must stay fixed while the player changes speed")

	var hard_director := TrafficDirector.new(612)
	hard_director.set_difficulty_stage(3)
	var hard_npc = hard_director.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 1, 300.0, 200.0)
	hard_director.update_vehicle(hard_npc, 1.0, 500.0)
	assert(is_equal_approx(hard_npc.y, 300.0 + (500.0 - 200.0) * GameConfig.ROAD_SCROLL_MULTIPLIER), "Difficulty must not rewrite the physics of an NPC's fixed world speed")

	var overtaker = director.acquire_vehicle(TrafficDirector.Kind.FAST_OVERTAKE, 1, 600.0, 920.0)
	overtaker.overtake_warning_remaining = 0.0
	var overtaker_y: float = overtaker.y
	director.update_vehicle(overtaker, 0.1, 760.0)
	assert(is_equal_approx(overtaker.y, overtaker_y + (760.0 - 920.0) * GameConfig.ROAD_SCROLL_MULTIPLIER * 0.1), "Fast traffic must use its own fixed world speed instead of a player-speed-derived animation speed")
	assert(is_equal_approx(overtaker.cruise_speed, 920.0), "Fast traffic must keep its assigned world speed")

	var speed_rng_a := TrafficDirector.new(613)
	var speed_rng_b := TrafficDirector.new(613)
	var sampled_speeds: Array[float] = []
	for _index in range(8):
		var speed_a: float = speed_rng_a._world_speed_for_spawn(TrafficDirector.Kind.STEADY_SLOW)
		var speed_b: float = speed_rng_b._world_speed_for_spawn(TrafficDirector.Kind.STEADY_SLOW)
		assert(is_equal_approx(speed_a, speed_b), "A fixed run seed must reproduce every NPC's assigned world speed")
		assert(speed_a >= 180.0 and speed_a <= 220.0, "Normal NPC world speeds must stay near the 200 target")
		sampled_speeds.append(speed_a)
	assert(sampled_speeds.min() < sampled_speeds.max(), "Traffic must contain more than one fixed world speed so the player can catch different vehicles")

	quit()
