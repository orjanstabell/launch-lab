extends Problem
## Energy, predict: how fast is it moving at a given height? (The angle doesn't matter!)

const ARROW_SCALE := 0.2   # meters of arrow per m/s

var height := 0.0


func _init():
	topic = "Energy"
	title = "Energy: speed at a height"
	answers = [{"label": "|v|", "unit": "m/s", "min": 0.0, "max": 60.0, "step": 0.01}]
	hidden_keys = ["predict", "v", "vx", "vy", "E"]


func generate() -> bool:
	launch = {"g": pick_gravity(), "theta": pick(20.0, 80.0, 1.0), "y0": pick(0.0, 5.0, 0.5), "v0": pick(8.0, 20.0, 0.5), "m": pick(0.5, 3.0, 0.1)}
	var top := Kinematics.apex_height(launch_with())
	height = pick(0.0, top * 0.9, 0.5)
	if top > 25.0 or Kinematics.horizontal_range(launch_with()) > 80.0:
		return false
	correct = [sqrt(launch["v0"] * launch["v0"] + 2.0 * launch["g"] * (launch["y0"] - height))]
	return true


func question() -> String:
	return "A bird is launched at v₀ = %s m/s, θ = %s° from y₀ = %s m (g = %s m/s²).\nHow fast is it moving when it is at height y = %s m?" % [n(launch["v0"]), n(launch["theta"]), n(launch["y0"]), n(launch["g"]), n(height)]


func solution_steps() -> Array[String]:
	return [
		"Energy is conserved:  ½·m·v₀² + m·g·y₀ = ½·m·v² + m·g·y",
		"m cancels:  v = √(v₀² + 2·g·(y₀ − y))",
		"v = √(%s² + 2·%s·(%s − %s)) = %s m/s" % [n(launch["v0"]), n(launch["g"]), n(launch["y0"]), n(height), n(correct[0])],
		"The angle never appears: at a given height the speed is the same going up and coming down, at any angle.",
	]


## The height line, and where the bird crosses it (going up and coming down):
## its real velocity arrow and one as long as your speed.
func markers(given: Array[float]) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"type": "height", "value": height, "label": "y = %s m" % n(height)}]
	if given.is_empty():
		return result
	var p := launch_with()
	var vy := Kinematics.initial_velocity(p).y
	var root := sqrt(maxf(vy * vy + 2.0 * p.g * (p.y0 - height), 0.0))
	for t in [(vy - root) / p.g, (vy + root) / p.g]:
		if t < 0.0 or (root < 0.01 and t > vy / p.g):
			continue   # before the launch, or the same point twice
		var v := Kinematics.velocity(p, t)
		var real := v * ARROW_SCALE
		var yours := v.normalized() * given[0] * ARROW_SCALE
		var pos := Kinematics.position(p, t)
		var side := v.normalized().orthogonal() * 0.6
		# Going up the arrows start at the line; coming down they end on it (not in the ground).
		var down := v.y < 0.0
		result.append({"type": "arrow", "who": "real", "pos": pos - real if down else pos, "vector": real, "at": t, "label": "real"})
		result.append({"type": "arrow", "who": "you", "pos": (pos - yours if down else pos) + side, "vector": yours, "at": t, "label": "you: %s m/s" % n(given[0])})
	return result


func outcome(given: Array[float]) -> String:
	return "Your arrow is %s" % percent_off(given[0], correct[0], "too long", "too short")
