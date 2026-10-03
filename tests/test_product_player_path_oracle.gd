extends SceneTree
const Oracle = preload("res://tests/support/player_path_oracle.gd")
const Drive = preload("res://scripts/drive_controller.gd")
const Integrity = preload("res://scripts/vehicle_integrity.gd")
const Cars = preload("res://scripts/catalog/vehicle_catalog.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var clear := _trace(60)
	var path: Dictionary = Oracle.find_path(clear)
	_check(path.status == "witness","clear road has a constructive path")
	_check(Oracle.validate_path(clear,path),"positive witness independently revalidates")
	var bypass := _trace(60)
	# Body enters player row after half a second: enough time to move sideways.
	for index in 60:
		bypass.frames[index].bodies = [_body(0.0,592.0-240.0+index*4.0,0.0,592.0-236.0+index*4.0)]
	path = Oracle.find_path(bypass)
	_check(path.status == "witness" and Oracle.validate_path(bypass,path),"continuous steer bypasses approaching car")
	var slow := bypass.duplicate(true)
	slow.steering_speed = 10.0
	_check(Oracle.find_path(slow).status == "unverified","insufficient steer never masquerades as an available lane")
	var wall := _trace(1)
	wall.frames[0].bodies = [_body(0.0,592.0,0.0,592.0,400.0)]
	_check(Oracle.find_path(wall).status == "unverified","full wall yields no witness, not a claim of global impossibility")
	var thin := _trace(1)
	thin.frames[0].bodies = [_body(-100.0,592.0,100.0,592.0,1.0)]
	_check(not Oracle.validate_path(thin,{"xs":[0.0,0.0],"controls":[0.0]}),"clear endpoints cannot hide swept contact")
	_check(not Oracle.validate_path(_trace(1),{"xs":[0.0,260.0],"controls":[1.0]}),"integer-lane teleport is rejected")
	_check(not Oracle.validate_path(_trace(1),{"xs":[0.0,0.0],"controls":[INF]}),"nonfinite input rejected")
	var narrow := _trace(1)
	narrow.x0 = 350.0
	_check(not Oracle.validate_path(narrow,{"xs":[350.0,370.0],"controls":[1.0]}),"body width prevents road-edge escape")
	var terminal := _trace(1)
	terminal.hull = 19.0
	_check(Oracle.find_path(terminal).status == "invalid","failed hull is not a drivable configuration")
	var bad := _trace(1)
	bad.frames[0].dt = 0.25
	_check(Oracle.find_path(bad).status == "invalid","outer-frame chord is not a continuous 60Hz trace")
	var slit := _trace(1)
	slit.frames[0].bodies = [_body(-100.0,592.0,-27.5,592.0,1.0),_body(100.0,592.0,34.7,592.0,1.0)]
	_check(Oracle.find_path(slit).status == "unverified","coarse inputs miss a fractional control window without claiming no solution")
	var refined: Dictionary = Oracle.find_path(slit,[0.0,-1.0,-0.5,0.5,1.0])
	_check(refined.status == "witness" and Oracle.validate_path(slit,refined),"half input constructs and replays a narrow continuous route")
	var wider := slit.duplicate(true)
	wider.half_x = 31.0
	_check(Oracle.find_path(wider,[0.0,-1.0,-0.5,0.5,1.0]).status == "unverified","one pixel wider body cannot reuse narrow-car witness")
	var forged := refined.duplicate(true)
	forged.controls[0] = 0.0
	_check(not Oracle.validate_path(slit,forged),"a safe-looking coordinate without matching controls is rejected")
	_check(Oracle.find_path(clear,[NAN]).status == "invalid","invalid candidate controls cannot generate a success")
	var malformed := _trace(1)
	malformed.frames[0].bodies = [{"x0":0.0}]
	_check(Oracle.find_path(malformed).status == "invalid","incomplete obstacle evidence fails closed")
	var edge := _trace(1)
	edge.x0 = 359.0
	_check(Oracle.validate_path(edge,{"xs":[359.0,360.0],"controls":[1.0]}),"real road clamp permits legal boundary without exceeding it")
	_check(refined.get("scope","") == "fixed_piecewise_linear_trace_only","positive result cannot claim counterfactual traffic safety")
	for car in Cars.VEHICLES:
		for track in Tracks.TRACKS:
			for hull in [100.0,85.0,70.0,50.0,30.0,25.0,20.0]:
				for speed in [0.0,200.0,600.0,1000.0]:
					for input in [-1.0,-0.5,0.0,0.5,1.0]:
						var steering: float = car.steering_speed*track.steering_multiplier
						var drive = Drive.new(speed,car.max_speed,car.acceleration,car.braking,steering,390.0,30.0)
						var integrity = Integrity.new()
						integrity.current = hull
						drive.step(1.0/60.0,0.0,0.0,input,0.0,0.0,integrity.max_speed_multiplier(),integrity.steering_multiplier())
						var actual := _trace(1)
						actual.frames[0].speed = drive.speed
						actual.max_speed = car.max_speed
						actual.steering_speed = steering
						actual.hull = hull
						_check(Oracle.validate_path(actual,{"xs":[0.0,drive.lateral_position],"controls":[input]}),"independent steering agrees with actual car/track/hull/speed/input")
	print("PATH_ORACLE_COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: print("PATH_ORACLE_FAIL "+failure)
	print("TEST_COMPLETE test_product_player_path_oracle.gd")
	quit(0 if failures.is_empty() else 1)

func _trace(count: int) -> Dictionary:
	var frames: Array = []
	for index in count: frames.append({"dt":1.0/60.0,"speed":800.0,"bodies":[]})
	return {"x0":0.0,"y":592.0,"road_half":390.0,"half_x":30.0,"half_y":30.0,"steering_speed":500.0,"max_speed":800.0,"hull":100.0,"frames":frames}

func _body(x0: float,y0: float,x1: float,y1: float,half_x: float = 25.0) -> Dictionary:
	return {"x0":x0,"y0":y0,"x1":x1,"y1":y1,"half_x":half_x,"half_y":42.0}

func _check(condition: bool,message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
