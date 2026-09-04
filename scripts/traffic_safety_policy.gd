class_name TrafficSafetyPolicy
extends RefCounted

const WALL_LONGITUDINAL_CLEARANCE := 120.0
const BODY_MARGIN := 4.0

static func reserved_lanes(vehicle) -> Array[int]:
	var lanes: Array[int] = [int(vehicle.lane)]
	if vehicle.lane_change_enabled and vehicle.warning_started and int(vehicle.target_lane) != int(vehicle.lane):
		lanes.append(int(vehicle.target_lane))
	return lanes

static func has_full_lane_wall(vehicles: Array, lane_count: int, clearance: float = WALL_LONGITUDINAL_CLEARANCE) -> bool:
	for reference in vehicles:
		var blocked := _lanes_in_window(vehicles, float(reference.y), clearance)
		if blocked.size() >= maxi(1, lane_count):
			return true
	return false

static func would_create_full_lane_wall(
	vehicles: Array,
	candidate,
	lane_count: int,
	candidate_y: float,
	candidate_lanes: Array[int],
	clearance: float = WALL_LONGITUDINAL_CLEARANCE
) -> bool:
	var entries: Array[Dictionary] = []
	for lane in candidate_lanes:
		entries.append({"lane": lane, "y": candidate_y})
	for other in vehicles:
		if other == candidate:
			continue
		for lane in reserved_lanes(other):
			entries.append({"lane": lane, "y": float(other.y)})
	for reference in entries:
		var blocked: Array[int] = []
		var window_start := float(reference.y)
		for entry in entries:
			var entry_y := float(entry.y)
			if entry_y >= window_start and entry_y - window_start < maxf(0.0, clearance):
				_append_unique(blocked, int(entry.lane))
		if blocked.size() >= maxi(1, lane_count):
			return true
	return false

static func would_form_full_lane_wall_during(
	vehicles: Array,
	candidate,
	lane_count: int,
	candidate_lanes: Array[int],
	duration: float,
	scroll_multiplier: float,
	clearance: float = WALL_LONGITUDINAL_CLEARANCE
) -> bool:
	var entries: Array[Dictionary] = []
	for lane in candidate_lanes:
		entries.append({
			"lane": lane,
			"y": float(candidate.y),
			"velocity": -float(candidate.cruise_speed) * scroll_multiplier,
		})
	for other in vehicles:
		if other == candidate:
			continue
		for lane in reserved_lanes(other):
			entries.append({
				"lane": lane,
				"y": float(other.y),
				"velocity": -float(other.cruise_speed) * scroll_multiplier,
			})
	var critical_times: Array[float] = [0.0, maxf(0.0, duration)]
	for first_index in range(entries.size()):
		for second_index in range(first_index + 1, entries.size()):
			var first := entries[first_index]
			var second := entries[second_index]
			var relative_velocity := float(first.velocity) - float(second.velocity)
			if is_zero_approx(relative_velocity):
				continue
			var initial_delta := float(first.y) - float(second.y)
			for boundary in [-clearance, 0.0, clearance]:
				var crossing_time: float = (float(boundary) - initial_delta) / relative_velocity
				if crossing_time > 0.0 and crossing_time < duration:
					critical_times.append(crossing_time)
	critical_times.sort()
	var sample_times: Array[float] = critical_times.duplicate()
	for index in range(critical_times.size() - 1):
		sample_times.append((critical_times[index] + critical_times[index + 1]) * 0.5)
	for sample_time in sample_times:
		if _entries_form_full_lane_wall(entries, lane_count, sample_time, clearance):
			return true
	return false

static func has_body_overlap(vehicles: Array, lane_width: float) -> bool:
	for first_index in range(vehicles.size()):
		var first = vehicles[first_index]
		for second_index in range(first_index + 1, vehicles.size()):
			var second = vehicles[second_index]
			var lateral_distance := absf(float(first.lane_position) - float(second.lane_position)) * maxf(1.0, lane_width)
			var longitudinal_distance := absf(float(first.y) - float(second.y))
			if lateral_distance < float(first.half_width) + float(second.half_width) + BODY_MARGIN \
				and longitudinal_distance < float(first.half_length) + float(second.half_length) + BODY_MARGIN:
				return true
	return false

static func rear_y_outside_full_wall(
	vehicles: Array,
	candidate,
	lane_count: int,
	candidate_y: float,
	candidate_lanes: Array[int],
	clearance: float = WALL_LONGITUDINAL_CLEARANCE
) -> float:
	var entries: Array[Dictionary] = []
	for lane in candidate_lanes:
		entries.append({"lane": lane, "y": candidate_y, "candidate": true})
	for other in vehicles:
		if other == candidate:
			continue
		for lane in reserved_lanes(other):
			entries.append({"lane": lane, "y": float(other.y), "candidate": false})
	var safe_y := candidate_y
	for reference in entries:
		var window_start := float(reference.y)
		if candidate_y < window_start or candidate_y - window_start >= maxf(0.0, clearance):
			continue
		var blocked: Array[int] = []
		var contains_candidate := false
		for entry in entries:
			var entry_y := float(entry.y)
			if entry_y >= window_start and entry_y - window_start < maxf(0.0, clearance):
				_append_unique(blocked, int(entry.lane))
				contains_candidate = contains_candidate or bool(entry.candidate)
		if contains_candidate and blocked.size() >= maxi(1, lane_count):
			safe_y = maxf(safe_y, window_start + clearance + 0.5)
	return safe_y

static func _lanes_in_window(vehicles: Array, y: float, clearance: float) -> Array[int]:
	var blocked: Array[int] = []
	for vehicle in vehicles:
		var vehicle_y := float(vehicle.y)
		if vehicle_y < y or vehicle_y - y >= maxf(0.0, clearance):
			continue
		for lane in reserved_lanes(vehicle):
			_append_unique(blocked, lane)
	return blocked

static func _entries_form_full_lane_wall(entries: Array[Dictionary], lane_count: int, time: float, clearance: float) -> bool:
	for reference in entries:
		var window_start := float(reference.y) + float(reference.velocity) * time
		var blocked: Array[int] = []
		for entry in entries:
			var entry_y := float(entry.y) + float(entry.velocity) * time
			if entry_y >= window_start and entry_y - window_start < maxf(0.0, clearance):
				_append_unique(blocked, int(entry.lane))
		if blocked.size() >= maxi(1, lane_count):
			return true
	return false

static func _append_unique(values: Array[int], value: int) -> void:
	if not values.has(value):
		values.append(value)
