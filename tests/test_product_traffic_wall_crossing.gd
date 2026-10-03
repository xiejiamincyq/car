extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
var failures: Array[String] = []

func _init() -> void:
	for reversed_order in [false,true]:
		var traffic := Traffic.new(2026)
		traffic.lane_events.enabled = false
		var rear = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE,2,1100.0,920.0)
		var first = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW,1,0.0,220.0)
		var second = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE,0,700.0,920.0)
		traffic.vehicles.assign([second,first,rear] if reversed_order else [rear,first,second])
		# Ahead pair: start separation700, end separation1264.33, but crosses
		# during rear's 2.44s braking horizon. Neither endpoint is the minimum.
		var horizon: float = 0.25 + rear.actual_world_speed / 420.0
		var crossing_seconds: float = 700.0 / ((920.0-220.0)*1.15)
		_check(crossing_seconds > 0.0 and crossing_seconds < horizon,"fixture has an interior pair crossing")
		var target: float = traffic._wall_following_target(rear)
		_check(not is_inf(target) and target < rear.actual_world_speed,"rear must start finite braking before an interior crossing forms a wall")
		first.actual_world_speed = 920.0
		second.actual_world_speed = 220.0
		_check(is_inf(traffic._wall_following_target(rear)),"diverging pair beyond clearance must not impose phantom wall braking")
		first.actual_world_speed = 220.0
		second.actual_world_speed = 920.0
		second.lane = 1
		second.lane_position = 1.0
		_check(is_inf(traffic._wall_following_target(rear)),"only two occupied lanes are not a full wall")
	for failure in failures: push_error("WALL_CROSSING_CHECK " + failure)
	print("WALL_CROSSING_CHECK failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_traffic_wall_crossing.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
