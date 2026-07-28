class_name TrafficVehicle
extends RefCounted

var kind: int
var lane: int
var target_lane: int
var y: float
var warning_remaining: float = 0.0
var change_started: bool = false
var warning_started: bool = false
var spawn_was_fair: bool = false
var lane_position: float = 0.0
var overtake_warning_remaining: float = 0.0

func _init(vehicle_kind: int, initial_lane: int, initial_y: float, change_target: int = -1) -> void:
	configure(vehicle_kind, initial_lane, initial_y, change_target)

func configure(vehicle_kind: int, initial_lane: int, initial_y: float, change_target: int = -1) -> void:
	kind = vehicle_kind
	lane = initial_lane
	target_lane = change_target
	y = initial_y
	warning_remaining = 0.0
	change_started = false
	warning_started = false
	spawn_was_fair = false
	lane_position = float(lane)
	overtake_warning_remaining = 0.0
