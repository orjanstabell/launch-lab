class_name Pig
extends RigidBody2D
## The target: a crash-test dummy, head and shoulders (the big one is stockier,
## with a sandbag torso: it's heavier). Knocked out when something hits it hard
## enough; a big dummy survives one hit. (The code still calls it a pig.)
## "Hard enough" = the impulse it receives in one physics step is above its
## threshold. Impulse = change in momentum, Δp = m·Δv (kg·m/s), so we measure it
## straight from how much the pig's velocity changed. A heavier or faster hit
## counts more, and so does a fall: landing from the tower is a hit from the ground.

signal died
signal dented   # a big dummy took a hit it survives

const RADIUS_M := 0.4
const BIG_RADIUS_M := 0.6
const KILL_IMPULSE := 2.5   # kg·m/s
const BIG_KILL_IMPULSE := 4.0
const GRACE_TIME := 0.5   # ignore hits right after spawning, while the level settles
const HURT_TIME := 0.4   # after a hit it survives, one hit can't count twice
const FADE_TIME := 0.5   # how long a defeated pig takes to fade away
const INK := Color(0.09, 0.09, 0.12)
const DUMMY_SKIN := Color(0.98, 0.8, 0.3)
const SUIT := Color(0.3, 0.33, 0.4)
const SANDBAG := Color(0.78, 0.66, 0.45)
const TAG_FLOOR := 0.8   # kg·m/s: smaller pushes (resting, rolling) get no tag
const TAG_TIME := 1.5   # seconds a hit's "J = ..." tag stays
const TAG_HIT := Color(1.0, 0.45, 0.35)
const SCARED_DISTANCE_M := 4.0   # the ball this close: eyes wide, mouth open
const BIG_MASS := 3.0   # default; levels can set their own (Editor tab: "Big dummy mass")

var big := false
var radius_m := RADIUS_M
var hits_left := 1
var pig_mass := 1.0

var _age := 0.0
var _dead := false
var _hurt_for := 0.0
var _last_velocity := Vector2.ZERO   # m/s, from the previous physics step
var _crumple := 0.0:   # 0 → 1 while a knocked-out dummy flattens
	set(value):
		_crumple = value
		queue_redraw()
## The force from contact (not gravity) this physics step, in newtons:
## F = m·Δv/Δt − m·g. Resting on the ground it's m·g upwards: the normal force.
var contact_force := Vector2.ZERO
var _tag_impulse := 0.0   # the biggest push in the hit being shown (kg·m/s)
var _tag_for := 0.0   # seconds the tag still shows
var _tag: Node2D   # draws the tag level, whichever way the dummy has rolled


## mass_kg = 0 means the default (1 kg, or 3 kg for a big pig).
func _init(is_big := false, mass_kg := 0.0):
	big = is_big
	radius_m = BIG_RADIUS_M if big else RADIUS_M
	hits_left = 2 if big else 1
	pig_mass = mass_kg if mass_kg > 0.0 else (BIG_MASS if big else 1.0)


func _ready():
	add_to_group("pigs")   # so overlays and the level can find every pig
	add_to_group("all_pigs")   # stays while a knocked-out pig fades, so its arrows can too
	_tag = Node2D.new()
	_tag.draw.connect(_draw_tag)
	add_child(_tag)
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
	queue_redraw()   # the eyes follow the ball
	if _tag_for > 0.0:
		_tag_for -= delta
		_tag.rotation = -rotation
		_tag.queue_redraw()


## A hit of size `impulse` (kg·m/s). Also called by a bird that hit this pig: by
## Newton's 3rd law the push the pig got equals the bird's change in momentum,
## which catches hits the pig's own Δp can't see, like being squashed against
## the ground (it can't move, so its velocity barely changes).
func take_impulse(impulse: float):
	if _dead or _age < GRACE_TIME:
		return
	if impulse > TAG_FLOOR and (_tag_for <= 0.0 or impulse > _tag_impulse):
		_tag_impulse = impulse
		_tag_for = TAG_TIME
	if _hurt_for > 0.0:
		return
	if impulse <= threshold():
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


## The impulse (kg·m/s) one hit must beat to count.
func threshold() -> float:
	return BIG_KILL_IMPULSE if big else KILL_IMPULSE


func _draw():
	var r := radius_m * Units.PIXELS_PER_METER
	var line := maxf(0.11 * r, 2.0)
	# Knocked out: it crumples flat onto the ground (squashed along the world's
	# up-down, whichever way it had rolled) while it fades.
	if _crumple > 0.0:
		draw_set_transform(Vector2(0, r * 0.85 * _crumple).rotated(-rotation), -rotation, Vector2(1.0 + 0.35 * _crumple, 1.0 - 0.85 * _crumple))
	# A crash-test dummy, head and shoulders, with the black-and-white target
	# sticker on its chest (so you can see it roll). It watches the slingshot,
	# follows the ball in the air, and goes wide-eyed when it's close.
	# The torso: the bottom of the circle, topped by shoulders that slope up to the
	# neck. The big one's are broader and higher (a stocky sandbag torso).
	var edge := 0.1 if big else 0.32   # where the shoulders meet the circle (y, in radii)
	var rise := 0.42 if big else 0.36   # how much higher the neck is than that
	var torso := _arc_points(r, asin(edge), PI - asin(edge))
	var half := sqrt(1.0 - edge * edge)
	for i in range(1, 12):
		var x := lerpf(-half, half, i / 12.0)
		torso.append(Vector2(x, edge - rise * (1.0 - pow(x / half, 2))) * r)
	draw_colored_polygon(torso, SANDBAG if big else SUIT)
	torso.append(torso[0])
	draw_polyline(torso, INK, line, true)
	if big:   # the sandbag's stitching
		for y in [0.35, 0.65]:
			draw_dashed_line(Vector2(-r * 0.7, r * y), Vector2(r * 0.7, r * y), INK, line * 0.4, line * 1.2)
		if hits_left < 2:   # took a hit: a split seam, sand spilling, which stays
			draw_polyline(PackedVector2Array([Vector2(-r * 0.55, r * 0.15), Vector2(-r * 0.4, r * 0.3), Vector2(-r * 0.6, r * 0.45), Vector2(-r * 0.42, r * 0.6)]), INK, line * 0.7, true)
			for dot in [Vector2(-0.62, 0.72), Vector2(-0.5, 0.8), Vector2(-0.68, 0.86)]:
				draw_circle(dot * r, line * 0.45, SANDBAG.darkened(0.3))
	_draw_sticker(Vector2(r * 0.3, r * (0.5 if big else 0.6)), r * (0.2 if big else 0.17), line * 0.5)
	var head_r := r * (0.5 if big else 0.6)
	var head := Vector2(0, -r + head_r + line * 0.5)
	draw_circle(head, head_r + line * 0.5, INK)
	draw_circle(head, head_r - line * 0.5, DUMMY_SKIN)
	# The face, on the side towards the slingshot.
	var look := _look_direction()
	var scared := not _dead and _ball_near()
	for x in [-0.6, -0.08]:
		var eye := head + Vector2(x, -0.08) * head_r
		if _dead:
			var s := head_r * 0.18
			draw_line(eye - Vector2(s, s), eye + Vector2(s, s), INK, line * 0.6)
			draw_line(eye + Vector2(-s, s), eye + Vector2(s, -s), INK, line * 0.6)
			continue
		var size := head_r * (0.3 if scared else 0.22)
		draw_circle(eye, size + line * 0.4, INK)
		draw_circle(eye, size, Color.WHITE)
		draw_circle(eye + look * size * 0.45, size * 0.5, INK)
	var mouth := head + Vector2(-0.34, 0.5) * head_r
	if scared:
		draw_circle(mouth, head_r * 0.16, INK)
	else:
		draw_line(mouth - Vector2(head_r * 0.22, 0), mouth + Vector2(head_r * 0.22, 0), INK, line * 0.6)
	draw_set_transform(Vector2.ZERO)


## The last hit's impulse over the dummy, red if it counted (it beat the threshold).
func _draw_tag():
	if _tag_for <= 0.0:
		return
	var counted := _tag_impulse > threshold()
	var fade := minf(1.0, _tag_for / 0.4)
	var text := "J = %s N·s" % String.num(_tag_impulse, 1)
	DrawUtil.label(_tag, Vector2(0, -radius_m * Units.PIXELS_PER_METER), Vector2(-30, -10), text, Color(TAG_HIT if counted else Color.WHITE, fade))


## The crash-test target: a disc in black and white quarters.
func _draw_sticker(at: Vector2, size: float, line: float):
	draw_circle(at, size + line, INK)
	draw_circle(at, size, Color.WHITE)
	for quarter in [0.0, PI]:
		var pie := PackedVector2Array([at])
		for point in _arc_points(size, quarter, quarter + PI / 2.0, 6):
			pie.append(at + point)
		draw_colored_polygon(pie, INK)


func _arc_points(r: float, from: float, to: float, steps := 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		points.append(Vector2.from_angle(lerpf(from, to, float(i) / steps)) * r)
	return points


## Where the eyes look (in the dummy's own turned frame): at the ball in the air, else at the slingshot.
func _look_direction() -> Vector2:
	var bird = PhysicsParams.bird
	var world := Vector2.LEFT
	if is_instance_valid(bird) and bird.state == Bird.State.FLYING:
		world = (bird.global_position - global_position).normalized()
	return world.rotated(-global_rotation)


func _ball_near() -> bool:
	var bird = PhysicsParams.bird
	return is_instance_valid(bird) and bird.state == Bird.State.FLYING and bird.global_position.distance_to(global_position) < SCARED_DISTANCE_M * Units.PIXELS_PER_METER
