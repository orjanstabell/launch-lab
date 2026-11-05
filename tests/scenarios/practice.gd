extends SceneTree
var main
var P
var R
var fails := 0
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	P = root.get_node("PhysicsParams")
	R = root.get_node("Reveal")
	run()
func frames(n):
	for i in n: await physics_frame
func ok(name, cond):
	if not cond: fails += 1
	print(("  ok    " if cond else "  FAIL  ") + name)
func pick(panel, title):
	for i in panel._picker.item_count:
		if title in panel._picker.get_item_text(i):
			panel._picker.select(i); return
func answer_and_check(panel, values):
	for i in values.size(): panel._answer_spins[i].value = values[i]
	panel.check()
	for i in 600:
		await physics_frame
		if panel._watching.is_empty(): break
	await frames(2)
func run():
	await frames(10)
	P.set_value("v0", 17.0); R.set_hidden("m", true)
	P.set_rocket_value("fuel", 1.5); P.set_split("pieces", 4)
	main.show_topic(3)
	var panel = main.find_children("*", "PracticePanel", true, false)[0]
	# Control, two unknowns: two pigs
	pick(panel, "Two pigs"); panel.new_problem()
	await frames(5)
	ok("problem open: inputs locked, no tower, unknowns hidden", P.inputs_locked and main.level.get_child_count() == 0 and R.is_hidden("v0") and R.is_hidden("theta"))
	ok("manual launch blocked", not P.manual_launch_allowed)
	var c = panel.problem.correct
	await answer_and_check(panel, [c[0] * 0.8, c[1]])
	ok("wrong two-pig answer misses: '%s'" % main.message.text, main.message.text.begins_with("✗"))
	await answer_and_check(panel, [snappedf(c[0], 0.01), snappedf(c[1], 0.1)])
	ok("right two-pig answer: '%s'" % main.message.text, main.message.text == "✓ Hit them all!")
	ok("answer still not shown", not panel._feedback.text.begins_with("Answer"))
	panel.show_solution()
	ok("Show solution: answer, solution flag, details on", String.num(c[0], 2) in panel._feedback.text and panel.solution_shown and main.show_details)
	# Yellow tap, flown for real with a scheduled tap
	pick(panel, "Yellow bird"); panel.new_problem()
	await frames(5)
	await answer_and_check(panel, [snappedf(panel.problem.correct[0], 0.01)])
	var trail_ok = main.bird.activations == 1
	ok("yellow tap at the right time: '%s', tapped once" % main.message.text, main.message.text == "✓ Hit!" and trail_ok)
	# real flight passes the pig?
	# Predict
	pick(panel, "Predict where it lands"); panel.new_problem()
	await frames(5)
	ok("predict: path hidden", R.is_hidden("predict"))
	await answer_and_check(panel, [panel.problem.correct[0] * 1.2])
	ok("predict wrong: '%s' / '%s'" % [main.message.text, panel._feedback.text], main.message.text.begins_with("✗ Not quite") and "short of your flag" in main.message.text and "too high" in panel._feedback.text)
	await answer_and_check(panel, [snappedf(panel.problem.correct[0], 0.01)])
	print("      after right predict: msg=%s bird_valid=%s fb=%s correct=%f" % [main.message.text, is_instance_valid(main.bird), panel._feedback.text, panel.problem.correct[0]])
	ok("predict right + bird flies, verdict after landing", main.message.text.begins_with("✓ Correct!") and is_instance_valid(main.bird) and main.bird.flight_time > 0.5)
	# Random kind
	for i in panel._picker.item_count:
		if panel._picker.get_item_text(i) == "Random: Momentum": panel._picker.select(i)
	panel.new_problem()
	ok("random momentum problem: '%s'" % panel.problem.title, panel.problem.topic == "Momentum" and panel._question.text.begins_with("[Momentum"))
	# Leave the tab: everything restored
	main.show_topic(0)
	await frames(3)
	ok("leaving the tab ends the problem", panel.problem == null)
	ok("values restored (v0 = %.1f), unlocked, tower back" % P.values["v0"], is_equal_approx(P.values["v0"], 17.0) and not P.inputs_locked and P.manual_launch_allowed and main.level.get_child_count() > 0)
	ok("rocket fuel (%.2f) and split pieces (%d) restored" % [P.rocket["fuel"], P.split["pieces"]], is_equal_approx(P.rocket["fuel"], 1.5) and P.split["pieces"] == 4 and P.split["speed"] < 0.0 and P.egg["back_speed"] < 0.0)
	ok("hidden values restored", R.is_hidden("m") and not R.is_hidden("predict") and not R.is_hidden("v0"))
	print("DONE, fails=%d" % fails)
	quit(fails)
