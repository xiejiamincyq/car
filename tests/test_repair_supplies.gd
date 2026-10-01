extends SceneTree
const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main.set_process(false)
	main._reset_run(611)
	main.run.start()
	main.integrity.current = 29
	var steering_before: float = main.integrity.steering_multiplier()
	var player_y: float = main.TrackGeometry.player_y(main.get_viewport_rect().size.y)
	main.repair_supplies.pickups.append(main.FuelPickup.new(1, player_y))
	main._update_repair_pickups(0.0)
	assert(main.integrity.current == 49 and main.integrity.steering_multiplier() > steering_before)
	assert(main.repair_supplies.pickups.is_empty(), "Repairs collect once")
	assert(main.run.coins == 0 and main.run.collisions == 0)
	main.integrity.current = 95
	assert(main.integrity.repair(20) == 5 and main.integrity.current == 100)
	main.integrity.current = 19
	assert(main.integrity.repair(20) == 0, "A failed car must not be resurrected by a late pickup")
	main._reset_run(611)
	main.run.start()
	main.repair_supplies.spawner.spawn_remaining = 0
	var spawn_y: float = main.FuelSpawnDirector.PICKUP_SPAWN_Y
	for lane in range(3): main.fuel_pickups.append(main.FuelPickup.new(lane, spawn_y))
	main._update_repair_pickups(0.0)
	assert(main.repair_supplies.pickups.is_empty(), "Repair spawn must defer when fuel occupies all lanes")
	main.fuel_pickups.clear()
	main.repair_supplies.spawner.spawn_remaining = 0
	main._update_repair_pickups(0.0)
	assert(main.repair_supplies.pickups.size() == 1)
	var pickup = main.repair_supplies.pickups[0]
	assert(main._world_spawn_exclusion_zones().has(Vector2(pickup.lane, pickup.y)), "NPC spawn must reserve repairs")
	main.drive.speed = 200
	var before: float = pickup.y
	main._update_repair_pickups(0.1)
	assert(is_equal_approx(pickup.y-before, 200*main.GameConfig.ROAD_SCROLL_MULTIPLIER*0.1), "Repairs are world stationary, like the road and fuel")
	main._pause_run()
	before = pickup.y
	var timer: float = main.repair_supplies.spawner.spawn_remaining
	main._process(0.5)
	assert(pickup.y == before and main.repair_supplies.spawner.spawn_remaining == timer, "Pause must freeze repair movement and generation")
	main._reset_run(611)
	assert(main.repair_supplies.pickups.is_empty())
	main.free()
	quit()
