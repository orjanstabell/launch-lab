extends Problem
## Kinematics, control, TWO unknowns: one bird must hit two pigs, one on a pole
## and one on the ground further away. Two points fix the path completely.


func _init():
	topic = "Kinematics"
	title = "Two pigs, one bird: find v₀ and θ"
	kind = "control"
	answers = [
		{"label": "v₀", "unit": "m/s", "min": 1.0, "max": 40.0, "step": 0.01, "key": "v0"},
		{"label": "θ", "unit": "°", "min": 0.0, "max": 90.0, "step": 0.1, "key": "theta"},
	]
	hidden_keys = ["v0", "theta", "predict"]


func generate() -> bool:
	var g := pick_gravity()
	var y0 := pick(0.0, 4.0, 0.5)
	var near := Vector2(pick(8.0, 20.0, 0.5), pick(1.0, 5.0, 0.5))   # on a pole
	var far := Vector2(near.x + pick(4.0, 14.0, 0.5), 0.0)   # on the ground
	var launch_values := Kinematics.solve_two_points(y0, near, far, g)
	if is_nan(launch_values.x) or launch_values.x < 3.0 or launch_values.x > 38.0 or launch_values.y < 5.0 or launch_values.y > 85.0:
		return false
	launch = {"g": g, "theta": 45.0, "y0": y0, "v0": 15.0, "m": 1.0}
	targets = [near, far]
	correct = [launch_values.x, launch_values.y]
	return true


func question() -> String:
	return "Hit BOTH pigs with one bird: one on a pole at (%s, %s) m, one on the ground at x = %s m.\ng = %s m/s², y₀ = %s m. Find v₀ and θ." % [n(targets[0].x), n(targets[0].y), n(targets[1].x), n(launch["g"]), n(launch["y0"])]


func solution_steps() -> Array[String]:
	var y0: float = launch["y0"]
	var g: float = launch["g"]
	var u := tan(deg_to_rad(correct[1]))
	var k := g * (1.0 + u * u) / (2.0 * correct[0] * correct[0])
	return [
		"Path: y = y₀ + x·u − k·x²,   u = tanθ,   k = g / (2·v₀²·cos²θ)",
		"Pig 1: %s − %s = %s·u − k·%s²" % [n(targets[0].y), n(y0), n(targets[0].x), n(targets[0].x)],
		"Pig 2: %s − %s = %s·u − k·%s²" % [n(targets[1].y), n(y0), n(targets[1].x), n(targets[1].x)],
		"Two equations, two unknowns (u and k) → u = %s,  k = %s" % [n(u, 4), n(k, 5)],
		"θ = atan(u) = %s°,   v₀ = √(g·(1 + u²) / (2·k)) = %s m/s" % [n(correct[1]), n(correct[0])],
		"(If both pigs were at the same x there'd be no solution: one path can't be at two heights at once.)",
	]


func solution_launch() -> LaunchParams:
	return launch_with({"v0": correct[0], "theta": correct[1]})
