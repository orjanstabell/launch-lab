class_name HidePanel
extends PanelContainer
## A toggle per symbol: pressed = its value is hidden ("?") everywhere.
## "Randomize hidden" gives every hidden launch value a random number, so you
## don't already know the answer you're trying to work out.
## A compact grid for the dock; explanations are in the tooltips.

const HIDDEN_COLOR := Color(1.0, 0.85, 0.2)
const COLUMNS := 9

var _buttons := {}   # symbol key -> Button


func _ready():
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var title := Label.new()
	title.text = "Hide values"
	title.tooltip_text = "Hide a number everywhere (shown as ?), then work it out yourself."
	title.mouse_filter = Control.MOUSE_FILTER_STOP   # so the tooltip shows
	box.add_child(title)

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
		button.add_theme_color_override("font_pressed_color", HIDDEN_COLOR)
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


func _on_toggled(on: bool, key: String):
	Reveal.set_hidden(key, on)


func _refresh():
	for key in _buttons:
		_buttons[key].set_pressed_no_signal(Reveal.is_hidden(key))


func _add_button(parent: Container, text: String, on_pressed: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 34)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
