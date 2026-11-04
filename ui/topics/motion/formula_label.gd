class_name FormulaLabel
extends LiveLabel
## Details: the motion formulas twice, with symbols and with the numbers filled in.
##   Before launch: the formula the next bird will follow.
##   In flight: the formula the bird is following right now (after an Activate,
##   that's a new segment starting where the bird was, with t counted from there).
## Compact (dock): where it will land, plus live readouts of t, x, y, vx, vy.
## Numbers go through Reveal, so hidden symbols show as "?".


func _build_lines() -> Array:
	var bird: Bird = PhysicsParams.bird
	var flying := PhysicsParams.is_flying()
	var p: LaunchParams = bird.segment if flying else PhysicsParams.launch_params()
	var first_segment := not flying or bird.activations == 0
	if details:
		var heading := "NEXT LAUNCH"
		if flying:
			heading = "BIRD IN FLIGHT" if first_segment else "BIRD IN FLIGHT: segment %d (t restarts at each Activate)" % (bird.activations + 1)
		return [heading] + _formula_lines(p, first_segment)

	# Compact: always the same four lines in fixed columns, so the panel keeps
	# its shape while the numbers change.
	var lines := [_prediction_line(p, first_segment)]
	var row1 := "   t = %s s     x = %s m     y = %s m"
	var row2 := "  vx = %s m/s  vy = %s m/s  |v| = %s m/s"
	if not is_instance_valid(bird):
		var dash := "–".lpad(6)
		lines.append("NOW  no bird yet")
		lines.append(row1 % [dash, dash, dash])
		lines.append(row2 % [dash, dash, dash])
		return lines
	var pos: Vector2 = Units.to_m(bird.position)
	var vel: Vector2 = bird.velocity_m()
	if bird.state == Bird.State.FLYING and bird.activations > 0:
		lines.append("NOW  in flight, segment t = %s s" % Reveal.live(bird.t, ["t"], 5))
	elif bird.state == Bird.State.FLYING:
		lines.append("NOW  in flight")
	else:
		lines.append("NOW  crashed: Godot physics in control")
	lines.append(row1 % [Reveal.live(bird.flight_time, ["t"]), Reveal.live(pos.x, ["x"]), Reveal.live(pos.y, ["y"])])
	lines.append(row2 % [Reveal.live(vel.x, ["vx"]), Reveal.live(vel.y, ["vy"]), Reveal.live(vel.length(), ["v"])])
	return lines


func _formula_lines(p: LaunchParams, first_segment: bool) -> Array:
	var v := Kinematics.initial_velocity(p)
	# Which symbols each number is made from. After an Activate, a segment starts
	# wherever the bird was, so its x₀ and y₀ are positions (x, y).
	var x0_from := [] if first_segment else ["x"]
	var y0_from := ["y0"] if first_segment else ["y"]
	var vx_from := ["v0", "theta", "vx"]
	var vy_from := ["v0", "theta", "vy"]
	return [
		"g = %s   v₀ = %s   θ = %s°   m = %s kg" % [_n(p.g, ["g"]), _n(p.v0, ["v0"]), _n(p.theta_deg, ["theta"]), _n(p.m, ["m"])],
		"",
		"x(t)  = x₀ + v₀·cos(θ)·t",
		"      = %s %s·t" % [_n(p.x0, x0_from), _signed(v.x, vx_from)],
		"y(t)  = y₀ + v₀·sin(θ)·t − ½·g·t²",
		"      = %s %s·t − %s·t²" % [_n(p.y0, y0_from), _signed(v.y, vy_from), _n(0.5 * p.g, ["g"])],
		"vx(t) = v₀·cos(θ)        = %s" % _n(v.x, vx_from),
		"vy(t) = v₀·sin(θ) − g·t  = %s − %s·t" % [_n(v.y, vy_from), _n(p.g, ["g"])],
		"",
		_prediction_line(p, first_segment),
		"Mass appears in none of these formulas!" if not p.is_rocket() else "+ ROCKET: v_e·ln(m₀/m(t)) extra speed along the thrust (see Momentum)",
		"",
		"SOLVE: hit target (X, Y), drop D = y₀ − Y",
		"  0 = D + X·tanθ − g·X² / (2·v₀²·cos²θ)",
		"  v₀ = √( g·X² / (2·cos²θ·(D + X·tanθ)) )",
		"  g  = 2·v₀²·cos²θ·(D + X·tanθ) / X²",
		"  θ: a·tan²θ − X·tanθ + (a − D) = 0,  a = g·X²/(2·v₀²)",
		"     two answers: a low arc and a high arc",
	]


func _prediction_line(p: LaunchParams, first_segment: bool) -> String:
	var landing_x := p.x0 + Kinematics.horizontal_range(p)
	var prediction_from := ["predict", "g", "v0", "theta", "y0" if first_segment else "y"]
	if not first_segment:
		prediction_from.append("x")
	return "Lands at x = %s m after %s s,  highest y = %s m" % [_n(landing_x, prediction_from), _n(Kinematics.time_of_flight(p), prediction_from), _n(Kinematics.apex_height(p), prediction_from)]


## "+ 12.5" or "− 12.5", so a negative number reads as a minus, not "+ -12.5".
## A hidden number shows as "+ ?" (the sign would give part of it away).
func _signed(x: float, depends_on: Array) -> String:
	if Reveal.any_hidden(depends_on):
		return "+ ?"
	return ("− " if x < 0.0 else "+ ") + _n(absf(x), [])


func _n(x: float, depends_on: Array) -> String:
	return Reveal.num(x, depends_on)
