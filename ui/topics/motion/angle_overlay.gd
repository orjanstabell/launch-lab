class_name AngleOverlay
extends Node2D
## Angle arcs, each measured from the horizontal (counter-clockwise = positive):
##   θ₁, θ₂, ...: the angle each formula segment started with (launch, then each Activate)
##   now:         the direction the bird is moving right now
##   yellow:      the angle the ability would set, if θ is ticked
## Before a launch, it shows the launch θ at the slingshot.

const RADIUS := 55.0
const SEGMENT_COLOR := Color(1, 1, 1, 0.95)
const NOW_COLOR := Color(0.55, 0.9, 1.0)
const ABILITY_COLOR := Color(1.0, 0.85, 0.2)

func _process(_delta: float):
	if visible:
		queue_redraw()


func _draw():
	var bird: Bird = PhysicsParams.bird
	if not is_instance_valid(bird):
		var p := PhysicsParams.launch_params()
		_draw_angle(Units.to_px(Vector2(p.x0, p.y0)), p.theta_deg, SEGMENT_COLOR, "θ = %s°" % _fmt(p.theta_deg, ["theta"]))
		return

	for i in bird.segment_history.size():
		var segment: LaunchParams = bird.segment_history[i]
		var center := Units.to_px(Vector2(segment.x0, segment.y0))
		_draw_angle(center, segment.theta_deg, SEGMENT_COLOR, "θ%s = %s°" % [_subscript(i + 1), _fmt(segment.theta_deg, ["theta"])])

	if bird.state == Bird.State.FLYING:
		var v: Vector2 = bird.velocity_m()
		var now_angle := rad_to_deg(atan2(v.y, v.x))
		# These two often point almost the same way, so their labels are stacked above the bird.
		var label_offset := Vector2(-60, -50)
		_draw_angle(bird.position, now_angle, NOW_COLOR, "now %s°" % _fmt(now_angle, ["theta", "vx", "vy"]), RADIUS * 1.5, label_offset)
		if PhysicsParams.ability_on["theta"]:
			var target: float = PhysicsParams.ability["theta"]
			_draw_angle(bird.position, target, ABILITY_COLOR, "ability θ = %s°" % _fmt(target, ["theta"]), RADIUS * 2.2, label_offset + Vector2(0, -24))


## Horizontal reference line, a line in the direction `angle_deg`, the arc between them, and a label.
## Sizes are px at 1× zoom (see the zoom rule in draw_util.gd). The label goes
## next to the arc unless `label_offset` (from `center`) says otherwise.
func _draw_angle(center: Vector2, angle_deg: float, color: Color, label: String, radius := RADIUS, label_offset := Vector2.INF):
	var k := DrawUtil.size_factor(self)
	var angle := -deg_to_rad(angle_deg)   # screen angles turn the other way, since screen y points down
	var arm := (radius + 25.0) * k
	draw_dashed_line(center, center + Vector2(arm, 0), Color(color, 0.6), 2.0 * k, 6.0 * k)
	draw_line(center, center + Vector2.from_angle(angle) * arm, color, 2.0 * k, true)
	if absf(angle) > 0.01:
		draw_arc(center, radius * k, 0.0, angle, 32, color, 2.0 * k, true)

	if label_offset == Vector2.INF:
		label_offset = Vector2.from_angle(angle / 2) * (radius + 10) + Vector2(8, 6)
	DrawUtil.label(self, center, label_offset, label, color)


func _subscript(n: int) -> String:
	const DIGITS := "₀₁₂₃₄₅₆₇₈₉"
	var result := ""
	for digit in str(n):
		result += DIGITS[int(digit)]
	return result


func _fmt(x: float, depends_on: Array) -> String:
	return Reveal.num(x, depends_on, 1)
