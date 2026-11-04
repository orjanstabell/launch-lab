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
func shot(label, unknown_index, high):
	main.reset_level()
	await frames(5)
	main.level.queue_free()   # open air: test the solver, not the hut
	await frames(5)
	var solve = main.find_children("*", "SolvePanel", true, false)[0]
	solve._unknown.select(unknown_index); solve._high_arc.button_pressed = high
	solve._solve()
	print("    ", label, ": ", solve._result.text)
	main.launch()
	var closest := 999.0
	for i in 400:
		await physics_frame
		var b = main.bird
		if is_instance_valid(b) and b.state == 0:
			closest = min(closest, Units.to_m(b.position).distance_to(P.target))
	ok("%s: bird passes through the target (closest %.3f m)" % [label, closest], closest < 0.15)
func run():
	await frames(10)
	P.set_target(Vector2(20.0, 3.0))
	await shot("solve v₀ at θ=45°", 0, false)
	P.set_value("v0", 18.0)
	await shot("solve θ low arc at v₀=18", 1, false)
	await shot("solve θ high arc at v₀=18", 1, true)
	P.set_value("theta", 40.0); P.set_value("v0", 14.0)
	await shot("solve g at v₀=14, θ=40", 2, false)
	print("DONE, fails=%d" % fails)
	quit(fails)
