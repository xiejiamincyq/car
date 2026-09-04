extends SceneTree

const CoinRenderer = preload("res://scripts/coin_renderer.gd")
const GameConfig = preload("res://scripts/game_config.gd")

func _init() -> void:
	var animated_scale := CoinRenderer.spin_scale(0.0, 4, false)
	assert(animated_scale >= CoinRenderer.MIN_SPIN_SCALE and animated_scale <= 1.0, "Coin rotation must retain a readable face at every frame")
	assert(is_equal_approx(CoinRenderer.spin_scale(0.0, 4, true), CoinRenderer.REDUCED_FLASHING_SCALE), "Reduced flashing must replace rapid coin rotation with a stable face")
	assert(is_equal_approx(CoinRenderer.spin_scale(3.0, 4, true), CoinRenderer.REDUCED_FLASHING_SCALE), "Reduced flashing coin shape must not pulse over time")

	var coin_center := Vector2(100.0, 100.0)
	var outside_player := coin_center + Vector2(GameConfig.COIN_ATTRACTION_RADIUS + 1.0, 0.0)
	assert(CoinRenderer.attraction_offset(coin_center, outside_player).is_zero_approx(), "Coins outside the attraction radius must remain fixed to the road")
	var inside_player := coin_center + Vector2(60.0, 30.0)
	var attraction := CoinRenderer.attraction_offset(coin_center, inside_player)
	assert(attraction.dot(inside_player - coin_center) > 0.0, "Nearby visual attraction must point toward the player")
	assert(attraction.length() <= CoinRenderer.MAX_ATTRACTION_OFFSET, "Visual attraction must stay subtle and preserve route readability")
	quit()
