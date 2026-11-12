class_name ParamPanel
extends PanelContainer
## The launch values, and the bird:
##   Launch:      what every new bird starts with (slider + number box)
##   On activate: only for birds that "change" (yellow, custom). Tick what the
##                ability should change and set the new value; use it mid-air
##                with Space or the big button. Picking the yellow bird fills it in.
## Under that: the bird picker, and the picked bird's own settings (split,
## rocket, egg) or what it does. Launching is the big button in the next column.
## Kept compact for the dock: explanations live in tooltips.
## "Spring launch" swaps the speed row for the spring's k and pull Δx; v₀ is
## then worked out from them (shown in the Launch header).

const ABILITY_COLOR := Color(1.0, 0.85, 0.2)   # the same yellow as the ability's dotted path
const OFF_COLOR := Color(1, 1, 1, 0.4)
const PANEL_WIDTH := 700.0   # fixed, so the On activate column comes and goes without moving the dock

var _grid: GridContainer
var _ability_cells: Array[Control] = []   # the On activate column: shown only for "change" birds
var _rows := {}   # key -> {"slider", "spin", "check", "ability_spin"} (the ability ones are missing for y₀)
var _bird_buttons := {}   # bird type -> Button
var _bird_about: Label
var _split_row: HBoxContainer
var _split_pieces: SpinBox
var _split_spread: SpinBox
var _split_conserve: CheckBox
var _rocket_row: HBoxContainer
var _rocket_spins := {}   # "fuel" / "exhaust" / "burn_rate" -> SpinBox
var _rocket_result: Label
var _egg_row: HBoxContainer
var _egg_spins := {}   # "mass" / "speed" -> SpinBox
var _egg_result: Label
var _egg_straight: CheckBox
var _refreshing := false   # true while we update the widgets ourselves
var _spring_toggle: Button
var _launch_header: Label
var _speed_name: Label   # the v₀ row's name ("Speed v₀" or "Spring k, Δx")
var _speed_widgets: Array[Control] = []   # slider + spin box, shown in speed mode
var _spring_spins := {}   # "k" / "pull" -> SpinBox, shown in spring mode


func _ready():
	custom_minimum_size.x = PANEL_WIDTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(_grid)
	# Header row: Launch | v₀ from the spring (spring mode) | Spring launch | On activate | -
	_grid.add_child(UiTheme.heading("Launch"))
	_launch_header = Label.new()
	_launch_header.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_grid.add_child(_launch_header)
	_spring_toggle = Button.new()
	_spring_toggle.text = "Spring launch"
	_spring_toggle.toggle_mode = true
	_spring_toggle.focus_mode = Control.FOCUS_NONE
	_spring_toggle.tooltip_text = "Launch with the slingshot's spring: set k and the pull Δx,\nand v₀ = Δx·√(k/m) follows from ½·k·Δx² = ½·m·v₀².\nA heavier ball then launches slower!"
	_spring_toggle.toggled.connect(_on_spring_toggled)
	_grid.add_child(_spring_toggle)
	var ability_title := UiTheme.heading("On activate")
	ability_title.tooltip_text = "What the Booster's or Custom's ability changes when you use it mid-air (Space)"
	ability_title.mouse_filter = Control.MOUSE_FILTER_PASS   # (so the tooltip shows)
	_add_ability_cell(ability_title)
	_add_ability_cell(Control.new())
	for key in PhysicsParams.DEFINITIONS:
		_add_row(_grid, key)

	_add_bird_picker(box)
	_add_split_row(box)
	_add_rocket_row(box)
	_add_egg_row(box)

	PhysicsParams.values_changed.connect(_refresh)
	Reveal.changed.connect(_refresh)
	_refresh()


func _add_bird_picker(box: VBoxContainer):
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)   # six names in a row: kept tight, or the dock outgrows the screen
	box.add_child(row)
	var title := UiTheme.heading("Ball")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)

	var group := ButtonGroup.new()
	for type in BirdTypes.TYPES:
		var info: Dictionary = BirdTypes.TYPES[type]
		if info.get("hidden", false):
			continue
		var button := Button.new()
		button.text = info["name"]
		button.icon = _bird_picture(type)   # the bird itself; the name stays readable text
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 34)
		button.add_theme_constant_override("h_separation", 2)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = info["about"]
		button.pressed.connect(PhysicsParams.set_bird_type.bind(type))
		row.add_child(button)
		_bird_buttons[type] = button

	# One line under the picker: what the bird does, or the blue bird's split settings.
	_bird_about = Label.new()
	_bird_about.add_theme_font_size_override("font_size", 16)
	box.add_child(_bird_about)


func _add_split_row(box: VBoxContainer):
	_split_row = HBoxContainer.new()
	_split_row.add_theme_constant_override("separation", 10)
	box.add_child(_split_row)

	var pieces_label := Label.new()
	pieces_label.text = "Pieces"
	_split_row.add_child(pieces_label)
	_split_pieces = SpinBox.new()
	_split_pieces.min_value = 2
	_split_pieces.max_value = 5
	_split_pieces.value_changed.connect(_on_split_changed.bind("pieces"))
	_split_pieces.tooltip_text = "How many equal pieces the Splitter splits into"
	_split_row.add_child(_split_pieces)

	var spread_label := Label.new()
	spread_label.text = "  Spread ±"
	_split_row.add_child(spread_label)
	_split_spread = SpinBox.new()
	_split_spread.max_value = 45
	_split_spread.step = 0.5
	_split_spread.suffix = "°"
	_split_spread.value_changed.connect(_on_split_changed.bind("spread"))
	_split_spread.tooltip_text = "How far the outer pieces fan out from the heading (the others are spread evenly between)"
	_split_row.add_child(_split_spread)

	_split_conserve = CheckBox.new()
	_split_conserve.text = "Conserve momentum"
	_split_conserve.focus_mode = Control.FOCUS_NONE
	_split_conserve.tooltip_text = "On: the pieces speed up so total momentum stays the same (real physics).\nOff: they keep the ball's speed, and momentum is lost."
	_split_conserve.toggled.connect(_on_split_changed.bind("conserve"))
	_split_row.add_child(_split_conserve)


## The rocket bird's engine: fuel, exhaust speed, burn rate, and the Δv they give.
func _add_rocket_row(box: VBoxContainer):
	_rocket_row = HBoxContainer.new()
	_rocket_row.add_theme_constant_override("separation", 6)
	box.add_child(_rocket_row)
	for key in PhysicsParams.ROCKET_DEFINITIONS:
		var def: Dictionary = PhysicsParams.ROCKET_DEFINITIONS[key]
		var label := Label.new()
		label.text = def["symbol"]
		label.tooltip_text = def["label"]
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		_rocket_row.add_child(label)
		var spin := _make_spin_box(def, def["min"], def["max"])
		spin.custom_minimum_size.x = 105
		spin.tooltip_text = def["label"]
		spin.value_changed.connect(_on_rocket_changed.bind(key))
		_rocket_row.add_child(spin)
		_rocket_spins[key] = spin
	_rocket_result = Label.new()
	_rocket_result.tooltip_text = "The rocket equation: Δv = v_e·ln(m₀/m₁), with m₀ = ball + fuel and m₁ = m₀ − fuel.\nThrust F = v_e·ṁ, burn time = fuel / ṁ."
	_rocket_result.mouse_filter = Control.MOUSE_FILTER_STOP
	_rocket_row.add_child(_rocket_result)


## the Dropper's egg: its mass, how fast she throws it, and the kick she gets.
func _add_egg_row(box: VBoxContainer):
	_egg_row = HBoxContainer.new()
	_egg_row.add_theme_constant_override("separation", 6)
	box.add_child(_egg_row)
	for key in PhysicsParams.EGG_DEFINITIONS:
		var def: Dictionary = PhysicsParams.EGG_DEFINITIONS[key]
		var label := Label.new()
		label.text = def["symbol"]
		label.tooltip_text = def["label"]
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		_egg_row.add_child(label)
		var spin := _make_spin_box(def, def["min"], def["max"])
		spin.custom_minimum_size.x = 105
		spin.tooltip_text = def["label"]
		spin.value_changed.connect(_on_egg_changed.bind(key))
		_egg_row.add_child(spin)
		_egg_spins[key] = spin
	_egg_straight = CheckBox.new()
	_egg_straight.text = "straight down"
	_egg_straight.focus_mode = Control.FOCUS_NONE
	_egg_straight.tooltip_text = "Off: it fires straight down, so the cannonball keeps the forward speed and lands ahead.\nOn: it also fires it backwards, so the cannonball falls straight down on screen.\nMomentum then pushes the cannon forwards: vₓ' = vₓ·m/m_body."
	_egg_straight.toggled.connect(_on_egg_straight_toggled)
	_egg_row.add_child(_egg_straight)
	_egg_result = Label.new()
	_egg_result.tooltip_text = "Momentum is conserved: m_b·Δv_ball + m_body·Δv_cannon = 0,\nand the cannonball leaves at u relative to the cannon. So the cannon is kicked up by (m_b/m)·u\nand the cannonball gets (m_body/m)·u extra downwards."
	_egg_result.mouse_filter = Control.MOUSE_FILTER_STOP
	_egg_row.add_child(_egg_result)


func _add_ability_cell(cell: Control):
	_grid.add_child(cell)
	_ability_cells.append(cell)


## The bird's picture for its button: BirdArt drawn once into a small transparent viewport.
func _bird_picture(type: String) -> ViewportTexture:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(28, 28)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := Node2D.new()
	canvas.draw.connect(func(): BirdArt.draw_bird(canvas, Vector2(13, 15), 9.0, type))
	viewport.add_child(canvas)
	add_child(viewport)
	return viewport.get_texture()


const ROW_TIPS := {
	"g": "Gravity g: the downward acceleration (Earth 9.81, Moon 1.62, Mars 3.71 m/s²)",
	"v0": "Launch speed v₀",
	"theta": "Launch angle θ above the horizontal (negative aims down, from a raised launch point)",
	"y0": "Launch height y₀ above the ground",
	"m": "Mass m: it cancels out of the flight (same arc), but matters for momentum, energy,\nforces, collisions and spring launches",
}


func _add_row(grid: GridContainer, key: String):
	var def: Dictionary = PhysicsParams.DEFINITIONS[key]
	var row := {}

	var name_label := Label.new()
	name_label.text = "%s  %s" % [def["label"], def["symbol"]]
	name_label.tooltip_text = ROW_TIPS[key]
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS   # (labels ignore the mouse by default: no tooltip)
	grid.add_child(name_label)

	# Launch value: slider + number box. (The speed row keeps its slider and box
	# in little slots, so spring mode can swap in the k and Δx boxes.)
	var slider_slot := HBoxContainer.new()
	var spin_slot := HBoxContainer.new()
	var slider := HSlider.new()
	slider.min_value = def["min"]
	slider.max_value = def["max"]
	slider.step = def["step"]
	slider.custom_minimum_size.x = 150
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_launch_changed.bind(key))
	slider.tooltip_text = ROW_TIPS[key]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_slot.add_child(slider)
	grid.add_child(slider_slot)
	row["slider"] = slider

	var spin := _make_spin_box(def, def["min"], def["max"])
	spin.value_changed.connect(_on_launch_changed.bind(key))
	spin.tooltip_text = ROW_TIPS[key]
	spin_slot.add_child(spin)
	grid.add_child(spin_slot)
	row["spin"] = spin

	if key == "v0":
		_speed_name = name_label
		_speed_widgets = [slider, spin]
		for spring_key in PhysicsParams.SPRING_DEFINITIONS:
			var spring_def: Dictionary = PhysicsParams.SPRING_DEFINITIONS[spring_key]
			var spring_spin := _make_spin_box(spring_def, spring_def["min"], spring_def["max"])
			spring_spin.tooltip_text = spring_def["label"]
			spring_spin.value_changed.connect(_on_spring_changed.bind(spring_key))
			(slider_slot if spring_key == "k" else spin_slot).add_child(spring_spin)
			_spring_spins[spring_key] = spring_spin

	# Ability value: on/off tick + number box.
	if key in PhysicsParams.ABILITY_DEFINITIONS:
		var ability_def: Dictionary = PhysicsParams.ABILITY_DEFINITIONS[key]
		var check := CheckBox.new()
		check.focus_mode = Control.FOCUS_NONE   # so Space doesn't toggle it
		check.toggled.connect(_on_ability_toggled.bind(key))
		check.tooltip_text = "Tick: the ability changes %s to the value on the right" % def["symbol"]
		_add_ability_cell(check)
		row["check"] = check

		var ability_spin := _make_spin_box(def, ability_def["min"], ability_def["max"])
		ability_spin.value_changed.connect(_on_ability_changed.bind(key))
		ability_spin.tooltip_text = "The new %s after the ability (when ticked)" % def["symbol"]
		_add_ability_cell(ability_spin)
		row["ability_spin"] = ability_spin
	else:
		_add_ability_cell(Control.new())
		var note := Label.new()
		note.text = "launch only"
		note.modulate = OFF_COLOR
		_add_ability_cell(note)

	_rows[key] = row


func _make_spin_box(def: Dictionary, min_value: float, max_value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = def["step"]
	spin.suffix = def["unit"]
	spin.custom_minimum_size.x = 120
	# After typing a number + Enter, drop focus so Space and Enter work as shortcuts again.
	var line_edit := spin.get_line_edit()
	line_edit.text_submitted.connect(func(_text): line_edit.release_focus())
	return spin


func _set_spin(spin: SpinBox, value: float, secret: bool, editable: bool):
	spin.value = value
	spin.get_line_edit().secret = secret
	spin.editable = editable


func _on_launch_changed(value: float, key: String):
	if not _refreshing:
		PhysicsParams.set_value(key, value)


func _on_spring_toggled(on: bool):
	if not _refreshing:
		PhysicsParams.set_launch_mode("spring" if on else "speed")


func _on_spring_changed(value: float, key: String):
	if not _refreshing:
		PhysicsParams.set_spring_value(key, value)


func _on_egg_straight_toggled(on: bool):
	if not _refreshing:
		PhysicsParams.set_egg_straight_down(on)


func _on_egg_changed(value: float, key: String):
	if not _refreshing:
		PhysicsParams.set_egg_value(key, value)


func _on_rocket_changed(value: float, key: String):
	if not _refreshing:
		PhysicsParams.set_rocket_value(key, value)


func _on_split_changed(value: Variant, key: String):
	if _refreshing:
		return
	if key == "pieces":
		value = int(value)
	PhysicsParams.set_split(key, value)


func _on_ability_toggled(on: bool, key: String):
	if not _refreshing:
		PhysicsParams.set_ability_on(key, on)


func _on_ability_changed(value: float, key: String):
	if not _refreshing:
		PhysicsParams.set_ability_value(key, value)


## Make every widget show the stored values.
## A hidden value (see Reveal) shows as dots, its slider knob disappears, and it
## can't be edited until you unhide it. While a practice problem is open
## (PhysicsParams.inputs_locked), nothing can be edited.
func _refresh():
	_refreshing = true
	var locked := PhysicsParams.inputs_locked
	# Only "change" birds (yellow, custom) use the On activate column: the others don't see it.
	var uses_column: bool = BirdTypes.TYPES[PhysicsParams.bird_type]["ability"] == "change"
	for cell in _ability_cells:
		cell.visible = uses_column
	_grid.columns = 5 if uses_column else 3   # (a grid skips hidden cells, so it needs fewer columns)
	for key in _rows:
		var row: Dictionary = _rows[key]
		var secret := Reveal.is_hidden(key)
		row["slider"].value = PhysicsParams.values[key]
		row["slider"].editable = not secret and not locked
		row["slider"].modulate.a = 0.0 if secret else 1.0
		_set_spin(row["spin"], PhysicsParams.values[key], secret, not secret and not locked)
		if row.has("check"):
			var on: bool = PhysicsParams.ability_on[key]
			row["check"].button_pressed = on
			row["check"].disabled = not uses_column or locked
			_set_spin(row["ability_spin"], PhysicsParams.ability[key], secret, uses_column and on and not secret and not locked)
			row["ability_spin"].modulate = ABILITY_COLOR if uses_column and on else OFF_COLOR

	var bird_info: Dictionary = BirdTypes.TYPES[PhysicsParams.bird_type]
	for type in _bird_buttons:
		_bird_buttons[type].set_pressed_no_signal(type == PhysicsParams.bird_type)
		_bird_buttons[type].disabled = locked
	_bird_about.text = bird_info["about"]
	_split_row.visible = bird_info["ability"] == "split"
	_rocket_row.visible = bird_info["ability"] == "rocket"
	_egg_row.visible = bird_info["ability"] == "egg"
	_bird_about.visible = not _split_row.visible and not _rocket_row.visible and not _egg_row.visible
	for key in _egg_spins:
		_set_spin(_egg_spins[key], PhysicsParams.egg[key], false, not locked)
	var egg_fraction: float = PhysicsParams.usable_egg_mass(PhysicsParams.values["m"]) / PhysicsParams.values["m"]
	_egg_straight.set_pressed_no_signal(PhysicsParams.egg["straight_down"])
	_egg_straight.disabled = locked
	var kick := "→ up +%s m/s" % Reveal.num(egg_fraction * PhysicsParams.egg["speed"], ["v"])
	if PhysicsParams.egg["straight_down"]:
		kick += ", forward ×%s" % String.num(1.0 / (1.0 - egg_fraction), 2)
	_egg_result.text = kick
	for key in _rocket_spins:
		var secret: bool = key == "fuel" and Reveal.is_hidden("fuel")
		_set_spin(_rocket_spins[key], PhysicsParams.rocket[key], secret, not locked and not secret)
	var m0: float = PhysicsParams.values["m"]
	var fuel := PhysicsParams.usable_fuel(m0)
	_rocket_result.text = "→ Δv = %s m/s" % Reveal.num(PhysicsParams.rocket["exhaust"] * log(m0 / (m0 - fuel)), ["v", "fuel"])
	_split_pieces.value = PhysicsParams.split["pieces"]
	_split_spread.value = PhysicsParams.split["spread"]
	_split_conserve.button_pressed = PhysicsParams.split["conserve"]
	_split_pieces.editable = not locked
	_split_spread.editable = not locked
	_split_conserve.disabled = locked

	# Spring mode: k and Δx instead of v₀; v₀ shown in the header.
	var spring_mode := PhysicsParams.launch_mode == "spring"
	_spring_toggle.set_pressed_no_signal(spring_mode)
	_spring_toggle.disabled = locked
	for widget in _speed_widgets:
		widget.visible = not spring_mode
	for spring_key in _spring_spins:
		var spring_spin: SpinBox = _spring_spins[spring_key]
		spring_spin.visible = spring_mode
		_set_spin(spring_spin, PhysicsParams.spring[spring_key], Reveal.is_hidden(spring_key), not locked and not Reveal.is_hidden(spring_key))
	_speed_name.text = "Spring k, Δx" if spring_mode else "Speed  v₀"
	_launch_header.text = "v₀ = %s m/s" % Reveal.num(PhysicsParams.values["v0"], ["v0", "k", "pull", "m"]) if spring_mode else ""
	_refreshing = false
