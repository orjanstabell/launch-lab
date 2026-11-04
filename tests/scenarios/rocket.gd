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
	main.load_level(L.blank("empty"))
	P.set_bird_type("rocket"); P.set_value("m", 2.0); P.set_value("theta", 50.0); P.set_value("v0", 12.0)
	P.set_rocket_value("fuel", 1.0); P.set_rocket_value("exhaust", 30.0); P.set_rocket_value("burn_rate", 0.8)
	main.launch(); await frames(30)
	var b = main.bird
	var speed_before = b.velocity_m().length()
	var e_before = b.total_energy()
	ok("rocket bird can fire", P.can_activate())
	P.activate()
	ok("fires only once", not P.can_activate())
	ok("segment is a rocket burning for 1.25 s (fuel 1 kg / 0.8 kg/s)", b.segment.is_rocket() and is_equal_approx(b.segment.burn_time, 1.25))
	var worst := 0.0
	for i in 70:
		await physics_frame
		if b.state != 0: break
		worst = max(worst, b.position.distance_to(K.position(b.segment, b.t) * Vector2(50, -50)))
	ok("follows the rocket formula exactly in flight (worst %.6f px)" % worst, worst < 1e-3)
	ok("mass at the end of the burn = 1 kg (got %.3f)" % K.mass_at(b.segment, b.segment.burn_time), absf(K.mass_at(b.segment, b.segment.burn_time) - 1.0) < 1e-4)
	var gained = K.rocket_speed(b.segment, b.segment.burn_time)
	ok("Δv along the thrust = 30·ln 2 = %.3f (got %.3f)" % [30.0 * log(2.0), gained], absf(gained - 30.0 * log(2.0)) < 1e-3)
	ok("exhaust puffs were released (%d)" % b.exhaust.puffs.size(), b.exhaust != null and b.exhaust.puffs.size() > 20)
	# momentum: bird + exhaust ≈ the bird without a rocket
	var total = b.mass_now() * b.velocity_m()
	for puff in b.exhaust.puffs: total += puff["mass"] * b.exhaust.puff_velocity(puff)
	var label = main.find_children("*", "MomentumLabel", true, false)[0]
	var plain = label._without_rocket(b.segment)
	var expected = b.segment.m * K.velocity(plain, b.t)
	ok("bird + exhaust Σp (%.2f, %.2f) ≈ no rocket p (%.2f, %.2f)" % [total.x, total.y, expected.x, expected.y], total.distance_to(expected) < 0.05 * expected.length())
	var e_after = b.total_energy()
	ok("the burn adds energy (%.1f → %.1f J)" % [e_before.x + e_before.y, e_after.x + e_after.y], e_after.x + e_after.y > e_before.x + e_before.y)
	print("DONE, fails=%d" % fails)
	quit(fails)
