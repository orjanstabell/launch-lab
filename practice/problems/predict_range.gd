extends Problem
## Kinematics, predict: where will it land?


func _init():
	topic = "Kinematics"
	title = "Predict where it lands"
	answers = [{"label": "lands at x", "unit": "m", "min": 0.0, "max": 200.0, "step": 0.01}]
	hidden_keys = ["predict", "x"]


func generate() -> bool:
	launch = {"g": pick_gravity(), "theta": pick(20.0, 70.0, 1.0), "y0": pick(0.0, 5.0, 0.5), "v0": pick(8.0, 22.0, 0.5), "m": 1.0}
	var reach := Kinematics.horizontal_range(launch_with())
	if reach < 5.0 or reach > 80.0:
		return false
	correct = [reach]
	return true


func question() -> String:
	return "v₀ = %s m/s, θ = %s°, g = %s m/s², launched from y₀ = %s m.\nWhere (x) will the bird land?" % [n(launch["v0"]), n(launch["theta"]), n(launch["g"]), n(launch["y0"])]


func solution_steps() -> Array[String]:
	var p := launch_with()
	var v := Kinematics.initial_velocity(p)
	var time := Kinematics.time_of_flight(p)
	return [
		"Split the velocity: vx = v₀·cosθ = %s m/s,  vy₀ = v₀·sinθ = %s m/s" % [n(v.x), n(v.y)],
		"Time in the air: y₀ + vy₀·t − ½·g·t² = 0",
		"t = (vy₀ + √(vy₀² + 2·g·y₀)) / g = %s s" % n(time),
		"x = vx·t = %s·%s = %s m" % [n(v.x), n(time), n(correct[0])],
	]


func markers(given: Array[float]) -> Array[Dictionary]:
	if given.is_empty():
		return []
	return [{"type": "x", "value": given[0], "label": "you: %s m" % n(given[0])}]


func outcome(given: Array[float]) -> String:
	return "It landed %s your flag" % distance_off(correct[0], given[0], "beyond", "short of")
