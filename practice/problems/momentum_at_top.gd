extends Problem
## Momentum, predict: the bird's momentum at the top of its arc.


func _init():
	topic = "Momentum"
	title = "Momentum at the top of the arc"
	answers = [{"label": "p", "unit": "kg·m/s", "min": 0.0, "max": 500.0, "step": 0.01}]
	hidden_keys = ["p", "predict", "vx", "vy", "v"]


func generate() -> bool:
	launch = {"g": pick_gravity(), "theta": pick(20.0, 75.0, 1.0), "y0": 0.0, "v0": pick(8.0, 25.0, 0.5), "m": pick(0.5, 5.0, 0.1)}
	correct = [launch["m"] * launch["v0"] * cos(deg_to_rad(launch["theta"]))]
	return true


func question() -> String:
	return "A %s kg bird is launched at v₀ = %s m/s, θ = %s° (g = %s m/s²).\nHow much momentum does it have at the top of its arc?" % [n(launch["m"]), n(launch["v0"]), n(launch["theta"]), n(launch["g"])]


func solution_steps() -> Array[String]:
	var vx: float = launch["v0"] * cos(deg_to_rad(launch["theta"]))
	return [
		"At the top vy = 0, so the speed is just vx = v₀·cosθ = %s m/s" % n(vx),
		"p = m·v = %s·%s = %s kg·m/s" % [n(launch["m"]), n(vx), n(correct[0])],
		"(g doesn't matter: gravity only changes vy, and vy is 0 at the top.)",
	]


## At the top of the arc: the real momentum arrow and yours (same scale).
func markers(given: Array[float]) -> Array[Dictionary]:
	if given.is_empty():
		return []
	var p := launch_with()
	var top_t := Kinematics.time_to_apex(p)
	var top := Kinematics.position(p, top_t)
	var scale := 3.0 / correct[0]   # the real arrow is 3 m long
	return [
		{"type": "arrow", "who": "real", "pos": top, "vector": Vector2(correct[0] * scale, 0), "at": top_t, "label": "real p"},
		{"type": "arrow", "who": "you", "pos": top + Vector2(0, -0.6), "vector": Vector2(given[0] * scale, 0), "at": top_t, "label": "your p = %s" % n(given[0])},
	]


func outcome(given: Array[float]) -> String:
	return "Your arrow is %s" % percent_off(given[0], correct[0], "too long", "too short")
