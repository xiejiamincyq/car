extends "res://scripts/lane_event_director.gd"

# Test-only raw world snapshots. The traffic observer must call begin_step
# and align birth/cancellation/retirement phases before invoking geometry.
var generation := 0
var births: Dictionary = {}
var retired: Dictionary = {}
var advanced: Dictionary = {}
var retirement_reasons: Dictionary = {}

func begin_step() -> void:
	births.clear()
	retired.clear()
	advanced.clear()
	retirement_reasons.clear()

func raw_cores() -> Dictionary:
	var result: Dictionary = {}
	if state == State.IDLE: return result
	var lane_width := GameConfig.ROAD_HALF_WIDTH*2.0/lane_count
	for closed_lane in _closed_lanes:
		var key := "%d/%d" % [generation,closed_lane]
		result[key] = {"id":closed_lane,"generation":generation,"x":(closed_lane+0.5)*lane_width-GameConfig.ROAD_HALF_WIDTH,
			"y":_core_y(),"half_x":lane_width*GameConfig.LANE_EVENT_CORE_HALF_LANE_RATIO,"half_y":34.0}
	return result

func begin_warning_lanes(target_lanes: Array[int]) -> void:
	var previous := raw_cores()
	super.begin_warning_lanes(target_lanes)
	generation += 1
	births.merge(raw_cores())
	_retire(previous,"replaced")

func _advance_road_distance(delta: float, player_speed: float) -> void:
	super._advance_road_distance(delta,player_speed)
	advanced = raw_cores()

func tick(delta: float, stage: int, player_lane: int, player_speed: float = 0.0) -> Dictionary:
	var previous := raw_cores()
	var event := super.tick(delta,stage,player_lane,player_speed)
	if event.ended: _retire(advanced if not advanced.is_empty() else previous,"ended")
	return event

func cancel_warning() -> void:
	var previous := raw_cores()
	super.cancel_warning()
	if state == State.IDLE: _retire(previous,"cancelled_warning")

func _retire(bodies: Dictionary, reason: String) -> void:
	retired.merge(bodies)
	for key in bodies: retirement_reasons[key] = reason
