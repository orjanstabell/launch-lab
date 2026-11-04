extends Problem
## Kinematics, predict, measurement: g is hidden. Watch the shot, measure where
## it lands (rulers or readouts), and work out g.


func _init():
	topic = "Kinematics"
	title = "Mystery planet: measure g"
	answers = [{"label": "g", "unit": "m/s²", "min": 0.1, "max": 30.0, "step": 0.01}]
	hidden_keys = ["g", "predict", "a", "F"]
	tolerance_percent = 4.0   # you're measuring, so a little slack
	demo_shot = true


func generate() -> bool:
	var g := pick(2.0, 25.0, 0.1)
	launch = {"g": g, "theta": pick(30.0, 60.0, 1.0), "y0": 0.0, "v0": pick(8.0, 20.0, 0.5), "m": 1.0}
	var reach := Kinematics.horizontal_range(launch_with())
	if reach < 8.0 or reach > 80.0:
		return false
	correct = [g]
	return true


func question() -> String:
	return "Mystery planet! g is hidden. Watch the shot (Space to watch again), measure where it lands, and work out g.\nv₀ = %s m/s, θ = %s°, launched from the ground." % [n(launch["v0"]), n(launch["theta"])]


func solution_steps() -> Array[String]:
	var p := launch_with()
	var reach := Kinematics.horizontal_range(p)
	return [
		"It landed at R = %s m" % n(reach),
		"Range on flat ground: R = v₀²·sin(2θ) / g",
		"g = v₀²·sin(2θ) / R = %s²·sin(%s°) / %s = %s m/s²" % [n(p.v0), n(2.0 * p.theta_deg), n(reach), n(correct[0])],
		"(Or from the time in the air: t = 2·v₀·sinθ / g.)",
	]


## A ghost flies the path your g gives, next to the real shot.
func ghosts(given: Array[float]) -> Array[Dictionary]:
	return [ghost(launch_with({"g": given[0]}), "your g")]


func outcome(given: Array[float]) -> String:
	var yours := Kinematics.horizontal_range(launch_with({"g": given[0]}))
	return "With your g it lands %s the real shot" % distance_off(yours, Kinematics.horizontal_range(launch_with()), "beyond", "short of")
