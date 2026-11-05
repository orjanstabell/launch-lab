class_name ForcesLabel
extends LiveLabel
## In flight the only force is gravity (no air resistance yet).
## Newton's 2nd law, a = F / m, then shows why mass doesn't matter for the path:
## a heavier bird gets pulled harder, but is exactly that much harder to speed up.


func _build_lines() -> Array:
	# The bird's own values while one is around, otherwise the next launch's.
	var bird: Bird = PhysicsParams.bird
	var m: float = PhysicsParams.values["m"]
	var g: float = PhysicsParams.values["g"]
	var heading := "NEXT LAUNCH"
	if is_instance_valid(bird):
		m = bird.mass_now()
		g = bird.segment.g
		heading = "BIRD IN FLIGHT" if bird.state == Bird.State.FLYING else "BIRD (crashed)"

	var force := m * g
	var mass_text := Reveal.num(m, ["m"])
	var g_text := Reveal.num(g, ["g"])
	var force_text := Reveal.num(force, ["F", "m", "g"])
	var accel_text := Reveal.num(g, ["a", "g"])
	var spring_waiting := PhysicsParams.launch_mode == "spring" and not PhysicsParams.is_flying()
	var spring_force: float = PhysicsParams.spring["k"] * PhysicsParams.spring["pull"]
	var spring_text := Reveal.num(spring_force, ["F", "k", "pull"])
	if not details:
		var compact := [
			"%s:  m = %s kg   g = %s m/s²" % [heading, mass_text, g_text],
			"F = m·g = %s N  (straight down: Fx = 0)" % force_text,
			"a = F/m = %s m/s² = g  (mass cancels out)" % accel_text,
		]
		# One short line each: this panel shares the dock with the momentum numbers.
		if spring_waiting:
			compact.append("Spring F = k·Δx = %s N, at release a = %s m/s²" % [spring_text, Reveal.num(spring_force / PhysicsParams.values["m"], ["a", "k", "pull", "m"])])
		if is_instance_valid(bird) and bird.burning():
			var thrust := bird.segment.exhaust_speed * bird.segment.burn_rate
			compact.append("Thrust F = v_e·ṁ = %s N, a = F/m = %s m/s²" % [Reveal.num(thrust, ["F"]), Reveal.live(thrust / bird.mass_now(), ["a"], 6)])
		return compact
	var lines := [
		heading,
		"m = %s kg   g = %s m/s²" % [mass_text, g_text],
		"",
		"Forces in flight: only gravity (no air yet)",
		"F  = m·g = %s · %s = %s N, straight down" % [mass_text, g_text, force_text],
		"Fx = 0 N",
		"Fy = −%s N" % force_text,
		"",
		"Newton's 2nd law:  a = F / m",
		"ax = 0 / %s = 0 m/s²   (so vx never changes)" % mass_text,
		"ay = −%s / %s = −%s m/s²   (= −g)" % [force_text, mass_text, accel_text],
		"",
		"Mass cancels:  a = m·g / m = g",
		"Double the mass → double the force,",
		"but the same acceleration and the same arc.",
	]
	if is_instance_valid(bird) and bird.state == Bird.State.PHYSICS:
		lines.append("")
		lines.append("After the hit, Godot adds contact forces too.")
	if is_instance_valid(bird) and bird.ability_kind() == "rocket":
		lines.append_array([
			"",
			"ROCKET: thrust F = v_e·ṁ (exhaust speed × kg burnt per second)",
			"The thrust stays the same, but the mass drops: a = F/m(t) grows",
			"as the fuel burns. Gravity m·g shrinks for the same reason.",
		])
	if PhysicsParams.launch_mode == "spring":
		lines.append_array([
			"",
			"SPRING (Hooke's law):  F = k·Δx, pulling the bird forward",
			"F = %s · %s = %s N  →  at release a = F/m = %s m/s²" % [Reveal.num(PhysicsParams.spring["k"], ["k"]), Reveal.num(PhysicsParams.spring["pull"], ["pull"]), spring_text, Reveal.num(spring_force / PhysicsParams.values["m"], ["a", "k", "pull", "m"])],
			"The force shrinks as the band relaxes, so the bird's speed builds up",
			"to v₀ = Δx·√(k/m) (see the Energy topic). Here mass DOES matter:",
			"the same spring launches a heavier bird slower.",
		])
	return lines

