class_name GameFeedback
extends RefCounted

enum FuelTier { NORMAL, LOW, CRITICAL }

const LOW_FUEL_THRESHOLD := 30.0
const CRITICAL_FUEL_THRESHOLD := 15.0
const STAGE_TRANSITION_SECONDS := 2.0

var maximum_sparks: int
var sparks: Array[Dictionary] = []
var low_fuel_tier: FuelTier = FuelTier.NORMAL
var flashing_enabled := true
var previous_stage := 0
var current_stage := 0
var stage_transition_mix := 1.0
var stage_banner_text := ""
var _elapsed_seconds := 0.0
var _stage_transition_elapsed := STAGE_TRANSITION_SECONDS
var _stage_banner_remaining := 0.0
var _spark_serial := 0

func _init(spark_cap: int) -> void:
	maximum_sparks = maxi(1, spark_cap)

func tick(delta: float, fuel: float, stage: int) -> void:
	var safe_delta := maxf(0.0, delta)
	_elapsed_seconds += safe_delta
	_update_sparks(safe_delta)
	low_fuel_tier = FuelTier.CRITICAL if fuel < CRITICAL_FUEL_THRESHOLD else (FuelTier.LOW if fuel < LOW_FUEL_THRESHOLD else FuelTier.NORMAL)
	if stage != current_stage:
		previous_stage = current_stage
		current_stage = maxi(0, stage)
		_stage_transition_elapsed = 0.0
		stage_transition_mix = 0.0
		_stage_banner_remaining = STAGE_TRANSITION_SECONDS
		stage_banner_text = "赛段 %d" % (current_stage + 1)
	else:
		_stage_transition_elapsed = minf(STAGE_TRANSITION_SECONDS, _stage_transition_elapsed + safe_delta)
		stage_transition_mix = _stage_transition_elapsed / STAGE_TRANSITION_SECONDS
		_stage_banner_remaining = maxf(0.0, _stage_banner_remaining - safe_delta)
		if is_zero_approx(_stage_banner_remaining):
			stage_banner_text = ""

func spawn_collision(position: Vector2, speed: float, maximum_speed: float) -> void:
	var speed_ratio := clampf(speed / maxf(1.0, maximum_speed), 0.0, 1.0)
	var spark_count := 6 + roundi(speed_ratio * 8.0)
	for spark_index in range(spark_count):
		while sparks.size() >= maximum_sparks:
			sparks.pop_front()
		var angle := float(_spark_serial + spark_index) * 2.399963
		var velocity := Vector2.from_angle(angle) * lerpf(90.0, 250.0, speed_ratio)
		sparks.append({"position": position, "velocity": velocity, "life": 0.35 + 0.18 * float(spark_index % 3)})
	_spark_serial += spark_count

func shake_magnitude_for_speed(speed: float, maximum_speed: float) -> float:
	return lerpf(4.0, 14.0, clampf(speed / maxf(1.0, maximum_speed), 0.0, 1.0))

func low_fuel_text() -> String:
	match low_fuel_tier:
		FuelTier.LOW: return "燃油偏低"
		FuelTier.CRITICAL: return "燃油危险"
		_: return ""

func is_fuel_warning_visible() -> bool:
	if low_fuel_tier == FuelTier.NORMAL:
		return false
	if not flashing_enabled:
		return true
	var frequency := 4.0 if low_fuel_tier == FuelTier.CRITICAL else 2.0
	return int(floor(_elapsed_seconds * frequency)) % 2 == 0

func reset() -> void:
	sparks.clear()
	low_fuel_tier = FuelTier.NORMAL
	previous_stage = 0
	current_stage = 0
	stage_transition_mix = 1.0
	stage_banner_text = ""
	_elapsed_seconds = 0.0
	_stage_transition_elapsed = STAGE_TRANSITION_SECONDS
	_stage_banner_remaining = 0.0

func _update_sparks(delta: float) -> void:
	var active: Array[Dictionary] = []
	for spark in sparks:
		var updated := spark.duplicate()
		updated.life = maxf(0.0, float(updated.life) - delta)
		updated.position += updated.velocity * delta
		updated.velocity *= maxf(0.0, 1.0 - 3.5 * delta)
		if updated.life > 0.0:
			active.append(updated)
	sparks = active
