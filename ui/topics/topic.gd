class_name Topic
extends RefCounted
## One way of looking at the flight: motion, forces, energy...
## Only one topic is shown at a time, so you can focus on one idea. A topic owns:
##   panel:    compact live numbers, in the dock under the ground (always shown)
##   details:  the formulas and explanations, floating over the sky; only shown
##             when "Formulas" is switched on, so the sky stays clear by default
##   overlays: drawn in the world, each with an on/off checkbox in the panel
##
## To add a topic: extend this class, call add_content() / add_details() /
## add_overlay() in _init(), and add it to the `topics` list in main.gd.

const PANEL_WIDTH := 670.0   # the same for every topic, so switching tabs doesn't change the size

var title := ""
var panel := PanelContainer.new()
var details := PanelContainer.new()
var overlays: Array[Node2D] = []

var _content := VBoxContainer.new()
var _options := HFlowContainer.new()   # one checkbox per overlay (wraps onto a second line if needed)
var _enabled := {}   # overlay -> is its checkbox ticked?
var _shown := false
var _show_details := false


func _init():
	panel.custom_minimum_size.x = PANEL_WIDTH
	_content.add_theme_constant_override("separation", 8)
	_options.add_theme_constant_override("h_separation", 20)
	panel.add_child(_content)
	_content.add_child(_options)


## Adds a control to the dock panel (above the overlay checkboxes).
func add_content(control: Control):
	_content.add_child(control)
	_content.move_child(control, _options.get_index())


## Sets what the floating details panel shows.
func add_details(control: Control):
	details.add_child(control)


## Adds a world overlay, plus a checkbox in the panel that turns it on and off.
func add_overlay(overlay: Node2D, checkbox_text: String, on := true, tooltip := ""):
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS   # keep drawing while paused
	overlays.append(overlay)
	_enabled[overlay] = on

	var check := CheckBox.new()
	check.text = checkbox_text
	check.tooltip_text = tooltip
	check.button_pressed = on
	check.focus_mode = Control.FOCUS_NONE   # so Space doesn't toggle it
	check.toggled.connect(_on_option_toggled.bind(overlay))
	_options.add_child(check)


func set_shown(shown: bool, show_details: bool):
	_shown = shown
	_show_details = show_details
	panel.visible = shown
	details.visible = shown and show_details and details.get_child_count() > 0
	_update_visibility()


func _on_option_toggled(on: bool, overlay: Node2D):
	_enabled[overlay] = on
	_update_visibility()


func _update_visibility():
	for overlay in overlays:
		overlay.visible = _shown and _enabled[overlay]
