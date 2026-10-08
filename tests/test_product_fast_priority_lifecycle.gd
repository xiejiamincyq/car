extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
var failures: Array[String] = []
class NormalBirths extends Traffic:
	func _kind_for_next_spawn() -> int: return Kind.STEADY_SLOW

func _init() -> void:
	var host = NormalBirths.new(42)
	host._player_speed = 200.0
	host._player_lane = 2
	var red = host.acquire_vehicle(2,0,200.0,920.0)
	red.arrival_warning_started = true
	host.vehicles.append(red)
	host.fast_priority.refresh(host.vehicles)
	host._spawn_next(200.0,2)
	_check(host.vehicles.size() == 2,"after red clears the player, non-conflicting traffic resumes before top retirement")
	for actor in host.vehicles:
		if actor != red: _check(actor.lane != 0,"post-pass new traffic still yields the reserved red corridor")
	_check(not host.has_vehicle_overlap() and not host.has_full_lane_wall(),"post-pass admission keeps body and wall safety")
	host.reset()
	_check(not host.fast_priority.active() and not host.lane_events.scheduling_paused,"reset releases the entire event")
	# A retained pooled identity must not donate priority to a later normal car.
	red = host.acquire_vehicle(2,0,650.0)
	host.vehicles.append(red)
	host.fast_priority.refresh(host.vehicles)
	red.configure(0,1,100.0,1,0,200.0)
	host.fast_priority.refresh(host.vehicles)
	_check(not host.fast_priority.active(),"pooled motion generation changes invalidate the owner")
	# If another clear lane takes less time than the leader's yielding manoeuvre,
	# priority must not turn into a forced wait behind that leader.
	host = NormalBirths.new(42)
	host._spawn_cooldown = 1000.0
	host.lane_events.enabled = false
	var leader = host.acquire_vehicle(0,1,200.0,200.0)
	red = host.acquire_vehicle(2,1,650.0,920.0)
	red.actual_world_speed = 200.0
	red.arrival_warning_started = true
	host.vehicles.assign([leader,red])
	for step in 60: host.tick(1.0/60.0,200.0,0)
	_check(red.lane == 2,"a clear adjacent route faster than yielding is taken within 1s, not forced queueing")
	for message in failures: push_error("FAST_PRIORITY_LIFECYCLE "+message)
	print("TEST_COMPLETE test_product_fast_priority_lifecycle.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
