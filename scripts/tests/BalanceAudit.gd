extends SceneTree
## Deterministic model probes, not a driving bot or a human win-rate estimate.
const Config = preload("res://scripts/game_config.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const Cars = preload("res://scripts/catalog/vehicle_catalog.gd")
const Difficulty = preload("res://scripts/difficulty_profile.gd")
const Drive = preload("res://scripts/drive_controller.gd")
const Run = preload("res://scripts/run_state.gd")
const Hull = preload("res://scripts/vehicle_integrity.gd")
const Coins = preload("res://scripts/coin_route_director.gd")
const CoinGameplay = preload("res://scripts/coin_gameplay_director.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const DT := 1.0/60.0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "res://tmp/balance"
	DirAccess.make_dir_recursive_absolute(folder)
	var fuel := FileAccess.open(folder+"/fuel-repair.csv", FileAccess.WRITE)
	var routes := FileAccess.open(folder+"/coin-followability.csv", FileAccess.WRITE)
	if fuel == null or routes == null:
		push_error("Cannot create audit outputs")
		quit(2)
		return
	fuel.store_csv_line(PackedStringArray(["track","car","difficulty","hull_scenario","assumed_fuel_every_s","result","seconds","distance_m","fuel_left","hull_final"]))
	routes.store_csv_line(PackedStringArray(["track","car","hull","overdrive_speed","seed","template","coins","centerline_followable","first_failed_coin","pickup_window_followable","window_failed_coin"]))
	var cases := 0
	var route_cases := 0
	var route_flags := 0
	for track in Tracks.all():
		for car in Cars.all():
			for difficulty in range(3):
				for scenario in ["healthy", "hull30", "hull30_repair_at20s"]:
					for supply in [0,16]:
						fuel.store_csv_line(_fuel_probe(track,car,difficulty,scenario,supply))
						cases += 1
			for state in [[100.0,false],[100.0,true],[30.0,false],[30.0,true]]:
				for seed in [611,2026,9001]:
					for template in range(-1,Coins.Template.size()):
						var director := Coins.new(seed,Config.ROAD_LANE_COUNT)
						var hull := Hull.new()
						hull.current = state[0]
						var speed: float = (car.max_speed+Config.OVERDRIVE_SPEED_BONUS)*hull.max_speed_multiplier()
						var authority: float = car.steering_speed*track.steering_multiplier*0.85*hull.steering_multiplier()
						var bounds := CoinGameplay.reachable_entry_lanes(1.0,speed,authority,720)
						var slope := CoinGameplay.followable_lane_slope(speed,authority)
						var route := director.generate_route(-90.0,1,[],[],[],[],template,bounds,slope)
						var failed := _route_probe(car,track,state[0],state[1],route)
						var window_failed := _route_probe(car,track,state[0],state[1],route,Config.COIN_PICKUP_LONGITUDINAL_DISTANCE*0.99)
						routes.store_csv_line(PackedStringArray([str(track.id),str(car.id),str(state[0]),str(state[1]),str(seed),str(template),str(route.size()),str(failed<0),str(failed),str(window_failed<0),str(window_failed)]))
						route_cases += 1
						if failed >= 0: route_flags += 1
	fuel.close()
	routes.close()
	print("BALANCE AUDIT: %d fuel/repair probes; %d route probes; %d conservative followability flags" % [cases,route_cases,route_flags])
	quit()

func _fuel_probe(track: Dictionary, car: Dictionary, difficulty: int, scenario: String, supply: int) -> PackedStringArray:
	var drive := Drive.new(Config.START_SPEED,car.max_speed,car.acceleration,car.braking,car.steering_speed)
	var run := Run.new(Config.MAX_FUEL,Config.FUEL_DRAIN_PER_SECOND,Config.FUEL_GRACE_SECONDS)
	run.configure_track(track)
	run.configure_difficulty(Difficulty.for_index(difficulty))
	var hull := Hull.new()
	hull.current = 100.0 if scenario == "healthy" else 30.0
	var repaired := false
	var next_supply := float(supply)
	run.start()
	while run.phase == Run.Phase.RUNNING and run.elapsed_seconds < 180:
		var before := drive.speed
		drive.step(DT,1,0,0,0,0,hull.max_speed_multiplier(),hull.steering_multiplier())
		run.tick(DT,drive.speed,drive.max_speed,maxf(0,(drive.speed-before)/DT))
		if scenario == "hull30_repair_at20s" and not repaired and run.elapsed_seconds >= 20:
			hull.repair(20)
			repaired = true
		if supply > 0 and run.elapsed_seconds >= next_supply:
			run.add_fuel(Config.FUEL_PICKUP_AMOUNT)
			next_supply += supply
	return PackedStringArray([str(track.id),str(car.id),str(difficulty),scenario,str(supply),"clear" if run.phase == Run.Phase.RUN_CLEAR else "fuel_failure", "%.3f" % run.elapsed_seconds,"%.2f" % run.distance,"%.3f" % run.fuel,str(hull.current)])

func _route_probe(car: Dictionary, track: Dictionary, health: float, overdrive: bool, route: Array, pickup_window: float = 0.0) -> int:
	var hull := Hull.new()
	hull.current = health
	var speed: float = (car.max_speed+(Config.OVERDRIVE_SPEED_BONUS if overdrive else 0.0))*hull.max_speed_multiplier()
	var drive := Drive.new(speed,car.max_speed,0,0,car.steering_speed)
	var lateral_speed: float = car.steering_speed*track.steering_multiplier*drive.speed_steering_multiplier()*hull.steering_multiplier()
	var lane_width := Config.ROAD_HALF_WIDTH*2.0/Config.ROAD_LANE_COUNT
	var low := lane_width*1.5
	var high := low
	var previous_y := Geometry.player_y(720.0)+pickup_window
	for index in range(route.size()):
		var coin = route[index]
		var seconds: float = (previous_y-coin.y)/(speed*Config.ROAD_SCROLL_MULTIPLIER)
		var target: float = lane_width*(coin.lane_position+0.5)
		low = maxf(low-lateral_speed*seconds,target-Config.COIN_PICKUP_LATERAL_DISTANCE)
		high = minf(high+lateral_speed*seconds,target+Config.COIN_PICKUP_LATERAL_DISTANCE)
		if low > high: return index
		previous_y = coin.y
	return -1
