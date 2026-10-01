extends RefCounted

const FuelPickup = preload("res://scripts/fuel_pickup.gd")
const FuelSpawnDirector = preload("res://scripts/fuel_spawn_director.gd")
const Config = preload("res://scripts/game_config.gd")
const REPAIR_AMOUNT := 20.0
const SPAWN_INTERVAL := 14.0
var pickups: Array[FuelPickup] = []
var spawner: FuelSpawnDirector

func _init(seed: int) -> void:
	spawner = FuelSpawnDirector.new(seed, Config.ROAD_LANE_COUNT, SPAWN_INTERVAL)

func reset(seed: int) -> void:
	pickups.clear()
	spawner.reset(seed)

func exclusion_zones() -> Array[Vector2]:
	var zones: Array[Vector2] = []
	for pickup in pickups: zones.append(Vector2(pickup.lane, pickup.y))
	return zones

func tick(delta: float, speed: float, blocked_lanes: Array, player_lane: int, player_center: Vector2, road_left: float, lane_width: float, viewport_height: float) -> int:
	var spawned := spawner.tick(delta, blocked_lanes, player_lane)
	if spawned != null: pickups.append(spawned)
	var collected := 0
	var active: Array[FuelPickup] = []
	for pickup in pickups:
		pickup.y += speed*Config.ROAD_SCROLL_MULTIPLIER*delta
		var x := road_left+lane_width*(pickup.lane+0.5)
		if absf(x-player_center.x) < 48.0 and absf(pickup.y-player_center.y) < 62.0:
			collected += 1
		elif pickup.y < viewport_height+60.0: active.append(pickup)
	pickups = active
	return collected
