extends SceneTree
## Checks kinematics.gd against answers worked out by hand.
## Run: godot --headless --path . --script res://tests/test_kinematics.gd

var failures := 0


func _init():
	# Default shot: v₀ = 15 m/s, θ = 45°, g = 9.81, launched from the ground.
	var p := make(15.0, 45.0, 9.81, 0.0)
	check("time of flight = 2·v₀·sin θ / g", Kinematics.time_of_flight(p), 2.0 * 15.0 * sin(PI / 4) / 9.81)
	check("range = v₀²·sin 2θ / g", Kinematics.horizontal_range(p), 15.0 * 15.0 / 9.81)
	check("apex = (v₀·sin θ)² / 2g", Kinematics.apex_height(p), pow(15.0 * sin(PI / 4), 2) / (2.0 * 9.81))
	check("y is 0 at landing", Kinematics.position(p, Kinematics.time_of_flight(p)).y, 0.0)
	check("vy is 0 at the apex", Kinematics.velocity(p, Kinematics.time_to_apex(p)).y, 0.0)
	check("vx never changes", Kinematics.velocity(p, 1.7).x, 15.0 * cos(PI / 4))

	# Thrown flat off a 10 m cliff at 10 m/s: falls for sqrt(2h/g).
	p = make(10.0, 0.0, 9.81, 10.0)
	check("cliff: time of flight = sqrt(2h/g)", Kinematics.time_of_flight(p), sqrt(2.0 * 10.0 / 9.81))
	check("cliff: range = v·t", Kinematics.horizontal_range(p), 10.0 * sqrt(2.0 * 10.0 / 9.81))
	check("cliff: apex is the start", Kinematics.apex_height(p), 10.0)

	# 30° and 60° land at the same spot (complementary angles).
	check("30° and 60° have the same range",
		Kinematics.horizontal_range(make(20.0, 30.0, 9.81, 0.0)),
		Kinematics.horizontal_range(make(20.0, 60.0, 9.81, 0.0)))

	# No gravity: it never comes down.
	p = make(15.0, 45.0, 0.0, 0.0)
	check_true("g = 0: never lands", is_inf(Kinematics.time_of_flight(p)))
	check_true("g = 0: no apex", is_inf(Kinematics.apex_height(p)))

	# No gravity, heading down at 45° from 5 m up (e.g. after a mid-air Activate): a straight line.
	p = make(10.0, -45.0, 0.0, 5.0)
	check("g = 0 heading down: lands after y₀ / |vy|", Kinematics.time_of_flight(p), 5.0 / (10.0 * sin(PI / 4)))
	check("g = 0 heading down: range equals the drop", Kinematics.horizontal_range(p), 5.0)

	# Solving for a target: plug each answer back in and check it really hits.
	var target := Vector2(25.0, 0.4)
	var speed := Kinematics.solve_speed(45.0, 9.81, 0.0, target)
	check_hit("solved v₀ hits the target", make(speed, 45.0, 9.81, 0.0), target)
	check("solved v₀ on flat ground = √(g·R/sin 2θ)", Kinematics.solve_speed(30.0, 9.81, 0.0, Vector2(20, 0)), sqrt(9.81 * 20.0 / sin(deg_to_rad(60.0))))
	var g_needed := Kinematics.solve_gravity(15.0, 45.0, 2.0, target)
	check_hit("solved g hits the target", make(15.0, 45.0, g_needed, 2.0), target)
	var angles := Kinematics.solve_angles(18.0, 9.81, 0.0, target)
	check_true("two angles reach the target (low and high arc)", angles.size() == 2 and angles[0] < angles[1])
	for angle in angles:
		check_hit("solved θ = %.2f° hits the target" % angle, make(18.0, angle, 9.81, 0.0), target)
	var closest := Kinematics.closest_approach(make(speed, 45.0, 9.81, 0.0), target)
	check_true("closest approach of the solved path is ~0 (%.4f m)" % closest.y, closest.y < 0.01)
	check_true("closest approach of a slower path is clearly a miss (%.2f m)" % Kinematics.closest_approach(make(speed - 2.0, 45.0, 9.81, 0.0), target).y,
		Kinematics.closest_approach(make(speed - 2.0, 45.0, 9.81, 0.0), target).y > 0.5)
	var pig_on_pole := Vector2(12.0, 3.0)
	var pig_on_ground := Vector2(20.0, 0.0)
	var both := Kinematics.solve_two_points(2.0, pig_on_pole, pig_on_ground, 9.81)
	check_hit("two-point launch hits the pig on the pole", make(both.x, both.y, 9.81, 2.0), pig_on_pole)
	check_hit("two-point launch hits the pig on the ground", make(both.x, both.y, 9.81, 2.0), pig_on_ground)
	check_true("out of reach: no angle", Kinematics.solve_angles(5.0, 9.81, 0.0, target).is_empty())
	check_true("aiming below the target: no speed works", is_nan(Kinematics.solve_speed(0.0, 9.81, 0.0, Vector2(10, 3))))
	# Straight up never moves sideways: no speed or gravity reaches a target in front.
	check_true("θ = 90°: no speed works", is_nan(Kinematics.solve_speed(90.0, 9.81, 0.0, target)))
	check_true("θ = 90°: no gravity works (was g ≈ 0)", is_nan(Kinematics.solve_gravity(15.0, 90.0, 0.0, target)))

	# Rocket: fired straight up with no gravity, it gains exactly v_e·ln(m₀/m₁).
	var rocket := make(0.0001, 90.0, 0.0, 10.0)
	rocket.m = 2.0
	rocket.thrust_dir = Vector2(0, 1)   # up, in physics coordinates (y up)
	rocket.exhaust_speed = 30.0
	rocket.burn_rate = 0.5
	rocket.burn_time = 2.0   # burns 1 kg: 2 kg → 1 kg
	var gained := Kinematics.velocity(rocket, 5.0).y - 0.0001
	check_true("rocket Δv = v_e·ln(m₀/m₁) = 30·ln 2 (got %.5f)" % gained, absf(gained - 30.0 * log(2.0)) < 1e-4)   # (Vector2 is 32-bit)
	check("rocket mass after the burn = 1 kg", Kinematics.mass_at(rocket, 3.0), 1.0)
	# The distance formula must match adding up the speed (checked numerically).
	var summed := 0.0
	var dt := 0.0001
	for i in int(2.0 / dt):
		summed += Kinematics.rocket_speed(rocket, (i + 0.5) * dt) * dt
	check_true("rocket distance formula matches the summed speed (%.5f vs %.5f)" % [Kinematics.rocket_distance(rocket, 2.0), summed], absf(Kinematics.rocket_distance(rocket, 2.0) - summed) < 1e-4)
	# With gravity, a rocket fired level from 10 m lands where the stepped path says.
	var level := make(10.0, 0.0, 9.81, 10.0)
	level.m = 1.0
	level.thrust_dir = Vector2.RIGHT
	level.exhaust_speed = 20.0
	level.burn_rate = 0.4
	level.burn_time = 1.0
	check_true("rocket lands at y = 0 (t = %.3f s)" % Kinematics.time_of_flight(level), absf(Kinematics.position(level, Kinematics.time_of_flight(level)).y) < 1e-3)

	if failures == 0:
		print("All kinematics tests passed.")
	else:
		print("%d kinematics test(s) FAILED." % failures)
	quit(1 if failures > 0 else 0)


## Does the path pass within 1 mm of the target? (Vector2 stores 32-bit floats,
## so 0.4 comes back as 0.3999999: an exact match is too strict here.)
func check_hit(name: String, p: LaunchParams, target: Vector2):
	var v := Kinematics.initial_velocity(p)
	var y := Kinematics.position(p, target.x / v.x).y
	check_true("%s (y = %.6f at x = %.1f, target y = %.6f)" % [name, y, target.x, target.y], absf(y - target.y) < 1e-3)


func make(v0: float, theta_deg: float, g: float, y0: float) -> LaunchParams:
	var p := LaunchParams.new()
	p.v0 = v0
	p.theta_deg = theta_deg
	p.g = g
	p.y0 = y0
	return p


func check(name: String, actual: float, expected: float):
	check_true("%s (got %.6f, expected %.6f)" % [name, actual, expected], absf(actual - expected) < 1e-6)


func check_true(name: String, ok: bool):
	if not ok:
		failures += 1
	print(("  ok    " if ok else "  FAIL  ") + name)
