extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
const STEP := 1.0 / 60.0

func _init() -> void:
	var traffic := Traffic.new(9001)
	traffic.set_viewport_height(720.0)
	traffic.set_difficulty_stage(1)
	traffic._spawn_cooldown = 1000.0
	var vehicle = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 200.0, 200.0)
	traffic.vehicles.append(vehicle)
	traffic.lane_events.begin_warning(0)
	var core_visible := false
	var lane_width := Config.ROAD_HALF_WIDTH * 2.0 / 3.0
	for step in range(300):
		traffic.tick(STEP, 180.0, 2)
		for marker in traffic.lane_events.core_markers(720.0):
			core_visible = core_visible or (marker.y >= 0.0 and marker.y <= 720.0)
			var dx: float = absf((vehicle.lane_position + 0.5 - marker.x) * lane_width)
			# Use the existing player/core 62px longitudinal contact threshold as
			# a conservative oracle; this does not enlarge the core for the NPC.
			if dx < lane_width * Config.LANE_EVENT_CORE_HALF_LANE_RATIO + vehicle.half_width and absf(vehicle.y - marker.y) < 62.0:
				print("CONSTRUCTION_EVIDENCE ", JSON.stringify({"seed":9001, "seconds":(step + 1) * STEP, "core_visible":core_visible, "npc_y":vehicle.y, "core_y":marker.y, "npc_lane_position":vehicle.lane_position, "core_lane_position":marker.x - 0.5, "npc_retained":traffic.vehicles.has(vehicle)}))
				print("FAIL: an existing NPC must brake or merge instead of entering the solid construction core")
				_finish(false)
				return
	if not core_visible:
		print("FAIL: construction fixture did not expose a visible solid core")
	_finish(core_visible)

func _finish(passed: bool) -> void:
	print("TEST_COMPLETE test_product_traffic_construction.gd")
	quit(0 if passed else 1)
