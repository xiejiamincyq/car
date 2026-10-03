extends "res://scripts/traffic_director.gd"

const Oracle = preload("res://tests/support/traffic_audit_geometry.gd")
var observed_steps := 0
var maximum_step := 0.0
var birth_count := 0
var retirement_count := 0
var audit_issues: Array[String] = []
var issue_counts: Dictionary = {}
var first_issue_snapshot: Dictionary = {}
var last_retired: Dictionary = {}
var _step_births: Dictionary = {}
var _step_retired: Dictionary = {}

func _tick_step(delta: float, player_speed: float, player_lane: int, frame_start: Dictionary) -> void:
	var before := _snapshot()
	_step_births.clear()
	_step_retired.clear()
	super._tick_step(delta,player_speed,player_lane,frame_start)
	observed_steps += 1
	maximum_step = maxf(maximum_step,delta)
	var after := _snapshot()
	var issues := Oracle.audit_step(before,after,_step_births,_step_retired,_viewport_height)
	if not issues.is_empty() and first_issue_snapshot.is_empty():
		first_issue_snapshot = {"step":observed_steps,"delta":delta,"player_speed":player_speed,"issues":issues.duplicate(),
			"before":before,"after":after,"births":_step_births.duplicate(true),"retired":_step_retired.duplicate(true)}
	for issue in issues:
		var category := issue.get_slice(":",0)
		issue_counts[category] = int(issue_counts.get(category,0))+1
		if audit_issues.size() < 64: audit_issues.append(issue)

func _spawn_next(player_speed: float, player_lane: int) -> void:
	var before := _snapshot()
	super._spawn_next(player_speed,player_lane)
	var after := _snapshot()
	for key in after:
		if not before.has(key):
			_step_births[key] = after[key]
			birth_count += 1

func _recycle_offscreen_vehicles() -> void:
	# Capture scalars before the pool can mutate this reference's generation.
	var final_positions := _snapshot()
	super._recycle_offscreen_vehicles()
	var after := _snapshot()
	for key in final_positions:
		if not after.has(key):
			_step_retired[key] = final_positions[key]
			last_retired = final_positions[key].duplicate()
			retirement_count += 1

func _snapshot() -> Dictionary:
	var result: Dictionary = {}
	var lane_width := GameConfig.ROAD_HALF_WIDTH*2.0/lane_count
	for vehicle in vehicles:
		var key := "%d/%d" % [vehicle.get_instance_id(),vehicle.motion_generation]
		result[key] = {"id":vehicle.get_instance_id(),"generation":vehicle.motion_generation,
			"x":(vehicle.lane_position+0.5)*lane_width-GameConfig.ROAD_HALF_WIDTH,"y":vehicle.y,
			"half_x":vehicle.half_width,"half_y":vehicle.half_length}
	return result
