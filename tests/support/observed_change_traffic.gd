extends "res://tests/support/observed_motion_traffic.gd"
var change_issues: Array[String] = []
var change_issue_counts: Dictionary = {}
var first_change_issue: Dictionary = {}
var warnings_observed := 0
var starts_observed := 0
var completions_observed := 0
var cancellations_observed := 0
var maximum_pending_seconds := 0.0
var censored_retirements := 0
var _change_clock := 0.0
var _change_delta := 0.0
var _episodes: Dictionary = {}
var _in_change_step := false
var _behavior_after: Dictionary = {}

func _tick_step(delta: float, speed: float, lane: int, frame_start: Dictionary) -> void:
	_change_delta = delta
	_in_change_step = true
	_behavior_after.clear()
	super._tick_step(delta,speed,lane,frame_start)
	_change_clock += delta
	_in_change_step = false
	var motion_final := _motion_snapshot()
	motion_final.merge(_motion_retired)
	for key in motion_final:
		if not _behavior_after.has(key):
			_note_change("missing_lateral_behavior_boundary",{"key":key},motion_final[key])
		elif absf(motion_final[key].lane_position-_behavior_after[key].position) > 0.000000000001:
			_note_change("lateral_outside_behavior",_behavior_after[key],motion_final[key])
	var present: Dictionary = {}
	for vehicle in vehicles:
		var body := _change_snapshot(vehicle)
		present[body.key] = true
		if _episodes.has(body.key) and _episodes[body.key].active and not _active(body):
			_release(body,_change_clock)
	for key in _episodes.keys():
		if not present.has(key):
			if _episodes[key].active: censored_retirements += 1
			_episodes.erase(key)

func unresolved_changes() -> int:
	var count := 0
	for episode in _episodes.values():
		if episode.active: count += 1
	return count

func _update_normal_lane_behavior(vehicle: TrafficVehicle, delta: float) -> void:
	var before := _change_snapshot(vehicle)
	var had_warning: bool = _episodes.has(before.key) and _episodes[before.key].active
	super._update_normal_lane_behavior(vehicle,delta)
	var after := _change_snapshot(vehicle)
	_behavior_after[after.key] = after
	_observe_change(before,after,delta,had_warning)

func _update_fast_overtaker(vehicle: TrafficVehicle, delta: float, speed: float) -> void:
	var before := _change_snapshot(vehicle)
	var had_warning: bool = _episodes.has(before.key) and _episodes[before.key].active
	super._update_fast_overtaker(vehicle,delta,speed)
	var after := _change_snapshot(vehicle)
	_behavior_after[after.key] = after
	_observe_change(before,after,delta,had_warning)

func _begin_fast_lane_change(vehicle: TrafficVehicle, target_lane: int) -> void:
	super._begin_fast_lane_change(vehicle,target_lane)
	_register_warning(_change_snapshot(vehicle),_event_clock())

func _cancel_planned_lane_change(vehicle: TrafficVehicle) -> void:
	super._cancel_planned_lane_change(vehicle)
	var body := _change_snapshot(vehicle)
	if not _active(body): _release(body,_event_clock())

func _observe_change(before: Dictionary, after: Dictionary, delta: float, had_warning: bool) -> void:
	if not _valid_change(before) or not _valid_change(after):
		_note_change("invalid_change_snapshot",before,after)
		return
	var key: String = before.key
	if not _episodes.has(key): _episodes[key] = _empty_episode()
	var episode: Dictionary = _episodes[key]
	if before.warning and not had_warning:
		_note_change("missing_warning_evidence",before,after)
	if after.warning and not episode.active: _register_warning(after,_change_clock+delta)
	var visible: bool = before.y >= 40.0 and before.y <= _viewport_height-before.half_y
	if episode.active and not before.moving:
		# Ordinary warnings consume the creation step; fast planning starts its
		# timer after that step. Credit observed exposure, never reported timer.
		var exposes: bool = before.warning or (after.warning and before.kind != 2)
		if before.kind == 2 and episode.created == _change_clock+delta: exposes = false
		if not visible: episode.visible_seconds = 0.0
		elif exposes: episode.visible_seconds += delta
	var moved: bool = absf(after.position-before.position) > 0.000000000001
	var starts: bool = (moved or after.moving) and not before.moving
	if starts:
		starts_observed += 1
		if not visible: _note_change("offscreen_start",before,after)
		if not episode.active or episode.visible_seconds+0.00000001 < episode.required:
			_note_change("incomplete_visible_warning",before,after)
		else:
			var allowed_time := minf(delta,maxf(0.0,episode.visible_seconds-episode.required))
			var lateral_rate := 3.4 if before.kind == 2 else 2.4
			if absf(after.position-before.position) > lateral_rate*allowed_time+0.00000001:
				_note_change("movement_before_warning_end",before,after)
	if episode.active:
		episode.has_moved = episode.has_moved or starts or before.moving
		if after.reserved and not after.moving:
			var pending: float = _change_clock+delta-episode.created
			maximum_pending_seconds = maxf(maximum_pending_seconds,pending)
			if pending > 2.0+0.00000001: _note_change("reservation_deadline",before,after)
		if not _active(after): _release(after,_change_clock+delta)

func _register_warning(body: Dictionary, clock: float) -> void:
	if not _episodes.has(body.key): _episodes[body.key] = _empty_episode()
	var episode: Dictionary = _episodes[body.key]
	# Re-targeting/refreshing an existing reservation must not restart its age.
	if episode.active:
		if not episode.has_moved: episode.target = body.target
		return
	if clock-episode.released < 0.75-0.00000001: _note_change("early_reservation_retry",body,body)
	if body.y < 40.0 or body.y > _viewport_height-body.half_y: _note_change("offscreen_warning",body,body)
	episode.active = true
	episode.created = clock
	episode.visible_seconds = 0.0
	episode.required = 0.60 if body.kind == 2 else [0.66,0.62,0.60,0.59][difficulty_stage]
	episode.target = body.target
	episode.has_moved = false
	warnings_observed += 1

func _release(body: Dictionary, clock: float) -> void:
	if not _episodes.has(body.key): _episodes[body.key] = _empty_episode()
	var episode: Dictionary = _episodes[body.key]
	if episode.active:
		if episode.has_moved:
			if absf(body.position-episode.target) > 0.001:
				_note_change("incomplete_physical_change",body,body)
			else: completions_observed += 1
		else: cancellations_observed += 1
	episode.active = false
	episode.released = clock

func _empty_episode() -> Dictionary:
	return {"active":false,"created":0.0,"visible_seconds":0.0,"required":0.0,"target":0,"has_moved":false,"released":-INF}

func _event_clock() -> float:
	return _change_clock+_change_delta if _in_change_step else _change_clock

func _active(body: Dictionary) -> bool:
	return body.warning or body.moving or body.reserved

func _valid_change(body: Dictionary) -> bool:
	for key in ["y","position","half_y","remaining","wait","cooldown"]:
		if not is_finite(body[key]): return false
	return body.half_y > 0.0 and body.remaining >= 0.0 and body.wait >= 0.0 and body.cooldown >= 0.0

func _change_snapshot(vehicle: TrafficVehicle) -> Dictionary:
	return {"key":"%d/%d" % [vehicle.get_instance_id(),vehicle.motion_generation],"kind":vehicle.kind,"target":vehicle.target_lane,
		"position":vehicle.lane_position,"y":vehicle.y,"half_y":vehicle.half_length,"warning":vehicle.warning_started,
		"moving":vehicle.change_started,"reserved":vehicle.lane_change_reservation_active,"remaining":vehicle.warning_remaining,
		"wait":vehicle.lane_change_wait_seconds,"cooldown":vehicle.lane_change_cooldown}

func _note_change(category: String, before: Dictionary, after: Dictionary) -> void:
	change_issue_counts[category] = int(change_issue_counts.get(category,0))+1
	if change_issues.size() < 64: change_issues.append("%s:%s" % [category,before.key])
	if first_change_issue.is_empty():
		first_change_issue = {"category":category,"clock":_change_clock,"delta":_change_delta,"before":before.duplicate(true),
			"after":after.duplicate(true),"episode":_episodes.get(before.key,{}).duplicate(true)}
