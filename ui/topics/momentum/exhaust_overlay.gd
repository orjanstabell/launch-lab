class_name ExhaustOverlay
extends Node2D
## Velocity arrows on some of the rocket's exhaust puffs (every third one, so it
## stays readable), measured from the ground. While the bird is slower than v_e
## the exhaust flies backwards; once the bird is faster, the exhaust still moves
## forwards, just slower than the bird.

const PX_PER_MPS := 6.0
const EVERY := 3
const COLOR := Color(1.0, 0.7, 0.4)


func _process(_delta: float):
	if visible:
		queue_redraw()


func _draw():
	var bird: Bird = PhysicsParams.bird
	if not is_instance_valid(bird) or bird.exhaust == null or not is_instance_valid(bird.exhaust):
		return
	var k := DrawUtil.size_factor(self)
	var exhaust := bird.exhaust
	var labelled := false
	for i in range(exhaust.puffs.size() - 1, -1, -EVERY):   # newest first
		var puff: Dictionary = exhaust.puffs[i]
		var at := Units.to_px(exhaust.puff_position(puff))
		var v := exhaust.puff_velocity(puff)
		var tip := at + Vector2(v.x, -v.y) * PX_PER_MPS * k
		DrawUtil.arrow(self, at, tip, Color(COLOR, 0.8))
		if not labelled:
			DrawUtil.label(self, tip, Vector2(6, 14), "exhaust: %s m/s (from the ground)" % Reveal.num(v.length(), ["v"]), COLOR)
			labelled = true
