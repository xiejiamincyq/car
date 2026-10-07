class_name CoinGameplayDirector
extends RefCounted

const CoinPickup = preload("res://scripts/coin_pickup.gd")
const CoinRouteDirector = preload("res://scripts/coin_route_director.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const TrackGeometry = preload("res://scripts/track_geometry.gd")

var coins: Array[CoinPickup] = []
var route_director: CoinRouteDirector
var spawn_distance_remaining := 0.0
var spawned_route_count := 0
var generated_coin_count := 0

func _init(run_seed: int, lanes: int = GameConfig.ROAD_LANE_COUNT) -> void:
	route_director = CoinRouteDirector.new(run_seed, lanes)

func reset(run_seed: int) -> void:
	coins.clear()
	route_director.reset(run_seed)
	spawn_distance_remaining = 0.0
	spawned_route_count = 0
	generated_coin_count = 0

func tick(
	delta: float,
	player_speed: float,
	player_lane: int,
	viewport_height: float,
	npc_zones: Array,
	fuel_zones: Array,
	construction_zones: Array,
	blocked_lanes: Array[int],
	entry_lane_range: Vector2 = Vector2(-INF, INF),
	maximum_lane_slope: float = INF,
	remaining_race_distance: float = INF
) -> bool:
	var safe_delta := maxf(0.0, delta)
	var safe_speed := maxf(0.0, player_speed)
	for coin in coins:
		coin.advance(safe_delta, safe_speed)
	_recycle_offscreen(viewport_height)
	spawn_distance_remaining -= safe_speed * GameConfig.ROAD_SCROLL_MULTIPLIER * safe_delta
	if spawn_distance_remaining > 0.0 or coins.size() > GameConfig.COIN_MAX_ACTIVE - CoinRouteDirector.MAX_COIN_COUNT:
		return false
	var route := route_director.generate_route(
		GameConfig.COIN_ROUTE_SPAWN_Y,
		player_lane,
		npc_zones,
		fuel_zones,
		construction_zones,
		blocked_lanes,
		-1,
		entry_lane_range,
		maximum_lane_slope
	)
	# Do not create/count coins which can only reach the player after finish.
	var eligible: Array[CoinPickup] = []
	for coin in route:
		var metres_until_pickup := maxf(0.0, TrackGeometry.player_y(viewport_height) - coin.y) * 0.1 / GameConfig.ROAD_SCROLL_MULTIPLIER
		if metres_until_pickup <= remaining_race_distance:
			eligible.append(coin)
	route = eligible
	if route.is_empty():
		spawn_distance_remaining = GameConfig.COIN_ROUTE_RETRY_DISTANCE
		return false
	coins.append_array(route)
	generated_coin_count += route.size()
	spawn_distance_remaining = GameConfig.COIN_ROUTE_INTERVAL_DISTANCE
	spawned_route_count += 1
	return true

static func reachable_entry_lanes(player_lane_position: float, maximum_speed: float, lateral_speed: float, viewport_height: float) -> Vector2:
	# Start the reaction clock when a coin is fully visible, not at its offscreen spawn.
	var visible_y := 20.0
	var seconds := maxf(0.0, (TrackGeometry.player_y(viewport_height)-visible_y) / maxf(1.0, maximum_speed*GameConfig.ROAD_SCROLL_MULTIPLIER)-0.2)
	var lane_width := GameConfig.ROAD_HALF_WIDTH*2.0/GameConfig.ROAD_LANE_COUNT
	var reach := (maxf(0.0,lateral_speed)*seconds+GameConfig.COIN_PICKUP_LATERAL_DISTANCE*0.9)/lane_width
	return Vector2(player_lane_position-reach,player_lane_position+reach)

static func followable_lane_slope(maximum_speed: float, lateral_speed: float) -> float:
	var lane_width := GameConfig.ROAD_HALF_WIDTH*2.0/GameConfig.ROAD_LANE_COUNT
	return maxf(0.0,lateral_speed)*0.9/(maxf(1.0,maximum_speed*GameConfig.ROAD_SCROLL_MULTIPLIER)*lane_width)

func collect_near(player_lane_position: float, player_y: float, lane_width: float) -> Array[CoinPickup]:
	var collected_coins: Array[CoinPickup] = []
	var active: Array[CoinPickup] = []
	for coin in coins:
		var lateral_distance := absf(coin.lane_position - player_lane_position) * maxf(1.0, lane_width)
		var longitudinal_distance := absf(coin.y - player_y)
		if lateral_distance < GameConfig.COIN_PICKUP_LATERAL_DISTANCE and longitudinal_distance < GameConfig.COIN_PICKUP_LONGITUDINAL_DISTANCE and coin.collect():
			collected_coins.append(coin)
		else:
			active.append(coin)
	coins = active
	return collected_coins

func blocked_lanes_near(y: float, clearance: float) -> Array[int]:
	var blocked: Array[int] = []
	for coin in coins:
		if coin.collected or absf(coin.y - y) > maxf(0.0, clearance):
			continue
		for lane in range(route_director.lane_count):
			if absf(coin.lane_position - float(lane)) <= 0.5 and not blocked.has(lane):
				blocked.append(lane)
	blocked.sort()
	return blocked

func guidance_reserved_lanes() -> Array[int]:
	var route_destinations := {}
	for coin in coins:
		if not coin.collected:
			route_destinations[coin.route_id] = clampi(roundi(coin.lane_position), 0, route_director.lane_count - 1)
	var reserved: Array[int] = []
	for route_id in route_destinations:
		var lane: int = route_destinations[route_id]
		if not reserved.has(lane):
			reserved.append(lane)
	reserved.sort()
	return reserved

func _recycle_offscreen(viewport_height: float) -> void:
	var active: Array[CoinPickup] = []
	for coin in coins:
		if not coin.collected and coin.y < viewport_height + GameConfig.COIN_RECYCLE_MARGIN:
			active.append(coin)
	coins = active
