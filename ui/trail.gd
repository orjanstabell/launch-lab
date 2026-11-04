class_name Trail
extends Node2D
## The path the bird actually took, drawn in segments:
##   each formula segment gets its own blue/purple shade, with a yellow ring
##   where Activate started it; orange is after Godot physics took over.

const FORMULA_COLORS := [Color(0.15, 0.35, 0.95), Color(0.6, 0.2, 0.85), Color(0.0, 0.6, 0.65)]
const PHYSICS_COLOR := Color(1.0, 0.5, 0.1)
const MARKER_COLOR := Color(1.0, 0.85, 0.2)

var _segments := []   # each: {"points": PackedVector2Array, "color": Color, "marker": bool}
var _formula_segment_count := 0
var _drawn_zoom := 0.0


func _process(_delta: float):
	if not is_equal_approx(DrawUtil.zoom(self), _drawn_zoom):
		queue_redraw()


func clear():
	_segments.clear()
	_formula_segment_count = 0
	queue_redraw()


func start_formula_segment(start: Vector2):
	var color: Color = FORMULA_COLORS[_formula_segment_count % FORMULA_COLORS.size()]
	_start_segment(start, color, _formula_segment_count > 0)
	_formula_segment_count += 1


func start_physics_segment(start: Vector2):
	_start_segment(start, PHYSICS_COLOR, false)


func add_point(point: Vector2):
	var points: PackedVector2Array = _segments[-1]["points"]
	if point.distance_to(points[-1]) > 2.0:
		points.append(point)
		_segments[-1]["points"] = points
		queue_redraw()


func _start_segment(start: Vector2, color: Color, marker: bool):
	_segments.append({"points": PackedVector2Array([start]), "color": color, "marker": marker})
	queue_redraw()


func _draw():
	_drawn_zoom = DrawUtil.zoom(self)
	var k := DrawUtil.size_factor(self)   # see the zoom rule in draw_util.gd
	for segment in _segments:
		var points: PackedVector2Array = segment["points"]
		if points.size() >= 2:
			draw_polyline(points, segment["color"], 3.0 * k, true)
		if segment["marker"]:
			draw_arc(points[0], 12.0 * k, 0.0, TAU, 24, MARKER_COLOR, 3.0 * k, true)
