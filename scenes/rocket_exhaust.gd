class_name RocketExhaust
extends Node2D
## What a burning rocket bird throws out the back. The rocket's motion is exact
## maths (see Kinematics), so this is only a picture of the exhaust: 30 "puffs" a
## second, each carrying the fuel burnt in that time (ṁ·Δt) at the bird's
## velocity minus v_e along the thrust, then flying as a projectile.
## Bird + exhaust together keep the momentum the bird alone would have had
## (apart from gravity): the Momentum topic checks that live.

const PUFFS_PER_SECOND := 30.0
const LIFETIME := 2.5   # seconds a puff stays visible

var bird: Bird
var puffs: Array[Dictionary] = []   # {"at": Vector2 m, "velocity": Vector2 m/s, "born": s, "mass": kg}
var g := 9.81
var _time := 0.0
var _next_emit := 0.0   # segment time of the next puff


func _physics_process(delta: float):
	# It sits under the trails, which keep running while paused (to redraw on
	# zoom changes), so freeze it here like the rest of the world.
	if get_tree().paused:
		queue_redraw()
		return
	_time += delta
	if is_instance_valid(bird) and bird.state == Bird.State.FLYING and bird.segment.is_rocket():
		var segment := bird.segment
		g = segment.g
		var step := 1.0 / PUFFS_PER_SECOND
		while _next_emit <= minf(bird.t, segment.burn_time):
			var emit_time := _next_emit
			_next_emit += step
			var age := bird.t - emit_time   # it may have left a moment ago
			var velocity := Kinematics.velocity(segment, emit_time) - segment.thrust_dir * segment.exhaust_speed
			var at := Kinematics.position(segment, emit_time) - segment.thrust_dir * bird.radius_m
			puffs.append({"at": at, "velocity": velocity, "born": _time - age, "mass": segment.burn_rate * minf(step, segment.burn_time - emit_time)})
	# Old puffs fade out.
	while not puffs.is_empty() and _time - puffs[0]["born"] > LIFETIME:
		puffs.pop_front()
	queue_redraw()


## Where a puff is now, and how fast it's going (it flies as a projectile).
func puff_position(puff: Dictionary) -> Vector2:
	var age: float = _time - puff["born"]
	return puff["at"] + puff["velocity"] * age + Vector2(0, -0.5 * g * age * age)


func puff_velocity(puff: Dictionary) -> Vector2:
	return puff["velocity"] + Vector2(0, -g * (_time - puff["born"]))


func _draw():
	var k := DrawUtil.size_factor(self)
	for puff in puffs:
		var fade: float = 1.0 - (_time - puff["born"]) / LIFETIME
		draw_circle(Units.to_px(puff_position(puff)), 3.0 * k, Color(0.9, 0.6, 0.3, 0.8 * fade))
