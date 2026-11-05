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
	await frames(10)
	main.show_topic(3)
	var panel = main.find_children("*", "PracticePanel", true, false)[0]
	for i in panel._picker.item_count:
		if "pull to hit" in panel._picker.get_item_text(i): panel._picker.select(i)
	panel.new_problem()
	await frames(3)
	ok("problem switched to spring mode", P.launch_mode == "spring")
	panel._answer_spins[0].value = snappedf(panel.problem.correct[0], 0.01)
	panel.check()
	for i in 600:
		await physics_frame
		if panel._watching.is_empty(): break
	await frames(2)
	ok("right pull hits: '%s'" % main.message.text, main.message.text == "✓ Hit!")
	ok("the bird flew with v₀ = Δx·√(k/m) (%.3f vs %.3f)" % [main.bird.segment_history[0].v0, P.spring_speed()], absf(main.bird.segment_history[0].v0 - P.spring_speed()) < 0.01)
	panel.end_problem()
	ok("ending restores speed mode", P.launch_mode == "speed")
	print("DONE, fails=%d" % fails)
	quit(fails)
