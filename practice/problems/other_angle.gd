extends Problem
## Kinematics, predict: on flat ground, two angles give the same range.


func _init():
	topic = "Kinematics"
	title = "Same range, other angle"
	answers = [{"label": "θ₂", "unit": "°", "min": 0.0, "max": 90.0, "step": 0.1}]
	hidden_keys = ["predict"]


func generate() -> bool:
	var theta := pick(15.0, 40.0, 1.0)
	launch = {"g": pick_gravity(), "theta": theta, "y0": 0.0, "v0": pick(10.0, 20.0, 0.5), "m": 1.0}
	correct = [90.0 - theta]
	return true


func question() -> String:
	return "Launched from the ground at θ = %s° (v₀ = %s m/s, g = %s m/s²).\nWhich OTHER angle lands in exactly the same spot, at the same speed?" % [n(launch["theta"]), n(launch["v0"]), n(launch["g"])]


func solution_steps() -> Array[String]:
	return [
		"Range on flat ground: R = v₀²·sin(2θ) / g",
		"sin(2θ) = sin(180° − 2θ), so 2θ₂ = 180° − 2θ  →  θ₂ = 90° − θ",
		"θ₂ = 90° − %s° = %s°" % [n(launch["theta"]), n(correct[0])],
		"(The two angles are equally far from 45°, the angle with the longest range.)",
	]


func fly_changes(given: Array[float]) -> Dictionary:
	return {"theta": given[0]} if not given.is_empty() else {}


func solution_launch() -> LaunchParams:
	return launch_with({"theta": correct[0]})


## The first shot flies next to yours.
func ghosts(_given: Array[float]) -> Array[Dictionary]:
	return [ghost(launch_with(), "first shot, θ = %s°" % n(launch["theta"], 0))]


func outcome(given: Array[float]) -> String:
	var yours := Kinematics.horizontal_range(launch_with({"theta": given[0]}))
	return "Your angle landed %s the first shot" % distance_off(yours, Kinematics.horizontal_range(launch_with()), "beyond", "short of")
