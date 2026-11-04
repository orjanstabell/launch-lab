extends Problem
## Energy, predict: the launch speed a spring slingshot gives.


func _init():
	topic = "Energy"
	title = "Spring slingshot: launch speed"
	answers = [{"label": "v₀", "unit": "m/s", "min": 0.0, "max": 60.0, "step": 0.01}]
	hidden_keys = ["v0", "predict", "E"]


func generate() -> bool:
	launch = {"mode": "spring", "k": pick(100.0, 1500.0, 10.0), "pull": pick(0.2, 1.5, 0.05), "m": pick(0.5, 4.0, 0.1), "g": 9.81, "theta": pick(30.0, 60.0, 1.0), "y0": 0.0}
	var v0: float = launch["pull"] * sqrt(launch["k"] / launch["m"])
	if v0 < 4.0 or v0 > 30.0:
		return false
	correct = [v0]
	return true


func question() -> String:
	return "The slingshot's spring has k = %s N/m and is pulled back Δx = %s m.\nWhat launch speed does it give a %s kg bird?" % [n(launch["k"]), n(launch["pull"]), n(launch["m"])]


func solution_steps() -> Array[String]:
	var stored: float = 0.5 * launch["k"] * launch["pull"] * launch["pull"]
	return [
		"The pulled spring stores  ½·k·Δx² = ½·%s·%s² = %s J" % [n(launch["k"]), n(launch["pull"]), n(stored)],
		"All of it becomes kinetic energy:  ½·k·Δx² = ½·m·v₀²",
		"v₀ = Δx·√(k/m) = %s·√(%s/%s) = %s m/s" % [n(launch["pull"]), n(launch["k"]), n(launch["m"]), n(correct[0])],
	]


## A ghost flies the path your v₀ gives, next to the real shot.
func ghosts(given: Array[float]) -> Array[Dictionary]:
	return [ghost(launch_with({"v0": given[0]}), "your v₀")]


func outcome(given: Array[float]) -> String:
	var yours := Kinematics.horizontal_range(launch_with({"v0": given[0]}))
	return "With your v₀ it lands %s the real shot" % distance_off(yours, Kinematics.horizontal_range(launch_with()), "beyond", "short of")
