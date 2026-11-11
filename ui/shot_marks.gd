class_name ShotMarks
extends Node2D
## What a shot leaves in the world for the class to read from the back row:
##   the miss, as a tape measure from where the path came closest to the can it
##   was nearest to, with the distance in big figures;
##   and, before a lecture cue's shot, a ring where its ability will fire by itself.
## Positions are in world pixels.

const TAPE_COLOR := Color(1.0, 0.92, 0.3)
const RING_COLOR := Color(1.0, 0.85, 0.2)

var _tape := {}   # {"from", "to", "text"}
var _ring := {}   # {"at", "text"}
var _drawn_zoom := 0.0


func _process(_delta: float):
	if not is_equal_approx(DrawUtil.zoom(self), _drawn_zoom):
		queue_redraw()


func show_miss(from: Vector2, to: Vector2, text: String):
	_tape = {"from": from, "to": to, "text": text}
	queue_redraw()


func show_ring(at: Vector2, text: String):
	_ring = {"at": at, "text": text}
	queue_redraw()


func clear():
	_tape = {}
	_ring = {}
	queue_redraw()


func _draw():
	_drawn_zoom = DrawUtil.zoom(self)
	var k := DrawUtil.size_factor(self)
	if not _ring.is_empty():
		draw_arc(_ring["at"], 14.0 * k, 0.0, TAU, 32, Color.BLACK, 7.0 * k, true)
		draw_arc(_ring["at"], 14.0 * k, 0.0, TAU, 32, RING_COLOR, 4.0 * k, true)
		DrawUtil.label(self, _ring["at"], Vector2(24, -14), _ring["text"], RING_COLOR, false, true, 26)
	if not _tape.is_empty():
		var from: Vector2 = _tape["from"]
		var to: Vector2 = _tape["to"]
		var across := (to - from).normalized().orthogonal() * 12.0 * k
		for pass_ in [[Color.BLACK, 10.0], [TAPE_COLOR, 6.0]]:   # a dark edge, so it reads on sky and ground
			draw_line(from, to, pass_[0], pass_[1] * k)
			for end in [from, to]:
				draw_line(end - across, end + across, pass_[0], pass_[1] * k)
		DrawUtil.label(self, (from + to) / 2.0, Vector2(18, -18), _tape["text"], TAPE_COLOR, false, true, 40)
