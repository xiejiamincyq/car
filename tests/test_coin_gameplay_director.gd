extends SceneTree

const CoinGameplayDirector = preload("res://scripts/coin_gameplay_director.gd")
const CoinPickup = preload("res://scripts/coin_pickup.gd")
const CoinRouteDirector = preload("res://scripts/coin_route_director.gd")
const GameConfig = preload("res://scripts/game_config.gd")

func _init() -> void:
	var director := CoinGameplayDirector.new(611, GameConfig.ROAD_LANE_COUNT)
	assert(director.tick(0.0, 0.0, 1, 720.0, [], [], [], []), "A new run must expose its first coin route without requiring elapsed time")
	assert(director.coins.size() >= 6 and director.coins.size() <= 12, "The gameplay director must publish one bounded route")
	var initial_signature := CoinRouteDirector.route_signature(director.coins)
	var first_y: float = director.coins[0].y
	director.tick(0.5, 400.0, 1, 720.0, [], [], [], [])
	assert(is_equal_approx(director.coins[0].y, first_y + 400.0 * GameConfig.ROAD_SCROLL_MULTIPLIER * 0.5), "Active coins must scroll only from player world movement")

	director.reset(611)
	assert(director.coins.is_empty() and director.spawned_route_count == 0, "Reset must remove old routes and counters")
	director.tick(0.0, 0.0, 1, 720.0, [], [], [], [])
	assert(CoinRouteDirector.route_signature(director.coins) == initial_signature, "Resetting with the same seed must restore the same first route")

	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	director.coins.assign([CoinPickup.new(99, 1.0, 592.0)])
	var collected: Array[CoinPickup] = director.collect_near(1.0, 592.0, lane_width)
	assert(collected.size() == 1 and collected[0].id == 99 and director.coins.is_empty(), "A nearby coin must be removed and returned for one-shot settlement")
	assert(director.collect_near(1.0, 592.0, lane_width).is_empty(), "A settled coin must not be collected twice")

	var delayed := CoinGameplayDirector.new(712, GameConfig.ROAD_LANE_COUNT)
	assert(not delayed.tick(0.0, 0.0, 1, 720.0, [], [], [], [0, 1, 2]), "A fully blocked route must delay instead of spawning")
	assert(delayed.spawn_distance_remaining == GameConfig.COIN_ROUTE_RETRY_DISTANCE, "Unsafe routing must use the short deterministic retry distance")
	var retry_seconds: float = GameConfig.COIN_ROUTE_RETRY_DISTANCE / (400.0 * GameConfig.ROAD_SCROLL_MULTIPLIER)
	assert(delayed.tick(retry_seconds, 400.0, 1, 720.0, [], [], [], []), "The director must retry once enough road distance becomes available")

	for coin in delayed.coins:
		coin.y = 800.0
	delayed.tick(0.0, 0.0, 1, 720.0, [], [], [], [])
	assert(delayed.coins.is_empty(), "Off-screen coins must be recycled from the active set")
	quit()
