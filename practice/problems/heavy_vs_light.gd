extends Problem
## Energy, predict: same spring, same pull, different mass. Where does it land?

var mass_2 := 1.0
var range_1 := 0.0


func _init():
	topic = "Energy"
	title = "Spring slingshot: heavy vs light bird"
	answers = [{"label": "new range", "unit": "m", "min": 0.0, "max": 200.0, "step": 0.01}]
	hidden_keys = ["predict", "v0", "E", "x"]


func generate() -> bool:
	launch = {"mode": "spring", "k": pick(200.0, 1200.0, 10.0), "pull": pick(0.3, 1.0, 0.05), "m": pick(0.5, 2.0, 0.1), "g": 9.81, "theta": pick(30.0, 60.0, 1.0), "y0": 0.0}
	mass_2 = pick(0.5, 4.0, 0.1)
	range_1 = Kinematics.horizontal_range(launch_with())
	var range_2 := Kinematics.horizontal_range(launch_with({"m": mass_2}))
	if is_equal_approx(mass_2, launch["m"]) or range_1 > 80.0 or range_2 > 80.0 or range_2 < 3.0:
		return false
	correct = [range_2]
	return true


func question() -> String:
	return "With this spring and pull, a %s kg bird launched from the ground lands %s m away.\nSame spring, same pull, same angle: where does a %s kg bird land?" % [n(launch["m"]), n(range_1), n(mass_2)]


func solution_steps() -> Array[String]:
	return [
		"Spring: ½·k·Δx² = ½·m·v₀²  →  v₀² = k·Δx² / m   (heavier → slower)",
		"Range: R = v₀²·sin(2θ) / g = k·Δx²·sin(2θ) / (m·g)   →   R ∝ 1/m",
		"R₂ = R₁ · m₁ / m₂ = %s · %s / %s = %s m" % [n(range_1), n(launch["m"]), n(mass_2), n(correct[0])],
		"Here mass matters: not in flight (it cancels there), but at the launch.",
	]


func fly_changes(_given: Array[float]) -> Dictionary:
	return {"m": mass_2}


func markers(given: Array[float]) -> Array[Dictionary]:
	if given.is_empty():
		return []
	return [{"type": "x", "value": given[0], "label": "you: %s m" % n(given[0])}]


## The first bird flies next to the new one.
func ghosts(_given: Array[float]) -> Array[Dictionary]:
	return [ghost(launch_with(), "the %s kg bird" % n(launch["m"], 1))]


func outcome(given: Array[float]) -> String:
	return "It landed %s your flag" % distance_off(correct[0], given[0], "beyond", "short of")
