extends RefCounted

## AudioServer retires stopped playbacks after a mix and main-thread cleanup.
## Fast headless frames alone do not prove that this lifecycle has completed.
static func capture(source: Node) -> Array[WeakRef]:
	var refs: Array[WeakRef] = []
	if source is AudioStreamPlayer and source.has_stream_playback():
		refs.append(weakref(source.get_stream_playback()))
	for child in source.get_children():
		refs.append_array(capture(child))
	return refs

static func wait_for_release(tree: SceneTree, refs: Array[WeakRef], timeout_seconds: float = 2.0) -> bool:
	var watched: Array[WeakRef] = refs.duplicate()
	# A silent probe observes a retirement cycle even if stop() has already
	# discarded the player's handle. It does not suppress any exit diagnostics.
	var probe := AudioStreamPlayer.new()
	var silence := AudioStreamWAV.new()
	silence.format = AudioStreamWAV.FORMAT_8_BITS
	silence.data = PackedByteArray([0, 0, 0, 0])
	silence.loop_mode = AudioStreamWAV.LOOP_FORWARD
	silence.loop_end = 4
	probe.stream = silence
	probe.volume_db = -80.0
	tree.root.add_child(probe)
	probe.play()
	watched.append(weakref(probe.get_stream_playback()))
	probe.stop()
	probe.stream = null
	probe.queue_free()
	var deadline := Time.get_ticks_msec() + int(maxf(timeout_seconds, 0.0) * 1000.0)
	while _has_live_playback(watched):
		if Time.get_ticks_msec() >= deadline:
			return false
		await tree.process_frame
	return true

static func _has_live_playback(refs: Array[WeakRef]) -> bool:
	for ref in refs:
		if ref.get_ref() != null:
			return true
	return false
