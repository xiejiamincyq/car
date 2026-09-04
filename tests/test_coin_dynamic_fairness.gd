extends SceneTree

const CoinRouteDirector = preload("res://scripts/coin_route_director.gd")
const FuelPickup = preload("res://scripts/fuel_pickup.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	for viewport_height in [720.0, 1080.0]:
		for seed in range(1, 41):
			_run_combined_snapshot(seed, viewport_height)
	quit()

func _run_combined_snapshot(seed: int, viewport_height: float) -> void:
	var traffic := TrafficDirector.new(seed, GameConfig.ROAD_LANE_COUNT)
	traffic.set_viewport_height(viewport_height)
	var closed_lane := seed % GameConfig.ROAD_LANE_COUNT
	traffic.lane_events.begin_warning(closed_lane)
	var open_lanes := traffic.lane_events.open_lanes()
	var npc_lane: int = open_lanes[0]
	var fuel_lane: int = open_lanes[1]
	var vehicle = traffic.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, npc_lane, -420.0, 200.0)
	traffic.vehicles.append(vehicle)
	var fuels: Array = [FuelPickup.new(fuel_lane, -600.0)]
	var construction_markers: Array[Vector2] = [Vector2(float(closed_lane) + 0.5, -500.0)]
	var npc_zones := CoinRouteDirector.npc_exclusion_zones(traffic.vehicles)
	var fuel_zones := CoinRouteDirector.fuel_exclusion_zones(fuels)
	var construction_zones := CoinRouteDirector.construction_exclusion_zones(construction_markers)
	var director := CoinRouteDirector.new(seed ^ 0x434F494E, GameConfig.ROAD_LANE_COUNT)
	var route: Array = director.generate_route(-90.0, 1, npc_zones, fuel_zones, construction_zones, [closed_lane])
	assert(not route.is_empty(), "Seed %d at %.0fp must retain a safe coin route around combined traffic, fuel, and construction" % [seed, viewport_height])
	for coin in route:
		assert(int(round(coin.lane_position)) != closed_lane, "Combined routing must never enter the construction lane")
		assert(not CoinRouteDirector.overlaps_any_zone(coin.lane_position, coin.y, npc_zones), "Combined routing must avoid live traffic")
		assert(not CoinRouteDirector.overlaps_any_zone(coin.lane_position, coin.y, fuel_zones), "Combined routing must avoid live fuel pickups")
		assert(not CoinRouteDirector.overlaps_any_zone(coin.lane_position, coin.y, construction_zones), "Combined routing must avoid construction cores")
	var first_coin = route[0]
	var spawn_lane := clampi(roundi(first_coin.lane_position), 0, GameConfig.ROAD_LANE_COUNT - 1)
	var spawn_candidate = traffic.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, spawn_lane, first_coin.y, 200.0)
	traffic.set_spawn_exclusion_zones(CoinRouteDirector.traffic_spawn_exclusion_zones(route))
	assert(not traffic._can_spawn_candidate(spawn_candidate, 500.0, 1), "Active coins must reserve their NPC spawn corridor")
