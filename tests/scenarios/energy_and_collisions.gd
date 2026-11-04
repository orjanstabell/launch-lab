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
	await frames(20)
	# Conservation in flight
	P.set_value("y0", 2.0); main.launch()
	var e0 = main.bird.launch_energy()
	var worst := 0.0
	for i in 150:
		await physics_frame
		if main.bird.state != 0: break
		var e = main.bird.total_energy()
		worst = max(worst, absf(e.x + e.y - e0))
	ok("E = KE + PE constant in flight (launch %.3f J, worst drift %.6f J)" % [e0, worst], worst < 1e-3)
	# Spring energy = launch KE
	P.set_value("y0", 0.0); P.set_launch_mode("spring"); P.set_value("m", 2.0)
	var spring_e = 0.5 * P.spring["k"] * pow(P.spring["pull"], 2)
	main.reset_level(); main.launch(); await frames(2)
	ok("½·k·Δx² (%.2f J) = launch KE ½·m·v₀² (%.2f J)" % [spring_e, main.bird.launch_energy()], absf(spring_e - main.bird.launch_energy()) < 1e-3)
	P.set_launch_mode("speed"); P.set_value("m", 1.0)
	# Blue split adds KE
	P.set_bird_type("blue"); main.reset_level(); main.launch(); await frames(20)
	var before = main.bird.total_energy()
	P.activate(); await frames(1)
	var after = main.bird.total_energy()
	ok("blue split adds energy (%.2f → %.2f J)" % [before.x + before.y, after.x + after.y], after.x + after.y > before.x + before.y + 0.1)
	P.set_bird_type("red")
	# Collision snapshot: hit the pig on the tower
	main.reset_level(); await frames(40)
	P.set_value("v0", 18.0); P.set_value("theta", 45.0)
	var solve = main.find_children("*", "SolvePanel", true, false)[0]
	solve._solve()
	main.launch()
	for i in 300:
		await physics_frame
		if P.collision.has("bird_after"): break
	var c = P.collision
	ok("snapshot recorded: bird hit the %s" % c.get("other_name", "?"), c.get("other_name") == "pig" and c.has("bird_after"))
	if c.has("bird_after"):
		var pb = c["bird_m"] * c["bird_before"] + c["other_m"] * c["other_before"]
		var pa = c["bird_m"] * c["bird_after"] + c["other_m"] * c["other_after"]
		print("      Σp before (%.2f, %.2f)  after (%.2f, %.2f)   KE %.1f → %.1f J" % [pb.x, pb.y, pa.x, pa.y, c["ke_before"], c["ke_after"]])
		ok("KE lost in the hit", c["ke_after"] < c["ke_before"])
		var energy_formulas = main.topics[3].details.get_child(0)   # the Energy tab's Formulas panel
		ok("Energy formulas panel shows the last hit's KE before/after", "LAST HIT" in "\n".join(energy_formulas._build_lines()))
	# A clean sideways hit with no gravity: nothing else pushes, so Σp must be kept
	P.set_value("g", 0.0); P.set_value("y0", 2.3); P.set_value("theta", 0.0); P.set_value("v0", 12.0)
	main.reset_level(); await frames(40)
	P.collision = {}
	main.launch()
	for i in 300:
		await physics_frame
		if P.collision.has("bird_after"): break
	c = P.collision
	if c.has("bird_after"):
		var pb = c["bird_m"] * c["bird_before"] + c["other_m"] * c["other_before"]
		var pa = c["bird_m"] * c["bird_after"] + c["other_m"] * c["other_after"]
		print("      g = 0, sideways: Σp before (%.2f, %.2f)  after (%.2f, %.2f)" % [pb.x, pb.y, pa.x, pa.y])
		ok("no outside push → Σp conserved (|Δp| %.3f of %.2f)" % [(pa - pb).length(), pb.length()], (pa - pb).length() < 0.1 * pb.length())
	else:
		ok("sideways hit recorded", false)
	print("DONE, fails=%d" % fails)
	quit(fails)
