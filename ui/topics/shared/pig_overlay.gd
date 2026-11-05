class_name PigOverlay
extends Node2D
## Arrows on every pig, including one that has just been knocked out (while it
## fades, so you still see what the hit did to it):
## "forces":
##   gravity  m·g, straight down
##   contact  F = m·Δv/Δt − m·g: whatever touches it besides gravity. Resting on
##            a plank or the ground it's the normal force, m·g straight up, so
##            the two arrows cancel (no acceleration). In a hit it's huge.
##            A hit lasts about one physics step, so the biggest push stays on
##            screen for a moment as a faded "hit" arrow.
##   The force arrows grow with log(F) (DrawUtil.log_arrow_length), like the
##   action cam's: a hit fits on screen, and a resting pig's arrows stay short
##   enough to end above the dock instead of under it.
## "velocity": its velocity v, while it moves.

const PX_PER_MPS := 20.0   # the same as the bird's (VelocityOverlay)
const MAX_ARROW := 350.0   # px at 1×; longer arrows are shortened (the labels keep the true value)
const GRAVITY_COLOR := Color(0.75, 0.45, 1.0)
const CONTACT_COLOR := Color(1.0, 0.55, 0.3)
const VELOCITY_COLOR := Color(0.6, 1.0, 0.4)
const HIT_SHOWN_FOR := 1.0   # seconds (game time) a hit's peak push stays on screen
const SMOOTHING := 0.3   # resting contact forces jitter a little from step to step

var mode := "forces"

var _contact := {}   # pig -> smoothed contact force (N)
var _hits := {}   # pig -> {"force": N, "age": s}


func _init(arrow_mode := "forces"):
	mode = arrow_mode


func _process(delta: float):
	# Follow the forces even while hidden, so switching to this tab (e.g. while
	# paused) shows a resting pig's normal force at once, not just its gravity.
	if mode == "forces" and not get_tree().paused:
		_follow_forces(delta * Engine.time_scale)
	if visible:
		queue_redraw()


## Smooth each pig's contact force, and remember its biggest recent push.
func _follow_forces(delta: float):
	for pig: Pig in get_tree().get_nodes_in_group("all_pigs"):
		var raw := pig.contact_force
		_contact[pig] = _contact.get(pig, raw).lerp(raw, SMOOTHING)
		var weight := pig.mass * PhysicsParams.world_gravity()
		var hit: Dictionary = _hits.get(pig, {"force": Vector2.ZERO, "age": INF})
		hit["age"] += delta
		if raw.length() > 3.0 * maxf(weight, 1.0) and (hit["age"] > HIT_SHOWN_FOR or raw.length() > hit["force"].length()):
			hit = {"force": raw, "age": 0.0}
		_hits[pig] = hit
	for pig in _contact.keys():   # forget pigs that are gone
		if not is_instance_valid(pig):
			_contact.erase(pig)
			_hits.erase(pig)


func _draw():
	var k := DrawUtil.size_factor(self)
	for pig: Pig in get_tree().get_nodes_in_group("all_pigs"):
		var fade := pig.modulate.a
		if mode == "velocity":
			var v := Units.to_m(pig.linear_velocity)
			if v.length() > 0.1:
				_arrow(pig.position, v * PX_PER_MPS, Color(VELOCITY_COLOR, fade), "v pig = %s m/s" % Reveal.num(v.length(), ["v"]), k)
			continue
		var weight := Vector2(0, -pig.mass * PhysicsParams.world_gravity())
		var left := pig.position + Vector2(-8, 0) * k
		var right := pig.position + Vector2(8, 0) * k
		_arrow(left, _log_scaled(weight), Color(GRAVITY_COLOR, fade), "", k)
		DrawUtil.label(self, left, Vector2(-16, 4), "gravity %s N" % Reveal.num(weight.length(), ["F"], 1), Color(GRAVITY_COLOR, fade), true)   # beside the pig, not under the ground
		var hit: Dictionary = _hits.get(pig, {})
		if not hit.is_empty() and hit["age"] < HIT_SHOWN_FOR:
			var faded: float = fade * (1.0 - hit["age"] / HIT_SHOWN_FOR)
			_arrow(right, _log_scaled(hit["force"]), Color(CONTACT_COLOR, 0.5 * faded), "hit: %s N" % Reveal.num(hit["force"].length(), ["F"], 0), k)
		var contact: Vector2 = _contact.get(pig, pig.contact_force)
		if contact.length() > 0.3:
			_arrow(right, _log_scaled(contact), Color(CONTACT_COLOR, fade), "contact %s N" % Reveal.num(contact.length(), ["F"], 1), k)


## `amount` in px at 1× (y up); shortened to MAX_ARROW.
func _arrow(from: Vector2, amount: Vector2, color: Color, text: String, k: float):
	var length := minf(amount.length(), MAX_ARROW) * k
	var tip := from + Vector2(amount.x, -amount.y).normalized() * length
	DrawUtil.arrow(self, from, tip, color)
	if text != "":
		DrawUtil.label(self, tip, Vector2(8, 4), text, color)


## A force (N) as an arrow in px at 1×, on the log scale.
func _log_scaled(force: Vector2) -> Vector2:
	return force.normalized() * DrawUtil.log_arrow_length(force.length())
