extends Problem
## Momentum + energy, control, two answers: what would it take for Matilda's egg
## to fall straight down (no forward speed), like it seems to in the game?
## Try it flies the shot: Matilda throws the egg backwards at YOUR speed, so you
## see the egg drift forwards (too slow), backwards (too fast) or drop straight
## down onto the flag. The energy answer is checked alongside.

const THROW_AT := 0.5   # seconds into the flight when she throws the egg
const DROP_HEIGHT := 8.0

var egg_mass := 0.4
var speed := 10.0


func _init():
	topic = "Momentum"
	title = "Matilda: what would it take to drop the egg straight down?"
	kind = "control"
	bird_type = "matilda"
	answers = [
		{"label": "throw back at", "unit": "m/s", "min": 0.0, "max": 200.0, "step": 0.01, "key": "egg_back"},
		{"label": "energy", "unit": "J", "min": 0.0, "max": 5000.0, "step": 0.01},
	]
	hidden_keys = ["v", "vx", "vy", "p", "E", "predict"]


func generate() -> bool:
	var mass := pick(1.0, 3.0, 0.1)
	egg_mass = pick(0.2, mass * 0.6, 0.05)
	speed = pick(6.0, 16.0, 0.5)
	# Flies level from a raised point, so its forward speed is exactly `speed`.
	launch = {"m": mass, "v0": speed, "theta": 0.0, "y0": DROP_HEIGHT, "g": 9.81, "egg_mass": egg_mass, "egg_speed": 4.0}
	var bird_mass: float = mass - egg_mass
	correct = [speed * mass / bird_mass, 0.5 * mass * speed * speed * egg_mass / bird_mass]
	return true


func question() -> String:
	return "Matilda (%s kg with her %s kg egg) flies at %s m/s forwards. She wants the egg to fall STRAIGHT down, with no forward speed.\nHow fast must she throw it backwards (relative to herself), and how much kinetic energy does that take? (Forward motion only.)" % [n(launch["m"]), n(egg_mass), n(speed)]


## The egg's forward speed after a backward throw at relative speed w:
## momentum m·vₓ = m_egg·v_egg + m_bird·v_bird, with v_bird − v_egg = w.
func egg_forward_speed(w: float) -> float:
	return speed - (launch["m"] - egg_mass) / launch["m"] * w


func judge(given: Array[float]) -> Dictionary:
	var drift := egg_forward_speed(given[0])
	var straight := absf(drift) <= 0.02 * speed + 0.05
	var energy_right := absf(given[1] - correct[1]) <= maxf(0.02 * correct[1], 0.05)
	var energy_note := "" if energy_right else "  ✗ but the energy is too %s" % ("high" if given[1] > correct[1] else "low")
	if straight:
		return {"ok": energy_right, "message": "✓ Straight down!" + (" And the energy is right." if energy_right else energy_note)}
	return {"ok": false, "message": "✗ The egg drifted %s at %s m/s%s" % ["forwards" if drift > 0 else "backwards", n(absf(drift), 1), energy_note]}


func tap_time(_given: Array[float]) -> float:
	return THROW_AT


func watch_time(_given: Array[float]) -> float:
	return THROW_AT + 1.0   # watch the egg fall for a second


## A flag on the ground straight below where she throws it.
func markers(_given: Array[float]) -> Array[Dictionary]:
	return [{"type": "x", "value": speed * THROW_AT, "label": "straight below the throw"}]


func solution_steps() -> Array[String]:
	var bird_mass: float = launch["m"] - egg_mass
	var reduced: float = egg_mass * bird_mass / launch["m"]
	return [
		"Momentum forwards is conserved: m·vₓ = m_egg·0 + m_bird·vₓ'",
		"vₓ' = vₓ·m / m_bird = %s·%s / %s = %s m/s  (she speeds up!)" % [n(speed), n(launch["m"]), n(bird_mass), n(correct[0])],
		"Relative to her the egg moves at 0 − vₓ' = −%s m/s: she throws it back exactly as fast as she ends up flying" % n(correct[0]),
		"Energy: ΔKE = ½·m_bird·vₓ'² − ½·m·vₓ² = ½·m·vₓ²·(m_egg / m_bird)",
		"ΔKE = ½·%s·%s²·(%s / %s) = %s J  (work done by her muscles)" % [n(launch["m"]), n(speed), n(egg_mass), n(bird_mass), n(correct[1])],
		"(Neat: a throw at relative speed w always costs ½·μ·w², with μ = m_egg·m_bird/m = %s kg.)" % n(reduced, 3),
	]
