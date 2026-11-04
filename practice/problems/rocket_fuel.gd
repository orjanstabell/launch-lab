extends Problem
## Momentum, predict: how much fuel for a given Δv? (The rocket equation backwards.)

var exhaust := 30.0
var wanted := 10.0


func _init():
	topic = "Momentum"
	title = "Rocket bird: fuel for a speed boost"
	bird_type = "rocket"
	answers = [{"label": "fuel", "unit": "kg", "min": 0.0, "max": 50.0, "step": 0.001}]
	hidden_keys = ["v", "p", "fuel"]


func generate() -> bool:
	launch = {"m": pick(1.0, 5.0, 0.1)}
	exhaust = pick(15.0, 80.0, 1.0)
	wanted = pick(5.0, minf(exhaust * 1.2, 20.0), 0.5)
	var fuel: float = launch["m"] * (1.0 - exp(-wanted / exhaust))
	if fuel > 0.9 * launch["m"]:
		return false
	correct = [fuel]
	# The real bird burns the right amount; the ghost burns yours.
	launch.merge({"v0": 14.0, "theta": 45.0, "y0": 6.0, "g": 9.81, "rocket_fuel": fuel, "rocket_exhaust": exhaust, "rocket_burn_rate": clampf(snappedf(launch["m"] * 1.5, 0.1), 0.1, 10.0)})
	return true


func question() -> String:
	return "A rocket bird has mass %s kg with its fuel, and exhaust speed v_e = %s m/s.\nHow much fuel must it burn to gain Δv = %s m/s?\n(Check fires it at the top of its arc with the right fuel, next to a ghost that burns yours.)" % [n(launch["m"]), n(exhaust), n(wanted)]


func solution_steps() -> Array[String]:
	return [
		"Rocket equation:  Δv = v_e·ln(m₀ / m₁)  →  m₁ = m₀·e^(−Δv/v_e)",
		"m₁ = %s·e^(−%s/%s) = %s kg" % [n(launch["m"]), n(wanted), n(exhaust), n(launch["m"] - correct[0], 3)],
		"fuel = m₀ − m₁ = %s kg" % n(correct[0], 3),
		"(Doubling Δv needs much more than double the fuel: that's the exponential.)",
	]


## It fires at the top of the arc.
func tap_time(_given: Array[float]) -> float:
	return Kinematics.time_to_apex(launch_with())


## A ghost rocket that burns your fuel.
func ghosts(given: Array[float]) -> Array[Dictionary]:
	return rocket_ghost(tap_time(given), given[0], "your fuel")


func outcome(given: Array[float]) -> String:
	var m: float = launch["m"]
	var usable := minf(given[0], 0.9 * m)
	return "Your fuel gives a Δv %s" % percent_off(exhaust * log(m / (m - usable)), wanted)
