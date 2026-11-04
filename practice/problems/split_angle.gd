extends Problem
## Momentum, predict: a bird splits into two pieces at ±α. From the speeds before
## and after, find α (momentum conserved).

const ARC_ANGLE := 35.0

var speed := 15.0
var piece_speed := 18.0


func _init():
	topic = "Momentum"
	title = "Split in two: find the angle"
	bird_type = "blue"
	answers = [{"label": "α", "unit": "°", "min": 0.0, "max": 90.0, "step": 0.1, "key": "split_spread"}]   # the pieces fly off at ±your α
	hidden_keys = ["p"]
	show_com = true


func generate() -> bool:
	var alpha := pick(10.0, 60.0, 1.0)
	speed = pick(8.0, 25.0, 0.5)
	piece_speed = snappedf(speed / cos(deg_to_rad(alpha)), 0.1)
	launch = {"m": pick(0.6, 3.0, 0.1), "split_pieces": 2, "split_speed": piece_speed}
	launch.merge(_arc_to(speed))
	correct = [rad_to_deg(acos(speed / piece_speed))]
	return true


func question() -> String:
	return "A %s kg bird flying at %s m/s splits into 2 equal pieces that fly off at ±α, each at %s m/s.\nMomentum is conserved. What is α?\n(Check splits it at the top of its arc with your angle: watch the center of mass.)" % [n(launch["m"]), n(speed), n(piece_speed)]


func solution_steps() -> Array[String]:
	return [
		"Along the original direction: m·v = 2·(m/2)·v'·cos α   (the sideways parts cancel)",
		"So v = v'·cos α  →  cos α = v / v' = %s / %s = %s" % [n(speed), n(piece_speed), n(speed / piece_speed, 4)],
		"α = acos(%s) = %s°" % [n(speed / piece_speed, 4), n(correct[0])],
		"The pieces must be faster than the bird was: only part of their speed points forward.",
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
		return "Momentum conserved: the center of mass stayed with the unsplit bird"
	return "Σp after the split was %s: the center of mass %s the unsplit bird" % [percent_off(forward_speed, speed), "ran ahead of" if forward_speed > speed else "fell behind"]


func outcome(given: Array[float]) -> String:
	return _momentum_outcome(piece_speed * cos(deg_to_rad(given[0])))
