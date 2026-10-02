extends SceneTree

const Audit = preload("res://scripts/tests/ProductMainAudit.gd")
var failures := 0

func _init() -> void:
	_check(Audit.swept_contact(Vector2(-3, 0), Vector2(3, 0), Vector2.ONE), "crossing with both endpoints outside is detected")
	_check(not Audit.swept_contact(Vector2(-3, 2), Vector2(3, 2), Vector2.ONE), "parallel near miss stays clear")
	_check(Audit.swept_contact(Vector2.ZERO, Vector2.ZERO, Vector2.ONE), "stationary overlap is detected")
	_check(not Audit.swept_contact(Vector2(-3, 1), Vector2(3, 1), Vector2.ONE), "tangent alone is not body penetration")
	_check(Audit.trajectory_input("accelerate", 0).forward, "normal trajectory uses forward input")
	_check(Audit.trajectory_input("brake_repass", 600).brake, "scheduled braking enters at ten seconds")
	_check(not Audit.trajectory_input("brake_repass", 700).forward, "scheduled coast does not accelerate")
	_check(not Audit.trajectory_input("overdrive_brake", 479).forward and Audit.trajectory_input("overdrive_brake", 480).forward, "first real forward press has a preceding release")
	_check(not Audit.trajectory_input("overdrive_brake", 485).forward and Audit.trajectory_input("overdrive_brake", 486).forward, "second real forward press has a preceding release")
	_check(Audit.coverage("overdrive_brake", false, false, false).get("overdrive") == "insufficient", "unreached events never silently pass")
	_check(Audit.coverage("brake_repass", true, false, false).get("repass") == "insufficient", "braking is not proof of another scored pass")
	_check(is_equal_approx(Audit.ledger_value(5.0, {"kind":"consume", "amount":10.0}), 0.0), "fuel depletion clamps at zero on terminal frame")
	_check(is_equal_approx(Audit.ledger_value(95.0, {"kind":"add", "amount":20.0, "maximum":100.0}), 100.0), "natural resource credit respects cap")
	_check(is_equal_approx(Audit.ledger_value(19.0, {"kind":"repair", "amount":20.0, "maximum":100.0}), 19.0), "repair cannot revive failed integrity")
	var terminal_run := Audit.RunLedger.new(1.0, 100.0, 0.0)
	terminal_run.start()
	terminal_run.tick(1.0, 500.0, 500.0)
	_check(terminal_run.phase == terminal_run.Phase.GAME_OVER and terminal_run.events.size() == 1 and terminal_run.events[0].kind == "tick", "transparent probe retains resource event on genuine fuel-terminal tick")
	var hull := Audit.HullLedger.new()
	hull.apply_damage(85.0)
	hull.repair(20.0)
	_check(hull.current == 15.0 and hull.events.size() == 2, "transparent hull probe keeps failed repair behavior")
	print("PRODUCT_MAIN_AUDIT_SELF_CHECK failures=%d" % failures)
	print("TEST_COMPLETE test_product_main_audit.gd")
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("PRODUCT_MAIN_AUDIT_SELF_CHECK " + label)
