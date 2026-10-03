extends RefCounted
# Caller supplies scalar start/final bodies aligned to the same lifetime
# interval. Birth/retirement phase alignment belongs to the step observer.
const Geometry = preload("res://tests/support/traffic_audit_geometry.gd")

static func audit_cross_step(npc_before: Dictionary, npc_after: Dictionary, core_before: Dictionary, core_after: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var npcs := _segments(npc_before,npc_after,"npc",issues)
	var cores := _segments(core_before,core_after,"core",issues)
	for npc_key in npcs:
		for core_key in cores:
			var n0: Dictionary = npc_before[npc_key]
			var n1: Dictionary = npc_after[npc_key]
			var c0: Dictionary = core_before[core_key]
			var c1: Dictionary = core_after[core_key]
			if Geometry.body_overlap(n0,c0): issues.append("core_initial_overlap:%s:%s" % [npc_key,core_key])
			if Geometry.body_overlap(n1,c1): issues.append("core_endpoint_overlap:%s:%s" % [npc_key,core_key])
			if Geometry.body_sweep(n0,n1,c0,c1): issues.append("core_sweep_overlap:%s:%s" % [npc_key,core_key])
	return issues

static func _segments(before: Dictionary, after: Dictionary, kind: String, issues: Array[String]) -> Array[String]:
	var valid: Array[String] = []
	for key in after:
		if not before.has(key): issues.append("%s_missing_start:%s" % [kind,key])
	for key in before:
		if not after.has(key):
			issues.append("%s_missing_final:%s" % [kind,key])
			continue
		if not Geometry._valid_body(before[key]) or not Geometry._valid_body(after[key]):
			issues.append("%s_invalid_snapshot:%s" % [kind,key])
			continue
		if not Geometry.same_identity(before[key],after[key]):
			issues.append("%s_identity_changed:%s" % [kind,key])
			continue
		if before[key].half_x != after[key].half_x or before[key].half_y != after[key].half_y:
			issues.append("%s_size_changed:%s" % [kind,key])
			continue
		valid.append(key)
	valid.sort()
	return valid
