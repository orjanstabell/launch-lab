class_name EnergyGraph
extends Control
## KE, PE and E against time for the current bird, drawn in the dock.
## In flight the white E line should stay flat: energy is conserved.
## Steps in it show where something added or removed energy (ability, split, crash).
## It records even while another tab is shown, so switching to Energy mid-flight
## still shows the whole flight.

const KE_COLOR := Color(1.0, 0.45, 0.35)
const PE_COLOR := Color(0.4, 0.7, 1.0)
const E_COLOR := Color.WHITE
const AFTER_CRASH_TIME := 3.0   # keep recording this long after the bird crashes

var _samples: Array[Vector3] = []   # (time, KE, PE)
var _bird: Bird = null
var _time := 0.0


func _init():
	custom_minimum_size = Vector2(600, 110)


func _process(delta: float):
	var bird: Bird = PhysicsParams.bird
	if bird != _bird:   # a new launch: start a new graph
		_bird = bird
		_samples.clear()
		_time = 0.0
	if is_instance_valid(bird) and not get_tree().paused:
		_time += delta
		var crashed_for := 0.0 if bird.state == Bird.State.FLYING else _time - bird.flight_time
		if crashed_for < AFTER_CRASH_TIME:
			var energy := bird.total_energy()
			_samples.append(Vector3(_time, energy.x, energy.y))
	if is_visible_in_tree():
		queue_redraw()


func _draw():
	var area := Rect2(Vector2(46, 4), size - Vector2(56, 24))
	var font := ThemeDB.fallback_font
	draw_rect(area, Color(1, 1, 1, 0.05))
	if Reveal.is_hidden("E"):
		draw_string(font, area.position + Vector2(10, 30), "energy hidden", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.5))
		return
	if _samples.is_empty():
		var hint := "Launch a bird to see its energy over time." if not is_instance_valid(PhysicsParams.bird) else "Unpause to record the energy."
		draw_string(font, area.position + Vector2(10, 30), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.5))
		return

	var max_time := maxf(_samples[-1].x, 2.0)
	var max_energy := 1.0
	for sample in _samples:
		max_energy = maxf(max_energy, sample.y + sample.z)
	max_energy *= 1.1
	var ke_line := PackedVector2Array()
	var pe_line := PackedVector2Array()
	var e_line := PackedVector2Array()
	for sample in _samples:
		var x := area.position.x + sample.x / max_time * area.size.x
		ke_line.append(Vector2(x, _y(sample.y, max_energy, area)))
		pe_line.append(Vector2(x, _y(sample.z, max_energy, area)))
		e_line.append(Vector2(x, _y(sample.y + sample.z, max_energy, area)))
	if e_line.size() >= 2:
		draw_polyline(pe_line, PE_COLOR, 2.0, true)
		draw_polyline(ke_line, KE_COLOR, 2.0, true)
		draw_polyline(e_line, E_COLOR, 2.0, true)

	draw_string(font, Vector2(0, area.position.y + 12), "%s J" % String.num(max_energy, 0), HORIZONTAL_ALIGNMENT_LEFT, 44, 13, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(0, area.end.y), "0", HORIZONTAL_ALIGNMENT_LEFT, 44, 13, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(area.end.x - 40, size.y - 2), "%s s" % String.num(max_time, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))
	var legend_y := size.y - 2
	draw_string(font, Vector2(area.position.x, legend_y), "KE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, KE_COLOR)
	draw_string(font, Vector2(area.position.x + 40, legend_y), "PE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PE_COLOR)
	draw_string(font, Vector2(area.position.x + 80, legend_y), "E = KE + PE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, E_COLOR)


func _y(energy: float, max_energy: float, area: Rect2) -> float:
	return area.end.y - energy / max_energy * area.size.y
