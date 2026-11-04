extends Problem
## Kinematics, predict: how long is it in the air?


func _init():
	topic = "Kinematics"
	title = "Predict the time in the air"
	answers = [{"label": "time", "unit": "s", "min": 0.0, "max": 30.0, "step": 0.01}]
	hidden_keys = ["predict", "t"]


func generate() -> bool:
	launch = {"g": pick_gravity(), "theta": pick(20.0, 80.0, 1.0), "y0": pick(0.0, 5.0, 0.5), "v0": pick(8.0, 22.0, 0.5), "m": 1.0}
	var time := Kinematics.time_of_flight(launch_with())
	if time > 10.0 or Kinematics.horizontal_range(launch_with()) > 80.0:
		return false
	correct = [time]
	return true


func question() -> String:
	return "v₀ = %s m/s, θ = %s°, g = %s m/s², launched from y₀ = %s m.\nHow long is the bird in the air?" % [n(launch["v0"]), n(launch["theta"]), n(launch["g"]), n(launch["y0"])]


func solution_steps() -> Array[String]:
	var p := launch_with()
	var vy := Kinematics.initial_velocity(p).y
	return [
		"Only the vertical motion matters: vy₀ = v₀·sinθ = %s m/s" % n(vy),
		"It lands when y = 0:  y₀ + vy₀·t − ½·g·t² = 0",
		"t = (vy₀ + √(vy₀² + 2·g·y₀)) / g   (the positive root)",
		"t = (%s + √(%s² + 2·%s·%s)) / %s = %s s" % [n(vy), n(vy), n(p.g), n(p.y0), n(p.g), n(correct[0])],
	]


## A clock on the bird, and a dot on its path at your time.
func markers(given: Array[float]) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"type": "clock", "until": correct[0], "label": ""}]
	if given.is_empty():
		return result
	var at := minf(given[0], correct[0])
	var label := "your %s s: still flying" % n(given[0]) if given[0] < correct[0] else "landed before your %s s" % n(given[0])
	result.append({"type": "point", "pos": Kinematics.position(launch_with(), at), "at": at, "label": label})
	return result


func outcome(given: Array[float]) -> String:
	return "It landed %s your time" % distance_off(correct[0], given[0], "after", "before", "s")
