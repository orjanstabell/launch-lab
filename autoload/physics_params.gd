extends Node
## The parameters you edit in the panel, and the bird they control.
##
## values:    the LAUNCH values. Every new bird starts with these.
## bird_type: which bird the next launch uses (see BirdTypes): this decides
##            what Activate (Space, mid-air) does.
## ability:   for birds whose ability is "change": what the bird switches to on
##            Activate. Only the keys ticked in `ability_on` are changed.
## split:     for the blue bird: how it splits.
## target:    a point (meters) for solve mode: "which launch hits this?"
## launch_mode: "speed" (set v₀ directly) or "spring" (set the slingshot's spring
##             constant k and pull Δx; v₀ then follows from the energy balance
##             ½·k·Δx² = ½·m·v₀², so v₀ = Δx·√(k/m)).

signal values_changed   # a launch value, ability setting or bird type was edited
signal flight_changed   # a bird launched, used its ability, or stopped following the formulas
signal launch_requested   # any UI can ask main to launch a bird
signal reset_requested   # ... or to reset the level
signal announced(text: String)   # a big message over the sky (e.g. quiz results)
@warning_ignore("unused_signal")   # emitted by Bird
signal bird_near_pig(bird: Bird, pig: Pig)   # a bird's proximity sensor found a pig (for the action cam)

const DEFINITIONS := {
	"g": {"label": "Gravity", "symbol": "g", "unit": "m/s²", "default": 9.81, "min": 0.0, "max": 30.0, "step": 0.01},
	"v0": {"label": "Speed", "symbol": "v₀", "unit": "m/s", "default": 15.0, "min": 1.0, "max": 40.0, "step": 0.1},
	# Negative angles aim downward (useful from a raised launch point). "random"
	# is the range Randomize uses, so a hidden angle stays a sensible upward shot.
	"theta": {"label": "Angle", "symbol": "θ", "unit": "°", "default": 45.0, "min": -90.0, "max": 90.0, "step": 0.5, "random": [15.0, 75.0]},
	"y0": {"label": "Height", "symbol": "y₀", "unit": "m", "default": 1.0, "min": 0.0, "max": 10.0, "step": 0.1},
	"m": {"label": "Mass", "symbol": "m", "unit": "kg", "default": 1.0, "min": 0.1, "max": 10.0, "step": 0.1},
}

## The slingshot as a spring (launch_mode "spring").
const SPRING_DEFINITIONS := {
	"k": {"label": "Spring k", "symbol": "k", "unit": "N/m", "default": 400.0, "min": 20.0, "max": 3000.0, "step": 1.0},
	"pull": {"label": "Pull Δx", "symbol": "Δx", "unit": "m", "default": 0.75, "min": 0.05, "max": 2.0, "step": 0.01},
}

## The rocket bird's engine: how much fuel it carries (part of m), how fast the
## exhaust leaves, and how fast it burns. Thrust F = v_e·ṁ; Δv = v_e·ln(m₀/m₁).
const ROCKET_DEFINITIONS := {
	"fuel": {"label": "Fuel", "symbol": "m_fuel", "unit": "kg", "default": 0.5, "min": 0.05, "max": 9.0, "step": 0.05},
	"exhaust": {"label": "Exhaust speed", "symbol": "v_e", "unit": "m/s", "default": 30.0, "min": 5.0, "max": 200.0, "step": 1.0},
	"burn_rate": {"label": "Burn rate", "symbol": "ṁ", "unit": "kg/s", "default": 1.0, "min": 0.1, "max": 10.0, "step": 0.1},
}

## The Dropper's egg: its mass (part of m) and how fast she throws it down, relative
## to herself. Momentum is conserved, so the throw kicks her up.
const EGG_DEFINITIONS := {
	"mass": {"label": "Ballast mass", "symbol": "m_b", "unit": "kg", "default": 0.4, "min": 0.05, "max": 9.0, "step": 0.05},
	"speed": {"label": "Throw speed (relative)", "symbol": "u", "unit": "m/s", "default": 15.0, "min": 1.0, "max": 60.0, "step": 0.5},
}

## What the ability can change, with its own defaults and limits. Mid-air the
## angle can point downwards (a dive), and the speed can be 0 (stop and drop).
## y₀ is where the slingshot holds the bird, so it only exists at launch.
const ABILITY_DEFINITIONS := {
	"g": {"default": 3.0, "min": 0.0, "max": 30.0},
	"v0": {"default": 30.0, "min": 0.0, "max": 40.0},
	"theta": {"default": -30.0, "min": -90.0, "max": 90.0},
	"m": {"default": 5.0, "min": 0.1, "max": 10.0},
}

var values := {}
var bird_type := "red"
var ability := {}
var ability_on := {}
const DEFAULT_SPLIT := {"pieces": 3, "spread": 12.0, "conserve": true, "speed": -1.0}   # spread: ± degrees from the heading; speed: practice problems force the pieces' speed (−1 = normal)
const DEFAULT_TARGET := Vector2(25.0, 2.3)
const DEFAULT_ELASTICITY := 0.2

var split := DEFAULT_SPLIT.duplicate()
var target := DEFAULT_TARGET
var launch_mode := "speed"
var spring := {}
var rocket := {}
var egg := {}
var collision := {}   # the last bird-hits-something snapshot (see Bird._record_collision)
## How bouncy the bird's collisions are (coefficient of restitution): 0 = they
## stick together, 1 = perfectly elastic (no kinetic energy lost). The bird
## carries it; pigs, blocks and the ground add (almost) none.
var elasticity := DEFAULT_ELASTICITY

# While a practice problem is open:
var inputs_locked := false   # the parameter panel can't change the values the problem set up
var manual_launch_allowed := true   # Space / the Launch button (false: only the problem launches)
var show_level := true   # false: an empty world (practice problems), so nothing blocks the shot
var bird: Bird = null   # the most recently launched bird, flying or not (null if none)


func _init():
	reset_to_defaults()


## Every setting back to how the game starts. A level is loaded on top of this,
## so nothing is left over from the level (or the fiddling) before it.
func reset_to_defaults():
	for key in DEFINITIONS:
		values[key] = DEFINITIONS[key]["default"]
	for key in ABILITY_DEFINITIONS:
		ability[key] = ABILITY_DEFINITIONS[key]["default"]
		ability_on[key] = false
	for key in SPRING_DEFINITIONS:
		spring[key] = SPRING_DEFINITIONS[key]["default"]
	for key in ROCKET_DEFINITIONS:
		rocket[key] = ROCKET_DEFINITIONS[key]["default"]
	for key in EGG_DEFINITIONS:
		egg[key] = EGG_DEFINITIONS[key]["default"]
	egg["straight_down"] = false   # true: she throws it back as well, so it falls straight down on screen
	egg["back_speed"] = -1.0   # practice problems: throw it back at exactly this speed (m/s, relative); −1 = use straight_down
	split = DEFAULT_SPLIT.duplicate()
	bird_type = "red"
	launch_mode = "speed"
	elasticity = DEFAULT_ELASTICITY
	target = DEFAULT_TARGET
	values_changed.emit()


func set_value(key: String, value: float):
	var def: Dictionary = DEFINITIONS[key]
	value = clampf(value, def["min"], def["max"])
	if is_equal_approx(values[key], value):
		return
	values[key] = value
	if key == "m":
		_update_spring_speed()   # a heavier bird leaves the same spring slower
	values_changed.emit()


func set_launch_mode(mode: String):
	launch_mode = mode
	_update_spring_speed()
	values_changed.emit()


func set_spring_value(key: String, value: float):
	var def: Dictionary = SPRING_DEFINITIONS[key]
	spring[key] = clampf(value, def["min"], def["max"])
	_update_spring_speed()
	values_changed.emit()


## The launch speed the spring gives: ½·k·Δx² = ½·m·v₀²  →  v₀ = Δx·√(k/m).
## (Assumes all the spring's energy goes into the bird, and the release is instant.)
func spring_speed() -> float:
	return spring["pull"] * sqrt(spring["k"] / values["m"])


## In spring mode, v₀ isn't set directly: it follows from k, Δx and m.
func _update_spring_speed():
	if launch_mode == "spring":
		var def: Dictionary = DEFINITIONS["v0"]
		values["v0"] = clampf(spring_speed(), def["min"], def["max"])


## Pick the bird for the next launch. If it has a preset, it fills in the
## On Activate column (ticks exactly the preset's values).
func set_bird_type(type: String):
	bird_type = type
	var preset: Dictionary = BirdTypes.TYPES[type].get("preset", {})
	if not preset.is_empty():
		for key in ability_on:
			ability_on[key] = preset.has(key)
		for key in preset:
			ability[key] = preset[key]
	values_changed.emit()


func set_ability_value(key: String, value: float):
	var def: Dictionary = ABILITY_DEFINITIONS[key]
	value = clampf(value, def["min"], def["max"])
	if is_equal_approx(ability[key], value):
		return
	ability[key] = value
	values_changed.emit()


func set_ability_on(key: String, on: bool):
	if ability_on[key] == on:
		return
	ability_on[key] = on
	values_changed.emit()


func set_rocket_value(key: String, value: float):
	var def: Dictionary = ROCKET_DEFINITIONS[key]
	rocket[key] = clampf(value, def["min"], def["max"])
	values_changed.emit()


func set_egg_value(key: String, value: float):
	var def: Dictionary = EGG_DEFINITIONS[key]
	egg[key] = clampf(value, def["min"], def["max"])
	values_changed.emit()


func set_egg_straight_down(on: bool):
	egg["straight_down"] = on
	values_changed.emit()


## Practice problems: force the backward throw speed (−1 = back to normal).
func set_egg_back_speed(speed: float):
	egg["back_speed"] = speed
	values_changed.emit()


## The egg can be at most 90% of the Dropper's mass.
func usable_egg_mass(bird_mass: float) -> float:
	return minf(egg["mass"], 0.9 * bird_mass)


## The fuel a burn can actually use: at most 90% of the bird's mass.
func usable_fuel(bird_mass: float) -> float:
	return minf(rocket["fuel"], 0.9 * bird_mass)


func set_elasticity(e: float):
	elasticity = clampf(e, 0.0, 1.0)
	values_changed.emit()


## Kept in range like the other settings, so a hand-edited level file can't
## break the split (e.g. 1 piece would divide by zero when fanning them out).
func set_split(key: String, value: Variant):
	if not split.has(key):
		return
	match key:
		"pieces":
			value = clampi(int(value), 2, 5)
		"spread":
			value = clampf(float(value), 0.0, 90.0)
		"conserve":
			value = bool(value)
		"speed":
			value = float(value)
	split[key] = value
	values_changed.emit()


func request_launch():
	launch_requested.emit()


func request_reset():
	reset_requested.emit()


func set_inputs_locked(locked: bool, allow_manual_launch := true):
	inputs_locked = locked
	manual_launch_allowed = allow_manual_launch
	values_changed.emit()


func announce(text: String):
	announced.emit(text)


func set_target(point: Vector2):
	target = Vector2(maxf(point.x, 0.5), maxf(point.y, 0.0))   # in front of the slingshot, not underground
	values_changed.emit()


## Snapshot of the launch values, for launching a new bird.
func launch_params() -> LaunchParams:
	return LaunchParams.from_dict(values)


## True while a bird is following the formulas (launched, not crashed yet).
func is_flying() -> bool:
	return is_instance_valid(bird) and bird.state == Bird.State.FLYING


## True if pressing Activate right now would do something.
func can_activate() -> bool:
	return is_flying() and bird.can_activate()


## Use the flying bird's ability.
func activate():
	if not can_activate():
		return
	bird.activate()
	flight_changed.emit()


## Gravity for Godot's own physics (blocks, pig, crashed bird): the bird's g while
## one is around, otherwise the launch g.
func world_gravity() -> float:
	if is_instance_valid(bird):
		return bird.segment.g
	return values["g"]


## Called by the bird itself.
func start_flight(new_bird: Bird):
	bird = new_bird
	flight_changed.emit()


func end_flight(old_bird: Bird):
	if bird == old_bird:
		bird = null
	flight_changed.emit()
