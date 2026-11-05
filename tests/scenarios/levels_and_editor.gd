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
	ok("a seed always gives the same random level", load("res://levels/level_generator.gd").generate(7) == load("res://levels/level_generator.gd").generate(7) and not load("res://levels/level_generator.gd").generate(7)["pigs"].is_empty())
	for preset in presets + [load("res://levels/level_generator.gd").generate(1), load("res://levels/level_generator.gd").generate(2), load("res://levels/level_generator.gd").generate(3), load("res://levels/level_generator.gd").generate(5), load("res://levels/level_generator.gd").generate(6)]:
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
	var levels_panel = main.topics[5].editor_panel
	main.show_topic(5)
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
	main.show_topic(4)   # leaving the Editor tab stops editing
	await frames(2)
	ok("leaving the Editor tab unfreezes the pieces", not main.editor.active and not main.level.get_child(0).freeze)
	main.show_topic(5)
	await frames(2)
	# Save / rename / copy / delete
	var store = load("res://levels/level_store.gd")
	for file in DirAccess.get_files_at(store.FOLDER):   # leftovers from a run that failed half-way
		if file.begins_with("zz_"):
			DirAccess.remove_absolute(store.FOLDER + file)
	levels_panel._name.text = "zz test level"
	levels_panel._task.text = "Test task"
	P.set_value("g", 5.5)
	P.set_rocket_value("fuel", 2.0)
	levels_panel._save()
	ok("saved", store.exists("zz test level"))
	var back = store.read(store.path_for("zz test level"))
	ok("saved file has the pieces, task and settings (g = %s)" % back["launch"]["g"], back["blocks"].size() == 1 and back["pigs"].size() == 1 and back["description"] == "Test task" and is_equal_approx(back["launch"]["g"], 5.5))
	levels_panel._name.text = "zz test level renamed"
	levels_panel._save()
	ok("renaming removes the old file", store.exists("zz test level renamed") and not store.exists("zz test level"))
	# A new level can't take an existing level's file (same name up to case/punctuation)
	levels_panel._loaded_name = ""   # as if this were a new level that was never saved
	levels_panel._name.text = "ZZ Test Level Renamed"
	levels_panel._task.text = "Other task"
	levels_panel._save()
	ok("saving a new level under a taken name is refused (%s)" % levels_panel._status.text,
		"already taken" in levels_panel._status.text and store.read(store.path_for("zz test level renamed"))["description"] == "Test task")
	ok("a write that can't happen reports false", not store.write("user://no_such_folder/x.json", {}))
	levels_panel._copy()
	ok("copy made", store.exists("zz test level renamed (copy)"))
	store.delete("zz test level renamed (copy)")
	ok("copy can be deleted", not store.exists("zz test level renamed (copy)"))
	# export/import round trip
	var path = "user://test_exported_level.json"
	store.write(path, levels_panel._captured("zz exported"))
	var imported = store.read(path)
	DirAccess.remove_absolute(path)
	ok("export/import round trip", imported["name"] == "zz exported" and imported["pigs"].size() == 1)
	# Importing a level whose name is taken saves it as a copy, never over the saved one
	var import_panel = main.topics[4].levels_panel
	var clash = store.read(store.path_for("zz test level renamed"))
	clash["description"] = "Imported task"
	import_panel._import_level(clash)
	ok("import under a taken name keeps the saved level and adds a copy (%s)" % import_panel._status.text,
		store.read(store.path_for("zz test level renamed"))["description"] == "Test task"
		and store.read(store.path_for("zz test level renamed (copy)"))["description"] == "Imported task")
	store.delete("zz test level renamed (copy)")
	# A broken or hand-edited file: the bad parts are skipped, the rest loads
	var broken_path = "user://test_broken_level.json"
	var broken := FileAccess.open(broken_path, FileAccess.WRITE)
	broken.store_string(JSON.stringify({"name": "zz broken", "topic": "two", "hidden": "g",
		"blocks": [{"x": 20.0, "y": 0.5, "w": 1.0, "h": 1.0}, {"x": 22.0, "y": 0.5}, "not a block"],
		"pigs": [{"x": 20.0, "y": 1.4}, {"x": 23.0, "y": 0.4, "big": "yes"}],
		"bird_type": "bomb", "launch_mode": "rubber band", "launch": {"v0": "fast", "theta": 30.0},
		"spring": {"q": 3.0}, "ability_on": {"wings": true, "g": "yes"}, "split": {"pieces": 1}, "target": "over there"}))
	broken.close()
	var bird_before: String = P.bird_type
	var sane = store.read(broken_path)
	DirAccess.remove_absolute(broken_path)
	main.load_level(sane)
	await frames(5)
	ok("broken file: only the good block and pig load (%d, %d), bad settings skipped" % [main.level.get_child_count(), sane["pigs"].size()],
		sane["blocks"].size() == 1 and sane["pigs"].size() == 1 and P.bird_type == bird_before and P.launch_mode == "speed" and is_equal_approx(P.values["theta"], 30.0) and P.split["pieces"] >= 2 and main.current_topic == 0)
	# Version 1 files had separate Forces and Momentum tabs: they still open on the same tab
	var v1 = func(topic): return store.parse(JSON.stringify({"name": "zz old", "version": 1, "topic": topic, "blocks": [], "pigs": []}))
	var unversioned = store.parse(JSON.stringify({"name": "zz old", "topic": 4, "blocks": [], "pigs": []}))
	var current = store.parse(JSON.stringify({"name": "zz new", "version": 2, "topic": 2, "blocks": [], "pigs": []}))
	ok("version 1 levels open on the same tab (Forces %s, Momentum %s, Energy %s, Practice %s → 1, 1, 2, 3); version 2 keeps %s" % [v1.call(1)["topic"], v1.call(2)["topic"], v1.call(3)["topic"], unversioned["topic"], current["topic"]],
		v1.call(1)["topic"] == 1 and v1.call(2)["topic"] == 1 and v1.call(3)["topic"] == 2 and unversioned["topic"] == 3 and current["topic"] == 2 and v1.call(2)["version"] == 2)
	# load the saved level back
	P.set_value("g", 9.81)
	P.set_rocket_value("fuel", 0.5)
	main.load_level(store.read(store.path_for("zz test level renamed")))
	ok("loading a saved level restores its g (%.2f), rocket fuel (%.2f) and banner" % [P.values["g"], P.rocket["fuel"]],
		is_equal_approx(P.values["g"], 5.5) and is_equal_approx(P.rocket["fuel"], 2.0) and "Test task" in main.banner.text)
	# Deleting in the Levels tab takes a second click (there's no undo)
	import_panel.refresh("zz test level renamed")
	import_panel._delete_selected()
	var kept_after_one: bool = store.exists("zz test level renamed") and "again" in import_panel._status.text
	import_panel._delete_selected()
	ok("Delete asks first, the second click deletes", kept_after_one and not store.exists("zz test level renamed"))
	# multi-pig message
	main.load_level(presets[5])
	await frames(30)
	var pig_nodes = main.get_tree().get_nodes_in_group("pigs")
	pig_nodes[0]._die()
	await frames(2)
	ok("pig counter: '%s'" % main.message.text, "2 to go" in main.message.text)
	print("DONE, fails=%d" % fails)
	quit(fails)
