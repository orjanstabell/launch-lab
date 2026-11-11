class_name ActionCamOverlay
extends Node2D
## Shown while the action cam is on (the topic's own arrows hide meanwhile).
## Three views of the collision, on both the bird and the pig, live:
## "forces":
##   gravity  m·g, straight down
##   contact  F = m·Δv/Δt − m·g  (whatever pushes it besides gravity: the other
##            body during the hit, the ground holding it up afterwards)
## The hit itself lasts about one physics step, so the biggest contact force is
## kept on screen as a faded "peak" arrow. Contact forces in a hit are hundreds
## of times bigger than gravity, so arrow lengths use a log scale; the labels
## give the true values.
## "velocities": each body's velocity v (m/s).
## "momentum": each body's p = m·v, and their total Σp at the middle: with no
## outside push it stays the same through the hit.

const GRAVITY_COLOR := Color(0.75, 0.45, 1.0)
const CONTACT_COLOR := Color(1.0, 0.55, 0.3)

var bird: Bird:
	set(value):
		bird = value
		_peaks.clear()
var pig: Pig
var view := "forces"

var _peaks := {}   # "bird" / "pig" -> the biggest contact force seen (Vector2, N)


func _process(_delta: float):
	if visible:
		queue_redraw()


func _draw():
	var k := DrawUtil.size_factor(self)
	if view == "velocities" or view == "momentum":
		_draw_motion(k)
		return
	if is_instance_valid(bird):
		_forces(bird.position, bird.mass_now(), bird.segment.g, bird.contact_force, "bird", -1.0, k)
	if is_instance_valid(pig):   # (even if the hit just knocked it out: it fades for a moment)
		_forces(pig.position, pig.mass, PhysicsParams.world_gravity(), pig.contact_force, "pig", 1.0, k)
	_caption("forces (log-scale arrows)")


## Velocity or momentum arrows on both bodies (linear scale: they're comparable sizes).
func _draw_motion(k: float):
	var momentum := view == "momentum"
	var total := Vector2.ZERO
	var points := []
	if is_instance_valid(bird):
		var v: Vector2 = bird.velocity_m()
		var amount: Vector2 = bird.mass_now() * v if momentum else v
		total += bird.mass_now() * v
		points.append(bird.position)
		_linear_arrow(bird.position, amount, Color(1.0, 0.5, 0.4), "ball: %s %s" % [Reveal.num(amount.length(), ["p" if momentum else "v"]), "kg·m/s" if momentum else "m/s"], -1.0, k)
	if is_instance_valid(pig):   # (even if the hit just knocked it out: it fades for a moment)
		var v := Units.to_m(pig.linear_velocity)
		var amount: Vector2 = pig.mass * v if momentum else v
		total += pig.mass * v
		points.append(pig.position)
		if amount.length() > 0.05:
			_linear_arrow(pig.position, amount, Color(0.6, 1.0, 0.4), "can: %s %s" % [Reveal.num(amount.length(), ["p" if momentum else "v"]), "kg·m/s" if momentum else "m/s"], 1.0, k)
	if momentum and points.size() == 2:
		var middle: Vector2 = (points[0] + points[1]) / 2.0 + Vector2(0, -90) * k
		_linear_arrow(middle, total, Color.WHITE, "Σp = %s kg·m/s" % Reveal.num(total.length(), ["p"]), 1.0, k)
	_caption("momentum p = m·v" if momentum else "velocities")


func _linear_arrow(from: Vector2, amount: Vector2, color: Color, text: String, side: float, k: float):
	var tip := from + Vector2(amount.x, -amount.y) * 8.0 * k
	DrawUtil.arrow(self, from, tip, color)
	DrawUtil.label(self, tip, Vector2(8 * side, 4), text, color, side < 0.0)


func _caption(what: String):
	var corner := (bird.position if is_instance_valid(bird) else Vector2.ZERO)
	DrawUtil.label(self, corner, Vector2(-160, -150), "ACTION CAM · slow motion · " + what, Color.WHITE)


## side: −1 puts the labels to the left (the bird), +1 to the right (the pig).
func _forces(at: Vector2, mass: float, g: float, contact: Vector2, who: String, side: float, k: float):
	var weight := Vector2(0, -mass * g)
	_arrow(at, weight, GRAVITY_COLOR, "gravity on %s: %s N" % [who, Reveal.num(weight.length(), ["F"], 1)], side, k)
	if contact.length() > _peaks.get(who, Vector2.ZERO).length():
		_peaks[who] = contact
	var peak: Vector2 = _peaks.get(who, Vector2.ZERO)
	if peak.length() > 1.5 * maxf(contact.length(), 1.0):
		_arrow(at, peak, Color(CONTACT_COLOR, 0.45), "peak contact on %s: %s N" % [who, Reveal.num(peak.length(), ["F"], 0)], side, k)
	if contact.length() > 0.5:
		_arrow(at, contact, CONTACT_COLOR, "contact on %s: %s N" % [who, Reveal.num(contact.length(), ["F"], 0)], side, k)


## Arrow length grows with log₁₀ of the force, so 10 N and 3000 N both fit.
func _arrow(from: Vector2, force: Vector2, color: Color, text: String, side: float, k: float):
	var length := DrawUtil.log_arrow_length(force.length()) * k
	var tip := from + Vector2(force.x, -force.y).normalized() * length
	DrawUtil.arrow(self, from, tip, color)
	DrawUtil.label(self, tip, Vector2(8 * side, 4), text, color, side < 0.0)
