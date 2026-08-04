extends SceneTree

const TrafficVehicle = preload("res://scripts/traffic_vehicle.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")
const PassEventResolver = preload("res://scripts/pass_event_resolver.gd")

func _init() -> void:
	var collision_edge := _complete_pass(PassEventResolver.COLLISION_LATERAL_DISTANCE, false, TrafficDirector.Kind.STEADY_SLOW)
	assert(collision_edge.overtake and not collision_edge.near_miss, "The collision boundary itself must not count as a near miss")
	var near_edge := _complete_pass(PassEventResolver.COLLISION_LATERAL_DISTANCE + 0.01, false, TrafficDirector.Kind.STEADY_SLOW)
	assert(near_edge.overtake and near_edge.near_miss, "Just outside collision range must count as a near miss")
	var far_edge := _complete_pass(PassEventResolver.NEAR_MISS_LATERAL_DISTANCE, false, TrafficDirector.Kind.SIGNAL_CHANGE)
	assert(far_edge.near_miss, "The inclusive near-miss boundary must reward the pass")
	var too_far := _complete_pass(PassEventResolver.NEAR_MISS_LATERAL_DISTANCE + 0.01, false, TrafficDirector.Kind.STEADY_SLOW)
	assert(too_far.overtake and not too_far.near_miss, "A safe distant pass must only award an overtake")

	var collided := _complete_pass(70.0, true, TrafficDirector.Kind.STEADY_SLOW)
	assert(not collided.overtake and not collided.near_miss, "A collided vehicle must award nothing")
	var fast := _complete_pass(70.0, false, TrafficDirector.Kind.FAST_OVERTAKE)
	assert(not fast.overtake and not fast.near_miss, "A rear fast overtaker must not be mistaken for a player overtake")
	var truck := TrafficVehicle.new(TrafficDirector.Kind.TRUCK, 1, 390.0)
	PassEventResolver.observe(truck, TrafficDirector.Kind.TRUCK, 500.0, 0.0, 110.0)
	truck.y = 500.0 + PassEventResolver.PASS_SETTLEMENT_DISTANCE + truck.half_length - TrafficVehicle.NORMAL_HALF_LENGTH
	assert(not PassEventResolver.observe(truck, TrafficDirector.Kind.TRUCK, 500.0, 0.0, 110.0).overtake, "A truck may not settle while its longer rear body is still alongside the player")
	truck.y += 0.01
	assert(PassEventResolver.observe(truck, TrafficDirector.Kind.TRUCK, 500.0, 0.0, 110.0).overtake, "A truck must settle immediately after its actual rear edge clears")

	var vehicle := TrafficVehicle.new(TrafficDirector.Kind.STEADY_SLOW, 1, 400.0)
	PassEventResolver.observe(vehicle, TrafficDirector.Kind.STEADY_SLOW, 500.0, 0.0, 70.0)
	vehicle.y = 500.0
	PassEventResolver.observe(vehicle, TrafficDirector.Kind.STEADY_SLOW, 500.0, 0.0, 70.0)
	vehicle.y = 600.0
	var first := PassEventResolver.observe(vehicle, TrafficDirector.Kind.STEADY_SLOW, 500.0, 0.0, 70.0)
	var repeated := PassEventResolver.observe(vehicle, TrafficDirector.Kind.STEADY_SLOW, 500.0, 0.0, 70.0)
	assert(first.overtake and first.near_miss and not repeated.overtake and not repeated.near_miss, "Each vehicle may settle pass events only once")

	var simulation_a := _simulate_300_seconds()
	var simulation_b := _simulate_300_seconds()
	assert(simulation_a == simulation_b, "A fixed 300-second pass sequence must produce deterministic statistics")
	assert(simulation_a.overtakes > 0 and simulation_a.near_misses > 0 and simulation_a.near_misses <= simulation_a.overtakes and simulation_a.overtakes < 100, "The 300-second statistics must exclude collisions and remain internally plausible")
	quit()

func _complete_pass(lateral_distance: float, collided: bool, kind: int) -> Dictionary:
	var vehicle := TrafficVehicle.new(kind, 1, 400.0)
	vehicle.collided_with_player = collided
	PassEventResolver.observe(vehicle, kind, 500.0, 0.0, lateral_distance)
	vehicle.y = 500.0
	PassEventResolver.observe(vehicle, kind, 500.0, 0.0, lateral_distance)
	vehicle.y = 600.0
	return PassEventResolver.observe(vehicle, kind, 500.0, 0.0, lateral_distance)

func _simulate_300_seconds() -> Dictionary:
	var overtakes := 0
	var near_misses := 0
	for second in range(300):
		if second % 3 != 0:
			continue
		var pass_index := second / 3
		var lateral_distance := 70.0 if pass_index % 2 == 0 else 110.0
		var event := _complete_pass(lateral_distance, pass_index % 5 == 0, TrafficDirector.Kind.STEADY_SLOW)
		overtakes += 1 if event.overtake else 0
		near_misses += 1 if event.near_miss else 0
	return {"overtakes": overtakes, "near_misses": near_misses}
