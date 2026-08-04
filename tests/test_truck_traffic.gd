extends SceneTree

const GameConfig = preload("res://scripts/game_config.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	var director := TrafficDirector.new(317)
	var car = director.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 1, 100.0)
	var truck = director.acquire_vehicle(TrafficDirector.Kind.TRUCK, 1, 100.0)
	assert(truck.half_length > car.half_length and truck.half_width > car.half_width, "A truck must have a genuinely larger body than a car")
	assert(truck.target_lane == truck.lane, "Trucks must never schedule a lane change")
	var car_collision_distance := GameConfig.COLLISION_LONGITUDINAL_DISTANCE
	var truck_collision_distance := director.collision_distance_for(truck)
	assert(truck_collision_distance > car_collision_distance, "Truck collision distance must include its longer body")
	assert(director.vehicles_have_minimum_gap(car, truck, director.minimum_lane_gap + car.half_length + truck.half_length), "Exact edge clearance must be accepted")
	assert(not director.vehicles_have_minimum_gap(car, truck, director.minimum_lane_gap + car.half_length + truck.half_length - 0.01), "A sub-boundary truck gap must be rejected")

	for stage in range(3):
		var early := TrafficDirector.new(900 + stage)
		early.set_difficulty_stage(stage)
		for _tick in range(240):
			early.tick(0.25, 560.0, 1)
			for vehicle in early.vehicles:
				assert(vehicle.kind != TrafficDirector.Kind.TRUCK, "Trucks may not appear before the final stage")
	var late := TrafficDirector.new(317)
	late.set_difficulty_stage(3)
	var saw_truck := false
	for _tick in range(480):
		late.tick(0.25, 560.0, 1)
		assert(late.all_active_spawns_are_fair(), "Truck spawns must preserve the reaction and escape-lane invariants")
		for vehicle in late.vehicles:
			saw_truck = saw_truck or vehicle.kind == TrafficDirector.Kind.TRUCK
	assert(saw_truck, "The final-stage deterministic schedule must actually introduce trucks")
	quit()
