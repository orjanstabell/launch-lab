class_name LevelsPanel
extends VBoxContainer
## The Levels tab: pick a level and play it.
##   ★ levels are built in; the others are levels you saved (in the Editor tab).
##   Click one to read its task, double-click (or Load) to play it.
##   Delete removes a saved level (a second click confirms); Import… adds a level .json file (e.g. one
##   handed out for a class). Random plays a new random level (LevelGenerator).

var main: Node   # set by main: loads levels

var _list: ItemList
var _about: Label
var _status: Label
var _levels: Array[Dictionary] = []   # what each list row loads: {"level", "saved"}
var _on_uploaded: JavaScriptObject   # kept here so the browser's callback stays alive
var _delete_armed := ""   # the saved level a first click on Delete picked: a second click deletes it


func _ready():
	add_theme_constant_override("separation", 4)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(600, 118)
	_list.max_columns = 2
	_list.same_column_width = true
	_list.item_selected.connect(_on_selected)
	_list.item_activated.connect(func(_index): _load_selected())
	add_child(_list)

	_about = Label.new()
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.custom_minimum_size = Vector2(600, 0)
	_about.add_theme_font_size_override("font_size", 16)
	_about.modulate = Color(1, 1, 1, 0.8)
	add_child(_about)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_add_button(row, "Load", _load_selected, "Play this level (double-click works too)")
	_add_button(row, "Import…", _import, "Add a level .json file to your levels")
	_add_button(row, "Random", _play_random, "Play a new random level (to keep it, Save it in the Editor tab)")
	_status = Label.new()
	_status.modulate = Color(1, 1, 1, 0.6)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_status)
	# Away from Load, and red: it can't be undone.
	var delete := _add_button(row, "Delete", _delete_selected, "Delete this saved level (★ levels are built in). Click twice: it can't be undone.")
	delete.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	delete.add_theme_color_override("font_hover_color", Color(1.0, 0.65, 0.6))

	visibility_changed.connect(_on_visibility_changed)
	refresh()


## Coming back to the tab: pick up levels saved in the Editor meanwhile.
func _on_visibility_changed():
	if is_visible_in_tree():
		refresh()


func setup(owner_main: Node):
	main = owner_main


func refresh(select_name := ""):
	_list.clear()
	_levels.clear()
	for preset in LevelPresets.all():
		_list.add_item("★ " + preset["name"])
		_levels.append({"level": preset, "saved": false})
	for level in LevelStore.list():
		_list.add_item(level["name"])
		_levels.append({"level": level, "saved": true})
		if level["name"] == select_name:
			_list.select(_list.item_count - 1)
	_on_selected(_list.get_selected_items()[0] if _list.is_anything_selected() else -1)


func _on_selected(index: int):
	_delete_armed = ""
	if index < 0:
		_about.text = "Pick a level to read its task."
		return
	var level: Dictionary = _levels[index]["level"]
	var task: String = level.get("description", "")
	_about.text = task if task != "" else "(no task text)"


func _selected() -> Dictionary:
	return _levels[_list.get_selected_items()[0]] if _list.is_anything_selected() else {}


func _load_selected():
	var choice := _selected()
	if choice.is_empty():
		_status.text = "Pick a level first."
		return
	main.load_level(choice["level"])
	_status.text = "Playing \"%s\"." % choice["level"]["name"]


func _play_random():
	var level := LevelGenerator.generate(randi())
	main.load_level(level)
	_status.text = "Playing \"%s\"." % level["name"]


func _delete_selected():
	var choice := _selected()
	if choice.is_empty() or not choice["saved"]:
		_status.text = "Only your own saved levels can be deleted."
		return
	var level_name: String = choice["level"]["name"]
	if _delete_armed != level_name:   # it's gone for good (no undo), so the first click only asks
		_delete_armed = level_name
		_status.text = "Click Delete again to delete \"%s\" for good." % level_name
		return
	LevelStore.delete(level_name)
	refresh()   # (disarms Delete)
	_status.text = "Deleted \"%s\"." % level_name


func _import():
	if OS.has_feature("web"):
		_import_in_browser()
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; Level files"])
	dialog.close_requested.connect(dialog.queue_free)
	dialog.file_selected.connect(_on_import_chosen.bind(dialog))
	add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


## A browser page can't browse the computer's folders, so it opens the browser's
## own "open file" window instead and gets the file's text back.
func _import_in_browser():
	_on_uploaded = JavaScriptBridge.create_callback(func(args: Array): _import_level(LevelStore.parse(str(args[0]))))
	JavaScriptBridge.get_interface("window").godotLevelUploaded = _on_uploaded
	JavaScriptBridge.eval("""
		const input = document.createElement('input');
		input.type = 'file';
		input.accept = '.json,application/json';
		input.onchange = () => input.files[0].text().then(text => window.godotLevelUploaded(text));
		input.click();
	""", true)


func _on_import_chosen(path: String, dialog: FileDialog):
	dialog.queue_free()
	_import_level(LevelStore.read(path))


func _import_level(level: Dictionary):
	if level.is_empty():
		_status.text = "That file isn't a level."
		return
	if LevelStore.exists(level["name"]):   # never replace a level that's already saved
		level["name"] = LevelStore.unused_name(level["name"] + " (copy)")
	if not LevelStore.save(level):
		_status.text = "Couldn't save \"%s\"." % level["name"]
		return
	refresh(level["name"])
	_status.text = "Imported \"%s\"." % level["name"]


func _add_button(parent: Container, text: String, on_pressed: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(70, 30)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
