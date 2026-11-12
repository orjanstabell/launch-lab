extends SceneTree
var main
var P
var fails := 0
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.level_data = load("res://levels/level_presets.gd").tower()   # (the game itself opens on an empty range)
	P = root.get_node("PhysicsParams")
	run()
func frames(n):
	for i in n: await physics_frame
func ok(name, cond):
	if not cond: fails += 1
	print(("  ok    " if cond else "  FAIL  ") + name)
func big_pig():
	for p in main.get_tree().get_nodes_in_group("pigs"):
		if p.big: return p
	return null
func shoot_big(v0):
	var pig = big_pig()
	var at = pig.position / 50.0; at.y = -at.y
	P.set_value("theta", 30.0)
	var K = load("res://physics/kinematics.gd")
	P.set_value("v0", K.solve_speed(30.0, P.values["g"], P.values["y0"], at) if v0 <= 0 else v0)
	main.launch()
	await frames(240)
func run():
	await frames(30)
	ok("default Tower has a small and a big pig (big = 3 kg)", main.get_tree().get_nodes_in_group("pigs").size() == 2 and big_pig() != null and is_equal_approx(big_pig().mass, 3.0))
	# Just the big pig, in the open, so nothing else gets hit first
	var L = load("res://levels/level.gd")
	var level = L.blank("big pig test")
	L.add_pig(level, Vector2(20.0, 0.6), true)
	main.load_level(level)
	await frames(60)
	await shoot_big(0.0)
	var pig = big_pig()
	ok("first hit: the big pig survives with a bandage (hits_left %s)" % (pig.hits_left if pig else "gone"), pig != null and pig.hits_left == 1)
	ok("the hit was recorded on both: J on pig %.2f, J on bird %.2f" % [(P.collision["other_m"] * (P.collision["other_after"] - P.collision["other_before"])).length(), (P.collision["bird_m"] * (P.collision["bird_after"] - P.collision["bird_before"])).length()], P.collision.get("other_name") == "big dummy" and P.collision.has("duration"))
	await frames(60)
	await shoot_big(0.0)
	ok("second hit finishes it", big_pig() == null)
	# heavy pig: set mass through the Levels tab
	var panel = main.topics[5].editor_panel
	panel._big_pig_mass.value = 40.0
	print("      level_data pigs after setting: %s   status: %s" % [main.level_data["pigs"], panel._status.text])
	await frames(60)
	print("      pigs in scene: %s" % [main.get_tree().get_nodes_in_group("pigs").map(func(p): return [p.big, p.mass])])
	ok("big pig mass set to 40 kg from the Levels tab", big_pig() != null and is_equal_approx(big_pig().mass, 40.0))
	# drop test: a heavy pig falling must not die from gravity alone
	var heavy = big_pig()
	heavy.position.y -= 50   # lift it 1 m: it falls freely for a while
	await frames(20)
	ok("a 40 kg pig in free fall isn't hurt by gravity alone (hits_left %d)" % heavy.hits_left, is_instance_valid(heavy) and heavy.hits_left == 2)
	print("DONE, fails=%d" % fails)
	quit(fails)
