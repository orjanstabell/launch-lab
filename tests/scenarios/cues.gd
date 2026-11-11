extends SceneTree
## The lecture cues (PageDown walks through them), the open range the game
## starts on, the strobe dots on the trail, and the miss measured in meters.
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
## One press of PageDown (true) or PageUp, never mistaken for a double press.
func key(forward := true):
	main._cue_key_ms = -100000
	main.cue_key(forward)
## Wait (at most `seconds`) until the loaded cue has shown its reveal.
func until_revealed(seconds := 12.0):
	for i in int(seconds * 60):
		if main.cue_stage == main.CueStage.REVEALED: return
		await physics_frame
func run():
	await frames(10)
	var presets = load("res://levels/level_presets.gd")
	var cues = presets.cues()
	ok("the game opens on an empty range, with no cue loaded", main.level.get_child_count() == 0 and main.level_data["name"] == "Open range" and main.cue_index == -1 and not main.cue_big.visible)

	# Cue 1: mass. Asked with the future hidden; PageDown flies it; the landing reveals it.
	key()
	await frames(2)
	ok("PageDown loads the first cue: question shown big, prediction hidden ('%s')" % main.cue_big.text, main.cue_index == 0 and main.cue_big.visible and main.cue_big.text == cues[0]["question"] and main.cue_small.text == cues[0]["options"] and R.is_hidden("predict") and is_equal_approx(P.values["m"], 5.0))
	main.cue_key(true)   # (no reset of the debounce: this is a clicker's double press)
	await frames(2)
	ok("a double press doesn't fly it", not P.is_flying() and main.cue_stage == main.CueStage.ASKED)
	key()
	await frames(5)
	ok("PageDown flies it: the question moves out of the arc's way", P.is_flying() and main.cue_stage == main.CueStage.FLOWN and not main.cue_big.visible and main.level_title.text == cues[0]["question"])
	key()
	await frames(2)
	ok("PageDown mid-flight doesn't wipe the shot", P.is_flying() and main.cue_index == 0)
	await until_revealed()
	await frames(40)
	ok("after the landing: the reveal line, the prediction back, the can down ('%s' / '%s')" % [main.cue_big.text, main.message.text], main.cue_big.text.begins_with("B.") and not R.is_hidden("predict") and main.message.text.begins_with("All down in 1 shot."))
	var stamps: Array = main.bird.trail._stamps
	var gaps := []
	for i in range(1, stamps.size()): gaps.append(stamps[i]["point"].x - stamps[i - 1]["point"].x)
	ok("the trail has a strobe dot every 0.1 s (%d dots), evenly spaced sideways" % stamps.size(), stamps.size() >= 20 and gaps.max() - gaps.min() < 0.01)
	key(false)
	await frames(2)
	ok("PageUp asks the same cue again", main.cue_index == 0 and main.cue_stage == main.CueStage.ASKED and R.is_hidden("predict") and main.get_tree().get_nodes_in_group("pigs").size() == 1)

	# Cue 2: the shot freezes itself at the exact top of the arc.
	main.load_level(cues[1])
	key()
	await until_revealed()
	var b = main.bird
	ok("the apex cue stops itself at the top (vy = %.6f m/s, vx = %.2f) and reveals" % [b.velocity_m().y, b.velocity_m().x], paused and absf(b.velocity_m().y) < 1e-6 and b.velocity_m().x > 7.0 and main.cue_big.text.begins_with("B."))
	key()
	await frames(3)
	ok("PageDown carries on from the stop", not paused and P.is_flying() and main.cue_index == 1)
	await frames(200)
	key()
	await frames(2)
	ok("the next PageDown loads the next cue", main.cue_index == 2 and main.cue_stage == main.CueStage.ASKED)

	# Cue 3: 60° from the ground reaches the same can as 30°.
	key()
	await until_revealed()
	await frames(40)
	ok("two angles: 60° knocks the can down ('%s')" % main.message.text, main.message.text.begins_with("All down"))
	P.set_value("theta", 30.0)
	main.launch()
	await frames(150)
	ok("...and so does 30°, set by hand afterwards", main.get_tree().get_nodes_in_group("pigs").size() == 0)

	# Cue 4: gravity switches off by itself, where the ring says.
	main.load_level(cues[3])
	ok("the gravity cue shows where it will switch off", not main.shot_marks._ring.is_empty())
	key()
	await until_revealed()
	b = main.bird
	stamps = b.trail._stamps
	var last: Vector2 = stamps[-1]["point"] - stamps[-2]["point"]
	var before: Vector2 = stamps[-2]["point"] - stamps[-3]["point"]
	ok("gravity is off (g = %s) and the last strobe gaps are equal: a straight line at steady speed" % b.segment.g, b.segment.g == 0.0 and b.activations == 1 and last.distance_to(before) < 0.01 and main.cue_big.text.begins_with("C."))
	key()
	await frames(2)
	ok("PageDown moves on although that shot never lands", main.cue_index == 4)

	# Cue 5: the split fires by itself at the top.
	key()
	await until_revealed()
	b = main.bird
	ok("the split cue splits at the top (%d pieces at vy = %.3f)" % [b.pieces.size(), b.pre_split.v0 * sin(deg_to_rad(b.pre_split.theta_deg)) - b.pre_split.g * b.split_t], b.pieces.size() == 3 and absf(b.pre_split.v0 * sin(deg_to_rad(b.pre_split.theta_deg)) - b.pre_split.g * b.split_t) < 1e-6)

	# Cue 6: g stays hidden until the class has worked it out.
	main.load_level(cues[5])
	key()
	await frames(300)
	ok("the planet cue waits after the landing: g still hidden", main.cue_stage == main.CueStage.FLOWN and R.is_hidden("g") and not P.is_flying())
	key()
	await frames(2)
	ok("PageDown reveals it ('%s')" % main.cue_big.text, main.cue_stage == main.CueStage.REVEALED and "3.71" in main.cue_big.text and not R.is_hidden("g"))
	key()
	await frames(2)
	ok("after the last cue, PageDown goes back to the open range", main.cue_index == -1 and main.level_data["name"] == "Open range" and not main.cue_big.visible)

	# The miss, in meters: the default shot lands about 11 m short of a can at 35 m.
	var far = load("res://levels/level.gd").blank("far can")
	load("res://levels/level.gd").add_pig(far, Vector2(35.0, 0.4))
	main.load_level(far)
	await frames(40)
	main.launch()
	await frames(240)
	ok("a shot that lands without hitting is measured ('%s')" % main.message.text, main.message.text.begins_with("Missed by 11") and "landed short of the can" in main.message.text and not main.shot_marks._tape.is_empty())
	P.set_value("v0", load("res://physics/kinematics.gd").solve_speed(45.0, 9.81, 1.0, Vector2(35.0, 0.4)))
	main.launch()
	await frames(300)
	ok("the second shot hits, and the shots are counted ('%s')" % main.message.text, main.message.text.begins_with("All down in 2 shots."))
	main.reset_level()
	ok("resetting clears the tape and the shot count", main.shot_marks._tape.is_empty() and main.shots == 0)
	print("DONE, fails=%d" % fails)
	quit()
