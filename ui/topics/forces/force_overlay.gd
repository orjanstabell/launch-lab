class_name ForceOverlay
extends Node2D
## Two arrows on the bird, both pointing down:
##   F = m·g: the gravity force. Grows when you raise the mass.
##   a = F/m: the acceleration. Stays at g whatever the mass, which is why
##            heavy and light birds fly the same arc.

const PX_PER_NEWTON := 12.0   # at 1× zoom
const PX_PER_MPS2 := 12.0   # same scale as the force, so with m = 1 kg both arrows match
const MAX_ARROW := 350.0   # px at 1×; longer arrows are shortened (the labels keep the true value)
const F_COLOR := Color(0.75, 0.45, 1.0)
const A_COLOR := Color(1.0, 0.6, 0.2)


func _process(_delta: float):
	if visible:
		queue_redraw()


func _draw():
	var k := DrawUtil.size_factor(self)   # see the zoom rule in draw_util.gd
	if PhysicsParams.launch_mode == "spring" and not PhysicsParams.is_flying():
		_draw_spring_force(k)
	var bird: Bird = PhysicsParams.bird
	if not is_instance_valid(bird):
		return
	if bird.burning():   # the rocket's thrust, along its fixed direction
		var thrust := bird.segment.exhaust_speed * bird.segment.burn_rate
		var direction := bird.segment.thrust_dir
		var tip := bird.position + Vector2(direction.x, -direction.y) * minf(thrust * PX_PER_NEWTON * 0.5, MAX_ARROW) * k
		DrawUtil.arrow(self, bird.position, tip, Color(1.0, 0.6, 0.15))
		DrawUtil.label(self, tip, Vector2(10, -6), "thrust F = v_e·ṁ = %s N" % Reveal.num(thrust, ["F"]), Color(1.0, 0.6, 0.15))
	var force := bird.mass_now() * bird.segment.g
	var accel := force / bird.mass_now()

	# Side by side, so they're easy to compare.
	var f_start := bird.position + Vector2(-14, 0) * k
	var a_start := bird.position + Vector2(14, 0) * k
	var f_tip := f_start + Vector2(0, minf(force * PX_PER_NEWTON, MAX_ARROW) * k)
	var a_tip := a_start + Vector2(0, minf(accel * PX_PER_MPS2, MAX_ARROW) * k)
	DrawUtil.arrow(self, f_start, f_tip, F_COLOR)
	DrawUtil.arrow(self, a_start, a_tip, A_COLOR)

	DrawUtil.label(self, f_tip, Vector2(-10, 0), "F = m·g = %s N" % Reveal.num(force, ["F", "m", "g"]), F_COLOR, true)
	DrawUtil.label(self, a_tip, Vector2(10, 0), "a = F/m = %s m/s²" % Reveal.num(accel, ["a", "g"]), A_COLOR)


## Before launch, in spring mode: the band pulls the waiting bird forward with
## F = k·Δx, along the launch direction (Hooke's law).
func _draw_spring_force(k: float):
	var direction := Vector2.from_angle(deg_to_rad(PhysicsParams.values["theta"]))
	var pull: float = PhysicsParams.spring["pull"]
	var force: float = PhysicsParams.spring["k"] * pull
	var bird_at := Units.to_px(Vector2(0, PhysicsParams.values["y0"]) - direction * pull)
	var tip := bird_at + Vector2(direction.x, -direction.y) * minf(force * PX_PER_NEWTON * 0.25, MAX_ARROW) * k
	DrawUtil.arrow(self, bird_at, tip, F_COLOR)
	DrawUtil.label(self, tip, Vector2(10, -6), "F = k·Δx = %s N" % Reveal.num(force, ["F", "k", "pull"]), F_COLOR)
