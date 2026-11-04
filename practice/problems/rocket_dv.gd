extends Problem
## Momentum, predict: the rocket equation.


func _init():
	topic = "Momentum"
	title = "Rocket bird: Δv from the rocket equation"
	bird_type = "rocket"
	answers = [{"label": "Δv", "unit": "m/s", "min": 0.0, "max": 500.0, "step": 0.01}]
	hidden_keys = ["v", "p"]


var exhaust := 30.0
var fuel := 0.5


func generate() -> bool:
	launch = {"m": pick(1.0, 5.0, 0.1)}
	exhaust = pick(10.0, 80.0, 1.0)
	fuel = pick(0.1, launch["m"] * 0.8, 0.05)
	correct = [exhaust * log(launch["m"] / (launch["m"] - fuel))]
	if correct[0] > 20.0:
		return false   # keep the flight on screen
	launch.merge({"v0": 14.0, "theta": 45.0, "y0": 6.0, "g": 9.81, "rocket_fuel": fuel, "rocket_exhaust": exhaust, "rocket_burn_rate": clampf(snappedf(fuel / 0.6, 0.1), 0.1, 10.0)})
	return true


func question() -> String:
	return "A rocket bird of %s kg (fuel included) burns %s kg of fuel, with exhaust speed v_e = %s m/s.\nHow much speed does it gain (ignore gravity during the burn)?\n(Check fires it at the top of its arc, next to a ghost rocket that gains your Δv.)" % [n(launch["m"]), n(fuel), n(exhaust)]


func solution_steps() -> Array[String]:
	var m1: float = launch["m"] - fuel
	return [
		"Momentum of bird + exhaust is conserved:  m·dv = v_e·dm",
		"Adding that up over the burn:  Δv = v_e·ln(m₀ / m₁)",
		"m₀ = %s kg,  m₁ = m₀ − fuel = %s kg" % [n(launch["m"]), n(m1)],
		"Δv = %s·ln(%s / %s) = %s m/s" % [n(exhaust), n(launch["m"]), n(m1), n(correct[0])],
		"(Only the mass RATIO matters: burning half the mass always gives v_e·ln 2.)",
	]


## It fires at the top of the arc.
func tap_time(_given: Array[float]) -> float:
	return Kinematics.time_to_apex(launch_with())


## A ghost rocket that burns just enough fuel to gain your Δv.
func ghosts(given: Array[float]) -> Array[Dictionary]:
	var m: float = launch["m"]
	return rocket_ghost(tap_time(given), m * (1.0 - exp(-given[0] / exhaust)), "your Δv")


func outcome(given: Array[float]) -> String:
	return "Your Δv is %s" % percent_off(given[0], correct[0])
