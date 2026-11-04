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
func screen_of(meters: Vector2) -> Vector2:
	return root.get_canvas_transform() * main.world.to_global(Vector2(meters.x, -meters.y) * 50.0)
func mouse(pos: Vector2, button := -1, pressed := false):
	var ev
	if button < 0:
		ev = InputEventMouseMotion.new()
	else:
		ev = InputEventMouseButton.new(); ev.button_index = button; ev.pressed = pressed
	ev.position = pos; ev.global_position = pos
	main._unhandled_input(ev)   # (headless window is 64×64, so push_input would rescale)
## A key press and release through the GUI, so a focused text box gets it first.
func key(code: Key, character: String):
	var ev := InputEventKey.new()
	ev.keycode = code; ev.unicode = character.unicode_at(0); ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate(); up.pressed = false
	Input.parse_input_event(up)
func run():
	await frames(20)
	P.set_launch_mode("spring")
	ok("default spring: v₀ = 0.75·√(400/1) = 15 (got %.3f)" % P.values["v0"], is_equal_approx(P.values["v0"], 15.0))
	P.set_value("m", 4.0)
	ok("4× the mass → half the speed: v₀ = %.3f" % P.values["v0"], is_equal_approx(P.values["v0"], 7.5))
	P.set_value("m", 1.0)
	P.set_spring_value("pull", 1.0)
	ok("pull 1 m → v₀ = 20 (got %.3f)" % P.values["v0"], is_equal_approx(P.values["v0"], 20.0))
	main.launch(); await frames(2)
	ok("bird launches with the spring's speed", is_equal_approx(main.bird.segment.v0, 20.0))
	main.reset_level(); await frames(30)
	# Drag: grab the waiting bird, pull down-left, let go
	var bird_at = Vector2(0, P.values["y0"]) + main.slingshot.pulled_back()
	mouse(screen_of(bird_at), MOUSE_BUTTON_LEFT, true)
	await frames(2)
	ok("clicking the waiting bird grabs it", main.dragging)
	var pull_to = Vector2(0, P.values["y0"]) + Vector2(-1.0, -1.0) * 0.9   # 1.27 m back at 45°
	mouse(screen_of(pull_to))
	await frames(2)
	ok("dragging sets θ = 45° (got %.1f) and Δx = 1.27 m (got %.2f)" % [P.values["theta"], P.spring["pull"]], absf(P.values["theta"] - 45.0) < 1.0 and absf(P.spring["pull"] - 1.273) < 0.05)
	mouse(screen_of(pull_to), MOUSE_BUTTON_LEFT, false)
	await frames(3)
	ok("letting go launches the bird", is_instance_valid(main.bird) and main.bird.state == 0 and not main.dragging)
	# Speed mode drag
	P.set_launch_mode("speed"); main.reset_level(); await frames(30)
	mouse(screen_of(Vector2(0, P.values["y0"])), MOUSE_BUTTON_LEFT, true)
	mouse(screen_of(Vector2(-2.0, P.values["y0"] - 0.0)))
	await frames(2)
	ok("speed mode: full pull straight back → θ = 0, v₀ = 40 (got θ %.1f, v₀ %.1f)" % [P.values["theta"], P.values["v0"]], P.values["theta"] < 0.5 and P.values["v0"] > 39.0)
	mouse(screen_of(Vector2(-2.0, 0)), MOUSE_BUTTON_LEFT, false)
	await frames(2)
	P.set_inputs_locked(true, false); main.reset_level(); await frames(5)
	mouse(screen_of(Vector2(0, P.values["y0"])), MOUSE_BUTTON_LEFT, true)
	await frames(2)
	ok("no grabbing while a practice problem locks things", not main.dragging)
	# Type a speed, then click the sky: the value is applied and Space launches again
	# (the number box used to keep the keyboard, so Space typed a space into it).
	P.set_inputs_locked(false); main.reset_level(); await frames(5)
	var speed_box: LineEdit = main.find_children("*", "ParamPanel", true, false)[0]._rows["v0"]["spin"].get_line_edit()
	speed_box.grab_focus(); await frames(1)
	speed_box.select_all()
	for i in 2:
		key(KEY_2, "2"); await frames(1)
	mouse(screen_of(Vector2(10, 8)), MOUSE_BUTTON_LEFT, true)
	mouse(screen_of(Vector2(10, 8)), MOUSE_BUTTON_LEFT, false)
	await frames(2)
	key(KEY_SPACE, " "); await frames(2)
	ok("typed v₀ = 22 and clicked the sky: applied (v₀ = %.1f) and Space launches" % P.values["v0"], is_equal_approx(P.values["v0"], 22.0) and P.is_flying())
	print("DONE, fails=%d" % fails)
	quit(fails)
