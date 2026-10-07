extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")
const Difficulty = preload("res://scripts/difficulty_profile.gd")
var failures: Array[String] = []

func _init() -> void:
	var totals: Array[float] = []
	for index in 3:
		var profile := Difficulty.for_index(index)
		var director := Traffic.new(611)
		director.configure_difficulty(profile)
		_check(director.target_active_vehicles == [3, 5, 7][index], "Difficulty must change actual traffic capacity")
		_check(director.target_active_vehicles < director.max_active_vehicles, "Pool must retain spare capacity")
		var visible_seconds := 0.0
		for step in 2700:
			director.set_difficulty_stage(mini(3, int(step / 675)))
			director.tick(1.0 / 60.0, 760.0, 1)
			for vehicle in director.vehicles:
				if vehicle.y > 0.0 and vehicle.y < 720.0: visible_seconds += 1.0 / 60.0
			_check(not director.has_vehicle_overlap() and not director.has_full_lane_wall(), "Difficulty preserves body and wall safety")
		totals.append(visible_seconds)
		print("DIFFICULTY_GRADIENT ", JSON.stringify({"difficulty":index,"visible_car_seconds":visible_seconds,"spawn_sequence":director.spawn_sequence()}))
	_check(totals[1] >= totals[0] * 1.15 and totals[2] >= totals[1] * 1.15, "Actual visible density must differ, not just configuration multipliers")
	for failure in failures: push_error(failure)
	print("TEST_COMPLETE test_product_difficulty_gradient.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
