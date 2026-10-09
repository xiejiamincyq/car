extends RefCounted

# Frozen acceptance limits, independent of production following/merge policy.
const ACCELERATION := 140.0
const FAST_ACCELERATION := 360.0
const BRAKING := 420.0
const FRAME_TOLERANCE := 0.0001
const NUMERIC_TOLERANCE := 0.00000001

static func audit_step(before: Dictionary, after: Dictionary, delta: float, player_speed: float, scroll: float) -> Array[String]:
	var issues: Array[String] = []
	if not is_finite(delta) or delta < 0.0 or delta > 1.0/60.0+0.000000000001 or not is_finite(player_speed) or player_speed < 0.0 or not is_finite(scroll) or scroll <= 0.0:
		issues.append("invalid_motion_interval")
		return issues
	for key in after:
		if not before.has(key): issues.append("motion_missing_start:%s" % key)
	for key in before:
		if not after.has(key):
			issues.append("motion_missing_final:%s" % key)
			continue
		var a: Dictionary = before[key]
		var b: Dictionary = after[key]
		if not _valid(a) or not _valid(b):
			issues.append("invalid_motion:%s" % key)
			continue
		if a.id != b.id or a.generation != b.generation:
			issues.append("motion_identity_changed:%s" % key)
			continue
		if a.kind != b.kind: issues.append("motion_kind_changed:%s" % key)
		if a.cruise_speed != b.cruise_speed: issues.append("cruise_changed:%s" % key)
		var change: float = b.speed-a.speed
		var acceleration := FAST_ACCELERATION if a.kind == 2 else ACCELERATION
		if change > acceleration*delta+NUMERIC_TOLERANCE: issues.append("world_acceleration:%s" % key)
		if -change > BRAKING*delta+NUMERIC_TOLERANCE: issues.append("world_braking:%s" % key)
		if absf(b.lane_position-a.lane_position) > _lateral_rate(a.kind)*delta+NUMERIC_TOLERANCE:
			issues.append("lateral_rate:%s" % key)
		var expected: float = (player_speed-b.speed)*scroll*delta
		if absf((b.y-a.y)-expected) > NUMERIC_TOLERANCE:
			issues.append("longitudinal_displacement:%s" % key)
	return issues

static func audit_frame(travel: Dictionary, kinds: Dictionary, delta: float) -> Array[String]:
	var issues: Array[String] = []
	if not is_finite(delta) or delta < 0.0:
		issues.append("invalid_frame_interval")
		return issues
	for key in travel:
		if not kinds.has(key) or not _valid_kind(kinds[key]) or not _finite_scalar(travel[key]) or travel[key] < 0.0:
			issues.append("invalid_frame_travel:%s" % key)
			continue
		if travel[key] > _lateral_rate(kinds[key])*delta+FRAME_TOLERANCE:
			issues.append("frame_lateral_budget:%s" % key)
	return issues

static func _valid(body: Dictionary) -> bool:
	for field in ["id","generation"]:
		if not body.has(field) or typeof(body[field]) != TYPE_INT: return false
	if body.generation < 1 or not body.has("kind") or not _valid_kind(body.kind): return false
	for field in ["speed","cruise_speed","lane_position","y"]:
		if not body.has(field) or not _finite_scalar(body[field]): return false
	return body.speed >= 0.0 and body.cruise_speed > 0.0

static func _valid_kind(kind: Variant) -> bool:
	return typeof(kind) == TYPE_INT and kind >= 0 and kind <= 3

static func _finite_scalar(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

static func _lateral_rate(kind: int) -> float:
	return 3.4 if kind == 2 else 2.4
