extends Problem
## Kinematics, control, TWO unknowns: hit the target with the top of the arc at
## a given height H. Exactly one speed and angle do it.


const APEX_TOLERANCE_M := 0.3

var apex_height := 0.0


func _init():
	topic = "Kinematics"
	title = "Hit the target with the top at H: find v₀ and θ"
	kind = "control"
	answers = [
		{"label": "v₀", "unit": "m/s", "min": 1.0, "max": 40.0, "step": 0.01, "key": "v0"},
		{"label": "θ", "unit": "°", "min": 0.0, "max": 90.0, "step": 0.1, "key": "theta"},
	]
	hidden_keys = ["v0", "theta", "predict"]


func generate() -> bool:
	var g := pick_gravity()
	var y0 := 0.0 if rng.randf() < 0.5 else pick(0.5, 2.0, 0.5)
	var target := Vector2(pick(14.0, 32.0, 0.5), pick(0.0, 3.0, 0.5))
	apex_height = pick(maxf(y0, target.y) + 2.0, maxf(y0, target.y) + 8.0, 0.5)
	var vy := sqrt(2.0 * g * (apex_height - y0))
	var time := vy / g + sqrt(2.0 * (apex_height - target.y) / g)
	var vx := target.x / time
	var v0 := Vector2(vx, vy).length()
	var theta := rad_to_deg(atan2(vy, vx))
	if v0 < 3.0 or v0 > 38.0 or theta < 5.0 or theta > 85.0:
		return false
	launch = {"g": g, "theta": 45.0, "y0": y0, "v0": 15.0, "m": 1.0}
	targets = [target]
	correct = [v0, theta]
	return true


func question() -> String:
	return "Hit the target at x = %s m, y = %s m, with the top of the arc at H = %s m.\ng = %s m/s², y₀ = %s m. Find both v₀ and θ." % [n(targets[0].x), n(targets[0].y), n(apex_height), n(launch["g"]), n(launch["y0"])]


func judge(given: Array[float]) -> Dictionary:
	var result := super(given)
	var top := Kinematics.apex_height(shot_launch(given))
	if result["ok"] and absf(top - apex_height) > APEX_TOLERANCE_M:
		return {"ok": false, "message": "✗ Hit the target, but the top of the arc was too %s" % ("high" if top > apex_height else "low")}
	return result


func solution_steps() -> Array[String]:
	var g: float = launch["g"]
	var y0: float = launch["y0"]
	var vy := sqrt(2.0 * g * (apex_height - y0))
	var t_up := vy / g
	var t_down := sqrt(2.0 * (apex_height - targets[0].y) / g)
	var vx := targets[0].x / (t_up + t_down)
	return [
		"At the top vy = 0, so  vy₀² = 2·g·(H − y₀):",
		"vy₀ = √(2·%s·(%s − %s)) = %s m/s" % [n(g), n(apex_height), n(y0), n(vy)],
		"Time up: t₁ = vy₀/g = %s s.   Time down from H to Y: t₂ = √(2·(H − Y)/g) = %s s" % [n(t_up), n(t_down)],
		"vx = X / (t₁ + t₂) = %s / %s = %s m/s" % [n(targets[0].x), n(t_up + t_down), n(vx)],
		"v₀ = √(vx² + vy₀²) = %s m/s,   θ = atan(vy₀/vx) = %s°" % [n(correct[0]), n(correct[1])],
	]


func solution_launch() -> LaunchParams:
	return launch_with({"v0": correct[0], "theta": correct[1]})


func markers(_given: Array[float]) -> Array[Dictionary]:
	return [{"type": "height", "value": apex_height, "label": "top of the arc: %s m" % n(apex_height)}]
