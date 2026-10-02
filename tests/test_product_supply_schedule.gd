extends SceneTree

const Fuel = preload("res://scripts/fuel_spawn_director.gd")
const Difficulty = preload("res://scripts/difficulty_profile.gd")
const Config = preload("res://scripts/game_config.gd")
const Repair = preload("res://scripts/repair_supply_director.gd")
var failures := 0

func _init() -> void:
	for index in range(3):
		var profile := Difficulty.for_index(index)
		_check(profile.get("fuel_spawn_interval", -1) == [6.0,7.0,8.0][index], "difficulty has absolute fuel interval %d" % index)
		_check(profile.get("repair_spawn_interval", -1) == [10.0,12.0,14.0][index], "difficulty has absolute repair interval %d" % index)
		_check(profile.get("supply_active_limit", -1) == 2, "each supply type has cap two")
		_check(profile.get("supply_minimum_road_advance", -1) == 136.0, "supply spacing uses road pixels, not display distance")
	_check(Config.FUEL_PICKUP_AMOUNT == 24.0 and Repair.REPAIR_AMOUNT == 20.0, "existing resource rewards stay unchanged")
	var stopped := Fuel.new(77, 3, 1.0)
	_check(stopped.has_method("configure_schedule") and _tick_argument_count(stopped) == 5, "explicit schedule API and mandatory active count / road advance exist")
	_configure(stopped, 1.0)
	_check(_tick(stopped, 5.0, [], 0, 0.0) == null and stopped.spawn_remaining == 1.0, "stopped car freezes time without accumulating supply debt")
	_check(_tick(stopped, 5.0, [], 0, -1.0) == null and stopped.spawn_remaining == 1.0, "backward/nonpositive advance cannot age scheduler")
	_check(_tick(stopped, 0.0, [], 0, 1000.0) == null and stopped.spawn_remaining == 1.0, "zero delta cannot age distance or spawn")
	var full := Fuel.new(77, 3, 1.0)
	_configure(full, 1.0)
	_check(_tick(full, 1.0, [], 2, 1000.0) == null, "full same-type supply defers rather than exceeding cap")
	var progress := Fuel.new(77, 3, 1.0)
	_configure(progress, 1.0)
	_check(_tick(progress, 1.0, [], 0, 1.0) != null, "first spawn needs time but no prior road spacing")
	_check(_tick(progress, 1.0, [], 0, 135.0) == null, "subsequent spawn needs full 136px since last success")
	if stopped.has_method("configure_schedule"):
		_test_schedule_state()
		_test_schedule_grid()
		_test_birth_spacing()
	print("PRODUCT_SUPPLY_SCHEDULE failures=%d" % failures)
	print("TEST_COMPLETE test_product_supply_schedule.gd")
	quit(0 if failures == 0 else 1)

# This adapter exists only to run the old implementation's semantic RED without
# parse errors. Production callers are migrated to the mandatory five arguments.
func _tick(spawner, delta: float, blocked: Array, active: int, advance: float):
	return spawner.callv("tick", [delta,blocked,1,active,advance] if _tick_argument_count(spawner) == 5 else [delta,blocked,1])

func _tick_argument_count(spawner) -> int:
	for method in spawner.get_method_list():
		if method.name == "tick": return method.args.size()
	return -1

func _configure(spawner, interval: float) -> void:
	if spawner.has_method("configure_schedule"): spawner.configure_schedule(interval, 2, 136.0)

func _test_schedule_state() -> void:
	var spawner := Fuel.new(77,3,1.0)
	_configure(spawner,1.0)
	_tick(spawner,0.4,[],0,40.0)
	_configure(spawner,1.0)
	_check(is_equal_approx(spawner.spawn_remaining,0.6), "identical configuration preserves timer")
	_check(_tick(spawner,0.6,[],0,60.0) != null, "idempotent configure preserves initial deadline")
	_check(spawner.opportunities == 1 and spawner.spawned == 1 and not spawner.pending, "first success counts exactly one opportunity and spawn")
	_check(spawner.spawn_remaining == 1.0 and spawner.road_advance_since_spawn == 0.0, "success restores full interval and spacing baseline")
	_check(_tick(spawner,1.0,[],0,100.0) == null and spawner.pending, "progress gate retains at most one pending opportunity")
	_check(spawner.opportunities == 2 and spawner.blocked_attempts == 1, "one gated attempt counts once")
	for frame in range(20): _tick(spawner,0.01,[],0,1.0)
	_check(spawner.opportunities == 2 and spawner.blocked_attempts == 1, "pending retry does not count every frame")
	_check(_tick(spawner,10.0,[],0,0.0) == null and spawner.blocked_attempts == 1, "stopping freezes pending retry")
	_check(_tick(spawner,0.3,[],0,16.0) != null, "exactly 136px total progress permits pending success at retry deadline")
	_check(spawner.opportunities == 2 and spawner.spawned == 2, "successful retry consumes existing opportunity, not another one")
	_check(_tick(spawner,20.0,[],0,1000.0) != null and spawner.spawned == 3 and spawner.spawn_remaining == 1.0, "large delta produces only one pickup and discards time debt")
	_check(_tick(spawner,0.01,[],0,1000.0) == null, "next success waits a full interval after large delta")
	var blocked := Fuel.new(77,3,1.0)
	var reference := Fuel.new(77,3,1.0)
	_configure(blocked,1.0)
	_configure(reference,1.0)
	_tick(blocked,1.0,[0,1,2],0,200.0)
	_tick(blocked,2.0,[0,1,2],0,200.0)
	_check(blocked.pending and blocked.opportunities == 1 and blocked.blocked_attempts == 2, "blocked retries preserve exactly one opportunity")
	var after_block = _tick(blocked,0.5,[],0,200.0)
	var direct = _tick(reference,1.0,[],0,200.0)
	_check(after_block.lane == direct.lane, "failed lane attempts do not consume RNG")
	var full := Fuel.new(77,3,1.0)
	_configure(full,1.0)
	_tick(full,1.0,[],2,200.0)
	_tick(full,3.0,[],2,200.0)
	_check(full.pending and full.opportunities == 1 and full.spawned == 0, "long capacity block has no catch-up queue")
	_check(_tick(full,0.5,[],1,200.0).lane == direct.lane, "capacity failures also preserve RNG")
	spawner.configure_schedule(2.0,2,136.0)
	_check(spawner.spawn_remaining == 2.0 and not spawner.pending and spawner.road_advance_since_spawn == 0.0 and spawner.has_spawned, "real configuration switch resets future schedule/progress without granting first-spawn exemption again")
	_check(spawner.spawned == 3 and spawner.opportunities == 3, "configuration switch retains statistics")
	var state_before: int = spawner._random.state
	spawner.configure_schedule(3.0,2,136.0)
	_check(spawner._random.state == state_before, "real configuration changes never re-seed RNG")
	spawner.reset(77)
	_check(spawner.spawn_remaining == 3.0 and spawner.spawned == 0 and spawner.opportunities == 0 and spawner.blocked_attempts == 0 and not spawner.pending, "reset clears counters and pending while retaining configured interval")
	_check(_tick(spawner,3.0,[],0,1.0).lane == direct.lane, "explicit reset restores seed sequence and first-spawn distance exemption")
	var repairs := Repair.new(77)
	repairs.pickups.append(preload("res://scripts/fuel_pickup.gd").new(1,-90.0))
	repairs.configure_schedule(10.0,2,136.0)
	_check(repairs.pickups.size() == 1, "repair configuration never deletes existing world pickups")

func _test_schedule_grid() -> void:
	for difficulty in range(3):
		var profile := Difficulty.for_index(difficulty)
		for kind in ["fuel", "repair"]:
			var interval: float = profile.fuel_spawn_interval if kind == "fuel" else profile.repair_spawn_interval
			for seconds in [60,120]:
				var reference_events: Array = []
				for hz in [30,60,120]:
					var first := _clock_sample(kind,interval,seconds,hz)
					var repeated := _clock_sample(kind,interval,seconds,hz)
					var expected := floori(seconds / interval)
					_check(first.opportunities == expected and first.spawned == expected and first.blocked_attempts == 0, "unblocked %s difficulty%d %ds %dHz counts match full intervals" % [kind,difficulty,seconds,hz])
					_check(first.events == repeated.events, "same seed repeats lane sequence and success intervals for %s/%d/%d/%d" % [kind,difficulty,seconds,hz])
					if reference_events.is_empty(): reference_events = first.events
					_check(first.events == reference_events, "frame rate cannot perturb the unobstructed seeded lane sequence")
					for event_index in range(first.events.size()):
						_check(absf(first.events[event_index].seconds - (event_index + 1) * interval) < 0.00001, "frame rate does not drift absolute supply interval")
					print("SUPPLY_CLOCK_SAMPLE ", JSON.stringify({"difficulty":difficulty,"kind":kind,"seconds":seconds,"hz":hz,"interval":interval,"opportunities":first.opportunities,"spawned":first.spawned,"blocked_attempts":first.blocked_attempts,"events":first.events}))

func _clock_sample(kind: String, interval: float, seconds: int, hz: int) -> Dictionary:
	var is_repair := kind == "repair"
	var director: Variant = Repair.new(431) if is_repair else Fuel.new(431,3,interval)
	director.configure_schedule(interval,2,136.0)
	var spawner = director.spawner if is_repair else director
	var events: Array[Dictionary] = []
	var dt := 1.0 / hz
	for frame in range(seconds * hz):
		var before: int = spawner.spawned
		var pickup
		if is_repair:
			# Actual wrapper movement/recycling, no player contact or repair reward.
			director.tick(dt,200.0,[],1,Vector2(-10000,-10000),0.0,260.0,720.0)
			if spawner.spawned > before: pickup = director.pickups.back()
		else:
			# Scheduler-only fixture: active_count=0 models an unobstructed supply
			# opportunity, not a real Main pickup or a claimed collection.
			pickup = spawner.tick(dt,[],1,0,200.0 * Config.ROAD_SCROLL_MULTIPLIER * dt)
		if spawner.spawned > before: events.append({"seconds":float(frame + 1) / hz,"lane":pickup.lane})
	return {"opportunities":spawner.opportunities,"spawned":spawner.spawned,"blocked_attempts":spawner.blocked_attempts,"events":events}

func _test_birth_spacing() -> void:
	var repairs := Repair.new(77)
	repairs.configure_schedule(1.0,2,136.0)
	var far_player := Vector2(-10000,-10000)
	repairs.tick(1.0,1.0 / Config.ROAD_SCROLL_MULTIPLIER,[0,2],1,far_player,0.0,260.0,10000.0)
	_check(repairs.pickups.size() == 1, "birth fixture creates first same-lane repair without reward")
	var first = repairs.pickups[0]
	var first_birth_y: float = first.y
	repairs.tick(1.0,136.0 / Config.ROAD_SCROLL_MULTIPLIER,[0,2],1,far_player,0.0,260.0,10000.0)
	_check(repairs.pickups.size() == 2, "spacing fixture reaches cap with two successful actual pickups")
	var second = repairs.pickups[1]
	print("SUPPLY_BIRTH_SPACING ", JSON.stringify({"first_birth_y":first_birth_y,"first_current_y":first.y,"newborn_y":second.y,"spacing":absf(first.y-second.y),"schedule_progress_after_success":repairs.spawner.road_advance_since_spawn,"same_lane":first.lane == second.lane}))
	_check(first_birth_y == Fuel.PICKUP_SPAWN_Y and second.y == Fuel.PICKUP_SPAWN_Y, "end-of-tick newborn is not advanced through time before its birth")
	_check(first.lane == second.lane and absf(first.y-second.y) >= 136.0, "actual same-lane bodies preserve minimum road advance, not only scheduler ledger")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("PRODUCT_SUPPLY_SCHEDULE " + message)
