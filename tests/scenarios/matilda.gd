extends SceneTree
## Matilda: throwing the egg conserves momentum, kicks her up by (m_egg/m)·u,
## keeps the center of mass on the old arc, and the egg can knock out a pig.
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
	main.load_level(L.blank("empty"))
	P.set_bird_type("matilda"); P.set_value("m", 2.0); P.set_value("theta", 45.0); P.set_value("v0", 15.0)
	P.set_egg_value("mass", 0.5); P.set_egg_value("speed", 20.0)
	main.launch(); await frames(30)
	var b = main.bird
	var v_before = b.velocity_m()
	ok("Matilda can throw her egg", P.can_activate())
	P.activate()
	ok("only one egg", not P.can_activate())
	ok("two pieces: Matilda and the egg", b.pieces.size() == 2 and b.pieces[1].type == "egg")
	var info = b.split_info
	ok("momentum conserved (%s → %s)" % [info["p_before"], info["p_after"]], info["p_before"].distance_to(info["p_after"]) < 1e-4)
	var kick = b.velocity_m().y - v_before.y
	ok("kicked up by (m_egg/m)·u = 0.25·20 = 5 m/s (got %.4f)" % kick, absf(kick - 5.0) < 1e-3)
	ok("Matilda is now 1.5 kg, the egg 0.5 kg", is_equal_approx(b.segment.m, 1.5) and is_equal_approx(b.pieces[1].segment.m, 0.5))
	var worst := 0.0
	for i in 40:
		await physics_frame
		if b.state != 0 or b.pieces[1].state != 0: break
		var com = (1.5 * b.position + 0.5 * b.pieces[1].position) / 2.0 / 50.0 * Vector2(1, -1)
		var unsplit = K.position(b.pre_split, b.split_t + b.flight_time - b.split_flight_time)
		worst = max(worst, com.distance_to(unsplit))
	ok("center of mass stays on the old arc (worst %.6f m)" % worst, worst < 1e-3)
	# Straight down on screen: the egg has no forward speed, she speeds up forwards
	main.reset_level(); await frames(5)
	P.set_egg_straight_down(true)
	main.launch(); await frames(30)
	b = main.bird
	var vx_before = b.velocity_m().x
	P.activate()
	var egg = b.pieces[1]
	ok("straight down: the egg has no forward speed (%.6f)" % egg.velocity_m().x, absf(egg.velocity_m().x) < 1e-4)
	ok("straight down: she speeds up forwards ×m/m_bird = ×%.3f (got ×%.3f)" % [2.0 / 1.5, b.velocity_m().x / vx_before], absf(b.velocity_m().x / vx_before - 2.0 / 1.5) < 1e-4)
	ok("straight down: momentum still conserved", b.split_info["p_before"].distance_to(b.split_info["p_after"]) < 1e-4)
	P.set_egg_straight_down(false)
	# The egg knocks out a pig below
	var level = L.blank("egg drop")
	L.add_pig(level, Vector2(12.0, 0.4))
	main.load_level(level)
	P.set_egg_value("mass", 1.0); P.set_egg_value("speed", 10.0)
	await frames(40)
	P.set_value("theta", 45.0); P.set_value("v0", 14.0)
	main.launch()
	for i in 600:
		await physics_frame
		# The egg keeps her forward speed, so drop it when its path (the yellow
		# preview) passes over the pig, not when she's right above it.
		if main.bird.state == 0 and P.can_activate():
			var egg_path = main.bird.preview_segments()[1]
			if K.closest_approach(egg_path, Vector2(12.0, 0.4)).y < 0.4:
				P.activate()
		if main.get_tree().get_nodes_in_group("pigs").is_empty(): break
	ok("dropped when its path crossed the pig, the egg knocked it out", main.get_tree().get_nodes_in_group("pigs").is_empty())
	print("DONE, fails=%d" % fails)
	quit(fails)
