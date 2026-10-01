extends SceneTree
const Gameplay = preload("res://scripts/coin_gameplay_director.gd")
const Routes = preload("res://scripts/coin_route_director.gd")
const Config = preload("res://scripts/game_config.gd")

func _init() -> void:
	# Comet RS, 30% hull, overdrive, mountain steering multiplier: the old
	# adjacent-lane rule can put the first coin beyond the reaction window.
	var bounds: Vector2 = Gameplay.reachable_entry_lanes(1.0, 855.0, 230.0, 720.0)
	assert(bounds.x > 0.0 and bounds.y < 2.0)
	for seed in [611,2026,9001]:
		for template in range(Routes.Template.size()):
			var director := Routes.new(seed,3)
			var route := director.generate_route(-90,1,[],[],[],[],template,bounds)
			if not route.is_empty():
				assert(route[0].lane_position >= bounds.x and route[0].lane_position <= bounds.y, "First coin must be reachable at the reserved speed and steering authority")
	var blocked := Routes.new(611,3)
	assert(blocked.generate_route(-90,1,[],[],[],[1],-1,Vector2(0.8,1.2)).is_empty(), "If the reachable entry lane is blocked, generation must wait")
	var slow: Vector2 = Gameplay.reachable_entry_lanes(1,100,500,720)
	assert(slow.x <= 0 and slow.y >= 2, "Slow traffic should retain adjacent-lane variety")
	var offset: Vector2 = Gameplay.reachable_entry_lanes(0.3,855,230,720)
	assert(is_equal_approx((offset.x+offset.y)*0.5,0.3), "Entry must use actual fractional player position")
	# Seed 611 produced a merge whose final coin exceeded damaged steering authority.
	var slope := Gameplay.followable_lane_slope(855.0,230.0)
	for template in [Routes.Template.GENTLE_MERGE,Routes.Template.CONSTRUCTION_DIVERSION]:
		var route := Routes.new(611,3).generate_route(-90,1,[],[],[],[],template,bounds,slope)
		for index in range(1,route.size()):
			var available_seconds: float = (route[index-1].y-route[index].y)/(855.0*Config.ROAD_SCROLL_MULTIPLIER)
			var lateral_distance: float = absf(route[index].lane_position-route[index-1].lane_position)*260.0
			assert(lateral_distance <= 230.0*available_seconds*0.9+0.001, "Every segment must fit the steering budget, not just the entry")
	var fallback := Routes.new(611,3).generate_route(-90,1,[],[],[],[],-1,bounds,slope)
	assert(not fallback.is_empty(), "Mixed generation must fall back to a followable template")
	var invalid_positions: Array[float] = [1.0,2.0]
	assert(not Routes._slope_is_followable(invalid_positions,55.0,slope))
	quit()
