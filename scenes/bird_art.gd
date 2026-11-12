class_name BirdArt
extends RefCounted
## How every projectile looks. Shared by the flying one (Bird), the slingshot
## (the one waiting to be launched) and the picker buttons.
##
## Each is a thing whose shape tells its job: a baseball (just a projectile), a
## bumblebee (beats its wings: pushes air back, so the air pushes it on), a bunch of
## grapes (comes apart into grapes), a hot-air balloon with a sandbag (drops its
## ballast), a space probe with a nozzle (a rocket), a stopwatch (set it up
## yourself). Flat colours and thick dark outlines, so they read from the back
## of a lecture hall. Everything faces +x and collides as a circle of `radius`;
## drawing sizes are in units of that radius. The balloon, sandbag and stopwatch
## stay upright however they fly; the others turn with their heading.

const INK := Color(0.09, 0.09, 0.12)
const CREAM := Color(0.97, 0.95, 0.88)
const STITCH := Color(0.84, 0.16, 0.18)
const BEE_GOLD := Color(1.0, 0.74, 0.12)
const BEE_TAIL := Color(0.98, 0.96, 0.9)
const POLLEN := Color(0.95, 0.45, 0.1)
const WING := Color(1, 1, 1, 0.75)
const AIR := Color(1, 1, 1, 0.9)
const WINGBEAT_TIME := 0.45   # seconds the Booster's big wing-beat shows after Space
const GRAPE := Color(0.5, 0.26, 0.62)
const LEAF := Color(0.3, 0.62, 0.25)
const STEM := Color(0.45, 0.3, 0.18)
const ENVELOPE := Color(0.2, 0.4, 0.82)
const WICKER := Color(0.66, 0.46, 0.24)
const SACK := Color(0.8, 0.66, 0.44)
const METAL := Color(0.8, 0.82, 0.86)
const NOZZLE := Color(0.32, 0.34, 0.4)
const UPRIGHT := ["matilda", "egg", "custom"]


## flame: a rocket is firing. spent: the ballast has been dropped / the grapes have split.
## The bumblebee: clock = seconds in flight (its wings flutter; 0 = still), beat =
## seconds since its wing-beat on Space (-1 = none), faster = that push sped it up.
static func draw_bird(canvas: CanvasItem, center: Vector2, radius: float, bird_type: String, flame := false, spent := false, clock := 0.0, beat := -1.0, faster := true):
	var info: Dictionary = BirdTypes.TYPES[bird_type]
	var line := maxf(0.13 * radius, 1.5)
	# Draw around (0, 0) in units of the radius; upright things undo the node's turn.
	var turn := -(canvas as Node2D).global_rotation if bird_type in UPRIGHT and canvas is Node2D else 0.0
	canvas.draw_set_transform(center, turn, Vector2.ONE * radius)
	var w := line / radius   # the outline width, in drawing units
	match bird_type:
		"red": _baseball(canvas, w)
		"yellow": _bumblebee(canvas, w, clock, beat, faster)
		"blue": _grape(canvas, Vector2.ZERO, 1.0, w) if spent else _grapes(canvas, w)
		"matilda": _balloon(canvas, w, spent)
		"egg": _sandbag(canvas, Vector2.ZERO, 1.0, w)
		"rocket": _probe(canvas, w, flame)
		"custom": _stopwatch(canvas, w, info["color"])
	canvas.draw_set_transform(Vector2.ZERO)


## A disc with a thick dark rim.
static func _disc(canvas: CanvasItem, at: Vector2, r: float, color: Color, w: float):
	canvas.draw_circle(at, r + w * 0.5, INK)
	canvas.draw_circle(at, r - w * 0.5, color)


## Points along an arc (radians), for seams and outlines.
static func _arc(center: Vector2, r: float, from: float, to: float, steps := 12) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		points.append(center + Vector2.from_angle(lerpf(from, to, float(i) / steps)) * r)
	return points


## The plain one: two red seams facing each other, with stitches (so you can see it spin).
static func _baseball(canvas: CanvasItem, w: float):
	_disc(canvas, Vector2.ZERO, 1.0, CREAM, w)
	for side in [-1.0, 1.0]:
		var middle := Vector2(side * 1.45, 0)
		var facing := 0.0 if side < 0 else PI
		var seam := _arc(middle, 1.0, facing - 0.62, facing + 0.62, 8)
		canvas.draw_polyline(seam, STITCH, w * 0.7)
		for i in range(1, seam.size() - 1):
			var across := (seam[i] - middle).normalized() * 0.13
			canvas.draw_line(seam[i] - across, seam[i] + across, STITCH, w * 0.6)


## The booster: a bumblebee. A boost needs something outside to push on, and a bee
## has the air: one hard beat of its wings throws air back (puffs behind it), so the
## air pushes the bee on. Slowed down, it beats the other way and the air goes ahead.
## At rest: black head with antennae, gold and black bands, the white tail of a
## bumblebee, fuzz all round, a pollen load on a hind leg, and small wings on its back.
static func _bumblebee(canvas: CanvasItem, w: float, clock: float, beat: float, faster: bool):
	var beating := beat >= 0.0 and beat < WINGBEAT_TIME
	var pivot := Vector2(-0.05, -0.72)   # where the wings join the back
	if beating:   # the air it threw: puffs moving away from the wings, fading
		var age := beat / WINGBEAT_TIME
		var side := -1.0 if faster else 1.0
		for k in 3:
			var at := pivot + Vector2(side * (0.9 + k * 0.45 + age * 1.6), 0.25 + k * 0.32)
			var air := Color(AIR, AIR.a * (1.0 - age))
			canvas.draw_arc(at, 0.45, PI - 0.9 if faster else -0.9, PI + 0.9 if faster else 0.9, 8, Color(INK, air.a), w * 1.6)
			canvas.draw_arc(at, 0.45, PI - 0.9 if faster else -0.9, PI + 0.9 if faster else 0.9, 8, air, w * 0.9)
	# Legs tucked under, the hind one carrying its pollen.
	canvas.draw_line(Vector2(0.25, 0.85), Vector2(0.35, 1.18), INK, w * 0.8)
	canvas.draw_line(Vector2(-0.3, 0.85), Vector2(-0.4, 1.15), INK, w * 0.8)
	_disc(canvas, Vector2(-0.42, 1.18), 0.17, POLLEN, w * 0.6)
	# Antennae, elbowed, from the head.
	for tip: Vector2 in [Vector2(1.2, -1.0), Vector2(0.98, -1.15)]:
		var elbow := Vector2(0.78, -0.95) + (tip - Vector2(1.1, -1.05)) * 0.3
		canvas.draw_polyline(PackedVector2Array([Vector2(0.68, -0.55), elbow, tip]), INK, w * 0.7)
		canvas.draw_circle(tip, w * 0.6, INK)
	# The fuzzy body.
	var fuzz := PackedVector2Array()
	for i in 32:
		fuzz.append(Vector2.from_angle(i * TAU / 32.0) * (1.0 + w * (0.75 if i % 2 == 0 else 0.15)))
	canvas.draw_colored_polygon(fuzz, INK)
	var inner := 1.0 - w * 0.5
	canvas.draw_circle(Vector2.ZERO, inner, BEE_GOLD)
	_band(canvas, -inner, -0.55, BEE_TAIL, inner)
	_band(canvas, -0.22, 0.12, INK, inner)
	_band(canvas, 0.5, inner, INK, inner)   # the head
	canvas.draw_circle(Vector2(0.78, -0.18), 0.1, Color(1, 1, 1, 0.8))   # shine on the head
	# Wings on the back: a quick flutter in flight, one big blurred beat on Space.
	if beating:
		for k in 4:
			var angle := lerpf(-1.2, -2.6, k / 3.0) if faster else lerpf(-2.6, -1.2, k / 3.0)   # the stroke ends where the air went
			_wing(canvas, pivot, angle, Vector2(0.62, 0.24), Color(1, 1, 1, 0.2 + 0.15 * k), w * 0.4)
	else:
		var flutter := 0.35 if int(clock * 24.0) % 2 == 1 else 0.0
		_wing(canvas, pivot, -2.5 + flutter, Vector2(0.5, 0.2), WING, w * 0.6)
		_wing(canvas, pivot + Vector2(0.12, 0), -2.2 + flutter, Vector2(0.48, 0.2), WING, w * 0.6)


## A wing: an oval hinged at `pivot`, pointing along `angle`.
static func _wing(canvas: CanvasItem, pivot: Vector2, angle: float, size: Vector2, color: Color, line: float):
	var points := PackedVector2Array()
	for i in 16:
		points.append(pivot + (Vector2(size.x, 0) + Vector2.from_angle(i * TAU / 16.0) * size).rotated(angle))
	canvas.draw_colored_polygon(points, color)
	points.append(points[0])
	canvas.draw_polyline(points, Color(INK, minf(color.a + 0.15, 1.0)), line)


## A vertical stripe of the body between x1 and x2, clipped to the circle of radius r.
static func _band(canvas: CanvasItem, x1: float, x2: float, color: Color, r: float):
	var points := PackedVector2Array()
	for i in 9:
		var x := lerpf(x1, x2, i / 8.0)
		points.append(Vector2(x, -sqrt(maxf(r * r - x * x, 0.0))))
	for i in 9:
		var x := lerpf(x2, x1, i / 8.0)
		points.append(Vector2(x, sqrt(maxf(r * r - x * x, 0.0))))
	canvas.draw_colored_polygon(points, color)


## The splitter: a bunch of grapes on a stem. Split, each piece is one grape.
static func _grapes(canvas: CanvasItem, w: float):
	canvas.draw_line(Vector2(-0.35, -0.75), Vector2(-0.75, -1.15), STEM, w * 1.4)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-0.6, -1.0), Vector2(-0.15, -1.35), Vector2(0.05, -1.0), Vector2(-0.35, -0.85)]), LEAF)
	var bunch := [Vector2(-0.45, -0.4), Vector2(0.15, -0.5), Vector2(0.6, -0.05), Vector2(-0.55, 0.25), Vector2(0.05, 0.15), Vector2(0.15, 0.68), Vector2(-0.3, 0.7)]
	for at in bunch:
		_grape(canvas, at, 0.4, w)


static func _grape(canvas: CanvasItem, at: Vector2, r: float, w: float):
	_disc(canvas, at, r, GRAPE, w)
	canvas.draw_circle(at + Vector2(-0.35, -0.35) * r, 0.22 * r, GRAPE.lightened(0.5))


## The dropper: a striped hot-air balloon, its basket, and a sandbag under it until dropped.
static func _balloon(canvas: CanvasItem, w: float, spent: bool):
	var middle := Vector2(0, -0.14)
	canvas.draw_line(Vector2(-0.6, 0.45), Vector2(-0.2, 0.82), INK, w * 0.5)
	canvas.draw_line(Vector2(0.6, 0.45), Vector2(0.2, 0.82), INK, w * 0.5)
	if not spent:
		canvas.draw_line(Vector2(0, 1.02), Vector2(0, 1.12), INK, w * 0.5)
		_sandbag(canvas, Vector2(0, 1.3), 0.26, w * 0.7)
	canvas.draw_rect(Rect2(-0.24, 0.8, 0.48, 0.24), INK)
	canvas.draw_rect(Rect2(-0.24 + w * 0.5, 0.8 + w * 0.5, 0.48 - w, 0.24 - w), WICKER)
	_disc(canvas, middle, 0.86, CREAM, w)
	for gore in [[-0.75, -0.3], [0.3, 0.75]]:   # two blue stripes, curving like a globe's
		var stripe := PackedVector2Array()
		for side in 2:
			for i in 13:
				var y := lerpf(-1.0, 1.0, float(i) / 12.0) if side == 0 else lerpf(1.0, -1.0, float(i) / 12.0)
				stripe.append(middle + Vector2(gore[side] * sqrt(1.0 - y * y), y) * (0.86 - w * 0.5))
		canvas.draw_colored_polygon(stripe, ENVELOPE)


## The Dropper's ballast: a tied sack.
static func _sandbag(canvas: CanvasItem, at: Vector2, r: float, w: float):
	_disc(canvas, at + Vector2(0, 0.12) * r, 0.88 * r, SACK, w)
	var neck := PackedVector2Array([at + Vector2(-0.4, -0.95) * r, at + Vector2(0.4, -0.95) * r, at + Vector2(0.15, -0.6) * r, at + Vector2(-0.15, -0.6) * r])
	canvas.draw_colored_polygon(neck, SACK)
	canvas.draw_polyline(neck + PackedVector2Array([neck[0]]), INK, w * 0.8)
	canvas.draw_line(at + Vector2(-0.25, -0.62) * r, at + Vector2(0.25, -0.62) * r, INK, w * 1.2)


## The rocket: a metal probe with four antennas swept back, a porthole, and a nozzle
## at the back, with a flame from it while it fires.
static func _probe(canvas: CanvasItem, w: float, flame: bool):
	for antenna in [[Vector2(-0.4, -0.85), Vector2(-2.0, -1.55)], [Vector2(-0.6, -0.7), Vector2(-2.3, -0.75)], [Vector2(-0.6, 0.7), Vector2(-2.3, 0.75)], [Vector2(-0.4, 0.85), Vector2(-2.0, 1.55)]]:
		canvas.draw_line(antenna[0], antenna[1], INK, w * 0.55)
	if flame:
		var flicker := 1.0 + 0.3 * sin(Time.get_ticks_msec() * 0.05)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-1.25, -0.32), Vector2(-1.25 - 1.4 * flicker, 0), Vector2(-1.25, 0.32)]), Color(1.0, 0.6, 0.12))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-1.25, -0.16), Vector2(-1.25 - 0.75 * flicker, 0), Vector2(-1.25, 0.16)]), Color(1.0, 0.95, 0.7))
	var nozzle := PackedVector2Array([Vector2(-0.8, -0.2), Vector2(-1.28, -0.36), Vector2(-1.28, 0.36), Vector2(-0.8, 0.2)])
	canvas.draw_colored_polygon(nozzle, NOZZLE)
	canvas.draw_polyline(nozzle + PackedVector2Array([nozzle[0]]), INK, w * 0.8)
	_disc(canvas, Vector2.ZERO, 1.0, METAL, w)
	canvas.draw_arc(Vector2(-0.35, 0), 0.95, -1.2, 1.2, 12, INK, w * 0.5)   # the seam between the halves
	canvas.draw_circle(Vector2(-0.3, -0.42), 0.16, Color.WHITE)   # a shine
	_disc(canvas, Vector2(0.45, 0), 0.3, Color(0.98, 0.72, 0.2), w * 0.8)   # the porthole


## Custom: a stopwatch (you set up what happens and when) in the type's colour.
static func _stopwatch(canvas: CanvasItem, w: float, color: Color):
	canvas.draw_rect(Rect2(-0.18, -1.32, 0.36, 0.3), INK)   # the crown
	canvas.draw_rect(Rect2(-0.12, -1.26, 0.24, 0.24), color)
	canvas.draw_line(Vector2.from_angle(-PI / 4.0) * 0.95, Vector2.from_angle(-PI / 4.0) * 1.2, INK, w * 1.6)   # the lap button
	_disc(canvas, Vector2.ZERO, 1.0, color, w)
	canvas.draw_circle(Vector2.ZERO, 0.72, INK)
	canvas.draw_circle(Vector2.ZERO, 0.72 - w * 0.5, Color.WHITE)
	for i in 4:
		var mark := Vector2.from_angle(i * PI / 2.0)
		canvas.draw_line(mark * 0.45, mark * 0.62, INK, w * 0.7)
	canvas.draw_line(Vector2.ZERO, Vector2.from_angle(-PI / 6.0) * 0.55, Color(0.84, 0.16, 0.18), w * 0.8)
	canvas.draw_circle(Vector2.ZERO, 0.1, INK)
