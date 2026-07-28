class_name CollisionResponder
extends RefCounted

var speed_penalty: float
var invulnerability_duration: float
var invulnerability_remaining: float = 0.0

func _init(penalty: float, duration: float) -> void:
	speed_penalty = penalty
	invulnerability_duration = duration

func try_collide(current_speed: float) -> Dictionary:
	if invulnerability_remaining > 0.0:
		return { "hit": false, "speed": current_speed }
	invulnerability_remaining = invulnerability_duration
	return { "hit": true, "speed": maxf(0.0, current_speed - speed_penalty) }

func advance(delta: float) -> void:
	invulnerability_remaining = maxf(0.0, invulnerability_remaining - delta)
