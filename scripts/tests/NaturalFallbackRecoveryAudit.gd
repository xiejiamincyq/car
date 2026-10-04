extends "res://scripts/tests/NaturalIntentRecoveryAudit.gd"

func _plan_trace(frames: Array, drive, hull: float = 100.0, initial_x: float = 0.0) -> Dictionary:
	# Validate the whole physical record before a local search can stop early.
	if frames.is_empty() or frames.size() > 7200:
		return {"status":"invalid","controls":[],"xs":[]}
	for offset in range(0,frames.size(),120):
		var trace := {"x0":initial_x,"y":592.0,"road_half":drive.road_half_width,
			"half_x":drive.player_half_width,"half_y":30.0,"steering_speed":drive.steering_speed,
			"max_speed":drive.max_speed,"hull":hull,"frames":frames.slice(offset,offset+120)}
		if not PathOracle._valid_trace(trace):
			return {"status":"invalid","controls":[],"xs":[]}
	var primary := super._plan_trace(frames,drive,hull,initial_x)
	if primary.status != "unverified": return primary
	# Intent is a conservative planning preference, not extra physical geometry.
	# Keep every committed prefix input; retry only the finite search-miss suffix.
	var start = primary.get("failed_window",-1)
	if typeof(start) != TYPE_INT or start < 0 or start >= frames.size() or primary.controls.size() != start or primary.xs.size() != start+1:
		return {"status":"invalid","controls":[],"xs":[]}
	var suffix: Array = []
	for frame in frames.slice(start):
		var copy: Dictionary = frame.duplicate()
		copy.erase("lane_intents")
		suffix.append(copy)
	var was_repairing := _repairing
	_repairing = true
	var alternate := super._plan_trace(suffix,drive,hull,primary.xs.back())
	_repairing = was_repairing
	if alternate.status != "candidate":
		primary.intent_fallback_window = start
		primary.intent_fallback_status = alternate.status
		return primary
	var controls: Array = primary.controls.duplicate()
	controls.append_array(alternate.controls)
	var xs: Array = primary.xs.duplicate()
	xs.append_array(alternate.xs.slice(1))
	alternate.controls = controls
	alternate.xs = xs
	alternate.intent_fallback_window = start
	alternate.scope = "one physical-geometry suffix candidate after intent search miss; full actual replay still required"
	for key in ["windows","refinements","hold_windows","center_windows"]:
		alternate[key] = primary.get(key,0)+alternate.get(key,0)
	return alternate
