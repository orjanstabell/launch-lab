extends Problem
## Energy, predict, measurement: the spring constant is hidden. Watch the shot,
## measure the range, and work out k.


func _init():
	topic = "Energy"
	title = "Mystery spring: measure k"
	answers = [{"label": "k", "unit": "N/m", "min": 1.0, "max": 5000.0, "step": 0.1}]
	hidden_keys = ["k", "v0", "predict", "E"]
	tolerance_percent = 5.0   # you're measuring, so a little slack
	demo_shot = true


func generate() -> bool:
	launch = {"mode": "spring", "k": pick(150.0, 1500.0, 10.0), "pull": pick(0.3, 1.2, 0.05), "m": pick(0.5, 3.0, 0.1), "g": 9.81, "theta": pick(30.0, 60.0, 1.0), "y0": 0.0}
	var reach := Kinematics.horizontal_range(launch_with())
	if reach < 8.0 or reach > 80.0:
		return false
	correct = [launch["k"]]
	return true


func question() -> String:
	return "Mystery spring! k is hidden. Watch the shot (Space to watch again), measure where it lands, and work out k.\nΔx = %s m, m = %s kg, θ = %s°, g = 9.81 m/s², launched from the ground." % [n(launch["pull"]), n(launch["m"]), n(launch["theta"])]


func solution_steps() -> Array[String]:
	var p := launch_with()
	var reach := Kinematics.horizontal_range(p)
	return [
		"It landed at R = %s m" % n(reach),
		"Range on flat ground: R = v₀²·sin(2θ) / g  →  v₀² = g·R / sin(2θ) = %s m²/s²" % n(p.v0 * p.v0),
		"Spring energy becomes KE: ½·k·Δx² = ½·m·v₀²  →  k = m·v₀² / Δx²",
		"k = %s·%s / %s² = %s N/m" % [n(p.m), n(p.v0 * p.v0), n(launch["pull"]), n(correct[0])],
	]


## A ghost flies the path your k gives, next to the real shot.
func ghosts(given: Array[float]) -> Array[Dictionary]:
	return [ghost(launch_with({"k": given[0]}), "your k")]


func outcome(given: Array[float]) -> String:
	var yours := Kinematics.horizontal_range(launch_with({"k": given[0]}))
	return "With your k it lands %s the real shot" % distance_off(yours, Kinematics.horizontal_range(launch_with()), "beyond", "short of")
