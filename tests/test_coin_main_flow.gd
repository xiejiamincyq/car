extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const CoinPickup = preload("res://scripts/coin_pickup.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.run.begin_countdown(0.0)
	var viewport_size: Vector2 = main.get_viewport_rect().size
	var player_y: float = main.TrackGeometry.player_y(viewport_size.y)
	var player_lane_position := float(main.GameConfig.ROAD_LANE_COUNT - 1) * 0.5
	main.coin_director.coins.assign([CoinPickup.new(501, player_lane_position, player_y)])
	main.coin_director.spawn_distance_remaining = 99999.0
	var score_before: int = main.run.score
	main._update_coins(0.0)
	assert(main.run.coins == 1, "Collecting a road coin must increment the run coin count")
	assert(main.run.score == score_before + main.GameConfig.COIN_SCORE, "The first coin must immediately award its base score through the shared combo")
	assert(main.coin_director.coins.is_empty(), "A collected coin must be removed from active gameplay")
	assert(main.feedback.coin_bursts.size() == 1, "Coin collection must emit one gold pickup burst")
	assert(main.audio_director.coin_audio.playing, "Coin collection must play its dedicated chirp")
	main._update_coins(0.0)
	assert(main.run.coins == 1 and main.run.score == score_before + main.GameConfig.COIN_SCORE, "A collected coin must settle only once")

	main.coin_director.coins.assign([CoinPickup.new(502, 0.0, 120.0)])
	main.run.phase = main.RunState.Phase.PAUSED
	var paused_y: float = main.coin_director.coins[0].y
	main._process(0.5)
	assert(is_equal_approx(main.coin_director.coins[0].y, paused_y), "Pausing must freeze coin routes with the road")

	main._reset_run(611)
	assert(main.run.coins == 0 and main.coin_director.coins.is_empty(), "Restarting must clear collected counts and old route objects")
	main.audio_director.shutdown()
	main.free()
	quit()
