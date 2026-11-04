extends Problem
## Kinematics, control: choose θ so the bird hits the target. Usually two
## angles work (a low and a high arc); either counts.


func _init():
	topic = "Kinematics"
	title = "Hit the target: find θ"
	kind = "control"
	answers = [{"label": "θ", "unit": "°", "min": 0.0, "max": 90.0, "step": 0.1, "key": "theta"}]
	hidden_keys = ["theta", "predict"]


func generate() -> bool:
	var g := pick_gravity()
	var v0 := pick(12.0, 30.0, 0.5)
	var y0 := 0.0 if rng.randf() < 0.5 else pick(0.5, 3.0, 0.5)
	var target := Vector2(pick(12.0, 32.0, 0.5), pick(0.0, 4.0, 0.5))
	var angles := Kinematics.solve_angles(v0, g, y0, target)
	if angles.is_empty() or angles[0] < 5.0 or angles[0] > 85.0:
		return false
	launch = {"g": g, "theta": 45.0, "y0": y0, "v0": v0, "m": 1.0}
	targets = [target]
	correct = angles
	return true


func question() -> String:
	return "Hit the target at x = %s m, y = %s m.\ng = %s m/s², v₀ = %s m/s, y₀ = %s m. At what angle θ? (Two angles work.)" % [n(targets[0].x), n(targets[0].y), n(launch["g"]), n(launch["v0"]), n(launch["y0"])]


func solution_steps() -> Array[String]:
	var g: float = launch["g"]
	var v0: float = launch["v0"]
	var drop: float = launch["y0"] - targets[0].y
	var a := g * targets[0].x * targets[0].x / (2.0 * v0 * v0)
	var u_low := tan(deg_to_rad(correct[0]))
	var u_high := tan(deg_to_rad(correct[1]))
	return [
		"With u = tanθ, the path through the target becomes a quadratic:",
		"a·u² − X·u + (a − D) = 0,   a = g·X²/(2·v₀²),   D = y₀ − Y",
		"a = %s·%s² / (2·%s²) = %s,   D = %s" % [n(g), n(targets[0].x), n(v0), n(a), n(drop)],
		"u = (X ± √(X² − 4·a·(a − D))) / (2·a) = %s or %s" % [n(u_low, 3), n(u_high, 3)],
		"θ = atan(u) = %s° (low arc) or %s° (high arc)" % [n(correct[0]), n(correct[1])],
	]


func solution_launch() -> LaunchParams:
	return launch_with({"theta": correct[0]})
