class_name SolvePanel
extends VBoxContainer
## Solve mode: "which launch hits the target?" Pick the unknown (v₀, θ or g);
## the other launch values stay as they are (locked), Kinematics.solve_*() works
## out the unknown and puts it in the Launch column. The formulas are in the
## Formulas panel. (To work it out yourself instead, use the Practice tab.)

const UNKNOWNS := ["v0", "theta", "g"]
const UNKNOWN_NAMES := ["speed v₀", "angle θ", "gravity g"]

var _unknown: OptionButton
var _target_x: SpinBox
var _target_y: SpinBox
var _high_arc: CheckBox
var _result: Label
var _refreshing := false


func _ready():
	add_theme_constant_override("separation", 4)

	var row := _add_row()
	_add_label(row, "Solve for")
	_unknown = OptionButton.new()
	for unknown_name in UNKNOWN_NAMES:
		_unknown.add_item(unknown_name)
	_unknown.focus_mode = Control.FOCUS_NONE
	_unknown.tooltip_text = "The value to work out. The other launch values stay as they are (locked)."
	_unknown.item_selected.connect(func(_index): _high_arc.visible = _key() == "theta")
	row.add_child(_unknown)
	_add_label(row, "  target x")
	_target_x = _make_spin(0.5, 100.0)
	row.add_child(_target_x)
	_add_label(row, "y")
	_target_y = _make_spin(0.0, 40.0)
	row.add_child(_target_y)

	var row2 := _add_row()
	var solve := Button.new()
	solve.text = "Solve"
	solve.focus_mode = Control.FOCUS_NONE
	solve.tooltip_text = "Work out the unknown and put it in the Launch column.\nRight-click in the world to move the target."
	solve.custom_minimum_size = Vector2(90, 32)
	solve.pressed.connect(_solve)
	row2.add_child(solve)
	_high_arc = CheckBox.new()
	_high_arc.text = "high arc"
	_high_arc.focus_mode = Control.FOCUS_NONE
	_high_arc.tooltip_text = "Two angles usually hit the same point: a low, fast arc and a high, slow one."
	_high_arc.visible = false
	row2.add_child(_high_arc)
	_result = Label.new()
	row2.add_child(_result)

	PhysicsParams.values_changed.connect(_refresh)
	_refresh()


func _key() -> String:
	return UNKNOWNS[_unknown.selected]


func _solve():
	var key := _key()
	var v := PhysicsParams.values
	var target := PhysicsParams.target
	var answer := NAN
	match key:
		"v0":
			answer = Kinematics.solve_speed(v["theta"], v["g"], v["y0"], target)
		"g":
			answer = Kinematics.solve_gravity(v["v0"], v["theta"], v["y0"], target)
		"theta":
			var angles := Kinematics.solve_angles(v["v0"], v["g"], v["y0"], target)
			if not angles.is_empty():
				answer = angles[1] if _high_arc.button_pressed else angles[0]

	var def: Dictionary = PhysicsParams.DEFINITIONS[key]
	if is_nan(answer):
		_result.text = "No %s can hit it with these values." % def["symbol"]
	elif answer < def["min"] or answer > def["max"]:
		_result.text = "Needs %s = %s %s (outside %s–%s)." % [def["symbol"], Reveal.num(answer, [key]), def["unit"], def["min"], def["max"]]
	else:
		PhysicsParams.set_value(key, answer)
		_result.text = "%s = %s %s ✓" % [def["symbol"], Reveal.num(answer, [key]), def["unit"]]


func _on_target_edited():
	if not _refreshing:
		PhysicsParams.set_target(Vector2(_target_x.value, _target_y.value))


func _refresh():
	_refreshing = true
	_target_x.value = PhysicsParams.target.x
	_target_y.value = PhysicsParams.target.y
	_refreshing = false


func _add_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	return row


func _add_label(parent: Container, text: String):
	var label := Label.new()
	label.text = text
	parent.add_child(label)


func _make_spin(min_value: float, max_value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 0.1
	spin.suffix = "m"
	spin.custom_minimum_size.x = 110
	spin.value_changed.connect(func(_value): _on_target_edited())
	var line_edit := spin.get_line_edit()
	line_edit.text_submitted.connect(func(_text): line_edit.release_focus())
	return spin
