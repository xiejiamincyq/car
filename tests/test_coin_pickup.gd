extends SceneTree

const CoinPickup = preload("res://scripts/coin_pickup.gd")
const GameConfig = preload("res://scripts/game_config.gd")

func _init() -> void:
	var coin := CoinPickup.new(7, 1.25, -90.0, 3, 2)
	assert(coin.id == 7 and is_equal_approx(coin.lane_position, 1.25), "A coin must preserve its stable id and continuous lane position")
	assert(coin.route_id == 3 and coin.template == 2, "A coin must retain its route identity for one-shot settlement and diagnostics")
	assert(is_zero_approx(coin.world_speed), "Coins must be stationary in world space")
	var start_y: float = coin.y
	coin.advance(0.5, 400.0)
	assert(is_equal_approx(coin.y, start_y + 400.0 * GameConfig.ROAD_SCROLL_MULTIPLIER * 0.5), "Only player speed may move a world-stationary coin on screen")
	coin.advance(1.0, 0.0)
	assert(is_equal_approx(coin.y, start_y + 400.0 * GameConfig.ROAD_SCROLL_MULTIPLIER * 0.5), "A stopped player must see a coin remain fixed against the road")
	assert(coin.collect() and not coin.collect(), "A coin must settle at most once")
	quit()
