extends RefCounted
const Geometry = preload("res://tests/support/traffic_audit_geometry.gd")

# Test-only constructive oracle; never a proof that no continuous path exists.
static func find_path(trace: Dictionary, controls: Array = [0.0,-1.0,1.0]) -> Dictionary:
	if not _valid_trace(trace): return {"status":"invalid","xs":[],"controls":[]}
	if controls.is_empty() or controls.size() > 9: return {"status":"invalid","xs":[],"controls":[]}
	for input in controls:
		if not _number(input) or absf(input) > 1.0: return {"status":"invalid","xs":[],"controls":[]}
	var frontier: Array = [{"xs":[trace.x0],"controls":[]}]
	var peak := 1
	for frame in trace.frames:
		var next_frontier: Array = []
		var bins: Dictionary = {}
		for node in frontier:
			var x: float = node.xs.back()
			for input in controls:
				var next := _next_x(trace,frame,x,input)
				if not _clear(trace,frame,x,next): continue
				# Deduplicate search candidates, NEVER round the physical position.
				# Pruning can miss a route, so exhaustion only means unverified.
				var bin_id := int(floor(next/2.0))
				if bins.has(bin_id): continue
				bins[bin_id] = true
				var xs: Array = node.xs.duplicate()
				var inputs: Array = node.controls.duplicate()
				xs.append(next)
				inputs.append(input)
				next_frontier.append({"xs":xs,"controls":inputs})
				if next_frontier.size() > 512:
					return {"status":"unverified","reason":"state_cap","xs":[],"controls":[]}
		if next_frontier.is_empty(): return {"status":"unverified","reason":"sample_exhausted","xs":[],"controls":[]}
		peak = maxi(peak,next_frontier.size())
		frontier = next_frontier
	var witness: Dictionary = frontier[0]
	if not validate_path(trace,witness): return {"status":"invalid","reason":"witness_replay_failed","xs":[],"controls":[]}
	witness.status = "witness"
	witness.scope = "fixed_piecewise_linear_trace_only"
	witness.peak_states = peak
	return witness

static func validate_path(trace: Dictionary, path: Dictionary) -> bool:
	if not _valid_trace(trace): return false
	if not path.has("xs") or not path.has("controls") or path.xs is not Array or path.controls is not Array: return false
	if path.controls.size() != trace.frames.size() or path.xs.size() != trace.frames.size()+1: return false
	if not _number(path.xs[0]) or absf(path.xs[0]-trace.x0) > 0.0000001: return false
	var x: float = trace.x0
	for index in trace.frames.size():
		var input = path.controls[index]
		if not _number(input) or absf(input) > 1.0 or not _number(path.xs[index+1]): return false
		var next := _next_x(trace,trace.frames[index],x,input)
		if absf(path.xs[index+1]-next) > 0.0000001 or not _clear(trace,trace.frames[index],x,next): return false
		x = next
	return true

static func _valid_trace(trace: Dictionary) -> bool:
	for key in ["x0","y","road_half","half_x","half_y","steering_speed","max_speed","hull"]:
		if not trace.has(key) or not _number(trace[key]): return false
	if trace.half_x <= 0.0 or trace.half_y <= 0.0 or trace.road_half <= trace.half_x: return false
	if trace.steering_speed <= 0.0 or trace.max_speed <= 0.0 or trace.hull < 20.0 or trace.hull > 100.0: return false
	if absf(trace.x0) > trace.road_half-trace.half_x: return false
	if not trace.has("frames") or trace.frames is not Array or trace.frames.is_empty() or trace.frames.size() > 120: return false
	for frame in trace.frames:
		if frame is not Dictionary: return false
		if frame.has("status") and frame.status != "valid": return false
		if not frame.has("dt") or not _number(frame.dt) or frame.dt <= 0.0 or frame.dt > 1.0/60.0+0.000000000001: return false
		if not frame.has("speed") or not _number(frame.speed) or frame.speed < 0.0: return false
		if not frame.has("bodies") or frame.bodies is not Array or frame.bodies.size() > 64: return false
		for body in frame.bodies:
			if body is not Dictionary: return false
			for key in ["x0","y0","x1","y1","half_x","half_y"]:
				if not body.has(key) or not _number(body[key]): return false
			if body.half_x <= 0.0 or body.half_y <= 0.0: return false
	return true

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

static func _next_x(trace: Dictionary, frame: Dictionary, x: float, input: float) -> float:
	var ratio := clampf((float(frame.speed)/maxf(1.0,trace.max_speed)-0.25)/0.75,0.0,1.0)
	var speed_factor := lerpf(1.0,0.85,ratio*ratio*(3.0-2.0*ratio))
	var hull: float = trace.hull
	var hull_factor := lerpf(0.60,0.68,(hull-20.0)/10.0)
	if hull > 70.0: hull_factor = lerpf(0.88,1.0,(hull-70.0)/30.0)
	elif hull > 30.0: hull_factor = lerpf(0.68,0.88,(hull-30.0)/40.0)
	var limit: float = trace.road_half-trace.half_x
	return clampf(x+input*trace.steering_speed*speed_factor*hull_factor*frame.dt,-limit,limit)

static func _clear(trace: Dictionary, frame: Dictionary, x: float, next: float) -> bool:
	for body in frame.bodies:
		var hx: float = trace.half_x+body.half_x
		var hy: float = trace.half_y+body.half_y
		if absf(x-body.x0) < hx and absf(trace.y-body.y0) < hy: return false
		if absf(next-body.x1) < hx and absf(trace.y-body.y1) < hy: return false
		if Geometry.swept_overlap(x-body.x0,trace.y-body.y0,next-body.x1,trace.y-body.y1,hx,hy): return false
	return true
