extends Problem
## Forces, predict, two answers: the thrust is constant, but the mass drops, so the
## acceleration from the thrust grows during the burn.

var exhaust := 30.0
var burn_rate := 1.0
var fuel := 0.5


func _init():
	topic = "Forces"
	title = "Rocket bird: acceleration at start and end of the burn"
	bird_type = "rocket"
	answers = [
		{"label": "a start", "unit": "m/s²", "min": 0.0, "max": 1000.0, "step": 0.01},
		{"label": "a end", "unit": "m/s²", "min": 0.0, "max": 1000.0, "step": 0.01},
	]
	hidden_keys = ["a", "F"]
	flies = false


func generate() -> bool:
	launch = {"m": pick(1.0, 4.0, 0.1)}
	exhaust = pick(10.0, 60.0, 1.0)
	burn_rate = pick(0.2, 2.0, 0.1)
	fuel = pick(0.2, launch["m"] * 0.7, 0.05)
	var thrust := exhaust * burn_rate
	correct = [thrust / launch["m"], thrust / (launch["m"] - fuel)]
	return true


func question() -> String:
	return "A %s kg rocket bird (fuel included) burns %s kg of fuel at ṁ = %s kg/s, exhaust speed v_e = %s m/s.\nWhat is the acceleration from the thrust at the start of the burn, and at the end?" % [n(launch["m"]), n(fuel), n(burn_rate), n(exhaust)]


func solution_steps() -> Array[String]:
	var thrust := exhaust * burn_rate
	return [
		"Thrust:  F = v_e·ṁ = %s·%s = %s N  (the same all through the burn)" % [n(exhaust), n(burn_rate), n(thrust)],
		"Start:  a = F / m₀ = %s / %s = %s m/s²" % [n(thrust), n(launch["m"]), n(correct[0])],
		"End:    a = F / (m₀ − fuel) = %s / %s = %s m/s²" % [n(thrust), n(launch["m"] - fuel), n(correct[1])],
		"Same push, less mass to push: the acceleration grows as the fuel burns.",
	]
