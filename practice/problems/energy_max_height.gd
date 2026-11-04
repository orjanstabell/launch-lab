extends Problem
## Energy, predict: how high does it go? Solved with energy instead of time.


func _init():
	topic = "Energy"
	title = "Energy: how high does it go?"
	answers = [{"label": "highest y", "unit": "m", "min": 0.0, "max": 100.0, "step": 0.01}]
	hidden_keys = ["predict", "y", "E"]


func generate() -> bool:
	var theta := 90.0 if rng.randf() < 0.3 else pick(30.0, 80.0, 1.0)   # sometimes straight up
	launch = {"g": pick_gravity(), "theta": theta, "y0": pick(0.0, 4.0, 0.5), "v0": pick(6.0, 18.0, 0.5), "m": pick(0.5, 3.0, 0.1)}
	var top := Kinematics.apex_height(launch_with())
	if top > 25.0:
		return false
	correct = [top]
	return true


func question() -> String:
	return "A %s kg bird is launched at v₀ = %s m/s, θ = %s° from y₀ = %s m (g = %s m/s²).\nUse energy: how high is the top of its flight?" % [n(launch["m"]), n(launch["v0"]), n(launch["theta"]), n(launch["y0"]), n(launch["g"])]


func solution_steps() -> Array[String]:
	var p := launch_with()
	var vx := p.v0 * cos(deg_to_rad(p.theta_deg))
	return [
		"Energy is conserved:  ½·m·v₀² + m·g·y₀ = ½·m·v_top² + m·g·H",
		"At the top only the sideways speed is left: v_top = vx = v₀·cosθ = %s m/s" % n(vx),
		"m cancels:  H = y₀ + (v₀² − vx²) / (2·g)",
		"H = %s + (%s² − %s²) / (2·%s) = %s m" % [n(p.y0), n(p.v0), n(vx), n(p.g), n(correct[0])],
		"(Straight up, vx = 0 and all the KE turns into PE.)",
	]


func markers(given: Array[float]) -> Array[Dictionary]:
	if given.is_empty():
		return []
	return [{"type": "height", "value": given[0], "label": "you: %s m" % n(given[0])}]


func outcome(given: Array[float]) -> String:
	return "The top was %s your line" % distance_off(correct[0], given[0], "above", "below")
