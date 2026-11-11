class_name Pig
extends RigidBody2D
## The target: a can (the big one is a drum). Knocked out when something hits it
## hard enough; a drum survives one hit. (The code still calls it a pig.)
## "Hard enough" = the impulse it receives in one physics step is above its
## threshold. Impulse = change in momentum, Δp = m·Δv (kg·m/s), so we measure it
## straight from how much the pig's velocity changed. A heavier or faster hit
## counts more, and so does a fall: landing from the tower is a hit from the ground.

signal died
signal dented   # a drum took a hit it survives

const RADIUS_M := 0.4
const BIG_RADIUS_M := 0.6
const KILL_IMPULSE := 2.5   # kg·m/s
const BIG_KILL_IMPULSE := 4.0
const GRACE_TIME := 0.5   # ignore hits right after spawning, while the level settles
const HURT_TIME := 0.4   # after a hit it survives, one hit can't count twice
const FADE_TIME := 0.5   # how long a defeated pig takes to fade away
const INK := Color(0.09, 0.09, 0.12)
const CAN_METAL := Color(0.82, 0.84, 0.88)
const CAN_STRIPE := Color(0.86, 0.22, 0.2)
const DRUM_METAL := Color(0.55, 0.62, 0.72)
const DRUM_STRIPE := Color(0.98, 0.78, 0.15)
const BIG_MASS := 3.0   # default; levels can set their own (Levels tab: "drum mass")

var big := false
var radius_m := RADIUS_M
var hits_left := 1
var pig_mass := 1.0

var _age := 0.0
var _dead := false
var _hurt_for := 0.0
var _last_velocity := Vector2.ZERO   # m/s, from the previous physics step
var _crumple := 0.0:   # 0 → 1 while a knocked-out can flattens
	set(value):
		_crumple = value
		queue_redraw()
## The force from contact (not gravity) this physics step, in newtons:
## F = m·Δv/Δt − m·g. Resting on the ground it's m·g upwards: the normal force.
var contact_force := Vector2.ZERO


## mass_kg = 0 means the default (1 kg, or 3 kg for a big pig).
func _init(is_big := false, mass_kg := 0.0):
	big = is_big
	radius_m = BIG_RADIUS_M if big else RADIUS_M
	hits_left = 2 if big else 1
	pig_mass = mass_kg if mass_kg > 0.0 else (BIG_MASS if big else 1.0)


func _ready():
	add_to_group("pigs")   # so overlays and the level can find every pig
	add_to_group("all_pigs")   # stays while a knocked-out pig fades, so its arrows can too
	var shape := CircleShape2D.new()
	shape.radius = radius_m * Units.PIXELS_PER_METER
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	mass = pig_mass
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.8
	collision_layer = Layers.BLOCKS
	collision_mask = Layers.GROUND | Layers.BLOCKS | Layers.BIRD


func _physics_process(delta: float):
	_age += delta
	_hurt_for -= delta
	var velocity := Units.to_m(linear_velocity)
	# Δp this step, ignoring what gravity alone (free fall) or the ground alone
	# (holding it up) does: each is m·g·Δt per step, which for a heavy pig is above
	# the threshold. Free fall: Δv = g·Δt. Resting: Δv = 0 while gravity pulls.
	# A real hit is far bigger than both, so take the smaller of the two readings.
	var change := velocity - _last_velocity
	var from_gravity := Vector2(0, -PhysicsParams.world_gravity() * delta)
	var impulse := mass * minf(change.length(), (change - from_gravity).length())
	contact_force = mass * (change - from_gravity) / delta
	_last_velocity = velocity
	take_impulse(impulse)


## A hit of size `impulse` (kg·m/s). Also called by a bird that hit this pig: by
## Newton's 3rd law the push the pig got equals the bird's change in momentum,
## which catches hits the pig's own Δp can't see, like being squashed against
## the ground (it can't move, so its velocity barely changes).
func take_impulse(impulse: float):
	if _dead or _age < GRACE_TIME or _hurt_for > 0.0:
		return
	if impulse <= (BIG_KILL_IMPULSE if big else KILL_IMPULSE):
		return
	hits_left -= 1
	if hits_left > 0:
		_hurt_for = HURT_TIME
		queue_redraw()   # now dented
		dented.emit()
		return
	_dead = true
	_die.call_deferred()


## Leave the game (out of the "pigs" group, no more collisions) and fade away.
func _die():
	remove_from_group("pigs")
	collision_layer = 0
	collision_mask = Layers.GROUND
	died.emit()
	var tween := create_tween()
	tween.tween_property(self, "_crumple", 1.0, FADE_TIME * 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func _draw():
	var r := radius_m * Units.PIXELS_PER_METER
	var line := maxf(0.11 * r, 2.0)
	# Knocked out: it crumples flat onto the ground (squashed along the world's
	# up-down, whichever way it had rolled) while it fades.
	if _crumple > 0.0:
		draw_set_transform(Vector2(0, r * 0.85 * _crumple).rotated(-rotation), -rotation, Vector2(1.0 + 0.35 * _crumple, 1.0 - 0.85 * _crumple))
	# A can seen end-on (the big one is a drum): a metal disc with a rim, and a
	# bold stripe across it, so you can see it roll. No face: it's a target.
	draw_circle(Vector2.ZERO, r + line * 0.5, INK)
	draw_circle(Vector2.ZERO, r - line * 0.5, DRUM_METAL if big else CAN_METAL)
	draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 32, INK, line * 0.5, true)
	var stripe := r * (0.3 if big else 0.36)
	draw_line(Vector2(-r + line, 0), Vector2(r - line, 0), DRUM_STRIPE if big else CAN_STRIPE, stripe)
	if big:
		for side in [-1.0, 1.0]:
			draw_line(Vector2(-r * 0.8, side * r * 0.5), Vector2(r * 0.8, side * r * 0.5), INK, line * 0.5)
	if big and hits_left < 2:   # took a hit: a flat dent on one side, which stays
		var dent := PackedVector2Array()
		for i in 9:
			dent.append(Vector2.from_angle(lerpf(-0.75, 0.75, i / 8.0) - PI / 2.0) * (r + line * 0.6))
		draw_colored_polygon(dent, INK)
	draw_set_transform(Vector2.ZERO)
