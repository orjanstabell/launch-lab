class_name TrajectoryPreview
extends Node2D
## Dotted path, white = what will happen:
##   before launch: the path the next bird will take
##   in flight: the formula segment the bird is following right now
## Yellow (in flight) = where the ability would send the bird (or, for the blue
## bird, each piece) if you pressed Activate right now. It moves along with the
## bird, so you can time it.
## Dots are placed at equal time steps, so wider gaps mean the bird is moving faster.
## Hidden when "Predictions" is hidden (see Reveal), so you can guess first.

const DOT_INTERVAL := 0.1   # seconds between dots
const MAX_TIME := 30.0
const MAX_DISTANCE_M := 60.0
const MAX_HEIGHT_M := 40.0
const CURRENT_COLOR := Color(1, 1, 1, 0.9)
const PENDING_COLOR := Color(1.0, 0.85, 0.2, 0.9)


func _ready():
	PhysicsParams.values_changed.connect(queue_redraw)
	PhysicsParams.flight_changed.connect(queue_redraw)
	Reveal.changed.connect(queue_redraw)


var _drawn_zoom := 0.0


func _process(_delta: float):
	# Redraw while flying (the yellow path starts at the moving bird) and when the zoom changes.
	if PhysicsParams.is_flying() or not is_equal_approx(DrawUtil.zoom(self), _drawn_zoom):
		queue_redraw()


func _draw():
	_drawn_zoom = DrawUtil.zoom(self)
	if Reveal.is_hidden("predict"):
		return
	if PhysicsParams.is_flying():
		var bird: Bird = PhysicsParams.bird
		for segment in bird.preview_segments():
			_draw_path(segment, PENDING_COLOR, 3.5)
		_draw_path(bird.segment, CURRENT_COLOR, 4.0)
		for piece in bird.pieces:   # after a blue bird split
			if piece != bird and is_instance_valid(piece) and piece.state == Bird.State.FLYING:
				_draw_path(piece.segment, CURRENT_COLOR, 3.0)
	else:
		_draw_path(PhysicsParams.launch_params(), CURRENT_COLOR, 4.0)


func _draw_path(p: LaunchParams, color: Color, radius: float):
	radius *= DrawUtil.size_factor(self)   # see the zoom rule in draw_util.gd
	var end_time := minf(Kinematics.time_of_flight(p), MAX_TIME)
	var dot_count := int(end_time / DOT_INTERVAL)
	for i in dot_count + 1:
		var pos := Kinematics.position(p, i * DOT_INTERVAL)
		if pos.x > MAX_DISTANCE_M or pos.y > MAX_HEIGHT_M:
			return
		draw_circle(Units.to_px(pos), radius, color)
	# Finish exactly at the landing point (y = 0), which usually falls between two dots.
	if end_time < MAX_TIME:
		draw_circle(Units.to_px(Kinematics.position(p, end_time)), radius, color)
