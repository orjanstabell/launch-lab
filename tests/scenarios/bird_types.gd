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

func com_and_unsplit(b):
	var m := 0.0; var com := Vector2.ZERO; var p := Vector2.ZERO
	for piece in b.pieces:
		m += piece.segment.m; com += piece.segment.m * Units.to_m(piece.position); p += piece.segment.m * piece.velocity_m()
	var t_u = b.split_t + b.flight_time - b.split_flight_time
	return [com / m, Kinematics.position(b.pre_split, t_u), p, b.pre_split.m * Kinematics.velocity(b.pre_split, t_u)]

func run():
	await frames(20)
	# Red: no ability
	P.set_bird_type("red"); main.launch(); await frames(20)
	ok("red bird: cannot activate", not P.can_activate())
	# Yellow preset
	P.set_bird_type("yellow")
	ok("yellow preset ticks only v0 = 30", P.ability_on["v0"] and not P.ability_on["theta"] and not P.ability_on["g"] and P.ability["v0"] == 30.0)
	main.launch(); await frames(20)
	var b = main.bird
	var dir = b.velocity_m().normalized()
	P.activate()
	ok("yellow boost: speed 30, same direction", abs(b.velocity_m().length() - 30.0) < 1e-4 and b.velocity_m().normalized().distance_to(dir) < 1e-4)
	# Blue, momentum conserved
	P.set_bird_type("blue"); P.set_value("v0", 18.0); P.set_value("theta", 50.0)
	main.launch(); await frames(25); b = main.bird
	ok("blue preview shows 3 piece paths", b.preview_segments().size() == 3)
	P.activate()
	await frames(2)
	ok("blue split into 3 pieces", b.pieces.size() == 3 and main.birds.get_child_count() == 3)
	ok("one trail per piece", main.trails.get_child_count() == 3)
	ok("cannot split twice", not P.can_activate())
	var info = b.split_info
	ok("p conserved at split (%s vs %s)" % [info["p_before"], info["p_after"]], info["p_before"].distance_to(info["p_after"]) < 1e-4)
	ok("KE increases at split (%.2f -> %.2f J)" % [info["ke_before"], info["ke_after"]], info["ke_after"] > info["ke_before"])
	var maxd := 0.0; var maxdp := 0.0
	for i in 40:
		await physics_frame
		var all_fly = true
		for piece in b.pieces: if not is_instance_valid(piece) or piece.state != 0: all_fly = false
		if not all_fly: break
		var r = com_and_unsplit(b)
		maxd = max(maxd, r[0].distance_to(r[1])); maxdp = max(maxdp, r[2].distance_to(r[3]))
	ok("center of mass stays on unsplit arc (max %.6f m)" % maxd, maxd < 1e-3)
	ok("total p of pieces = unsplit p, live (max %.6f)" % maxdp, maxdp < 1e-3)
	# Blue, game-style (not conserved)
	P.set_split("conserve", false)
	main.launch(); await frames(25); b = main.bird
	P.activate()
	info = b.split_info
	var lost = 1.0 - info["p_after"].length() / info["p_before"].length()
	ok("game-style split loses momentum (%.2f%%)" % (lost * 100), lost > 0.001)
	ok("game-style keeps speed", abs(info["speed_after"] - info["speed_before"]) < 1e-4)
	print("DONE, fails=%d" % fails)
	quit(fails)
