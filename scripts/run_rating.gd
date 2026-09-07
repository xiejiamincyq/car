class_name RunRating
extends RefCounted

# Pure scoring: failed/invalid runs deliberately have no formal rating.
static func evaluate(result: Dictionary, targets: Dictionary) -> Dictionary:
	if result.get("cleared", false) != true or not valid_targets(targets):
		return {}
	var elapsed = result.get("survival", 0.0)
	if not _positive_number(elapsed):
		return {}
	for key in ["overtakes", "coins", "collisions"]:
		if not result.get(key, 0) is int or int(result.get(key, 0)) < 0:
			return {}
	var parts := {
		"time": roundi(40.0 * clampf(2.0 - float(elapsed) / float(targets.time), 0.0, 1.0)),
		"overtakes": roundi(20.0 * clampf(float(result.get("overtakes", 0)) / float(targets.overtakes), 0.0, 1.0)),
		"collisions": 20 - 4 * mini(5, int(result.get("collisions", 0))),
		"coins": roundi(20.0 * clampf(float(result.get("coins", 0)) / float(targets.coins), 0.0, 1.0)),
	}
	var total := int(parts.time + parts.overtakes + parts.collisions + parts.coins)
	return {"total": total, "grade": grade_for(total), "parts": parts}

static func grade_for(total: int) -> String:
	if total >= 90: return "S"
	if total >= 80: return "A"
	if total >= 70: return "B"
	if total >= 60: return "C"
	return "D"

static func valid_targets(targets: Dictionary) -> bool:
	return _positive_number(targets.get("time")) and _positive_number(targets.get("overtakes")) and _positive_number(targets.get("coins"))

static func _positive_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0
