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


static func save(level: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var path := path_for(level["name"])
	write(path, level)
	return path


static func delete(level_name: String):
	var path := path_for(level_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func exists(level_name: String) -> bool:
	return FileAccess.file_exists(path_for(level_name))


## A safe file name from the level name ("Moon gravity!" → "moon_gravity.json").
static func path_for(level_name: String) -> String:
	var safe := ""
	for character in level_name.to_lower():
		safe += character if character.is_valid_identifier() or character.is_valid_int() else "_"
	return FOLDER + (safe if safe.strip_edges() != "" else "level") + ".json"


static func write(path: String, level: Dictionary):
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(level, "\t"))


## The level in a JSON file, or {} if it can't be read.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("name"):
		return {}
	var level: Dictionary = parsed
	# Fill in anything an older or hand-made file leaves out.
	var blank := Level.blank(level["name"])
	for key in blank:
		if not level.has(key):
			level[key] = blank[key]
	return level
