extends Node
## Hide the numbers behind any symbol, so you have to work them out yourself
## (e.g. hide g, randomize it, then measure the arc to find it).
##
## Every display formats its numbers through num(), listing the symbols the
## number depends on. If any of them is hidden, it shows "?" instead. So hiding
## g also hides ½·g = 4.91 in the y(t) formula, which would give g away.

signal changed

## Symbol key -> how it's written. The first five match PhysicsParams' keys.
const SYMBOLS := {
	"g": "g", "v0": "v₀", "theta": "θ", "y0": "y₀", "m": "m",
	"t": "t", "x": "x", "y": "y", "vx": "vx", "vy": "vy", "v": "|v|", "F": "F", "a": "a", "p": "p",
	"k": "k", "pull": "Δx", "E": "E",   # E covers KE, PE and the total
	"fuel": "m_fuel",   # the rocket bird's fuel
	"predict": "Predictions",   # the dotted path, and where/when/how high it lands
}

var hidden := {}


func _init():
	for key in SYMBOLS:
		hidden[key] = false


func set_hidden(key: String, on: bool):
	if hidden[key] == on:
		return
	hidden[key] = on
	changed.emit()


func is_hidden(key: String) -> bool:
	return hidden[key]


func any_hidden(keys: Array) -> bool:
	for key in keys:
		if hidden[key]:
			return true
	return false


func show_all():
	for key in SYMBOLS:
		hidden[key] = false
	changed.emit()


## Give each hidden launch value a random number. Stays away from the extremes
## of each range (e.g. g = 0, which never lands), and snaps to the slider step.
func randomize_hidden():
	for key in PhysicsParams.DEFINITIONS:
		if is_hidden(key):
			var def: Dictionary = PhysicsParams.DEFINITIONS[key]
			var value := lerpf(def["min"], def["max"], randf_range(0.1, 0.9))
			if def.has("random"):
				value = randf_range(def["random"][0], def["random"][1])
			PhysicsParams.set_value(key, snappedf(value, def["step"]))
	for key in PhysicsParams.SPRING_DEFINITIONS:   # k and Δx, for spring launches
		if is_hidden(key):
			var def: Dictionary = PhysicsParams.SPRING_DEFINITIONS[key]
			PhysicsParams.set_spring_value(key, snappedf(lerpf(def["min"], def["max"], randf_range(0.1, 0.6)), def["step"]))


## Like num(), but for numbers that change every frame: always `decimals`
## decimals, padded on the left to `width` characters. In a monospace font the
## number then keeps the same width as it changes, so the text doesn't wobble.
func live(value: float, depends_on: Array, width := 6, decimals := 2) -> String:
	var text := "?"
	if not any_hidden(depends_on):
		text = "∞" if is_inf(value) else ("%." + str(decimals) + "f") % _no_negative_zero(value, decimals)
	return text.lpad(width)


## `value` as text, or "?" if any symbol in `depends_on` is hidden.
func num(value: float, depends_on: Array, decimals := 2) -> String:
	if any_hidden(depends_on):
		return "?"
	if is_inf(value):
		return "∞"
	return String.num(_no_negative_zero(value, decimals), decimals)


## A tiny rounding error like −0.000001 would show as "-0.00": make it 0.
func _no_negative_zero(value: float, decimals: int) -> float:
	return 0.0 if absf(value) < 0.5 * pow(10.0, -decimals) else value
