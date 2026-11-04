extends SceneTree
## Pausing freezes everything (the rocket's exhaust too), resetting the level
## unpauses, pigs get arrows in Forces and Motion, the action cam keeps drawing a
## pig the hit knocked out, and every button and checkbox has a tooltip.
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
## The class_name of a node's script. (Naming the classes here directly would
## compile them before the autoloads exist.)
func kind(node) -> String:
	return String(node.get_script().get_global_name())
func run():
	await frames(10)
	var controls = main.find_children("*", "SimControls", true, false)[0]

	# Rocket exhaust freezes with the rest of the world
	main.show_topic(0)
	P.set_bird_type("rocket")
	P.request_reset()
	P.request_launch()
	main.bird.activate_at = 0.3
	await frames(40)
	var exhaust = main.bird.exhaust
	ok("the rocket fired and puffs out exhaust", exhaust != null and exhaust.puffs.size() > 3)
	controls.toggle_pause()
	await frames(2)
	var time_before: float = exhaust._time
	var puff_before: Vector2 = exhaust.puff_position(exhaust.puffs[0])
	var bird_before: Vector2 = main.bird.position
	await frames(30)
	ok("paused: the bird and its exhaust both hold still", is_equal_approx(exhaust._time, time_before) and exhaust.puff_position(exhaust.puffs[0]) == puff_before and main.bird.position == bird_before)
	var motion_overlays = main.topics[0].overlays
	ok("Motion topic has exhaust and pig arrows", motion_overlays.any(func(o): return kind(o) == "ExhaustOverlay") and motion_overlays.any(func(o): return kind(o) == "PigOverlay"))
	ok("the Pause button says Resume", controls._pause_button.text == "Resume")

	# Resetting the level unpauses
	main.reset_level()
	await process_frame
	await process_frame
	ok("reset unpauses", not paused)
	ok("the Pause button follows", controls._pause_button.text == "Pause")

	# Pig arrows in Forces: a resting pig's contact force holds it up (≈ m·g)
	P.set_bird_type("red")
	main.show_topic(1)
	main.reset_level()
	await frames(90)
	var pig_overlay = null
	for o in main.topics[1].overlays:
		if kind(o) == "PigOverlay": pig_overlay = o
	var pig = get_nodes_in_group("all_pigs")[0]
	var held: Vector2 = pig_overlay._contact.get(pig, Vector2.ZERO)
	var weight: float = pig.mass * P.world_gravity()
	ok("Forces: resting pig's contact force ≈ m·g up (%.2f N vs %.2f N)" % [held.y, weight], pig_overlay.visible and absf(held.y - weight) < 0.1 * weight and absf(held.x) < 0.1 * weight)

	# Action cam: a pig knocked out by the hit is still drawn (it fades first)
	var cam = main.action_overlay
	var dying = get_nodes_in_group("pigs")[0]
	cam.pig = dying
	dying.take_impulse(100.0)
	await frames(3)
	ok("a knocked-out pig leaves 'pigs' but stays in 'all_pigs' while it fades", not dying.is_in_group("pigs") and dying.is_in_group("all_pigs"))
	var drawn := false
	for line in FileAccess.get_file_as_string("res://scenes/action_cam_overlay.gd").split("\n"):
		if "is_in_group(\"pigs\")" in line: drawn = true
	ok("the action cam no longer skips pigs that left the 'pigs' group", not drawn)

	# Tooltips on every button and checkbox
	var missing := []
	for node in main.find_children("*", "BaseButton", true, false):
		if node.get_parent() is SpinBox or node.get_parent() is PopupMenu:
			continue
		if node.tooltip_text == "":
			missing.append("%s '%s'" % [node.get_class(), node.text if "text" in node else ""])
	ok("every button and checkbox has a tooltip (missing: %s)" % ", ".join(missing), missing.is_empty())
	print("DONE, fails=%d" % fails)
	quit(fails)
