extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
var failures := 0
var main

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	await process_frame
	for pair in [[KEY_W, KEY_W], [KEY_UP, KEY_UP], [KEY_W, KEY_UP], [KEY_UP, KEY_W]]:
		await _prepare()
		await _key(pair[0], true)
		await _key(pair[0], false)
		main._process(0.1)
		await _key(pair[1], true)
		main._process(0.01)
		_check(main.overdrive.is_active(), "released forward pair %s activates" % [pair])
		await _key(pair[1], false)
	var extra_binding := InputEventKey.new()
	extra_binding.keycode = KEY_I
	InputMap.action_add_event("accelerate", extra_binding)
	await _prepare()
	await _double(KEY_I)
	_check(main.overdrive.is_active(), "new forward bindings share overdrive without a second key list")
	InputMap.action_erase_event("accelerate", extra_binding)
	for interval in [0.28, 0.2801]:
		await _prepare()
		await _key(KEY_UP, true)
		await _key(KEY_UP, false)
		main._process(interval)
		await _key(KEY_UP, true)
		_check(main.overdrive.is_active() == (interval <= 0.28), "exact double-tap boundary %s" % interval)
		await _key(KEY_UP, false)
	await _prepare()
	await _key(KEY_W, true)
	main._process(0.05)
	await _key(KEY_UP, true)
	main._process(0.05)
	await _key(KEY_W, true, true)
	main._process(0.05)
	_check(not main.overdrive.is_active(), "overlapping keys and echo are not a double tap")
	await _key(KEY_W, false)
	await _key(KEY_UP, false)
	await _key(KEY_UP, true)
	main._process(0.01)
	_check(main.overdrive.is_active(), "all forward keys must release before a second edge")
	await _key(KEY_UP, false)
	await _prepare()
	await _key(KEY_W, true)
	await _key(KEY_W, false)
	main._process(0.3)
	await _key(KEY_UP, true)
	main._process(0.01)
	_check(not main.overdrive.is_active(), "expired pair does not activate")
	await _key(KEY_UP, false)
	await _prepare()
	main.run.fuel = 14.0
	await _double(KEY_UP)
	_check(not main.overdrive.is_active(), "low fuel rejects arrow activation")
	await _prepare()
	await _double(KEY_UP)
	var remaining: float = main.overdrive.active_remaining
	await _double(KEY_W)
	_check(main.overdrive.active_remaining < remaining, "extra taps cannot restart active overdrive")
	main.overdrive.tick(10.0, 100.0)
	await _double(KEY_UP)
	_check(main.overdrive.is_cooling_down(), "cooldown rejects new pairs")
	for phase in [main.RunState.Phase.READY, main.RunState.Phase.COUNTDOWN, main.RunState.Phase.RUN_CLEAR, main.RunState.Phase.GAME_OVER]:
		await _prepare()
		main.run.phase = phase
		main.run.countdown_remaining = 3.0
		await _key(KEY_UP, true)
		await _key(KEY_UP, false)
		await _key(KEY_UP, true)
		await _key(KEY_UP, false)
		_check(not main.overdrive.is_active(), "non-driving phase ignores pairs: %s" % phase)
	for loss in [false, true]:
		await _prepare()
		await _key(KEY_W, true)
		main._process(0.05)
		if loss:
			main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		else:
			main._pause_run()
		main.run.phase = main.RunState.Phase.RUNNING
		await _key(KEY_UP, true)
		main._process(0.01)
		_check(not main.overdrive.is_active(), "held key cannot bridge pause/focus")
		await _key(KEY_W, false)
		await _key(KEY_UP, false)
		await _double(KEY_UP)
		_check(main.overdrive.is_active(), "fresh released pair works after pause/focus")
	await _prepare()
	await _key(KEY_W, true)
	main._process(0.05)
	main._reset_run()
	main.run.start()
	await _key(KEY_UP, true)
	main._process(0.01)
	_check(not main.overdrive.is_active(), "reset cannot reuse held forward keys")
	await _key(KEY_W, false)
	await _key(KEY_UP, false)
	await _double(KEY_UP)
	_check(main.overdrive.is_active(), "fresh pair works after reset")
	var teardown = preload("res://tests/support/audio_teardown.gd")
	var playbacks: Array[WeakRef] = teardown.capture(main)
	main.audio_director.shutdown()
	main.queue_free()
	await process_frame
	_check(await teardown.wait_for_release(self, playbacks), "input test audio retires within the bounded teardown")
	print("FORWARD_INPUT failures=%d" % failures)
	print("TEST_COMPLETE test_forward_overdrive_input.gd")
	quit(1 if failures > 0 else 0)

func _prepare() -> void:
	await _key(KEY_W, false)
	await _key(KEY_UP, false)
	main._reset_run()
	main.run.start()

func _double(code: Key) -> void:
	await _key(code, true)
	await _key(code, false)
	main._process(0.05)
	await _key(code, true)
	main._process(0.01)
	await _key(code, false)

func _key(code: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed:
		main._process(0.0)
	await process_frame

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FORWARD_INPUT: " + label)
