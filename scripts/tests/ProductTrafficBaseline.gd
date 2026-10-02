extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const Drive = preload("res://scripts/drive_controller.gd")
const Overdrive = preload("res://scripts/overdrive_controller.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const Difficulty = preload("res://scripts/difficulty_profile.gd")
const Config = preload("res://scripts/game_config.gd")
const SEEDS := [611, 2026, 9001, 616, 618]
const TRAJECTORIES := ["accelerate", "brake_repass", "overdrive_brake"]
const STEP := 1.0 / 60.0
const SAMPLE_SECONDS := 120.0
const WARMUP_SECONDS := 10.0

# Count production spawn outcomes without changing candidate selection or RNG.
class ObservedTraffic extends Traffic:
	var scheduled_opportunities := 0
	var capacity_skips := 0
	var candidate_attempts := 0
	var accepted := 0
	func _spawn_next(player_speed: float, player_lane: int) -> void:
		scheduled_opportunities += 1
		if vehicles.size() >= target_active_vehicles:
			capacity_skips += 1
		else:
			candidate_attempts += 1
		var before := vehicles.size()
		super._spawn_next(player_speed, player_lane)
		accepted += vehicles.size() - before

func _init() -> void:
	var pilot := OS.get_cmdline_user_args().has("--pilot")
	var cases := 0
	var started := Time.get_ticks_usec()
	print("PRODUCT_TRAFFIC_BASELINE_CONFIG ", JSON.stringify({"seeds":SEEDS, "trajectories":TRAJECTORIES, "step_seconds":STEP, "sample_seconds":SAMPLE_SECONDS, "warmup_seconds":WARMUP_SECONDS, "track":"neon_coast", "car":"pulse_gt", "difficulty":"standard", "player_lane":1, "stage":"floor(seconds/30), capped 3", "scope":"pure traffic model; no player collisions, resource termination, pickup injection or real save I/O; not a playability proof", "pilot":pilot}))
	for seed in SEEDS:
		for trajectory in TRAJECTORIES:
			print("PRODUCT_TRAFFIC_SAMPLE ", JSON.stringify(_sample(seed, trajectory)))
			cases += 1
			if pilot:
				break
		if pilot:
			break
	print("PRODUCT_TRAFFIC_BASELINE_COMPLETE ", JSON.stringify({"cases":cases, "wall_seconds":(Time.get_ticks_usec() - started) / 1000000.0}))
	quit(0)

func _sample(seed: int, trajectory: String) -> Dictionary:
	var traffic := ObservedTraffic.new(seed)
	traffic.configure_track(Tracks.get_by_id(&"neon_coast"))
	traffic.configure_difficulty(Difficulty.for_index(1))
	traffic.set_viewport_height(720.0)
	var drive := Drive.new(Config.START_SPEED, Config.MAX_SPEED, Config.ACCELERATION, Config.BRAKING, Config.STEERING_SPEED, Config.ROAD_HALF_WIDTH)
	var overdrive := Overdrive.new()
	var episodes: Dictionary = {}
	var stats := {"seed":seed, "trajectory":trajectory, "seconds":SAMPLE_SECONDS, "visible_car_seconds":0.0, "empty_seconds":0.0, "longest_empty_seconds":0.0, "longest_empty_after_warmup_seconds":0.0, "warnings":0, "started":0, "completed":0, "cancelled":0, "despawned_unresolved":0, "censored_at_end":0, "max_warning_wait_seconds":0.0, "max_episode_seconds":0.0, "legacy_no_escape_seconds":0.0, "legacy_longest_no_escape_seconds":0.0, "legacy_overlap_frames":0, "legacy_wall_frames":0, "overdrive_activations":0, "brake_frames":0}
	var waits: Array[float] = []
	var resolutions: Array[float] = []
	var empty_run := 0.0
	var empty_after_warmup := 0.0
	var blocked_run := 0.0
	var hazard_printed := false
	stats.independent_sweep_frames = 0
	stats.lateral_bound_violations = 0
	stats.visible_removed = 0
	stats.visible_fast_car_seconds = 0.0
	stats.physical_completed = 0
	stats.definitions_version = 2
	for step in range(roundi(SAMPLE_SECONDS / STEP)):
		var seconds := (step + 1) * STEP
		_apply_input(drive, overdrive, trajectory, step, stats)
		traffic.set_difficulty_stage(mini(3, int(step * STEP / 30.0)))
		var before: Dictionary = {}
		for vehicle in traffic.vehicles:
			before[vehicle.get_instance_id()] = {"generation":vehicle.motion_generation,"x":vehicle.lane_position,"y":vehicle.y,"half_width":vehicle.half_width,"half_length":vehicle.half_length}
		traffic.tick(STEP, drive.speed, 1)
		var visible := 0
		var present: Dictionary = {}
		for vehicle in traffic.vehicles:
			if vehicle.y + vehicle.half_length >= 0.0 and vehicle.y - vehicle.half_length <= 720.0:
				visible += 1
				if vehicle.kind == Traffic.Kind.FAST_OVERTAKE:
					stats.visible_fast_car_seconds += STEP
			if vehicle.last_lateral_distance > Traffic.FAST_LANE_CHANGE_SPEED * STEP + 0.0001:
				stats.lateral_bound_violations += 1
			var identity: int = vehicle.get_instance_id()
			present[identity] = true
			_observe_episode(vehicle, identity, seconds, episodes, stats, waits, resolutions)
		if _independent_body_sweep(before, traffic.vehicles):
			stats.independent_sweep_frames += 1
		for identity in before:
			if not present.has(identity) and float(before[identity].y) + float(before[identity].half_length) >= 0.0 and float(before[identity].y) - float(before[identity].half_length) <= 720.0:
				stats.visible_removed += 1
		for identity in episodes.keys():
			if not present.has(identity):
				if episodes[identity].active:
					stats.despawned_unresolved += 1
					_record_elapsed(episodes[identity], seconds, stats)
				episodes.erase(identity)
		stats.visible_car_seconds += visible * STEP
		empty_run = empty_run + STEP if visible == 0 else 0.0
		if visible == 0:
			stats.empty_seconds += STEP
		stats.longest_empty_seconds = maxf(stats.longest_empty_seconds, empty_run)
		if seconds > WARMUP_SECONDS:
			empty_after_warmup = empty_after_warmup + STEP if visible == 0 else 0.0
			stats.longest_empty_after_warmup_seconds = maxf(stats.longest_empty_after_warmup_seconds, empty_after_warmup)
		# Legacy lane-set availability is only an observed congestion proxy,
		# not the future independent swept/reachable-player safety oracle.
		var blocked: bool = traffic.reachable_player_lanes(1, 592.0, traffic.braking_reaction_clearance(drive.speed)).is_empty()
		blocked_run = blocked_run + STEP if blocked else 0.0
		stats.legacy_no_escape_seconds += STEP if blocked else 0.0
		stats.legacy_longest_no_escape_seconds = maxf(stats.legacy_longest_no_escape_seconds, blocked_run)
		stats.legacy_overlap_frames += 1 if traffic.has_vehicle_overlap() else 0
		stats.legacy_wall_frames += 1 if traffic.has_full_lane_wall() else 0
		if not hazard_printed and (traffic.has_vehicle_overlap() or traffic.has_full_lane_wall()):
			var state: Array = []
			for vehicle in traffic.vehicles:
				state.append({"kind":vehicle.kind,"lane":vehicle.lane,"position":vehicle.lane_position,"previous_position":vehicle.previous_lane_position,"target":vehicle.target_lane,"y":vehicle.y,"previous_y":vehicle.previous_y,"actual":vehicle.actual_world_speed,"desired":vehicle.cruise_speed,"warning":vehicle.warning_started,"moving":vehicle.change_started})
			print("PRODUCT_TRAFFIC_FIRST_HAZARD ", JSON.stringify({"seed":seed,"trajectory":trajectory,"seconds":seconds,"overlap":traffic.has_vehicle_overlap(),"wall":traffic.has_full_lane_wall(),"state":state}))
			hazard_printed = true
	for episode in episodes.values():
		if episode.active:
			stats.censored_at_end += 1
			_record_elapsed(episode, SAMPLE_SECONDS, stats)
	stats.average_visible_cars = stats.visible_car_seconds / SAMPLE_SECONDS
	stats.scheduled_opportunities = traffic.scheduled_opportunities
	stats.capacity_skips = traffic.capacity_skips
	stats.candidate_attempts = traffic.candidate_attempts
	stats.spawned = traffic.accepted
	stats.rejected = traffic.candidate_attempts - traffic.accepted
	stats.rejection_ratio = float(stats.rejected) / maxf(1.0, traffic.candidate_attempts)
	stats.warning_to_start_p95_seconds = _p95(waits)
	stats.resolution_p95_seconds = _p95(resolutions)
	stats.start_wait_sample_count = waits.size()
	stats.resolution_sample_count = resolutions.size()
	stats.started_counter = traffic.lane_change_started_count
	stats.event_count = traffic.lane_events.events_started_count
	stats.terminal_reason = "fixed_simulation_budget_reached"
	return stats

func _apply_input(drive, overdrive, trajectory: String, step: int, stats: Dictionary) -> void:
	var cycle_step := step % 1800
	var accelerate := 1.0
	var brake := 0.0
	if trajectory == "brake_repass":
		# Every 30s: brake at [10,11.25), coast [11.25,14), accelerate otherwise.
		if cycle_step >= 600 and cycle_step < 675:
			accelerate = 0.0
			brake = 1.0
		elif cycle_step >= 675 and cycle_step < 840:
			accelerate = 0.0
	elif trajectory == "overdrive_brake":
		# Two controller edges at 8.0/8.1s, then brake [14,15.5), coast to 18s.
		# Constant supplied fuel isolates traffic, not a fuel-budget assertion.
		if cycle_step == 480 or cycle_step == 486:
			if overdrive.observe_accelerate_press(100.0, 100.0) == Overdrive.ActivationResult.ACTIVATED:
				stats.overdrive_activations += 1
		if cycle_step >= 840 and cycle_step < 930:
			accelerate = 0.0
			brake = 1.0
		elif cycle_step >= 930 and cycle_step < 1080:
			accelerate = 0.0
	overdrive.tick(STEP, 100.0)
	drive.step(STEP, accelerate, brake, 0.0, overdrive.speed_limit_bonus(), overdrive.acceleration_bonus())
	stats.brake_frames += 1 if brake > 0.0 else 0

func _observe_episode(vehicle, identity: int, seconds: float, episodes: Dictionary, stats: Dictionary, waits: Array[float], resolutions: Array[float]) -> void:
	if not episodes.has(identity):
		episodes[identity] = {"active":false, "start":0.0, "movement_start":-1.0, "origin_lane":vehicle.lane}
	var episode: Dictionary = episodes[identity]
	if episode.active:
		_record_elapsed(episode, seconds, stats)
		if vehicle.change_started and episode.movement_start < 0.0:
			episode.movement_start = seconds
			waits.append(seconds - float(episode.start))
			stats.started += 1
		if vehicle.lane != episode.origin_lane or not vehicle.warning_started:
			if vehicle.lane != episode.origin_lane:
				stats.completed += 1
				if not vehicle.change_started and absf(vehicle.lane_position - float(vehicle.target_lane)) <= 0.001:
					stats.physical_completed += 1
			else:
				stats.cancelled += 1
			resolutions.append(seconds - float(episode.start))
			episode.active = false
	if not episode.active and vehicle.warning_started:
		episode.active = true
		episode.start = seconds
		episode.movement_start = -1.0
		episode.origin_lane = vehicle.lane
		stats.warnings += 1

func _record_elapsed(episode: Dictionary, seconds: float, stats: Dictionary) -> void:
	stats.max_episode_seconds = maxf(stats.max_episode_seconds, seconds - float(episode.start))
	if episode.movement_start < 0.0:
		stats.max_warning_wait_seconds = maxf(stats.max_warning_wait_seconds, seconds - float(episode.start))

func _p95(values: Array[float]) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return values[mini(values.size() - 1, ceili(values.size() * 0.95) - 1)]

func _independent_body_sweep(before: Dictionary, vehicles: Array) -> bool:
	# An independent rectangle/slab oracle: no production overlap, lane-set,
	# following, or reservation predicate is called here.
	var lane_width := Config.ROAD_HALF_WIDTH * 2.0 / 3.0
	for first_index in vehicles.size():
		var first = vehicles[first_index]
		var first_id: int = first.get_instance_id()
		if not before.has(first_id) or before[first_id].generation != first.motion_generation:
			continue
		for second_index in range(first_index + 1, vehicles.size()):
			var second = vehicles[second_index]
			var second_id: int = second.get_instance_id()
			if not before.has(second_id) or before[second_id].generation != second.motion_generation:
				continue
			var old_first: Dictionary = before[first_id]
			var old_second: Dictionary = before[second_id]
			var x_interval := _contact_interval((float(old_first.x)-float(old_second.x))*lane_width, (first.lane_position-second.lane_position)*lane_width, first.half_width+second.half_width)
			var y_interval := _contact_interval(float(old_first.y)-float(old_second.y), first.y-second.y, first.half_length+second.half_length)
			if maxf(x_interval.x, y_interval.x) < minf(x_interval.y, y_interval.y) - 0.000001:
				return true
	return false

func _contact_interval(start: float, end: float, radius: float) -> Vector2:
	if is_equal_approx(start, end):
		return Vector2(0.0, 1.0) if absf(start) < radius else Vector2(1.0, 0.0)
	var first := (-radius-start) / (end-start)
	var second := (radius-start) / (end-start)
	return Vector2(maxf(0.0, minf(first, second)), minf(1.0, maxf(first, second)))
