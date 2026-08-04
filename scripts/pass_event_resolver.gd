class_name PassEventResolver
extends RefCounted

const GameConfig = preload("res://scripts/game_config.gd")

const COLLISION_LATERAL_DISTANCE := GameConfig.COLLISION_LATERAL_DISTANCE
const NEAR_MISS_LATERAL_DISTANCE := GameConfig.NEAR_MISS_LATERAL_DISTANCE
const PASS_SETTLEMENT_DISTANCE := GameConfig.PASS_SETTLEMENT_DISTANCE

static func observe(vehicle: RefCounted, kind: int, player_y: float, player_x: float, vehicle_x: float) -> Dictionary:
	var event := {"overtake": false, "near_miss": false}
	if kind == 2 or vehicle.passed_player:
		return event
	if vehicle.y < player_y - PASS_SETTLEMENT_DISTANCE:
		vehicle.was_ahead_of_player = true
	if absf(vehicle.y - player_y) <= PASS_SETTLEMENT_DISTANCE:
		vehicle.closest_lateral_distance = minf(vehicle.closest_lateral_distance, absf(vehicle_x - player_x))
	if not vehicle.was_ahead_of_player or vehicle.y <= player_y + PASS_SETTLEMENT_DISTANCE:
		return event
	vehicle.passed_player = true
	if vehicle.collided_with_player:
		return event
	event.overtake = true
	event.near_miss = vehicle.closest_lateral_distance > COLLISION_LATERAL_DISTANCE and vehicle.closest_lateral_distance <= NEAR_MISS_LATERAL_DISTANCE
	return event
