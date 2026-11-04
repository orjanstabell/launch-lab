class_name Bird
extends RigidBody2D
## While FLYING, the bird is NOT simulated by Godot. Every physics frame its
## position is computed straight from the formulas in kinematics.gd.
##
## Activate (Space, mid-air) depends on the bird type (see BirdTypes):
##   "change": start a NEW formula segment from where the bird is right now, with
##             a new g, speed (same direction), angle (same speed) and/or mass.
##   "split":  the blue bird splits into pieces, each on its own formula segment.
##   "rocket": burns fuel along its heading; the segment's formula includes the
##             rocket equation, and the bird gets lighter as it burns.
##   "egg":    Matilda throws an egg straight down and recoils up; bird and egg
##             each get their own segment (like a split into two unequal pieces).
##
## On the first hit, a bird becomes a normal RigidBody2D with the formula's
## velocity at that moment, and Godot physics handles the crash.

enum State { FLYING, PHYSICS }

const MAX_FLIGHT_TIME := 30.0   # give up on birds that never come down (g = 0)
const SENSOR_RADIUS_M := 2.5   # the proximity sensor: notices pigs this close (for the action cam)
const PHYSICS_TRAIL_TIME := 4.0   # keep drawing the trail this long after the hit

var state := State.FLYING
var type := "red"   # key into BirdTypes.TYPES
var radius_m := 0.3
var segment: LaunchParams   # the formula the bird follows right now (its g and m are the bird's too)
var segment_history: Array[LaunchParams] = []   # every segment so far, including the current one
var t := 0.0   # seconds since the current segment started
var flight_time := 0.0   # seconds since launch
var activations := 0
var trail: Trail
var hit_position := Vector2.INF   # meters: where it first hit something (INF = hasn't yet)
var exhaust: RocketExhaust = null   # the rocket bird's exhaust puffs, once it fires
## The force from contact (not gravity) this physics step, in newtons:
## F = m·Δv/Δt − m·g. Zero while flying on the formula (only gravity acts then).
var contact_force := Vector2.ZERO
var _previous_velocity := Vector2.INF
var activate_at := INF   # flight time at which to use the ability automatically (practice problems)

# Blue bird split
var is_piece := false   # an extra piece from a split (not the bird you launched)
var pieces: Array[Bird] = []   # after a split: every piece, this bird included
var pre_split: LaunchParams   # the segment the bird was on when it split
var split_t := 0.0   # time on pre_split at the moment of the split
var split_flight_time := 0.0   # flight_time at the moment of the split
var _sync_to: Bird = null   # a new piece: on its first step, catch up with the bird it split from
var split_info := {}   # momentum and energy before/after, for the Momentum topic

var _shape := CircleShape2D.new()
var _time_since_hit := 0.0
var _collision_pending := false   # waiting to record "just after" the hit
var _collision_frames := 0
const COLLISION_MAX_FRAMES := 8   # give up waiting for the hit to show after this many steps


## Call before add_child().
func setup(launch_values: Dictionary, bird_type: String, trail_node: Trail):
	type = bird_type
	radius_m = BirdTypes.TYPES[type]["radius"]
	segment = LaunchParams.from_dict(launch_values)
	segment_history.append(segment)
	trail = trail_node


## For the extra pieces of a split: start straight on `piece_segment`. Call before add_child().
func setup_piece(piece_segment: LaunchParams, bird_type: String, trail_node: Trail, flight_time_so_far: float):
	type = bird_type
	radius_m = BirdTypes.TYPES[type]["radius"]
	segment = piece_segment
	segment_history.append(segment)
	trail = trail_node
	flight_time = flight_time_so_far
	is_piece = true


func _ready():
	_shape.radius = radius_m * Units.PIXELS_PER_METER
	var collision := CollisionShape2D.new()
	collision.shape = _shape
	add_child(collision)

	mass = segment.m   # mass plays no part in the path, only in the crash (and a rocket's burn)
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.6
	physics_material_override.bounce = PhysicsParams.elasticity   # (Godot adds both bodies' bounce; pigs have none)

	# In flight, Godot physics leaves the bird alone: frozen, and on no collision layers.
	freeze = true
	collision_layer = 0
	collision_mask = 0

	position = Units.to_px(Kinematics.position(segment, 0.0))
	trail.start_formula_segment(position)
	_add_sensor()
	if not is_piece:
		PhysicsParams.start_flight(self)


## A second, much bigger circle that touches nothing: it only notices pigs
## nearby, so the action cam can zoom in before the hit.
func _add_sensor():
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = Layers.BLOCKS
	var circle := CircleShape2D.new()
	circle.radius = SENSOR_RADIUS_M * Units.PIXELS_PER_METER
	var shape := CollisionShape2D.new()
	shape.shape = circle
	sensor.add_child(shape)
	sensor.body_entered.connect(_on_sensor_entered)
	add_child(sensor)


func _on_sensor_entered(body: Node2D):
	if body is Pig and state == State.FLYING:
		PhysicsParams.bird_near_pig.emit(self, body)


func _exit_tree():
	if not is_piece:
		PhysicsParams.end_flight(self)


func _physics_process(delta: float):
	match state:
		State.FLYING:
			_fly(delta)
		State.PHYSICS:
			_update_physics_trail(delta)
			var velocity := Units.to_m(linear_velocity)
			if _previous_velocity != Vector2.INF:
				contact_force = mass * ((velocity - _previous_velocity) / delta - Vector2(0, -segment.g))
			_previous_velocity = velocity
	if global_position.x > 4000 or global_position.x < -1000 or global_position.y > 2000:
		queue_free()   # far off screen


## Velocity in m/s (y up), whoever is in control.
func velocity_m() -> Vector2:
	if state == State.FLYING:
		return Kinematics.velocity(segment, t)
	return Units.to_m(linear_velocity)


## The mass right now (a rocket bird gets lighter while it burns).
func mass_now() -> float:
	return Kinematics.mass_at(segment, t) if state == State.FLYING else mass


## True while a rocket is firing.
func burning() -> bool:
	return state == State.FLYING and segment.is_rocket() and t < segment.burn_time


## This bird's energy in joules: Vector2(kinetic, potential).
## KE = ½·m·v², PE = m·g·y with y measured from the ground and the bird's own g.
func energy() -> Vector2:
	var v := velocity_m()
	var m := mass_now()
	return Vector2(0.5 * m * v.length_squared(), m * segment.g * Units.to_m(position).y)


## The whole bird's energy: after a blue bird split, all the pieces together.
func total_energy() -> Vector2:
	if pieces.is_empty():
		return energy()
	var total := Vector2.ZERO
	for piece in pieces:
		if is_instance_valid(piece):
			total += piece.energy()
	return total


## The energy it was launched with (KE + PE at t = 0 of the first segment).
func launch_energy() -> float:
	var first := segment_history[0]
	return 0.5 * first.m * first.v0 * first.v0 + first.m * first.g * first.y0


func ability_kind() -> String:
	return BirdTypes.TYPES[type]["ability"]


## True if Activate would do something right now.
func can_activate() -> bool:
	if state != State.FLYING or is_piece:
		return false
	match ability_kind():
		"change":
			return PhysicsParams.ability_on.values().has(true)
		"split":
			return pieces.is_empty()   # only once
		"rocket":
			return activations == 0   # one burn
		"egg":
			return pieces.is_empty()   # one egg
	return false


func activate():
	if not can_activate():
		return
	match ability_kind():
		"change":
			_start_segment(next_segment())
		"split":
			_split()
		"egg":
			_drop_egg()
		"rocket":
			_start_segment(rocket_segment())
			exhaust = RocketExhaust.new()
			exhaust.bird = self
			trail.get_parent().add_child(exhaust)   # cleared with the trails on the next launch


## The segment(s) Activate would start right now, for the yellow preview path.
func preview_segments() -> Array[LaunchParams]:
	var result: Array[LaunchParams] = []
	if can_activate():
		match ability_kind():
			"split":
				result = split_segments()
			"rocket":
				result.append(rocket_segment())
			"egg":
				result = egg_segments()
			_:
				result.append(next_segment())
	return result


## For "change" birds: the segment Activate would start right now.
## Starts from the bird's current position and velocity, then swaps in
## whatever the ability changes.
func next_segment() -> LaunchParams:
	var ability := PhysicsParams.ability
	var on := PhysicsParams.ability_on
	var pos := Kinematics.position(segment, t)
	var vel := Kinematics.velocity(segment, t)

	var next := LaunchParams.new()
	next.x0 = pos.x
	next.y0 = pos.y
	next.v0 = ability["v0"] if on["v0"] else vel.length()   # new speed, same direction
	next.theta_deg = ability["theta"] if on["theta"] else rad_to_deg(atan2(vel.y, vel.x))   # new direction, same speed
	next.g = ability["g"] if on["g"] else segment.g
	next.m = ability["m"] if on["m"] else mass_now()
	return next


## For the rocket bird: the segment Activate would start right now. It fires
## along the current heading (that direction stays fixed during the burn).
func rocket_segment() -> LaunchParams:
	var settings := PhysicsParams.rocket
	var pos := Kinematics.position(segment, t)
	var vel := Kinematics.velocity(segment, t)
	var m := mass_now()
	var next := LaunchParams.new()
	next.x0 = pos.x
	next.y0 = pos.y
	next.v0 = vel.length()
	next.theta_deg = rad_to_deg(atan2(vel.y, vel.x))
	next.g = segment.g
	next.m = m
	next.thrust_dir = vel.normalized() if vel.length() > 0.01 else Vector2(0, 1)
	next.exhaust_speed = settings["exhaust"]
	next.burn_rate = settings["burn_rate"]
	next.burn_time = PhysicsParams.usable_fuel(m) / settings["burn_rate"]
	return next


## For the blue bird: one segment per piece if it split right now.
## The pieces fan out evenly from −spread to +spread around the current heading,
## and share the mass equally.
func split_segments() -> Array[LaunchParams]:
	var settings := PhysicsParams.split
	var count: int = settings["pieces"]
	var spread: float = settings["spread"]
	var pos := Kinematics.position(segment, t)
	var vel := Kinematics.velocity(segment, t)
	var heading := rad_to_deg(atan2(vel.y, vel.x))

	var offsets: Array[float] = []
	for i in count:
		offsets.append(lerpf(-spread, spread, float(i) / (count - 1)))

	# Momentum p = m·v must be the same just before and just after the split:
	# it happens in an instant, so no outside force has time to change p.
	# Each piece has m/n, and only cos(offset) of its speed points along the old
	# heading (the sideways parts cancel out, since the fan is symmetric). So:
	#   m·v = Σ (m/n)·v'·cos(offsetᵢ)   →   v' = n·v / Σ cos(offsetᵢ)
	# The pieces must speed UP. The real game skips this (v' = v) and loses momentum.
	var speed := vel.length()
	if settings.get("speed", -1.0) >= 0.0:   # a practice problem: your answer for v'
		speed = settings["speed"]
	elif settings["conserve"]:
		var cos_sum := 0.0
		for offset in offsets:
			cos_sum += cos(deg_to_rad(offset))
		speed *= count / cos_sum

	var result: Array[LaunchParams] = []
	for offset in offsets:
		var piece := LaunchParams.new()
		piece.x0 = pos.x
		piece.y0 = pos.y
		piece.v0 = speed
		piece.theta_deg = heading + offset
		piece.g = segment.g
		piece.m = mass_now() / count
		result.append(piece)
	return result


func _split():
	var count: int = PhysicsParams.split["pieces"]
	_break_up(split_segments(), int(count / 2.0), type, {"kind": "split", "pieces": count, "spread": PhysicsParams.split["spread"]})


## For Matilda: [her segment, the egg's segment] if she threw the egg right now.
## The throw happens in an instant, so momentum is conserved. Downwards, the egg
## leaves at speed u relative to her:
##   m_egg·Δv_egg + m_bird·Δv_bird = 0   and   Δv_egg − Δv_bird = u·(down)
##   →  Δv_bird = (m_egg/m)·u up,   Δv_egg = (m_bird/m)·u down
## Sideways she can also throw it backwards, at speed w relative to herself.
## The same two rules give:  her vₓ' = vₓ + (m_egg/m)·w,  the egg's = vₓ − (m_bird/m)·w
##   w = 0 ("let go"): the egg keeps her forward speed vₓ
##   w = vₓ·m/m_bird ("straight down", like in the game): the egg has no forward
##        speed, and she speeds up to vₓ' = vₓ·m/m_bird
## (A practice problem can set w directly: PhysicsParams.egg["back_speed"].)
func egg_segments() -> Array[LaunchParams]:
	var m := mass_now()
	var egg_mass := PhysicsParams.usable_egg_mass(m)
	var bird_mass := m - egg_mass
	var throw_speed: float = PhysicsParams.egg["speed"]
	var pos := Kinematics.position(segment, t)
	var vel := Kinematics.velocity(segment, t)
	var down := Vector2(0, -1)
	var bird_velocity := vel - down * (egg_mass / m) * throw_speed
	var egg_velocity := vel + down * (bird_mass / m) * throw_speed
	var back_speed: float = PhysicsParams.egg["back_speed"]
	if back_speed < 0.0:
		back_speed = vel.x * m / bird_mass if PhysicsParams.egg["straight_down"] else 0.0
	bird_velocity.x = vel.x + (egg_mass / m) * back_speed
	egg_velocity.x = vel.x - (bird_mass / m) * back_speed
	var result: Array[LaunchParams] = []
	for part in [[bird_mass, bird_velocity], [egg_mass, egg_velocity]]:
		var piece := LaunchParams.new()
		var v: Vector2 = part[1]
		piece.x0 = pos.x
		piece.y0 = pos.y
		piece.v0 = v.length()
		piece.theta_deg = rad_to_deg(atan2(v.y, v.x))
		piece.g = segment.g
		piece.m = part[0]
		result.append(piece)
	return result


func _drop_egg():
	_break_up(egg_segments(), 0, "egg", {"kind": "egg", "pieces": 2, "egg_speed": PhysicsParams.egg["speed"], "straight_down": PhysicsParams.egg["straight_down"]})


## Break into pieces (a split, or Matilda and her egg): note momentum and energy
## before and after for the Momentum topic, keep the old segment as the
## "unsplit" reference, carry on as piece `keep`, and launch the others as new
## birds of `other_type`.
func _break_up(new_segments: Array[LaunchParams], keep: int, other_type: String, info: Dictionary):
	var v_before := Kinematics.velocity(segment, t)
	var p_after := Vector2.ZERO
	var ke_after := 0.0
	for piece_segment in new_segments:
		var v := Kinematics.initial_velocity(piece_segment)
		p_after += piece_segment.m * v
		ke_after += 0.5 * piece_segment.m * v.length_squared()
	split_info = info
	split_info.merge({
		"p_before": mass_now() * v_before,
		"p_after": p_after,
		"ke_before": 0.5 * mass_now() * v_before.length_squared(),
		"ke_after": ke_after,
		"speed_before": v_before.length(),
		"speed_after": new_segments[keep].v0,
		"masses": new_segments.map(func(piece): return piece.m),
	})
	pre_split = segment
	split_t = t
	split_flight_time = flight_time

	pieces = [self]
	for i in new_segments.size():
		if i == keep:
			continue
		var piece_trail := Trail.new()
		trail.get_parent().add_child(piece_trail)
		var piece := Bird.new()
		piece.setup_piece(new_segments[i], other_type, piece_trail, flight_time)
		piece._sync_to = self
		get_parent().add_child(piece)
		pieces.append(piece)
	_start_segment(new_segments[keep])


func _start_segment(new_segment: LaunchParams):
	segment = new_segment
	segment_history.append(segment)
	t = 0.0
	mass = segment.m
	activations += 1
	trail.start_formula_segment(position)


func _fly(delta: float):
	# A new piece: the split happened partway through a step, and the bird it
	# split from has already done the rest of that step (maybe the next one too).
	# Take exactly that much time, so all the pieces share one clock.
	if _sync_to != null:
		if is_instance_valid(_sync_to) and _sync_to.flight_time > flight_time:
			delta = _sync_to.flight_time - flight_time
		_sync_to = null
	# A scheduled ability (e.g. "tap the yellow bird at t = 0.83 s"): move to that
	# exact moment first, use it there, then do the rest of this step.
	if flight_time + delta >= activate_at:
		var first_part := maxf(activate_at - flight_time, 0.0)
		activate_at = INF
		t += first_part
		flight_time += first_part
		position = Units.to_px(Kinematics.position(segment, t))
		trail.add_point(position)
		PhysicsParams.activate()
		delta -= first_part
	var next_t := t + delta
	var from := position
	var to := Units.to_px(Kinematics.position(segment, next_t))

	# Would the bird hit something on its way from `from` to `to` this frame?
	var hit_fraction := _cast_motion(from, to)
	# Backup for a bird that starts out touching the ground (y₀ = 0 and a flat angle):
	# the sweep ignores anything the bird already overlaps, so check the height directly.
	var falling := Kinematics.velocity(segment, t).y < 0.0
	if hit_fraction == 1.0 and falling and Kinematics.position(segment, next_t).y < radius_m:
		hit_fraction = 0.0
	if hit_fraction < 1.0:
		# Move up to the point of contact and let Godot physics take over from there.
		t += delta * hit_fraction
		flight_time += delta * hit_fraction
		position = from.lerp(to, hit_fraction)
		trail.add_point(position)
		_hand_over_to_physics()
		return

	t = next_t
	flight_time += delta
	position = to
	rotation = Units.to_px(Kinematics.velocity(segment, t)).angle()   # face where it's going
	if segment.is_rocket():
		queue_redraw()   # the flame comes and goes
	trail.add_point(position)

	if flight_time > MAX_FLIGHT_TIME:
		queue_free()


## Sweeps the bird's circle from `from` to `to` (local pixels).
## Returns how far along it can move before touching something: 1.0 = no hit.
func _cast_motion(from: Vector2, to: Vector2) -> float:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, get_parent().to_global(from))
	query.motion = to - from
	query.collision_mask = Layers.BLOCKS
	# Only check the ground on the way down, so a bird launched from y₀ = 0
	# (already touching the ground) isn't stopped right away.
	if Kinematics.velocity(segment, t).y < 0.0:
		query.collision_mask |= Layers.GROUND
	var result := get_world_2d().direct_space_state.cast_motion(query)
	return result[0]


func _hand_over_to_physics():
	mass = mass_now()   # (before the state changes: a rocket keeps the mass it has left)
	state = State.PHYSICS
	hit_position = Units.to_m(position)
	collision_layer = Layers.BIRD
	collision_mask = Layers.GROUND | Layers.BLOCKS
	freeze = false
	linear_velocity = Units.to_px(Kinematics.velocity(segment, t))
	trail.start_physics_segment(position)
	_record_collision()
	PhysicsParams.flight_changed.emit()


## If the bird just hit a pig or a block, note both bodies' velocities just
## before the hit (the bird's straight from the formula). Once the hit has
## actually happened (Godot resolves the contact a step or two later), the other
## body's velocity changes, and _check_collision_after() notes both again, so the
## Momentum and Energy topics can compare momentum and kinetic energy.
func _record_collision():
	var probe := CircleShape2D.new()
	probe.radius = _shape.radius + 3.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = Layers.BLOCKS
	var hits := get_world_2d().direct_space_state.intersect_shape(query, 1)
	if hits.is_empty():
		return   # hit the ground: it's attached to the Earth, so no comparison
	var other: RigidBody2D = hits[0]["collider"]
	var other_velocity: Vector2 = other._last_velocity if other is Pig else Units.to_m(other.linear_velocity)
	var bird_velocity := Kinematics.velocity(segment, t)
	PhysicsParams.collision = {
		"bird": self,
		"other": other,
		"other_name": "pig" if other is Pig else "block",
		"at": Units.to_m(position),
		"other_at": Units.to_m(other.position),
		"other_radius": other.radius_m if other is Pig else 0.0,
		"bird_m": mass_now(),
		"other_m": other.mass,
		"bird_before": bird_velocity,
		"other_before": other_velocity,
		"ke_before": 0.5 * mass_now() * bird_velocity.length_squared() + 0.5 * other.mass * other_velocity.length_squared(),
	}
	_collision_pending = true
	_collision_frames = 0


func _check_collision_after():
	var hit := PhysicsParams.collision
	if hit.get("bird") != self:
		_collision_pending = false
		return
	_collision_frames += 1
	var other: RigidBody2D = hit["other"]
	if not is_instance_valid(other):
		_collision_pending = false
		return
	var other_velocity := Units.to_m(other.linear_velocity)
	var other_changed := other_velocity.distance_to(hit["other_before"]) > 0.3
	if not other_changed and _collision_frames < COLLISION_MAX_FRAMES:
		return   # the push hasn't happened yet
	_collision_pending = false
	var bird_velocity := velocity_m()
	hit["bird_after"] = bird_velocity
	hit["other_after"] = other_velocity
	hit["duration"] = _collision_frames * get_physics_process_delta_time()   # how long the push took (≈ physics steps)
	# Measured elasticity: how fast they separate vs. how fast they approached,
	# along the line between their centers:  e = −(v₁' − v₂')·n / (v₁ − v₂)·n
	var normal: Vector2 = (hit["other_at"] - hit["at"]).normalized()
	var closing: float = (hit["bird_before"] - hit["other_before"]).dot(normal)
	if closing > 0.01:
		hit["measured_e"] = -(bird_velocity - other_velocity).dot(normal) / closing
	if other is Pig:
		other.take_impulse(hit["bird_m"] * (bird_velocity - hit["bird_before"]).length())
	hit["ke_after"] = 0.5 * hit["bird_m"] * bird_velocity.length_squared() + 0.5 * hit["other_m"] * other_velocity.length_squared()
	PhysicsParams.flight_changed.emit()


func _update_physics_trail(delta: float):
	if _collision_pending:
		_check_collision_after()
	_time_since_hit += delta
	if _time_since_hit < PHYSICS_TRAIL_TIME and not sleeping:
		trail.add_point(position)


func _draw():
	draw_bird(self, Vector2.ZERO, _shape.radius, type, burning())


## Shared with the slingshot, which draws a bird waiting to be launched.
## Every bird faces +x and is drawn from its BirdTypes entry ("shape" and
## "style"); it always collides as a plain circle.
static func draw_bird(canvas: CanvasItem, center: Vector2, radius: float, bird_type: String, flame := false):
	var info: Dictionary = BirdTypes.TYPES[bird_type]
	match info.get("shape", "round"):
		"triangle":
			_draw_yellow_bird(canvas, center, radius, info["color"])
		"matilda":
			_draw_matilda(canvas, center, radius, info["color"])
		"egg":
			_draw_egg(canvas, center, radius, info["color"])
		_:
			_draw_round_bird(canvas, center, radius, info["color"], info.get("style", {}), flame)


## The round birds, in the style of the classic ones: a black outline, a cream
## belly, two head feathers, black tail feathers, white eyes and a big beak.
## style: "brow" (a thick angry unibrow), "spots" (darker spots on the side),
## "cheeks" (orange patches under the eyes), "eyes" (eye size), "rocket" (a
## rocket strapped to its back; `flame` = it's firing). Sizes in units of `r`.
static func _draw_round_bird(canvas: CanvasItem, center: Vector2, r: float, color: Color, style: Dictionary, flame: bool):
	var at := func(x: float, y: float) -> Vector2: return center + Vector2(x, y) * r
	var shape := func(points: Array) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in points:
			result.append(at.call(point.x, point.y))
		return result
	var ink := Color(0.06, 0.05, 0.05)
	var line := maxf(0.07 * r, 1.0)

	# Tail feathers at the back, and two head feathers on top (drawn first, so the
	# body covers their roots).
	for feather in [[Vector2(-0.9, -0.05), Vector2(-1.45, -0.32), Vector2(-1.38, -0.12), Vector2(-0.9, 0.08)],
			[Vector2(-0.92, 0.05), Vector2(-1.5, 0.05), Vector2(-1.45, 0.22), Vector2(-0.92, 0.18)],
			[Vector2(-0.9, 0.15), Vector2(-1.35, 0.4), Vector2(-1.25, 0.5), Vector2(-0.88, 0.28)]]:
		canvas.draw_colored_polygon(shape.call(feather), ink)
	for tuft in [[Vector2(-0.25, -0.98), 0.3], [Vector2(0.12, -1.08), 0.27]]:
		canvas.draw_circle(at.call(tuft[0].x, tuft[0].y), tuft[1] * r + line, ink)
		canvas.draw_circle(at.call(tuft[0].x, tuft[0].y), tuft[1] * r, color)

	# Body with its outline, and the cream belly along the bottom.
	canvas.draw_circle(center, r + line, ink)
	canvas.draw_circle(center, r, color)
	var belly := []
	for i in 13:   # along the bottom of the body...
		var angle := lerpf(deg_to_rad(28.0), deg_to_rad(152.0), i / 12.0)
		belly.append(Vector2(cos(angle), sin(angle)))
	var left: Vector2 = belly[-1]
	var right: Vector2 = belly[0]
	for i in range(1, 12):   # ...and back along a curve that bulges up in the middle
		var f := i / 12.0
		belly.append(left.lerp(Vector2(0.0, 0.18), f).lerp(Vector2(0.0, 0.18).lerp(right, f), f))
	canvas.draw_colored_polygon(shape.call(belly), Color(0.89, 0.78, 0.66))
	if style.get("spots", false):
		for spot in [[Vector2(-0.55, 0.12), Vector2(0.11, 0.17)], [Vector2(-0.25, 0.08), Vector2(0.12, 0.22)]]:
			_ellipse(canvas, at.call(spot[0].x, spot[0].y), spot[1] * r, color.darkened(0.3))

	if style.get("rocket", false):
		_draw_rocket(canvas, at, shape, ink, line, flame)

	# Face, at the front: cheeks, eyes looking forward, brow, beak.
	var eye_size: float = style.get("eyes", 1.0)
	if style.get("cheeks", false):
		canvas.draw_colored_polygon(shape.call([Vector2(-0.05, 0.0), Vector2(0.98, -0.08), Vector2(1.0, 0.25), Vector2(0.0, 0.32)]), Color(0.85, 0.35, 0.15))
	for eye in [[Vector2(0.32, -0.12), 0.21], [Vector2(0.72, -0.12), 0.18]]:
		var size: float = eye[1] * eye_size * r
		canvas.draw_circle(at.call(eye[0].x, eye[0].y), size + line * 0.8, ink)
		canvas.draw_circle(at.call(eye[0].x, eye[0].y), size, Color.WHITE)
		canvas.draw_circle(at.call(eye[0].x, eye[0].y) + Vector2(size * 0.35, 0), size * 0.38, ink)
	if style.get("brow", false):
		canvas.draw_colored_polygon(shape.call([Vector2(0.08, -0.45), Vector2(0.52, -0.27), Vector2(0.98, -0.47), Vector2(1.0, -0.32), Vector2(0.52, -0.14), Vector2(0.1, -0.32)]), ink)
	var upper := [Vector2(0.36, 0.14), Vector2(0.62, 0.05), Vector2(1.22, 0.3), Vector2(0.45, 0.38)]
	var lower := [Vector2(0.42, 0.36), Vector2(1.08, 0.34), Vector2(0.58, 0.55)]
	canvas.draw_colored_polygon(shape.call(lower), Color(0.95, 0.55, 0.05))
	canvas.draw_colored_polygon(shape.call(upper), Color(1.0, 0.72, 0.1))
	for part in [upper, lower]:
		var edge: PackedVector2Array = shape.call(part)
		edge.append(edge[0])
		canvas.draw_polyline(edge, ink, line * 0.7, true)


## A little rocket strapped along the bird's back, pointing forward (where it
## pushes), with a flame from the nozzle while it fires.
static func _draw_rocket(canvas: CanvasItem, at: Callable, shape: Callable, ink: Color, line: float, flame: bool):
	var tube := [Vector2(-1.25, -0.98), Vector2(0.15, -0.98), Vector2(0.15, -0.62), Vector2(-1.25, -0.62)]
	if flame:
		var flicker := 1.0 + 0.3 * sin(Time.get_ticks_msec() * 0.05)
		canvas.draw_colored_polygon(shape.call([Vector2(-1.3, -0.95), Vector2(-1.3 - 1.1 * flicker, -0.8), Vector2(-1.3, -0.65)]), Color(1.0, 0.7, 0.15))
		canvas.draw_colored_polygon(shape.call([Vector2(-1.3, -0.88), Vector2(-1.3 - 0.6 * flicker, -0.8), Vector2(-1.3, -0.72)]), Color(1.0, 0.95, 0.7))
	canvas.draw_colored_polygon(shape.call([Vector2(-1.38, -1.02), Vector2(-1.25, -0.92), Vector2(-1.25, -0.68), Vector2(-1.38, -0.58)]), Color(0.3, 0.3, 0.33))   # nozzle
	canvas.draw_colored_polygon(shape.call([Vector2(-1.15, -0.98), Vector2(-1.45, -1.25), Vector2(-0.85, -0.98)]), Color(0.8, 0.12, 0.1))   # fins
	canvas.draw_colored_polygon(shape.call([Vector2(-1.15, -0.62), Vector2(-1.45, -0.35), Vector2(-0.85, -0.62)]), Color(0.8, 0.12, 0.1))
	canvas.draw_colored_polygon(shape.call(tube), Color(0.78, 0.8, 0.84))
	canvas.draw_colored_polygon(shape.call([Vector2(0.15, -0.98), Vector2(0.6, -0.8), Vector2(0.15, -0.62)]), Color(0.8, 0.12, 0.1))   # nose cone
	var outline: PackedVector2Array = shape.call([Vector2(-1.25, -0.98), Vector2(0.15, -0.98), Vector2(0.6, -0.8), Vector2(0.15, -0.62), Vector2(-1.25, -0.62), Vector2(-1.25, -0.98)])
	canvas.draw_polyline(outline, ink, line * 0.7, true)
	for strap_x in [-0.75, -0.2]:   # straps holding it on
		canvas.draw_line(at.call(strap_x, -0.98), at.call(strap_x + 0.1, -0.35), Color(0.35, 0.2, 0.1), line * 1.2)


static func _ellipse(canvas: CanvasItem, middle: Vector2, half_size: Vector2, color: Color):
	var points := PackedVector2Array()
	for i in 16:
		points.append(middle + Vector2(cos(i * TAU / 16.0) * half_size.x, sin(i * TAU / 16.0) * half_size.y))
	canvas.draw_colored_polygon(points, color)


## The yellow bird: an upright triangle (point up, flat bottom) facing forward
## (+x), with a white belly, angry brows, eyes and beak at the front, a feather
## tuft on top and tail feathers at the back. Sizes are in units of `r`.
static func _draw_yellow_bird(canvas: CanvasItem, center: Vector2, r: float, color: Color):
	var at := func(x: float, y: float) -> Vector2: return center + Vector2(x, y) * r
	var shape := func(points: Array) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in points:
			result.append(at.call(point.x, point.y))
		return result
	var ink := Color(0.08, 0.06, 0.04)

	# Feathers first, so the body covers their roots: a tuft on top, a tail behind.
	for feather in [
		[Vector2(-0.05, -1.05), Vector2(-0.85, -1.45), Vector2(-0.3, -1.3), Vector2(0.1, -1.15)],
		[Vector2(0.0, -1.1), Vector2(-0.45, -1.8), Vector2(-0.05, -1.45), Vector2(0.2, -1.1)],
		[Vector2(0.1, -1.1), Vector2(0.3, -1.65), Vector2(0.35, -1.2)],
		[Vector2(-0.8, 0.15), Vector2(-1.55, -0.3), Vector2(-1.2, 0.15), Vector2(-0.7, 0.35)],
		[Vector2(-0.8, 0.35), Vector2(-1.5, 0.2), Vector2(-1.15, 0.5), Vector2(-0.7, 0.55)],
	]:
		canvas.draw_colored_polygon(shape.call(feather), ink)

	# Body: a black outline, then the yellow triangle on top, both with rounded corners.
	var outline := _rounded([Vector2(0.05, -1.22), Vector2(1.28, 0.95), Vector2(-1.18, 0.95)], 0.32)
	var body := _rounded([Vector2(0.05, -1.08), Vector2(1.15, 0.87), Vector2(-1.05, 0.87)], 0.26)
	canvas.draw_colored_polygon(shape.call(outline), ink)
	canvas.draw_colored_polygon(shape.call(body), color)
	# A shine near the top, a shadow along the back edge, the white belly along the bottom.
	canvas.draw_colored_polygon(shape.call([Vector2(0.0, -0.78), Vector2(0.27, -0.45), Vector2(0.2, -0.36), Vector2(-0.05, -0.66)]), color.lightened(0.45))
	canvas.draw_colored_polygon(shape.call([Vector2(-0.6, 0.15), Vector2(-0.45, 0.87), Vector2(-0.8, 0.87), Vector2(-0.92, 0.7)]), color.darkened(0.25))
	canvas.draw_colored_polygon(shape.call([Vector2(-0.8, 0.87), Vector2(-0.5, 0.68), Vector2(0.0, 0.61), Vector2(0.55, 0.63), Vector2(0.9, 0.76), Vector2(0.92, 0.87)]), Color(0.97, 0.97, 0.95))

	# Eyes at the front, looking forward.
	for eye in [[Vector2(0.05, 0.3), 0.2], [Vector2(0.58, 0.27), 0.17]]:
		canvas.draw_circle(at.call(eye[0].x, eye[0].y), eye[1] * r + 0.06 * r, ink)
		canvas.draw_circle(at.call(eye[0].x, eye[0].y), eye[1] * r, Color.WHITE)
		canvas.draw_circle(at.call(eye[0].x + eye[1] * 0.45, eye[0].y), eye[1] * 0.4 * r, ink)
	# Angry brows, lower towards the middle.
	canvas.draw_colored_polygon(shape.call([Vector2(-0.24, -0.0), Vector2(0.3, 0.12), Vector2(0.28, 0.21), Vector2(-0.26, 0.1)]), Color(0.65, 0.2, 0.0))
	canvas.draw_colored_polygon(shape.call([Vector2(0.42, 0.14), Vector2(0.82, 0.03), Vector2(0.84, 0.12), Vector2(0.44, 0.23)]), Color(0.65, 0.2, 0.0))

	# The beak, just below the eyes, pointing forward.
	var upper := [Vector2(0.28, 0.5), Vector2(0.55, 0.42), Vector2(1.0, 0.58), Vector2(0.38, 0.62)]
	var lower := [Vector2(0.34, 0.62), Vector2(0.9, 0.6), Vector2(0.42, 0.74)]
	canvas.draw_colored_polygon(shape.call(upper), Color(1.0, 0.68, 0.0))
	canvas.draw_colored_polygon(shape.call(lower), Color(0.95, 0.55, 0.0))
	var edge: PackedVector2Array = shape.call(upper)
	edge.append(edge[0])
	canvas.draw_polyline(edge, ink, maxf(0.05 * r, 1.0), true)



## A convex polygon with its corners rounded off: each corner is replaced by a
## short curve starting `corner` (in units of r) along each edge.
static func _rounded(points: Array, corner: float) -> Array:
	var result := []
	for i in points.size():
		var here: Vector2 = points[i]
		var before: Vector2 = points[i - 1]
		var after: Vector2 = points[(i + 1) % points.size()]
		var start := here + (before - here).normalized() * corner
		var end := here + (after - here).normalized() * corner
		for step in 6:   # a quadratic curve from start to end, pulled toward the corner
			var f := step / 5.0
			result.append(start.lerp(here, f).lerp(here.lerp(end, f), f))
	return result



## An egg shape (wider at the bottom), as points in units of r around (0, 0).
static func _egg_outline(width: float, height: float, bulge: float) -> Array:
	var points := []
	for i in 32:
		var angle := i * TAU / 32.0
		var widen := 1.0 + bulge * sin(angle)   # sin > 0 is the bottom (screen y points down)
		points.append(Vector2(cos(angle) * width * widen, sin(angle) * height))
	return points


## Matilda: an egg-shaped white bird with a big oval orange beak, small round
## eyes with eyelashes, short yellow cheek spots, and black feathers on her
## head and tail. Faces +x; sizes in units of `r`.
static func _draw_matilda(canvas: CanvasItem, center: Vector2, r: float, color: Color):
	var at := func(x: float, y: float) -> Vector2: return center + Vector2(x, y) * r
	var shape := func(points: Array) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in points:
			result.append(at.call(point.x, point.y))
		return result
	var ink := Color(0.06, 0.05, 0.05)
	var line := maxf(0.07 * r, 1.0)

	# Black feathers: a curl on top and a tail at the back.
	canvas.draw_line(at.call(0.0, -0.98), at.call(-0.05, -1.25), ink, line * 1.6)   # a curl on top
	canvas.draw_arc(at.call(0.08, -1.32), 0.14 * r, PI * 0.95, PI * 2.4, 12, ink, line * 1.6, true)
	canvas.draw_colored_polygon(shape.call([Vector2(0.12, -0.98), Vector2(0.38, -1.2), Vector2(0.44, -1.08), Vector2(0.22, -0.96)]), ink)
	for feather in [[Vector2(-0.9, 0.0), Vector2(-1.4, -0.25), Vector2(-1.32, -0.08), Vector2(-0.9, 0.12)],
			[Vector2(-0.92, 0.1), Vector2(-1.45, 0.12), Vector2(-1.4, 0.28), Vector2(-0.92, 0.22)]]:
		canvas.draw_colored_polygon(shape.call(feather), ink)

	# The egg-shaped body: outline, white, and a soft shadow low at the back.
	var body := _egg_outline(0.92, 1.05, 0.12)
	var outline := _egg_outline(0.92 + 0.08, 1.05 + 0.08, 0.12)
	canvas.draw_colored_polygon(shape.call(outline), ink)
	canvas.draw_colored_polygon(shape.call(body), color)
	canvas.draw_colored_polygon(shape.call([Vector2(-0.95, 0.15), Vector2(-0.55, 0.55), Vector2(-0.2, 0.95), Vector2(-0.6, 0.85), Vector2(-0.95, 0.5)]), color.darkened(0.12))

	# Small round eyes with eyelashes, looking forward.
	for eye in [[Vector2(0.28, -0.25), 0.16], [Vector2(0.64, -0.25), 0.14]]:
		var middle: Vector2 = at.call(eye[0].x, eye[0].y)
		var size: float = eye[1] * r
		canvas.draw_circle(middle, size + line * 0.8, ink)
		canvas.draw_circle(middle, size, Color.WHITE)
		canvas.draw_circle(middle + Vector2(size * 0.35, 0), size * 0.42, ink)
		for lash in [-0.5, 0.0, 0.5]:   # little lashes on top
			var root := middle + Vector2(lash * size, -size)
			canvas.draw_line(root, root + Vector2(lash * size * 0.5, -size * 0.55), ink, line * 0.6)

	# Three short yellow cheek spots, behind the beak.
	for spot in [Vector2(0.02, 0.08), Vector2(0.1, 0.18), Vector2(0.2, 0.08)]:
		canvas.draw_line(at.call(spot.x, spot.y), at.call(spot.x + 0.1, spot.y - 0.02), Color(0.98, 0.78, 0.2), line * 1.3)

	# A big oval beak, with the mouth line.
	var beak_middle: Vector2 = at.call(0.72, 0.12)
	_ellipse(canvas, beak_middle, Vector2(0.36, 0.2) * r + Vector2(line, line) * 0.7, ink)
	_ellipse(canvas, beak_middle, Vector2(0.36, 0.2) * r, Color(1.0, 0.68, 0.1))
	canvas.draw_line(at.call(0.4, 0.13), at.call(1.06, 0.13), ink, line * 0.6)


## Matilda's egg: white, wider at the bottom, with a couple of speckles.
static func _draw_egg(canvas: CanvasItem, center: Vector2, r: float, color: Color):
	var line := maxf(0.12 * r, 1.0)
	var points := PackedVector2Array()
	var edge := PackedVector2Array()
	for point in _egg_outline(0.82, 1.0, 0.15):
		points.append(center + point * r)
		edge.append(center + point * (r + line))
	canvas.draw_colored_polygon(edge, Color(0.06, 0.05, 0.05))
	canvas.draw_colored_polygon(points, color)
	canvas.draw_circle(center + Vector2(-0.25, -0.3) * r, 0.12 * r, color.darkened(0.15))
	canvas.draw_circle(center + Vector2(0.3, 0.25) * r, 0.1 * r, color.darkened(0.15))
