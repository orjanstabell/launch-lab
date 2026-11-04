extends Problem
## Energy + kinematics, control: how far must you pull the spring to hit the pig?


func _init():
	topic = "Energy"
	title = "Spring slingshot: pull to hit the pig"
	kind = "control"
	answers = [{"label": "Δx", "unit": "m", "min": 0.05, "max": 2.0, "step": 0.01, "key": "pull"}]
	hidden_keys = ["pull", "v0", "predict"]


func generate() -> bool:
	var g := pick_gravity()
	var theta := pick(25.0, 65.0, 1.0)
	var mass := pick(0.5, 3.0, 0.1)
	var k := pick(200.0, 1500.0, 10.0)
	var y0 := 0.0 if rng.randf() < 0.5 else pick(0.5, 2.0, 0.5)
	var target := Vector2(pick(12.0, 32.0, 0.5), pick(0.0, 4.0, 0.5))
	var v0 := Kinematics.solve_speed(theta, g, y0, target)
	if is_nan(v0):
		return false
	var pull := v0 * sqrt(mass / k)
	if pull < 0.1 or pull > 1.9:
		return false
	launch = {"mode": "spring", "k": k, "pull": 0.5, "m": mass, "g": g, "theta": theta, "y0": y0}
	targets = [target]
	correct = [pull]
	return true


func question() -> String:
	return "Spring k = %s N/m, bird m = %s kg, θ = %s°, g = %s m/s², y₀ = %s m.\nHow far back (Δx) must you pull to hit the pig at (%s, %s) m?" % [n(launch["k"]), n(launch["m"]), n(launch["theta"]), n(launch["g"]), n(launch["y0"]), n(targets[0].x), n(targets[0].y)]


func solution_steps() -> Array[String]:
	var v0 := correct[0] * sqrt(launch["k"] / launch["m"])
	return [
		"1) The speed that hits the pig (kinematics):",
		"   v₀² = g·X² / (2·cos²θ·(y₀ − Y + X·tanθ))  →  v₀ = %s m/s" % n(v0),
		"2) The pull that gives that speed (energy): ½·k·Δx² = ½·m·v₀²",
		"   Δx = v₀·√(m/k) = %s·√(%s/%s) = %s m" % [n(v0), n(launch["m"]), n(launch["k"]), n(correct[0])],
	]


func solution_launch() -> LaunchParams:
	return launch_with({"pull": correct[0]})
