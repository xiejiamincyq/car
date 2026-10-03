extends "res://tests/support/observed_core_traffic.gd"

const MotionOracle = preload("res://tests/support/traffic_motion_audit.gd")
var motion_steps := 0
var frame_checks := 0
var motion_birth_count := 0
var motion_retirement_count := 0
var motion_issues: Array[String] = []
var motion_issue_counts: Dictionary = {}
var first_motion_issue: Dictionary = {}
var last_frame_travel: Dictionary = {}
var _motion_births: Dictionary = {}
var _motion_retired: Dictionary = {}
var _frame_travel: Dictionary = {}
var _frame_kinds: Dictionary = {}

func tick(delta: float, player_speed: float, player_lane: int = 1) -> void:
	_frame_travel.clear()
	_frame_kinds.clear()
	super.tick(delta,player_speed,player_lane)
	frame_checks += 1
	last_frame_travel = _frame_travel.duplicate()
	_record_motion(MotionOracle.audit_frame(_frame_travel,_frame_kinds,maxf(0.0,delta)),
		{"frame":frame_checks,"delta":delta,"travel":last_frame_travel,"kinds":_frame_kinds.duplicate()})

func _tick_step(delta: float, player_speed: float, player_lane: int, frame_start: Dictionary) -> void:
	var before := _motion_snapshot()
	_motion_births.clear()
	_motion_retired.clear()
	super._tick_step(delta,player_speed,player_lane,frame_start)
	motion_steps += 1
	var after := _motion_snapshot()
	after.merge(_motion_retired)
	var starts := before.duplicate()
	starts.merge(_motion_births)
	var issues := MotionOracle.audit_step(starts,after,delta,player_speed,GameConfig.ROAD_SCROLL_MULTIPLIER)
	for key in starts:
		if after.has(key):
			_frame_travel[key] = float(_frame_travel.get(key,0.0))+absf(after[key].lane_position-starts[key].lane_position)
			if not _frame_kinds.has(key): _frame_kinds[key] = starts[key].kind
	_record_motion(issues,{"step":motion_steps,"delta":delta,"player_speed":player_speed,"before":before,"after":after,
		"births":_motion_births.duplicate(true),"retired":_motion_retired.duplicate(true)})

func _spawn_next(player_speed: float, player_lane: int) -> void:
	var before := _motion_snapshot()
	super._spawn_next(player_speed,player_lane)
	var after := _motion_snapshot()
	for key in after:
		if not before.has(key):
			_motion_births[key] = after[key]
			motion_birth_count += 1

func _recycle_offscreen_vehicles() -> void:
	var final := _motion_snapshot()
	super._recycle_offscreen_vehicles()
	var after := _motion_snapshot()
	for key in final:
		if not after.has(key):
			_motion_retired[key] = final[key]
			motion_retirement_count += 1

func _record_motion(issues: Array[String], evidence: Dictionary) -> void:
	if not issues.is_empty() and first_motion_issue.is_empty():
		first_motion_issue = evidence.duplicate(true)
		first_motion_issue.issues = issues.duplicate()
	for issue in issues:
		var category := issue.get_slice(":",0)
		motion_issue_counts[category] = int(motion_issue_counts.get(category,0))+1
		if motion_issues.size() < 64: motion_issues.append(issue)

func _motion_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for vehicle in vehicles:
		var key := "%d/%d" % [vehicle.get_instance_id(),vehicle.motion_generation]
		result[key] = {"id":vehicle.get_instance_id(),"generation":vehicle.motion_generation,"kind":vehicle.kind,
			"speed":vehicle.actual_world_speed,"cruise_speed":vehicle.cruise_speed,"lane_position":vehicle.lane_position,"y":vehicle.y}
	return result
