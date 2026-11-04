extends Problem
## Kinematics, control: launch from the ground so the top of the arc is exactly
## as high as the range is long. (The answer doesn't depend on v₀ or g!)


func _init():
	topic = "Kinematics"
	title = "Top as high as the range: find θ"
	kind = "control"
	answers = [{"label": "θ", "unit": "°", "min": 0.0, "max": 90.0, "step": 0.1, "key": "theta"}]
	hidden_keys = ["theta", "predict"]


func generate() -> bool:
	launch = {"g": pick_gravity(), "theta": 45.0, "y0": 0.0, "v0": pick(8.0, 25.0, 0.5), "m": 1.0}
	correct = [rad_to_deg(atan(4.0))]
	return true


func question() -> String:
	return "Launch from the ground so the top of the arc is exactly as high as the range is long.\nv₀ = %s m/s, g = %s m/s². At what angle θ?" % [n(launch["v0"]), n(launch["g"])]


func judge(given: Array[float]) -> Dictionary:
	var p := shot_launch(given)
	var top := Kinematics.apex_height(p)
	var reach := Kinematics.horizontal_range(p)
	if absf(top - reach) <= 0.03 * reach:
		return {"ok": true, "message": "✓ Top = range!"}
	return {"ok": false, "message": "✗ The top was %s than the range" % ("higher" if top > reach else "lower")}


func solution_steps() -> Array[String]:
	return [
		"Top:   H = v₀²·sin²θ / (2·g)",
		"Range: R = v₀²·sin(2θ) / g = 2·v₀²·sinθ·cosθ / g",
		"H = R  →  sin²θ / 2 = 2·sinθ·cosθ  →  tanθ = 4",
		"θ = atan(4) = %s°" % n(correct[0]),
		"v₀ and g cancel out: the same angle works at any speed, on any planet.",
	]


func solution_launch() -> LaunchParams:
	return launch_with({"theta": correct[0]})


func markers(_given: Array[float]) -> Array[Dictionary]:
	return []
