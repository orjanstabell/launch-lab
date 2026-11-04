class_name Level
extends RefCounted
## A level is a plain Dictionary, so it saves straight to JSON:
##   name, description (the task shown to the student)
##   blocks: [{"x", "y", "w", "h"}]   centers and sizes in meters
##   pigs:   [{"x", "y"}]             centers in meters ("big": true for a big pig, "mass" in kg)
##   launch: launch values, launch_mode, spring, bird_type, ability, ability_on, split, rocket, egg
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
	level["rocket"] = PhysicsParams.rocket.duplicate()
	level["egg"] = PhysicsParams.egg.duplicate()
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
## doesn't mention keeps its current value. Anything unknown or of the wrong
## kind (a hand-edited file, or one saved by a newer version) is skipped.
static func apply_settings(level: Dictionary):
	# The launch mode first: in spring mode, setting m recomputes v₀ from the spring.
	var mode: String = level.get("launch_mode", "speed") if level.get("launch_mode") in ["speed", "spring"] else "speed"
	for key in _known_numbers(level.get("spring"), PhysicsParams.SPRING_DEFINITIONS):
		PhysicsParams.set_spring_value(key, level["spring"][key])
	PhysicsParams.set_launch_mode(mode)
	for key in _known_numbers(level.get("launch"), PhysicsParams.DEFINITIONS):
		PhysicsParams.set_value(key, level["launch"][key])
	PhysicsParams.set_launch_mode(mode)   # (spring mode: v₀ from k, Δx and the new m)
	var bird_type: Variant = level.get("bird_type")
	if bird_type is String and BirdTypes.TYPES.has(bird_type) and not BirdTypes.TYPES[bird_type].get("hidden", false):
		PhysicsParams.set_bird_type(bird_type)
	var ability_on: Variant = level.get("ability_on")
	if ability_on is Dictionary:
		for key in ability_on:
			if key in PhysicsParams.ability_on and ability_on[key] is bool:
				PhysicsParams.set_ability_on(key, ability_on[key])
	for key in _known_numbers(level.get("ability"), PhysicsParams.ABILITY_DEFINITIONS):
		PhysicsParams.set_ability_value(key, level["ability"][key])
	for key in _known_numbers(level.get("rocket"), PhysicsParams.ROCKET_DEFINITIONS):
		PhysicsParams.set_rocket_value(key, level["rocket"][key])
	for key in _known_numbers(level.get("egg"), PhysicsParams.EGG_DEFINITIONS):
		PhysicsParams.set_egg_value(key, level["egg"][key])
	if level.get("egg") is Dictionary and level["egg"].get("straight_down") is bool:
		PhysicsParams.set_egg_straight_down(level["egg"]["straight_down"])
	var split: Variant = level.get("split")
	if split is Dictionary:
		for key in split:
			if split[key] is float or split[key] is int or split[key] is bool:
				PhysicsParams.set_split(key, split[key])   # (it keeps them in range)
	if level.get("elasticity") is float or level.get("elasticity") is int:
		PhysicsParams.set_elasticity(level["elasticity"])
	var target: Variant = level.get("target")
	if target is Array and target.size() == 2 and target.all(func(n): return n is float or n is int):
		PhysicsParams.set_target(Vector2(target[0], target[1]))
	elif not level.get("pigs", []).is_empty():
		PhysicsParams.set_target(Vector2(level["pigs"][0]["x"], level["pigs"][0]["y"]))
	Reveal.show_all()
	for key in level.get("hidden", []):
		if Reveal.hidden.has(key):
			Reveal.set_hidden(key, true)
	if level.get("randomize_hidden", false):
		Reveal.randomize_hidden()


## The keys of `values` that `definitions` knows and that hold a number.
static func _known_numbers(values: Variant, definitions: Dictionary) -> Array:
	if not (values is Dictionary):
		return []
	return values.keys().filter(func(key): return key in definitions and (values[key] is float or values[key] is int))
