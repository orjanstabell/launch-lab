extends Problem
## Kinematics, control: a yellow bird flies a normal arc until you tap it; from
## then on it flies in a straight line (g → 0, so it keeps the velocity it had).
## When must you tap so the straight line hits the pig?


func _init():
	topic = "Kinematics"
	title = "Gravity off: when to tap (g → 0)"
	kind = "control"
	bird_type = "custom"
	ability = {"g": 0.0}
	answers = [{"label": "tap at t", "unit": "s", "min": 0.0, "max": 10.0, "step": 0.01, "tap": true}]
	hidden_keys = ["t", "predict"]


func generate() -> bool:
	var g := pick_gravity()
	var v0 := pick(10.0, 22.0, 0.5)
	var theta := pick(30.0, 70.0, 1.0)
	launch = {"g": g, "theta": theta, "y0": pick(0.0, 2.0, 0.5), "v0": v0, "m": 1.0}
	var p := launch_with()
	# Pick the tap moment, then put the pig somewhere on the straight line after it.
	var tap := pick(0.2, minf(Kinematics.time_of_flight(p) * 0.6, 2.5), 0.05)
	var at := Kinematics.position(p, tap)
	var heading := Kinematics.velocity(p, tap).normalized()
	var target := at + heading * rng.randf_range(4.0, 16.0)
	target = Vector2(snappedf(target.x, 0.5), snappedf(target.y, 0.5))
	if target.x < 10.0 or target.x > 40.0 or target.y < 0.5 or target.y > 15.0:
		return false
	targets = [target]
	var answer := _tap_time_for(p, target)
	if is_nan(answer):
		return false
	correct = [answer]
	return true


## Solve for the tap time t₁: after the tap the bird moves in a straight line
## along its velocity at t₁, and that line must pass through the target (X, Y):
##   (X − x(t₁))·vy(t₁) = (Y − y(t₁))·vx
## which works out to the quadratic  ½·g·vx·t₁² − g·X·t₁ + (X·vy₀ − (Y − y₀)·vx) = 0.
func _tap_time_for(p: LaunchParams, target: Vector2) -> float:
	var v := Kinematics.initial_velocity(p)
	var a := 0.5 * p.g * v.x
	var b := -p.g * target.x
	var c := target.x * v.y - (target.y - p.y0) * v.x
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return NAN
	for root in [(-b - sqrt(discriminant)) / (2.0 * a), (-b + sqrt(discriminant)) / (2.0 * a)]:
		if root > 0.0 and root < target.x / v.x:   # tapped before reaching the pig
			return root
	return NAN


func question() -> String:
	return "This ball flies straight (g → 0) after you tap it. Hit the dummy at (%s, %s) m.\nv₀ = %s m/s, θ = %s°, g = %s m/s², y₀ = %s m. At what time t must you tap?" % [n(targets[0].x), n(targets[0].y), n(launch["v0"]), n(launch["theta"]), n(launch["g"]), n(launch["y0"])]


## The straight line after tapping at `tap`: a segment with g = 0.
func _after_tap(tap: float) -> LaunchParams:
	var p := launch_with()
	var at := Kinematics.position(p, tap)
	var v := Kinematics.velocity(p, tap)
	var line := LaunchParams.new()
	line.x0 = at.x
	line.y0 = at.y
	line.v0 = v.length()
	line.theta_deg = rad_to_deg(atan2(v.y, v.x))
	line.g = 0.0
	return line


func judge(given: Array[float]) -> Dictionary:
	var line := _after_tap(given[0])
	var closest := Kinematics.closest_approach(line, targets[0])
	if closest.y <= HIT_TOLERANCE_M:
		return {"ok": true, "message": "✓ Hit!"}
	var passed := Kinematics.position(line, closest.x)
	return {"ok": false, "message": "✗ Missed by %s m: passed %s the dummy" % [n(closest.y, 1), "above" if passed.y > targets[0].y else "below"]}


func watch_time(given: Array[float]) -> float:
	return given[0] + Kinematics.closest_approach(_after_tap(given[0]), targets[0]).x


func solution_steps() -> Array[String]:
	var p := launch_with()
	var v := Kinematics.initial_velocity(p)
	var c := targets[0].x * v.y - (targets[0].y - p.y0) * v.x
	return [
		"Before the tap: x = vx·t,  y = y₀ + vy₀·t − ½·g·t²,  vy = vy₀ − g·t",
		"vx = %s m/s,  vy₀ = %s m/s" % [n(v.x), n(v.y)],
		"After tapping at t₁ it goes straight along its velocity, so the dummy must be on that line:",
		"(X − x(t₁))·vy(t₁) = (Y − y(t₁))·vx   →   ½·g·vx·t₁² − g·X·t₁ + (X·vy₀ − (Y − y₀)·vx) = 0",
		"%s·t₁² − %s·t₁ + %s = 0" % [n(0.5 * p.g * v.x, 3), n(p.g * targets[0].x, 3), n(c, 3)],
		"t₁ = %s s  (the root before the ball reaches the dummy)" % n(correct[0]),
	]


func solution_paths() -> Array[Dictionary]:
	var line := _after_tap(correct[0])
	return [
		{"params": launch_with(), "until": correct[0]},
		{"params": line, "until": Kinematics.closest_approach(line, targets[0]).x + 0.3},
	]
