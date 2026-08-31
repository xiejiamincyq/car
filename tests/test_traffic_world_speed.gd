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

	var crowded := TrafficDirector.new(614)
	crowded.set_viewport_height(720.0)
	crowded._player_lane = 1
	crowded._player_speed = 500.0
	var crowded_npc = crowded.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 1, 500.0, 200.0)
	var left_blocker = crowded.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 0, 592.0, 200.0)
	var right_blocker = crowded.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 2, 592.0, 200.0)
	crowded.vehicles.assign([crowded_npc, left_blocker, right_blocker])
	var crowded_start_y: float = crowded_npc.y
	crowded.update_vehicle(crowded_npc, 0.1, 500.0)
	assert(is_equal_approx(crowded_npc.y - crowded_start_y, (500.0 - 200.0) * GameConfig.ROAD_SCROLL_MULTIPLIER * 0.1), "Safety rules must not overwrite an NPC's fixed world speed when nearby lanes are occupied")

	var merge_guard := TrafficDirector.new(615)
	merge_guard.set_viewport_height(720.0)
	merge_guard._player_lane = 0
	merge_guard._player_speed = 360.0
	var unsafe_changer = merge_guard.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 0, 530.0, 200.0)
	unsafe_changer.target_lane = 1
	unsafe_changer.warning_started = true
	unsafe_changer.warning_remaining = 0.5
	merge_guard.vehicles.append(unsafe_changer)
	merge_guard.update_vehicle(unsafe_changer, 0.1, 360.0)
	assert(not unsafe_changer.lane_change_enabled and unsafe_changer.target_lane == unsafe_changer.lane, "A warned lane change must be cancelled before it reserves the player's final escape lane")

	var spawn_guard := TrafficDirector.new(616)
	var faster_follower = spawn_guard.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 0, 0.0, 220.0)
	faster_follower.spawn_was_fair = true
	spawn_guard.vehicles.append(faster_follower)
	var slower_ahead = spawn_guard.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 0, -620.0, 180.0)
	assert(not spawn_guard._can_spawn_candidate(slower_ahead, 220.0, 1), "Spawning must reject an NPC speed order that would close the safe gap before either vehicle recycles")
	faster_follower.cruise_speed = 180.0
	var faster_ahead = spawn_guard.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 0, -620.0, 220.0)
	assert(spawn_guard._can_spawn_candidate(faster_ahead, 500.0, 1), "Spawning may accept an NPC speed order whose road-space gap can only grow")
	faster_follower.cruise_speed = 200.0
	var truck_ahead = spawn_guard.acquire_vehicle(TrafficDirector.Kind.TRUCK, 0, -620.0, 160.0)
	assert(spawn_guard._can_spawn_candidate(truck_ahead, 500.0, 1), "A slower truck may spawn when the leading vehicle will recycle before a faster follower can close the safe gap")

	var warning_guard := TrafficDirector.new(617)
	warning_guard._player_speed = 560.0
	var warned_fast = warning_guard.acquire_vehicle(TrafficDirector.Kind.FAST_OVERTAKE, 0, 592.0, 920.0)
	warned_fast.overtake_warning_remaining = 1.0
	warning_guard.vehicles.append(warned_fast)
	assert(warning_guard.reachable_player_lanes(1, 592.0, 72.0).has(0), "A warned fast car must not count as an immediate collision before it is released")
	assert(not warning_guard.reachable_player_lanes(1, 592.0, warning_guard.braking_reaction_clearance(560.0)).has(0), "Route planning must reserve the warned fast car's lane before steering the player into it")
	var slowest_truck_speed := TrafficDirector.NORMAL_SPEED_MIN * TrafficDirector.TrafficVehicle.TRUCK_CRUISE_SPEED_MULTIPLIER
	var truck_closing_speed := 560.0 - slowest_truck_speed
	var expected_braking_clearance := GameConfig.COLLISION_LONGITUDINAL_DISTANCE + truck_closing_speed * TrafficDirector.BRAKING_REACTION_SECONDS * GameConfig.ROAD_SCROLL_MULTIPLIER + truck_closing_speed * truck_closing_speed / (2.0 * GameConfig.BRAKING) * GameConfig.ROAD_SCROLL_MULTIPLIER
	assert(is_equal_approx(warning_guard.braking_reaction_clearance(560.0), expected_braking_clearance), "Reaction planning must use the actual slowest sampled truck speed")

	var frame_guard := TrafficDirector.new(618)
	frame_guard._spawn_cooldown = 100.0
	var already_in_lane = frame_guard.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 1, 507.0, 220.0)
	already_in_lane.lane_change_enabled = false
	already_in_lane.spawn_was_fair = true
	var merging_same_frame = frame_guard.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 0, 346.0, 220.0)
	merging_same_frame.target_lane = 1
	merging_same_frame.warning_started = true
	merging_same_frame.warning_remaining = 0.0
	merging_same_frame.spawn_was_fair = true
	frame_guard.vehicles.assign([already_in_lane, merging_same_frame])
	frame_guard.tick(1.0, 360.0, 2)
	assert(merging_same_frame.lane == 0 and not merging_same_frame.change_started, "Lane-change safety must compare one coherent frame instead of mixing another NPC's new position with this NPC's old position")

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
		assert(speed_a >= TrafficDirector.NORMAL_SPEED_MIN and speed_a <= TrafficDirector.NORMAL_SPEED_MAX, "Normal NPC world speeds must stay near the 200 target")
		sampled_speeds.append(speed_a)
	assert(sampled_speeds.min() < sampled_speeds.max(), "Traffic must contain more than one fixed world speed so the player can catch different vehicles")

	quit()
