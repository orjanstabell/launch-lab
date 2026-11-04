extends Problem
## Kinematics, control: choose v₀ so the bird hits the target. θ, g and y₀ are given.


func _init():
	topic = "Kinematics"
	title = "Hit the target: find v₀"
	kind = "control"
	answers = [{"label": "v₀", "unit": "m/s", "min": 1.0, "max": 40.0, "step": 0.01, "key": "v0"}]
	hidden_keys = ["v0", "predict"]


func generate() -> bool:
	var g := pick_gravity()
	var theta := pick(25.0, 65.0, 1.0)
	var y0 := 0.0 if rng.randf() < 0.5 else pick(0.5, 3.0, 0.5)
	var target := Vector2(pick(12.0, 32.0, 0.5), pick(0.0, 4.0, 0.5))
	var v0 := Kinematics.solve_speed(theta, g, y0, target)
	if is_nan(v0) or v0 < 3.0 or v0 > 38.0:
		return false
	launch = {"g": g, "theta": theta, "y0": y0, "v0": 15.0, "m": 1.0}
	targets = [target]
	correct = [v0]
	return true


func question() -> String:
	return "Hit the target at x = %s m, y = %s m.\ng = %s m/s², θ = %s°, y₀ = %s m. What launch speed v₀ do you need?" % [n(targets[0].x), n(targets[0].y), n(launch["g"]), n(launch["theta"]), n(launch["y0"])]


func solution_steps() -> Array[String]:
	var g: float = launch["g"]
	var theta: float = launch["theta"]
	var y0: float = launch["y0"]
	var v0 := correct[0]
	return [
		"The path:  y = y₀ + x·tanθ − g·x² / (2·v₀²·cos²θ)",
		"At the target x = X, y = Y. Solve for v₀:",
		"v₀² = g·X² / (2·cos²θ·(y₀ − Y + X·tanθ))",
		"    = %s·%s² / (2·cos²%s°·(%s − %s + %s·tan %s°))" % [n(g), n(targets[0].x), n(theta), n(y0), n(targets[0].y), n(targets[0].x), n(theta)],
		"    = %s m²/s²" % n(v0 * v0),
		"v₀ = %s m/s" % n(v0),
	]


func solution_launch() -> LaunchParams:
	return launch_with({"v0": correct[0]})
