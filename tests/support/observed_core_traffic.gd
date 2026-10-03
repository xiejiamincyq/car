extends "res://tests/support/observed_traffic.gd"

const Events = preload("res://tests/support/observed_lane_events.gd")
const CoreOracle = preload("res://tests/support/traffic_core_audit.gd")
var core_steps := 0
var core_birth_count := 0
var core_retirement_count := 0
var aborted_core_birth_count := 0
var core_issues: Array[String] = []
var core_issue_counts: Dictionary = {}
var first_core_issue: Dictionary = {}
var last_core_step: Dictionary = {}
var _motion_seen := false
var _motion_cores: Dictionary = {}
var _early_retired: Dictionary = {}

func _init(seed: int, lanes: int = 3, safe_distance: float = 620.0, lane_gap: float = 180.0) -> void:
	super(seed,lanes,safe_distance,lane_gap)
	lane_events = Events.new(_event_seed(seed),lanes,GameConfig.LANE_EVENTS_ENABLED)

func _tick_step(delta: float, player_speed: float, player_lane: int, frame_start: Dictionary) -> void:
	var events = lane_events as Events
	var npc_before := _snapshot()
	var core_before: Dictionary = events.raw_cores()
	events.begin_step()
	_motion_seen = false
	_motion_cores.clear()
	_early_retired.clear()
	super._tick_step(delta,player_speed,player_lane,frame_start)
	core_steps += 1
	core_birth_count += events.births.size()
	core_retirement_count += events.retired.size()
	var npc_final := _snapshot()
	npc_final.merge(_step_retired)
	var core_final: Dictionary = events.raw_cores()
	core_final.merge(events.retired)
	var core_start := core_before.duplicate()
	core_start.merge(events.births)
	var issues: Array[String] = []
	# Early retirement occurs before any NPC lateral/longitudinal update.
	# Only previously existing NPCs can meet that core advance; unborn NPCs
	# must not be projected backwards into this phase.
	var early_start: Dictionary = {}
	var physical_early_retired: Dictionary = {}
	for key in _early_retired:
		# Scheduling is an atomic proposal before NPC movement. A newborn
		# unchanged core cancelled at this boundary was never published;
		# keep its raw lifecycle/count, not a fictitious physical contact.
		if (not core_before.has(key) and events.births.has(key)
			and events.retirement_reasons.get(key,"") == "cancelled_warning"
			and events.births[key] == _early_retired[key]
			and CoreOracle.Geometry._valid_body(events.births[key])):
			aborted_core_birth_count += 1
			continue
		if core_start.has(key): early_start[key] = core_start[key]
		physical_early_retired[key] = _early_retired[key]
	issues.append_array(CoreOracle.audit_cross_step(npc_before,npc_before,early_start,physical_early_retired))
	var live_start: Dictionary = {}
	var live_final: Dictionary = {}
	for key in _motion_cores:
		if core_start.has(key): live_start[key] = core_start[key]
		if core_final.has(key): live_final[key] = core_final[key]
	var old_final: Dictionary = {}
	for key in npc_before:
		if npc_final.has(key): old_final[key] = npc_final[key]
	issues.append_array(CoreOracle.audit_cross_step(npc_before,old_final,live_start,live_final))
	# Birth is after the core's road advance. The admitted body has no earlier
	# lifetime. Hold the core at the actual pre-NPC-motion boundary for it.
	var born_final: Dictionary = {}
	for key in _step_births:
		if npc_final.has(key): born_final[key] = npc_final[key]
	issues.append_array(CoreOracle.audit_cross_step(_step_births,born_final,_motion_cores,live_final))
	for key in core_start:
		if not _motion_cores.has(key) and not _early_retired.has(key):
			issues.append("core_unobserved_lifetime:%s" % key)
	for key in core_final:
		if not _motion_cores.has(key) and not _early_retired.has(key):
			issues.append("core_unobserved_final:%s" % key)
	if not _motion_seen: issues.append("core_missing_motion_boundary")
	last_core_step = {"step":core_steps,"delta":delta,"player_speed":player_speed,
		"npc_before":npc_before,"npc_births":_step_births.duplicate(true),"npc_final":npc_final,
		"core_before":core_before,"core_births":events.births.duplicate(true),
		"early_retired":_early_retired.duplicate(true),"motion_cores":_motion_cores.duplicate(true),
		"core_final":core_final,"retirement_reasons":events.retirement_reasons.duplicate(true)}
	if not issues.is_empty() and first_core_issue.is_empty():
		first_core_issue = last_core_step.duplicate(true)
		first_core_issue.issues = issues.duplicate()
	for issue in issues:
		var category := issue.get_slice(":",0)
		core_issue_counts[category] = int(core_issue_counts.get(category,0))+1
		if core_issues.size() < 64: core_issues.append(issue)

func _mark_motion_boundary() -> void:
	if _motion_seen: return
	_motion_seen = true
	var events = lane_events as Events
	_motion_cores = events.raw_cores()
	_early_retired = events.retired.duplicate(true)

func _update_normal_lane_behavior(vehicle: TrafficVehicle, delta: float) -> void:
	_mark_motion_boundary()
	super._update_normal_lane_behavior(vehicle,delta)

func _update_fast_overtaker(vehicle: TrafficVehicle, delta: float, player_speed: float) -> void:
	_mark_motion_boundary()
	super._update_fast_overtaker(vehicle,delta,player_speed)

func _update_traffic_speeds(delta: float) -> void:
	# This real hook is reached even in a step with no admitted NPC bodies.
	_mark_motion_boundary()
	super._update_traffic_speeds(delta)
