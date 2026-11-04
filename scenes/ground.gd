class_name Ground
extends StaticBody2D
## The ground (its top is y = 0 m) plus rulers in meters, so you can read off
## distances and heights and compare them with the formula panel.
## The rulers adapt to the camera zoom: fewer labels when zoomed out, and the
## labels follow the zoom rule in draw_util.gd so they stay readable.

const START_M := -20.0
const WIDTH_M := 140.0
const DEPTH_M := 5.0
const RULER_LENGTH_M := 110
const HEIGHT_RULER_X_M := -2.5
const HEIGHT_RULER_TOP_M := 80

var _drawn_zoom := 0.0


func _process(_delta: float):
	if not is_equal_approx(DrawUtil.zoom(self), _drawn_zoom):
		queue_redraw()


func _ready():
	var shape := RectangleShape2D.new()
	shape.size = Vector2(WIDTH_M, DEPTH_M) * Units.PIXELS_PER_METER
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Units.to_px(Vector2(START_M + WIDTH_M / 2, -DEPTH_M / 2))
	add_child(collision)

	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	collision_layer = Layers.GROUND
	collision_mask = 0


func _draw():
	var ppm := Units.PIXELS_PER_METER
	var zoom := DrawUtil.zoom(self)
	var k := DrawUtil.size_factor(self)
	_drawn_zoom = zoom

	# Ground: dirt with a strip of grass on top.
	var top_left := Units.to_px(Vector2(START_M, 0))
	draw_rect(Rect2(top_left, Vector2(WIDTH_M, DEPTH_M) * ppm), Color(0.45, 0.32, 0.2))
	draw_rect(Rect2(top_left, Vector2(WIDTH_M * ppm, 8 * k)), Color(0.35, 0.65, 0.25))

	# Distance ruler along the ground: a tick every meter, labels every 5 m (10 m zoomed out).
	var tick_color := Color(1, 1, 1, 0.8)
	var label_every := 5 if zoom >= 0.6 else 10
	for x in range(0, RULER_LENGTH_M + 1):
		var p := Units.to_px(Vector2(x, 0))
		var big := x % label_every == 0
		draw_line(p + Vector2(0, 8) * k, p + Vector2(0, 22 if big else 14) * k, tick_color, 2.0 * k)
		if big:
			DrawUtil.label(self, p, Vector2(-12, 42), "%d m" % x, tick_color, false, false)

	# Height ruler left of the slingshot: labels every 1 m (5 m or 10 m zoomed out).
	var sky_ink := Color(0.1, 0.2, 0.35, 0.8)
	var height_label_every := 1 if zoom >= 0.8 else (5 if zoom >= 0.4 else 10)
	draw_line(Units.to_px(Vector2(HEIGHT_RULER_X_M, 0)), Units.to_px(Vector2(HEIGHT_RULER_X_M, HEIGHT_RULER_TOP_M)), sky_ink, 2.0 * k)
	for y in range(1, HEIGHT_RULER_TOP_M + 1):
		var p := Units.to_px(Vector2(HEIGHT_RULER_X_M, y))
		var labelled := y % height_label_every == 0
		draw_line(p, p + Vector2(14 if labelled else 7, 0) * k, sky_ink, 2.0 * k)
		if labelled:
			DrawUtil.label(self, p, Vector2(18, 6), "%d m" % y, sky_ink, false, false)
