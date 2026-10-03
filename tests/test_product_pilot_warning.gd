extends SceneTree
const Pilot = preload("res://tests/test_dynamic_pickup_smoke.gd")
var failures: Array[String] = []

func _init() -> void:
	# Reduced from the actual Comet seed611 warning before its first impact.
	# The NPC is still centered and vx=0, but will traverse left after 0.226s.
	var obstacle := {"x":0.0,"y":315.0,"speed":180.0,"vx":0.0,"target_x":-260.0,
		"intent_lateral_speed":624.0,"warning_delay":0.226666666666666}
	_check(not Pilot.pilot_route_safe(-73.5,592.0,731.85,400.0,-73.5,[obstacle],-35.0),"holding position must anticipate announced left change")
	_check(not Pilot.pilot_route_safe(-73.5,592.0,731.85,400.0,260.0,[obstacle],-35.0),"coasting lateral escape is still too late for the warning fixture")
	_check(Pilot.pilot_route_safe(-73.5,592.0,731.85,400.0,260.0,[obstacle],-378.0),"early finite braking plus lateral escape is permitted")
	obstacle.warning_delay = 2.0
	_check(Pilot.pilot_route_safe(-73.5,592.0,731.85,400.0,-73.5,[obstacle],-35.0),"warning delay is respected rather than moving before it finishes")
	obstacle.erase("intent_lateral_speed")
	obstacle.erase("warning_delay")
	_check(Pilot.pilot_route_safe(-73.5,592.0,731.85,400.0,-73.5,[obstacle],-35.0),"legacy caller without optional intent fields preserves motion prediction")
	for failure in failures: push_error("PILOT_WARNING_SELF_CHECK "+failure)
	print("PILOT_WARNING_SELF_CHECK failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_pilot_warning.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
