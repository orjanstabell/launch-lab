class_name Problem
extends RefCounted
## One kind of practice problem. To add a new kind: extend this class, set the
## variables in _init(), override generate(), question() and solution_steps(),
## then add the script to ProblemTypes.ALL.
##
## Two kinds:
##   "predict": you work out a number (where it lands, a force...). Check flies
##              the shot and shows your answer in the world next to what really
##              happens: a flag at your x, a line at your height, or a see-through
##              "ghost" bird flying the path your number gives. Then it says how
##              close you were (outcome()).
##   "control": you choose launch value(s) to make something happen (hit the
##              pigs). Try it launches once with them and judges the shot.
## Either kind: an answer with a "key" sets that value for the shot (so for a
## predict problem the real bird can use your number, e.g. the split speed).

const HIT_TOLERANCE_M := 0.5   # the bird's center passing this close to a target counts as a hit

var topic := ""   # "Kinematics", "Forces", "Momentum"...
var title := ""   # shown in the problem picker
var kind := "predict"
## What you type: {"label", "unit", "min", "max", "step"}. For control problems
## also "key" (the launch value it sets) or "tap": true (when to use the ability).
var answers: Array[Dictionary] = []
var correct: Array[float] = []   # the right answer(s), same order as `answers`
var tolerance_percent := 2.0   # predict: how close counts as right
var hidden_keys: Array[String] = []   # Reveal symbols hidden while the problem is open
var launch := {}   # launch values for the scene (PhysicsParams keys), plus "mode": "spring" with "k" and "pull"
var bird_type := "red"
var ability := {}   # ticked ability values for "change" birds, e.g. {"g": 0.0}
var targets: Array[Vector2] = []   # pigs to hit (meters)
var flies := true   # predict: fly the shot on Check (and when the solution is shown)
var show_com := false   # draw the pieces' center of mass (split problems)
var demo_shot := false   # fire one shot as soon as the problem opens, to watch and measure
var rng := RandomNumberGenerator.new()


## Override: pick random values and fill in launch, targets, correct...
## Return false if this try isn't usable (e.g. the answer is outside the slider
## range); the panel then simply calls it again.
func generate() -> bool:
	return true


func question() -> String:
	return ""


## The worked solution, one line per step.
func solution_steps() -> Array[String]:
	return []


## predict: is each number close enough to the right answer?
func is_correct(given: Array[float]) -> bool:
	for i in correct.size():
		if absf(given[i] - correct[i]) > maxf(absf(correct[i]) * tolerance_percent / 100.0, 0.01):
			return false
	return true


## control: the launch your answers make (answers with a "key" set that launch value).
func shot_launch(given: Array[float]) -> LaunchParams:
	var changes := {}
	for i in answers.size():
		if answers[i].has("key"):
			changes[answers[i]["key"]] = given[i]
	return launch_with(changes)


## control: did the shot work? Returns {"ok", "message"}. Default: the path
## passes every target.
func judge(given: Array[float]) -> Dictionary:
	var p := shot_launch(given)
	for target in targets:
		var closest := Kinematics.closest_approach(p, target)
		if closest.y > HIT_TOLERANCE_M:
			var passed := Kinematics.position(p, closest.x)
			var which := "" if targets.size() == 1 else (" can %d" % (targets.find(target) + 1))
			return {"ok": false, "message": "✗ Missed%s by %s m: passed %s it" % [which, n(closest.y, 1), "above" if passed.y > target.y else "below"]}
	return {"ok": true, "message": "✓ Hit!" if targets.size() <= 1 else "✓ Hit them all!"}


## control: how long to watch the shot before judging it (flight time, seconds).
func watch_time(given: Array[float]) -> float:
	var p := shot_launch(given)
	var latest := 0.0
	for target in targets:
		latest = maxf(latest, Kinematics.closest_approach(p, target).x)
	return latest if not targets.is_empty() else minf(Kinematics.time_of_flight(p), 30.0)


## control: when to use the ability automatically (flight time), or INF for never.
func tap_time(given: Array[float]) -> float:
	for i in answers.size():
		if answers[i].get("tap", false):
			return given[i]
	return INF


## predict: launch-value changes to fly with after a right answer (default: none).
func fly_changes(_given: Array[float]) -> Dictionary:
	return {}


## predict: what happened to your answer in the simulation, shown after the
## shot ("landed 2.1 m beyond your flag"). "" = just right or wrong.
func outcome(_given: Array[float]) -> String:
	return ""


## predict: see-through birds flying what your answer says would happen, next to
## the real bird. Each part: {"params", "start" (seconds after launch), "until"
## (seconds, INF = until it lands), "label"}; one ghost can be several parts
## with the same label (a rocket burn, then coasting). Use ghost() to make one.
func ghosts(_given: Array[float]) -> Array[Dictionary]:
	return []


## The correct path(s) to draw when the solution is shown:
## [{"params": LaunchParams, "until": seconds}]. Override for multi-part paths.
func solution_paths() -> Array[Dictionary]:
	var p := solution_launch()
	if p == null:
		return []
	return [{"params": p, "until": INF}]


## The launch with the right answer(s) filled in. null = nothing to draw.
func solution_launch() -> LaunchParams:
	return null


## Extra things to draw in the world. `given` = the answers you last checked
## (empty if none yet). Each is a dictionary with "type" and "label":
##   "height": a dashed line at y = "value"      "x": a flag at x = "value"
##   "point": a dot at "pos"                     "arrow": "vector" (meters) from "pos"
##   "clock": a running t = ... next to the bird, stopping at "until"
## "point" and "arrow" can have "at": they appear that many seconds into the shot.
## "arrow" has "who": "you" or "real" (its colour).
func markers(_given: Array[float]) -> Array[Dictionary]:
	return []


# --- Helpers for subclasses ---

## A random number between low and high, rounded to `step` (so it's nice to work with).
func pick(low: float, high: float, step: float) -> float:
	return snappedf(rng.randf_range(low, high), step)


## A random g: usually Earth's, sometimes another value.
func pick_gravity() -> float:
	return 9.81 if rng.randf() < 0.6 else pick(3.0, 15.0, 0.1)


## The problem's launch values as LaunchParams, with `changes` applied (e.g. {"v0": 16.4}).
## Anything the problem doesn't set keeps LaunchParams' default. (No autoloads
## here, so problems stay pure and easy to test.)
func launch_with(changes := {}) -> LaunchParams:
	var values := launch.duplicate()
	values.merge(changes, true)
	var p := LaunchParams.new()
	for key in values:
		match key:
			"g": p.g = values[key]
			"v0": p.v0 = values[key]
			"theta": p.theta_deg = values[key]
			"y0": p.y0 = values[key]
			"m": p.m = values[key]
	# Spring launch: v₀ follows from ½·k·Δx² = ½·m·v₀².
	if values.get("mode", "speed") == "spring" and not changes.has("v0"):
		p.v0 = values["pull"] * sqrt(values["k"] / p.m)
	return p


## One ghost part (see ghosts()).
static func ghost(params: LaunchParams, label: String, start := 0.0, until := INF) -> Dictionary:
	return {"params": params, "label": label, "start": start, "until": until}


## A projectile starting at `pos` with velocity `vel` (for ghosts that start mid-flight).
static func launch_from(pos: Vector2, vel: Vector2, g: float, m := 1.0) -> LaunchParams:
	var p := LaunchParams.new()
	p.x0 = pos.x
	p.y0 = pos.y
	p.v0 = vel.length()
	p.theta_deg = rad_to_deg(atan2(vel.y, vel.x))
	p.g = g
	p.m = m
	return p


## A rocket bird's path if it fires at `fire_time` and burns `fuel`, as ghost
## parts: the burn, then coasting. It burns for as long as the real rocket
## (launch's "rocket_fuel" / "rocket_burn_rate"), just faster or slower, so it
## pulls ahead or falls behind from the moment it fires. (Δv only depends on the
## mass ratio, not on how fast the fuel burns.)
func rocket_ghost(fire_time: float, fuel: float, label: String) -> Array[Dictionary]:
	var p := launch_with()
	var burn := launch_from(Kinematics.position(p, fire_time), Kinematics.velocity(p, fire_time), p.g, p.m)
	var used := clampf(fuel, 0.0, 0.9 * p.m)
	if used > 0.0001:
		burn.thrust_dir = Kinematics.velocity(p, fire_time).normalized()
		burn.exhaust_speed = launch["rocket_exhaust"]
		burn.burn_time = minf(launch["rocket_fuel"], 0.9 * p.m) / launch["rocket_burn_rate"]
		burn.burn_rate = used / burn.burn_time
	return [ghost(burn, label, fire_time, burn.burn_time), ghost(Kinematics.after_burn(burn), label, fire_time + burn.burn_time)]


## "12% too big", "3% too small" or "spot on".
static func percent_off(value: float, right: float, big := "too big", small := "too small") -> String:
	var off := (value - right) / right * 100.0 if right != 0.0 else 0.0
	if absf(off) < 0.5:
		return "spot on"
	return "%d%% %s" % [roundi(absf(off)), big if off > 0.0 else small]


## "2.1 m beyond" / "0.4 m short of": how far `actual` is from `yours` along x.
static func distance_off(actual: float, yours: float, more: String, less: String, unit := "m") -> String:
	var d := actual - yours
	if absf(d) < 0.05:
		return "right on"
	return "%s %s %s" % [n(absf(d), 1), unit, more if d > 0.0 else less]


static func n(x: float, decimals := 2) -> String:
	return String.num(x, decimals)
