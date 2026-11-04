class_name Pig
extends RigidBody2D
## The target. Dies when something hits it hard enough; a big pig survives one hit.
## "Hard enough" = the impulse it receives in one physics step is above its
## threshold. Impulse = change in momentum, Δp = m·Δv (kg·m/s), so we measure it
## straight from how much the pig's velocity changed. A heavier or faster hit
## counts more, and so does a fall: landing from the tower is a hit from the ground.

signal died

const RADIUS_M := 0.4
const BIG_RADIUS_M := 0.6
const KILL_IMPULSE := 2.5   # kg·m/s
const BIG_KILL_IMPULSE := 4.0
const GRACE_TIME := 0.5   # ignore hits right after spawning, while the level settles
const HURT_TIME := 0.4   # after a hit it survives, one hit can't count twice
const FADE_TIME := 0.5   # how long a defeated pig takes to fade away
const BIG_MASS := 3.0   # default; levels can set their own (Levels tab: "big pig mass")

var big := false
var radius_m := RADIUS_M
var hits_left := 1
var pig_mass := 1.0

var _age := 0.0
var _dead := false
var _hurt_for := 0.0
var _last_velocity := Vector2.ZERO   # m/s, from the previous physics step
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
		queue_redraw()   # now wearing a bandage
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
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func _draw():
	var r := radius_m * Units.PIXELS_PER_METER
	draw_circle(Vector2.ZERO, r, Color(0.4, 0.72, 0.22) if big else Color(0.45, 0.8, 0.25))
	draw_circle(Vector2(0, r * 0.15), r * 0.35, Color(0.35, 0.65, 0.18))   # snout
	draw_circle(Vector2(-r * 0.12, r * 0.15), r * 0.08, Color(0.15, 0.3, 0.05))
	draw_circle(Vector2(r * 0.12, r * 0.15), r * 0.08, Color(0.15, 0.3, 0.05))
	for side in [-1, 1]:
		draw_circle(Vector2(side * r * 0.4, -r * 0.35), r * 0.18, Color.WHITE)
		draw_circle(Vector2(side * r * 0.4, -r * 0.35), r * 0.08, Color.BLACK)
	if big and hits_left < 2:   # took a hit: a bandage on the forehead
		var band := Rect2(-r * 0.45, -r * 0.8, r * 0.9, r * 0.22)
		draw_set_transform(Vector2.ZERO, 0.4)
		draw_rect(band, Color(0.95, 0.9, 0.8))
		draw_set_transform(Vector2.ZERO, -0.4)
		draw_rect(band, Color(0.95, 0.9, 0.8))
		draw_set_transform(Vector2.ZERO)
