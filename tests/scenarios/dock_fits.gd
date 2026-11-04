extends SceneTree
## The dock (topic panel | parameters | sim controls) must always fit on the
## 1920×1080 screen: every tab, every bird (speed and spring launch, in flight
## and after the hit) and every kind of practice problem, asked and answered.
## A single long line used to push the right-hand columns off the screen.
var main
var P
var fails := 0
var columns: HBoxContainer   # the dock's three columns
var widest := 0.0
var tallest := 0.0
const SCREEN := Vector2(1920, 1080)
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	P = root.get_node("PhysicsParams")
	run()
func frames(n):
	for i in n: await process_frame
func ok(name, cond):
	if not cond: fails += 1
	print(("  ok    " if cond else "  FAIL  ") + name)
## Fails (once per state) if the dock pokes out of the screen right now. The
## columns sit side by side at their own widths, so the last one's right edge
## shows whether they fit (the row itself always stretches to the full width).
func fits(what: String):
	await frames(2)
	var last: Control = columns.get_child(columns.get_child_count() - 1)
	var right := last.get_global_rect().end.x
	var bottom := columns.get_global_rect().end.y
	widest = maxf(widest, right)
	tallest = maxf(tallest, bottom)
	if right > SCREEN.x - 10.0 or bottom > SCREEN.y:
		ok("%s: dock fits on screen (right edge %.0f px, bottom %.0f px)" % [what, right, bottom], false)
func run():
	await frames(10)
	columns = main.find_children("*", "ParamPanel", true, false)[0].get_parent()
	for i in main.topics.size():
		main.show_topic(i)
		await fits("tab %s" % main.topics[i].title)
	# Every bird, both launch modes: before launch, in flight (ability used), after the hit.
	Engine.time_scale = 3.0
	for mode in ["speed", "spring"]:
		for type in ["red", "yellow", "blue", "matilda", "rocket", "custom"]:
			main.reset_level()
			P.set_launch_mode(mode)
			P.set_bird_type(type)
			if type == "custom":
				P.set_ability_on("theta", true)
			var what := "%s bird, %s launch" % [type, mode]
			for i in 4:
				main.show_topic(i)
				await fits("%s, %s tab, waiting" % [what, main.topics[i].title])
			main.launch()
			while P.is_flying() and main.bird.flight_time < 0.4:
				await process_frame
			P.activate()
			for i in 4:
				main.show_topic(i)
				await fits("%s, %s tab, in flight" % [what, main.topics[i].title])
			for f in 900:
				if not P.is_flying(): break
				await process_frame
			await frames(30)
			for i in 4:
				main.show_topic(i)
				await fits("%s, %s tab, after the hit" % [what, main.topics[i].title])
	P.set_launch_mode("speed")
	P.set_bird_type("red")
	# Every kind of practice problem: asked, answered wrong, solution shown.
	main.show_topic(4)
	await frames(2)
	var panel = main.find_children("*", "PracticePanel", true, false)[0]
	for item in panel._picker.item_count:
		var kind = panel._picker.get_item_metadata(item)
		if not (kind is int):
			continue
		panel._picker.select(item)
		panel.new_problem()
		var title: String = panel.problem.title
		await fits("practice '%s', asked" % title)
		for i in panel.problem.answers.size():
			panel._answer_spins[i].value = panel.problem.correct[i] * 1.3 + 0.5
		panel.check()
		for f in 1200:
			if panel._watching.is_empty(): break
			await process_frame
		await fits("practice '%s', answered" % title)
		panel.show_solution()
		await fits("practice '%s', solution shown" % title)
		panel.end_problem()
	Engine.time_scale = 1.0
	# The levels: each preset's task and settings in the Levels and Editor tabs.
	for preset in load("res://levels/level_presets.gd").all():
		main.load_level(preset)
		main.show_topic(5)
		await fits("level '%s', Levels tab" % preset["name"])
		main.show_topic(6)
		await fits("level '%s', Editor tab" % preset["name"])
	main.show_topic(0)
	ok("the dock always fit on the %d×%d screen (widest right edge %.0f px, lowest bottom %.0f px)" % [SCREEN.x, SCREEN.y, widest, tallest], widest <= SCREEN.x - 10.0 and tallest <= SCREEN.y)
	print("DONE, fails=%d" % fails)
	quit(fails)
