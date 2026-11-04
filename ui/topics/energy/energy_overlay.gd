class_name EnergyOverlay
extends Node2D
## A stacked bar next to the bird: KE (red) on top of PE (blue). The dashed line
## marks the energy it was launched with: in flight the bar keeps that height.

const PX_PER_JOULE := 0.8   # at 1× zoom
const MAX_BAR := 260.0
const BAR_WIDTH := 16.0


func _process(_delta: float):
	if visible:
		queue_redraw()


func _draw():
	var bird: Bird = PhysicsParams.bird
	if not is_instance_valid(bird) or Reveal.is_hidden("E"):
		return
	var k := DrawUtil.size_factor(self)   # see the zoom rule in draw_util.gd
	var energy := bird.total_energy()
	var launch := bird.launch_energy()
	# One scale for the whole flight, so the bar's height can be compared over time.
	var scale_px := minf(PX_PER_JOULE, MAX_BAR / maxf(maxf(launch, energy.x + energy.y), 1.0)) * k
	var base := bird.position + Vector2(-60, 40) * k
	var width := BAR_WIDTH * k
	var pe_height := maxf(energy.y, 0.0) * scale_px
	var ke_height := energy.x * scale_px
	draw_rect(Rect2(base - Vector2(0, pe_height), Vector2(width, pe_height)), EnergyGraph.PE_COLOR)
	draw_rect(Rect2(base - Vector2(0, pe_height + ke_height), Vector2(width, ke_height)), EnergyGraph.KE_COLOR)
	var launch_y := base.y - launch * scale_px
	draw_dashed_line(Vector2(base.x - 6 * k, launch_y), Vector2(base.x + width + 6 * k, launch_y), Color.WHITE, 2.0 * k, 4.0 * k)
	DrawUtil.label(self, Vector2(base.x, base.y - pe_height - ke_height), Vector2(-10, -8), "E = %s J" % Reveal.num(energy.x + energy.y, ["E"], 1), Color.WHITE, true)
