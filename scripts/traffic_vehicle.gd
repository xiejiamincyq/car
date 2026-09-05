class_name TrafficVehicle
extends RefCounted

const NORMAL_HALF_WIDTH := 25.0
const NORMAL_HALF_LENGTH := 42.0
const TRUCK_HALF_WIDTH := 31.0
const TRUCK_HALF_LENGTH := 74.0
const FAST_OVERTAKE_KIND := 2
const TRUCK_KIND := 3
const SIGNAL_CHANGE_KIND := 1
const NORMAL_CRUISE_SPEED := 200.0
const TRUCK_CRUISE_SPEED_MULTIPLIER := 0.80

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
var passed_player: bool = false
var was_ahead_of_player: bool = false
var collided_with_player: bool = false
var closest_lateral_distance: float = INF
var half_width: float = NORMAL_HALF_WIDTH
var half_length: float = NORMAL_HALF_LENGTH
var visual_variant: int = 0
var cruise_speed: float = NORMAL_CRUISE_SPEED
var lane_change_enabled: bool = false
var impact_speed_offset := 0.0
var previous_lane_position := 0.0
var lateral_velocity := 0.0
var previous_y := 0.0
var actual_world_speed := 0.0

func _init(vehicle_kind: int, initial_lane: int, initial_y: float, change_target: int = -1, variant: int = 0, assigned_cruise_speed: float = -1.0) -> void:
	configure(vehicle_kind, initial_lane, initial_y, change_target, variant, assigned_cruise_speed)

func configure(vehicle_kind: int, initial_lane: int, initial_y: float, change_target: int = -1, variant: int = 0, assigned_cruise_speed: float = -1.0) -> void:
	kind = vehicle_kind
	lane = initial_lane
	target_lane = change_target
	y = initial_y
	previous_y = y
	warning_remaining = 0.0
	change_started = false
	warning_started = false
	spawn_was_fair = false
	lane_position = float(lane)
	previous_lane_position = lane_position
	lateral_velocity = 0.0
	impact_speed_offset = 0.0
	overtake_warning_remaining = 0.0
	passed_player = false
	was_ahead_of_player = false
	collided_with_player = false
	closest_lateral_distance = INF
	half_width = TRUCK_HALF_WIDTH if kind == TRUCK_KIND else NORMAL_HALF_WIDTH
	half_length = TRUCK_HALF_LENGTH if kind == TRUCK_KIND else NORMAL_HALF_LENGTH
	visual_variant = maxi(0, variant)
	cruise_speed = assigned_cruise_speed if assigned_cruise_speed > 0.0 else _cruise_speed_for_kind(kind)
	actual_world_speed = cruise_speed
	lane_change_enabled = kind == SIGNAL_CHANGE_KIND

static func _cruise_speed_for_kind(vehicle_kind: int) -> float:
	match vehicle_kind:
		FAST_OVERTAKE_KIND: return 920.0
		TRUCK_KIND: return NORMAL_CRUISE_SPEED * TRUCK_CRUISE_SPEED_MULTIPLIER
		_: return NORMAL_CRUISE_SPEED
