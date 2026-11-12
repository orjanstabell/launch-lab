class_name EditorPanel
extends VBoxContainer
## The Editor tab: edit the loaded level. Editing is on while this tab is open
## (the pieces are frozen), and off as soon as you leave it (they come alive).
##   pieces: click in the world to place (it drops onto whatever is below),
##           drag to move, right-click to delete
##   Name / Task / opens on: saved with the level (the task is shown to the player)
##   Save, Save copy, Export…, New; big pig mass for the level's big pig(s)
## Saving also captures the current settings (launch values, bird, hidden values...).

var main: Node   # set by main: owns the level data and the editor

var _name: LineEdit
var _task: LineEdit
var _opens_on: OptionButton
var _big_pig_mass: SpinBox
var _status: Label
var _loaded_name := ""   # the saved level being edited ("" if it's a ★ level or new)


func _ready():
	add_theme_constant_override("separation", 4)

	var row := _add_row()
	var group := ButtonGroup.new()
	for piece in LevelEditor.PIECES:
		var button := _add_button(row, piece, func(): main.editor.piece = piece, "Place: %s" % piece)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = piece == "box"
	_add_button(row, "Clear", _clear, "Remove every piece")

	row = _add_row()
	_add_label(row, "Name")
	_name = LineEdit.new()
	_name.custom_minimum_size.x = 200
	_name.text_submitted.connect(func(_text): _name.release_focus())
	row.add_child(_name)
	_add_button(row, "Save", _save, "Save under this name (renames the saved level you're editing)")
	_add_button(row, "Save copy", _copy, "Save a copy under a new name")
	_add_button(row, "Export…", _export, "Save as a .json file anywhere (to share it)")
	_add_button(row, "New", _new_level, "Start an empty level")

	row = _add_row()
	_add_label(row, "Task")
	_task = LineEdit.new()
	_task.custom_minimum_size.x = 250
	_task.placeholder_text = "What should the player do?"
	_task.text_submitted.connect(func(_text): _task.release_focus())
	row.add_child(_task)
	_add_label(row, "opens on")
	_opens_on = OptionButton.new()
	_opens_on.focus_mode = Control.FOCUS_NONE
	_opens_on.tooltip_text = "Which tab the level opens on"
	row.add_child(_opens_on)

	row = _add_row()
	_add_label(row, "Big dummy mass")
	_big_pig_mass = SpinBox.new()
	_big_pig_mass.min_value = 0.5
	_big_pig_mass.max_value = 50.0
	_big_pig_mass.step = 0.5
	_big_pig_mass.suffix = "kg"
	_big_pig_mass.value = Pig.BIG_MASS
	_big_pig_mass.tooltip_text = "The mass of the big dumm(ies) in this level. A heavy one barely moves when hit;\na light one flies off."
	_big_pig_mass.value_changed.connect(_on_big_pig_mass_changed)
	var line_edit := _big_pig_mass.get_line_edit()
	line_edit.text_submitted.connect(func(_text): line_edit.release_focus())
	row.add_child(_big_pig_mass)
	_status = Label.new()
	_status.text = "Click to place · drag to move · right-click to delete"
	_status.modulate = Color(1, 1, 1, 0.6)
	row.add_child(_status)

	visibility_changed.connect(_on_visibility_changed)


func setup(owner_main: Node):
	main = owner_main
	for topic in main.topics:
		if not (topic is LevelsTopic or topic is EditorTopic):
			_opens_on.add_item(topic.title)


## Editing is on exactly while this tab is shown.
func _on_visibility_changed():
	if main == null:
		return
	var shown := is_visible_in_tree()
	if shown:
		_show_level_fields()
	if main.editor.active != shown:
		main.set_editing(shown)


func _show_level_fields():
	var level: Dictionary = main.level_data
	_name.text = level.get("name", "")
	_task.text = level.get("description", "")
	_opens_on.select(clampi(level.get("topic", 0), 0, _opens_on.item_count - 1))
	for pig in level["pigs"]:
		if pig.get("big", false):
			_big_pig_mass.set_value_no_signal(pig.get("mass", Pig.BIG_MASS))
			break
	_loaded_name = level["name"] if LevelStore.exists(level["name"]) else ""


## The level as it is now: its pieces, the fields above, and the current settings.
func _captured(level_name: String) -> Dictionary:
	main.level_data["name"] = level_name
	main.level_data["description"] = _task.text.strip_edges()
	var level := Level.capture(main.level_data, _opens_on.selected)
	main.update_banner()
	return level


func _save():
	var level_name := _name.text.strip_edges()
	if level_name == "":
		_status.text = "Give the level a name first."
		return
	var is_rename := _loaded_name != "" and LevelStore.path_for(_loaded_name) != LevelStore.path_for(level_name)
	var is_other_level := _loaded_name == "" or is_rename
	if is_other_level and LevelStore.exists(level_name):
		_status.text = "\"%s\" is already taken by another level: pick another name or use Copy." % level_name
		return
	if not LevelStore.save(_captured(level_name)):
		_status.text = "Couldn't save \"%s\"." % level_name
		return
	if is_rename:
		LevelStore.delete(_loaded_name)   # only now that the new file is safely written
	_loaded_name = level_name
	_status.text = "Saved \"%s\" (find it in Levels)." % level_name


func _copy():
	var level_name := LevelStore.unused_name(_name.text.strip_edges() + " (copy)")
	if not LevelStore.save(_captured(level_name)):
		_status.text = "Couldn't save \"%s\"." % level_name
		return
	_loaded_name = level_name
	_name.text = level_name
	_status.text = "Saved a copy: \"%s\"." % level_name


func _new_level():
	main.level_data = Level.blank("New level")
	main.editor.data = main.level_data
	main.reset_level()
	main.update_banner()
	_show_level_fields()
	_status.text = "Pick a piece and click in the world to place it."


func _clear():
	main.level_data["blocks"].clear()
	main.level_data["pigs"].clear()
	main.reset_level()


func _on_big_pig_mass_changed(value: float):
	var found := false
	for pig in main.level_data["pigs"]:
		if pig.get("big", false):
			pig["mass"] = value
			found = true
	if found:
		main.reset_level()
		_status.text = "Big dummy: %s kg." % String.num(value, 1)
	else:
		_status.text = "No big dummy in this level yet: place one first."


func _export():
	if OS.has_feature("web"):
		# A browser page can't write to the computer's folders: hand it over as a download.
		var file_name := LevelStore.path_for(_name.text).get_file()
		var json := LevelStore.to_json(_captured(_name.text.strip_edges()))
		JavaScriptBridge.download_buffer(json.to_utf8_buffer(), file_name, "application/json")
		_status.text = "Downloaded %s" % file_name
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; Level files"])
	dialog.current_file = LevelStore.path_for(_name.text).get_file()
	dialog.close_requested.connect(dialog.queue_free)
	dialog.file_selected.connect(_on_export_chosen.bind(dialog))
	add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


func _on_export_chosen(path: String, dialog: FileDialog):
	dialog.queue_free()
	if LevelStore.write(path, _captured(_name.text.strip_edges())):
		_status.text = "Exported to %s" % path
	else:
		_status.text = "Couldn't write %s (is the folder read-only?)" % path


func _add_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	return row


func _add_label(parent: Container, text: String):
	var label := Label.new()
	label.text = text
	parent.add_child(label)


func _add_button(parent: Container, text: String, on_pressed: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 30)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
