extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")
func _init() -> void:
	for stage in range(1, 4):
		for seed in range(1, 6):
			var traffic := Traffic.new(seed)
			traffic.set_difficulty_stage(stage)
			for step in range(1200):
				var before: Array = []
				for vehicle in traffic.vehicles:
					before.append({"kind":vehicle.kind,"lane":vehicle.lane,"y":vehicle.y,"actual":vehicle.actual_world_speed})
				traffic.tick(0.1, 560.0, 1)
				if not traffic.all_active_spawns_are_fair():
					var state: Array = []
					for vehicle in traffic.vehicles:
						state.append({"kind":vehicle.kind,"lane":vehicle.lane,"pos":vehicle.lane_position,"y":vehicle.y,"actual":vehicle.actual_world_speed,"desired":vehicle.cruise_speed,"warning":vehicle.warning_started,"moving":vehicle.change_started})
					print("SPAWN_REGRESSION_EVIDENCE ", JSON.stringify({"seed":seed,"stage":stage,"step":step,"before":before,"state":state,"core_y":traffic.lane_events._core_y(),"core_lanes":traffic.lane_events.closed_lanes()}))
					print("TEST_COMPLETE test_product_traffic_spawn_regression.gd")
					quit(1)
					return
	print("TEST_COMPLETE test_product_traffic_spawn_regression.gd")
	quit(0)
