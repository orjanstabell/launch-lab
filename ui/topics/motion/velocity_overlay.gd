class_name VelocityOverlay
extends Node2D
## Arrows on the bird: its velocity v, split into its x part (vx) and y part (vy).
## The dashed lines close the rectangle, showing that vx + vy add up to v.

const PX_PER_MPS := 20.0   # arrow length at 1× zoom: px per m/s
const MAX_ARROW := 350.0   # px at 1×; longer arrows are shortened (the labels keep the true value)
const V_COLOR := Color.WHITE
const VX_COLOR := Color(1.0, 0.35, 0.3)
const VY_COLOR := Color(0.3, 1.0, 0.4)


func _process(_delta: float):
	if visible:
		queue_redraw()


func _draw():
	var bird: Bird = PhysicsParams.bird
	if not is_instance_valid(bird):
		return
	var k := DrawUtil.size_factor(self)   # see the zoom rule in draw_util.gd
	var origin: Vector2 = bird.position
	var v: Vector2 = bird.velocity_m()

	var px_per_mps := PX_PER_MPS
	if v.length() * px_per_mps > MAX_ARROW:
		px_per_mps = MAX_ARROW / v.length()
	var vx_tip := origin + Vector2(v.x, 0) * px_per_mps * k
	var vy_tip := origin + Vector2(0, -v.y) * px_per_mps * k   # minus: screen y points down
	var v_tip := vx_tip + (vy_tip - origin)

	draw_dashed_line(vx_tip, v_tip, Color(1, 1, 1, 0.5), 1.5 * k, 6.0 * k)
	draw_dashed_line(vy_tip, v_tip, Color(1, 1, 1, 0.5), 1.5 * k, 6.0 * k)
	DrawUtil.arrow(self, origin, vx_tip, VX_COLOR)
	DrawUtil.arrow(self, origin, vy_tip, VY_COLOR)
	DrawUtil.arrow(self, origin, v_tip, V_COLOR)

	DrawUtil.label(self, vx_tip, Vector2(0, 28), "vx = %s m/s" % Reveal.num(v.x, ["vx"]), VX_COLOR)
	DrawUtil.label(self, vy_tip, Vector2(-12, 6), "vy = %s m/s" % Reveal.num(v.y, ["vy"]), VY_COLOR, true)
	DrawUtil.label(self, v_tip, Vector2(12, -6), "v = %s m/s" % Reveal.num(v.length(), ["v"]), V_COLOR)
