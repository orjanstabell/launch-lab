extends Problem
## Momentum, predict: how fast must the blue bird's pieces fly so that momentum
## is conserved when it splits?

const ARC_ANGLE := 35.0

var count := 3
var spread := 15.0
var speed := 15.0


func _init():
	topic = "Momentum"
	title = "Splitter split: speed of the pieces"
	bird_type = "blue"
	answers = [{"label": "v'", "unit": "m/s", "min": 0.0, "max": 100.0, "step": 0.01, "key": "split_speed"}]   # the pieces fly at your v'
	hidden_keys = ["p"]
	show_com = true


func generate() -> bool:
	count = rng.randi_range(2, 5)
	spread = pick(5.0, 30.0, 1.0)
	speed = pick(8.0, 25.0, 0.5)
	launch = {"m": pick(0.6, 3.0, 0.1), "split_pieces": count, "split_spread": spread}
	launch.merge(_arc_to(speed))
	correct = [speed * count / _cos_sum()]
	return true


## Σ cos(offsetᵢ) for the pieces, fanned evenly from −spread to +spread.
func _cos_sum() -> float:
	var total := 0.0
	for i in count:
		total += cos(deg_to_rad(lerpf(-spread, spread, float(i) / (count - 1))))
	return total


func question() -> String:
	return "A %s kg Splitter flying at %s m/s splits into %d equal pieces, fanned out evenly from −%s° to +%s°.\nHow fast must each piece fly so that momentum is conserved?\n(Check splits it at the top of its arc with your speed: watch the center of mass.)" % [n(launch["m"]), n(speed), count, n(spread), n(spread)]


func solution_steps() -> Array[String]:
	var angles := []
	for i in count:
		angles.append(n(lerpf(-spread, spread, float(i) / (count - 1)), 1) + "°")
	return [
		"The split is instant, so no outside force changes the momentum: p before = p after",
		"m·v = Σ (m/n)·v'·cos(αᵢ)   (the sideways parts cancel, since the fan is symmetric)",
		"Angles: %s,   Σcos(αᵢ) = %s" % [", ".join(angles), n(_cos_sum(), 4)],
		"v' = n·v / Σcos(αᵢ) = %d·%s / %s = %s m/s" % [count, n(speed), n(_cos_sum(), 4), n(correct[0])],
		"The mass cancels: it doesn't matter how heavy the ball is!",
	]


## Fly so the top of the arc is where the bird moves at `speed` (sideways).
func _arc_to(top_speed: float) -> Dictionary:
	return {"g": 9.81, "y0": 8.0, "theta": ARC_ANGLE, "v0": top_speed / cos(deg_to_rad(ARC_ANGLE))}


## The split happens at the top of the arc.
func tap_time(_given: Array[float]) -> float:
	return Kinematics.time_to_apex(launch_with())


## The bird that didn't split: the center of mass should stay with it.
func ghosts(_given: Array[float]) -> Array[Dictionary]:
	var p := launch_with()
	var top_t := Kinematics.time_to_apex(p)
	return [ghost(launch_from(Kinematics.position(p, top_t), Vector2(speed, 0), p.g), "no split", top_t)]


## How the forward momentum after the split compares, as a sentence.
func _momentum_outcome(forward_speed: float) -> String:
	if absf(forward_speed - speed) / speed < tolerance_percent / 100.0:
		return "Momentum conserved: the center of mass stayed with the unsplit ball"
	return "Σp after the split was %s: the center of mass %s the unsplit ball" % [percent_off(forward_speed, speed), "ran ahead of" if forward_speed > speed else "fell behind"]


func outcome(given: Array[float]) -> String:
	return _momentum_outcome(given[0] * _cos_sum() / count)
