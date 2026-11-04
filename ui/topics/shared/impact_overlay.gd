class_name ImpactOverlay
extends Node2D
## The last hit, frozen in place where it happened (so you can study it even
## after the pig has gone): the push the bird gave the pig, and the push the pig
## gave the bird.
##   Impulse J = Δp = m·(v_after − v_before)   (N·s, the same as kg·m/s)
##   Average force F = J / Δt                   (Δt = how long the push lasted)
## Newton's 3rd law: the two pushes are equal in size and opposite in direction.
## If they aren't, something else pushed too (the plank or ground under the pig).

const PX_PER_NS := 20.0   # arrow length at 1× zoom: px per N·s
const MAX_ARROW := 300.0
const ON_PIG := Color(0.6, 1.0, 0.4)
const ON_BIRD := Color(1.0, 0.5, 0.4)


func _process(_delta: float):
	if visible:
		queue_redraw()


func _draw():
	var hit := PhysicsParams.collision
	if hit.is_empty() or not hit.has("bird_after") or hit.get("bird") != PhysicsParams.bird:
		return
	var k := DrawUtil.size_factor(self)   # see the zoom rule in draw_util.gd
	var on_other: Vector2 = hit["other_m"] * (hit["other_after"] - hit["other_before"])
	var on_bird: Vector2 = hit["bird_m"] * (hit["bird_after"] - hit["bird_before"])
	var bird_at := Units.to_px(hit["at"])
	var other_at := Units.to_px(hit["other_at"])

	# Ghosts of where they were at the moment of the hit.
	draw_arc(bird_at, 0.3 * Units.PIXELS_PER_METER, 0.0, TAU, 24, Color(ON_BIRD, 0.6), 2.0 * k, true)
	if hit["other_radius"] > 0.0:
		draw_arc(other_at, hit["other_radius"] * Units.PIXELS_PER_METER, 0.0, TAU, 28, Color(ON_PIG, 0.6), 2.0 * k, true)

	_arrow(other_at, on_other, ON_PIG, "push on the %s: J = %s N·s" % [hit["other_name"], _n(on_other.length())], k)
	_arrow(bird_at, on_bird, ON_BIRD, "push on the bird: J = %s N·s" % _n(on_bird.length()), k)

	var duration: float = maxf(hit.get("duration", 0.0), 0.001)
	var opposite := (on_bird + on_other).length() <= 0.2 * maxf(on_other.length(), 0.01)
	var note := "equal and opposite (Newton's 3rd law)" if opposite else "not opposite: something else pushed too"
	DrawUtil.label(self, other_at, Vector2(-120, -70), "F ≈ J/Δt ≈ %s N over Δt ≈ %s s" % [_n(on_other.length() / duration, 0), _n(duration, 3)], Color.WHITE)
	DrawUtil.label(self, other_at, Vector2(-120, -48), note, Color.WHITE)
	if hit.has("measured_e"):
		DrawUtil.label(self, other_at, Vector2(-120, -92), "elasticity e = %s,  KE kept %s%%" % [String.num(hit["measured_e"], 2), String.num(hit["ke_after"] / maxf(hit["ke_before"], 0.001) * 100.0, 0)], Color.WHITE)


func _arrow(from: Vector2, impulse: Vector2, color: Color, text: String, k: float):
	var length := minf(impulse.length() * PX_PER_NS, MAX_ARROW) * k
	var tip := from + Vector2(impulse.x, -impulse.y).normalized() * length   # minus: screen y points down
	DrawUtil.arrow(self, from, tip, color)
	DrawUtil.label(self, tip, Vector2(8, 4), text, color)


func _n(x: float, decimals := 2) -> String:
	return Reveal.num(x, ["p", "F"], decimals)
