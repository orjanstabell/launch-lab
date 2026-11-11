class_name DrawUtil
extends RefCounted
## Small drawing helpers shared by the overlays.
##
## Zoom rule: when the camera zooms in, the world grows by `zoom`, but overlay
## arrows, labels and arcs only grow by √zoom. So at 3× they're 1.7× bigger:
## clearer, but still fit on screen. Overlays give sizes in "screen px at 1×"
## and multiply by size_factor() to get world px.

const FONT_SIZE := 18


## How much the camera is zoomed in on `canvas` (1 = not zoomed).
static func zoom(canvas: CanvasItem) -> float:
	return canvas.get_viewport().get_canvas_transform().get_scale().x


## Multiply an overlay size (px at 1×) by this to get world px, following the zoom rule.
static func size_factor(canvas: CanvasItem) -> float:
	var z := zoom(canvas)
	return sqrt(z) / z


## Text with a dark outline, readable on any background.
## `anchor` is a world point; `offset` is in px at 1× from there to the left end
## of the baseline. right_align puts the END of the text at the offset instead.
## outlined = false skips the dark outline (for quiet labels such as rulers).
## The text is drawn at its final on-screen size, so it stays sharp when zoomed.
static func label(canvas: CanvasItem, anchor: Vector2, offset: Vector2, text: String, color: Color, right_align := false, outlined := true, font_size := FONT_SIZE):
	var z := zoom(canvas)
	var grow := sqrt(z)
	var font := ThemeDB.fallback_font
	var size := roundi(font_size * grow)
	var pos := offset * grow
	if right_align:
		pos.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_set_transform(anchor, 0.0, Vector2.ONE / z)   # undo the zoom: draw in screen px
	if outlined:
		canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, roundi(6 * grow), Color.BLACK)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	canvas.draw_set_transform(Vector2.ZERO)


## A line with an arrowhead at `to`. Skipped if it's too short to see.
static func arrow(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color):
	var k := size_factor(canvas)
	if from.distance_to(to) < 4.0 * k:
		return
	canvas.draw_line(from, to, color, 3.0 * k, true)
	var dir := (to - from).normalized()
	var side := dir.orthogonal() * 7.0 * k
	var back := to - dir * 12.0 * k
	canvas.draw_colored_polygon(PackedVector2Array([to + dir * 4.0 * k, back + side, back - side]), color)


## Arrow length (px at 1×) for a force that can be anything from a pig's weight to
## a hit thousands of times bigger: it grows with log₁₀(1 + F), so 10 N and 3000 N
## both fit, and two equal forces still get equal arrows. The labels give the true value.
static func log_arrow_length(newtons: float) -> float:
	return 40.0 * log(1.0 + newtons) / log(10.0)
