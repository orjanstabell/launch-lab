class_name BirdArt
extends RefCounted
## How every projectile looks. Shared by the flying one (Bird), the slingshot
## (the one waiting to be launched) and the picker buttons.
##
## Each is a familiar thing whose shape tells its job: a baseball (just a
## projectile), a bumblebee (beats its wings: pushes air back, so the air pushes
## it on), a firework star shell (bursts into stars), a little cannon pointing
## down (fires a cannonball down and recoils up), a water-bottle rocket (squirts
## its water out the back) and a dial (you set what changes). Flat colours and
## thick dark outlines, so they read from the back of a lecture hall. Everything
## faces +x and collides as a circle of `radius`; drawing sizes are in units of
## that radius. The cannon, its cannonball and the dial stay upright however
## they fly; the others turn with their heading.
## What happens around a ball when you press Space (the burst, the recoil
## arrows, the dial's tags) is drawn by AbilityMarks.

const INK := Color(0.09, 0.09, 0.12)
const CREAM := Color(0.97, 0.95, 0.88)
const STITCH := Color(0.84, 0.16, 0.18)
const BEE_GOLD := Color(1.0, 0.74, 0.12)
const BEE_TAIL := Color(0.98, 0.96, 0.9)
const POLLEN := Color(0.95, 0.45, 0.1)
const WING := Color(1, 1, 1, 0.75)
const AIR := Color(1, 1, 1, 0.9)
const WINGBEAT_TIME := 0.45   # seconds the Booster's big wing-beat shows after Space
const SHELL := Color(0.18, 0.2, 0.32)
const SPARK := Color(1.0, 0.85, 0.3)
const GUNMETAL := Color(0.3, 0.32, 0.38)
const IRON := Color(0.22, 0.23, 0.27)
const BOTTLE := Color(0.85, 0.94, 1.0)
const WATER := Color(0.2, 0.55, 0.95)
const FIN := Color(0.86, 0.22, 0.2)
const UPRIGHT := ["matilda", "egg", "custom"]


## `look` holds the picture's state (all optional):
##   "spent": the cannonball is fired / this is a piece of the burst shell
##   "clock": seconds in flight (the bee's wings flutter, the fuse fizzes; 0 = still)
##   "beat": seconds since Space (-1 = not pressed), "faster": that push sped it up
##   "fuel": the water rocket's water left, 1 → 0, "spraying": it is firing
static func draw_bird(canvas: CanvasItem, center: Vector2, radius: float, bird_type: String, look := {}):
	var info: Dictionary = BirdTypes.TYPES[bird_type]
	var line := maxf(0.13 * radius, 1.5)
	# Draw around (0, 0) in units of the radius; upright things undo the node's turn.
	var turn := -(canvas as Node2D).global_rotation if bird_type in UPRIGHT and canvas is Node2D else 0.0
	canvas.draw_set_transform(center, turn, Vector2.ONE * radius)
	var w := line / radius   # the outline width, in drawing units
	var clock: float = look.get("clock", 0.0)
	var beat: float = look.get("beat", -1.0)
	match bird_type:
		"red": _baseball(canvas, w)
		"yellow": _bumblebee(canvas, w, clock, beat, look.get("faster", true))
		"blue": _star(canvas, w, info["color"]) if look.get("spent", false) else _star_shell(canvas, w, info["color"], clock)
		"matilda": _cannon(canvas, w, info["color"])
		"egg": _cannonball(canvas, w)
		"rocket": _water_rocket(canvas, w, look.get("fuel", 1.0), look.get("spraying", false))
		"custom": _dial(canvas, w, info["color"], beat >= 0.0)
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


## The splitter: a firework star shell, the textbook burst problem. A dark round
## shell with a coloured paper band, and a fuse at the back that fizzes in flight.
static func _star_shell(canvas: CanvasItem, w: float, color: Color, clock: float):
	var tip := Vector2(-1.4, -0.35)
	canvas.draw_polyline(PackedVector2Array([Vector2(-0.85, -0.1), Vector2(-1.15, -0.15), tip]), INK, w * 1.1)
	if clock > 0.0:   # the lit fuse: a spark that flickers
		var flick := 0.7 + 0.5 * absf(sin(clock * 37.0))
		for i in 6:
			var ray := Vector2.from_angle(i * TAU / 6.0 + clock * 9.0) * 0.32 * flick
			canvas.draw_line(tip, tip + ray, SPARK, w * 0.7)
	_disc(canvas, Vector2.ZERO, 1.0, SHELL, w)
	_band(canvas, -0.2, 0.2, color, 1.0 - w * 0.5)
	canvas.draw_circle(Vector2(0.4, -0.45), 0.14, Color(1, 1, 1, 0.5))   # a shine


## One piece of the burst shell: a five-point star with a white-hot core.
static func _star(canvas: CanvasItem, w: float, color: Color):
	var points := PackedVector2Array()
	for i in 10:
		points.append(Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * (1.25 if i % 2 == 0 else 0.55))
	canvas.draw_colored_polygon(points, color)
	points.append(points[0])
	canvas.draw_polyline(points, INK, w)
	canvas.draw_circle(Vector2.ZERO, 0.28, Color(1, 1, 0.9))


## The recoil ball: a little cannon pointing straight down, its barrel below a
## round body. Firing throws the cannonball down, so the cannon is kicked up.
static func _cannon(canvas: CanvasItem, w: float, color: Color):
	canvas.draw_rect(Rect2(-0.3, 0.3, 0.6, 1.0), INK)
	canvas.draw_rect(Rect2(-0.3 + w * 0.5, 0.3, 0.6 - w, 1.0 - w * 0.5), GUNMETAL)
	canvas.draw_rect(Rect2(-0.4, 1.12, 0.8, 0.28), INK)   # the muzzle ring
	canvas.draw_rect(Rect2(-0.4 + w * 0.5, 1.12 + w * 0.5, 0.8 - w, 0.28 - w), GUNMETAL.lightened(0.2))
	_disc(canvas, Vector2(0, -0.12), 0.88, color, w)
	canvas.draw_line(Vector2(-0.84, 0.05), Vector2(0.84, 0.05), INK, w * 0.7)   # a riveted band
	for x in [-0.5, 0.0, 0.5]:
		canvas.draw_circle(Vector2(x, 0.05), 0.09, INK)
	canvas.draw_circle(Vector2(-0.3, -0.5), 0.14, Color(1, 1, 1, 0.45))


## What the cannon fires: an iron ball.
static func _cannonball(canvas: CanvasItem, w: float):
	_disc(canvas, Vector2.ZERO, 1.0, IRON, w)
	canvas.draw_circle(Vector2(-0.35, -0.35), 0.25, Color(1, 1, 1, 0.55))


## The rocket: a water-bottle rocket with a red nose cone and fins. The water is
## the mass it throws out. Under thrust it sits at the back (the nozzle end), so
## its surface is a line across the heading, and it drains as the rocket fires.
static func _water_rocket(canvas: CanvasItem, w: float, fuel: float, spraying: bool):
	if spraying:   # the jet out of the nozzle
		var flicker := 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.05)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-1.2, -0.18), Vector2(-1.2 - 1.3 * flicker, -0.45), Vector2(-1.2 - 1.3 * flicker, 0.45), Vector2(-1.2, 0.18)]), Color(WATER, 0.55))
	for side in [-1.0, 1.0]:   # fins at the back
		var fin := PackedVector2Array([Vector2(-0.35, side * 0.85), Vector2(-1.15, side * 1.3), Vector2(-1.0, side * 0.45)])
		canvas.draw_colored_polygon(fin, FIN)
		canvas.draw_polyline(fin + PackedVector2Array([fin[0]]), INK, w * 0.8)
	canvas.draw_rect(Rect2(-1.22, -0.2, 0.3, 0.4), INK)   # the nozzle
	var nose := PackedVector2Array([Vector2(0.55, -0.82), Vector2(1.45, 0.0), Vector2(0.55, 0.82)])
	canvas.draw_colored_polygon(nose, FIN)
	canvas.draw_polyline(nose + PackedVector2Array([nose[0]]), INK, w)
	_disc(canvas, Vector2.ZERO, 1.0, BOTTLE, w)
	var inner := 1.0 - w * 0.5
	if fuel > 0.0:
		_band(canvas, -inner, -inner + 2.0 * inner * clampf(fuel, 0.0, 1.0), WATER, inner)
	canvas.draw_line(Vector2(0.3, -0.62), Vector2(0.55, -0.35), Color(1, 1, 1, 0.9), w)   # a glint on the plastic


## Custom: a dial (you set what changes). Space turns its pointer.
static func _dial(canvas: CanvasItem, w: float, color: Color, turned: bool):
	_disc(canvas, Vector2.ZERO, 1.0, color, w)
	_disc(canvas, Vector2.ZERO, 0.62, Color(0.97, 0.97, 0.94), w * 0.8)
	for i in 5:
		var mark := Vector2.from_angle(PI * 0.75 + i * PI * 0.375)
		canvas.draw_line(mark * 0.4, mark * 0.55, INK, w * 0.6)
	var pointer := Vector2.from_angle(-PI * 0.25 if turned else PI * 0.75) * 0.5
	canvas.draw_line(Vector2.ZERO, pointer, INK, w * 1.8)
	canvas.draw_circle(Vector2.ZERO, 0.13, INK)
