extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Coin = preload("res://scripts/coin_pickup.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,720)
	var main = Main.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main.set_process(false)
	for lane in 3:
		for seed_value in range(1,13):
			main._reset_run(seed_value)
			main.run.start()
			main.drive.speed = 200.0
			main.drive.lateral_position = (lane - 1) * 260.0
			main.traffic.lane_events.enabled = false
			var red = main.traffic.acquire_vehicle(main.traffic.Kind.FAST_OVERTAKE,lane,650.0)
			red.actual_world_speed = 200.0
			main.traffic.vehicles.append(red)
			main.traffic.fast_priority.refresh(main.traffic.vehicles)
			for other_lane in 3:
				if other_lane != lane:
					main.traffic.vehicles.append(main.traffic.acquire_vehicle(0,other_lane,-90.0,200.0))
			var fuel = main.FuelPickup.new(lane,200.0)
			var repair = main.FuelPickup.new(lane,300.0)
			main.fuel_pickups.append(fuel)
			main.repair_supplies.pickups.append(repair)
			main.fuel_spawn_director.spawn_remaining = 0.0
			main.repair_supplies.spawner.spawn_remaining = 0.0
			main._update_fuel_pickups(0.01)
			main._update_repair_pickups(0.01)
			_check(main.fuel_pickups.size() == 1 and main.repair_supplies.pickups.size() == 1,"new supplies defer when the only reachable lane belongs to red priority")
			_check(main.fuel_pickups.has(fuel) and main.repair_supplies.pickups.has(repair),"existing supplies remain, not cleared for red priority")
			_check(is_equal_approx(fuel.y,202.3) and is_equal_approx(repair.y,302.3),"existing supply motion remains grounded")
			main.traffic.vehicles.assign([red])
			var existing = Coin.new(999,lane,200.0,99)
			main.coin_director.coins.append(existing)
			main._update_coins(0.01)
			for coin in main.coin_director.coins:
				if coin != existing:
					_check(absf(coin.lane_position - lane) > 0.5,"new coin guidance avoids the red priority corridor")
			_check(main.coin_director.coins.has(existing) and is_equal_approx(existing.y,202.3),"existing coins stay grounded and are not erased")
	main.traffic.reset()
	_check(main.traffic.fast_priority_lanes().is_empty() and not main.traffic.lane_events.scheduling_paused,"restart releases priority and construction admission")
	var refs: Array[WeakRef] = AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self,refs),"isolated pickup test releases audio")
	for message in failures: push_error("FAST_PRIORITY_PICKUPS "+message)
	print("FAST_PRIORITY_PICKUPS cases=36 failures=",failures.size())
	print("TEST_COMPLETE test_product_fast_priority_pickups.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
