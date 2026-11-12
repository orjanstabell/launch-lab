class_name AbilityMarks
extends Node2D
## What happens around a ball when you press Space, drawn level (a child of the
## ball that undoes its turn):
##   Splitter: a burst where the shell went off, and for a moment a ring at the
##     pieces' centre of mass. Momentum is conserved, so it carries on along the
##     arc the whole shell was on.
##   Recoil: a muzzle flash and smoke under the cannon, and two equal and
##     opposite Δp arrows, on the cannon and on the cannonball.
##   Custom: tags for what the dial changed ("g → 3.7 m/s²").
## Timed by the ball's segment time t (it restarts at Space), so it all freezes
## on pause and step.

const BURST_TIME := 0.3
const COM_TIME := 1.5
const SMOKE_TIME := 0.6
const RECOIL_TIME := 1.0
const TAG_TIME := 2.0
const FLASH := Color(1.0, 0.9, 0.5)
const SMOKE := Color(0.85, 0.85, 0.85)
const KICK := Color(1.0, 0.55, 0.15)

var bird: Bird


func _draw():
	if bird.state != Bird.State.FLYING or bird.activations == 0:
		return
	var t := bird.t
	var k := DrawUtil.size_factor(self)
	var r := bird.radius_m * Units.PIXELS_PER_METER
	match bird.split_info.get("kind", ""):
		"split":
			_burst(t, k, r)
		"egg":
			_recoil(t, k, r)
	if not bird.changes.is_empty() and t < TAG_TIME:
		DrawUtil.label(self, Vector2.ZERO, Vector2(16, -20), "   ".join(bird.changes), Color.WHITE)


## A world point (meters) in this node's level frame.
func _here(meters: Vector2) -> Vector2:
	return to_local(bird.get_parent().to_global(Units.to_px(meters)))


func _burst(t: float, k: float, r: float):
	var at := _here(Kinematics.position(bird.pre_split, bird.split_t))
	if t < BURST_TIME:
		var age := t / BURST_TIME
		for i in 10:
			var ray := Vector2.from_angle(i * TAU / 10.0)
			draw_line(at + ray * r * (0.4 + 2.0 * age), at + ray * r * (1.0 + 3.0 * age), Color(FLASH, 1.0 - age), 3.0 * k)
	if t >= COM_TIME:
		return
	# The pieces' centre of mass, from where they really are (if one has hit something, stop).
	var com := Vector2.ZERO
	var total := 0.0
	for piece in bird.pieces:
		if not is_instance_valid(piece) or piece.state != Bird.State.FLYING:
			return
		com += piece.mass_now() * piece.global_position
		total += piece.mass_now()
	com = to_local(com / total)
	var fade := minf(1.0, (COM_TIME - t) / 0.3)
	draw_arc(com, r * 0.9, 0.0, TAU, 24, Color(BirdArt.INK, fade), 5.0 * k)
	draw_arc(com, r * 0.9, 0.0, TAU, 24, Color(1, 1, 1, fade), 2.5 * k)
	DrawUtil.label(self, com, Vector2(14, -10), "centre of mass", Color(1, 1, 1, fade))


func _recoil(t: float, k: float, r: float):
	var muzzle := _here(Kinematics.position(bird.pre_split, bird.split_t)) + Vector2(0, r * 1.4)
	if t < BURST_TIME * 0.6:
		var flash := PackedVector2Array()
		for i in 12:
			flash.append(muzzle + Vector2.from_angle(i * PI / 6.0) * r * (0.9 if i % 2 == 0 else 0.4))
		draw_colored_polygon(flash, FLASH)
	if t < SMOKE_TIME:
		var age := t / SMOKE_TIME
		for side in [-1.0, 0.0, 1.0]:
			draw_circle(muzzle + Vector2(side * r * 0.9 * age, r * 0.6 * (1.0 + age)), r * (0.35 + 0.4 * age), Color(SMOKE, 0.8 * (1.0 - age)))
	if t >= RECOIL_TIME or bird.pieces.size() < 2 or not is_instance_valid(bird.pieces[1]):
		return
	# Equal and opposite: the cannon's change in momentum, and the cannonball's.
	var before := Kinematics.velocity(bird.pre_split, bird.split_t)
	var kick := bird.segment.m * (Kinematics.initial_velocity(bird.segment) - before)
	var dir := Vector2(kick.x, -kick.y).normalized()   # (meters have y up, the screen y down)
	var length := 46.0 * k
	var ball: Bird = bird.pieces[1]
	var ball_at := to_local(ball.global_position)
	var ball_r := ball.radius_m * Units.PIXELS_PER_METER
	DrawUtil.arrow(self, dir * r * 1.1, dir * (r * 1.1 + length), KICK)
	DrawUtil.arrow(self, ball_at - dir * ball_r * 1.3, ball_at - dir * (ball_r * 1.3 + length), KICK)
	DrawUtil.label(self, dir * (r * 1.1 + length), Vector2(8, 0), "Δp", KICK)
	DrawUtil.label(self, ball_at - dir * (ball_r * 1.3 + length), Vector2(8, 10), "−Δp", KICK)
