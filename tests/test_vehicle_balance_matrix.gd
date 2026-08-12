extends SceneTree

const DriveController = preload("res://scripts/drive_controller.gd")
const CollisionResponder = preload("res://scripts/collision_responder.gd")
const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")

func _init() -> void:
	var leaders := {
		"max_speed": &"",
		"acceleration": &"",
		"braking": &"",
		"steering_speed": &"",
		"collision_speed_penalty": &"",
	}
	var leader_values := {
		"max_speed": -INF,
		"acceleration": -INF,
		"braking": -INF,
		"steering_speed": -INF,
		"collision_speed_penalty": INF,
	}
	for vehicle in VehicleCatalog.all():
		var drive := DriveController.new(280.0, vehicle.max_speed, vehicle.acceleration, vehicle.braking, vehicle.steering_speed, 300.0, 30.0)
		drive.step(2.0, 1.0, 0.0)
		assert(drive.speed > 650.0 and drive.speed <= vehicle.max_speed, "%s must reach a useful two-second launch speed" % vehicle.id)
		var launch_speed := drive.speed
		drive.step(0.5, 0.0, 1.0)
		assert(drive.speed < launch_speed and drive.speed >= 0.0, "%s must brake predictably" % vehicle.id)
		drive.reset()
		drive.step(0.5, 0.0, 0.0, 1.0)
		assert(drive.lateral_position >= 225.0 and drive.lateral_position <= 270.0, "%s must retain playable half-second steering" % vehicle.id)
		var collision := CollisionResponder.new(vehicle.collision_speed_penalty, 1.0)
		var impact = collision.try_collide(vehicle.max_speed)
		assert(impact.speed >= 400.0 and impact.speed < vehicle.max_speed, "%s must survive a top-speed impact without ignoring it" % vehicle.id)
		for stat in ["max_speed", "acceleration", "braking", "steering_speed"]:
			if float(vehicle[stat]) > float(leader_values[stat]):
				leader_values[stat] = vehicle[stat]
				leaders[stat] = vehicle.id
		if float(vehicle.collision_speed_penalty) < float(leader_values.collision_speed_penalty):
			leader_values.collision_speed_penalty = vehicle.collision_speed_penalty
			leaders.collision_speed_penalty = vehicle.id
	var distinct_leaders := {}
	for stat in leaders:
		distinct_leaders[leaders[stat]] = true
	assert(distinct_leaders.size() >= 4, "The five core attributes must create at least four distinct vehicle niches")
	assert(VehicleCatalog.validate().is_empty(), "No vehicle may dominate another or leave the shared performance budget")
	quit()
