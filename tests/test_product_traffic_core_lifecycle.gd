extends SceneTree
const Recorder = preload("res://tests/support/observed_lane_events.gd")
const Plain = preload("res://scripts/lane_event_director.gd")
var failures: Array[String] = []

func _init() -> void:
	var recorded := Recorder.new(611)
	var plain := Plain.new(611)
	var closed: Array[int] = [0,1]
	for event in [recorded,plain]: event.begin_warning_lanes(closed)
	_check(recorded.raw_cores().size() == 2,"records both cores at raw world birth even outside render window")
	_check(recorded.births.size() == 2,"birth boundary is retained before any movement")
	_check(recorded.generation == 1,"first event has stable independent generation")
	recorded.begin_step()
	for event in [recorded,plain]: event.tick(0.5,3,2,300.0)
	_check(recorded.event_history() == plain.event_history(),"observer does not change event sequence")
	_check(recorded._travel_distance == plain._travel_distance and recorded.state == plain.state,"observer does not change actual travel or state")
	_check(recorded.advanced.size() == 2,"records movement boundary in raw scalars")
	if not recorded.advanced.is_empty():
		_check(recorded.advanced.values()[0].y == recorded._core_y(),"world coordinate is not rounded through Vector2")
	recorded.begin_step()
	recorded.cancel_warning()
	_check(recorded.retired.size() == 2,"warning cancellation records actual final cores")
	_check(recorded.retirement_reasons.values().has("cancelled_warning"),"legal cancellation is distinguished from unexplained deletion")
	recorded.begin_step()
	recorded.begin_warning_lanes(closed)
	_check(recorded.generation == 2,"cancelled event does not reuse a generation despite production counter decrement")
	recorded.begin_step()
	recorded.state = Plain.State.CLOSED
	# Account for double-lane warning lead-in; start just before the real tail
	# retirement boundary rather than guessing an absolute travel distance.
	recorded._travel_distance += 840.0-recorded._event_tail_y()-0.1
	recorded.tick(1.0/60.0,3,2,20.0)
	_check(recorded.state == Plain.State.IDLE and recorded.retired.size() == 2,"natural event end retains final positions before closed lanes are cleared")
	if not recorded.retired.is_empty():
		_check(recorded.retired.values()[0].y > 1000.0,"retirement is recorded after the actual road advance")
	for failure in failures: push_error("CORE_LIFECYCLE_SELF_CHECK "+failure)
	print("CORE_LIFECYCLE_SELF_CHECK failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_traffic_core_lifecycle.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
