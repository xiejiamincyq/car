class_name CoinGameplayDirector
extends RefCounted

const CoinPickup = preload("res://scripts/coin_pickup.gd")
const CoinRouteDirector = preload("res://scripts/coin_route_director.gd")
const GameConfig = preload("res://scripts/game_config.gd")

var coins: Array[CoinPickup] = []
var route_director: CoinRouteDirector
var spawn_distance_remaining := 0.0
var spawned_route_count := 0

func _init(run_seed: int, lanes: int = GameConfig.ROAD_LANE_COUNT) -> void:
	route_director = CoinRouteDirector.new(run_seed, lanes)

func reset(run_seed: int) -> void:
	coins.clear()
	route_director.reset(run_seed)
	spawn_distance_remaining = 0.0
	spawned_route_count = 0

func tick(
	delta: float,
	player_speed: float,
	player_lane: int,
	viewport_height: float,
	npc_zones: Array,
	fuel_zones: Array,
	construction_zones: Array,
	blocked_lanes: Array[int]
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
		blocked_lanes
	)
	if route.is_empty():
		spawn_distance_remaining = GameConfig.COIN_ROUTE_RETRY_DISTANCE
		return false
	coins.append_array(route)
	spawn_distance_remaining = GameConfig.COIN_ROUTE_INTERVAL_DISTANCE
	spawned_route_count += 1
	return true

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

func _recycle_offscreen(viewport_height: float) -> void:
	var active: Array[CoinPickup] = []
	for coin in coins:
		if not coin.collected and coin.y < viewport_height + GameConfig.COIN_RECYCLE_MARGIN:
			active.append(coin)
	coins = active
