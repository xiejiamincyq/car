class_name DriveController
extends RefCounted

var start_speed: float
var max_speed: float
var acceleration: float
var braking: float
var steering_speed: float
var road_half_width: float
var player_half_width: float
var rolling_resistance: float
var speed: float
var lateral_position: float = 0.0

func _init(
		initial_speed: float,
		maximum_speed: float,
		acceleration_per_second: float,
		braking_per_second: float,
		steering_per_second: float,
		road_limit: float = 300.0,
		car_half_width: float = 0.0,
		coasting_resistance: float = 35.0
	) -> void:
	start_speed = initial_speed
	max_speed = maximum_speed
	acceleration = acceleration_per_second
	braking = braking_per_second
	steering_speed = steering_per_second
	road_half_width = road_limit
	player_half_width = car_half_width
	rolling_resistance = maxf(0.0, coasting_resistance)
	speed = start_speed

func step(delta: float, accelerate_input: float, brake_input: float, steering_input: float = 0.0) -> void:
	var resistance := rolling_resistance if accelerate_input <= 0.0 and brake_input <= 0.0 else 0.0
	var speed_change := (accelerate_input * acceleration - brake_input * braking - resistance) * delta
	speed = clampf(speed + speed_change, 0.0, max_speed)
	var center_limit := maxf(0.0, road_half_width - player_half_width)
	lateral_position = clampf(
		lateral_position + steering_input * steering_speed * delta,
		-center_limit,
		center_limit
	)

func reset() -> void:
	speed = start_speed
	lateral_position = 0.0
