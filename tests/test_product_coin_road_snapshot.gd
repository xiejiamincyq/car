extends SceneTree

# Controlled geometry fixture, actual Main/traffic/construction impact. This
# is not a natural seed or an automated-playability claim.
const MainScene = preload("res://scenes/main.tscn")
const Config = preload("res://scripts/game_config.gd")
const Coin = preload("res://scripts/coin_pickup.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
var failures: Array[String] = []

class CoinInputs extends "res://scripts/coin_gameplay_director.gd":
	var entry := Vector2.ZERO
	var slope := 0.0
	func tick(delta: float, player_speed: float, player_lane: int, viewport_height: float, npc_zones: Array, fuel_zones: Array,
		construction_zones: Array, blocked_lanes: Array[int], entry_lane_range: Vector2 = Vector2(-INF, INF), maximum_lane_slope: float = INF) -> bool:
		entry = entry_lane_range
		slope = maximum_lane_slope
		return super.tick(delta, player_speed, player_lane, viewport_height, npc_zones, fuel_zones, construction_zones, blocked_lanes, entry_lane_range, maximum_lane_slope)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for delta in [0.1, 0.5]:
		await _frame_case(delta, false)
		await _frame_case(delta, true)
	await _boundary_cases()
	for failure in failures:
		push_error("COIN_ROAD_SNAPSHOT " + failure)
	print("COIN_ROAD_SNAPSHOT failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_coin_road_snapshot.gd")
	quit(0 if failures.is_empty() else 1)

func _frame_case(delta: float, construction: bool) -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main.set_process(false)
	main.difficulty_index = 0
	main._reset_run(9001)
	main.run.start()
	main.run.distance = 1000.0
	main.drive.speed = 200.0
	main.traffic._spawn_cooldown = 1000.0
	main.traffic.lane_events.enabled = construction
	main.coin_director = CoinInputs.new(9001)
	main.coin_director.spawn_distance_remaining = 99999.0
	var coin = Coin.new(99001, 0.0, 100.0)
	var fuel = main.FuelPickup.new(0, -100.0)
	var repair = main.FuelPickup.new(2, -200.0)
	main.coin_director.coins.append(coin)
	main.fuel_pickups.append(fuel)
	main.repair_supplies.pickups.append(repair)
	# Independent input arithmetic; never infer expected advance from the
	# post-impact speed or a new field added by the fix.
	var speed_before_impact: float = 200.0 - main.drive.rolling_resistance * delta
	var expected: float = speed_before_impact * Config.ROAD_SCROLL_MULTIPLIER * delta
	var road_before: float = main.ROAD_MARK_REPEAT_DISTANCE - 10.0
	main.road_scroll = road_before
	var core_before := 0.0
	if construction:
		var event = main.traffic.lane_events
		event.begin_warning(1)
		event.state = event.State.CLOSED
		core_before = main.TrackGeometry.player_y(720.0) - 30.0 - expected
		event._travel_distance = core_before + Config.LANE_EVENT_CORE_TRAVEL_MARGIN + Config.LANE_EVENT_TAPER_CONE_SPACING * (Config.LANE_EVENT_TAPER_CONE_COUNT - 1) + Config.LANE_EVENT_CORE_GAP
	main._process(delta)
	var actual: float = coin.y - 100.0
	print("COIN_ROAD_FRAME ", JSON.stringify({"controlled_fixture":true,"construction":construction,"delta":delta,
		"expected":expected,"coin_advance":actual,"fuel_advance":fuel.y+100.0,"repair_advance":repair.y+200.0,
		"speed_before_impact":speed_before_impact,"speed_after_impact":main.drive.speed,"collisions":main.run.collisions}))
	_check(main.run.phase == main.RunState.Phase.RUNNING, "fixture survives actual impact")
	_check(main.persistence_enabled == false and current_scene == null, "fixture cannot access formal save")
	_check(absf(actual - expected) < 0.0001, "coin follows actual ground advance, construction=%s dt=%s" % [construction,delta])
	_check(absf(main.coin_director.spawn_distance_remaining - (99999.0 - expected)) < 0.0001, "coin distance clock uses same ground advance, construction=%s dt=%s" % [construction,delta])
	_check(absf(fuel.y + 100.0 - expected) < 0.0001 and absf(repair.y + 200.0 - expected) < 0.0001, "supplies remain on ground")
	_check(absf(main.road_scroll - fposmod(road_before + expected, main.ROAD_MARK_REPEAT_DISTANCE)) < 0.0001, "road wraps without losing unwrapped travel")
	_check(coin.world_speed == 0.0, "coin remains world speed zero")
	var lane_width: float = Config.ROAD_HALF_WIDTH * 2.0 / Config.ROAD_LANE_COUNT
	var worst_speed: float = maxf(main.drive.speed, (main.drive.max_speed + Config.OVERDRIVE_SPEED_BONUS) * main.integrity.max_speed_multiplier())
	var lateral: float = main.drive.steering_speed * 0.85 * main.integrity.steering_multiplier()
	var reach := (lateral * maxf(0.0, (592.0 - 20.0) / (worst_speed * Config.ROAD_SCROLL_MULTIPLIER) - 0.2) + Config.COIN_PICKUP_LATERAL_DISTANCE * 0.9) / lane_width
	_check(absf(main.coin_director.entry.x - (1.0 - reach)) < 0.0001 and absf(main.coin_director.entry.y - (1.0 + reach)) < 0.0001, "route entry uses current post-impact hull/ability")
	_check(absf(main.coin_director.slope - lateral * 0.9 / (worst_speed * Config.ROAD_SCROLL_MULTIPLIER * lane_width)) < 0.000001, "route slope does not use equivalent ground motion speed")
	if construction:
		_check(main.run.collisions == 1 and main.drive.speed < speed_before_impact, "real construction collision reduces speed once")
		_check(absf(main.traffic.lane_events.core_markers(720.0)[0].y - core_before - expected) < 0.001, "construction core advances with the ground")
	else:
		_check(main.run.collisions == 0 and absf(main.drive.speed - speed_before_impact) < 0.0001, "ordinary frame has no synthetic collision")
	await _retire(main)

func _boundary_cases() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main.set_process(false)
	main._reset_run(611)
	main.run.start()
	main.traffic._spawn_cooldown = 1000.0
	main.traffic.lane_events.enabled = false
	main.drive.speed = 200.0
	main.coin_director.spawn_distance_remaining = 0.0
	main._process(0.5)
	_check(main.coin_director.spawned_route_count == 1 and not main.coin_director.coins.is_empty(), "actual Main births a bounded route")
	var nearest := -INF
	for coin in main.coin_director.coins:
		nearest = maxf(nearest, coin.y)
	_check(nearest == Config.COIN_ROUTE_SPAWN_Y, "newborn route does not move before birth")
	_check(main.coin_director.spawn_distance_remaining == Config.COIN_ROUTE_INTERVAL_DISTANCE, "successful birth starts full distance interval")
	var coin = main.coin_director.coins[0]
	var before: float = coin.y
	var advance: float = (main.drive.speed - main.drive.rolling_resistance * 0.1) * Config.ROAD_SCROLL_MULTIPLIER * 0.1
	main._process(0.1)
	_check(absf(coin.y - before - advance) < 0.0001, "newborn moves only on following real frame")
	_check(absf(main.coin_director.spawn_distance_remaining - Config.COIN_ROUTE_INTERVAL_DISTANCE + advance) < 0.0001, "distance resumes only after real birth")
	for mode in ["zero_time", "parked", "paused", "countdown"]:
		main.run.phase = main.RunState.Phase.RUNNING
		main.drive.speed = 200.0
		if mode == "parked": main.drive.speed = 0.0
		if mode == "paused": main._pause_run()
		if mode == "countdown":
			main.run.phase = main.RunState.Phase.TITLE
			main.run.begin_countdown()
		before = coin.y
		var timer: float = main.coin_director.spawn_distance_remaining
		var births: int = main.coin_director.spawned_route_count
		main._process(0.0 if mode == "zero_time" else 0.1)
		_check(coin.y == before and main.coin_director.spawn_distance_remaining == timer and main.coin_director.spawned_route_count == births, "no coin movement or distance accrual for %s" % mode)
	main.run.phase = main.RunState.Phase.RUNNING
	main.drive.speed = 123.0
	before = coin.y
	main._update_coins(0.1)
	_check(absf(coin.y - before - 123.0 * Config.ROAD_SCROLL_MULTIPLIER * 0.1) < 0.0001, "existing direct-call contract still uses current speed")
	await _retire(main)

func _retire(main) -> void:
	var refs: Array[WeakRef] = AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, refs), "fixture audio retires")

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
