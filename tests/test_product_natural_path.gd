extends "res://scripts/tests/ProductNaturalPathAudit.gd"

func _init() -> void:
	call_deferred("_run_selfcheck")

func _run_selfcheck() -> void:
	var passed := _selfcheck()
	print("TEST_COMPLETE test_product_natural_path.gd")
	quit(0 if passed else 1)
