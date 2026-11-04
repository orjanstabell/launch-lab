class_name MarkersOverlay
extends Node2D
## Marks the highest point and the landing point of the predicted path (the
## next launch, or the segment the bird is on), with their computed values.
## Hidden along with the path when "Predictions" is hidden.

const APEX_COLOR := Color(1.0, 1.0, 1.0)
const LANDING_COLOR := Color(1.0, 0.55, 0.55)


func _process(_delta: float):
	if visible:
		queue_redraw()


func _draw():
	if Reveal.is_hidden("predict"):
		return
	var bird: Bird = PhysicsParams.bird
	var flying := PhysicsParams.is_flying()
	var p: LaunchParams = bird.segment if flying else PhysicsParams.launch_params()
	var first_segment := not flying or bird.activations == 0
	var from := ["predict", "g", "v0", "theta", "y0" if first_segment else "y"]
	var k := DrawUtil.size_factor(self)   # see the zoom rule in draw_util.gd

	var apex_t := Kinematics.time_to_apex(p)
	if apex_t > 0.0 and not is_inf(apex_t):   # a path that only goes down has no apex ahead
		var apex := Kinematics.position(p, apex_t)
		_marker(Units.to_px(apex), APEX_COLOR, k)
		DrawUtil.label(self, Units.to_px(apex), Vector2(-60, -18), "top: y = %s m" % Reveal.num(apex.y, from), APEX_COLOR)

	var land_t := Kinematics.time_of_flight(p)
	if not is_inf(land_t):
		var landing := Kinematics.position(p, land_t)
		_marker(Units.to_px(landing), LANDING_COLOR, k)
		DrawUtil.label(self, Units.to_px(landing), Vector2(-70, -18), "lands: x = %s m" % Reveal.num(landing.x, from + (["x"] if not first_segment else [])), LANDING_COLOR)


func _marker(center: Vector2, color: Color, k: float):
	draw_arc(center, 8.0 * k, 0.0, TAU, 20, Color.BLACK, 4.0 * k, true)
	draw_arc(center, 8.0 * k, 0.0, TAU, 20, color, 2.0 * k, true)
