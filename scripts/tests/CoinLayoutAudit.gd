extends SceneTree
## Controlled model diagnosis, not real driving or a full gameplay fairness gate.
const Route = preload("res://scripts/coin_route_director.gd")
const Coins = preload("res://scripts/coin_gameplay_director.gd")
const Traffic = preload("res://scripts/traffic_director.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const Difficulty = preload("res://scripts/difficulty_profile.gd")
const Vehicle = preload("res://scripts/catalog/vehicle_catalog.gd")
const Config = preload("res://scripts/game_config.gd")
class MeasuredRoute extends Route:
	var attempts := [0,0,0,0,0,0,0,0]
	var accepted := [0,0,0,0,0,0,0,0]
	var coin_bins := [0,0,0]
	var curves := 0
	func _build_lane_positions(template: int,count: int,player_lane: int,open_lanes: Array[int],blocked: Array[int]) -> Array[float]:
		attempts[template]+=1
		return super._build_lane_positions(template,count,player_lane,open_lanes,blocked)
	func _make_route(positions: Array[float],anchor: float,spacing: float,template: int) -> Array[CoinPickup]:
		accepted[template]+=1
		if positions.max()-positions.min()>0.05 and absf(positions[0]-positions[-1])<0.001:curves+=1
		for position in positions:coin_bins[clampi(roundi(position),0,2)]+=1
		return super._make_route(positions,anchor,spacing,template)
func _init() -> void:
	var source_before := FileAccess.get_sha256("res://scripts/coin_route_director.gd")
	var vehicle := Vehicle.get_by_id(&"pulse_gt")
	for track in Tracks.all():
		for difficulty in 3:
			var attempts := [0,0,0,0,0,0,0,0]
			var accepted := [0,0,0,0,0,0,0,0]
			var bins := [0,0,0]
			var curves := 0
			var steering: float=vehicle.steering_speed*track.steering_multiplier*0.85
			var ceiling: float=vehicle.max_speed+Config.OVERDRIVE_SPEED_BONUS
			var entry := Coins.reachable_entry_lanes(1.0,ceiling,steering,720.0)
			var slope := Coins.followable_lane_slope(ceiling,steering)
			for seed_value in [611,2026,9001]:
				var traffic := Traffic.new(seed_value)
				traffic.configure_track(track)
				traffic.configure_difficulty(Difficulty.for_index(difficulty))
				var coins := Coins.new(seed_value^911)
				var measured := MeasuredRoute.new(seed_value^911)
				coins.route_director=measured
				for step in 2700:
					traffic.set_difficulty_stage(mini(3,int(step/675)))
					traffic.tick(1.0/60.0,760.0,1)
					var blocked := traffic.lane_events.closed_lanes()
					for lane in traffic.fast_priority_lanes():
						if not blocked.has(lane):blocked.append(lane)
					coins.tick(1.0/60.0,760.0,1,720.0,Route.npc_exclusion_zones(traffic.vehicles),[],
						Route.construction_exclusion_zones(traffic.lane_events.core_markers(720.0)),blocked,entry,slope)
				for i in Route.Template.size():
					attempts[i]+=measured.attempts[i]
					accepted[i]+=measured.accepted[i]
				for i in 3:bins[i]+=measured.coin_bins[i]
				curves+=measured.curves
			print("COIN_LAYOUT_SAMPLE ",JSON.stringify({"track":track.id,"difficulty":difficulty,"vehicle":"pulse_gt",
				"player_lane":1,"seeds":[611,2026,9001],"seconds":45,"entry":str(entry),"slope":slope,
				"attempts":attempts,"accepted_templates":accepted,"curved_routes":curves,"coin_lane_bins":bins,
				"scope":"Traffic+coin model, fixed center driver, no pickups, no birth reservations or collisions"}))
	var unchanged := source_before==FileAccess.get_sha256("res://scripts/coin_route_director.gd")
	print("COIN_LAYOUT_SOURCE ",JSON.stringify({"route_sha256":source_before,"unchanged":unchanged}))
	print("COIN_LAYOUT_AUDIT_COMPLETE")
	quit(0 if unchanged else 1)
