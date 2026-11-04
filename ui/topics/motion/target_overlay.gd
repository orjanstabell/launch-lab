class_name TargetOverlay
extends Node2D
## The solve-mode target: a crosshair at PhysicsParams.target.
## Right-click anywhere in the world to move it.

const COLOR := Color(1.0, 0.3, 0.3)


func _process(_delta: float):
	if visible:
		queue_redraw()


func _draw():
	var k := DrawUtil.size_factor(self)   # see the zoom rule in draw_util.gd
	var center := Units.to_px(PhysicsParams.target)
	var r := 14.0 * k
	draw_arc(center, r, 0.0, TAU, 28, COLOR, 2.5 * k, true)
	draw_line(center - Vector2(r * 1.5, 0), center + Vector2(r * 1.5, 0), COLOR, 2.0 * k)
	draw_line(center - Vector2(0, r * 1.5), center + Vector2(0, r * 1.5), COLOR, 2.0 * k)
	var target := PhysicsParams.target
	DrawUtil.label(self, center, Vector2(20, -16), "target (%s, %s)" % [String.num(target.x, 1), String.num(target.y, 1)], COLOR)
