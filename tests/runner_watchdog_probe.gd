extends SceneTree
# Wall-clock watchdog acceptance probe, not part of test_*.gd discovery.
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	await create_timer(3.0).timeout
	print("WATCHDOG_PROBE_COMPLETE")
	quit()
