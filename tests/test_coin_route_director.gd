extends SceneTree

const CoinRouteDirector = preload("res://scripts/coin_route_director.gd")
const CoinPickup = preload("res://scripts/coin_pickup.gd")
const FuelPickup = preload("res://scripts/fuel_pickup.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

const ANCHOR_Y := -90.0

func _init() -> void:
	_test_reproducible_bounded_routes()
	_test_all_five_templates()
	_test_hazard_and_closure_exclusion()
	_test_unreachable_routes_delay_safely()
	_test_live_world_exclusion_adapters()
	quit()

func _test_reproducible_bounded_routes() -> void:
	var first := CoinRouteDirector.new(611, 3)
	var second := CoinRouteDirector.new(611, 3)
	var varied := CoinRouteDirector.new(612, 3)
	var route_a: Array = first.generate_route(ANCHOR_Y, 1, [], [], [], [])
	var route_b: Array = second.generate_route(ANCHOR_Y, 1, [], [], [], [])
	var route_c: Array = varied.generate_route(ANCHOR_Y, 1, [], [], [], [])
	assert(route_a.size() >= 6 and route_a.size() <= 12, "Every generated coin route must contain 6-12 coins")
	assert(CoinRouteDirector.route_signature(route_a) == CoinRouteDirector.route_signature(route_b), "The same run seed must reproduce the same coin route")
	assert(CoinRouteDirector.route_signature(route_a) != CoinRouteDirector.route_signature(route_c), "Different run seeds must vary coin routing")
	_assert_route_geometry(route_a, 1)

func _test_all_five_templates() -> void:
	for template in range(CoinRouteDirector.Template.size()):
		var director := CoinRouteDirector.new(700 + template, 3)
		var blocked: Array[int] = []
		if template == CoinRouteDirector.Template.CONSTRUCTION_DIVERSION:
			blocked.append(0)
		var route: Array = director.generate_route(ANCHOR_Y, 0, [], [], [], blocked, template)
		assert(not route.is_empty(), "Template %d must produce a usable route when at least two lanes are open" % template)
		assert(route[0].template == template, "A requested template must remain identifiable in generated coin data")
		_assert_route_geometry(route, 0)

func _test_hazard_and_closure_exclusion() -> void:
	var npc_zones: Array[Vector3] = [Vector3(1.0, -250.0, 110.0), Vector3(2.0, -520.0, 90.0)]
	var fuel_zones: Array[Vector3] = [Vector3(0.0, -390.0, 100.0)]
	var construction_zones: Array[Vector3] = [Vector3(2.0, -700.0, 120.0)]
	var director := CoinRouteDirector.new(808, 3)
	var route: Array = director.generate_route(ANCHOR_Y, 1, npc_zones, fuel_zones, construction_zones, [0])
	assert(not route.is_empty(), "The director must try alternate templates and lanes around local hazards")
	for coin in route:
		assert(int(round(coin.lane_position)) != 0, "A route must never guide the player into a closed lane")
		assert(not CoinRouteDirector.overlaps_any_zone(coin.lane_position, coin.y, npc_zones), "Coins must avoid NPC current and reserved corridors")
		assert(not CoinRouteDirector.overlaps_any_zone(coin.lane_position, coin.y, fuel_zones), "Coins must not overlap fuel pickups")
		assert(not CoinRouteDirector.overlaps_any_zone(coin.lane_position, coin.y, construction_zones), "Coins must avoid construction cores")

func _test_unreachable_routes_delay_safely() -> void:
	var director := CoinRouteDirector.new(909, 3)
	assert(director.generate_route(ANCHOR_Y, 1, [], [], [], [0, 1, 2]).is_empty(), "A fully blocked road must delay coin generation")
	var wall: Array[Vector3] = []
	for lane in range(3):
		wall.append(Vector3(float(lane), -420.0, 500.0))
	assert(director.generate_route(ANCHOR_Y, 1, wall, [], [], []).is_empty(), "A hazard wall must not be decorated as an apparently safe coin route")

func _test_live_world_exclusion_adapters() -> void:
	var traffic := TrafficDirector.new(1001, 3)
	var changer = traffic.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 0, -260.0, 200.0)
	changer.target_lane = 1
	changer.warning_started = true
	var npc_zones: Array[Vector3] = CoinRouteDirector.npc_exclusion_zones([changer])
	assert(npc_zones.size() == 2 and int(npc_zones[0].x) == 0 and int(npc_zones[1].x) == 1, "NPC exclusions must reserve both current and announced target lanes")
	var planned = traffic.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 2, -330.0, 200.0)
	planned.target_lane = 1
	planned.warning_started = false
	var planned_zones: Array[Vector3] = CoinRouteDirector.npc_exclusion_zones([planned])
	assert(planned_zones.size() == 2, "A deterministic future lane change must reserve its target before the warning becomes visible")
	var fuel_zones: Array[Vector3] = CoinRouteDirector.fuel_exclusion_zones([FuelPickup.new(2, -410.0)])
	assert(fuel_zones.size() == 1 and int(fuel_zones[0].x) == 2, "Fuel pickups must expose their occupied coin-exclusion corridor")
	var construction_zones: Array[Vector3] = CoinRouteDirector.construction_exclusion_zones([Vector2(1.5, -620.0)])
	assert(construction_zones.size() == 1 and int(construction_zones[0].x) == 1, "Construction core markers must convert from edge coordinates to lane-center coordinates")
	var coins: Array[CoinPickup] = [CoinPickup.new(1, 1.12, -90.0)]
	var spawn_zones: Array[Vector2] = CoinRouteDirector.traffic_spawn_exclusion_zones(coins)
	assert(spawn_zones.size() == 1 and spawn_zones[0] == Vector2(1.0, -90.0), "Coin routes must be able to reserve NPC spawn space at the screen boundary")
	var boundary_coins: Array[CoinPickup] = [CoinPickup.new(2, 0.50, -120.0)]
	var boundary_zones: Array[Vector2] = CoinRouteDirector.traffic_spawn_exclusion_zones(boundary_coins)
	assert(boundary_zones == [Vector2(0.0, -120.0), Vector2(1.0, -120.0)], "A coin crossing a lane divider must reserve both potentially overlapping NPC lanes")

func _assert_route_geometry(route: Array, player_lane: int) -> void:
	assert(absf(route[0].lane_position - float(player_lane)) <= 1.0, "A route must begin in the current or an adjacent reachable lane")
	for index in range(route.size()):
		var coin = route[index]
		assert(coin.lane_position >= 0.0 and coin.lane_position <= 2.0, "Coin lane positions must remain inside the road")
		assert(is_zero_approx(coin.world_speed), "Generated coins must keep absolute world speed at zero")
		if index == 0:
			continue
		var previous = route[index - 1]
		var spacing: float = float(previous.y) - float(coin.y)
		assert(spacing >= 55.0 and spacing <= 75.0, "Consecutive coin spacing must remain within the frozen 55-75 px band")
		var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
		var maximum_player_speed := GameConfig.MAX_SPEED + GameConfig.OVERDRIVE_SPEED_BONUS
		var travel_seconds := spacing / (maximum_player_speed * GameConfig.ROAD_SCROLL_MULTIPLIER)
		var reachable_lane_delta := GameConfig.STEERING_SPEED * travel_seconds / lane_width * 0.95
		assert(absf(coin.lane_position - previous.lane_position) <= reachable_lane_delta, "Coin routes must remain collectible even at maximum overdrive speed")
