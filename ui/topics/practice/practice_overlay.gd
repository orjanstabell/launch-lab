class_name PracticeOverlay
extends Node2D
## Draws the practice problem in the world: the pigs to hit, markers (your
## prediction, a required height...), ghost birds flying what your answer says
## would happen, the pieces' center of mass, and, once asked for, the correct path.

const TARGET_COLOR := Color(1.0, 0.3, 0.3)
const MARKER_COLOR := Color(1.0, 0.85, 0.2)
const SOLUTION_COLOR := Color(0.3, 1.0, 0.4)
const REAL_COLOR := Color(0.35, 0.85, 1.0)   # "what really happened" arrows
const GHOST_COLOR := Color(0.92, 0.92, 1.0)
const COM_COLOR := Color(1.0, 0.5, 0.95)
const PIG_RADIUS_M := 0.3
const GHOST_RADIUS_M := 0.3

var practice: PracticePanel


func _process(_delta: float):
	if visible:
		queue_redraw()


func _draw():
	var problem := practice.problem
	if problem == null:
		return
	var k := DrawUtil.size_factor(self)   # see the zoom rule in draw_util.gd

	for target in problem.targets:
		_draw_pig(Units.to_px(target), k)

	for marker in problem.markers(practice.given):
		if practice.sim_time < marker.get("at", 0.0):
			continue   # not yet: it appears when the shot gets there
		match marker["type"]:
			"height":
				var value: float = marker["value"]
				draw_dashed_line(Units.to_px(Vector2(0, value)), Units.to_px(Vector2(45, value)), MARKER_COLOR, 2.0 * k, 10.0 * k)
				DrawUtil.label(self, Units.to_px(Vector2(0, value)), Vector2(8, -8), marker["label"], MARKER_COLOR)
			"x":
				_draw_flag(marker["value"], marker["label"], k)
			"point":
				var at := Units.to_px(marker["pos"])
				draw_circle(at, 7.0 * k, MARKER_COLOR)
				draw_arc(at, 11.0 * k, 0.0, TAU, 24, MARKER_COLOR, 2.0 * k, true)
				DrawUtil.label(self, at, Vector2(14, -14), marker["label"], MARKER_COLOR)
			"arrow":
				var color := MARKER_COLOR if marker["who"] == "you" else REAL_COLOR
				var from := Units.to_px(marker["pos"])
				var to := Units.to_px(marker["pos"] + marker["vector"])
				DrawUtil.arrow(self, from, to, color)
				DrawUtil.label(self, (from + to) / 2.0, Vector2(12, -8 if marker["who"] == "you" else 18), marker["label"], color)
			"clock":
				var bird: Bird = PhysicsParams.bird
				if is_instance_valid(bird) and not practice.given.is_empty():
					DrawUtil.label(self, bird.position, Vector2(18, -26), "t = %s s" % Problem.n(minf(practice.sim_time, marker["until"])), MARKER_COLOR)

	if not practice.given.is_empty():
		_draw_ghosts(problem.ghosts(practice.given), k)
	if problem.show_com:
		_draw_center_of_mass(k)

	if practice.solution_shown:
		for part in problem.solution_paths():
			var p: LaunchParams = part["params"]
			var until := minf(minf(part["until"], Kinematics.time_of_flight(p)), 30.0)
			for i in int(until / 0.1) + 1:
				draw_circle(Units.to_px(Kinematics.position(p, i * 0.1)), 3.5 * k, SOLUTION_COLOR)
			draw_circle(Units.to_px(Kinematics.position(p, until)), 3.5 * k, SOLUTION_COLOR)


## A flag on the ground at x.
func _draw_flag(x: float, text: String, k: float):
	var foot := Units.to_px(Vector2(x, 0))
	var top := Units.to_px(Vector2(x, 1.5))
	draw_line(foot, top, MARKER_COLOR, 3.0 * k)
	draw_colored_polygon(PackedVector2Array([top, top + Vector2(22, 8) * k, top + Vector2(0, 16) * k]), MARKER_COLOR)
	DrawUtil.label(self, top, Vector2(-30, -10), text, MARKER_COLOR)


## Each ghost: its trail so far and a see-through bird where it is now, keeping
## pace with the real shot (practice.sim_time). Parts with the same label are one ghost.
func _draw_ghosts(parts: Array[Dictionary], k: float):
	var now := {}   # label -> where that ghost is
	for part in parts:
		var local: float = practice.sim_time - part["start"]
		if local < 0.0:
			continue
		var p: LaunchParams = part["params"]
		var shown := minf(local, PracticePanel.ghost_duration(part))
		for i in int(shown / 0.1) + 1:
			draw_circle(Units.to_px(Kinematics.position(p, i * 0.1)), 3.0 * k, Color(GHOST_COLOR, 0.7))
		now[part["label"]] = Units.to_px(Kinematics.position(p, shown))
	var r := GHOST_RADIUS_M * Units.PIXELS_PER_METER
	for label in now:
		draw_circle(now[label], r, Color(GHOST_COLOR, 0.35))
		draw_arc(now[label], r, 0.0, TAU, 28, GHOST_COLOR, 2.0 * k, true)
		DrawUtil.label(self, now[label], Vector2(14, 26), label, GHOST_COLOR)


## The pieces' center of mass ✛ after a split.
func _draw_center_of_mass(k: float):
	var bird: Bird = PhysicsParams.bird
	if not is_instance_valid(bird) or bird.pieces.size() < 2:
		return
	var com := Vector2.ZERO
	var total := 0.0
	for piece in bird.pieces:
		if is_instance_valid(piece):
			com += piece.mass_now() * piece.position
			total += piece.mass_now()
	com /= total
	var size := 14.0 * k
	draw_line(com - Vector2(size, 0), com + Vector2(size, 0), COM_COLOR, 3.0 * k)
	draw_line(com - Vector2(0, size), com + Vector2(0, size), COM_COLOR, 3.0 * k)
	DrawUtil.label(self, com, Vector2(16, -12), "center of mass", COM_COLOR)


## A little pig with a crosshair on it.
func _draw_pig(center: Vector2, k: float):
	var r := PIG_RADIUS_M * Units.PIXELS_PER_METER
	draw_circle(center, r, Color(0.45, 0.8, 0.25))
	draw_circle(center + Vector2(-r * 0.35, -r * 0.3), r * 0.15, Color.BLACK)
	draw_circle(center + Vector2(r * 0.35, -r * 0.3), r * 0.15, Color.BLACK)
	draw_circle(center + Vector2(0, r * 0.2), r * 0.3, Color(0.35, 0.65, 0.18))
	var cross := r * 1.6
	draw_arc(center, cross, 0.0, TAU, 28, TARGET_COLOR, 2.0 * k, true)
	draw_line(center - Vector2(cross * 1.3, 0), center + Vector2(cross * 1.3, 0), TARGET_COLOR, 1.5 * k)
	draw_line(center - Vector2(0, cross * 1.3), center + Vector2(0, cross * 1.3), TARGET_COLOR, 1.5 * k)
