extends SceneTree
## The "drop the egg straight down" practice problem flies the shot with the
## player's throw speed: the egg really drifts forwards / backwards / falls
## straight, and the verdict matches what happened in the flight.
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
func attempt(panel, w, energy):
	panel._answer_spins[0].value = w
	panel._answer_spins[1].value = energy
	panel.check()
	var egg_vx = INF
	for i in 400:
		await physics_frame
		var b = main.bird
		if is_instance_valid(b) and b.pieces.size() == 2 and is_instance_valid(b.pieces[1]) and egg_vx == INF:
			egg_vx = b.pieces[1].velocity_m().x
		if panel._watching.is_empty(): break
	await frames(2)
	return egg_vx
func run():
	await frames(10)
	main.show_topic(3)
	var panel = main.find_children("*", "PracticePanel", true, false)[0]
	for i in panel._picker.item_count:
		if "drop the ballast straight down" in panel._picker.get_item_text(i): panel._picker.select(i)
	panel.new_problem()
	await frames(5)
	var c = panel.problem.correct
	var vx = panel.problem.speed
	var egg_vx = await attempt(panel, snappedf(c[0], 0.01), snappedf(c[1], 0.01))
	ok("right throw + energy: '%s', egg forward speed in flight %.3f m/s" % [main.message.text, egg_vx], main.message.text.begins_with("✓ Straight down!") and absf(egg_vx) < 0.05 * vx)
	egg_vx = await attempt(panel, snappedf(c[0] * 0.6, 0.01), snappedf(c[1], 0.01))
	ok("too slow: '%s', egg really drifts forwards (%.2f m/s)" % [main.message.text, egg_vx], "forwards" in main.message.text and egg_vx > 0.5)
	egg_vx = await attempt(panel, snappedf(c[0] * 1.5, 0.01), snappedf(c[1], 0.01))
	ok("too fast: '%s', egg really flies backwards (%.2f m/s)" % [main.message.text, egg_vx], "backwards" in main.message.text and egg_vx < -0.5)
	egg_vx = await attempt(panel, snappedf(c[0], 0.01), snappedf(c[1] * 1.3, 0.01))
	ok("right throw, wrong energy: '%s'" % main.message.text, "Straight down" in main.message.text and "energy is too high" in main.message.text)
	panel.end_problem()
	ok("ending restores the normal egg throw", P.egg["back_speed"] < 0.0)
	print("DONE, fails=%d" % fails)
	quit(fails)
