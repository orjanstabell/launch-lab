class_name MomentumOverlay
extends Node2D
## Before a split: the bird's momentum arrow p = m·v.
## After a blue bird split:
##   - a momentum arrow on each piece
##   - the pieces' center of mass ✛, with their total momentum Σp
##   - the unsplit bird ○: where the bird would be if it hadn't split,
##     on the old arc (faint dots)
## With momentum conserved and only gravity acting, ✛ and ○ stay together.
## Pigs get a momentum arrow too while they move, so in a hit you can watch
## momentum pass from the bird to the pig.

const PX_PER_P := 20.0   # arrow length at 1× zoom: px per kg·m/s
const MAX_ARROW := 350.0
const P_COLOR := Color(0.4, 0.85, 1.0)
const COM_COLOR := Color(1.0, 0.95, 0.4)
const UNSPLIT_COLOR := Color(1, 1, 1, 0.8)
const PIG_COLOR := Color(0.6, 1.0, 0.4)


func _process(_delta: float):
	if visible:
		queue_redraw()


func _draw():
	var k := DrawUtil.size_factor(self)   # see the zoom rule in draw_util.gd
	_draw_pigs(k)
	var bird: Bird = PhysicsParams.bird
	if not is_instance_valid(bird):
		return

	if bird.pieces.is_empty():
		var p: Vector2 = bird.mass_now() * bird.velocity_m()
		_p_arrow(bird.position, p, k, P_COLOR)
		DrawUtil.label(self, bird.position + _arrow_vector(p, k), Vector2(10, -6), "p = m·v = %s kg·m/s" % Reveal.num(p.length(), ["p", "m", "v"]), P_COLOR)
		return

	_draw_old_arc(bird, k)

	# Center of mass: positions averaged, weighted by mass.
	var total_m := 0.0
	var com := Vector2.ZERO
	var total_p := Vector2.ZERO
	for piece in bird.pieces:
		if not is_instance_valid(piece) or piece.state != Bird.State.FLYING:
			return   # a piece hit something; the comparison no longer holds
		var p: Vector2 = piece.mass_now() * piece.velocity_m()
		_p_arrow(piece.position, p, k, Color(P_COLOR, 0.7))
		total_m += piece.mass_now()
		com += piece.mass_now() * piece.position
		total_p += p
	com /= total_m

	var t_unsplit := bird.split_t + bird.flight_time - bird.split_flight_time
	var unsplit := Units.to_px(Kinematics.position(bird.pre_split, t_unsplit))
	draw_arc(unsplit, 12.0 * k, 0.0, TAU, 24, UNSPLIT_COLOR, 2.5 * k, true)
	DrawUtil.label(self, unsplit, Vector2(-16, 30), "unsplit bird", UNSPLIT_COLOR, true)

	var size := 10.0 * k
	draw_line(com - Vector2(size, 0), com + Vector2(size, 0), COM_COLOR, 3.0 * k)
	draw_line(com - Vector2(0, size), com + Vector2(0, size), COM_COLOR, 3.0 * k)
	_p_arrow(com, total_p, k, COM_COLOR)
	DrawUtil.label(self, com + _arrow_vector(total_p, k), Vector2(10, -6), "Σp = %s kg·m/s" % Reveal.num(total_p.length(), ["p", "m", "v"]), COM_COLOR)
	DrawUtil.label(self, com, Vector2(16, 30), "center of mass", COM_COLOR)


func _draw_pigs(k: float):
	for pig: Pig in get_tree().get_nodes_in_group("pigs"):
		var p: Vector2 = pig.mass * Units.to_m(pig.linear_velocity)
		if p.length() < 0.05:
			continue   # resting: nothing to show
		_p_arrow(pig.position, p, k, PIG_COLOR)
		DrawUtil.label(self, pig.position + _arrow_vector(p, k), Vector2(10, -6), "p pig = %s kg·m/s" % Reveal.num(p.length(), ["p"]), PIG_COLOR)


## The rest of the arc the bird was on when it split: where it would have gone.
func _draw_old_arc(bird: Bird, k: float):
	if Reveal.is_hidden("predict"):
		return
	var end_time := minf(Kinematics.time_of_flight(bird.pre_split), bird.split_t + 30.0)
	var step := 0.1
	var dot_t := bird.split_t
	while dot_t < end_time:
		draw_circle(Units.to_px(Kinematics.position(bird.pre_split, dot_t)), 2.5 * k, Color(UNSPLIT_COLOR, 0.5))
		dot_t += step


func _arrow_vector(p: Vector2, k: float) -> Vector2:
	var length := minf(p.length() * PX_PER_P, MAX_ARROW)
	return Vector2(p.x, -p.y).normalized() * length * k   # minus: screen y points down


func _p_arrow(from: Vector2, p: Vector2, k: float, color: Color):
	DrawUtil.arrow(self, from, from + _arrow_vector(p, k), color)
