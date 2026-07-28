extends SceneTree

const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	for seed in range(1, 11):
		var director = TrafficDirector.new(seed)
		for _second in range(30):
			director.tick(1.0, 500.0, 1)
			assert(director.all_active_spawns_are_fair(), "Each of ten fixed seeds must keep actual spawns fair for 15 seconds")

	var director = TrafficDirector.new(73)
	for _second in range(300):
		director.tick(1.0, 500.0, 1)
	assert(director.vehicles.size() <= director.max_active_vehicles, "Five minutes must keep active traffic bounded")
	assert(director.allocated_vehicle_count <= director.max_active_vehicles, "Traffic must reuse a bounded object pool")

	director.reset()
	var changer = director.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 1, 120.0)
	director.vehicles.append(changer)
	director.update_vehicle(changer, 0.1, 500.0)
	assert(changer.warning_remaining > 0.0, "Lane-change warning must begin while the car is visible")
	assert(abs(changer.target_lane - changer.lane) == 1, "Lane change must only target an adjacent lane")
	assert(director.is_lane_change_safe(changer), "Lane change target must be safe before the move")
	changer.warning_remaining = 0.01
	director.update_vehicle(changer, 0.1, 500.0)
	assert(changer.change_started, "Lane change must begin after its visible warning")
	assert(changer.lane_position != float(changer.lane), "Lane change must move smoothly instead of jumping lanes")

	var overtaker = director.acquire_vehicle(TrafficDirector.Kind.FAST_OVERTAKE, 0, 820.0)
	director.update_vehicle(overtaker, 1.0, 760.0)
	assert(overtaker.overtake_warning_remaining >= 1.0, "Fast overtaker must warn for at least one visible second before collision risk")
	assert(director.is_fast_spawn_fair(760.0, 1), "Fast overtaker must use the player-speed reaction-distance fairness check")

	director.reset()
	assert(director.vehicles.is_empty(), "Restart must clear actual active traffic")
	quit()
