extends SceneTree
## Every predict problem flies the shot on Check and shows the player's answer
## in the world. For each kind, with the right answer and a wrong one:
##   - the shot flies, the check finishes, and the verdict (✓/✗) matches
##   - a wrong answer gets a sentence about what happened ("landed 2 m beyond...")
##   - a ghost made from the RIGHT answer flies exactly with the real bird, and
##     one from a wrong answer ends up somewhere else
##   - split problems: the pieces' center of mass stays with the "no split"
##     ghost only when the answer conserves momentum
var main
var P
var fails := 0
# These ghosts are a different bird (the first shot), not "your answer":
const OTHER_BIRD_GHOSTS := ["Same range, other angle", "Spring slingshot: heavy vs light ball"]

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

## Check with `answers`; follow the flight. Returns the largest distance (m)
## between the real bird and the ghost while both fly (or the center of mass and
## the ghost, for splits), and whether the check finished.
func attempt(panel, answers: Array) -> Dictionary:
	for i in answers.size():
		panel._answer_spins[i].value = answers[i]
	var given: Array[float] = []
	for i in answers.size():
		given.append(panel._answer_spins[i].value)
	panel.check()
	var problem = panel.problem
	var gap := 0.0
	var finished := false
	for i in 3000:
		await physics_frame
		var bird = main.bird
		if is_instance_valid(bird) and bird.state == 0:   # FLYING
			var t: float = bird.flight_time
			var here: Vector2 = Units.to_m(bird.position)
			if problem.show_com and bird.pieces.size() > 1:
				var com := Vector2.ZERO
				var total := 0.0
				var all_flying := true
				for piece in bird.pieces:
					# (a piece that just hit something stops mid-step, before it hands over to physics)
					if not is_instance_valid(piece) or piece.state != 0 or absf(piece.flight_time - t) > 1e-6: all_flying = false
					else:
						com += piece.mass_now() * Units.to_m(piece.position)
						total += piece.mass_now()
				here = com / total if all_flying else Vector2.INF
			if here != Vector2.INF and (not problem.show_com or bird.pieces.size() > 1):
				for part in problem.ghosts(given):
					var local: float = t - part["start"]
					if local >= 0.0 and local <= part["until"] and local <= Kinematics.time_of_flight(part["params"]):
						gap = maxf(gap, here.distance_to(Kinematics.position(part["params"], local)))
		if panel._watching.is_empty():
			finished = true
			break
	await frames(2)
	return {"gap": gap, "finished": finished}

func run():
	await frames(10)
	Engine.time_scale = 3.0   # the flights are formulas: a faster clock doesn't change them
	main.show_topic(3)
	var panel = main.find_children("*", "PracticePanel", true, false)[0]
	for item in panel._picker.item_count:
		var kind = panel._picker.get_item_metadata(item)
		if not (kind is int):
			continue
		var sample = panel._samples[kind]
		if sample.kind != "predict":
			continue
		panel._picker.select(item)
		panel.new_problem()
		await frames(3)
		var problem = panel.problem
		var name: String = problem.title
		if problem.demo_shot:
			await frames(5)
		if not problem.flies:
			panel.check()
			ok("%s: check-only, answered at once ('%s')" % [name, main.message.text], main.message.text != "")
			panel.end_problem()
			continue
		var has_ghost: bool = not problem.ghosts(problem.correct).is_empty() and name not in OTHER_BIRD_GHOSTS

		var right := []
		var wrong := []
		for i in problem.answers.size():
			var value: float = problem.correct[i]
			right.append(value)
			# 30% off, but angles 15° off: near 0° cos barely changes, so 30% of a
			# small random angle (say 10° → 13.5°) can fly almost the same path.
			wrong.append(value + 15.0 if problem.answers[i]["unit"] == "°" else value * 1.3 + 0.5)
		var r = await attempt(panel, right)
		ok("%s, right answer: finished=%s, '%s'" % [name, r["finished"], main.message.text], r["finished"] and main.message.text.begins_with("✓"))
		if has_ghost or problem.show_com:
			ok("%s, right answer: ghost flies with the real %s (max gap %.3f m)" % [name, "center of mass" if problem.show_com else "bird", r["gap"]], r["gap"] < 0.3)
		var w = await attempt(panel, wrong)
		ok("%s, wrong answer: finished=%s, '%s'" % [name, w["finished"], main.message.text], w["finished"] and main.message.text.begins_with("✗") and "  ·  " in main.message.text)
		if has_ghost or problem.show_com:
			ok("%s, wrong answer: ghost and real part ways (max gap %.2f m)" % [name, w["gap"]], w["gap"] > 0.5)
		panel.end_problem()
		await frames(2)
	Engine.time_scale = 1.0
	ok("ending restores the split and rocket settings", P.split["speed"] < 0.0 and is_equal_approx(P.rocket["fuel"], P.ROCKET_DEFINITIONS["fuel"]["default"]))
	print("DONE, fails=%d" % fails)
	quit(fails)
