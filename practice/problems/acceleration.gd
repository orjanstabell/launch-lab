extends Problem
## Forces, predict: from the force and the mass, find the acceleration (and the planet).

const PLANETS := {"the Moon": 1.62, "Mars": 3.71, "Earth": 9.81, "Jupiter": 24.79}

var planet := ""


func _init():
	topic = "Forces"
	title = "Acceleration from force and mass"
	answers = [{"label": "a", "unit": "m/s²", "min": 0.0, "max": 50.0, "step": 0.01}]
	hidden_keys = ["g", "a"]


func generate() -> bool:
	planet = PLANETS.keys()[rng.randi() % PLANETS.size()]
	launch = {"g": PLANETS[planet], "m": pick(0.5, 8.0, 0.1), "y0": 10.0, "v0": 5.0, "theta": 0.0}
	correct = [launch["g"]]
	return true


func question() -> String:
	return "Gravity pulls a %s kg ball down with F = %s N.\nWhat is its acceleration? (Which planet is it on?) Check throws it off a 10 m ledge, next to a ghost that falls with your a." % [n(launch["m"]), n(launch["m"] * launch["g"])]


func solution_steps() -> Array[String]:
	return [
		"Newton's 2nd law: a = F / m",
		"a = %s / %s = %s m/s²" % [n(launch["m"] * launch["g"]), n(launch["m"]), n(correct[0])],
		"That's g on %s." % planet,
	]


## Arrows at the start: the real acceleration and yours (same scale).
func markers(given: Array[float]) -> Array[Dictionary]:
	if given.is_empty():
		return []
	var scale := 2.5 / correct[0]   # the real arrow is 2.5 m long
	var start := Vector2(0.0, launch["y0"])
	return [
		{"type": "arrow", "who": "real", "pos": start, "vector": Vector2(0, -correct[0] * scale), "label": "real a"},
		{"type": "arrow", "who": "you", "pos": start + Vector2(0.6, 0), "vector": Vector2(0, -given[0] * scale), "label": "your a"},
	]


## A ghost falls with the acceleration your answer gives (a = your a).
func ghosts(given: Array[float]) -> Array[Dictionary]:
	return [ghost(launch_with({"g": given[0]}), "your a")]


func outcome(given: Array[float]) -> String:
	var a: float = given[0]
	if a <= 0.0:
		return "With your a it would never come down"
	var yours := Kinematics.time_of_flight(launch_with({"g": a}))
	return "With your a it hit the ground %s" % distance_off(yours, Kinematics.time_of_flight(launch_with()), "later", "earlier", "s")
