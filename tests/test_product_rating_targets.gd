extends SceneTree
const Rating = preload("res://scripts/run_rating.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const Cars = preload("res://scripts/catalog/vehicle_catalog.gd")
const Coins = preload("res://scripts/coin_gameplay_director.gd")
const Config = preload("res://scripts/game_config.gd")

func _init() -> void:
	var okay := true
	var rating = Rating.new()
	if not rating.has_method("targets_for_run"):
		print("FAIL: rating must derive targets from this run's generated coins and actual cruise distance rate")
		print("TEST_COMPLETE test_product_rating_targets.gd")
		quit(1)
		return
	var slowest := INF
	for car in Cars.all(): slowest = minf(slowest, car.max_speed)
	for track in Tracks.all():
		var targets: Dictionary = rating.targets_for_run(track, {"generated_coins": 240})
		okay = _check(is_equal_approx(targets.time, track.finish_distance / (slowest * 0.1)), "Cruise baseline must exclude acceleration and overdrive") and okay
		okay = _check(targets.coins == 216, "240 spawned coins require 216 for full points") and okay
		var result := {"cleared": true, "survival": targets.time, "coins": 100, "overtakes": targets.overtakes, "collisions": 0}
		okay = _check(Rating.evaluate(result, targets).parts.coins < 20, "100 coins must no longer saturate a 240-coin scene") and okay
		result.coins = 216
		okay = _check(Rating.evaluate(result, targets).total == 100, "90 percent and cruise time must attain full marks") and okay
	var none: Dictionary = rating.targets_for_run(Tracks.all()[0], {"generated_coins": 0})
	okay = _check(none.coins == 0, "An empty scene must not invent collectable coins") and okay
	var zero: Dictionary = Rating.evaluate({"cleared": true, "survival": none.time, "coins": 0, "overtakes": none.overtakes, "collisions": 0}, none)
	okay = _check(not zero.is_empty() and zero.parts.coins == 0, "No generated coins cannot award free coin points") and okay
	var director = Coins.new(611)
	director.tick(0.0, 0.0, 1, 720.0, [], [], [], [])
	okay = _check(director.generated_coin_count == director.coins.size(), "Count actual coins, not routes or pickups") and okay
	var generated: int = director.generated_coin_count
	for coin in director.coins: coin.y = 900.0
	director.tick(0.0, 0.0, 1, 720.0, [], [], [], [])
	okay = _check(director.generated_coin_count == generated, "Missed coins stay in the denominator") and okay
	director.reset(611)
	okay = _check(director.generated_coin_count == 0, "A new run resets its own denominator") and okay
	var no_blocked_lanes: Array[int] = []
	director.call("tick", 0.0, 0.0, 1, 720.0, [], [], [], no_blocked_lanes, Vector2(-INF, INF), INF, 1.0)
	okay = _check(director.generated_coin_count == 0 and director.coins.is_empty(), "Do not count unreachable post-finish coins") and okay
	print("TEST_COMPLETE test_product_rating_targets.gd")
	quit(0 if okay else 1)

func _check(condition: bool, message: String) -> bool:
	if not condition: print("FAIL: ", message)
	return condition
