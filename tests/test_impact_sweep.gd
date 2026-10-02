extends SceneTree

const Impact = preload("res://scripts/impact_model.gd")
var failures := 0

func _init() -> void:
	var model := Impact.new()
	if not model.has_method("swept_rect_entry"):
		_check(false, "pure open-rectangle entry helper is required")
	else:
		var corner: Dictionary = model.call("swept_rect_entry", Vector2(58.24,63.235), Vector2(47.84,73.585), Vector2(50,72))
		_check(corner.hit and corner.normal == Vector2.RIGHT, "corner uses approaching right-side entry, not separated bottom endpoint")
		_check(absf(corner.fraction - (58.24-50.0)/10.4) < 0.00001, "corner time of entry is the slab intersection")
		var horizontal: Dictionary = model.call("swept_rect_entry", Vector2(-3,0), Vector2(3,0), Vector2.ONE)
		_check(horizontal.hit and horizontal.normal == Vector2.LEFT, "horizontal two-clear-endpoints entry has left-side normal")
		var vertical: Dictionary = model.call("swept_rect_entry", Vector2(0,3), Vector2(0,-3), Vector2.ONE)
		_check(vertical.hit and vertical.normal == Vector2.DOWN, "longitudinal traversal has rear-entry normal")
		for pair in [[Vector2(-3,1),Vector2(3,1)], [Vector2(-3,-3),Vector2(-1,-1)], [Vector2(1,0),Vector2(2,0)], [Vector2.ZERO,Vector2(3,0)]]:
			_check(not model.call("swept_rect_entry", pair[0], pair[1], Vector2.ONE).hit, "tangency, pure endpoint touch, outward departure or existing overlap is not a new entry: %s" % [pair])
		_check(model.call("swept_rect_entry", Vector2(1,0),Vector2.ZERO,Vector2.ONE).hit, "boundary moving into open interior is an entry")
	print("IMPACT_SWEEP failures=%d" % failures)
	print("TEST_COMPLETE test_impact_sweep.gd")
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("IMPACT_SWEEP " + message)
