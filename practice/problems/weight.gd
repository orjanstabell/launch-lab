extends Problem
## Forces, predict: how hard does gravity pull on a bird, on some planet?

const PLANETS := {"the Moon": 1.62, "Mars": 3.71, "Earth": 9.81, "Jupiter": 24.79}

var planet := ""


func _init():
	topic = "Forces"
	title = "Gravity's pull on another planet"
	answers = [{"label": "F", "unit": "N", "min": 0.0, "max": 500.0, "step": 0.01}]
	hidden_keys = ["F"]


func generate() -> bool:
	planet = PLANETS.keys()[rng.randi() % PLANETS.size()]
	launch = {"g": PLANETS[planet], "m": pick(0.5, 8.0, 0.1), "y0": 10.0, "v0": 5.0, "theta": 0.0}
	correct = [launch["m"] * launch["g"]]
	return true


func question() -> String:
	return "A ball of %s kg is on %s, where g = %s m/s².\nHow strong is gravity's pull on it? (Check throws it off a 10 m ledge, next to a ghost that falls with your force.)" % [n(launch["m"]), planet, n(launch["g"])]


func solution_steps() -> Array[String]:
	return [
		"Weight (gravity's pull): F = m·g",
		"F = %s·%s = %s N" % [n(launch["m"]), n(launch["g"]), n(correct[0])],
	]


## Arrows at the start: the real force and yours (same scale).
func markers(given: Array[float]) -> Array[Dictionary]:
	if given.is_empty():
		return []
	var scale := 2.5 / correct[0]   # the real arrow is 2.5 m long
	var start := Vector2(0.0, launch["y0"])
	return [
		{"type": "arrow", "who": "real", "pos": start, "vector": Vector2(0, -correct[0] * scale), "label": "real F"},
		{"type": "arrow", "who": "you", "pos": start + Vector2(0.6, 0), "vector": Vector2(0, -given[0] * scale), "label": "your F"},
	]


## A ghost falls with the acceleration your answer gives (a = F/m).
func ghosts(given: Array[float]) -> Array[Dictionary]:
	return [ghost(launch_with({"g": given[0] / launch["m"]}), "your F")]


func outcome(given: Array[float]) -> String:
	var a: float = given[0] / launch["m"]
	if a <= 0.0:
		return "With your F it would never come down"
	var yours := Kinematics.time_of_flight(launch_with({"g": a}))
	return "With your F it hit the ground %s" % distance_off(yours, Kinematics.time_of_flight(launch_with()), "later", "earlier", "s")
