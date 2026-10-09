extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")
const Difficulty = preload("res://scripts/difficulty_profile.gd")
const SEEDS := [611,2026,9001,616,618]
var failures: Array[String] = []

func _init() -> void:
	var totals: Array[float] = [0.0,0.0,0.0]
	var normal_totals: Array[float] = [0.0,0.0,0.0]
	for seed_value in SEEDS:
		for index in 3:
			_sample(seed_value,index,totals,normal_totals)
	# Density is a seeded population statistic, not a per-event guarantee. Keep
	# all frozen seeds. Separate normal traffic density from the fast event's
	# speed-dependent screen residency: 450 changes residency, not spawn capacity.
	# Keep every original all-car observation and require its monotonic gradient.
	_check(totals[1] > totals[0] and totals[2] > totals[1], "All-car visible density remains monotonic across difficulties")
	_check(normal_totals[1] >= normal_totals[0] * 1.15 and normal_totals[2] >= normal_totals[1] * 1.15, "Actual ordinary traffic density across all frozen matrix seeds must differ by at least 15%")
	print("DIFFICULTY_GRADIENT_TOTAL ",JSON.stringify({"seeds":SEEDS,"visible_car_seconds":totals,"normal_visible_car_seconds":normal_totals}))
	for failure in failures: push_error(failure)
	print("TEST_COMPLETE test_product_difficulty_gradient.gd")
	quit(0 if failures.is_empty() else 1)

func _sample(seed_value: int,index: int,totals: Array[float],normal_totals: Array[float]) -> void:
		var profile := Difficulty.for_index(index)
		var director := Traffic.new(seed_value)
		director.configure_difficulty(profile)
		_check(director.target_active_vehicles == [3, 5, 7][index], "Difficulty must change actual traffic capacity")
		_check(director.target_active_vehicles < director.max_active_vehicles, "Pool must retain spare capacity")
		var visible_seconds := 0.0
		var normal_seconds := 0.0
		for step in 2700:
			director.set_difficulty_stage(mini(3, int(step / 675)))
			director.tick(1.0 / 60.0, 760.0, 1)
			for vehicle in director.vehicles:
				if vehicle.y > 0.0 and vehicle.y < 720.0:
					visible_seconds += 1.0 / 60.0
					if vehicle.kind != Traffic.Kind.FAST_OVERTAKE: normal_seconds += 1.0 / 60.0
			_check(not director.has_vehicle_overlap() and not director.has_full_lane_wall(), "Difficulty preserves body and wall safety")
		totals[index] += visible_seconds
		normal_totals[index] += normal_seconds
		print("DIFFICULTY_GRADIENT ", JSON.stringify({"seed":seed_value,"difficulty":index,"visible_car_seconds":visible_seconds,"normal_visible_car_seconds":normal_seconds,"spawn_sequence":director.spawn_sequence()}))

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
