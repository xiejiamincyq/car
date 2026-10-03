extends SceneTree
const Hard = preload("res://scripts/tests/ProductHardSupplyAudit.gd")
var failures: Array[String] = []

func _init() -> void:
	# Natural Sunrise/Comet/30-hull/2026 approach: 334px lateral travel,
	# damaged steering 296px/s, road-fixed repair already at y238.
	_check(Hard.supply_needs_braking(-74.1,571.1,296.4,260.0,238.4,592.0),"visible repair needs more lateral travel time")
	_check(Hard.supply_needs_braking(74.1,571.1,296.4,-260.0,238.4,592.0),"supply pacing is symmetric across the road")
	_check(Hard.supply_needs_braking(86.6,107.5,355.0,260.0,643.8,592.0),"last portion of actual supply contact window remains actionable")
	_check(not Hard.supply_needs_braking(86.6,107.5,355.0,260.0,654.0,592.0),"exact rear tangent is outside strict supply contact")
	_check(not Hard.supply_needs_braking(240.0,571.1,296.4,260.0,238.4,592.0),"within pickup contact width needs no lateral pacing")
	_check(not Hard.supply_needs_braking(-74.1,200.0,296.4,260.0,238.4,592.0),"slow approach already provides enough time")
	_check(not Hard.supply_needs_braking(-74.1,0.0,296.4,260.0,238.4,592.0),"stopped car is not braked forever")
	_check(not Hard.supply_needs_braking(-74.1,571.1,0.0,260.0,238.4,592.0),"zero authority does not divide by zero")
	_check(not Hard.supply_needs_braking(-74.1,571.1,296.4,260.0,-90.0,592.0),"offscreen supply cannot cause clairvoyant braking")
	_check(not Hard.supply_needs_braking(-74.1,571.1,296.4,260.0,700.0,592.0),"already missed supply is not pursued")
	for failure in failures: push_error("SUPPLY_PACE_SELF_CHECK "+failure)
	print("SUPPLY_PACE_SELF_CHECK failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_pilot_supply_pace.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
