extends SceneTree
var main
var P
var K
var fails := 0
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	P = root.get_node("PhysicsParams")
	K = load("res://physics/kinematics.gd")
	run()
func frames(n):
	for i in n: await physics_frame
func ok(name, cond):
	if not cond: fails += 1
	print(("  ok    " if cond else "  FAIL  ") + name)
func run():
	await frames(10)
	var L = load("res://levels/level.gd")
	var level = L.blank("action")
	L.add_pig(level, Vector2(20.0, 0.6), true)
	main.load_level(level)
	await frames(40)
	var sim = main.find_children("*", "SimControls", true, false)[0]
	sim.cycle_action_cam()
	ok("action cam switched on", main.action_cam_enabled)
	P.set_value("theta", 35.0); P.set_value("v0", K.solve_speed(35.0, 9.81, 0.0, Vector2(20.0, 0.6)))
	main.launch()
	var triggered := false
	var bird_dist := 0.0
	for i in 400:
		await physics_frame
		if not main.action.is_empty():
			triggered = true
			bird_dist = (main.bird.position / 50.0).distance_to(Vector2(20.0, -0.6))
			break
	ok("the sensor triggered the action cam before the hit (bird %.2f m from the pig, still flying: %s)" % [bird_dist, main.bird.state == 0], triggered and main.bird.state == 0)
	ok("slow motion on (time scale %.2f), overlay shown" % Engine.time_scale, is_equal_approx(Engine.time_scale, 0.12) and main.action_overlay.visible)
	await frames(30)
	ok("camera zooms in (zoom %.2f, heading to 3)" % main.view_zoom, main.view_zoom > 1.2)
	var saw_contact := 0.0
	for i in 2000:
		await physics_frame
		var pig = main.action_overlay.pig
		if is_instance_valid(pig): saw_contact = max(saw_contact, pig.contact_force.length())
		if main.action.is_empty(): break
	ok("a big contact force on the pig was measured (%.0f N)" % saw_contact, saw_contact > 100.0)
	ok("afterwards: back to normal speed (%.2f) and overlay hidden" % Engine.time_scale, is_equal_approx(Engine.time_scale, 1.0) and not main.action_overlay.visible)
	var resting = main.get_tree().get_nodes_in_group("pigs")
	if resting.size() > 0:
		await frames(60)
		ok("resting pig: contact force = its weight, upwards (normal force %.1f N vs m·g %.1f N)" % [resting[0].contact_force.y, resting[0].mass * 9.81], absf(resting[0].contact_force.y - resting[0].mass * 9.81) < 0.5)
	print("DONE, fails=%d" % fails)
	quit(fails)
