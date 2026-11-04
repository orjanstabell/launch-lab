class_name Slingshot
extends Node2D
## The launch point (x₀, y₀). Draws a post up to the launch height from the panel,
## with a bird in it while no bird is flying.
## In spring mode the waiting bird sits pulled back by Δx (opposite the launch
## direction), with the bands stretched. While you drag the bird with the mouse,
## main sets drag_offset and the bird follows it.

const BAND_COLOR := Color(0.3, 0.15, 0.05)

var loaded := true:
	set(value):
		if loaded != value:
			loaded = value
			queue_redraw()

var drag_offset := Vector2.ZERO:   # meters from the launch point (zero = not dragging)
	set(value):
		drag_offset = value
		queue_redraw()


func _ready():
	PhysicsParams.values_changed.connect(queue_redraw)


func _draw():
	var bird_type: Dictionary = BirdTypes.TYPES[PhysicsParams.bird_type]
	var radius: float = bird_type["radius"] * Units.PIXELS_PER_METER
	var launch_point := Units.to_px(Vector2(0, PhysicsParams.values["y0"]))
	var fork := launch_point + Vector2(0, radius)
	var wood := Color(0.4, 0.25, 0.1)
	var left_tip := fork + Vector2(-14, -radius * 1.4)
	var right_tip := fork + Vector2(14, -radius * 1.4)
	draw_line(Vector2.ZERO, fork, wood, 8.0)
	draw_line(fork, left_tip, wood, 6.0)
	draw_line(fork, right_tip, wood, 6.0)
	if not loaded:
		return

	var pulled := pulled_back()
	# Drawn on or above the ground, even if a low launch point and a big pull
	# would put it underground (the Δx label still shows the true pull).
	var bird_m := Vector2(0, PhysicsParams.values["y0"]) + pulled
	bird_m.y = maxf(bird_m.y, bird_type["radius"])
	var bird_at := Units.to_px(bird_m)
	draw_line(left_tip, bird_at, BAND_COLOR, 3.0)
	BirdArt.draw_bird(self, bird_at, radius, PhysicsParams.bird_type)
	draw_line(right_tip, bird_at, BAND_COLOR, 3.0)
	if PhysicsParams.launch_mode == "spring" and pulled.length() > 0.02:
		draw_dashed_line(bird_at, launch_point, Color(1, 1, 1, 0.7), 1.5, 5.0)
		DrawUtil.label(self, bird_at, Vector2(-40, 30), "Δx = %s m" % Reveal.num(pulled.length(), ["pull"]), Color.WHITE)


## Where the waiting bird is, relative to the launch point (meters, y up).
func pulled_back() -> Vector2:
	if drag_offset != Vector2.ZERO:
		return drag_offset
	if PhysicsParams.launch_mode == "spring":
		return -Vector2.from_angle(deg_to_rad(PhysicsParams.values["theta"])) * PhysicsParams.spring["pull"]
	return Vector2.ZERO
