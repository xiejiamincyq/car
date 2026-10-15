extends RefCounted
## Acceptance for an external, real-time Main driver, not human playtest.
static func key_event(key: int, down: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	return event

static func moving_frame(previous_phase_running: bool, previous_distance: float, distance: float, gap: float) -> bool:
	# Pauses, stopped vehicles and suspend/resume gaps cannot supply driving time.
	return previous_phase_running and distance > previous_distance + 0.000001 and gap > 0.0 and gap <= 0.25

static func throttle_held(previous: bool, speed: float, maximum: float) -> bool:
	if speed < maximum*0.65: return true
	if speed > maximum*0.75: return false
	return previous

static func missing_coverage(summary: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	var required := {"wall_seconds":1800.0,"driving_wall_seconds":1800.0,"returns":20,"outcomes":20,"tracks":4,"cars":6,"difficulties":3}
	for field in required:
		if float(summary.get(field, 0)) < required[field]: missing.append(field)
	if not summary.get("source_stable", false): missing.append("source_changed")
	if not summary.get("errors", []).is_empty(): missing.append("runtime_oracles")
	if int(summary.get("title_node_drift", 999)) > 2: missing.append("retained_title_nodes")
	return missing
