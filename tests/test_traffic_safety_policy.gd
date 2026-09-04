extends SceneTree

const TrafficSafetyPolicy = preload("res://scripts/traffic_safety_policy.gd")
const TrafficVehicle = preload("res://scripts/traffic_vehicle.gd")

func _init() -> void:
	var left := TrafficVehicle.new(0, 0, 200.0)
	var center := TrafficVehicle.new(0, 1, 230.0)
	var right := TrafficVehicle.new(0, 2, 170.0)
	assert(TrafficSafetyPolicy.has_full_lane_wall([left, center, right], 3), "Three nearby NPCs across all lanes must be identified as an unsolvable wall")
	right.y = 430.0
	assert(not TrafficSafetyPolicy.has_full_lane_wall([left, center, right], 3), "Longitudinally staggered traffic must remain a valid weave pattern")

	var overlap_a := TrafficVehicle.new(0, 1, 260.0)
	var overlap_b := TrafficVehicle.new(0, 1, 300.0)
	assert(TrafficSafetyPolicy.has_body_overlap([overlap_a, overlap_b], 260.0), "Intersecting NPC body rectangles must be detected")
	overlap_b.y = 500.0
	assert(not TrafficSafetyPolicy.has_body_overlap([overlap_a, overlap_b], 260.0), "Separated vehicles must not be reported as clipping")

	left.target_lane = 1
	left.lane_change_enabled = true
	left.warning_started = true
	right.y = 210.0
	assert(TrafficSafetyPolicy.has_full_lane_wall([left, right], 3), "A warned lane change must reserve both occupied lanes when checking for a future wall")
	var wall_left := TrafficVehicle.new(2, 0, 288.9)
	var wall_center := TrafficVehicle.new(1, 1, 256.3)
	var wall_right := TrafficVehicle.new(2, 2, 175.3)
	var safe_rear_y := TrafficSafetyPolicy.rear_y_outside_full_wall([wall_left, wall_center, wall_right], wall_left, 3, wall_left.y, [0])
	assert(safe_rear_y > wall_left.y and not TrafficSafetyPolicy.would_create_full_lane_wall([wall_center, wall_right], wall_left, 3, safe_rear_y, [0]), "A fast NPC must be moved behind the unsafe three-lane window while it waits")

	var changing_right := TrafficVehicle.new(1, 2, 260.0, 1, 0, 220.0)
	var slower_left := TrafficVehicle.new(0, 0, 123.0, -1, 0, 180.0)
	assert(not TrafficSafetyPolicy.would_create_full_lane_wall([slower_left], changing_right, 3, changing_right.y, [2, 1]), "The lane change begins outside the wall clearance")
	assert(TrafficSafetyPolicy.would_form_full_lane_wall_during([slower_left], changing_right, 3, [2, 1], 1.0, 1.0), "Relative NPC speeds must reject a lane change that would form a wall during its warning and movement")
	quit()
