class_name RunRating
extends RefCounted

const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")

static func reference_time(finish_distance: float) -> float:
	var slowest := INF
	for vehicle in VehicleCatalog.all():
		slowest = minf(slowest, float(vehicle.max_speed))
	# RunState advances metres at 0.1 times the internal speed, not HUD km/h.
	return maxf(0.0, finish_distance) / (slowest * 0.1)

static func targets_for_run(track: Dictionary, result: Dictionary) -> Dictionary:
	var targets: Dictionary = track.get("rating_targets", {}).duplicate(true)
	targets["time"] = reference_time(float(track.get("finish_distance", 0.0)))
	if result.has("generated_coins"):
		var count = result.generated_coins
		if not count is int or count < 0:
			return {}
		targets["coins"] = ceili(float(count) * 0.9)
	return targets

# Pure scoring; completion rewards remain the responsibility of progression.
static func evaluate(result: Dictionary, targets: Dictionary) -> Dictionary:
	if not result.get("cleared") is bool or not valid_targets(targets):
		return {}
	var cleared: bool = result.cleared
	var progress := 1.0
	if not cleared:
		if not _nonnegative_number(result.get("distance")) or not _positive_number(result.get("finish_distance")):
			return {}
		progress = clampf(float(result.distance) / float(result.finish_distance), 0.0, 1.0)
	var elapsed = result.get("survival", 0.0)
	if not _nonnegative_number(elapsed) or (float(elapsed) <= 0.0 and (cleared or progress > 0.0)):
		return {}
	for key in ["overtakes", "coins", "collisions"]:
		if not result.get(key, 0) is int or int(result.get(key, 0)) < 0:
			return {}
	var pace := clampf(2.0 - float(elapsed) / (float(targets.time) * progress), 0.0, 1.0) if progress > 0.0 else 0.0
	var time_points := roundi(40.0 * pace * progress)
	if cleared and float(elapsed) > float(targets.time): time_points = mini(39,time_points)
	var coin_points := roundi(20.0 * clampf(float(result.get("coins", 0)) / float(targets.coins), 0.0, 1.0)) if targets.coins > 0 else 0
	# Integer presentation must not move the actual full-score threshold.
	if int(result.get("coins", 0)) < float(targets.coins): coin_points = mini(19,coin_points)
	var parts := {
		"time": time_points,
		"overtakes": roundi(20.0 * clampf(float(result.get("overtakes", 0)) / float(targets.overtakes), 0.0, 1.0)),
		"collisions": roundi((20 - 4 * mini(5, int(result.get("collisions", 0)))) * progress),
		"coins": coin_points,
	}
	var total := int(parts.time + parts.overtakes + parts.collisions + parts.coins)
	if not cleared:
		var cap := floori(99.0 * progress)
		if total > cap:
			parts = _cap_parts(parts, total, cap)
			total = cap
		return {"total": total, "grade": grade_for(total), "parts": parts, "cleared": false, "progress": progress, "cap": cap, "targets": targets.duplicate()}
	return {"total": total, "grade": grade_for(total), "parts": parts, "targets": targets.duplicate()}

static func _cap_parts(parts: Dictionary, total: int, cap: int) -> Dictionary:
	var scaled := {}
	var fractions := {}
	var assigned := 0
	for key in parts:
		var exact := float(parts[key]) * cap / total
		scaled[key] = floori(exact)
		fractions[key] = exact - float(scaled[key])
		assigned += int(scaled[key])
	# Largest remainder allocation keeps the four displayed integers additive.
	while assigned < cap:
		var largest: String = "time"
		for key in fractions:
			if float(fractions[key]) > float(fractions[largest]):
				largest = key
		scaled[largest] += 1
		fractions[largest] = -1.0
		assigned += 1
	return scaled

static func grade_for(total: int) -> String:
	if total >= 90: return "S"
	if total >= 80: return "A"
	if total >= 70: return "B"
	if total >= 60: return "C"
	return "D"

static func valid_targets(targets: Dictionary) -> bool:
	return _positive_number(targets.get("time")) and _positive_number(targets.get("overtakes")) and _nonnegative_number(targets.get("coins"))

static func _positive_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0

static func _nonnegative_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0
