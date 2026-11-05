class_name LevelGenerator
extends RefCounted
## Random levels, built from prefabs: small structures that stand on their own
## (the same ones the built-in levels use), set side by side with gaps.
## Only levels where every pig can be reached by a clear shot are kept.

const PREFABS := ["tower", "box", "pillar", "wall", "pit", "pig", "big_pig"]
const FIRST_X := 16.0   # meters: where the first prefab may start
const BIRD_ROOM := 0.35   # a path closer than this to a block would clip it
const MAX_TRIES := 100


## A random level. The same seed always gives the same level.
static func generate(level_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	for i in MAX_TRIES:
		var level := _build(rng)
		if _winnable(level):
			level["name"] = "Random %d" % level_seed
			return level
	return LevelPresets.tower()   # never seen in practice: most layouts are winnable


static func _build(rng: RandomNumberGenerator) -> Dictionary:
	var level := Level.blank()
	level["description"] = "A random level: knock down every pig. (To keep it, Save it in the Editor tab.)"
	level["launch"] = {"g": 9.81, "y0": 0.0}   # what the winnable check assumes
	var x := FIRST_X + rng.randf_range(0.0, 6.0)
	for i in rng.randi_range(2, 3):
		x = _add_prefab(level, PREFABS[rng.randi() % PREFABS.size()], x, rng) + rng.randf_range(2.0, 6.0)
	return level


## Adds prefab `kind` with its left edge at `left` (meters). Returns its right edge.
static func _add_prefab(level: Dictionary, kind: String, left: float, rng: RandomNumberGenerator) -> float:
	match kind:
		"tower":   # two posts and a plank, the pig on top
			LevelPresets.add_tower(level, left + 1.4)
			return left + 2.8
		"box":
			Level.add_block(level, Vector2(1.0, 1.0), Vector2(left + 0.5, 0.5))
			Level.add_pig(level, Vector2(left + 0.5, 1.4))
			return left + 1.0
		"pillar":   # the pig on top
			var height: float = [3.0, 5.0, 8.0][rng.randi() % 3]
			Level.add_block(level, Vector2(1.0, height), Vector2(left + 0.5, height / 2.0))
			Level.add_pig(level, Vector2(left + 0.5, height + 0.4))
			return left + 1.0
		"wall":   # no pig: it's in the way
			var height: float = [3.0, 5.0, 7.0][rng.randi() % 3]
			Level.add_block(level, Vector2(0.4, height), Vector2(left + 0.2, height / 2.0))
			return left + 0.4
		"pit":   # two walls, the pig at the bottom between them
			Level.add_block(level, Vector2(0.4, 3.0), Vector2(left + 0.2, 1.5))
			Level.add_block(level, Vector2(0.4, 3.0), Vector2(left + 5.2, 1.5))
			Level.add_pig(level, Vector2(left + 2.7, 0.4))
			return left + 5.4
		"pig":
			Level.add_pig(level, Vector2(left + 0.4, 0.4))
			return left + 0.8
		_:   # "big_pig"
			Level.add_pig(level, Vector2(left + Pig.BIG_RADIUS_M, Pig.BIG_RADIUS_M), true)
			return left + 2.0 * Pig.BIG_RADIUS_M


## At least one pig, and every pig has a clear shot.
static func _winnable(level: Dictionary) -> bool:
	if level["pigs"].is_empty():
		return false
	for pig in level["pigs"]:
		if not _has_clear_shot(level, Vector2(pig["x"], pig["y"])):
			return false
	return true


## Is there a launch (g = 9.81, y₀ = 0, v₀ within the slider) that reaches
## `target` without touching a block on the way?
static func _has_clear_shot(level: Dictionary, target: Vector2) -> bool:
	for theta in range(10, 82, 2):
		var p := LaunchParams.new()
		p.theta_deg = theta
		p.v0 = Kinematics.solve_speed(theta, p.g, 0.0, target)
		if is_nan(p.v0) or p.v0 > PhysicsParams.DEFINITIONS["v0"]["max"]:
			continue
		if path_clear(level, p, Kinematics.closest_approach(p, target).x):
			return true
	return false


## True if path `p` stays clear of the level's blocks until time `until`.
static func path_clear(level: Dictionary, p: LaunchParams, until: float) -> bool:
	for i in int(until / 0.01):
		var at := Kinematics.position(p, i * 0.01)
		for block in level["blocks"]:
			if absf(at.x - block["x"]) < block["w"] / 2.0 + BIRD_ROOM and absf(at.y - block["y"]) < block["h"] / 2.0 + BIRD_ROOM:
				return false
	return true
