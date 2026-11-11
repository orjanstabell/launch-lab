class_name BirdArt
extends RefCounted
## How every projectile looks. Shared by the flying one (Bird) and the slingshot
## (the one waiting to be launched).
##
## One look for all of them: a round body in the type's colour, a thick dark
## outline, and two eyes at the front, looking where it's going. What a type
## DOES is its mark ("mark" in BirdTypes): chevrons for a boost, a seam where it
## splits, ballast slung underneath, a rocket on its back, dials for your own
## ability. Flat colours and thick lines, so it reads from the back of a
## lecture hall. Everything faces +x; sizes are in units of the radius.

const INK := Color(0.09, 0.09, 0.12)
const BALLAST := Color(0.38, 0.41, 0.48)


## flame: a rocket is firing. spent: the ballast has been dropped.
static func draw_bird(canvas: CanvasItem, center: Vector2, radius: float, bird_type: String, flame := false, spent := false):
	var info: Dictionary = BirdTypes.TYPES[bird_type]
	var mark: String = info.get("mark", "")
	var line := maxf(0.13 * radius, 1.5)
	var at := func(x: float, y: float) -> Vector2: return center + Vector2(x, y) * radius
	var shape := func(points: Array) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in points:
			result.append(at.call(point.x, point.y))
		return result

	if mark == "weight":   # the ballast itself: no eyes, it only falls
		_draw_weight(canvas, center, radius, info["color"], line)
		return
	# Slung underneath: drawn first, so the body covers where it's attached.
	if mark == "ballast" and not spent:
		_draw_weight(canvas, at.call(-0.05, 0.95), 0.5 * radius, BALLAST, line * 0.8)

	canvas.draw_circle(center, radius + line * 0.5, INK)
	canvas.draw_circle(center, radius - line * 0.5, info["color"])
	if mark == "rocket":   # strapped on top, above the eyes
		_draw_rocket(canvas, at, shape, line, flame)

	match mark:
		"chevrons":   # a push forwards
			for x in [-0.72, -0.34]:
				canvas.draw_polyline(shape.call([Vector2(x, -0.36), Vector2(x + 0.32, 0.0), Vector2(x, 0.36)]), INK, line * 1.1, true)
		"seam":   # where it comes apart
			canvas.draw_polyline(shape.call([Vector2(-0.3, -0.88), Vector2(-0.1, -0.45), Vector2(-0.42, -0.05), Vector2(-0.14, 0.4), Vector2(-0.36, 0.86)]), INK, line, true)
		"dials":   # set it up yourself
			for dial in [[-0.3, -0.52], [0.24, -0.26]]:
				canvas.draw_line(at.call(-0.74, dial[0]), at.call(-0.14, dial[0]), INK, line)
				canvas.draw_circle(at.call(dial[1], dial[0]), 0.15 * radius, INK)
		"ballast":
			if spent:   # the empty hook
				canvas.draw_line(at.call(-0.05, 0.62), at.call(-0.05, 0.9), INK, line)

	# The eyes, at the front, looking ahead.
	for eye in [[Vector2(0.26, -0.2), 0.27], [Vector2(0.64, -0.18), 0.21]]:
		var middle: Vector2 = at.call(eye[0].x, eye[0].y)
		var size: float = eye[1] * radius
		canvas.draw_circle(middle, size + line * 0.5, INK)
		canvas.draw_circle(middle, size, Color.WHITE)
		canvas.draw_circle(middle + Vector2(size * 0.38, 0), size * 0.45, INK)


## A plain weight: a dark disc with a lighter band (so you can see it turn).
static func _draw_weight(canvas: CanvasItem, center: Vector2, r: float, color: Color, line: float):
	canvas.draw_circle(center, r + line * 0.5, INK)
	canvas.draw_circle(center, r - line * 0.5, color)
	canvas.draw_line(center + Vector2(-0.6, 0) * r, center + Vector2(0.6, 0) * r, color.lightened(0.45), maxf(0.28 * r, 1.0))


## A little rocket strapped along the back, pointing forward (where it pushes),
## with a flame from the nozzle while it fires.
static func _draw_rocket(canvas: CanvasItem, at: Callable, shape: Callable, line: float, flame: bool):
	if flame:
		var flicker := 1.0 + 0.3 * sin(Time.get_ticks_msec() * 0.05)
		canvas.draw_colored_polygon(shape.call([Vector2(-1.3, -1.0), Vector2(-1.3 - 1.1 * flicker, -0.82), Vector2(-1.3, -0.64)]), Color(1.0, 0.7, 0.15))
		canvas.draw_colored_polygon(shape.call([Vector2(-1.3, -0.92), Vector2(-1.3 - 0.6 * flicker, -0.82), Vector2(-1.3, -0.72)]), Color(1.0, 0.95, 0.7))
	var body := [Vector2(-1.38, -1.06), Vector2(-1.25, -0.98), Vector2(0.15, -0.98), Vector2(0.62, -0.82), Vector2(0.15, -0.66), Vector2(-1.25, -0.66), Vector2(-1.38, -0.58)]
	canvas.draw_colored_polygon(shape.call(body), Color(0.8, 0.82, 0.86))
	canvas.draw_colored_polygon(shape.call([Vector2(0.15, -0.98), Vector2(0.62, -0.82), Vector2(0.15, -0.66)]), Color(0.82, 0.16, 0.12))   # nose cone
	var outline: PackedVector2Array = shape.call(body)
	outline.append(outline[0])
	canvas.draw_polyline(outline, INK, line * 0.8, true)
