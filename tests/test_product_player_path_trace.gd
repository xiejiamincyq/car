extends SceneTree
const Traffic = preload("res://tests/support/observed_player_path_traffic.gd")
const Path = preload("res://tests/support/player_path_oracle.gd")
const Drive = preload("res://scripts/drive_controller.gd")
const Plain = preload("res://scripts/traffic_director.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var traffic = Traffic.new(611)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	traffic.vehicles.append(traffic.acquire_vehicle(0,1,350.0,200.0))
	var frames: Array = []
	var first_raw: Dictionary = {}
	for index in 60:
		traffic.tick(1.0/60.0,800.0,1)
		if index == 0: first_raw = traffic.last_core_step.duplicate(true)
		frames.append(traffic.last_path_frame.duplicate(true))
	_check(not frames[0].is_empty(),"actual substep produces immutable path frame")
	if not frames[0].is_empty():
		_check(frames[0].get("status","") == "valid","complete NPC birth/motion/retirement evidence is accepted")
		_check(frames[0].bodies.size() == 1,"actual NPC is included, not an empty-road success")
		var trace := {"x0":0.0,"y":592.0,"road_half":390.0,"half_x":30.0,"half_y":30.0,"steering_speed":500.0,"max_speed":800.0,"hull":100.0,"frames":frames}
		var witness: Dictionary = Path.find_path(trace)
		_check(witness.status == "witness" and Path.validate_path(trace,witness),"real approaching-car trace has a continuous bypass")
		_check(not Path.validate_path(trace,{"xs":_zeros(61),"controls":_zeros(60)}),"center-lane controls collide with real traffic")
		var replay = Traffic.new(611)
		replay._spawn_cooldown = 1000.0
		replay.lane_events.enabled = false
		replay.vehicles.append(replay.acquire_vehicle(0,1,350.0,200.0))
		var replay_frames: Array = []
		var drive = Drive.new(800.0,800.0,220.0,420.0,500.0,390.0,30.0)
		for index in 60:
			drive.step(1.0/60.0,1.0,0.0,witness.controls[index])
			_check(absf(drive.lateral_position-witness.xs[index+1]) < 0.0000001,"witness input reconstructs real Drive position")
			var lane := clampi(int(floor((drive.lateral_position+390.0)/260.0)),0,2)
			replay.tick(1.0/60.0,drive.speed,lane)
			replay_frames.append(replay.last_path_frame.duplicate(true))
		trace.frames = replay_frames
		_check(Path.validate_path(trace,witness),"witness revalidates against actual player-lane feedback replay")
		var missing := first_raw.duplicate(true)
		missing.npc_final.clear()
		_check(Traffic._frame_from_raw(missing,1.0/60.0,800.0).status == "invalid","missing final NPC never creates an empty-road witness")
		var changed := first_raw.duplicate(true)
		var key: String = changed.npc_final.keys()[0]
		changed.npc_final[key].generation += 1
		_check(Traffic._frame_from_raw(changed,1.0/60.0,800.0).status == "invalid","pooled generation mismatch rejects the trace")
		var duplicate := first_raw.duplicate(true)
		duplicate.npc_births = duplicate.npc_before.duplicate(true)
		_check(Traffic._frame_from_raw(duplicate,1.0/60.0,800.0).status == "invalid","duplicate birth cannot overwrite an existing lifetime")
		var invalid_trace := trace.duplicate(true)
		invalid_trace.frames[0].status = "invalid"
		invalid_trace.frames[0].bodies.clear()
		_check(Path.find_path(invalid_trace).status == "invalid","a rejected raw frame cannot masquerade as clear road")
	var cancelled = Traffic.new(2026)
	cancelled.set_difficulty_stage(1)
	cancelled._spawn_cooldown = 1000.0
	cancelled.lane_events._cooldown_remaining = 0.0
	var occupied = cancelled.acquire_vehicle(0,2,-708.0,200.0)
	occupied.lane_change_enabled = false
	cancelled.vehicles.append(occupied)
	cancelled.tick(1.0/60.0,75.75,0)
	_check(cancelled.aborted_core_birth_count == 1,"unsafe scheduled core is truly unpublished")
	_check(cancelled.last_path_frame.status == "valid" and cancelled.last_path_frame.bodies.size() == 1,"atomic rollback removes phantom core but retains actual NPC")
	var existing: Dictionary = cancelled.last_core_step.duplicate(true)
	existing.core_before = existing.core_births.duplicate(true)
	existing.core_births.clear()
	var existing_frame := Traffic._frame_from_raw(existing,1.0/60.0,75.75)
	_check(existing_frame.status == "valid" and existing_frame.bodies.size() == 2,"existing early-retired core remains physical rather than being discarded as an atomic proposal")
	var observed = Traffic.new(9001)
	var plain = Plain.new(9001)
	for index in 180:
		observed.tick(1.0/60.0,760.0,1)
		plain.tick(1.0/60.0,760.0,1)
		_check(_state(observed) == _state(plain),"path observer leaves RNG, NPC motion and core state unchanged")
	_check(observed.birth_count > 0,"observer equivalence includes actual natural births")
	var closure = _closure()
	var closure_frames: Array = []
	var cone_exposure := 0
	for index in 60:
		closure.tick(1.0/60.0,800.0,1)
		closure_frames.append(closure.last_path_frame.duplicate(true))
		for body in closure.last_path_frame.bodies:
			if body.family == "cone": cone_exposure += 1
	_check(cone_exposure > 0,"real construction trace includes collidable taper cones")
	var closure_trace := {"x0":0.0,"y":592.0,"road_half":390.0,"half_x":30.0,"half_y":30.0,"steering_speed":500.0,"max_speed":800.0,"hull":100.0,"frames":closure_frames}
	var closure_path: Dictionary = Path.find_path(closure_trace)
	_check(closure_path.status == "witness","real whole-lane core has a continuous side route")
	if closure_path.status == "witness":
		var changed_lane := false
		var closure_replay = _closure()
		var replay_drive = Drive.new(800.0,800.0,220.0,420.0,500.0,390.0,30.0)
		var closure_replay_frames: Array = []
		for index in 60:
			replay_drive.step(1.0/60.0,1.0,0.0,closure_path.controls[index])
			var lane := clampi(int(floor((replay_drive.lateral_position+390.0)/260.0)),0,2)
			changed_lane = changed_lane or lane != 1
			closure_replay.tick(1.0/60.0,replay_drive.speed,lane)
			closure_replay_frames.append(closure_replay.last_path_frame.duplicate(true))
		_check(changed_lane,"actual feedback test truly crosses an integer lane boundary")
		closure_trace.frames = closure_replay_frames
		_check(Path.validate_path(closure_trace,closure_path),"actual changed player lane keeps core/cone replay collision free")
	print("PATH_TRACE_COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: print("PATH_TRACE_FAIL "+failure)
	print("TEST_COMPLETE test_product_player_path_trace.gd")
	quit(0 if failures.is_empty() else 1)

func _closure():
	var traffic = Traffic.new(2026)
	traffic._spawn_cooldown = 1000.0
	traffic.set_difficulty_stage(1)
	traffic.lane_events.begin_warning(1)
	traffic.lane_events.state = 2
	traffic.lane_events._travel_distance += 100.0-traffic.lane_events._core_y()
	return traffic

func _zeros(count: int) -> Array:
	var values: Array = []
	values.resize(count)
	values.fill(0.0)
	return values

func _state(traffic) -> Array:
	var values: Array = [traffic.spawn_sequence(),traffic.lane_events.state,traffic.lane_events._travel_distance]
	for vehicle in traffic.vehicles:
		values.append([vehicle.kind,vehicle.lane_position,vehicle.y,vehicle.actual_world_speed,vehicle.cruise_speed,vehicle.warning_remaining,vehicle.change_started])
	return values

func _check(condition: bool,message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
