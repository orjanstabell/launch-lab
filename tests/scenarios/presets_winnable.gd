extends SceneTree
## For each preset: plan a shot with the solvers (a clear path to the pig),
## then fly it for real in the level and check that the pig(s) go down.
var main
var P
var K
var fails := 0
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	P = root.get_node("PhysicsParams")
	K = load("res://physics/kinematics.gd")
	run()
func frames(n):
	for i in n: await physics_frame
func pigs_left():
	return main.get_tree().get_nodes_in_group("pigs").size()
func path_clear(preset, theta, v0, target):
	var p = P.launch_params(); p.theta_deg = theta; p.v0 = v0
	var t_end = K.closest_approach(p, target).x
	for i in int(t_end / 0.01):
		var at = K.position(p, i * 0.01)
		for b in preset["blocks"]:
			if absf(at.x - b["x"]) < b["w"] / 2.0 + 0.35 and absf(at.y - b["y"]) < b["h"] / 2.0 + 0.35:
				return false
	return true
## Does the egg's path reach the pig without clipping a block on the way?
func egg_path_clear(path, until):
	for i in int(until / 0.005):
		var q = K.position(path, i * 0.005)
		for block in main.level_data["blocks"]:
			if absf(q.x - block["x"]) < block["w"] / 2.0 + 0.2 and absf(q.y - block["y"]) < block["h"] / 2.0 + 0.2:
				return false
	return true


func fly(theta, v0, tap):
	P.set_value("theta", theta)
	if P.launch_mode == "spring": P.set_spring_value("pull", v0 * sqrt(P.values["m"] / P.spring["k"]))
	else: P.set_value("v0", v0)
	main.launch()
	main.bird.activate_at = tap if tap >= 0.0 else INF
	var target = main.get_tree().get_nodes_in_group("pigs")[0]
	for i in 600:
		await physics_frame
		if tap < 0.0 and is_instance_valid(main.bird) and P.can_activate() and is_instance_valid(target):   # Matilda's egg
			var at = Vector2(target.position.x, -target.position.y) / 50.0
			var egg_path = main.bird.preview_segments()[1]
			var close = K.closest_approach(egg_path, at)
			if close.y < 0.4 and egg_path_clear(egg_path, close.x):
				P.activate()
		if pigs_left() == 0: break
func run():
	await frames(5)
	for preset in load("res://levels/level_presets.gd").all():
		main.load_level(preset)
		await frames(30)
		var total = pigs_left()
		var shots := 0
		# Fire at the remaining pigs one by one (a big pig needs two hits).
		while pigs_left() > 0 and shots < 6:
			shots += 1
			var pig_node = main.get_tree().get_nodes_in_group("pigs")[0]
			var pig = Vector2(pig_node.position.x, -pig_node.position.y) / 50.0
			var plan = []
			var tap = INF
			if preset.get("bird_type", "") == "custom":   # yellow: launch as given, tap at the formula's time
				var p = P.launch_params()
				var v = K.initial_velocity(p)
				var a = 0.5 * p.g * v.x; var b = -p.g * pig.x; var c = pig.x * v.y - (pig.y - p.y0) * v.x
				plan = [p.theta_deg, p.v0]; tap = (-b - sqrt(b * b - 4 * a * c)) / (2 * a)
			elif preset.get("bird_type", "") == "matilda":   # fly over, drop the egg when its path crosses the pig
				var above = pig + Vector2(0.0, 6.0)
				plan = [50.0, K.solve_speed(50.0, 9.81, 0.0, above)]
				tap = -1.0
			elif preset.get("bird_type", "") == "blue":   # a shot an earlier search showed clears all three
				var middle = Vector2(preset["pigs"][1]["x"], preset["pigs"][1]["y"])
				plan = [40.0, K.solve_speed(40.0, 9.81, 0.0, middle)]
				var p = P.launch_params(); p.theta_deg = plan[0]; p.v0 = plan[1]
				tap = K.closest_approach(p, middle).x * 0.5
			else:
				for theta in range(10, 82, 2):
					var v0 = K.solve_speed(float(theta), P.values["g"], P.values["y0"], pig)
					if not is_nan(v0) and v0 < 38.0 and path_clear(preset, float(theta), v0, pig):
						plan = [float(theta), v0]; break
			if plan.is_empty():
				break
			await fly(plan[0], plan[1], tap)
			await frames(30)
		var down = total - pigs_left()
		var won = pigs_left() == 0
		if not won: fails += 1
		print(("  ok    " if won else "  FAIL  ") + "%s: %d/%d pigs down in %d shot(s)" % [preset["name"], down, total, shots])
	print("DONE, fails=%d" % fails)
	quit(fails)
