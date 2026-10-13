extends SceneTree
const Routes = preload("res://scripts/coin_route_director.gd")
const Gameplay = preload("res://scripts/coin_gameplay_director.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const Vehicles = preload("res://scripts/catalog/vehicle_catalog.gd")
const Hull = preload("res://scripts/vehicle_integrity.gd")
const Config = preload("res://scripts/game_config.gd")
var failures: Array[String]=[]
var cases := 0
func _init() -> void:
	if Routes.Template.get("S_CURVE",-1)<0:
		_check(false,"All tracks need identifiable left/right/S curve templates")
		_finish()
		return
	for track in Tracks.all():
		for vehicle in Vehicles.all():
			for integrity in [100.0,70.0,30.0]:
				var hull := Hull.new()
				hull.current=integrity
				var steering: float=vehicle.steering_speed*track.steering_multiplier*0.85*hull.steering_multiplier()
				var ceiling: float=(vehicle.max_speed+Config.OVERDRIVE_SPEED_BONUS)*hull.max_speed_multiplier()
				var entry := Gameplay.reachable_entry_lanes(1.0,ceiling,steering,720.0)
				var slope := Gameplay.followable_lane_slope(ceiling,steering)
				var bins := [0,0,0]
				var curved := 0
				var shapes := {}
				for seed_value in [611,2026,9001,616,618]:
					var director := Routes.new(seed_value)
					for index in 50:
						var route := director.generate_route(-90,1,[],[],[],[],-1,entry,slope)
						cases+=1
						_check(not route.is_empty(),"Clear reachable corridor retains bounded generation")
						if route.is_empty():continue
						shapes[route[0].template]=true
						var low: float=route[0].lane_position
						var high := low
						for coin in route:
							bins[clampi(roundi(coin.lane_position),0,2)]+=1
							low=minf(low,coin.lane_position)
							high=maxf(high,coin.lane_position)
							_check(is_zero_approx(coin.world_speed) and coin.lane_position>=0 and coin.lane_position<=2,"Curves stay on the static road")
						_check(route[0].lane_position>=entry.x and route[0].lane_position<=entry.y,"Continuous first coin stays inside original reaction reach")
						if high-low>0.05 and absf(route[0].lane_position-route[-1].lane_position)<0.001:curved+=1
						for i in range(1,route.size()):
							var spacing: float=route[i-1].y-route[i].y
							_check(spacing>=55 and spacing<=75 and absf(route[i].lane_position-route[i-1].lane_position)<=slope*spacing+0.00001,"Every curved segment keeps original steering/spacing budget")
				_check(curved>=90,"At least 36% successful clear-road routes are true loops, not linear merges")
				_check(bins[1]<=float(bins[0]+bins[1]+bins[2])*0.60,"Clear reachable road no longer overwhelmingly centers coins")
				_check(abs(bins[0]-bins[2])<=float(bins[0]+bins[1]+bins[2])*0.15,"Accepted positions are not systematically left/right biased")
				for key in ["LEFT_ARC","RIGHT_ARC","S_CURVE"]:_check(shapes.has(Routes.Template.get(key)),"Every course/vehicle/hull can produce all new curve shapes")
	var wall: Array[Vector3]=[Vector3(0,-420,1000),Vector3(1,-420,1000),Vector3(2,-420,1000)]
	_check(Routes.new(611).generate_route(-90,1,wall,[],[],[]).is_empty(),"Diversity never overrides an impossible hazard wall")
	for position in [0.0,0.3,0.5,1.0,1.5,1.7,2.0]:
		var entry := Gameplay.reachable_entry_lanes(position,900,230,720)
		for seed_value in [611,2026,9001]:
			var route := Routes.new(seed_value).generate_route(-90,roundi(position),[],[],[],[],-1,entry,Gameplay.followable_lane_slope(900,230))
			_check(not route.is_empty() and route[0].lane_position>=entry.x and route[0].lane_position<=entry.y,"Fractional side drivers retain truthful reachable entries")
	for entry in [Vector2(0.5,0.5),Vector2(1.5,1.5),Vector2(0.49,0.51),Vector2(1.49,1.51)]:
		var position: float=(entry.x+entry.y)*0.5
		for seed_value in [611,2026,9001]:
			var route := Routes.new(seed_value).generate_route(-90,roundi(position),[],[],[],[],-1,entry,0.0)
			_check(not route.is_empty() and route[0].lane_position>=entry.x and route[0].lane_position<=entry.y,"Continuous divider entries do not disappear between lane bins")
			var blocked_divider: Array[int]=[roundi(position)]
			_check(Routes.new(seed_value).generate_route(-90,roundi(position),[],[],[],blocked_divider,-1,entry,0.0).is_empty(),"Divider reachability does not waive construction clearance")
	var blocked: Array[int]=[0,2]
	for seed_value in [611,2026,9001]:
		var route := Routes.new(seed_value).generate_route(-90,1,[],[],[],blocked)
		_check(not route.is_empty(),"Single safe lane is not rejected to satisfy diversity quotas")
		for coin in route:_check(coin.lane_position>0.55 and coin.lane_position<1.45,"Construction safety remains authoritative")
	_finish()
func _check(ok: bool,message: String) -> void:
	if not ok and not failures.has(message):failures.append(message)
func _finish() -> void:
	for failure in failures:push_error(failure)
	print("COIN_DIVERSITY ",JSON.stringify({"cases":cases,"failures":failures}))
	print("TEST_COMPLETE test_coin_layout_diversity.gd")
	quit(0 if failures.is_empty() else 1)
