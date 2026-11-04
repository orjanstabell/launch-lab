class_name MomentumLabel
extends LiveLabel
## Momentum p = m·v (a vector). Gravity changes it steadily: Δp = F·Δt.
## For the blue bird: momentum and kinetic energy just before and just after the
## split, and whether momentum was conserved.


func _build_lines() -> Array:
	var bird: Bird = PhysicsParams.bird
	if not details:
		return _compact_lines(bird)
	var lines := [
		"MOMENTUM   p = m·v   (a vector, in kg·m/s)",
		"Gravity changes it:  Δp = F·Δt",
		"  px never changes, py drops by m·g every second.",
		"",
	]
	if not is_instance_valid(bird):
		var p := PhysicsParams.launch_params()
		lines.append("Next launch:  p = m·v₀ = %s · %s = %s" % [_n(p.m, ["m"]), _n(p.v0, ["v0"]), _n(p.m * p.v0, ["p", "m", "v0"])])
	elif bird.pieces.is_empty():
		var v: Vector2 = bird.velocity_m()
		var p: Vector2 = bird.mass_now() * v
		lines.append("Bird:  m = %s kg   |v| = %s m/s" % [_n(bird.mass_now(), ["m"]), Reveal.live(v.length(), ["v"])])
		lines.append("  px = %s   py = %s   |p| = %s" % [Reveal.live(p.x, ["p", "m", "vx"]), Reveal.live(p.y, ["p", "m", "vy"]), Reveal.live(p.length(), ["p", "m", "v"])])
		if bird.ability_kind() == "split":
			lines.append("")
			lines.append("Press Space to split. Watch the center of mass:")
			lines.append("with momentum conserved, it stays on the old arc.")
		elif bird.ability_kind() == "egg":
			lines.append("")
			lines.append("Press Space to throw the egg down. Momentum is conserved,")
			lines.append("so the throw kicks Matilda up: recoil, like a gun.")
	else:
		lines.append_array(_split_lines(bird))
	if is_instance_valid(bird) and bird.ability_kind() == "rocket":
		lines.append_array(_rocket_lines(bird))
	var hit := _last_hit(bird)
	if not hit.is_empty():
		lines.append_array(_hit_lines(hit))
	return lines


func _rocket_lines(bird: Bird) -> Array:
	var settings := PhysicsParams.rocket
	var lines := [
		"",
		"ROCKET EQUATION",
		"The bird pushes exhaust backwards; the exhaust pushes the bird forwards.",
		"Momentum of bird + exhaust is conserved: in a short time the bird",
		"(mass m) speeds up by dv while throwing out dm at speed v_e:",
		"  m·dv = v_e·dm   →   Δv = v_e·ln(m₀ / m₁)",
		"Exhaust %s m/s, fuel %s kg: from %s kg down to %s kg" % [String.num(settings["exhaust"], 1), String.num(PhysicsParams.usable_fuel(PhysicsParams.values["m"]), 2), String.num(PhysicsParams.values["m"], 2), String.num(PhysicsParams.values["m"] - PhysicsParams.usable_fuel(PhysicsParams.values["m"]), 2)],
	]
	if bird.segment.is_rocket():
		var gained := Kinematics.rocket_speed(bird.segment, bird.t)
		var full := Kinematics.rocket_speed(bird.segment, bird.segment.burn_time)
		lines.append("Gained so far: %s of %s m/s" % [Reveal.live(gained, ["v"], 6), Reveal.num(full, ["v"])])
		if bird.exhaust != null and is_instance_valid(bird.exhaust) and bird.state == Bird.State.FLYING:
			# Bird + all its exhaust vs. the bird alone without a rocket (same start, same gravity).
			var total: Vector2 = bird.mass_now() * bird.velocity_m()
			for puff in bird.exhaust.puffs:
				total += puff["mass"] * bird.exhaust.puff_velocity(puff)
			var plain := _without_rocket(bird.segment)
			var expected: Vector2 = bird.segment.m * Kinematics.velocity(plain, bird.t)
			var p_from := ["p", "m", "v"]
			lines.append("Bird + exhaust: Σp (%s, %s)" % [Reveal.live(total.x, p_from), Reveal.live(total.y, p_from)])
			lines.append("No rocket at all: p  (%s, %s)  ≈ the same!" % [Reveal.live(expected.x, p_from), Reveal.live(expected.y, p_from)])
	return lines


## The same segment without the rocket: what the bird would do if it never fired.
func _without_rocket(segment: LaunchParams) -> LaunchParams:
	var plain := LaunchParams.new()
	plain.x0 = segment.x0
	plain.y0 = segment.y0
	plain.v0 = segment.v0
	plain.theta_deg = segment.theta_deg
	plain.g = segment.g
	plain.m = segment.m
	return plain


## The collision snapshot for this bird, once "just after" is recorded ({} if none).
func _last_hit(bird: Bird) -> Dictionary:
	var hit := PhysicsParams.collision
	if hit.is_empty() or hit.get("bird") != bird or not hit.has("bird_after"):
		return {}
	return hit


func _hit_lines(hit: Dictionary) -> Array:
	var p_from := ["p", "m", "v"]
	var rows := []
	for when in ["before", "after"]:
		var bird_p: Vector2 = hit["bird_m"] * hit["bird_" + when]
		var other_p: Vector2 = hit["other_m"] * hit["other_" + when]
		rows.append("  %-6s bird (%s, %s)  %s (%s, %s)  Σp (%s, %s)" % [when, _n(bird_p.x, p_from), _n(bird_p.y, p_from), hit["other_name"], _n(other_p.x, p_from), _n(other_p.y, p_from), _n(bird_p.x + other_p.x, p_from), _n(bird_p.y + other_p.y, p_from)])
	var explanation := [
		"Σp stayed (nearly) the same: the push between them is equal and",
		"opposite (Newton's 3rd law), so it only moves momentum between them.",
	] if _hit_conserved(hit) else [
		"Σp changed: something ELSE pushed during the hit (an outside force),",
		"e.g. the plank or the ground under the %s. Without that, Σp would stay." % hit["other_name"],
	]
	return [
		"",
		"LAST HIT: bird (%s kg) + %s (%s kg), p in kg·m/s" % [_n(hit["bird_m"], ["m"]), hit["other_name"], String.num(hit["other_m"], 2)],
	] + rows + explanation + [
		"KE %s J → %s J  (%s%% kept)" % [_n(hit["ke_before"], ["E"]), _n(hit["ke_after"], ["E"]), String.num(hit["ke_after"] / maxf(hit["ke_before"], 0.001) * 100.0, 0)],
		"Measured elasticity e = %s (set: %s). e = 1 keeps all the KE; e = 0 makes them stick." % [String.num(hit.get("measured_e", NAN), 2) if hit.has("measured_e") else "?", String.num(PhysicsParams.elasticity, 2)],
	]


## Did the total momentum survive the hit (within 10%)?
static func _hit_conserved(hit: Dictionary) -> bool:
	var before: Vector2 = hit["bird_m"] * hit["bird_before"] + hit["other_m"] * hit["other_before"]
	var after: Vector2 = hit["bird_m"] * hit["bird_after"] + hit["other_m"] * hit["other_after"]
	return before.distance_to(after) <= 0.1 * maxf(before.length(), 0.01)


## Dock version: just the live numbers.
func _compact_lines(bird: Bird) -> Array:
	var p_from := ["p", "m", "v"]
	if not is_instance_valid(bird):
		var p := PhysicsParams.launch_params()
		return ["p = m·v   (kg·m/s)", "Next launch:  p = %s" % _n(p.m * p.v0, ["p", "m", "v0"])]
	if bird.pieces.is_empty():
		var p: Vector2 = bird.mass_now() * bird.velocity_m()
		var lines := [
			"p = m·v   (kg·m/s)",
			"px = %s   py = %s   |p| = %s" % [Reveal.live(p.x, ["p", "m", "vx"]), Reveal.live(p.y, ["p", "m", "vy"]), Reveal.live(p.length(), p_from)],
		]
		var hit := _last_hit(bird)
		if not hit.is_empty():
			var before: Vector2 = hit["bird_m"] * hit["bird_before"] + hit["other_m"] * hit["other_before"]
			var after: Vector2 = hit["bird_m"] * hit["bird_after"] + hit["other_m"] * hit["other_after"]
			lines.append("Hit the %s: Σp (%s, %s) → (%s, %s) %s" % [hit["other_name"], _n(before.x, p_from), _n(before.y, p_from), _n(after.x, p_from), _n(after.y, p_from), "conserved ✓" if _hit_conserved(hit) else "(outside push)"])
		return lines
	var info := bird.split_info
	var p_before: Vector2 = info["p_before"]
	var p_after: Vector2 = info["p_after"]
	var lost := 1.0 - p_after.length() / p_before.length()
	var status := "momentum conserved ✓" if absf(lost) < 0.001 else "%s%% momentum lost ✗" % String.num(lost * 100.0, 1)
	var what := "Egg thrown" if info.get("kind") == "egg" else "Split into %d" % info["pieces"]
	var lines := ["%s: %s,  KE %s → %s J" % [what, status, _n(info["ke_before"], ["m", "v"]), _n(info["ke_after"], ["m", "v"])]]
	var total_p := Vector2.ZERO
	for piece in bird.pieces:
		if not is_instance_valid(piece) or piece.state != Bird.State.FLYING:
			lines.append("A piece hit something: outside force.")
			return lines
		total_p += piece.mass_now() * piece.velocity_m()
	var t_unsplit := bird.split_t + bird.flight_time - bird.split_flight_time
	var p_unsplit := bird.pre_split.m * Kinematics.velocity(bird.pre_split, t_unsplit)
	lines.append("Σp pieces    (%s, %s)" % [Reveal.live(total_p.x, p_from), Reveal.live(total_p.y, p_from)])
	lines.append("unsplit bird (%s, %s)" % [Reveal.live(p_unsplit.x, p_from), Reveal.live(p_unsplit.y, p_from)])
	return lines


func _split_lines(bird: Bird) -> Array:
	var info := bird.split_info
	var p_before: Vector2 = info["p_before"]
	var p_after: Vector2 = info["p_after"]
	var lost := 1.0 - p_after.length() / p_before.length()
	var p_from := ["p", "m", "v"]
	var header: String
	if info.get("kind") == "egg":
		var masses: Array = info["masses"]
		header = "Matilda threw a %s kg egg down at u = %s m/s (she is now %s kg)" % [String.num(masses[1], 2), String.num(info["egg_speed"], 1), String.num(masses[0], 2)]
		if info.get("straight_down", false):
			header += "\n  and backwards, so it falls straight down: she speeds up forwards ×%s (vₓ' = vₓ·m/m_bird)" % String.num((masses[0] + masses[1]) / masses[0], 2)
	else:
		header = "Blue bird split: %d pieces of %s kg, ±%s°" % [info["pieces"], _n(bird.mass_now(), ["m"]), String.num(info["spread"], 1)]
	var lines := [
		header,
		"  speed     %s → %s m/s" % [_n(info["speed_before"], ["v"]), _n(info["speed_after"], ["v"])],
		"  p before  (%s, %s)" % [_n(p_before.x, p_from), _n(p_before.y, p_from)],
		"  p after   (%s, %s)   %s" % [_n(p_after.x, p_from), _n(p_after.y, p_from),
			"conserved ✓" if absf(lost) < 0.001 else "%s%% lost ✗ (like the real game)" % String.num(lost * 100.0, 1)],
		"  KE before %s J → after %s J" % [_n(info["ke_before"], ["m", "v"]), _n(info["ke_after"], ["m", "v"])],
		"  (the throw adds energy, from Matilda's muscles)" if info.get("kind") == "egg" else "  (the split adds energy, like a small explosion)",
		"",
	]
	# Live check: total momentum of the pieces vs. the bird that didn't split.
	var total_p := Vector2.ZERO
	for piece in bird.pieces:
		if not is_instance_valid(piece) or piece.state != Bird.State.FLYING:
			lines.append("A piece hit something: an outside force, so the")
			lines.append("center of mass no longer follows the old arc.")
			return lines
		total_p += piece.mass_now() * piece.velocity_m()
	var t_unsplit := bird.split_t + bird.flight_time - bird.split_flight_time
	var p_unsplit := bird.pre_split.m * Kinematics.velocity(bird.pre_split, t_unsplit)
	lines.append("Now:  Σp pieces    (%s, %s)" % [Reveal.live(total_p.x, p_from), Reveal.live(total_p.y, p_from)])
	lines.append("      unsplit bird (%s, %s)" % [Reveal.live(p_unsplit.x, p_from), Reveal.live(p_unsplit.y, p_from)])
	lines.append("Center of mass (+) vs. unsplit bird (o): same spot")
	lines.append("exactly when momentum is conserved.")
	return lines


func _n(x: float, depends_on: Array) -> String:
	return Reveal.num(x, depends_on)
