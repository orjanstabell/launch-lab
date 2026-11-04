class_name BirdArt
extends RefCounted
## How every bird looks. Shared by the flying Bird and the slingshot (a bird
## waiting to be launched).


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
