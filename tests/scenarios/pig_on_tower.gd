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
## The small pig on the tower (the level also has a big pig on the ground).
func pig_alive():
	for pig in main.get_tree().get_nodes_in_group("pigs"):
		if not pig.big:
			return true
	return false
func run():
	await frames(120)
	ok("pig rests on the tower without dying", pig_alive())
	var solve = main.find_children("*", "SolvePanel", true, false)[0]
	for case in [[0, false, "v₀"], [1, false, "θ low"], [1, true, "θ high"]]:
		main.reset_level(); P.set_value("v0", 18.0); P.set_value("theta", 45.0)
		await frames(60)
		solve._unknown.select(case[0]); solve._high_arc.button_pressed = case[1]; solve._solve()
		main.launch()
		await frames(300)
		ok("solve %s (%s) then launch: pig down" % [case[2], solve._result.text], not pig_alive())
	print("DONE, fails=%d" % fails)
	quit(fails)
