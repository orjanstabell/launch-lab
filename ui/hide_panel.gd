class_name HidePanel
extends HBoxContainer
## "Hide values…" and, next to it, what's hidden right now. The button opens a
## grid above it with a toggle per symbol: lit = its value is hidden ("?")
## everywhere. Hiding is a setup step before a question, so the grid stays out
## of the way until it's opened; the summary keeps what's hidden on screen.
## "Randomize" gives every hidden launch value a random number, so you don't
## already know the answer you're trying to work out.

const COLUMNS := 9

var _buttons := {}   # symbol key -> Button
var _open_button: Button
var _summary: Label
var _grid_panel: PanelContainer   # floats above the row (top_level: the row doesn't lay it out)


func _ready():
	add_theme_constant_override("separation", 10)
	_open_button = _add_button(self, "Hide values…", Callable(), "Hide a number everywhere (shown as ?), then work it out yourself")
	_open_button.toggle_mode = true
	_open_button.toggled.connect(_set_open)
	_summary = Label.new()
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_summary.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	add_child(_summary)

	_grid_panel = PanelContainer.new()
	_grid_panel.top_level = true
	_grid_panel.visible = false
	add_child(_grid_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_grid_panel.add_child(box)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	box.add_child(actions)

	for key in Reveal.SYMBOLS:
		var button := Button.new()
		button.text = Reveal.SYMBOLS[key]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.toggled.connect(_on_toggled.bind(key))
		if key == "predict":
			button.tooltip_text = "Hide the dotted path, and where/when/how high it lands"
			button.custom_minimum_size = Vector2(0, 34)
			actions.add_child(button)
		else:
			button.tooltip_text = "Hide %s" % Reveal.SYMBOLS[key]
			button.custom_minimum_size = Vector2(38, 30)
			grid.add_child(button)
		_buttons[key] = button

	_add_button(actions, "Randomize", Reveal.randomize_hidden, "Give every hidden launch value a random number")
	_add_button(actions, "Show all", Reveal.show_all, "Unhide everything")

	Reveal.changed.connect(_refresh)
	_refresh()


## Opens the grid just above the row it's in, right edges lined up.
func _set_open(on: bool):
	_grid_panel.visible = on
	if on:
		_grid_panel.reset_size()
		var row := get_parent_control().get_global_rect()
		_grid_panel.global_position = Vector2(row.end.x - _grid_panel.size.x, row.position.y - _grid_panel.size.y - 8)


func _on_toggled(on: bool, key: String):
	Reveal.set_hidden(key, on)


func _refresh():
	var hidden_names := []
	for key in _buttons:
		_buttons[key].set_pressed_no_signal(Reveal.is_hidden(key))
		if Reveal.is_hidden(key):
			hidden_names.append("predictions" if key == "predict" else Reveal.SYMBOLS[key])
	_summary.text = "Hidden: " + ", ".join(hidden_names) if not hidden_names.is_empty() else "Nothing hidden"


func _add_button(parent: Container, text: String, on_pressed: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 34)
	button.focus_mode = Control.FOCUS_NONE
	if on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
