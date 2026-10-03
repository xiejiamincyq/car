extends RefCounted

# Test-only scalar geometry: no gameplay policy or Vector2 conversion.
static func swept_overlap(x0: float, y0: float, x1: float, y1: float, half_x: float, half_y: float) -> bool:
	var x_interval := _axis_interval(x0,x1,half_x)
	var y_interval := _axis_interval(y0,y1,half_y)
	return maxf(x_interval[0],y_interval[0]) < minf(x_interval[1],y_interval[1])

static func _axis_interval(start: float, finish: float, half_size: float) -> Array:
	var displacement := finish-start
	if displacement == 0.0:
		return [0.0,1.0] if absf(start) < half_size else [1.0,0.0]
	var first := (-half_size-start)/displacement
	var second := (half_size-start)/displacement
	return [maxf(0.0,minf(first,second)),minf(1.0,maxf(first,second))]

static func same_identity(before: Dictionary, after: Dictionary) -> bool:
	return before.id == after.id and before.generation == after.generation

static func body_overlap(first: Dictionary, second: Dictionary) -> bool:
	return absf(first.x-second.x) < first.half_x+second.half_x and absf(first.y-second.y) < first.half_y+second.half_y

static func body_sweep(first_before: Dictionary, first_after: Dictionary, second_before: Dictionary, second_after: Dictionary) -> bool:
	if not same_identity(first_before,first_after) or not same_identity(second_before,second_after): return false
	return swept_overlap(first_before.x-second_before.x,first_before.y-second_before.y,
		first_after.x-second_after.x,first_after.y-second_after.y,first_after.half_x+second_after.half_x,first_after.half_y+second_after.half_y)

static func visible(body: Dictionary, height: float) -> bool:
	return body.y+body.half_y >= 0.0 and body.y-body.half_y <= height

static func retirement(before: Dictionary, final: Dictionary, height: float) -> String:
	if final.is_empty(): return "missing_final_snapshot"
	if not same_identity(before,final): return "identity_mismatch"
	return "visible_removed" if visible(final,height) else "offscreen_recycled"

static func audit_step(before: Dictionary, after: Dictionary, births: Dictionary, retired: Dictionary, height: float) -> Array[String]:
	var issues: Array[String] = []
	var starts := before.duplicate()
	starts.merge(births)
	var finals := after.duplicate()
	finals.merge(retired)
	for key in births:
		if before.has(key): issues.append("duplicate_birth:"+key)
	for key in retired:
		if after.has(key): issues.append("contradictory_lifecycle:"+key)
	for key in finals:
		if not starts.has(key): issues.append("missing_birth_snapshot:"+key)
	var identities := starts.keys()
	identities.sort()
	var live_ids: Dictionary = {}
	for key in identities:
		if not _valid_body(starts[key]) or (finals.has(key) and not _valid_body(finals[key])):
			issues.append("invalid_snapshot:"+key)
			continue
		var instance_id: int = starts[key].id
		if live_ids.has(instance_id):
			issues.append("overlapping_generations:%d" % instance_id)
		live_ids[instance_id] = true
		if not finals.has(key):
			issues.append("missing_final_snapshot:"+key)
		elif not same_identity(starts[key],finals[key]):
			issues.append("identity_mismatch:"+key)
		elif starts[key].half_x != finals[key].half_x or starts[key].half_y != finals[key].half_y:
			issues.append("body_size_changed:"+key)
		if retired.has(key):
			var outcome := retirement(starts[key],finals[key],height)
			if outcome != "offscreen_recycled": issues.append(outcome+":"+key)
	for first_index in identities.size():
		var first_key: String = identities[first_index]
		for second_index in range(first_index+1,identities.size()):
			var second_key: String = identities[second_index]
			if not _valid_body(starts[first_key]) or not _valid_body(starts[second_key]): continue
			if body_overlap(starts[first_key],starts[second_key]):
				var label := "birth_overlap" if births.has(first_key) or births.has(second_key) else "initial_overlap"
				issues.append("%s:%s:%s" % [label,first_key,second_key])
			if not finals.has(first_key) or not finals.has(second_key): continue
			if not _valid_body(finals[first_key]) or not _valid_body(finals[second_key]): continue
			if body_overlap(finals[first_key],finals[second_key]):
				issues.append("endpoint_overlap:%s:%s" % [first_key,second_key])
			if body_sweep(starts[first_key],finals[first_key],starts[second_key],finals[second_key]):
				issues.append("sweep_overlap:%s:%s" % [first_key,second_key])
	return issues

static func _valid_body(body: Dictionary) -> bool:
	if not body.has("id") or not body.has("generation"): return false
	if typeof(body.id) != TYPE_INT or typeof(body.generation) != TYPE_INT or body.generation < 1: return false
	for key in ["x","y","half_x","half_y"]:
		if not body.has(key) or typeof(body[key]) not in [TYPE_FLOAT,TYPE_INT]: return false
		if is_nan(float(body[key])) or is_inf(float(body[key])): return false
	return body.half_x > 0.0 and body.half_y > 0.0
