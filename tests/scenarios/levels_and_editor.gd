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
func body_positions():
	var out = []
	for c in main.level.get_children(): out.append(c.position / 50.0)
	return out
func run():
	await frames(10)
	var presets = load("res://levels/level_presets.gd").all()
	for preset in presets:
		main.load_level(preset)
		await frames(5)
		var start = body_positions()
		await frames(180)
		var now = body_positions()
		var moved := 0.0
		for i in min(start.size(), now.size()): moved = max(moved, start[i].distance_to(now[i]))
		var pigs = main.get_tree().get_nodes_in_group("pigs").size()
		ok("preset '%s': %d pieces stay put after 3 s (max move %.3f m), %d pigs alive" % [preset["name"], start.size(), moved, pigs], moved < 0.1 and pigs == preset["pigs"].size() and now.size() == start.size())
	# hidden g preset
	main.load_level(presets[3])
	ok("'Find the hidden g': g hidden, randomized (g = %.2f)" % P.values["g"], R.is_hidden("g") and not is_equal_approx(P.values["g"], 9.81))
	R.show_all()
	# Editor
	var levels_panel = main.topics[6].editor_panel
	main.show_topic(6)
	await frames(2)
	levels_panel._new_level()
	await frames(2)
	ok("New: empty level, editing on", main.level_data["blocks"].is_empty() and main.editor.active)
	var click = func(at, button = MOUSE_BUTTON_LEFT, pressed = true):
		var ev = InputEventMouseButton.new(); ev.button_index = button; ev.pressed = pressed
		main.editor.handle_input(ev, at)
	main.editor.piece = "box"
	click.call(Vector2(10.04, 3.0)); click.call(Vector2(10.04, 3.0), MOUSE_BUTTON_LEFT, false)
	click.call(Vector2(10.2, 3.0)); click.call(Vector2(10.2, 3.0), MOUSE_BUTTON_LEFT, false)
	var b = main.level_data["blocks"]
	ok("first box on the ground at x snapped to 10.0 (%s)" % [b[0]], b.size() >= 1 and is_equal_approx(b[0]["y"], 0.3) and is_equal_approx(b[0]["x"], 10.0))
	ok("second box stacks on the first (y = %.2f)" % (b[1]["y"] if b.size() > 1 else -1.0), b.size() == 2 and is_equal_approx(b[1]["y"], 0.9))
	main.editor.piece = "pig"
	click.call(Vector2(10.0, 5.0)); click.call(Vector2(10.0, 5.0), MOUSE_BUTTON_LEFT, false)
	ok("pig drops onto the stack (y = %.2f)" % main.level_data["pigs"][0]["y"], is_equal_approx(main.level_data["pigs"][0]["y"], 1.6))
	await frames(2)
	ok("bodies frozen while editing", main.level.get_child(0).freeze)
	# move the top box sideways by dragging
	click.call(Vector2(10.2, 0.9))
	var motion = InputEventMouseMotion.new(); main.editor.handle_input(motion, Vector2(14.0, 0.9))
	click.call(Vector2(14.0, 0.9), MOUSE_BUTTON_LEFT, false)
	ok("dragging moved the box to x = 14, onto the ground (%s)" % [main.level_data["blocks"][1]], is_equal_approx(main.level_data["blocks"][1]["x"], 14.0) and is_equal_approx(main.level_data["blocks"][1]["y"], 0.3))
	click.call(Vector2(14.0, 0.3), MOUSE_BUTTON_RIGHT)
	ok("right-click deleted it", main.level_data["blocks"].size() == 1)
	main.show_topic(5)   # leaving the Editor tab stops editing
	await frames(2)
	ok("leaving the Editor tab unfreezes the pieces", not main.editor.active and not main.level.get_child(0).freeze)
	main.show_topic(6)
	await frames(2)
	# Save / rename / copy / delete
	var store = load("res://levels/level_store.gd")
	levels_panel._name.text = "zz test level"
	levels_panel._task.text = "Test task"
	P.set_value("g", 5.5)
	levels_panel._save()
	ok("saved", store.exists("zz test level"))
	var back = store.read(store.path_for("zz test level"))
	ok("saved file has the pieces, task and settings (g = %s)" % back["launch"]["g"], back["blocks"].size() == 1 and back["pigs"].size() == 1 and back["description"] == "Test task" and is_equal_approx(back["launch"]["g"], 5.5))
	levels_panel._name.text = "zz test level renamed"
	levels_panel._save()
	ok("renaming removes the old file", store.exists("zz test level renamed") and not store.exists("zz test level"))
	levels_panel._copy()
	ok("copy made", store.exists("zz test level renamed (copy)"))
	store.delete("zz test level renamed (copy)")
	ok("copy can be deleted", not store.exists("zz test level renamed (copy)"))
	# export/import round trip
	var path = "user://test_exported_level.json"
	store.write(path, levels_panel._captured("zz exported"))
	var imported = store.read(path)
	ok("export/import round trip", imported["name"] == "zz exported" and imported["pigs"].size() == 1)
	# load the saved level back
	P.set_value("g", 9.81)
	main.load_level(store.read(store.path_for("zz test level renamed")))
	ok("loading a saved level restores its g (%.2f) and banner" % P.values["g"], is_equal_approx(P.values["g"], 5.5) and "Test task" in main.banner.text)
	store.delete("zz test level renamed")
	# multi-pig message
	main.load_level(presets[5])
	await frames(30)
	var pig_nodes = main.get_tree().get_nodes_in_group("pigs")
	pig_nodes[0]._die()
	await frames(2)
	ok("pig counter: '%s'" % main.message.text, "2 to go" in main.message.text)
	print("DONE, fails=%d" % fails)
	quit(fails)
