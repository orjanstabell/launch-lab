extends SceneTree
var main
var P
var fails := 0

func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	P = root.get_node("PhysicsParams")
	run()

func frames(n):
	for i in n: await physics_frame

func ok(name, cond):
	if not cond: fails += 1
	print(("  ok    " if cond else "  FAIL  ") + name)

func run():
	await frames(30)
	P.set_bird_type("custom")
	ok("no ability ticked by default", not P.ability_on.values().has(true))
	# Set the ability up BEFORE launch: change only g
	P.set_ability_on("g", true); P.set_ability_value("g", 3.0)
	main.launch()
	await frames(30)
	var b = main.bird
	var pos = Kinematics.position(b.segment, b.t); var vel = Kinematics.velocity(b.segment, b.t)
	P.activate()
	ok("g ability: starts where bird is", Kinematics.position(b.segment, 0).distance_to(pos) < 1e-4)
	ok("g ability: velocity unchanged", Kinematics.velocity(b.segment, 0).distance_to(vel) < 1e-4)
	ok("g ability: g = 3", is_equal_approx(b.segment.g, 3.0))
	ok("history has 2 segments", b.segment_history.size() == 2)
	var maxe = 0.0
	for i in 30:
		await physics_frame
		if b.state == 0: maxe = max(maxe, b.position.distance_to(Units.to_px(Kinematics.position(b.segment, b.t))))
	ok("follows new segment exactly (err %.6f px)" % maxe, maxe < 1e-3)
	# Dive: theta -45 only keeps speed
	P.set_ability_on("g", false); P.set_ability_on("theta", true); P.set_ability_value("theta", -45.0)
	var speed = b.velocity_m().length()
	P.activate()
	ok("theta ability keeps speed", abs(b.velocity_m().length() - speed) < 1e-4)
	ok("theta ability dives at -45°", abs(rad_to_deg(b.velocity_m().angle()) + 45.0) < 1e-3)
	ok("g kept after theta-only ability", is_equal_approx(b.segment.g, 3.0))
	# Stop and drop: v0 = 0
	main.launch(); await frames(30); b = main.bird
	P.set_ability_on("theta", false); P.set_ability_on("v0", true); P.set_ability_value("v0", 0.0)
	var x_before = Kinematics.position(b.segment, b.t).x
	P.activate()
	await frames(20)
	ok("v0 = 0: falls straight down (dx %.6f)" % (Kinematics.position(b.segment, b.t).x - x_before), abs(Kinematics.position(b.segment, b.t).x - x_before) < 1e-6)
	# Launch values edited mid-air only affect the next bird
	P.set_value("v0", 20.0)
	ok("launch edit mid-air leaves flying bird alone", is_equal_approx(b.segment.v0, 0.0))
	await process_frame
	main.launch(); await frames(2)
	ok("next bird uses new launch v0", is_equal_approx(main.bird.segment.v0, 20.0))
	# Activate with nothing ticked does nothing
	P.set_ability_on("v0", false)
	var segs = main.bird.segment_history.size()
	P.activate()
	ok("no ability ticked: activate does nothing", main.bird.segment_history.size() == segs)
	print("DONE, fails=%d" % fails)
	quit(fails)
