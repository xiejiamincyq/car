class_name VehicleCatalog
extends RefCounted

const BASE_MAX_SPEED := 760.0
const BASE_ACCELERATION := 220.0
const BASE_BRAKING := 420.0
const BASE_STEERING_SPEED := 540.0
const BASE_COLLISION_SPEED_PENALTY := 260.0
const MIN_PERFORMANCE_BUDGET := 4.75
const MAX_PERFORMANCE_BUDGET := 5.15

const VEHICLES := [
	{
		"id": &"pulse_gt",
		"name_key": &"vehicle_pulse_gt",
		"role_key": &"vehicle_role_balanced",
		"texture_path": "res://assets/vehicles/player_pulse_gt.png",
		"max_speed": 760.0,
		"acceleration": 220.0,
		"braking": 420.0,
		"steering_speed": 540.0,
		"collision_speed_penalty": 260.0,
	},
	{
		"id": &"driftwing",
		"name_key": &"vehicle_driftwing",
		"role_key": &"vehicle_role_agile",
		"texture_path": "res://assets/vehicles/player_driftwing.png",
		"max_speed": 700.0,
		"acceleration": 216.0,
		"braking": 483.0,
		"steering_speed": 637.0,
		"collision_speed_penalty": 300.0,
	},
	{
		"id": &"flashpoint",
		"name_key": &"vehicle_flashpoint",
		"role_key": &"vehicle_role_sprint",
		"texture_path": "res://assets/vehicles/player_flashpoint.png",
		"max_speed": 775.0,
		"acceleration": 264.0,
		"braking": 386.0,
		"steering_speed": 502.0,
		"collision_speed_penalty": 300.0,
	},
	{
		"id": &"comet_rs",
		"name_key": &"vehicle_comet_rs",
		"role_key": &"vehicle_role_speed",
		"texture_path": "res://assets/vehicles/player_comet_rs.png",
		"max_speed": 859.0,
		"acceleration": 224.0,
		"braking": 378.0,
		"steering_speed": 459.0,
		"collision_speed_penalty": 270.0,
	},
	{
		"id": &"tidebreaker",
		"name_key": &"vehicle_tidebreaker",
		"role_key": &"vehicle_role_stable",
		"texture_path": "res://assets/vehicles/player_tidebreaker.png",
		"max_speed": 714.0,
		"acceleration": 198.0,
		"braking": 470.0,
		"steering_speed": 540.0,
		"collision_speed_penalty": 226.0,
	},
	{
		"id": &"aurora_x",
		"name_key": &"vehicle_aurora_x",
		"role_key": &"vehicle_role_expert",
		"texture_path": "res://assets/vehicles/player_aurora_x.png",
		"max_speed": 836.0,
		"acceleration": 253.0,
		"braking": 344.0,
		"steering_speed": 459.0,
		"collision_speed_penalty": 260.0,
	},
]

static func all() -> Array:
	return VEHICLES.duplicate(true)

static func get_by_id(vehicle_id: StringName) -> Dictionary:
	for vehicle in VEHICLES:
		if vehicle.id == vehicle_id:
			return vehicle.duplicate(true)
	return {}

static func performance_budget(vehicle: Dictionary) -> float:
	return (
		float(vehicle.get("max_speed", 0.0)) / BASE_MAX_SPEED
		+ float(vehicle.get("acceleration", 0.0)) / BASE_ACCELERATION
		+ float(vehicle.get("braking", 0.0)) / BASE_BRAKING
		+ float(vehicle.get("steering_speed", 0.0)) / BASE_STEERING_SPEED
		+ BASE_COLLISION_SPEED_PENALTY / float(vehicle.get("collision_speed_penalty", INF))
	)

static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for vehicle in VEHICLES:
		var vehicle_id: StringName = vehicle.get("id", &"")
		if String(vehicle_id).is_empty() or ids.has(vehicle_id):
			errors.append("Vehicle IDs must be present and unique")
		ids[vehicle_id] = true
		for key in [&"max_speed", &"acceleration", &"braking", &"steering_speed", &"collision_speed_penalty"]:
			if float(vehicle.get(key, 0.0)) <= 0.0:
				errors.append("Vehicle %s has an invalid %s" % [vehicle_id, key])
		var texture_path := String(vehicle.get("texture_path", ""))
		if not texture_path.begins_with("res://assets/vehicles/player_") or not ResourceLoader.exists(texture_path):
			errors.append("Vehicle %s needs a valid player sprite" % vehicle_id)
		var budget := performance_budget(vehicle)
		if budget < MIN_PERFORMANCE_BUDGET or budget > MAX_PERFORMANCE_BUDGET:
			errors.append("Vehicle %s is outside the shared performance budget" % vehicle_id)
	for first_index in VEHICLES.size():
		for second_index in VEHICLES.size():
			if first_index != second_index and _dominates(VEHICLES[first_index], VEHICLES[second_index]):
				errors.append("Vehicle %s must not dominate %s" % [VEHICLES[first_index].id, VEHICLES[second_index].id])
	return errors

static func _dominates(first: Dictionary, second: Dictionary) -> bool:
	var no_worse := (
		float(first.max_speed) >= float(second.max_speed)
		and float(first.acceleration) >= float(second.acceleration)
		and float(first.braking) >= float(second.braking)
		and float(first.steering_speed) >= float(second.steering_speed)
		and float(first.collision_speed_penalty) <= float(second.collision_speed_penalty)
	)
	var strictly_better := (
		float(first.max_speed) > float(second.max_speed)
		or float(first.acceleration) > float(second.acceleration)
		or float(first.braking) > float(second.braking)
		or float(first.steering_speed) > float(second.steering_speed)
		or float(first.collision_speed_penalty) < float(second.collision_speed_penalty)
	)
	return no_worse and strictly_better
