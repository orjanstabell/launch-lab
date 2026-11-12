class_name LevelPresets
extends RefCounted
## The levels that come with the game, each built around one idea.
## (Saved levels live in user://levels/, see LevelStore.)


static func all() -> Array[Dictionary]:
	return [tower(), moon(), two_angles(), hidden_gravity(), high_arc_only(), three_pigs(), egg_drop(), heavy_spring(), yellow_straight()]


## What the game opens on: nothing but the slingshot and the rulers, so a demo
## (or a student trying things out) starts without anything to aim at.
static func open_range() -> Dictionary:
	return Level.blank("Open range")


## The lecture cues: one question each, stepped through with PageDown (a
## presenter clicker's key). A cue is a level with a few more keys:
##   question, options: asked big over the sky, with the future hidden
##   reveal: the one line shown once the physics has answered ("{g}" = the value of g)
##   stop_at_apex: the shot freezes itself at the top of the arc
##   activate_at: the ability fires by itself, at this flight time or at "apex"
##   mark: a label for the ring that shows where it will fire
##   reveal_on_key: the reveal waits for PageDown (the class works something out first)
static func cues() -> Array[Dictionary]:
	return [cue_mass(), cue_apex(), cue_two_angles(), cue_no_gravity(), cue_split(), cue_planet()]


static func _cue(cue_name: String, question: String, options: String, reveal: String) -> Dictionary:
	var level := Level.blank(cue_name)
	level["question"] = question
	level["options"] = options
	level["reveal"] = reveal
	level["hidden"] = ["predict"]
	return level


static func cue_mass() -> Dictionary:
	var level := _cue("Mass and the arc", "1 kg hits the dummy. Same launch, 5 kg?", "A  short   ·   B  hits   ·   C  long",
		"B.  Same arc. 5× the pull on 5× the mass.")
	level["launch"] = {"g": 9.81, "v0": 15.0, "theta": 45.0, "y0": 1.0, "m": 5.0}
	Level.add_pig(level, Vector2(23.6, Pig.RADIUS_M))
	level["topic"] = 1   # Forces & momentum: the F arrow is 5× as long, a is the same
	return level


static func cue_apex() -> Dictionary:
	var level := _cue("Speed at the top", "How fast is it at the top?", "A  zero   ·   B  slower, not zero   ·   C  same as at launch",
		"B.  Not zero. Only the vertical part stopped.")
	level["launch"] = {"g": 9.81, "v0": 15.0, "theta": 60.0, "y0": 1.0, "m": 1.0}
	level["stop_at_apex"] = true
	return level


static func cue_two_angles() -> Dictionary:
	var level := _cue("Two angles, one range", "30° hits the dummy. Does 60°?", "A  short   ·   B  hits   ·   C  long",
		"B.  Same spot. Less speed across, more time aloft.")
	level["launch"] = {"g": 9.81, "v0": 15.0, "theta": 60.0, "y0": 0.0, "m": 1.0}   # (from the ground: a raised launch favours the flat shot)
	Level.add_pig(level, Vector2(19.5, Pig.RADIUS_M))
	return level


static func cue_no_gravity() -> Dictionary:
	var level := _cue("Gravity off", "Gravity switches off here. Then what?", "A  stops   ·   B  keeps curving   ·   C  straight line",
		"C.  Straight line, steady speed. No force, no change.")
	level["launch"] = {"g": 9.81, "v0": 16.0, "theta": 55.0, "y0": 1.0, "m": 1.0}
	level["bird_type"] = "custom"
	level["ability_on"] = {"g": true, "v0": false, "theta": false, "m": false}
	level["ability"] = {"g": 0.0}
	level["activate_at"] = 0.7   # still on its way up
	level["mark"] = "g → 0 here"
	return level


static func cue_split() -> Dictionary:
	var level := _cue("Split and center of mass", "It splits at the top. Where does the center go?", "A  drops   ·   B  stays on the old arc   ·   C  follows the top piece",
		"B.  On the old arc. The center of mass never noticed.")
	level["launch"] = {"g": 9.81, "v0": 17.0, "theta": 50.0, "y0": 1.0, "m": 1.0}
	level["bird_type"] = "blue"
	level["activate_at"] = "apex"
	level["mark"] = "splits here"
	level["topic"] = 1   # Forces & momentum: the center of mass and the old arc
	return level


static func cue_planet() -> Dictionary:
	var level := _cue("Unknown planet", "Unknown planet. Watch it land: which g?", "A  1.6 Moon   ·   B  3.7 Mars   ·   C  9.8 Earth   ·   D  24.8 Jupiter",
		"B.  g = {g} m/s². The arc was the measurement.")
	level["launch"] = {"g": 3.71, "v0": 10.0, "theta": 45.0, "y0": 1.0, "m": 1.0}
	level["hidden"] = ["g", "predict"]
	level["reveal_on_key"] = true
	return level


## The first level: a small tower with the dummy on top.
static func tower() -> Dictionary:
	var level := Level.blank("Tower")
	level["description"] = "Knock the dummy off its tower, then take on the big one in the hard hat (it survives one hit)."
	add_tower(level, 25.0)
	Level.add_pig(level, Vector2(29.5, Pig.BIG_RADIUS_M), true)
	return level


static func moon() -> Dictionary:
	var level := Level.blank("Moon gravity")
	level["description"] = "On the Moon g = 1.62 m/s². Clear the wall and hit the dummy."
	level["launch"] = {"g": 1.62, "v0": 10.0, "theta": 45.0, "y0": 1.0, "m": 1.0}
	Level.add_block(level, Vector2(0.4, 6.0), Vector2(22.0, 3.0))
	Level.add_pig(level, Vector2(38.0, 0.4))
	return level


static func two_angles() -> Dictionary:
	var level := Level.blank("Same range, two angles")
	level["description"] = "v₀ = 16 m/s is fixed. Two different angles hit the dummy: find both."
	level["launch"] = {"g": 9.81, "v0": 16.0, "theta": 20.0, "y0": 1.0, "m": 1.0}
	Level.add_pig(level, Vector2(22.0, 0.4))
	return level


static func hidden_gravity() -> Dictionary:
	var level := Level.blank("Find the hidden g")
	level["description"] = "g is hidden and random. Measure it with a test shot, then hit the dummy."
	level["launch"] = {"v0": 14.0, "theta": 45.0, "y0": 1.0, "m": 1.0}
	level["hidden"] = ["g", "predict"]
	level["randomize_hidden"] = true
	add_tower(level, 24.0)
	return level


static func high_arc_only() -> Dictionary:
	var level := Level.blank("High arc only")
	level["description"] = "v₀ = 17 m/s. The wall blocks the low arc: find the high one."
	level["launch"] = {"g": 9.81, "v0": 17.0, "theta": 30.0, "y0": 1.0, "m": 1.0}
	Level.add_block(level, Vector2(0.4, 7.0), Vector2(19.0, 3.5))
	Level.add_pig(level, Vector2(22.0, 0.4))
	return level


static func three_pigs() -> Dictionary:
	var level := Level.blank("Three dummies, one Splitter")
	level["description"] = "Use the Splitter to hit all three dummies."
	level["launch"] = {"g": 9.81, "v0": 17.0, "theta": 45.0, "y0": 1.0, "m": 1.0}
	level["bird_type"] = "blue"
	for x in [24.0, 27.0, 30.0]:
		Level.add_block(level, Vector2(1.0, 1.0), Vector2(x, 0.5))
		Level.add_pig(level, Vector2(x, 1.4))
	return level


static func egg_drop() -> Dictionary:
	var level := Level.blank("Ballast drop")
	level["description"] = "The dummy hides in a deep pit. Fly the Dropper over it and drop the ballast in."
	level["launch"] = {"g": 9.81, "v0": 17.0, "theta": 50.0, "y0": 1.0, "m": 1.0}
	level["bird_type"] = "matilda"
	Level.add_block(level, Vector2(0.4, 3.0), Vector2(21.0, 1.5))
	Level.add_block(level, Vector2(0.4, 3.0), Vector2(26.0, 1.5))
	Level.add_pig(level, Vector2(23.5, 0.4))
	level["topic"] = 1   # Forces & momentum
	return level


static func heavy_spring() -> Dictionary:
	var level := Level.blank("Spring: heavy ball")
	level["description"] = "A 3 kg ball in the spring slingshot: how far must you pull to reach the dummy?"
	level["launch"] = {"g": 9.81, "theta": 40.0, "y0": 1.0, "m": 3.0}
	level["launch_mode"] = "spring"
	level["spring"] = {"k": 800.0, "pull": 0.6}
	add_tower(level, 26.0)
	return level


static func yellow_straight() -> Dictionary:
	var level := Level.blank("Gravity off: straight shot")
	level["description"] = "Tap (Space) to switch gravity off (g → 0) at the right moment, and fly straight at the dummy."
	level["launch"] = {"g": 9.81, "v0": 18.0, "theta": 60.0, "y0": 1.0, "m": 1.0}
	level["bird_type"] = "custom"
	level["ability_on"] = {"g": true, "v0": false, "theta": false, "m": false}
	level["ability"] = {"g": 0.0}
	Level.add_block(level, Vector2(1.0, 8.0), Vector2(24.0, 4.0))   # a tall pillar
	Level.add_pig(level, Vector2(24.0, 8.4))
	return level


## Two posts and a plank, with the pig on top (the plank's top is at 1.9 m).
static func add_tower(level: Dictionary, x: float):
	Level.add_block(level, Vector2(0.3, 1.6), Vector2(x - 1.0, 0.8))
	Level.add_block(level, Vector2(0.3, 1.6), Vector2(x + 1.0, 0.8))
	Level.add_block(level, Vector2(2.8, 0.3), Vector2(x, 1.75))
	Level.add_pig(level, Vector2(x, 2.3))
