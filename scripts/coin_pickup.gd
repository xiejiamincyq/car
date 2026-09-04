class_name CoinPickup
extends RefCounted

const GameConfig = preload("res://scripts/game_config.gd")

const WORLD_SPEED := 0.0

var id: int
var lane_position: float
var y: float
var route_id: int
var template: int
var world_speed := WORLD_SPEED
var collected := false

func _init(initial_id: int, initial_lane_position: float, initial_y: float, initial_route_id: int = 0, initial_template: int = 0) -> void:
	id = initial_id
	lane_position = initial_lane_position
	y = initial_y
	route_id = initial_route_id
	template = initial_template

func advance(delta: float, player_speed: float) -> void:
	var relative_speed := maxf(0.0, player_speed) - world_speed
	y += relative_speed * GameConfig.ROAD_SCROLL_MULTIPLIER * maxf(0.0, delta)

func collect() -> bool:
	if collected:
		return false
	collected = true
	return true
