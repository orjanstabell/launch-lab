class_name ElasticityRow
extends HBoxContainer
## Sets how bouncy collisions are (PhysicsParams.elasticity, the coefficient of
## restitution e). It changes the world in every tab, so it sits with the
## simulation controls; the last hit's measured e is in the Forces & momentum formulas.


var _spin: SpinBox
var _refreshing := false


func _ready():
	add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "Elasticity e"
	label.tooltip_text = "Coefficient of restitution: how fast things separate after a hit,\ncompared with how fast they came together.\n0 = they stick together (most kinetic energy lost)\n1 = perfectly elastic (no kinetic energy lost)"
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(label)
	_spin = SpinBox.new()
	_spin.min_value = 0.0
	_spin.max_value = 1.0
	_spin.step = 0.05
	_spin.custom_minimum_size.x = 90
	_spin.value_changed.connect(_on_changed)
	add_child(_spin)
	var hint := Label.new()
	hint.text = "0 sticky · 1 bouncy"
	hint.tooltip_text = "Takes effect from the next launch"
	hint.mouse_filter = Control.MOUSE_FILTER_STOP
	hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	add_child(hint)
	PhysicsParams.values_changed.connect(_refresh)
	_refresh()


func _on_changed(value: float):
	if not _refreshing:
		PhysicsParams.set_elasticity(value)


func _refresh():
	_refreshing = true
	_spin.value = PhysicsParams.elasticity
	_refreshing = false
