class_name EnergyLabel
extends LiveLabel
## Kinetic energy KE = ½·m·v², potential energy PE = m·g·y, and the total.
## In flight only gravity does work, so the total stays the same: KE turns into
## PE on the way up and back into KE on the way down. Things that change it:
## the spring (before launch), the bird's ability, a blue bird split, a crash.


func _build_lines() -> Array:
	var bird: Bird = PhysicsParams.bird
	if not details:
		return _compact_lines(bird)
	var lines := [
		"ENERGY  (joules, J)",
		"KE = ½·m·v²   energy of motion",
		"PE = m·g·y    energy of height (y measured from the ground)",
		"E  = KE + PE",
		"",
		"In flight only gravity does work, so E stays the same:",
		"KE turns into PE on the way up, and back on the way down.",
		"(Mass is in every term, so it cancels: the path doesn't depend on m.)",
		"",
	]
	if PhysicsParams.launch_mode == "spring":
		var k: float = PhysicsParams.spring["k"]
		var pull: float = PhysicsParams.spring["pull"]
		lines.append_array([
			"SPRING LAUNCH",
			"The pulled band stores  ½·k·Δx² = ½·%s·%s² = %s J" % [_n(k, ["k"]), _n(pull, ["pull"]), _n(0.5 * k * pull * pull, ["k", "pull"])],
			"At release it all becomes KE:  ½·k·Δx² = ½·m·v₀²  →  v₀ = Δx·√(k/m)",
			"(Assumes no losses and an instant release.)",
			"",
		])
	lines.append_array([
		"WHAT CHANGES E",
		"  the bird's ability (Activate): a new speed or g adds or removes energy",
		"  a blue bird split: the pieces have MORE KE (the split works like an explosion)",
		"  a crash: energy goes into heat, sound, bending and moving the blocks",
	])
	var hit := PhysicsParams.collision
	if not hit.is_empty() and hit.has("after_bird") and hit["bird"] == bird:
		var before: float = hit["ke_before"]
		var after: float = hit["ke_after"]
		lines.append_array([
			"",
			"LAST HIT (bird + %s)" % hit["other_name"],
			"  KE just before %s J,  just after %s J:  %s J lost (%s%%)" % [_n(before, ["E"]), _n(after, ["E"]), _n(before - after, ["E"]), String.num((before - after) / before * 100.0, 0) if before > 0.0 else "0"],
		])
	return lines


func _compact_lines(bird: Bird) -> Array:
	if not is_instance_valid(bird):
		var p := PhysicsParams.launch_params()
		var ke := 0.5 * p.m * p.v0 * p.v0
		var pe := p.m * p.g * p.y0
		var first := "Next launch:  KE = ½·m·v₀² = %s J   PE = m·g·y₀ = %s J" % [_n(ke, ["E"]), _n(pe, ["E"])]
		if PhysicsParams.launch_mode == "spring":
			var spring_energy: float = 0.5 * PhysicsParams.spring["k"] * pow(PhysicsParams.spring["pull"], 2)
			return [first, "Spring: ½·k·Δx² = %s J → becomes the KE at launch" % _n(spring_energy, ["E", "k", "pull"])]
		return [first, "E = KE + PE = %s J" % _n(ke + pe, ["E"])]
	var energy := bird.total_energy()
	var total := energy.x + energy.y
	var change := total - bird.launch_energy()
	return [
		"KE = ½·m·v² = %s J    PE = m·g·y = %s J" % [Reveal.live(energy.x, ["E"], 8), Reveal.live(energy.y, ["E"], 8)],
		"E  = KE + PE = %s J   change since launch %s J" % [Reveal.live(total, ["E"], 8), Reveal.live(change, ["E"], 8)],
	]


func _n(x: float, depends_on: Array) -> String:
	return Reveal.num(x, depends_on)
