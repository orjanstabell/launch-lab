class_name LevelStore
extends RefCounted
## Saving and loading levels as JSON files in user://levels/ (one file per
## level, named after the level), plus export/import anywhere on disk so levels
## can be handed out, e.g. to a class.

const FOLDER := "user://levels/"


## Every saved level, sorted by name.
static func list() -> Array[Dictionary]:
	var levels: Array[Dictionary] = []
	DirAccess.make_dir_recursive_absolute(FOLDER)
	for file in DirAccess.get_files_at(FOLDER):
		if file.ends_with(".json"):
			var level := read(FOLDER + file)
			if not level.is_empty():
				levels.append(level)
	levels.sort_custom(func(a, b): return String(a["name"]).naturalnocasecmp_to(b["name"]) < 0)
	return levels


static func save(level: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	return write(path_for(level["name"]), level)


static func delete(level_name: String):
	var path := path_for(level_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		if OS.has_feature("web"):
			# shortcut: the browser only stores user:// changes after a file is written, and a
			# delete isn't one, so write a tiny file to make it stick. Drop it once Godot syncs deletes.
			FileAccess.open(FOLDER + ".sync", FileAccess.WRITE)


static func exists(level_name: String) -> bool:
	return FileAccess.file_exists(path_for(level_name))


## `level_name`, with "+" added until no saved level uses it.
static func unused_name(level_name: String) -> String:
	while exists(level_name):
		level_name += "+"
	return level_name


## A safe file name from the level name ("Moon gravity!" → "moon_gravity.json").
static func path_for(level_name: String) -> String:
	var safe := ""
	for character in level_name.to_lower():
		safe += character if character.is_valid_identifier() or character.is_valid_int() else "_"
	return FOLDER + (safe if safe.strip_edges() != "" else "level") + ".json"


## False if the file couldn't be written (e.g. a write-protected USB stick).
static func write(path: String, level: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(to_json(level))
	return true


static func to_json(level: Dictionary) -> String:
	return JSON.stringify(level, "\t")


## The level in a JSON file, or {} if it can't be read.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return parse(FileAccess.get_file_as_string(path))


## The level in JSON text, or {} if it isn't one. The text can come from
## anywhere (Import…), so pieces that are malformed are left out instead of
## breaking the level.
static func parse(json: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json)
	if not (parsed is Dictionary) or not (parsed.get("name") is String):
		return {}
	var level: Dictionary = parsed
	Level.migrate(level)
	# Fill in anything an older or hand-made file leaves out (or has the wrong kind of value for).
	var blank := Level.blank(level["name"])
	for key in blank:
		if not _same_kind(level.get(key), blank[key]):
			level[key] = blank[key]
	level["blocks"] = level["blocks"].filter(func(block): return _numbers(block, ["x", "y", "w", "h"]) and block["w"] > 0.0 and block["h"] > 0.0)
	level["pigs"] = level["pigs"].filter(func(pig): return _numbers(pig, ["x", "y"]) and pig.get("big", false) is bool and (not pig.has("mass") or _numbers(pig, ["mass"])))
	return level


## True if `entry` is a Dictionary whose `keys` all hold numbers.
static func _numbers(entry: Variant, keys: Array) -> bool:
	return entry is Dictionary and keys.all(func(key): return entry.get(key) is float or entry.get(key) is int)


static func _same_kind(value: Variant, example: Variant) -> bool:
	var numbers := [TYPE_INT, TYPE_FLOAT]   # JSON reads every number as a float
	return typeof(value) == typeof(example) or (typeof(value) in numbers and typeof(example) in numbers)
