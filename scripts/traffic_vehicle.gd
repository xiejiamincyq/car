class_name TrafficVehicle
extends RefCounted

var kind: int
var lane: int
var target_lane: int
var y: float
var warning_remaining: float = 0.0
var change_started: bool = false

func _init(vehicle_kind: int, initial_lane: int, initial_y: float, change_target: int = -1) -> void:
	kind = vehicle_kind
	lane = initial_lane
	target_lane = change_target
	y = initial_y
