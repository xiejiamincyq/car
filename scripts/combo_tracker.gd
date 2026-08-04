class_name ComboTracker
extends RefCounted

var window_seconds: float
var maximum_multiplier: int
var events_per_multiplier: int
var event_count: int = 0
var multiplier: int = 1
var remaining_seconds: float = 0.0

func _init(window: float, maximum: int, events_per_step: int) -> void:
	window_seconds = maxf(0.1, window)
	maximum_multiplier = maxi(1, maximum)
	events_per_multiplier = maxi(1, events_per_step)

func award(base_points: int) -> int:
	event_count += 1
	remaining_seconds = window_seconds
	multiplier = mini(maximum_multiplier, 1 + floori(float(event_count) / float(events_per_multiplier)))
	return maxi(0, base_points) * multiplier

func tick(delta: float) -> void:
	if event_count == 0:
		return
	remaining_seconds = maxf(0.0, remaining_seconds - maxf(0.0, delta))
	if is_zero_approx(remaining_seconds):
		clear()

func clear() -> void:
	event_count = 0
	multiplier = 1
	remaining_seconds = 0.0
