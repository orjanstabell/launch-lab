class_name SimControls
extends PanelContainer
## Pause, step one physics frame, slow motion, zoom, the action cam, and the
## Formulas over the sky: 2×3 buttons for the dock, each showing its key, so the
## class can see what the lecturer pressed. Pause and the action cam light up while on.
## Zoom "fit" (the default) zooms out just enough to keep the whole predicted
## arc and the level on screen; 2× and 3× follow the bird.
## Pausing uses SceneTree.paused (stops the bird AND Godot physics);
## slow motion uses Engine.time_scale (every delta gets multiplied by it).

signal zoom_changed(zoom: float)
signal action_cam_changed(view: String)   # "" (off), "forces", "velocities" or "momentum"

const SPEEDS := [1.0, 0.5, 0.25, 0.1]
const ZOOMS := [1.0, 2.0, 3.0]

var _speed_index := 0
var _zoom_index := 0
var _stepping := false
var _pause_button: Button
var _step_button: Button
var _speed_button: Button
var _zoom_button: Button
var _action_button: Button
var details_button: Button   # Formulas: main connects it (and handles D)
const ACTION_VIEWS := ["", "forces", "velocities", "momentum"]
var _action_index := 0
var _shown_paused := false   # what the Pause button currently says


func _ready():
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	_pause_button = _add_button(grid, toggle_pause, "Pause / resume the simulation (P)")
	_pause_button.toggle_mode = true
	_step_button = _add_button(grid, step_frame, "While paused: run exactly one physics frame (F)")
	_speed_button = _add_button(grid, cycle_speed, "Slow motion: 1×, 0.5×, 0.25×, 0.1× (S)")
	_zoom_button = _add_button(grid, cycle_zoom, "Fit: keep the whole arc on screen.\n2×, 3×: follow the bird up close (Z)")
	_action_button = _add_button(grid, cycle_action_cam, "Action cam: when a bird gets close to a pig, zoom in, go into slow motion\nand show the collision on both: forces, velocities or momentum. Click to cycle (C)")
	_action_button.toggle_mode = true
	details_button = _add_button(grid, Callable(), "Show the formulas and explanations over the sky (D)")
	details_button.toggle_mode = true
	details_button.text = "Formulas (D)"
	_refresh()


func _process(_delta: float):
	if get_tree().paused != _shown_paused:   # e.g. a level reset unpaused it
		_refresh()


func _unhandled_input(event: InputEvent):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_P:
			toggle_pause()
		KEY_F:
			step_frame()
		KEY_S:
			cycle_speed()
		KEY_Z:
			cycle_zoom()
		KEY_C:
			cycle_action_cam()


func toggle_pause():
	if not _stepping:
		get_tree().paused = not get_tree().paused
	_refresh()   # (also puts back the lit look a click toggled while stepping)


## Runs exactly one physics frame, then pauses again.
func step_frame():
	if not get_tree().paused or _stepping:
		return
	_stepping = true
	get_tree().paused = false
	await get_tree().physics_frame   # the next physics frame starts and runs...
	await get_tree().physics_frame   # ...and the one after starts: freeze before it runs
	get_tree().paused = true
	_stepping = false


## The slow-motion speed chosen with S (1, 0.5, 0.25 or 0.1).
func speed() -> float:
	return SPEEDS[_speed_index]


func cycle_speed():
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	Engine.time_scale = SPEEDS[_speed_index]
	_refresh()


func cycle_zoom():
	_zoom_index = (_zoom_index + 1) % ZOOMS.size()
	zoom_changed.emit(ZOOMS[_zoom_index])
	_refresh()


func cycle_action_cam():
	_action_index = (_action_index + 1) % ACTION_VIEWS.size()
	action_cam_changed.emit(ACTION_VIEWS[_action_index])
	_refresh()


func _refresh():
	var paused := get_tree().paused
	_shown_paused = paused
	_pause_button.text = "Resume (P)" if paused else "Pause (P)"
	_pause_button.set_pressed_no_signal(paused)
	_step_button.text = "Step (F)"
	_step_button.disabled = not paused
	_speed_button.text = "Speed %s× (S)" % String.num(SPEEDS[_speed_index], 2)
	_zoom_button.text = "Zoom: fit (Z)" if _zoom_index == 0 else "Zoom %s× (Z)" % String.num(ZOOMS[_zoom_index])
	var view: String = ACTION_VIEWS[_action_index]
	_action_button.text = "Action cam: %s (C)" % (view if view != "" else "off")
	_action_button.set_pressed_no_signal(view != "")


func _add_button(parent: Container, on_pressed: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(150, 36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # the two columns share the panel's width
	button.focus_mode = Control.FOCUS_NONE   # so Space/Enter don't "click" the last pressed button
	if on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
