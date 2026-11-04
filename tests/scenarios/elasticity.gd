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
func head_on(e):
	var L = load("res://levels/level.gd")
	var level = L.blank("elastic")
	L.add_pig(level, Vector2(15.0, 2.0))
	level["launch"] = {"g": 0.0, "v0": 10.0, "theta": 0.0, "y0": 2.0, "m": 1.0}
	main.load_level(level)
	P.set_elasticity(e)
	P.collision = {}
	await frames(40)
	main.launch()
	for i in 200:
		await physics_frame
		if P.collision.has("bird_after"): break
	return P.collision
func run():
	await frames(10)
	for e in [1.0, 0.5, 0.0]:
		var c = await head_on(e)
		if not c.has("bird_after"):
			ok("e = %s: hit recorded" % e, false); continue
		var kept = c["ke_after"] / c["ke_before"]
		var expected_kept = (1.0 + e * e) / 2.0   # equal masses, head on
		print("      e = %.1f: bird %.2f → %.2f m/s, pig → %.2f m/s, measured e %.2f, KE kept %.0f%% (theory %.0f%%)" % [e, c["bird_before"].x, c["bird_after"].x, c["other_after"].x, c.get("measured_e", -1), kept * 100, expected_kept * 100])
		ok("e = %.1f: measured e ≈ set (%.2f)" % [e, c.get("measured_e", -1)], absf(c.get("measured_e", -1) - e) < 0.15)
		ok("e = %.1f: KE kept ≈ (1 + e²)/2 for equal masses" % e, absf(kept - expected_kept) < 0.12)
	print("DONE, fails=%d" % fails)
	quit(fails)
