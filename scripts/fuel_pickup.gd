class_name FuelPickup
extends RefCounted

var lane: int
var y: float

func _init(initial_lane: int, initial_y: float) -> void:
	lane = initial_lane
	y = initial_y
