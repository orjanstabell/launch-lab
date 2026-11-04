extends Problem
## Kinematics, predict: how high will it go?


func _init():
	topic = "Kinematics"
	title = "Predict the highest point"
	answers = [{"label": "highest y", "unit": "m", "min": 0.0, "max": 100.0, "step": 0.01}]
	hidden_keys = ["predict", "y"]


func generate() -> bool:
	launch = {"g": pick_gravity(), "theta": pick(25.0, 80.0, 1.0), "y0": pick(0.0, 5.0, 0.5), "v0": pick(8.0, 22.0, 0.5), "m": 1.0}
	var top := Kinematics.apex_height(launch_with())
	if top > 25.0:
		return false
	correct = [top]
	return true


func question() -> String:
	return "v₀ = %s m/s, θ = %s°, g = %s m/s², launched from y₀ = %s m.\nHow high (y) is the top of the arc?" % [n(launch["v0"]), n(launch["theta"]), n(launch["g"]), n(launch["y0"])]


func solution_steps() -> Array[String]:
	var p := launch_with()
	var vy := Kinematics.initial_velocity(p).y
	return [
		"Only the vertical motion matters: vy₀ = v₀·sinθ = %s m/s" % n(vy),
		"At the top vy = 0:  0 = vy₀² − 2·g·(y − y₀)",
		"y = y₀ + vy₀² / (2·g) = %s + %s² / (2·%s) = %s m" % [n(p.y0), n(vy), n(p.g), n(correct[0])],
	]


func markers(given: Array[float]) -> Array[Dictionary]:
	if given.is_empty():
		return []
	return [{"type": "height", "value": given[0], "label": "you: %s m" % n(given[0])}]


func outcome(given: Array[float]) -> String:
	return "The top was %s your line" % distance_off(correct[0], given[0], "above", "below")
