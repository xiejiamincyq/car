extends "res://tests/support/observed_change_traffic.gd"

var last_path_frame: Dictionary = {}
var _boundary_cones: Array[Dictionary] = []

func _tick_step(delta: float, player_speed: float, player_lane: int, frame_start: Dictionary) -> void:
	var cone_points := lane_events.cone_markers(_viewport_height)
	_boundary_cones.clear()
	super._tick_step(delta,player_speed,player_lane,frame_start)
	last_path_frame = _frame_from_raw(last_core_step,delta,player_speed)
	cone_points.append_array(_boundary_cones)
	# Both visible endpoints plus a full road-advance margin conservatively
	# cover any intervening cone motion, including early event retirement.
	# At the real product's <=1200 internal speed, no cone can cross the
	# entire visible interval between the two samples (<=23 pixels/substep).
	for cone in cone_points:
		var x: float = cone.lane_position*260.0-390.0
		last_path_frame.bodies.append({"x0":x,"x1":x,"y0":cone.y,"y1":cone.y,
			"half_x":14.0,"half_y":16.0+player_speed*1.15*delta,"family":"cone","identity":str(cone.id)})
	# A bad motion/lifecycle source is never silently treated as an empty road.
	for counts in [issue_counts,core_issue_counts,motion_issue_counts,change_issue_counts]:
		if not counts.is_empty(): last_path_frame.status = "invalid"
	if lane_count != 3 or player_speed > 1200.0: last_path_frame.status = "invalid"

func _mark_motion_boundary() -> void:
	if not _motion_seen: _boundary_cones = lane_events.cone_markers(_viewport_height)
	super._mark_motion_boundary()

static func _frame_from_raw(raw: Dictionary, delta: float, speed: float) -> Dictionary:
	var frame := {"status":"invalid","dt":delta,"speed":speed,"bodies":[],"scope":"conservative_whole_substep_envelopes"}
	for field in ["npc_before","npc_births","npc_final","core_before","core_births","core_final","early_retired","motion_cores","retirement_reasons"]:
		if not raw.has(field) or raw[field] is not Dictionary: return frame
	if not is_finite(delta) or delta <= 0.0 or delta > 1.0/60.0+0.000000000001 or not is_finite(speed) or speed < 0.0: return frame
	for family in ["npc","core"]:
		var starts: Dictionary = raw[family+"_before"].duplicate()
		for key in raw[family+"_births"]:
			if starts.has(key): return frame
			starts[key] = raw[family+"_births"][key]
		var finals: Dictionary = raw[family+"_final"]
		for key in finals:
			if not starts.has(key): return frame
		for key in starts:
			if not finals.has(key): return frame
			var before: Dictionary = starts[key]
			var after: Dictionary = finals[key]
			if not Oracle._valid_body(before) or not Oracle._valid_body(after): return frame
			if not Oracle.same_identity(before,after) or before.half_x != after.half_x or before.half_y != after.half_y: return frame
			# An unchanged newborn cancelled before any movement was an atomic
			# unpublished proposal. Existing/advanced/late-retired bodies remain.
			if (family == "core" and not raw.core_before.has(key) and raw.core_births.has(key)
				and raw.early_retired.has(key) and not raw.motion_cores.has(key)
				and raw.retirement_reasons.get(key,"") == "cancelled_warning"
				and before == raw.early_retired[key] and before == after): continue
			# NPC y moves once per actual substep. A bounded lateral path from
			# a to b can visit p only if |p-a|+|b-p| <= total_budget.
			# Thus all bends lie within midpoint(a,b) +/- total_budget/2.
			# Birth/retirement occupy the full interval conservatively, not later
			# than reality. This can miss a route but cannot create a fake gap.
			var lateral_budget := 3.4*260.0*delta+0.00000001
			if family == "npc" and absf(after.x-before.x) > lateral_budget: return frame
			var extra_x := lateral_budget*0.5 if family == "npc" else absf(after.x-before.x)*0.5
			var center_x: float = (before.x+after.x)*0.5
			var center_y: float = (before.y+after.y)*0.5
			frame.bodies.append({"x0":center_x,"x1":center_x,"y0":center_y,"y1":center_y,
				"half_x":before.half_x+extra_x,
				"half_y":before.half_y+absf(after.y-before.y)*0.5,"family":family,"identity":key})
	frame.status = "valid"
	return frame
