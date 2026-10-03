extends "res://scripts/tests/ProductMainPathAudit.gd"

func _run() -> void:
	var passed := await _selfcheck()
	print("TEST_COMPLETE test_product_main_path_joint.gd")
	quit(0 if passed else 1)
