class_name Level
extends RefCounted
## A level is a plain Dictionary, so it saves straight to JSON:
##   name, description (the task shown to the student)
##   blocks: [{"x", "y", "w", "h"}]   centers and sizes in meters
##   pigs:   [{"x", "y"}]             centers in meters ("big": true for a big pig, "mass" in kg)
##   launch: launch values, launch_mode, spring, bird_type, ability, ability_on, split
##   hidden: Reveal symbols to hide; randomize_hidden: give them random values on load
##   target: [x, y] for solve mode; topic: which topic tab to show
## capture() reads the current settings into a level; apply_settings() does the reverse.

const VERSION := 1


## An empty level with the default settings.
static func blank(level_name := "New level") -> Dictionary:
	return {
		"version": VERSION,
		"name": level_name,
		"description": "",
		"blocks": [],
		"pigs": [],
		"hidden": [],
		"randomize_hidden": false,
		"topic": 0,
	}


static func add_block(level: Dictionary, size: Vector2, center: Vector2):
	level["blocks"].append({"x": center.x, "y": center.y, "w": size.x, "h": size.y})


static func add_pig(level: Dictionary, center: Vector2, big := false):
	var pig := {"x": center.x, "y": center.y}
	if big:
		pig["big"] = true
	level["pigs"].append(pig)


## The level's objects plus everything currently set up (launch values, bird,
## hidden values...), so loading it later reproduces the exercise.
static func capture(objects: Dictionary, topic: int) -> Dictionary:
	var level := objects.duplicate(true)
	level["version"] = VERSION
	level["launch"] = PhysicsParams.values.duplicate()
	level["launch_mode"] = PhysicsParams.launch_mode
	level["spring"] = PhysicsParams.spring.duplicate()
	level["bird_type"] = PhysicsParams.bird_type
	level["ability"] = PhysicsParams.ability.duplicate()
	level["ability_on"] = PhysicsParams.ability_on.duplicate()
	level["split"] = PhysicsParams.split.duplicate()
	level["elasticity"] = PhysicsParams.elasticity
	level["target"] = [PhysicsParams.target.x, PhysicsParams.target.y]
	level["topic"] = topic
	var hidden := []
	for key in Reveal.hidden:
		if Reveal.hidden[key]:
			hidden.append(key)
	level["hidden"] = hidden
	return level


## Put a level's settings into PhysicsParams and Reveal. Anything the level
## doesn't mention keeps its current value.
static func apply_settings(level: Dictionary):
	# The launch mode first: in spring mode, setting m recomputes v₀ from the spring.
	var mode: String = level.get("launch_mode", "speed")
	for key in level.get("spring", {}):
		PhysicsParams.set_spring_value(key, level["spring"][key])
	PhysicsParams.set_launch_mode(mode)
	for key in level.get("launch", {}):
		if key in PhysicsParams.DEFINITIONS:
			PhysicsParams.set_value(key, level["launch"][key])
	PhysicsParams.set_launch_mode(mode)   # (spring mode: v₀ from k, Δx and the new m)
	if level.has("bird_type"):
		PhysicsParams.set_bird_type(level["bird_type"])
	for key in level.get("ability_on", {}):
		PhysicsParams.set_ability_on(key, level["ability_on"][key])
	for key in level.get("ability", {}):
		PhysicsParams.set_ability_value(key, level["ability"][key])
	for key in level.get("split", {}):
		PhysicsParams.set_split(key, level["split"][key])
	if level.has("elasticity"):
		PhysicsParams.set_elasticity(level["elasticity"])
	if level.has("target"):
		PhysicsParams.set_target(Vector2(level["target"][0], level["target"][1]))
	elif not level.get("pigs", []).is_empty():
		PhysicsParams.set_target(Vector2(level["pigs"][0]["x"], level["pigs"][0]["y"]))
	Reveal.show_all()
	for key in level.get("hidden", []):
		if Reveal.hidden.has(key):
			Reveal.set_hidden(key, true)
	if level.get("randomize_hidden", false):
		Reveal.randomize_hidden()
