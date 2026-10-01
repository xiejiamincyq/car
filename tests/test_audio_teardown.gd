extends SceneTree

const AudioTeardown = preload("res://tests/support/audio_teardown.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := AudioStreamPlayer.new()
	root.add_child(player)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.data = PackedByteArray([0, 0, 0, 0])
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 4
	player.stream = stream
	player.play()
	var pending := AudioTeardown.capture(player)
	assert(pending.size() == 1, "Capture must observe a real playback, not just a stopped player")
	var retained: AudioStreamPlayback = player.get_stream_playback()
	player.stop()
	player.stream = null
	player.queue_free()
	await process_frame
	var timeout := 1.0 if "--long-timeout-probe" in OS.get_cmdline_user_args() else 0.05
	assert(not await AudioTeardown.wait_for_release(self, pending, timeout), "A retained playback must fail the bounded cleanup check, not pass after a fixed delay")
	assert(pending[0].get_ref() == retained)
	retained = null
	assert(await AudioTeardown.wait_for_release(self, pending), "Released playbacks must drain without exit leaks")
	assert(pending[0].get_ref() == null)
	print("AUDIO_TEARDOWN_COMPLETE")
	print("TEST_COMPLETE test_audio_teardown.gd")
	quit()
