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
##   "egg":    the Dropper throws an egg straight down and recoils up; bird and egg
##             each get their own segment (like a split into two unequal pieces).
##
## On the first hit, a bird becomes a normal RigidBody2D with the formula's
## velocity at that moment, and Godot physics handles the crash.

signal auto_stopped   # it paused the game at `pause_at`

enum State { FLYING, PHYSICS }

const MAX_FLIGHT_TIME := 30.0   # give up on birds that never come down (g = 0)
const SENSOR_RADIUS_M := 2.5   # the proximity sensor: notices pigs this close (for the action cam)
const PHYSICS_TRAIL_TIME := 4.0   # keep drawing the trail this long after the hit
## A bird that leaves this box (meters) is removed: a bit past either end of the
## ground (−20 m to 120 m), or fallen where there's no ground to land on.
const WORLD_M := Rect2(-30.0, -20.0, 160.0, 1000.0)

var state := State.FLYING
var type := "red"   # key into BirdTypes.TYPES
var radius_m := 0.3
var segment: LaunchParams   # the formula the bird follows right now (its g and m are the bird's too)
var segment_history: Array[LaunchParams] = []   # every segment so far, including the current one
var t := 0.0   # seconds since the current segment started
var flight_time := 0.0   # seconds since launch
var activations := 0
var _sped_up := true   # the last "change" ability made it faster (the bee's air goes back, not ahead)
var trail: Trail
var hit_position := Vector2.INF   # meters: where it first hit something (INF = hasn't yet)
var exhaust: RocketExhaust = null   # the rocket bird's exhaust puffs, once it fires
## The force from contact (not gravity) this physics step, in newtons:
## F = m·Δv/Δt − m·g. Zero while flying on the formula (only gravity acts then).
var contact_force := Vector2.ZERO
var _previous_velocity := Vector2.INF
var activate_at := INF   # flight time at which to use the ability automatically (practice problems, lecture cues)
var pause_at := INF   # flight time at which to pause the game on exactly that moment (e.g. the top of the arc)
var _stamps := 0   # strobe dots left on the trail so far

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
	if not WORLD_M.has_point(Units.to_m(position)):
		queue_free()


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
			var speed_before := Kinematics.velocity(segment, t).length()
			_start_segment(next_segment())
			_sped_up = Kinematics.velocity(segment, 0.0).length() >= speed_before
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
		if cos_sum > 0.01:   # 2 pieces at ±90° fly straight sideways: no speed can carry the forward momentum
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


## For the Dropper: [her segment, the egg's segment] if she threw the egg right now.
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


## Break into pieces (a split, or the Dropper and her egg): note momentum and energy
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
	queue_redraw()   # (a Dropper no longer carries its ballast)


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
	# A scheduled stop (e.g. "freeze at the top"): only fly up to that exact moment
	# this step, and pause there.
	if flight_time + delta >= pause_at:
		delta = maxf(pause_at - flight_time, 0.0)
		pause_at = INF
		get_tree().paused = true
		auto_stopped.emit()
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
	if segment.is_rocket() or type in BirdArt.UPRIGHT or type == "yellow":
		queue_redraw()   # the flame comes and goes; upright pictures undo the new turn; the bee's wings flutter
	trail.add_point(position)
	# The strobe: a dot wherever the formula puts the bird at each tick (the bird
	# you launched only, or a split would fill the sky with dots).
	while not is_piece and (_stamps + 1) * Trail.STAMP_INTERVAL <= flight_time:
		_stamps += 1
		var ago := flight_time - _stamps * Trail.STAMP_INTERVAL
		trail.add_stamp(Units.to_px(Kinematics.position(segment, maxf(t - ago, 0.0))))

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
		"other_name": ("big dummy" if other.big else "dummy") if other is Pig else "block",
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
	var beat := t if state == State.FLYING and activations > 0 else -1.0   # (t restarts at each activation)
	var clock := flight_time if state == State.FLYING else 0.0
	BirdArt.draw_bird(self, Vector2.ZERO, _shape.radius, type, burning(), not pieces.is_empty(), clock, beat, _sped_up)
