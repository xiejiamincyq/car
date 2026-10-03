extends "res://tests/test_dynamic_pickup_smoke.gd"
## Diagnostic subset of unchanged natural fixtures, not the 30-case gate.
class AdmissionProbe extends "res://scripts/traffic_director.gd":
	var unsafe_admissions := 0
	func _can_spawn_candidate(candidate: TrafficVehicle, speed: float, lane: int) -> bool:
		var admitted := super._can_spawn_candidate(candidate, speed, lane)
		if admitted:
			for other in vehicles:
				if candidate.lane == other.lane and (candidate.kind == Kind.FAST_OVERTAKE or other.kind == Kind.FAST_OVERTAKE) and not vehicles_keep_safe_gap_until_recycle(candidate, other, speed):
					unsafe_admissions += 1
					if unsafe_admissions <= 6:
						print("PICKUP_REPRO_UNBRAKEABLE_BIRTH ", JSON.stringify({"candidate": _entry(candidate), "other": _entry(other), "player_speed": speed}))
		return admitted
	static func _entry(vehicle) -> Dictionary:
		return {"kind": vehicle.kind, "y": vehicle.y, "lane": vehicle.lane, "speed": vehicle.actual_world_speed, "cruise": vehicle.cruise_speed}

class DiagnosticMain extends MainPipelineProbe:
	func _ready() -> void:
		super._ready()
		traffic = AdmissionProbe.new(611)

# All existing Main/pickup/steering behavior remains unchanged. Only observe
# accepted traffic before it joins the array, including offscreen births.
func _pipeline_script() -> Script:
	return DiagnosticMain

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var metadata := _source_metadata()
	print("PICKUP_REPRO_CONFIG ", JSON.stringify(metadata))
	var configs := [[8, 1]] if OS.get_cmdline_user_args().has("--construction") else [[8, 0], [9, 0], [9, 1]]
	for config in configs:
		var stats: Dictionary = await _sample(config[0], config[1])
		print("PICKUP_REPRO_SAMPLE ", JSON.stringify(stats))
	_check(_source_metadata() == metadata, "Source remains unchanged throughout diagnostic subset")
	for failure in failures: push_error(failure)
	print("PICKUP_REPRO_COMPLETE")
	quit(0 if failures.is_empty() else 1)
