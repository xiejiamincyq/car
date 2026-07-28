extends SceneTree

const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	var first_run = TrafficDirector.new(73)
	var second_run = TrafficDirector.new(73)
	first_run.fill_to_count(8)
	second_run.fill_to_count(8)
	assert(first_run.spawn_signature() == second_run.spawn_signature(), "A fixed seed must reproduce the traffic order")

	for vehicle in first_run.vehicles:
		assert(vehicle.y <= -first_run.minimum_spawn_distance, "Traffic must begin above the safe spawn distance")
		assert(first_run.is_lane_valid(vehicle.lane), "Every spawn must use a valid lane")
	for lane in range(first_run.lane_count):
		assert(first_run.has_minimum_lane_gap(lane), "Cars in one lane must respect the minimum gap")

	var changer = first_run.create_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 1, -700.0)
	first_run.update_vehicle(changer, 0.35, 500.0)
	assert(changer.warning_remaining > 0.0, "Lane changer must show its warning before moving")
	assert(changer.lane == 1, "Lane changer cannot move during its warning")
	first_run.update_vehicle(changer, 0.6, 500.0)
	assert(changer.lane != 1, "Lane changer must move after its warning")

	var slow = first_run.create_vehicle(TrafficDirector.Kind.STEADY_SLOW, 0, -700.0)
	var overtaker = first_run.create_vehicle(TrafficDirector.Kind.FAST_OVERTAKE, 2, -700.0)
	first_run.update_vehicle(slow, 1.0, 500.0)
	first_run.update_vehicle(overtaker, 1.0, 500.0)
	assert(overtaker.y > slow.y, "Fast overtaker must close faster than steady traffic")
	quit()
