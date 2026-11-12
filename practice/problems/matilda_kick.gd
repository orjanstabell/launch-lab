extends Problem
## Momentum, predict: the Dropper throws her egg down and recoils up. How big is the kick?

const THROW_AT := 0.5   # seconds after launch

var egg_mass := 0.4
var throw_speed := 15.0


func _init():
	topic = "Momentum"
	title = "Recoil: the kick from firing the cannonball"
	bird_type = "matilda"
	answers = [{"label": "kick Δv", "unit": "m/s", "min": 0.0, "max": 100.0, "step": 0.01}]
	hidden_keys = ["v", "p"]


func generate() -> bool:
	launch = {"m": pick(1.0, 4.0, 0.1)}
	egg_mass = pick(0.1, launch["m"] * 0.6, 0.05)
	throw_speed = pick(5.0, 30.0, 0.5)
	correct = [egg_mass / launch["m"] * throw_speed]
	# The flight: she throws at THROW_AT ("let go" sideways: no backward throw).
	launch.merge({"v0": pick(8.0, 14.0, 0.5), "theta": pick(20.0, 45.0, 1.0), "y0": 3.0, "g": 9.81, "egg_mass": egg_mass, "egg_speed": throw_speed, "egg_back": 0.0})
	return true


func question() -> String:
	return "The Recoil cannon weighs %s kg with its cannonball. It fires the %s kg cannonball straight down at %s m/s relative to itself.\nHow much does its upward speed change? (Check: it throws at %s s into the flight, next to a ghost with your kick.)" % [n(launch["m"]), n(egg_mass), n(throw_speed), n(THROW_AT, 1)]


func solution_steps() -> Array[String]:
	var bird_mass: float = launch["m"] - egg_mass
	return [
		"The throw is instant, so momentum is conserved:  m_b·Δv_ball + m_body·Δv_cannon = 0",
		"The cannonball leaves at u relative to the cannon:  Δv_ball − Δv_cannon = u (downwards)",
		"Together:  Δv_cannon = (m_b / m)·u  upwards,  Δv_ball = (m_body / m)·u  downwards",
		"Δv_cannon = %s / %s · %s = %s m/s up" % [n(egg_mass), n(launch["m"]), n(throw_speed), n(correct[0])],
		"(The cannonball gets %s m/s extra downwards: the lighter one gets the bigger change.)" % n(bird_mass / launch["m"] * throw_speed),
	]


func tap_time(_given: Array[float]) -> float:
	return THROW_AT


## From the throw on: a ghost whose upward speed changed by your Δv.
func ghosts(given: Array[float]) -> Array[Dictionary]:
	var p := launch_with()
	var kicked := Kinematics.velocity(p, THROW_AT) + Vector2(0, given[0])
	return [ghost(launch_from(Kinematics.position(p, THROW_AT), kicked, p.g), "your kick", THROW_AT)]


func outcome(given: Array[float]) -> String:
	return "Your kick is %s" % percent_off(given[0], correct[0])
