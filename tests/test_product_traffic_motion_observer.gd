extends SceneTree
const Recorder = preload("res://tests/support/observed_motion_traffic.gd")
const Traffic = preload("res://scripts/traffic_director.gd")
var failures: Array[String] = []
var checks := 0

class SpeedFault extends Recorder:
	func _following_speed(vehicle: TrafficVehicle, delta: float) -> float:
		return vehicle.actual_world_speed+200.0*delta

class PositionFault extends Recorder:
	func _advance_normal_vehicle(vehicle: TrafficVehicle, delta: float, speed: float) -> void:
		super._advance_normal_vehicle(vehicle,delta,speed)
		vehicle.y += 1.0

class LateralFault extends Recorder:
	var forward := true
	func _update_normal_lane_behavior(vehicle: TrafficVehicle, delta: float) -> void:
		super._update_normal_lane_behavior(vehicle,delta)
		vehicle.lane_position += (2.4*delta+0.00005)*(1.0 if forward else -1.0)
		forward = not forward

func _init() -> void:
	var recorded := Recorder.new(611)
	var plain := Traffic.new(611)
	for traffic in [recorded,plain]:
		traffic.lane_events.enabled = false
		traffic._spawn_cooldown = 0.01
		traffic.tick(0.25,760.0,1)
	_check(recorded.motion_steps == 15,"fifteen actual substeps audited")
	_check(recorded.frame_checks == 1,"one cumulative frame check after all substeps")
	_check(recorded.motion_birth_count == plain.vehicles.size() and recorded.motion_birth_count > 0,"true birth captures finite premovement world speed")
	_check(recorded.motion_issues.is_empty(),"natural newly born NPC obeys motion contract")
	_check(recorded.spawn_sequence() == plain.spawn_sequence(),"observer preserves actual RNG")
	_check(_motion(recorded) == _motion(plain),"observer preserves actual speed and position")
	var retiring := Recorder.new(2026)
	_setup(retiring,710.0)
	retiring.tick(1.0/60.0,10000.0,1)
	_check(retiring.motion_retirement_count == 1 and retiring.vehicles.is_empty(),"motion captures actual offscreen retirement")
	_check(retiring.motion_issues.is_empty(),"final speed before pool reuse validates retirement motion")
	var speed_fault := SpeedFault.new(611)
	_setup(speed_fault,200.0)
	speed_fault.tick(0.25,300.0,1)
	_check(speed_fault.motion_issue_counts.get("world_acceleration",0) == 15,"every real excessive speed step is detected")
	_check(not speed_fault.first_motion_issue.is_empty(),"first speed fault keeps raw before/after/birth/retirement")
	var position_fault := PositionFault.new(611)
	_setup(position_fault,200.0)
	position_fault.tick(1.0/60.0,300.0,1)
	_check(position_fault.motion_issue_counts.get("longitudinal_displacement",0) == 1,"a hidden position correction fails despite legal speeds")
	var lateral_fault := LateralFault.new(611)
	_setup(lateral_fault,200.0)
	lateral_fault.tick(0.25,300.0,1)
	_check(lateral_fault.motion_issue_counts.get("frame_lateral_budget",0) == 1,"whole-frame oracle sums oscillating path not endpoint chord")
	_check(lateral_fault.last_frame_travel.size() == 1,"keeps actual cumulative raw path")
	if not lateral_fault.last_frame_travel.is_empty():
		_check(lateral_fault.last_frame_travel.values()[0] > 2.4*0.25+0.0001,"fifteen small excesses cannot reset tolerance")
	for step in 80: position_fault.tick(1.0/60.0,300.0,1)
	_check(position_fault.motion_issues.size() == 64,"motion detail buffer stays bounded")
	_check(position_fault.motion_issue_counts.get("longitudinal_displacement",0) == 81,"full failure count survives detail bound")
	for failure in failures: push_error("MOTION_OBSERVER_SELF_CHECK "+failure)
	print("MOTION_OBSERVER_SELF_CHECK checks=%d failures=%d" % [checks,failures.size()])
	print("TEST_COMPLETE test_product_traffic_motion_observer.gd")
	quit(0 if failures.is_empty() else 1)

func _setup(traffic, y: float) -> void:
	traffic.lane_events.enabled = false
	traffic._spawn_cooldown = 1000.0
	var vehicle = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW,1,y,200.0)
	traffic.vehicles.append(vehicle)

func _motion(traffic) -> Array:
	var result: Array = []
	for vehicle in traffic.vehicles:
		result.append([vehicle.kind,vehicle.lane_position,vehicle.y,vehicle.actual_world_speed,vehicle.cruise_speed])
	return result

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
